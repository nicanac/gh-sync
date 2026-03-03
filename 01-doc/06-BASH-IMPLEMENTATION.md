# 06 — Bash Implementation Deep Dive

Complete technical breakdown of `gh-sync.sh` — the primary implementation (~950 lines).

---

## Script Header & Safety

```bash
#!/bin/bash
set -Eeuo pipefail
```

| Flag | Effect |
|------|--------|
| `-E` | ERR traps are inherited by functions, subshells, and command substitutions |
| `-e` | Exit immediately on any command failure |
| `-u` | Treat unset variables as errors |
| `-o pipefail` | Return the exit code of the first failing pipe command, not the last |

This is the **strictest** Bash error mode. Any unhandled error terminates the script immediately.

---

## Constants (Lines 19–22)

```bash
readonly SYNC_FOLDERS=(".github" ".agent" ".agents" ".claude")
readonly CONFIG_FILE="${HOME}/.gh-sync-config"
readonly VERSION="1.0.0"
```

- `SYNC_FOLDERS` — Array of four folder names to synchronize
- `CONFIG_FILE` — Path to the persistent config storing the golden source path
- `VERSION` — Displayed by `--version` and in the `--help` output

---

## Logging System (Lines 29–44)

Color-coded output helpers using ANSI escape sequences:

| Function | Prefix | Color | Output |
|----------|--------|-------|--------|
| `write_header()` | `=== ... ===` | Cyan | Section headers |
| `write_ok()` | `[OK]` | Green | Success messages |
| `write_warn()` | `[!!]` | Yellow | Warnings |
| `write_err()` | `[ERR]` | Red | Errors (→ stderr) |
| `write_info()` | `->` | Gray | Informational |
| `write_colored()` | — | Custom | Arbitrary color + message |

All error output goes to `stderr` (`>&2`), keeping `stdout` clean for piping.

---

## Cleanup & Error Traps (Lines 46–67)

### Temp Dir Registry

```bash
_TEMP_DIRS=()

register_temp_dir() { _TEMP_DIRS+=("$1"); }

cleanup() {
    for _d in "${_TEMP_DIRS[@]}"; do
        [[ -d "$_d" ]] && rm -rf -- "$_d"
    done
    _TEMP_DIRS=()
}
```

Every time a function creates a temp directory (via `mktemp -d`), it registers it. The `EXIT` trap calls `cleanup()` to remove all registered temp dirs.

### Why Not One Global Temp Dir?

The `ERR` trap could fire inside a nested function, and if `cleanup()` deleted a temp dir that an outer function was still using, it would cascade into more errors. The comment in the code explicitly warns:

> "Do NOT call cleanup here — let the EXIT trap handle it."

### Traps

```bash
trap cleanup EXIT   # Always runs, even on success
trap on_error ERR   # Reports error location (line number)
```

---

## Argument Parser (Lines 110–185)

The `parse_args()` function processes all command-line arguments:

```bash
parse_args() {
    ACTION="$1"
    shift

    case "$ACTION" in
        push|pull|diff|status|init) ;;     # Valid actions
        -h|--help) usage 0 ;;
        -v|--version) echo "gh-sync ${VERSION}"; exit 0 ;;
        *) write_err "Unknown action: $ACTION"; usage 1 ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)   DRY_RUN=true; shift ;;
            --force)     FORCE=true; shift ;;
            --exclude)   IFS=',' read -ra EXCLUDE_PATTERNS <<< "$2"; shift 2 ;;
            --exclude=*) IFS=',' read -ra EXCLUDE_PATTERNS <<< "${1#*=}"; shift ;;
            --only)      IFS=',' read -ra ONLY_FOLDERS <<< "$2"; shift 2 ;;
            --only=*)    IFS=',' read -ra ONLY_FOLDERS <<< "${1#*=}"; shift ;;
            --latest)    LATEST=true; shift ;;
            --all)       ALL=true; shift ;;
            --keep)      KEEP="$2"; shift 2 ;;
            --keep=*)    KEEP="${1#*=}"; shift ;;
            -*)          write_err "Unknown option: $1"; usage 1 ;;
            *)           PROJECT_PATH="$1"; shift ;;  # Positional arg
        esac
    done

    # Default project path to current directory
    [[ -z "$PROJECT_PATH" ]] && PROJECT_PATH="$(pwd)"
}
```

**Key design decisions:**
- First positional argument is always the action
- Second positional argument (optional) is the project path
- `--exclude`, `--only`, and `--keep` support both value syntax (space and `=`)
- Comma-separated patterns and folder lists are split into arrays via `IFS=','`
- New `--latest` and `--all` boolean flags for backup management

---

## Configuration File Loading

The `load_project_config()` function checks for `.gh-sync.json` in the target project.

```bash
load_project_config() {
    local config_file="$1/.gh-sync.json"
    [[ ! -f "$config_file" ]] && return

    # Uses a python command or jq fallback
    # ...
}
```

This allows projects to define `exclude` patterns, `only` folder selections, and a customized `golden_source` without requiring CLI parameters. CLI flags still override these values.

---

## Golden Source Resolution (Lines 188–207)

```bash
get_golden_source() {
    # 1. Environment variable (highest priority)
    if [[ -n "${GH_SYNC_SOURCE:-}" ]]; then
        normalize_path "$GH_SYNC_SOURCE"
        return
    fi

    # 2. Config file
    if [[ -f "$CONFIG_FILE" ]]; then
        local path
        path="$(head -1 "$CONFIG_FILE" | tr -d '[:space:]')"
        path="$(normalize_path "$path")"
        if [[ -n "$path" && -d "$path" ]]; then
            echo "$path"
            return
        fi
    fi

    echo ""
}
```

**Notes:**
- `${GH_SYNC_SOURCE:-}` prevents unset-variable errors under `set -u`
- Config file is read with `head -1` (only first line matters)
- All paths are normalized (backslashes → forward slashes)
- An empty string return is explicitly handled by the caller

---

## Hash Detection (Lines 230–239)

```bash
if command -v md5sum &>/dev/null; then
    _HASH_CMD="md5sum"
elif command -v md5 &>/dev/null; then
    _HASH_CMD="md5"
elif command -v shasum &>/dev/null; then
    _HASH_CMD="shasum"
else
    write_err "No hash command found"
    exit 1
fi
```

This runs once at script startup, not per-file. The detected command is stored in a global variable and used throughout.

---

## File Collection: `get_all_files()` (Lines 250–339)

This is the **performance-critical** function. It collects metadata for all files in a directory using batched operations.

### Step 1: Batch Hash (Lines 258–269)

```bash
case "$_HASH_CMD" in
    md5sum)
        find "$folder" -type f -exec md5sum -- {} + > "$tmp_work/hashes.raw" ;;
    md5)
        find "$folder" -type f -exec md5 -r -- {} + > "$tmp_work/hashes.raw" ;;
    shasum)
        find "$folder" -type f -exec shasum -a 256 -- {} + > "$tmp_work/hashes.raw" ;;
esac
```

The `+` terminator (instead of `\;`) tells `find` to batch multiple file arguments into a single command invocation. This is dramatically faster.

### Step 2: Batch Stat (Lines 273–280)

```bash
if [[ "$_IS_DARWIN" == "true" ]]; then
    # macOS: stat -f with pipe-delimited format
    find "$folder" -type f -exec stat -f '%m|%z|%N' {} +
else
    # GNU: find's built-in -printf (ZERO extra subprocesses)
    find "$folder" -type f -printf '%T@|%s|%p\n'
fi
```

On GNU/Linux, `find -printf` is a **built-in** that requires zero subprocess forks. On macOS (Darwin), `stat -f` is used with a pipe-delimited format.

### Step 3: AWK Merge (Lines 282–326)

A single `awk` invocation reads both files and produces the merged output:

```bash
AWK_BASE="$folder" awk '
BEGIN { base = ENVIRON["AWK_BASE"] }
# Pass 1: Build hash lookup table from hashes.raw
NR == FNR {
    hash = $1
    sub(/^[^ ]+ +\*?/, "")  # Remove hash + spaces + optional binary marker
    hashes[$0] = hash
    next
}
# Pass 2: Read stats.raw, join with hashes, output TSV
{
    # Parse pipe-delimited: MTIME|SIZE|FILEPATH
    n = index($0, "|")
    mtime = substr($0, 1, n-1)
    rest = substr($0, n+1)
    n2 = index(rest, "|")
    size = substr(rest, 1, n2-1)
    filepath = substr(rest, n2+1)

    # Compute relative path
    rel = filepath
    idx = index(rel, base)
    if (idx == 1) {
        rel = substr(rel, length(base) + 1)
        sub(/^\//, "", rel)
    }

    h = hashes[filepath]
    if (h == "") h = "unknown"

    printf "%s\t%s\t%s\t%s\t%s\n", rel, filepath, mtime, size, h
}
' "$tmp_work/hashes.raw" "$tmp_work/stats.raw"
```

**Key technique:** `ENVIRON["AWK_BASE"]` is used instead of `-v base="$folder"` because awk's `-v` flag interprets backslash sequences in the value string. On Windows paths like `C:\Users`, `\U` would be interpreted as an escape sequence, corrupting the path.

### Step 4: Exclusion Filter (Lines 328–336)

After the merge, exclusion patterns are applied in pure Bash (no forks):

```bash
if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
    while IFS=$'\t' read -r rel rest; do
        should_exclude "$rel" && continue
        printf '%s\t%s\n' "$rel" "$rest"
    done < "$tmp_work/merged.tsv"
else
    cat "$tmp_work/merged.tsv"
fi
```

---

## Folder Comparison: `compare_folders()` (Lines 346–403)

Uses Unix `comm` for O(n) set operations:

```bash
# Sorted key files
awk -F'\t' '{print $1}' source.tsv | sort > sk.txt
awk -F'\t' '{print $1}' target.tsv | sort > tk.txt

# Set operations
comm -23 sk.txt tk.txt  →  ONLY_IN_SOURCE  (in source, not in target)
comm -13 sk.txt tk.txt  →  ONLY_IN_TARGET  (in target, not in source)

# Intersection: join by key, compare hash + mtime
join -t$'\t' -j1 s_kh.tsv t_kh.tsv > joined.tsv
# Read joined.tsv: if s_hash != t_hash → MODIFIED
```

Output format: `STATUS\tRELATIVE_PATH\tDETAIL` (tab-separated)

---

## Sync Engine: `sync_folder()` (Lines 408–495)

This function:
1. Receives pre-computed diffs (cached, not recomputed)
2. Splits diffs into `to_copy` (ONLY_IN_SOURCE + MODIFIED) and `only_target` (ONLY_IN_TARGET)
3. Displays what will be copied and what will be kept
4. In dry-run mode: exits without changes
5. Creates a timestamped backup of the target folder
6. Copies each file, creating directories as needed
7. Returns the copy count via `stdout` (all display output goes to `stderr`)

### Diff Caching

The `do_push()` and `do_pull()` functions compute diffs **once** and cache them in an associative array:

```bash
declare -A cached_diffs
for folder in "${SYNC_FOLDERS[@]}"; do
    diffs="$(compare_folders "$src" "$tgt" "Golden" "Project")"
    cached_diffs["$folder"]="$diffs"
done
```

The cached diffs are then passed to `sync_folder()` as parameter `$5`, avoiding recomputation.

---

## Action Functions

### `do_init()` (Lines 510–580)

1. Shows current golden source (if any)
2. Prompts for a new path
3. Trims whitespace and quotes from input
4. Expands tilde (`~`) to `$HOME`
5. Offers to create the directory if it doesn't exist
6. Resolves to absolute path via `cd ... && pwd -P`
7. Shows which sync folders exist and their file counts
8. Saves to `~/.gh-sync-config`

### `do_push()` (Lines 585–663)

1. Computes diffs (golden → project) for each folder, caching results
2. Shows a summary of total changes
3. If `--dry-run`: shows details, exits
4. If not `--force`: prompts for confirmation
5. Calls `sync_folder()` for each folder with cached diffs
6. Reports grand total

### `do_pull()` (Lines 668–744)

Mirror of `do_push()` with reversed source/target:
- Source = project directory
- Target = golden source

### `do_diff()` (Lines 749–816)

For each folder:
1. Checks if source/target exist
2. Runs `compare_folders()`
3. Displays per-file results with colored icons
4. Shows grand total

### `do_status()`

For each folder:
1. Skips if filtered out by `--only`
2. Runs `compare_folders()`
3. Counts: identical, only-in-golden, only-in-project, modified
4. Displays per-folder breakdown
5. Computes and shows grand totals

### `do_backups()`, `do_restore()`, `do_clean()`

These functions manage the timestamped `gh-sync-backup-*` directories created by changes.
- `do_backups()` uses `ls -td "$TMPDIR"/gh-sync-backup-*` to sort and index backups.
- `do_restore()` confirms with the user, handles `--latest`, and executes an `rm` + `cp` to recover state.
- `do_clean()` honors `--all` or `--keep N` and deletes the excess backup directories.

---

## Main Entry Point (Lines 905–949)

```bash
main() {
    parse_args "$@"

    if [[ "$ACTION" == "init" ]]; then
        do_init
        exit 0
    fi

    golden_source="$(get_golden_source)"
    # Validate golden source exists...

    PROJECT_PATH="$(normalize_path "$PROJECT_PATH")"
    # Validate project path exists...

    project_root="$(cd "$PROJECT_PATH" && pwd -P)"

        push)    do_push    "$golden_source" "$project_root" ;;
        pull)    do_pull    "$golden_source" "$project_root" ;;
        diff)    do_diff    "$golden_source" "$project_root" ;;
        status)  do_status  "$golden_source" "$project_root" ;;
        backups) do_backups "$project_root" ;;
        restore) do_restore "$project_root" ;;
        clean)   do_clean ;;
    esac
}

main "$@"
```

The `init` action is handled separately because it doesn't require the golden source to already exist.
