<#
.SYNOPSIS
    Install gh-sync on this machine.

.DESCRIPTION
    Copies gh-sync.ps1 and gh-sync.cmd to ~\bin and adds that folder
    to the user PATH so the command is available from any terminal.

    Run this once. After installation, open a NEW terminal and use:
        gh-sync init          (first-time config)
        gh-sync push|pull|diff|status
#>

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  gh-sync Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$binDir = Join-Path $env:USERPROFILE "bin"

# 1. Create ~/bin if needed
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    Write-Host "  [OK] Created: $binDir" -ForegroundColor Green
}
else {
    Write-Host "  [OK] Exists:  $binDir" -ForegroundColor Green
}

# 2. Copy files
$filesToCopy = @("gh-sync.ps1", "gh-sync.cmd")
foreach ($file in $filesToCopy) {
    $src = Join-Path $scriptDir $file
    $dst = Join-Path $binDir $file
    if (-not (Test-Path $src)) {
        Write-Host "  [ERR] Missing: $src" -ForegroundColor Red
        exit 1
    }
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "  [OK] Installed: $file -> $binDir" -ForegroundColor Green
}

# 3. Add ~/bin to PATH if not already there
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -and $userPath.ToLower().Contains($binDir.ToLower())) {
    Write-Host "  [OK] PATH already contains $binDir" -ForegroundColor Green
}
else {
    $newPath = if ($userPath) { "$userPath;$binDir" } else { $binDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "  [OK] Added $binDir to user PATH" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    1. Open a NEW terminal (for PATH to take effect)" -ForegroundColor Gray
Write-Host "    2. Run:  gh-sync init" -ForegroundColor Yellow
Write-Host "       (enter the path to your golden .github folder)" -ForegroundColor Gray
Write-Host "    3. Then from any project folder:" -ForegroundColor Gray
Write-Host "         gh-sync push    - push golden -> project" -ForegroundColor Gray
Write-Host "         gh-sync pull    - pull project -> golden" -ForegroundColor Gray
Write-Host "         gh-sync diff    - preview differences" -ForegroundColor Gray
Write-Host "         gh-sync status  - sync overview" -ForegroundColor Gray
Write-Host ""
