<#
.SYNOPSIS
    Synchronize golden AI config folders to/from any project.

.DESCRIPTION
    gh-sync is a bidirectional sync tool that keeps your AI configuration
    folders (.github, .agent, .agents, .claude) in sync between a single
    golden source directory and any number of project copies.

    The golden source is a directory containing one or more of:
      .github/   - GitHub Copilot agents, skills, memory-bank
      .agent/    - VS Code agent rules, skills, workflows
      .agents/   - Additional agent skills
      .claude/   - Claude Code skills

    Configure via:  gh-sync init
    Or set env var: GH_SYNC_SOURCE=C:\path\to\golden-source

.PARAMETER Action
    push   - Copy golden source -> project
    pull   - Copy project -> golden source
    diff   - Show differences without changing anything
    status - Show sync overview per folder
    init   - Configure the golden source path

.PARAMETER ProjectPath
    Path to the project root. Defaults to current directory.

.PARAMETER DryRun
    Preview changes without modifying files.

.PARAMETER Exclude
    Wildcard patterns to exclude (relative paths).

.PARAMETER Force
    Skip confirmation prompt.

.EXAMPLE
    gh-sync push                        # push all folders to current project
    gh-sync pull                        # pull project changes back to golden
    gh-sync push C:\Projects\MyApp      # push to a specific project
    gh-sync diff                        # preview differences
    gh-sync push -DryRun               # dry-run
    gh-sync push -Force                # skip confirmation
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet("push", "pull", "diff", "status", "init")]
    [string]$Action,

    [Parameter(Position = 1)]
    [string]$ProjectPath = (Get-Location).Path,

    [switch]$DryRun,

    [string[]]$Exclude = @(),

    [switch]$Force
)

# -- Folders to sync --
$SYNC_FOLDERS = @(".github", ".agent", ".agents", ".claude")

# -- Resolve golden source path --
function Get-GoldenSource {
    if ($env:GH_SYNC_SOURCE) { return $env:GH_SYNC_SOURCE }

    $configFile = Join-Path $env:USERPROFILE ".gh-sync-config"
    if (Test-Path $configFile) {
        $path = (Get-Content $configFile -First 1).Trim()
        if ($path -and (Test-Path $path)) { return $path }
    }

    return $null
}

$GoldenSource = Get-GoldenSource

# -- Helpers --
function Write-Header { param([string]$msg); Write-Host ("`n=== " + $msg + " ===") -ForegroundColor Cyan }
function Write-Ok { param([string]$msg); Write-Host ("  [OK] " + $msg) -ForegroundColor Green }
function Write-Warn { param([string]$msg); Write-Host ("  [!!] " + $msg) -ForegroundColor Yellow }
function Write-Err { param([string]$msg); Write-Host ("  [ERR] " + $msg) -ForegroundColor Red }
function Write-Info { param([string]$msg); Write-Host ("  -> " + $msg) -ForegroundColor Gray }

function Get-RelPath {
    param([string]$base, [string]$full)
    return $full.Substring($base.Length).TrimStart('\', '/')
}

function Test-ShouldExclude {
    param([string]$relativePath)
    foreach ($pattern in $script:Exclude) {
        if ($relativePath -like $pattern) { return $true }
    }
    return $false
}

function Get-AllFiles {
    param([string]$folder)
    if (-not (Test-Path $folder)) { return @() }
    $files = Get-ChildItem -Path $folder -Recurse -File
    $result = @()
    foreach ($file in $files) {
        $rel = Get-RelPath -base $folder -full $file.FullName
        if (Test-ShouldExclude $rel) { continue }
        $hash = (Get-FileHash $file.FullName -Algorithm MD5).Hash
        $result += [PSCustomObject]@{
            RelativePath = $rel
            FullPath     = $file.FullName
            LastWrite    = $file.LastWriteTimeUtc
            Length       = $file.Length
            Hash         = $hash
        }
    }
    return $result
}

function Compare-Folders {
    param([string]$sourceDir, [string]$targetDir, [string]$sourceLabel, [string]$targetLabel)

    $sourceFiles = Get-AllFiles -folder $sourceDir
    $targetFiles = Get-AllFiles -folder $targetDir

    $sourceMap = @{}
    foreach ($f in $sourceFiles) { $sourceMap[$f.RelativePath] = $f }

    $targetMap = @{}
    foreach ($f in $targetFiles) { $targetMap[$f.RelativePath] = $f }

    $allKeys = @($sourceMap.Keys) + @($targetMap.Keys) | Sort-Object -Unique

    $results = @()
    foreach ($key in $allKeys) {
        $inSource = $sourceMap.ContainsKey($key)
        $inTarget = $targetMap.ContainsKey($key)

        if ($inSource -and (-not $inTarget)) {
            $results += [PSCustomObject]@{
                RelativePath = $key
                Status       = "ONLY_IN_SOURCE"
                Detail       = "Only in $sourceLabel"
                SourceFile   = $sourceMap[$key]
                TargetFile   = $null
            }
        }
        elseif ((-not $inSource) -and $inTarget) {
            $results += [PSCustomObject]@{
                RelativePath = $key
                Status       = "ONLY_IN_TARGET"
                Detail       = "Only in $targetLabel"
                SourceFile   = $null
                TargetFile   = $targetMap[$key]
            }
        }
        else {
            $s = $sourceMap[$key]
            $t = $targetMap[$key]
            if ($s.Hash -ne $t.Hash) {
                $newer = $sourceLabel
                if ($t.LastWrite -gt $s.LastWrite) { $newer = $targetLabel }
                $results += [PSCustomObject]@{
                    RelativePath = $key
                    Status       = "MODIFIED"
                    Detail       = "Different (newer in $newer)"
                    SourceFile   = $s
                    TargetFile   = $t
                }
            }
        }
    }
    return $results
}

function Invoke-SyncFolder {
    param(
        [string]$sourceDir,
        [string]$targetDir,
        [string]$folderName,
        [bool]$isDryRun
    )

    if (-not (Test-Path $sourceDir)) {
        Write-Info "Skipping $folderName (not in source)"
        return @{ Copied = 0; Skipped = $true }
    }

    $diffs = Compare-Folders -sourceDir $sourceDir -targetDir $targetDir -sourceLabel "source" -targetLabel "target"

    if ($diffs.Count -eq 0) {
        Write-Ok "$folderName -- already in sync"
        return @{ Copied = 0; Skipped = $false }
    }

    $toCopy = $diffs | Where-Object { $_.Status -eq "ONLY_IN_SOURCE" -or $_.Status -eq "MODIFIED" }
    $toDelete = $diffs | Where-Object { $_.Status -eq "ONLY_IN_TARGET" }

    if ($toCopy -and $toCopy.Count -gt 0) {
        Write-Host "  $folderName -- $($toCopy.Count) file(s) to copy/update:" -ForegroundColor White
        foreach ($f in $toCopy) {
            Write-Info ($f.Status.PadRight(16) + " " + $f.RelativePath)
        }
    }
    if ($toDelete -and $toDelete.Count -gt 0) {
        Write-Host "  $folderName -- $($toDelete.Count) file(s) only in target (kept):" -ForegroundColor DarkYellow
        foreach ($f in $toDelete) { Write-Warn $f.RelativePath }
    }

    if ($isDryRun) {
        return @{ Copied = 0; Skipped = $false }
    }

    # Create backup
    if (Test-Path $targetDir) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupName = "gh-sync-backup-$folderName-$timestamp"
        $backupDir = Join-Path ([System.IO.Path]::GetTempPath()) $backupName
        Copy-Item -Path $targetDir -Destination $backupDir -Recurse -Force
    }

    # Copy files
    $copiedCount = 0
    foreach ($f in $toCopy) {
        $src = Join-Path $sourceDir $f.RelativePath
        $dst = Join-Path $targetDir $f.RelativePath
        $dstDir = Split-Path $dst -Parent
        if (-not (Test-Path $dstDir)) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        }
        Copy-Item -Path $src -Destination $dst -Force
        $copiedCount++
    }
    Write-Ok "$folderName -- $copiedCount file(s) synced"
    return @{ Copied = $copiedCount; Skipped = $false }
}

# ============================================================================
# INIT
# ============================================================================
if ($Action -eq "init") {
    Write-Header "INIT: Configure gh-sync"
    $configFile = Join-Path $env:USERPROFILE ".gh-sync-config"

    if ($GoldenSource) {
        Write-Info "Current golden source: $GoldenSource"
    }

    Write-Host ""
    Write-Host "  The golden source is a DIRECTORY containing your shared folders:" -ForegroundColor White
    Write-Host "    .github/  .agent/  .agents/  .claude/" -ForegroundColor Gray
    Write-Host ""
    $newPath = Read-Host "  Enter the path to your golden source directory"
    $newPath = $newPath.Trim().Trim('"')

    if (-not (Test-Path $newPath)) {
        Write-Warn "Path does not exist yet. Create it? [y/N]"
        $create = Read-Host "  "
        if ($create -in @("y", "Y", "yes", "Yes")) {
            New-Item -ItemType Directory -Path $newPath -Force | Out-Null
            Write-Ok "Created: $newPath"
        }
        else {
            Write-Err "Aborted. Please create the folder first."
            exit 1
        }
    }

    # Show which sync folders exist in the golden source
    Write-Host ""
    foreach ($folder in $SYNC_FOLDERS) {
        $fp = Join-Path $newPath $folder
        if (Test-Path $fp) {
            $count = (Get-ChildItem -Path $fp -Recurse -File).Count
            Write-Ok "$folder ($count files)"
        }
        else {
            Write-Warn "$folder (not found -- will be skipped during sync)"
        }
    }

    Set-Content -Path $configFile -Value $newPath -Encoding UTF8
    Write-Host ""
    Write-Ok "Saved config to: $configFile"
    Write-Ok "Golden source set to: $newPath"
    Write-Host ""
    Write-Info "You can now use: gh-sync push, pull, diff, status"
    exit 0
}

# ============================================================================
# VALIDATION
# ============================================================================
if (-not $GoldenSource) {
    Write-Err "Golden source not configured."
    Write-Err "Run 'gh-sync init' to set it up, or set GH_SYNC_SOURCE env var."
    exit 1
}

if (-not (Test-Path $GoldenSource)) {
    Write-Err "Golden source not found: $GoldenSource"
    Write-Err "Run 'gh-sync init' to reconfigure."
    exit 1
}

$resolvedProject = Resolve-Path $ProjectPath -ErrorAction SilentlyContinue
if (-not $resolvedProject) {
    Write-Err "Project path does not exist: $ProjectPath"
    exit 1
}
$ProjectRoot = $resolvedProject.Path

# ============================================================================
# PUSH
# ============================================================================
if ($Action -eq "push") {
    Write-Header "PUSH: Golden Source -> Project"
    Write-Info "Source:  $GoldenSource"
    Write-Info "Target:  $ProjectRoot"
    Write-Host ""

    # Collect all diffs first for summary
    $allDiffs = @()
    foreach ($folder in $SYNC_FOLDERS) {
        $src = Join-Path $GoldenSource $folder
        $tgt = Join-Path $ProjectRoot $folder
        if (Test-Path $src) {
            $diffs = Compare-Folders -sourceDir $src -targetDir $tgt -sourceLabel "Golden" -targetLabel "Project"
            foreach ($d in $diffs) {
                $d | Add-Member -NotePropertyName "Folder" -NotePropertyValue $folder -Force
            }
            $allDiffs += $diffs
        }
    }

    if ($allDiffs.Count -eq 0) {
        Write-Ok "All folders already in sync -- nothing to do."
        exit 0
    }

    foreach ($folder in $SYNC_FOLDERS) {
        $folderDiffs = @($allDiffs | Where-Object { $_.Folder -eq $folder })
        if ($folderDiffs.Count -gt 0) {
            $toCopy = @($folderDiffs | Where-Object { $_.Status -ne "ONLY_IN_TARGET" }).Count
            $extra = @($folderDiffs | Where-Object { $_.Status -eq "ONLY_IN_TARGET" }).Count
            Write-Host "  $folder -- $toCopy to sync, $extra only in project" -ForegroundColor White
        }
    }

    if ($DryRun.IsPresent) {
        Write-Host ""
        foreach ($folder in $SYNC_FOLDERS) {
            $src = Join-Path $GoldenSource $folder
            $tgt = Join-Path $ProjectRoot $folder
            if (Test-Path $src) {
                Invoke-SyncFolder -sourceDir $src -targetDir $tgt -folderName $folder -isDryRun $true | Out-Null
            }
        }
        Write-Warn "Dry-run mode -- no files were changed."
        exit 0
    }

    if (-not $Force) {
        Write-Host ""
        $answer = Read-Host "  Proceed with PUSH? [y/N]"
        if ($answer -notin @("y", "Y", "yes", "Yes")) {
            Write-Warn "Aborted."
            exit 0
        }
    }

    Write-Host ""
    $totalCopied = 0
    foreach ($folder in $SYNC_FOLDERS) {
        $src = Join-Path $GoldenSource $folder
        $tgt = Join-Path $ProjectRoot $folder
        $result = Invoke-SyncFolder -sourceDir $src -targetDir $tgt -folderName $folder -isDryRun $false
        $totalCopied += $result.Copied
    }
    Write-Host ""
    Write-Ok "Push complete! ($totalCopied files updated across all folders)"
}

# ============================================================================
# PULL
# ============================================================================
elseif ($Action -eq "pull") {
    Write-Header "PULL: Project -> Golden Source"
    Write-Info "Source:  $ProjectRoot"
    Write-Info "Target:  $GoldenSource"
    Write-Host ""

    $allDiffs = @()
    foreach ($folder in $SYNC_FOLDERS) {
        $src = Join-Path $ProjectRoot $folder
        $tgt = Join-Path $GoldenSource $folder
        if (Test-Path $src) {
            $diffs = Compare-Folders -sourceDir $src -targetDir $tgt -sourceLabel "Project" -targetLabel "Golden"
            foreach ($d in $diffs) {
                $d | Add-Member -NotePropertyName "Folder" -NotePropertyValue $folder -Force
            }
            $allDiffs += $diffs
        }
    }

    if ($allDiffs.Count -eq 0) {
        Write-Ok "All folders already in sync -- nothing to do."
        exit 0
    }

    foreach ($folder in $SYNC_FOLDERS) {
        $folderDiffs = @($allDiffs | Where-Object { $_.Folder -eq $folder })
        if ($folderDiffs.Count -gt 0) {
            $toCopy = @($folderDiffs | Where-Object { $_.Status -ne "ONLY_IN_TARGET" }).Count
            Write-Host "  $folder -- $toCopy to pull back" -ForegroundColor White
        }
    }

    if ($DryRun.IsPresent) {
        Write-Host ""
        foreach ($folder in $SYNC_FOLDERS) {
            $src = Join-Path $ProjectRoot $folder
            $tgt = Join-Path $GoldenSource $folder
            if (Test-Path $src) {
                Invoke-SyncFolder -sourceDir $src -targetDir $tgt -folderName $folder -isDryRun $true | Out-Null
            }
        }
        Write-Warn "Dry-run mode -- no files were changed."
        exit 0
    }

    if (-not $Force) {
        Write-Host ""
        $answer = Read-Host "  Proceed with PULL? [y/N]"
        if ($answer -notin @("y", "Y", "yes", "Yes")) {
            Write-Warn "Aborted."
            exit 0
        }
    }

    Write-Host ""
    $totalCopied = 0
    foreach ($folder in $SYNC_FOLDERS) {
        $src = Join-Path $ProjectRoot $folder
        $tgt = Join-Path $GoldenSource $folder
        $result = Invoke-SyncFolder -sourceDir $src -targetDir $tgt -folderName $folder -isDryRun $false
        $totalCopied += $result.Copied
    }
    Write-Host ""
    Write-Ok "Pull complete! ($totalCopied files updated in golden source)"
}

# ============================================================================
# DIFF
# ============================================================================
elseif ($Action -eq "diff") {
    Write-Header "DIFF: Golden Source <-> Project"
    Write-Info "Golden:  $GoldenSource"
    Write-Info "Project: $ProjectRoot"

    $totalDiffs = 0
    foreach ($folder in $SYNC_FOLDERS) {
        $src = Join-Path $GoldenSource $folder
        $tgt = Join-Path $ProjectRoot $folder

        $srcExists = Test-Path $src
        $tgtExists = Test-Path $tgt

        if (-not $srcExists -and -not $tgtExists) { continue }

        Write-Host ""
        Write-Host "  --- $folder ---" -ForegroundColor Cyan

        if (-not $srcExists) {
            Write-Warn "Only in project (not in golden source)"
            continue
        }
        if (-not $tgtExists) {
            $fileCount = (Get-ChildItem -Path $src -Recurse -File).Count
            Write-Warn "Not in project ($fileCount golden files would be pushed)"
            $totalDiffs += $fileCount
            continue
        }

        $diffs = Compare-Folders -sourceDir $src -targetDir $tgt -sourceLabel "Golden" -targetLabel "Project"

        if ($diffs.Count -eq 0) {
            Write-Ok "In sync"
        }
        else {
            $totalDiffs += $diffs.Count
            foreach ($d in $diffs) {
                $icon = "?"
                $color = "White"
                if ($d.Status -eq "ONLY_IN_SOURCE") { $icon = "+"; $color = "Green" }
                elseif ($d.Status -eq "ONLY_IN_TARGET") { $icon = "-"; $color = "Red" }
                elseif ($d.Status -eq "MODIFIED") { $icon = "~"; $color = "Yellow" }

                Write-Host "  [$icon] $($d.RelativePath)" -ForegroundColor $color
                Write-Host "      $($d.Detail)" -ForegroundColor DarkGray
            }
        }
    }

    Write-Host ""
    if ($totalDiffs -eq 0) {
        Write-Ok "All folders fully in sync!"
    }
    else {
        Write-Warn "$totalDiffs total difference(s) found."
    }
}

# ============================================================================
# STATUS
# ============================================================================
elseif ($Action -eq "status") {
    Write-Header "STATUS: Sync Overview"
    Write-Info "Golden:  $GoldenSource"
    Write-Info "Project: $ProjectRoot"
    Write-Host ""

    $grandInSync = 0
    $grandOnlyGolden = 0
    $grandOnlyProject = 0
    $grandModified = 0

    foreach ($folder in $SYNC_FOLDERS) {
        $src = Join-Path $GoldenSource $folder
        $tgt = Join-Path $ProjectRoot $folder

        $srcExists = Test-Path $src
        $tgtExists = Test-Path $tgt

        if (-not $srcExists -and -not $tgtExists) { continue }

        Write-Host "  --- $folder ---" -ForegroundColor Cyan

        if (-not $srcExists) {
            Write-Warn "Only in project"
            Write-Host ""
            continue
        }

        if (-not $tgtExists) {
            $count = (Get-ChildItem -Path $src -Recurse -File).Count
            Write-Warn "Not in project ($count files to push)"
            $grandOnlyGolden += $count
            Write-Host ""
            continue
        }

        $diffs = Compare-Folders -sourceDir $src -targetDir $tgt -sourceLabel "Golden" -targetLabel "Project"
        $totalGolden = (Get-AllFiles -folder $src).Count
        $onlyInTarget = @($diffs | Where-Object { $_.Status -eq "ONLY_IN_TARGET" }).Count
        $onlyInSource = @($diffs | Where-Object { $_.Status -eq "ONLY_IN_SOURCE" }).Count
        $modified = @($diffs | Where-Object { $_.Status -eq "MODIFIED" }).Count
        $identical = $totalGolden - $onlyInSource - $modified

        Write-Host "    In sync:         $identical" -ForegroundColor Green
        Write-Host "    Only in Golden:  $onlyInSource" -ForegroundColor Cyan
        Write-Host "    Only in Project: $onlyInTarget" -ForegroundColor Magenta
        Write-Host "    Modified:        $modified" -ForegroundColor Yellow
        Write-Host ""

        $grandInSync += $identical
        $grandOnlyGolden += $onlyInSource
        $grandOnlyProject += $onlyInTarget
        $grandModified += $modified
    }

    Write-Host "  === TOTAL ===" -ForegroundColor Cyan
    Write-Host "    In sync:         $grandInSync files" -ForegroundColor Green
    Write-Host "    Only in Golden:  $grandOnlyGolden files" -ForegroundColor Cyan
    Write-Host "    Only in Project: $grandOnlyProject files" -ForegroundColor Magenta
    Write-Host "    Modified:        $grandModified files" -ForegroundColor Yellow
}
