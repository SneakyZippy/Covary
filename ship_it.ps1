$ErrorActionPreference = "Stop"
$env:GH_PAGER = ""

$jsonContent = Get-Content -Raw -Path "version.json" | ConvertFrom-Json
$latestVersion = $jsonContent.latest_version
$buildNumber = $jsonContent.build_number
$releaseNotes = $jsonContent.release_notes

# Generate a timestamp (e.g., yyyyMMdd_HHmmss)
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$sourceApk = "build\app\outputs\flutter-apk\app-release.apk"
$destApk = "$env:USERPROFILE\My Drive\Covary\Builds\Covary_v${latestVersion}_b${buildNumber}_${timestamp}.apk"

# Ensure directory exists
$destDir = Split-Path $destApk
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
}

Write-Host "Copying APK to $destApk..."
Copy-Item -Path $sourceApk -Destination $destApk -Force

$tag = "v${latestVersion}+${buildNumber}"

$notesFile = "release_notes_temp.txt"
$releaseNotes | Out-File -FilePath $notesFile -Encoding utf8

Write-Host "Creating GitHub Release for $tag..."
gh release create $tag $sourceApk --title "Release $tag" --notes-file $notesFile

Remove-Item -Path $notesFile -Force
Write-Host "Release created successfully."
