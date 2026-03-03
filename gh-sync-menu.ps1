# =============================================================================
# gh-sync-menu.ps1 - Interactive User Interface for gh-sync
# =============================================================================

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GhSyncCmd = "gh-sync"

# Attempt to locate gh-sync
if (Get-Command "gh-sync" -ErrorAction SilentlyContinue) {
    $GhSyncCmd = "gh-sync"
}
elseif (Test-Path (Join-Path $ScriptDir "gh-sync.ps1")) {
    $GhSyncCmd = Join-Path $ScriptDir "gh-sync.ps1"
}
else {
    Write-Host "Error: gh-sync not found in PATH and ./gh-sync.ps1 not found." -ForegroundColor Red
    Write-Host "Please install gh-sync first."
    exit 1
}

function Show-Header {
    Clear-Host
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host "             gh-sync Interactive UI              " -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Pause-Script {
    Write-Host "`nPress [Enter] to continue..." -ForegroundColor Yellow
    Read-Host
}

while ($true) {
    Show-Header
    Write-Host "Choose an action:"
    Write-Host "  1) Status  - Check sync status (In-sync, Modified, Missing)" -ForegroundColor Green
    Write-Host "  2) Diff    - See detailed file-by-file differences" -ForegroundColor Green
    Write-Host "  3) Push    - Copy golden source -> project" -ForegroundColor Green
    Write-Host "  4) Pull    - Copy project -> golden source" -ForegroundColor Green
    Write-Host "  5) Backups - Manage, restore, and clean backups" -ForegroundColor Green
    Write-Host "  6) Init    - Configure golden source path" -ForegroundColor Green
    Write-Host "  0) Exit" -ForegroundColor Red
    Write-Host ""

    $choice = Read-Host "Select [0-6]"
    
    switch ($choice) {
        "1" {
            Show-Header
            Write-Host "Running Status..." -ForegroundColor Cyan
            & $GhSyncCmd status
            Pause-Script
        }
        "2" {
            Show-Header
            Write-Host "Running Diff..." -ForegroundColor Cyan
            & $GhSyncCmd diff
            Pause-Script
        }
        "3" {
            Show-Header
            Write-Host "Push: Golden Source -> Current Project" -ForegroundColor Yellow
            $dry_run_input = Read-Host "Dry run? (Preview only) [Y/n]"
            $args_list = [System.Collections.Generic.List[string]]::new()
            $args_list.Add("push")
            if ($dry_run_input -notmatch "^[Nn]$") {
                $args_list.Add("--dry-run")
            }
            $only = Read-Host "Only specific folders? (e.g. .github,.agents or leave empty for all)"
            if (-not [string]::IsNullOrWhiteSpace($only)) {
                $args_list.Add("--only")
                $args_list.Add($only)
            }
            
            Write-Host "`nExecuting: $GhSyncCmd $($args_list -join ' ')" -ForegroundColor Cyan
            & $GhSyncCmd @args_list
            Pause-Script
        }
        "4" {
            Show-Header
            Write-Host "Pull: Current Project -> Golden Source" -ForegroundColor Yellow
            $dry_run_input = Read-Host "Dry run? (Preview only) [Y/n]"
            $args_list = [System.Collections.Generic.List[string]]::new()
            $args_list.Add("pull")
            if ($dry_run_input -notmatch "^[Nn]$") {
                $args_list.Add("--dry-run")
            }
            $only = Read-Host "Only specific folders? (e.g. .github,.agents or leave empty for all)"
            if (-not [string]::IsNullOrWhiteSpace($only)) {
                $args_list.Add("--only")
                $args_list.Add($only)
            }
            Write-Host "`nExecuting: $GhSyncCmd $($args_list -join ' ')" -ForegroundColor Cyan
            & $GhSyncCmd @args_list
            Pause-Script
        }
        "5" {
            $inBackup = $true
            while ($inBackup) {
                Show-Header
                Write-Host "Backup Management:"
                Write-Host "  1) List Available Backups" -ForegroundColor Green
                Write-Host "  2) Restore Latest Backup" -ForegroundColor Green
                Write-Host "  3) Restore Specific Backup (Interactive)" -ForegroundColor Green
                Write-Host "  4) Clean Old Backups" -ForegroundColor Green
                Write-Host "  0) Back to Main Menu" -ForegroundColor Red
                Write-Host ""
                $b_choice = Read-Host "Select [0-4]"
                
                switch ($b_choice) {
                    "1" {
                        Show-Header
                        & $GhSyncCmd backups
                        Pause-Script
                    }
                    "2" {
                        Show-Header
                        & $GhSyncCmd restore --latest
                        Pause-Script
                    }
                    "3" {
                        Show-Header
                        & $GhSyncCmd restore
                        Pause-Script
                    }
                    "4" {
                        Show-Header
                        $keep_cnt = Read-Host "Keep how many backups per folder? [Default: 5]"
                        if ([string]::IsNullOrWhiteSpace($keep_cnt)) {
                            & $GhSyncCmd clean
                        }
                        else {
                            & $GhSyncCmd clean --keep $keep_cnt
                        }
                        Pause-Script
                    }
                    "0" {
                        $inBackup = $false
                    }
                    default {
                        Write-Host "Invalid option" -ForegroundColor Red
                        Start-Sleep -Seconds 1
                    }
                }
            }
        }
        "6" {
            Show-Header
            & $GhSyncCmd init
            Pause-Script
        }
        "0" {
            Write-Host "Exiting..."
            exit 0
        }
        default {
            Write-Host "Invalid option. Please enter a number from 0 to 6." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
