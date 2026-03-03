# 05 — CLI Reference

Complete command-line reference for the `gh-sync` tool.

---

## Synopsis

```
gh-sync <action> [project_path] [options]
```

---

## Actions

### `gh-sync init`

Configure the golden source directory path.

```bash
gh-sync init
```

**Interactive prompts:**
1. Asks for the path to your golden source directory
2. Shows which sync folders (`.github`, `.agent`, `.agents`, `.claude`) exist and their file counts
3. Saves the path to `~/.gh-sync-config`

**Notes:**
- Run this once before using any other command
- If the path doesn't exist, it offers to create it
- Tilde expansion (`~`) is supported
- Alternative: Set the `GH_SYNC_SOURCE` environment variable instead

---

### `gh-sync push [project_path]`

Copy files from the golden source → project directory.

```bash
# Push to current directory
gh-sync push

# Push to a specific project
gh-sync push ~/projects/my-app

# Push with options
gh-sync push --dry-run
gh-sync push --force
gh-sync push --exclude "*.log,temp/*"
gh-sync push --only .github
```

**Behavior:**
1. Compares each sync folder (golden vs project)
2. Shows a summary of changes per folder
3. Prompts for confirmation (unless `--force`)
4. Creates a timestamped backup of each target folder
5. Copies new and modified files from golden → project
6. Reports per-folder and total files synced

**What gets copied:**
- Files only in golden source → **copied** to project
- Files modified (different hash) → **overwritten** in project
- Files only in project → **kept** (flagged, not deleted)

---

### `gh-sync pull [project_path]`

Copy files from project directory → golden source.

```bash
# Pull from current directory
gh-sync pull

# Pull from a specific project
gh-sync pull ~/projects/my-app
```

**Behavior:**
Same as `push` but with reversed direction:
- Source = project directory
- Target = golden source

Use this when you've made improvements to AI configs in a specific project and want to propagate them back to the golden source.

---

### `gh-sync diff [project_path]`

Show file-by-file differences between golden source and project.

```bash
gh-sync diff
gh-sync diff ~/projects/my-app
```

**Output:**
```
=== DIFF: Golden Source <-> Project ===
  ->  Golden:  /home/user/golden-source
  ->  Project: /home/user/projects/my-app

  --- .github ---
  [+] agents/new-agent.md
      Only in Golden
  [-] prompts/old-prompt.md
      Only in Project
  [~] agents/speckit.analyze.agent.md
      Different (newer in Golden)

  --- .agents ---
  [OK] In sync

  [!!] 3 total difference(s) found.
```

**Legend:**

| Symbol | Color | Meaning |
|--------|-------|---------|
| `[+]` | 🟢 Green | File only in golden source (would be copied on push) |
| `[-]` | 🔴 Red | File only in project (kept, never deleted) |
| `[~]` | 🟡 Yellow | File exists in both but content differs |

---

### `gh-sync status [project_path]`

Quick overview of sync state per folder with totals.

```bash
gh-sync status
gh-sync status ~/projects/my-app
```

**Output:**
```
=== STATUS: Sync Overview ===
  ->  Golden:  /home/user/golden-source
  ->  Project: /home/user/projects/my-app

  --- .github ---
    In sync:         18
    Only in Golden:  2
    Only in Project: 1
    Modified:        3

  --- .agents ---
    In sync:         65
    Only in Golden:  0
    Only in Project: 0
    Modified:        0

  === TOTAL ===
    In sync:         83 files
    Only in Golden:  2 files
    Only in Project: 1 files
    Modified:        3 files
```

---

### `gh-sync backups`

List all available backups in the temporary directory.

```bash
gh-sync backups
```

**Output:**
Displays numbered backups sorted by date (most recent first) with the folder name, timestamp, path, and file count.

---

### `gh-sync restore`

Restore files from a previous backup. 

```bash
# Restore specific backup by ID
gh-sync restore 1

# Restore the most recent backup for a specific folder
gh-sync restore .github --latest

# Restore without confirming
gh-sync restore 1 --force
```

**Behavior:**
1. Verifies the backup exists.
2. Prompts before overwrite unless `--force` is used.
3. Copies all files from the backup directory back to the specific project target directory, overwriting current files.

---

### `gh-sync clean`

Remove old automatic backups from the temporary directory.

```bash
# Keep only the last 5 backups total
gh-sync clean --keep 5

# Remove all backups
gh-sync clean --all
```

**Behavior:**
1. Requires either `--keep` or `--all`.
2. Asks for confirmation before deletion unless `--force` is supplied.
3. Removes the specified number of older backup directories.

---

## Options

### `--dry-run`

Preview changes without modifying any files. Works with `push` and `pull`.

```bash
gh-sync push --dry-run
gh-sync pull --dry-run
```

When active, the tool:
- Shows what would be copied
- Shows what would be skipped
- Does NOT create backups
- Does NOT write any files
- Displays a warning: "Dry-run mode -- no files were changed."

---

### `--force`

Skip the "Proceed? [y/N]" confirmation prompt. Useful for scripting and CI.

```bash
gh-sync push --force
gh-sync pull --force
```

---

### `--exclude pat1,pat2`

Exclude files matching glob patterns (comma-separated). Patterns are matched against **relative paths** within each sync folder.

```bash
# Single pattern
gh-sync push --exclude "*.log"

# Multiple patterns (comma-separated)
gh-sync push --exclude "*.log,*.tmp,node_modules/*"

# Also supports = syntax
gh-sync push --exclude="*.log,temp/*"
```

**Pattern examples:**

| Pattern | Matches |
|---------|---------|
| `*.log` | All `.log` files |
| `temp/*` | Everything inside `temp/` subdirectory |
| `*.md` | All Markdown files |
| `agents/*.bak` | Backup files in the `agents/` subfolder |

---

### `--only folder1,folder2`

Sync only specified folders instead of all supported folders (comma-separated). The values must match one or more of `.github`, `.agent`, `.agents`, or `.claude`.

```bash
# Sync only .github
gh-sync push --only .github

# Sync multiple specific folders
gh-sync push --only .github,.agents
```

---

### `-h`, `--help`

Show the help message with usage summary.

```bash
gh-sync --help
gh-sync -h
```

---

### `-v`, `--version`

Show the current version.

```bash
gh-sync --version
gh-sync -v
# Output: gh-sync 1.0.0
```

---

## Project Path

The optional `project_path` argument specifies the target project directory:

```bash
# Uses current directory (default)
gh-sync push

# Explicit project path
gh-sync push /path/to/project

# Relative path works too
gh-sync push ../other-project
```

If not provided, defaults to `$(pwd)` (Bash) or `Get-Location` (PowerShell).

---

## Configuration Priority

The golden source path is resolved in this order:

| Priority | Source | Example |
|----------|--------|---------|
| 1 (highest) | `$GH_SYNC_SOURCE` env var | `export GH_SYNC_SOURCE=~/golden` |
| 2 | `~/.gh-sync-config` file | Set via `gh-sync init` |

If neither is set, the tool exits with an error asking you to run `gh-sync init`.

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success (or user aborted gracefully) |
| `1` | Error (missing config, invalid path, missing hash command) |
| Non-zero | Unexpected error (trapped by `set -Eeuo pipefail`) |

---

## PowerShell-Specific Notes

On Windows, the same commands work but use PowerShell parameter syntax:

```powershell
# PowerShell native parameters
gh-sync push -DryRun
gh-sync push -Force
gh-sync push -Exclude "*.log","*.tmp"
gh-sync push C:\Projects\MyApp -DryRun -Force

# CMD wrapper (passes args to PowerShell)
gh-sync.cmd push --dry-run
```

The `.cmd` wrapper translates standard CLI flags to PowerShell parameters internally via `%*` argument forwarding.

---

## Configuration File

Projects can have a `.gh-sync.json` file placed in their root to define default arguments. For more information, see `04-CORE-CONCEPTS.md`.
