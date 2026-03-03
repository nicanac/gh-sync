# 10 — Developer Guide

How to contribute to gh-sync, coding conventions, and guidance for extending the tool.

---

## Getting Started as a Contributor

### Clone the Repo

```bash
git clone https://github.com/your-org/gh-sync.git
cd gh-sync
```

### Understand the Structure

There are only **three core files** to understand:

| File | Platform | Lines |
|------|----------|-------|
| `gh-sync.sh` | Bash (Linux/macOS/WSL/Git Bash) | ~950 |
| `gh-sync.ps1` | PowerShell (Windows) | ~579 |
| `gh-sync.cmd` | Windows CMD wrapper | 6 |

Everything else is either an installer or synced content.

### Quick Test Cycle

1. Edit `gh-sync.sh` or `gh-sync.ps1` directly
2. Run without installing:
   ```bash
   # Bash
   bash gh-sync.sh status

   # PowerShell
   .\gh-sync.ps1 status
   ```
3. No build step, no compilation, no dependencies

---

## Coding Conventions

### Bash (`gh-sync.sh`)

| Convention | Example |
|-----------|---------|
| **Strict mode** | `set -Eeuo pipefail` at the top |
| **Function naming** | `snake_case` for helpers, `do_action` for action dispatchers |
| **Constants** | `UPPER_SNAKE_CASE` with `readonly` |
| **Local variables** | Declared with `local` inside functions |
| **Error output** | Always to `stderr` via `>&2` |
| **Return values** | Numeric counts via `stdout`, display via `stderr` |
| **Quoting** | Always double-quote variables: `"$var"` |
| **Temp files** | `mktemp -d` + `register_temp_dir` |
| **Comments** | Section headers with `# ===`, inline with `#` |

### PowerShell (`gh-sync.ps1`)

| Convention | Example |
|-----------|---------|
| **Function naming** | `Verb-Noun` (PowerShell standard) |
| **Parameters** | `CmdletBinding` with `[ValidateSet]` |
| **Output** | `Write-Host` with `-ForegroundColor` |
| **Objects** | `[PSCustomObject]@{}` for structured data |
| **Error handling** | `ErrorAction SilentlyContinue` where appropriate |

### Both Implementations

| Convention | Reason |
|-----------|--------|
| **Feature parity** | Both scripts must support the same commands, options, and output format |
| **Same output format** | Logging prefixes (`[OK]`, `[!!]`, `[ERR]`, `->`) must match |
| **Same diff symbols** | `[+]`, `[-]`, `[~]` with the same color mapping |
| **Non-destructive** | Never delete files in the target — only copy/overwrite |

---

## Adding a New Action

### Step 1: Update Bash

1. Add the action name to the `case` validation in `parse_args()`:
   ```bash
   case "$ACTION" in
       push|pull|diff|status|init|YOUR_ACTION) ;;
   ```

2. Create the action function:
   ```bash
   do_your_action() {
       local golden_source="$1"
       local project_root="$2"
       write_header "YOUR_ACTION: Description"
       # ... implementation ...
   }
   ```

3. Add to the `case` dispatch in `main()`:
   ```bash
   case "$ACTION" in
       push)        do_push "$golden_source" "$project_root" ;;
       your_action) do_your_action "$golden_source" "$project_root" ;;
   esac
   ```

4. Update `usage()` to document the new action.

### Step 2: Update PowerShell

1. Add to `[ValidateSet]`:
   ```powershell
   [ValidateSet("push", "pull", "diff", "status", "init", "your_action")]
   ```

2. Add the `elseif` block:
   ```powershell
   elseif ($Action -eq "your_action") {
       Write-Header "YOUR_ACTION: Description"
       # ... implementation ...
   }
   ```

### Step 3: Update Documentation

- Update `README.md` usage table
- Update `01-doc/05-CLI-REFERENCE.md`

---

## Adding a New Sync Folder

To sync an additional folder (e.g., `.cursor/`):

### Bash

```bash
readonly SYNC_FOLDERS=(".github" ".agent" ".agents" ".claude" ".cursor")
```

### PowerShell

```powershell
$SYNC_FOLDERS = @(".github", ".agent", ".agents", ".claude", ".cursor")
```

That's it — the entire sync pipeline, diff, and status logic is driven by the `SYNC_FOLDERS` array. No other code changes needed.

---

## Adding a New CLI Option

### Bash

1. Add parsing in `parse_args()`:
   ```bash
   --your-flag)
       YOUR_FLAG=true
       shift
       ;;
   ```

2. Declare the default at the top:
   ```bash
   YOUR_FLAG=false
   ```

3. Use it in action functions:
   ```bash
   if [[ "$YOUR_FLAG" == "true" ]]; then ...
   ```

### PowerShell

1. Add to the `param()` block:
   ```powershell
   [switch]$YourFlag
   ```

2. Use it:
   ```powershell
   if ($YourFlag.IsPresent) { ... }
   ```

---

## Performance Considerations

### Bash Critical Path

The performance-critical function is `get_all_files()`. If modifying it:

1. **Keep subprocess count low** — The `find -exec ... +` pattern is essential
2. **Don't add per-file loops** — Use `awk` or `comm` for batch processing
3. **Watch for MINGW64 quirks** — md5sum on Git Bash outputs `HASH *FILEPATH` (note the `*`)
4. **macOS compatibility** — `find -printf` doesn't exist on BSD; use `stat -f` fallback

### PowerShell

The `Get-AllFiles` function uses per-file `Get-FileHash`. For directories with thousands of files, consider:
- Using `[System.Security.Cryptography.MD5]` directly for lower overhead
- Batching with `Get-FileHash` pipeline

---

## Testing Strategies

Since gh-sync is a script without a test framework, testing is done manually:

### Basic Smoke Test

```bash
# Create a golden source with test files
mkdir -p /tmp/golden/.github/agents
echo "test" > /tmp/golden/.github/agents/test.md

# Create a project
mkdir -p /tmp/project

# Set up config
export GH_SYNC_SOURCE=/tmp/golden

# Test each command
bash gh-sync.sh status /tmp/project
bash gh-sync.sh diff /tmp/project
bash gh-sync.sh push /tmp/project --dry-run
bash gh-sync.sh push /tmp/project --force
bash gh-sync.sh status /tmp/project   # Should show "in sync"

# Modify and test pull
echo "modified" > /tmp/project/.github/agents/test.md
bash gh-sync.sh diff /tmp/project      # Should show [~]
bash gh-sync.sh pull /tmp/project --force
```

### Edge Cases to Test

| Scenario | Expected Behavior |
|----------|-------------------|
| Empty golden source | All folders skipped |
| Empty project | All golden files pushed |
| Files only in project | Flagged `[!!]`, never deleted |
| Identical files | Reported "in sync" |
| Spaces in filenames | Handled correctly |
| Windows backslash paths | Normalized to forward slashes |
| Binary file markers (`*`) | Stripped by awk pattern |
| No hash command | Error message + exit 1 |
| Missing config | Error message suggesting `gh-sync init` |

---

## Project Roadmap

Potential future enhancements:

| Feature | Complexity | Impact |
|---------|------------|--------|
| `gh-sync watch` — auto-sync on file changes | Medium | High |
| Git integration — auto-commit after sync | Low | Medium |
| Profile support — multiple golden sources | Medium | Medium |
| Plugin system — custom sync hooks | High | Medium |
| JSON output mode for scripting | Low | Medium |

---

## Code Navigation Quick Reference

### Bash (`gh-sync.sh`) — Key Locations

| Section | Lines | Description |
|---------|-------|-------------|
| Constants | 19–22 | `SYNC_FOLDERS`, `CONFIG_FILE`, `VERSION` |
| Logging | 29–44 | Color-coded output functions |
| Cleanup/Traps | 46–67 | Temp dir registry, EXIT/ERR traps |
| Defaults | 69–74 | Action, paths, flags |
| Usage/Help | 77–108 | Help text |
| Arg Parser | 110–185 | `parse_args()` |
| Golden Source | 188–207 | `get_golden_source()` |
| Helpers | 209–227 | `normalize_path()`, `should_exclude()` |
| Hash Detection | 230–239 | `md5sum`/`md5`/`shasum` |
| File Collection | 250–339 | `get_all_files()` |
| Comparison | 346–403 | `compare_folders()` |
| Sync Engine | 408–495 | `sync_folder()` |
| Init | 549–621 | `do_init()` |
| Push | 664–747 | `do_push()` |
| Pull | 752–833 | `do_pull()` |
| Diff | 838–905 | `do_diff()` |
| Status | 910–1023 | `do_status()` |
| Backups | 1028–1244 | `do_backups()`, `do_restore()`, `do_clean()` |
| Main | 1249–1334 | Entry point, validation, dispatch |

### PowerShell (`gh-sync.ps1`) — Key Locations

| Section | Lines | Description |
|---------|-------|-------------|
| Synopsis/Help | 1–45 | Comment-based help |
| Parameters | 47–61 | CmdletBinding |
| Constants | 64 | `$SYNC_FOLDERS` |
| Golden Source | 67–77 | `Get-GoldenSource` |
| Helpers | 82–99 | Logging, path, exclusion |
| File Collection | 101–119 | `Get-AllFiles` |
| Comparison | 121–175 | `Compare-Folders` |
| Sync Engine | 177–237 | `Invoke-SyncFolder` |
| Init | 250–298 | Init action block |
| Validation | 300–320 | Path/config validation |
| Push | 325–393 | Push action block |
| Pull | 398–466 | Pull action block |
| Diff | 471–529 | Diff action block |
| Status | 534–596 | Status action block |
| Backups | 601–796 | Backups/restore/clean action blocks |
