# 04 — Core Concepts

This document explains the fundamental concepts behind gh-sync. Understanding these will make the code and behavior intuitive.

---

## 1. Golden Source

The **golden source** is a single directory on your machine that serves as the **single source of truth** for all your AI configuration files.

### What It Contains

The golden source directory has up to four subfolders:

```
~/my-golden-source/
├── .github/    →  GitHub Copilot agents, skills, memory bank, instructions
├── .agent/     →  VS Code agent rules, skills, workflows
├── .agents/    →  Additional shared agent skills
└── .claude/    →  Claude Code skills and configuration
```

### How It's Configured

The golden source path is stored in one of two places (checked in this order):

1. **Environment variable** `GH_SYNC_SOURCE` — highest priority
2. **Project config file** `.gh-sync.json` — in the project root
3. **Global config file** `~/.gh-sync-config` — set via `gh-sync init`

The config file is a single-line text file containing the absolute path:

```
/home/user/ai-config-hub
```

### Why Not Git Submodules?

Git submodules could solve a similar problem, but:
- They require all projects to be Git repos
- They introduce complex merge/update workflows
- They can't handle partial syncs (per-folder)
- They don't support exclusion patterns or dry-run previews
- gh-sync works with any directory, Git or not

---

## 2. Sync Folders

gh-sync operates on exactly **four folder names**. These are hardcoded as constants:

```bash
# Bash
readonly SYNC_FOLDERS=(".github" ".agent" ".agents" ".claude")

# PowerShell
$SYNC_FOLDERS = @(".github", ".agent", ".agents", ".claude")
```

### Per-Folder Independence

Each folder is synced independently. This means:
- By default, all four folders are processed in sequence.
- Users can filter which folders are synced using the `--only f1,f2` flag (e.g. `--only .github,.agents`).
- If `.github/` exists in the golden source but `.claude/` doesn't, only `.github/` is synced
- Folders not present in the golden source are silently skipped
- Folders not present in the project target are created on `push`
- All reporting (diff, status) is broken down per folder with a grand total

### Why These Four?

| Folder | AI Tool | Convention |
|--------|---------|------------|
| `.github/` | GitHub Copilot | Standard GitHub convention for Copilot agents, instructions, and memory banks |
| `.agent/` | VS Code Agent | VS Code extension convention for agent rules and skills |
| `.agents/` | Cross-platform agents | Additional skill libraries shared across multiple tools |
| `.claude/` | Claude Code | Anthropic's Claude Code extension skill convention |

---

## 3. Hash-Based Comparison

gh-sync determines if a file has changed by comparing **content hashes**, not just timestamps or file sizes.

### Hash Command Detection

At startup, the script detects the available hash command (checked in order):

```bash
if command -v md5sum &>/dev/null; then
    _HASH_CMD="md5sum"
elif command -v md5 &>/dev/null; then
    _HASH_CMD="md5"
elif command -v shasum &>/dev/null; then
    _HASH_CMD="shasum"
```

| Platform | Typical Hash Command |
|----------|---------------------|
| Linux | `md5sum` |
| macOS | `md5` (BSD) or `shasum` |
| Windows (Git Bash) | `md5sum` (from coreutils) |
| Windows (PowerShell) | `Get-FileHash -Algorithm MD5` |

### Why Hashes, Not Timestamps?

Timestamps can lie:
- Copying a file may update its `mtime` to "now" even though the content is unchanged
- Git operations (checkout, rebase) may reset timestamps
- Timezone differences across machines can cause false positives

By comparing MD5/SHA hashes, gh-sync accurately detects **actual content changes**.

### Timestamp as Tiebreaker

When a file IS modified (hash mismatch), the modification time (`mtime`) is used to determine **which side is newer**. The diff output says "newer in Golden" or "newer in Project" accordingly.

---

## 4. File Collection Pipeline

The Bash implementation uses a highly optimized, **batched** file collection strategy. Instead of spawning subprocesses per file (which is slow on large folder trees), it uses a 3-step pipeline:

### Step 1: Batch Hash

One single `find ... -exec md5sum {} +` call hashes ALL files in the directory. The `+` terminator makes `find` batch arguments, so only 1–2 subprocess forks happen regardless of file count.

### Step 2: Batch Stat

One single `find ... -printf '%T@|%s|%p\n'` call (GNU) or `find ... -exec stat -f '%m|%z|%N' {} +` (macOS) gets modification time and file size for ALL files.

### Step 3: Merge with AWK

A single `awk` invocation merges the hash and stat data by filepath, computing relative paths and outputting a clean TSV:

```
RELATIVE_PATH\tFULL_PATH\tMTIME_EPOCH\tSIZE\tHASH
```

### Performance Impact

| Approach | Subprocesses for 1000 files |
|----------|----------------------------|
| Per-file hash/stat (naive) | ~3000 forks |
| Batched pipeline (gh-sync) | ~4 forks total |

This makes gh-sync performant even on large config directories with hundreds of files.

---

## 5. Folder Comparison

Once file metadata is collected for both source and target, the comparison uses Unix set operations:

```bash
# Extract sorted file keys
awk '{print $1}' source.tsv | sort > sk.txt
awk '{print $1}' target.tsv | sort > tk.txt

# Files only in source (to be pushed)
comm -23 sk.txt tk.txt → ONLY_IN_SOURCE

# Files only in target (project-specific, not deleted)
comm -13 sk.txt tk.txt → ONLY_IN_TARGET

# Files in both: join by key, compare hashes
join sk.txt tk.txt → check hash equality → MODIFIED
```

### Comparison Results

| Status | Meaning | Push Action | Pull Action |
|--------|---------|-------------|-------------|
| `ONLY_IN_SOURCE` | File exists in source but not target | **Copied to target** | **Copied to target** |
| `ONLY_IN_TARGET` | File exists in target but not source | Flagged ⚠️, **never deleted** | Flagged ⚠️, **never deleted** |
| `MODIFIED` | File exists in both but content differs | **Overwritten** (source wins) | **Overwritten** (source wins) |

> **Key safety guarantee:** gh-sync **never deletes files**. Files only in the target are flagged but preserved.

---

## 6. Backup Strategy

Before any sync operation modifies the target, gh-sync creates a full backup:

```bash
# Bash
backup_dir="$(mktemp -d "${TMPDIR:-/tmp}/gh-sync-backup-${folder}-${timestamp}.XXXXXX")"
cp -a "$target_dir/." "$backup_dir/"
```

```powershell
# PowerShell
$backupDir = Join-Path ([System.IO.Path]::GetTempPath()) "gh-sync-backup-$folderName-$timestamp"
Copy-Item -Path $targetDir -Destination $backupDir -Recurse -Force
```

### Backup Location

| Platform | Backup Path |
|----------|-------------|
| Linux | `/tmp/gh-sync-backup-github-20260303-094117.XXXXXX/` |
| macOS | `$TMPDIR/gh-sync-backup-github-20260303-094117.XXXXXX/` |
| Windows | `%TEMP%\gh-sync-backup-.github-20260303-094117\` |

### Managing Backups

Unlike manual temporary files, `gh-sync` provides built-in commands to list, restore, and clear these backups:

- **`gh-sync backups`**: Lists the available backups found in the temp directory.
- **`gh-sync restore [num/folder]`**: Restores the previously stored contents to the target directory. Add `--latest` to restore the last backup for a given folder.
- **`gh-sync clean --keep N`**: Keeps the specified number of the most recent backups per folder and deletes the rest.

### Backup Properties

- **One per sync folder** — `.github`, `.agent`, `.agents`, `.claude` each get their own backup
- **Timestamped** — Format: `YYYYMMDD-HHMMSS`
- **Temporary** — Stored in the OS temp directory, cleaned up automatically by OS policies over time or manually with `gh-sync clean`
- **Full copy** — The entire target folder is backed up, not just changed files
- **Only on actual writes** — Dry-run mode does NOT create backups

---

## 7. Safety Mechanisms

gh-sync implements multiple layers of safety:

### 1. Confirmation Prompt

By default, push and pull operations require explicit user confirmation:

```
  Proceed with PUSH? [y/N]
```

Skippable with `--force` for scripting/CI use.

### 2. Dry-Run Mode

`--dry-run` shows exactly what would happen without writing any files:

```bash
gh-sync push --dry-run
```

### 3. Non-Destructive Default

Files only in the target are **never deleted**, only flagged:

```
  [!!] extra-file.md     # Flagged but left alone
```

### 4. Error Traps (Bash)

```bash
set -Eeuo pipefail     # Exit on error, undefined vars, pipe failures
trap cleanup EXIT      # Always clean up temp files
trap on_error ERR      # Report error location
```

### 5. Temp Dir Registry

The bash script maintains an array (`_TEMP_DIRS`) of all temporary directories. The `EXIT` trap ensures all are cleaned up, even if the script crashes.

---

## 8. Exclusion Patterns

Users can exclude files from sync using glob patterns:

```bash
gh-sync push --exclude "*.log,node_modules/*,*.tmp"
```

### How It Works

```bash
# Bash: pattern matching using case statement
should_exclude() {
    local rel_path="$1"
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        case "$rel_path" in
            $pattern) return 0 ;;  # Match found, exclude
        esac
    done
    return 1  # No match, include
}
```

```powershell
# PowerShell: -like operator
function Test-ShouldExclude {
    param([string]$relativePath)
    foreach ($pattern in $script:Exclude) {
        if ($relativePath -like $pattern) { return $true }
    }
    return $false
}
```

Patterns are matched against **relative paths** within each sync folder.

---

## 9. Path Normalization

On Windows (Git Bash / MINGW64), paths may contain backslashes. gh-sync normalizes all paths to forward slashes:

```bash
normalize_path() {
    echo "${1//\\//}"
}
```

This prevents issues with awk, find, and other Unix tools that interpret backslashes as escape characters.

**Also critical:** The `awk` merge step uses `ENVIRON["AWK_BASE"]` instead of `-v base="$folder"` to avoid awk interpreting backslashes in Windows paths as escape sequences (e.g., `\U` → unicode escape).

---

## 10. Per-Project Configuration File

To avoid repeating the same command-line flags on every run, gh-sync supports a per-project `.gh-sync.json` configuration file located in the project's root directory.

### Format and Precedence

The file allows configuring default behaviors for a specific project:

```json
{
  "golden_source": "~/alternative-golden-source",
  "exclude": ["*.log", "temp/*"],
  "only": [".github", ".agents"]
}
```

Precedence order (highest to lowest):
1. Command Line Flags (`--only`, `--exclude`)
2. Project-level `.gh-sync.json`
3. Global file `~/.gh-sync-config` / Default settings

This ensures maximum flexibility where a project can define its own default sync rules, but users can still override them ad-hoc via the CLI.
