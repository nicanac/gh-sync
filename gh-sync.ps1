<#
.SYNOPSIS
    Synchronize a golden .github folder to/from any project.

.DESCRIPTION
    gh-sync is a bidirectional sync tool that keeps your .github folder
    (agents, skills, memory-bank, instructions) in sync between a single
    golden source and any number of project copies.

    Set $env:GH_SYNC_SOURCE to point to your golden .github folder,
    or create a config file at ~\.gh-sync-config (one line: the path).

.PARAMETER Action
    push   - Copy golden source -> project .github
    pull   - Copy project .github -> golden source
    diff   - Show differences without changing anything
    status - Show which side is newer per file

.PARAMETER ProjectPath
    Path to the project root that contains (or will contain) a .github folder.
    Defaults to the current working directory.

.PARAMETER DryRun
    Show what would happen without making any changes. Works with push/pull.

.PARAMETER Exclude
    Array of relative path patterns to exclude (supports wildcards).

.PARAMETER Force
    Skip the confirmation prompt.

.EXAMPLE
    gh-sync push
    gh-sync pull
    gh-sync push C:\Projects\MyApp
    gh-sync diff
    gh-sync push -DryRun
    gh-sync push -Force
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

# -- Resolve golden source path --
function Get-GoldenSource {
    # 1. Environment variable
    if ($env:GH_SYNC_SOURCE) { return $env:GH_SYNC_SOURCE }

    # 2. Config file in user home
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

function Resolve-ProjectGithub {
    param([string]$Path)
    $resolved = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (-not $resolved) {
        Write-Err "Project path does not exist: $Path"
        exit 1
    }
    return Join-Path $resolved.Path ".github"
}

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

function Invoke-Sync {
    param(
        [string]$sourceDir,
        [string]$targetDir,
        [string]$label,
        [bool]$isDryRun
    )

    $diffs = Compare-Folders -sourceDir $sourceDir -targetDir $targetDir -sourceLabel "source" -targetLabel "target"

    if ($diffs.Count -eq 0) {
        Write-Ok "Already in sync -- nothing to do."
        return
    }

    $toCopy = $diffs | Where-Object { $_.Status -eq "ONLY_IN_SOURCE" -or $_.Status -eq "MODIFIED" }
    $toDelete = $diffs | Where-Object { $_.Status -eq "ONLY_IN_TARGET" }

    Write-Header "$label -- Summary"
    if ($toCopy -and $toCopy.Count -gt 0) {
        Write-Host "  Files to copy/update: $($toCopy.Count)" -ForegroundColor White
        foreach ($f in $toCopy) {
            Write-Info ($f.Status.PadRight(16) + " " + $f.RelativePath)
        }
    }
    if ($toDelete -and $toDelete.Count -gt 0) {
        Write-Host ""
        Write-Host "  Files only in target (will NOT be deleted -- use manual cleanup):" -ForegroundColor DarkYellow
        foreach ($f in $toDelete) { Write-Warn $f.RelativePath }
    }

    if ($isDryRun) {
        Write-Warn "Dry-run mode -- no files were changed."
        return
    }

    if (-not $Force) {
        Write-Host ""
        $answer = Read-Host "  Proceed? [y/N]"
        if ($answer -notin @("y", "Y", "yes", "Yes")) {
            Write-Warn "Aborted."
            return
        }
    }

    # Create backup
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupDir = Join-Path ([System.IO.Path]::GetTempPath()) "gh-sync-backup-$timestamp"
    if (Test-Path $targetDir) {
        Copy-Item -Path $targetDir -Destination $backupDir -Recurse -Force
        Write-Info "Backup created at: $backupDir"
    }

    # Copy files
    foreach ($f in $toCopy) {
        $src = Join-Path $sourceDir $f.RelativePath
        $dst = Join-Path $targetDir $f.RelativePath
        $dstDir = Split-Path $dst -Parent
        if (-not (Test-Path $dstDir)) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        }
        Copy-Item -Path $src -Destination $dst -Force
        Write-Ok "Copied: $($f.RelativePath)"
    }

    Write-Ok "Sync complete! ($($toCopy.Count) files updated)"
}

# -- Handle "init" action before validation --
if ($Action -eq "init") {
    Write-Header "INIT: Configure gh-sync"
    $configFile = Join-Path $env:USERPROFILE ".gh-sync-config"

    if ($GoldenSource) {
        Write-Info "Current golden source: $GoldenSource"
    }

    Write-Host ""
    $newPath = Read-Host "  Enter the path to your golden .github folder"
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

    Set-Content -Path $configFile -Value $newPath -Encoding UTF8
    Write-Ok "Saved config to: $configFile"
    Write-Ok "Golden source set to: $newPath"
    Write-Host ""
    Write-Info "You can now use: gh-sync push, pull, diff, status"
    exit 0
}

# -- Validation --
if (-not $GoldenSource) {
    Write-Err "Golden source not configured."
    Write-Err "Run 'gh-sync init' to set it up, or set the GH_SYNC_SOURCE environment variable."
    exit 1
}

if (-not (Test-Path $GoldenSource)) {
    Write-Err "Golden source not found: $GoldenSource"
    Write-Err "Run 'gh-sync init' to reconfigure, or check the path."
    exit 1
}

$ProjectGithub = Resolve-ProjectGithub -Path $ProjectPath

# -- Actions --
if ($Action -eq "push") {
    Write-Header "PUSH: Golden Source -> Project"
    Write-Info "Source:  $GoldenSource"
    Write-Info "Target:  $ProjectGithub"

    if (-not (Test-Path $ProjectGithub)) {
        Write-Warn "Target .github folder does not exist -- it will be created."
    }

    Invoke-Sync -sourceDir $GoldenSource -targetDir $ProjectGithub -label "PUSH" -isDryRun $DryRun.IsPresent
}
elseif ($Action -eq "pull") {
    Write-Header "PULL: Project -> Golden Source"
    Write-Info "Source:  $ProjectGithub"
    Write-Info "Target:  $GoldenSource"

    if (-not (Test-Path $ProjectGithub)) {
        Write-Err "Project does not have a .github folder at: $ProjectGithub"
        exit 1
    }

    Invoke-Sync -sourceDir $ProjectGithub -targetDir $GoldenSource -label "PULL" -isDryRun $DryRun.IsPresent
}
elseif ($Action -eq "diff") {
    Write-Header "DIFF: Golden Source <-> Project"
    Write-Info "Golden:  $GoldenSource"
    Write-Info "Project: $ProjectGithub"

    if (-not (Test-Path $ProjectGithub)) {
        Write-Warn "Project .github folder does not exist yet."
        Write-Info "A 'push' will create it with all golden source files."
        exit 0
    }

    $diffs = Compare-Folders -sourceDir $GoldenSource -targetDir $ProjectGithub -sourceLabel "Golden" -targetLabel "Project"

    if ($diffs.Count -eq 0) {
        Write-Ok "Folders are identical -- fully in sync!"
    }
    else {
        Write-Host ""
        Write-Host "  Found $($diffs.Count) difference(s):" -ForegroundColor White
        Write-Host ""
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
elseif ($Action -eq "status") {
    Write-Header "STATUS: Sync Overview"
    Write-Info "Golden:  $GoldenSource"
    Write-Info "Project: $ProjectGithub"

    if (-not (Test-Path $ProjectGithub)) {
        Write-Warn "Project has no .github folder."
        exit 0
    }

    $diffs = Compare-Folders -sourceDir $GoldenSource -targetDir $ProjectGithub -sourceLabel "Golden" -targetLabel "Project"
    $totalGolden = (Get-AllFiles -folder $GoldenSource).Count
    $onlyInTarget = ($diffs | Where-Object { $_.Status -eq "ONLY_IN_TARGET" }).Count
    $onlyInSource = ($diffs | Where-Object { $_.Status -eq "ONLY_IN_SOURCE" }).Count
    $modified = ($diffs | Where-Object { $_.Status -eq "MODIFIED" }).Count
    $identical = $totalGolden - $onlyInSource - $modified

    Write-Host ""
    Write-Host "  In sync:         $identical files" -ForegroundColor Green
    Write-Host "  Only in Golden:  $onlyInSource files" -ForegroundColor Cyan
    Write-Host "  Only in Project: $onlyInTarget files" -ForegroundColor Magenta
    Write-Host "  Modified:        $modified files" -ForegroundColor Yellow
}
