$ErrorActionPreference = "Stop"

Write-Host "--- Covary Shipping Process ---" -ForegroundColor Cyan

# 1. Load current version
if (-not (Test-Path "version.json")) {
    Write-Error "version.json not found!"
}
$json = Get-Content -Raw -Path "version.json" | ConvertFrom-Json
$currentVersion = $json.latest_version
$newBuildNumber = [int]$json.build_number + 1
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$releaseNotes = $json.release_notes

Write-Host "New Build: v$currentVersion+$newBuildNumber" -ForegroundColor Green

# 2. Update version.json
$json.build_number = $newBuildNumber
$json.build_timestamp = $timestamp
$json | ConvertTo-Json -Depth 10 | Out-File -FilePath "version.json" -Encoding utf8

# 3. Update pubspec.yaml
$pubspec = Get-Content -Path "pubspec.yaml"
$newVersionString = "version: $currentVersion+$newBuildNumber"
$pubspec = $pubspec -replace "^version: .*$", $newVersionString
$pubspec | Out-File -FilePath "pubspec.yaml" -Encoding utf8

Write-Host "Files updated. Starting build..." -ForegroundColor Yellow

# 4. Build APK
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw "Flutter build failed!" }

# 4b. Build Web PWA
Write-Host "Building Web PWA..." -ForegroundColor Yellow
flutter build web --base-href "/Covary/" --release
if ($LASTEXITCODE -ne 0) { throw "Flutter web build failed!" }

Write-Host "Deploying PWA to GitHub Pages..." -ForegroundColor Yellow
$remoteUrl = git remote get-url origin
$deployDir = "build\web_deploy"
if (Test-Path $deployDir) { Remove-Item -Recurse -Force $deployDir }
New-Item -ItemType Directory -Force -Path $deployDir | Out-Null

Copy-Item -Path "build\web\*" -Destination $deployDir -Recurse -Force
New-Item -ItemType File -Path (Join-Path $deployDir ".nojekyll") -Force | Out-Null

Push-Location $deployDir
git init | Out-Null
git remote add origin $remoteUrl
git checkout -b gh-pages | Out-Null
git add --all
git add -f .nojekyll 2>$null
git commit -m "Deploy PWA v$currentVersion+$newBuildNumber" | Out-Null
git push -f origin gh-pages
Pop-Location
Remove-Item -Recurse -Force $deployDir
Write-Host "PWA deployed successfully to GitHub Pages!" -ForegroundColor Green

# 5. Git Operations
$tag = "v$currentVersion+$newBuildNumber"
git add pubspec.yaml version.json
git commit -m "Bump version to $tag"
git push
git tag $tag
git push origin $tag

# 6. Backup to Google Drive
$sourceApk = "build\app\outputs\flutter-apk\app-release.apk"
$driveTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$destApk = "$env:USERPROFILE\My Drive\Covary\Builds\Covary_v${currentVersion}_b${newBuildNumber}_${driveTimestamp}.apk"
$destDir = Split-Path $destApk
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
}
Copy-Item -Path $sourceApk -Destination $destApk -Force
Write-Host "Backup created: $destApk" -ForegroundColor Gray

# 7. GitHub Release
Write-Host "Creating GitHub Release..." -ForegroundColor Yellow
$notesFile = "release_notes_temp.txt"
# Ensure we use UTF8 without BOM for maximum compatibility with gh CLI
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path (Get-Location) $notesFile), $releaseNotes, $utf8NoBom)

gh release create $tag $sourceApk --title "Release $tag" --notes-file $notesFile
Remove-Item -Path $notesFile -Force

Write-Host "--- Ship It Successful! ---" -ForegroundColor Green
