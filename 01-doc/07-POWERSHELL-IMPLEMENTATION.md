# 07 — PowerShell Implementation Deep Dive

Complete technical breakdown of `gh-sync.ps1` — the Windows-native implementation (~579 lines).

---

## Script Structure Overview

Unlike the Bash version (which uses functions dispatched via `main()`), the PowerShell version uses:

1. **CmdletBinding parameters** for argument parsing (lines 47–61)
2. **Standalone functions** for shared logic (lines 67–237)
3. **Top-level `if/elseif` blocks** for action routing (lines 242–578)

---

## Parameter Declaration (Lines 47–61)

```powershell
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet("push", "pull", "diff", "status", "init")]
    [string]$Action,

    [Parameter(Position = 1)]
    [string]$ProjectPath = (Get-Location).Path,

    [switch]$DryRun,

    [string[]]$Exclude = @(),
    [string[]]$Only = @(),

    [switch]$Force,

    # Backup management parameters
    [int]$Keep,
    [switch]$All,
    [switch]$Latest
)
```

**Key differences from Bash:**
- `[ValidateSet]` provides built-in validation — invalid actions are rejected by PowerShell itself
- `$ProjectPath` defaults to `Get-Location` (equivalent to `pwd`)
- `$DryRun` and `$Force` are switches (boolean flags), not string parsing
- `$Exclude` and `$Only` accept an array of strings natively
- Backup management uses native typed parameters like `[int]$Keep`.

---

## Configuration File Loading

Similar to the Bash version, PowerShell checks for `.gh-sync.json` per project:

```powershell
    $projectConfigPath = Join-Path $ProjectRoot ".gh-sync.json"
    if (Test-Path $projectConfigPath) {
        $cfg = Get-Content $projectConfigPath -Raw | ConvertFrom-Json
        # apply only, exclude, golden_source...
    }
```

PowerShell natively parses JSON configurations into objects with `ConvertFrom-Json`.

---

## Golden Source Resolution (Lines 67–77)

```powershell
function Get-GoldenSource {
    if ($env:GH_SYNC_SOURCE) { return $env:GH_SYNC_SOURCE }

    $configFile = Join-Path $env:USERPROFILE ".gh-sync-config"
    if (Test-Path $configFile) {
        $path = (Get-Content $configFile -First 1).Trim()
        if ($path -and (Test-Path $path)) { return $path }
    }

    return $null
}
```

Same priority as Bash:
1. `$env:GH_SYNC_SOURCE` environment variable
2. `~/.gh-sync-config` file (first line)

**Platform difference:** Uses `$env:USERPROFILE` instead of `$HOME` (standard on Windows).

---

## Logging Functions (Lines 82–86)

```powershell
function Write-Header { param([string]$msg); Write-Host ("`n=== " + $msg + " ===") -ForegroundColor Cyan }
function Write-Ok     { param([string]$msg); Write-Host ("  [OK] " + $msg) -ForegroundColor Green }
function Write-Warn   { param([string]$msg); Write-Host ("  [!!] " + $msg) -ForegroundColor Yellow }
function Write-Err    { param([string]$msg); Write-Host ("  [ERR] " + $msg) -ForegroundColor Red }
function Write-Info   { param([string]$msg); Write-Host ("  -> " + $msg) -ForegroundColor Gray }
```

Output matches the Bash version for visual consistency. Uses PowerShell's `-ForegroundColor` instead of ANSI escape codes.

---

## Helper Functions

### `Get-RelPath` (Lines 88–91)

```powershell
function Get-RelPath {
    param([string]$base, [string]$full)
    return $full.Substring($base.Length).TrimStart('\', '/')
}
```

Computes relative path by stripping the base directory prefix. Trims both `\` and `/` to handle Windows and Unix-style paths.

### `Test-ShouldExclude` (Lines 93–99)

```powershell
function Test-ShouldExclude {
    param([string]$relativePath)
    foreach ($pattern in $script:Exclude) {
        if ($relativePath -like $pattern) { return $true }
    }
    return $false
}
```

Uses PowerShell's `-like` operator for wildcard matching.

---

## File Collection: `Get-AllFiles` (Lines 101–119)

```powershell
function Get-AllFiles {
    param([string]$folder)
    if (-not (Test-Path $folder)) { return @() }
    
    $result = [System.Collections.Generic.List[PSCustomObject]]::new()
    $md5 = [System.Security.Cryptography.MD5]::Create()
    
    $files = Get-ChildItem -Path $folder -Recurse -File

    foreach ($file in $files) {
        $rel = Get-RelPath -base $folder -full $file.FullName
        if (Test-ShouldExclude $rel) { continue }
        
        $stream = [System.IO.File]::OpenRead($file.FullName)
        $hashBytes = $md5.ComputeHash($stream)
        $stream.Close()
        $hash = [BitConverter]::ToString($hashBytes) -replace '-', ''
        
        $result.Add([PSCustomObject]@{
            RelativePath = $rel
            FullPath     = $file.FullName
            LastWrite    = $file.LastWriteTimeUtc
            Length       = $file.Length
            Hash         = $hash
        })
    }
    $md5.Dispose()
    return $result
}
```

**Comparison with Bash version:**

| Aspect | Bash | PowerShell |
|--------|------|-----------|
| File discovery | `find -type f` | `Get-ChildItem -Recurse -File` |
| Hashing | Batched `find -exec md5sum {} +` | Single `[System.Security.Cryptography.MD5]::Create()` instance |
| Stat info | Batched `find -printf` or `stat` | Built into `FileInfo` object |
| Output format | TSV strings | `PSCustomObject` stored in `List[PSCustomObject]` |
| Performance | ~4 forks total | Fast native .NET cryptography + O(1) list appends |

The PowerShell version uses raw .NET for `MD5` hashing and generic `List` types, drastically outperforming iterative `Get-FileHash` and array concatenation (`+=`).

---

## Folder Comparison: `Compare-Folders` (Lines 121–175)

```powershell
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
            # ONLY_IN_SOURCE
        }
        elseif ((-not $inSource) -and $inTarget) {
            # ONLY_IN_TARGET
        }
        else {
            # Compare hashes
            if ($s.Hash -ne $t.Hash) {
                # MODIFIED (determine which is newer by LastWrite)
            }
        }
    }
    return $results
}
```

**Algorithm:** Builds two hashtables (key = relative path), unions the keys, then classifies each key.

The output is an array of `PSCustomObject` with properties:
- `RelativePath`
- `Status` (`ONLY_IN_SOURCE` | `ONLY_IN_TARGET` | `MODIFIED`)
- `Detail`
- `SourceFile` / `TargetFile` (the original metadata objects)

---

## Sync Engine: `Invoke-SyncFolder` (Lines 177–237)

```powershell
function Invoke-SyncFolder {
    param(
        [string]$sourceDir,
        [string]$targetDir,
        [string]$folderName,
        [bool]$isDryRun
    )
    # 1. Skip if source doesn't exist
    # 2. Run Compare-Folders
    # 3. Split into toCopy and toDelete (only-in-target)
    # 4. Display changes
    # 5. If dry-run → return early
    # 6. Create backup (Copy-Item -Recurse)
    # 7. Copy each changed file (Copy-Item -Force)
    # 8. Return @{ Copied = $copiedCount; Skipped = $false }
}
```

Returns a hashtable `@{ Copied = N; Skipped = $bool }` for the caller to aggregate.

---

## Action Blocks

### Init Block (Lines 242–290)

```powershell
if ($Action -eq "init") {
    $newPath = Read-Host "  Enter the path to your golden source directory"
    # Validate, create if needed, show folder inventory
    Set-Content -Path $configFile -Value $newPath -Encoding UTF8
    exit 0
}
```

### Validation Block (Lines 292–312)

Before any action (except init), validates:
1. Golden source is configured and exists
2. Project path exists and resolves to an absolute path

### Push Block (Lines 317–383)

```powershell
if ($Action -eq "push") {
    # 1. Compute diffs per folder, tag each diff with folder name
    # 2. Show per-folder summary
    # 3. If --dry-run → show details, exit
    # 4. If not --force → prompt
    # 5. Invoke-SyncFolder for each folder
    # 6. Report total
}
```

**Diff caching difference:** Unlike Bash (which uses an associative array `cached_diffs`), PowerShell adds a `Folder` property to each diff object via `Add-Member`, then filters by folder name later. The compare operation still happens once per folder.

### Pull Block (Lines 388–452)

Mirror of push with reversed source/target directions.

### Diff Block (Lines 457–513)

```powershell
elseif ($Action -eq "diff") {
    foreach ($folder in $SYNC_FOLDERS) {
        # Check existence, compare, display with color-coded icons
    }
}
```

Uses the same `[+]`, `[-]`, `[~]` icon convention with color mapping:
```powershell
if ($d.Status -eq "ONLY_IN_SOURCE") { $icon = "+"; $color = "Green" }
elseif ($d.Status -eq "ONLY_IN_TARGET") { $icon = "-"; $color = "Red" }
elseif ($d.Status -eq "MODIFIED") { $icon = "~"; $color = "Yellow" }
```

### Status Block (Lines 518–578)

Displays per-folder and grand-total metrics:
- In sync (identical files)
- Only in Golden
- Only in Project
- Modified

### Backup Management (Lines 647–835)

The script includes commands for managing the temporary backups it creates:
- **`backups`**: Uses `Get-ChildItem -Path $backupDir -Directory -Filter "gh-sync-backup-*"` to sort and index available backups.
- **`restore`**: Connects indexes to target paths, verifies destination logic, handles `--latest`, and executes an overwrite recovery using `Copy-Item -Recurse`.
- **`clean`**: Validates whether to keep `N` backups or `--all` of them, confirms unless `--force` is used, and then calls `Remove-Item` on outdated ones.

---

## Key Differences from Bash

| Feature | Bash (`gh-sync.sh`) | PowerShell (`gh-sync.ps1`) |
|---------|---------------------|---------------------------|
| **Error handling** | `set -Eeuo pipefail` + traps | PowerShell's built-in `ErrorAction` |
| **Temp dir management** | Registered array + EXIT trap | PowerShell handles temp via `[System.IO.Path]::GetTempPath()` |
| **File collection** | Batched `find + md5sum + stat + awk` (4 forks) | Per-file `Get-ChildItem + [System.Security.Cryptography.MD5]` |
| **Comparison** | `comm` + `join` (Unix set operations) | Hashtable lookup in PowerShell |
| **Path handling** | `normalize_path()` for backslashes | Native Windows paths |
| **Config file parsing** | Bash string + jq string evaluation | Native `ConvertFrom-Json` to object |
| **Argument parsing** | Manual `while/case` loop | `CmdletBinding` + `param()` |
| **Line count** | ~1400 lines | ~835 lines |

The PowerShell version relies heavily on .NET objects, bringing extreme performance benefits to file processing while side-stepping the sub-process text manipulation required in the Bash approach.
