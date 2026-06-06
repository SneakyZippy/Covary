$ErrorActionPreference = "Stop"

Write-Host "--- Covary Shipping Process ---" -ForegroundColor Cyan

# 1. Load current version
if (-not (Test-Path "version.json")) {
    Write-Error "version.json not found!"
}
$json = Get-Content -Raw -Encoding UTF8 -Path "version.json" | ConvertFrom-Json
$currentVersion = $json.latest_version
$newBuildNumber = [int]$json.build_number + 1
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
$tag = "v$currentVersion+$newBuildNumber"

Write-Host "New Build: $tag" -ForegroundColor Green

# Define UTF-8 without BOM encoding
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

# Extract body from current release notes
$oldNotes = $json.release_notes
$notesBody = ""
if ($oldNotes) {
    $lines = $oldNotes -split "`r?`n"
    if ($lines.Count -gt 0) {
        if ($lines[0] -match "^Release v?\d+\.\d+\.\d+(\+\d+)?") {
            $bodyLines = @()
            $startedBody = $false
            for ($i = 1; $i -lt $lines.Count; $i++) {
                if (-not $startedBody) {
                    if ([string]::IsNullOrWhiteSpace($lines[$i])) {
                        continue
                    }
                    $startedBody = $true
                }
                $bodyLines += $lines[$i]
            }
            $notesBody = $bodyLines -join "`n"
        } else {
            $notesBody = $oldNotes
        }
    }
}

$editNotes = Read-Host "Do you want to edit the release notes details in Notepad? (y/n)"
if ($editNotes -eq "y" -or $editNotes -eq "yes") {
    $tempFile = Join-Path $env:TEMP "covary_release_notes.txt"
    $lastTag = git describe --tags --abbrev=0 2>$null
    $gitCommits = ""
    if ($lastTag) {
        $gitCommits = git log "$lastTag..HEAD" --oneline
    }
    
    $template = @"
# Release Notes for Release $tag
# Edit the text below the separator line. Lines starting with # will be ignored.
#
# Recent commits since last tag ($lastTag) for reference:
$( if ($gitCommits) { $gitCommits | Out-String } else { "# No new commits found since $lastTag" } )
--------------------------------------------------
$notesBody
"@
    [System.IO.File]::WriteAllText($tempFile, $template, $utf8NoBom)
    
    Write-Host "Opening Notepad for release notes editing..." -ForegroundColor Yellow
    Start-Process notepad.exe -ArgumentList $tempFile -Wait
    
    if (Test-Path $tempFile) {
        $editedContent = Get-Content -Raw -Path $tempFile
        Remove-Item $tempFile -Force
        
        $cleanLines = @()
        $foundSeparator = $false
        foreach ($line in $editedContent -split "`r?`n") {
            if (-not $foundSeparator) {
                if ($line -like "--------------------------------------------------*") {
                    $foundSeparator = $true
                }
                continue
            }
            if ($line.StartsWith("#")) {
                continue
            }
            $cleanLines += $line
        }
        
        if ($foundSeparator) {
            $notesBody = ($cleanLines -join "`n").Trim()
        } else {
            $cleanLines = @()
            foreach ($line in $editedContent -split "`r?`n") {
                if (-not $line.StartsWith("#")) {
                    $cleanLines += $line
                }
            }
            $notesBody = ($cleanLines -join "`n").Trim()
        }
    }
}

# Always format with the correct and matching header
$json.release_notes = "Release $tag`n`n$notesBody"

# 2. Update version.json
$json.build_number = $newBuildNumber
$json.build_timestamp = $timestamp
$jsonString = $json | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText((Join-Path (Get-Location) "version.json"), $jsonString, $utf8NoBom)

# 3. Update pubspec.yaml
$pubspec = Get-Content -Encoding UTF8 -Path "pubspec.yaml"
$newVersionString = "version: $currentVersion+$newBuildNumber"
$pubspec = $pubspec -replace "^version: .*$", $newVersionString
$pubspecString = $pubspec -join "`n"
[System.IO.File]::WriteAllText((Join-Path (Get-Location) "pubspec.yaml"), $pubspecString, $utf8NoBom)

Write-Host "Files updated. Starting build..." -ForegroundColor Yellow

# 4. Build APK
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw "Flutter build failed!" }

# 5. Git Operations
git add pubspec.yaml version.json
git commit -m "Bump version to $tag"
git push
git tag $tag
git push origin $tag

$sourceApk = "build\app\outputs\flutter-apk\app-release.apk"

# 6. GitHub Release
if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Host "Creating GitHub Release..." -ForegroundColor Yellow
    $notesFile = "release_notes_temp.txt"
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) $notesFile), $json.release_notes, $utf8NoBom)

    gh release create $tag $sourceApk --title "Release $tag" --notes-file $notesFile
    Remove-Item -Path $notesFile -Force
} else {
    Write-Host "[Warning] GitHub CLI (gh) not found in PATH. Skipping remote GitHub Release creation." -ForegroundColor Yellow
    Write-Host "You can manually upload the APK located at: $sourceApk" -ForegroundColor Green
}

Write-Host "--- Ship It Successful! ---" -ForegroundColor Green