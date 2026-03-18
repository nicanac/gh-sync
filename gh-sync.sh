#!/bin/bash
set -Eeuo pipefail

# =============================================================================
# gh-sync — Synchronize golden AI config folders to/from any project.
#
# Syncs up to four folders between a single "golden source" directory and
# any number of project directories:
#   .github/   .agent/   .agents/   .claude/
#
# Usage:
#   gh-sync push  [project_path] [--dry-run] [--force] [--exclude pat1,pat2] [--only .github,.agents]
#   gh-sync pull  [project_path] [--dry-run] [--force] [--exclude pat1,pat2] [--only .github,.agents]
#   gh-sync diff  [project_path] [--exclude pat1,pat2] [--only .github,.agents]
#   gh-sync status [project_path] [--exclude pat1,pat2] [--only .github,.agents]
#   gh-sync init
#   gh-sync backups [project_path]
#   gh-sync restore [project_path] [--latest] [--force]
#   gh-sync clean [--keep N] [--all] [--force]
# =============================================================================

# -- Constants ----------------------------------------------------------------
readonly SYNC_FOLDERS=(".github" ".agent" ".agents" ".claude" ".cursor")
readonly CONFIG_FILE="${HOME}/.gh-sync-config"
readonly VERSION="2.1.0"

# -- Script location ----------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT_NAME="$(basename -- "${BASH_SOURCE[0]}")"

# -- Logging ------------------------------------------------------------------
_color_reset="\033[0m"
_color_cyan="\033[36m"
_color_green="\033[32m"
_color_yellow="\033[33m"
_color_red="\033[31m"
_color_gray="\033[90m"
_color_white="\033[97m"
_color_magenta="\033[35m"
_color_dark_yellow="\033[33m"

write_header()  { printf "\n${_color_cyan}=== %s ===${_color_reset}\n" "$1"; }
write_ok()      { printf "  ${_color_green}[OK]${_color_reset} %s\n" "$1"; }
write_warn()    { printf "  ${_color_yellow}[!!]${_color_reset} %s\n" "$1"; }
write_err()     { printf "  ${_color_red}[ERR]${_color_reset} %s\n" "$1" >&2; }
write_info()    { printf "  ${_color_gray}->  %s${_color_reset}\n" "$1"; }
write_colored() { printf "  %b%s%b\n" "$1" "$2" "${_color_reset}"; }

# -- Cleanup / error trap -----------------------------------------------------
# Use an array of temp dirs so nested functions don't cascade-delete each other's
# temp directories when the ERR trap fires.
_TEMP_DIRS=()

register_temp_dir() { _TEMP_DIRS+=("$1"); }

cleanup() {
    for _d in "${_TEMP_DIRS[@]}"; do
        [[ -d "$_d" ]] && rm -rf -- "$_d"
    done
    _TEMP_DIRS=()
}

on_error() {
    write_err "Unexpected error on line ${BASH_LINENO[0]} (exit code $?)"
    # Do NOT call cleanup here — let the EXIT trap handle it.
    # This prevents cascade-deleting a parent function's temp dir.
}

trap cleanup EXIT
trap on_error ERR

# -- Defaults -----------------------------------------------------------------
ACTION=""
PROJECT_PATH=""
DRY_RUN=false
FORCE=false
EXCLUDE_PATTERNS=()
ONLY_FOLDERS=()
KEEP_BACKUPS=5

# -- Usage --------------------------------------------------------------------
usage() {
    cat <<EOF
gh-sync ${VERSION} — AI config folder synchronization

Usage:
  gh-sync <action> [project_path] [options]

Actions:
  push      Copy golden source -> project
  pull      Copy project -> golden source
  diff      Show file-by-file differences per folder
  status    Quick sync overview per folder + totals
  init      Configure the golden source path
  config    Show effective config (or generate a .gh-sync.json template)
  backups   List available backups
  restore   Restore from a backup
  clean     Remove old backups

Options:
  --dry-run             Preview changes without modifying files
  --force               Skip the "Proceed? [y/N]" confirmation prompt
  --exclude pat1,pat2   Exclude files matching patterns (comma-separated)
  --only f1,f2          Sync only specific folders (e.g. --only .github,.agents)
  --keep N              For 'clean': keep last N backups per folder (default: 5)
  --all                 For 'clean': remove all backups
  --latest              For 'restore': restore the most recent backup
  -h, --help            Show this help message
  -v, --version         Show version

Per-Project Config:
  Place a .gh-sync.json in your project root to set defaults:
  {"exclude": ["*.log"], "only": [".github"], "golden_source": "/path"}
  CLI flags override config file values.

Examples:
  gh-sync push
  gh-sync push /path/to/project
  gh-sync push --only .github
  gh-sync push --only .github,.agents --dry-run
  gh-sync diff
  gh-sync push --dry-run
  gh-sync push --force
  gh-sync pull
  gh-sync status
  gh-sync config
  gh-sync config init
  gh-sync backups
  gh-sync restore --latest
  gh-sync clean --keep 3
EOF
    exit "${1:-0}"
}

# -- Argument parsing ---------------------------------------------------------
parse_args() {
    if [[ $# -eq 0 ]]; then
        write_err "No action specified."
        usage 1
    fi

    ACTION="$1"
    shift

    # Validate action
    case "$ACTION" in
        push|pull|diff|status|init|backups|restore|clean|config) ;;
        -h|--help) usage 0 ;;
        -v|--version) echo "gh-sync ${VERSION}"; exit 0 ;;
        *)
            write_err "Unknown action: $ACTION"
            usage 1
            ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --exclude)
                if [[ $# -lt 2 ]]; then
                    write_err "--exclude requires a value"
                    exit 1
                fi
                IFS=',' read -ra EXCLUDE_PATTERNS <<< "$2"
                shift 2
                ;;
            --exclude=*)
                IFS=',' read -ra EXCLUDE_PATTERNS <<< "${1#*=}"
                shift
                ;;
            --only)
                if [[ $# -lt 2 ]]; then
                    write_err "--only requires a value"
                    exit 1
                fi
                IFS=',' read -ra ONLY_FOLDERS <<< "$2"
                shift 2
                ;;
            --only=*)
                IFS=',' read -ra ONLY_FOLDERS <<< "${1#*=}"
                shift
                ;;
            --keep)
                if [[ $# -lt 2 ]]; then
                    write_err "--keep requires a number"
                    exit 1
                fi
                KEEP_BACKUPS="$2"
                shift 2
                ;;
            --keep=*)
                KEEP_BACKUPS="${1#*=}"
                shift
                ;;
            --all)
                KEEP_BACKUPS=0
                shift
                ;;
            --latest)
                LATEST=true
                shift
                ;;
            -h|--help)
                usage 0
                ;;
            -v|--version)
                echo "gh-sync ${VERSION}"
                exit 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                write_err "Unknown option: $1"
                usage 1
                ;;
            *)
                # Positional: project path
                if [[ -z "$PROJECT_PATH" ]]; then
                    PROJECT_PATH="$1"
                else
                    write_err "Unexpected argument: $1"
                    usage 1
                fi
                shift
                ;;
        esac
    done

    # Default project path to current directory
    if [[ -z "$PROJECT_PATH" ]]; then
        PROJECT_PATH="$(pwd)"
    fi
}

# -- Golden source resolution -------------------------------------------------
get_golden_source() {
    # 1. Environment variable
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

# -- Helpers ------------------------------------------------------------------

# Convert Windows backslash paths to forward slashes (essential for MINGW64/Git Bash)
normalize_path() {
    echo "${1//\\//}"
}

# Check if a relative path matches any exclusion pattern
should_exclude() {
    local rel_path="$1"
    local pattern
    for pattern in "${EXCLUDE_PATTERNS[@]+"${EXCLUDE_PATTERNS[@]}"}"; do
        # shellcheck disable=SC2254
        case "$rel_path" in
            $pattern) return 0 ;;
        esac
    done
    return 1
}

# Check if a folder name should be processed (--only filter)
should_process_folder() {
    local folder="$1"
    # If --only is not set, process all folders
    if [[ ${#ONLY_FOLDERS[@]} -eq 0 ]]; then
        return 0
    fi
    local f
    for f in "${ONLY_FOLDERS[@]}"; do
        if [[ "$f" == "$folder" ]]; then
            return 0
        fi
    done
    return 1
}

# Validate --only folder names against SYNC_FOLDERS
validate_only_folders() {
    if [[ ${#ONLY_FOLDERS[@]} -eq 0 ]]; then
        return 0
    fi
    local f valid
    for f in "${ONLY_FOLDERS[@]}"; do
        valid=false
        local sf
        for sf in "${SYNC_FOLDERS[@]}"; do
            if [[ "$f" == "$sf" ]]; then
                valid=true
                break
            fi
        done
        if [[ "$valid" == "false" ]]; then
            write_err "Invalid folder name in --only: '$f'"
            write_err "Valid folders: ${SYNC_FOLDERS[*]}"
            exit 1
        fi
    done
}

# -- Per-project config loading -----------------------------------------------
load_project_config() {
    local project_path="$1"
    local config_file="${project_path}/.gh-sync.json"

    [[ -f "$config_file" ]] || return 0

    write_info "Loading project config: ${config_file}"

    # We need python or jq to parse JSON. Try python first (more common), then jq
    local json_content
    json_content="$(cat "$config_file")"

    # Parse exclude (only if not already set via CLI)
    if [[ ${#EXCLUDE_PATTERNS[@]} -eq 0 ]]; then
        local excludes
        if command -v python3 &>/dev/null; then
            excludes="$(python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    for e in d.get('exclude', []):
        print(e)
except: pass
" <<< "$json_content" 2>/dev/null)" || true
        elif command -v python &>/dev/null; then
            excludes="$(python -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    for e in d.get('exclude', []):
        print(e)
except: pass
" <<< "$json_content" 2>/dev/null)" || true
        elif command -v jq &>/dev/null; then
            excludes="$(jq -r '.exclude[]? // empty' <<< "$json_content" 2>/dev/null)" || true
        fi
        if [[ -n "$excludes" ]]; then
            while IFS= read -r pattern; do
                [[ -n "$pattern" ]] && EXCLUDE_PATTERNS+=("$pattern")
            done <<< "$excludes"
        fi
    fi

    # Parse only (only if not already set via CLI)
    if [[ ${#ONLY_FOLDERS[@]} -eq 0 ]]; then
        local only_list
        if command -v python3 &>/dev/null; then
            only_list="$(python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    for e in d.get('only', []):
        print(e)
except: pass
" <<< "$json_content" 2>/dev/null)" || true
        elif command -v python &>/dev/null; then
            only_list="$(python -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    for e in d.get('only', []):
        print(e)
except: pass
" <<< "$json_content" 2>/dev/null)" || true
        elif command -v jq &>/dev/null; then
            only_list="$(jq -r '.only[]? // empty' <<< "$json_content" 2>/dev/null)" || true
        fi
        if [[ -n "$only_list" ]]; then
            while IFS= read -r f; do
                [[ -n "$f" ]] && ONLY_FOLDERS+=("$f")
            done <<< "$only_list"
        fi
    fi

    # Parse golden_source override (only if not set via env or CLI config)
    if [[ -z "${GH_SYNC_SOURCE:-}" ]]; then
        local gs_override
        if command -v python3 &>/dev/null; then
            gs_override="$(python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    v = d.get('golden_source', '')
    if v: print(v)
except: pass
" <<< "$json_content" 2>/dev/null)" || true
        elif command -v python &>/dev/null; then
            gs_override="$(python -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    v = d.get('golden_source', '')
    if v: print(v)
except: pass
" <<< "$json_content" 2>/dev/null)" || true
        elif command -v jq &>/dev/null; then
            gs_override="$(jq -r '.golden_source // empty' <<< "$json_content" 2>/dev/null)" || true
        fi
        if [[ -n "$gs_override" ]]; then
            PROJECT_GOLDEN_SOURCE="$gs_override"
        fi
    fi
}

# Variable to store per-project golden source override
PROJECT_GOLDEN_SOURCE=""
LATEST=false

# Detect hash command once at startup (avoid per-file detection)
if command -v md5sum &>/dev/null; then
    _HASH_CMD="md5sum"
elif command -v md5 &>/dev/null; then
    _HASH_CMD="md5"
elif command -v shasum &>/dev/null; then
    _HASH_CMD="shasum"
else
    write_err "No hash command found (md5sum, md5, or shasum required)"
    exit 1
fi

# Detect OS once at startup
_IS_DARWIN=false
[[ "$(uname)" == "Darwin" ]] && _IS_DARWIN=true

# Collect file metadata for a directory using FULLY BATCHED operations.
# Outputs lines of: RELATIVE_PATH<TAB>FULL_PATH<TAB>MTIME_EPOCH<TAB>SIZE<TAB>HASH
#
# Performance: ~4 total subprocess forks regardless of file count (vs N*3 before).
# Uses find -exec ... + for batching and awk for merging — no per-file subshells.
get_all_files() {
    local folder="$1"
    [[ -d "$folder" ]] || return 0

    local tmp_work
    tmp_work="$(mktemp -d)" || return 1
    register_temp_dir "$tmp_work"

    # 1. Batch hash: ALL files hashed in 1-2 subprocess calls via find -exec +
    case "$_HASH_CMD" in
        md5sum)
            find "$folder" -type f -exec md5sum -- {} + > "$tmp_work/hashes.raw" 2>/dev/null || true
            ;;
        md5)
            find "$folder" -type f -exec md5 -r -- {} + > "$tmp_work/hashes.raw" 2>/dev/null || true
            ;;
        shasum)
            find "$folder" -type f -exec shasum -a 256 -- {} + > "$tmp_work/hashes.raw" 2>/dev/null || true
            ;;
    esac

    [[ -s "$tmp_work/hashes.raw" ]] || { rm -rf -- "$tmp_work"; return 0; }

    # 2. Batch stat: ALL files in 0-2 subprocess calls
    if [[ "$_IS_DARWIN" == "true" ]]; then
        # macOS: stat -f with pipe-delimited format to handle spaces in paths
        find "$folder" -type f -exec stat -f '%m|%z|%N' {} + > "$tmp_work/stats.raw" 2>/dev/null
    else
        # GNU find -printf: ZERO subprocesses (built into find)
        find "$folder" -type f -printf '%T@|%s|%p\n' > "$tmp_work/stats.raw" 2>/dev/null
    fi

    # 3. Merge hash + stat using awk (1 subprocess, handles spaces in paths)
    #    Pass 1: read hashes.raw -> build hash[filepath] map
    #    Pass 2: read stats.raw  -> join with hashes and output
    #    NOTE: Uses ENVIRON instead of -v to avoid awk interpreting backslashes
    #    in Windows paths (e.g. \U -> escape sequence)
    AWK_BASE="$folder" awk '
    BEGIN { base = ENVIRON["AWK_BASE"] }
    # --- Pass 1: hash file ---
    # Format: "HASH  FILEPATH" (md5sum: 2 spaces) or "HASH FILEPATH" (md5 -r: 1 space)
    # On MINGW64/Windows, md5sum outputs binary-mode marker: "HASH *FILEPATH"
    NR == FNR {
        hash = $1
        # Remove hash + leading spaces + optional binary-mode asterisk to get filepath
        sub(/^[^ ]+ +\*?/, "")
        hashes[$0] = hash
        next
    }
    # --- Pass 2: stat file ---
    # Format: "MTIME|SIZE|FILEPATH" (pipe delimited)
    {
        n = index($0, "|")
        mtime = substr($0, 1, n-1)
        rest = substr($0, n+1)
        n2 = index(rest, "|")
        size = substr(rest, 1, n2-1)
        filepath = substr(rest, n2+1)

        # Truncate fractional seconds from mtime
        dot = index(mtime, ".")
        if (dot > 0) mtime = substr(mtime, 1, dot-1)

        # Compute relative path: remove base prefix using index()
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
    ' "$tmp_work/hashes.raw" "$tmp_work/stats.raw" > "$tmp_work/merged.tsv"

    # 4. Apply exclusion patterns (pure bash, no forks)
    if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
        while IFS=$'\t' read -r rel rest; do
            should_exclude "$rel" && continue
            printf '%s\t%s\n' "$rel" "$rest"
        done < "$tmp_work/merged.tsv"
    else
        cat "$tmp_work/merged.tsv"
    fi

    rm -rf -- "$tmp_work"
}

# Compare two directories. Outputs lines of:
#   STATUS<TAB>RELATIVE_PATH<TAB>DETAIL
# where STATUS is: ONLY_IN_SOURCE, ONLY_IN_TARGET, MODIFIED
#
# Optimized: uses `comm` for O(n) set operations instead of per-key grep.
compare_folders() {
    local source_dir="$1"
    local target_dir="$2"
    local source_label="$3"
    local target_label="$4"

    local tmp_dir
    tmp_dir="$(mktemp -d)" || { write_err "Failed to create temp dir"; return 1; }
    register_temp_dir "$tmp_dir"

    local source_data="$tmp_dir/source.tsv"
    local target_data="$tmp_dir/target.tsv"

    get_all_files "$source_dir" > "$source_data"
    get_all_files "$target_dir" > "$target_data"

    # Extract sorted keys
    awk -F'\t' '{print $1}' "$source_data" | sort > "$tmp_dir/sk.txt"
    awk -F'\t' '{print $1}' "$target_data" | sort > "$tmp_dir/tk.txt"

    local results=""

    # Files only in source (one comm call, no loop)
    while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        results+="ONLY_IN_SOURCE\t${key}\tOnly in ${source_label}\n"
    done < <(comm -23 "$tmp_dir/sk.txt" "$tmp_dir/tk.txt")

    # Files only in target
    while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        results+="ONLY_IN_TARGET\t${key}\tOnly in ${target_label}\n"
    done < <(comm -13 "$tmp_dir/sk.txt" "$tmp_dir/tk.txt")

    # Files in both — build keyed hash+mtime lookup tables, then join
    # Source: key<TAB>hash<TAB>mtime
    awk -F'\t' '{print $1 "\t" $5 "\t" $3}' "$source_data" | sort -t$'\t' -k1,1 > "$tmp_dir/s_kh.tsv"
    awk -F'\t' '{print $1 "\t" $5 "\t" $3}' "$target_data" | sort -t$'\t' -k1,1 > "$tmp_dir/t_kh.tsv"

    # Join on key (field 1), output: key, s_hash, s_mtime, t_hash, t_mtime
    join -t$'\t' -j1 "$tmp_dir/s_kh.tsv" "$tmp_dir/t_kh.tsv" > "$tmp_dir/joined.tsv" 2>/dev/null || true

    while IFS=$'\t' read -r key s_hash s_mtime t_hash t_mtime; do
        if [[ "$s_hash" != "$t_hash" ]]; then
            local newer="$source_label"
            if [[ "$t_mtime" -gt "$s_mtime" ]] 2>/dev/null; then
                newer="$target_label"
            fi
            results+="MODIFIED\t${key}\tDifferent (newer in ${newer})\n"
        fi
    done < "$tmp_dir/joined.tsv"

    rm -rf -- "$tmp_dir"

    if [[ -n "$results" ]]; then
        printf '%b' "$results"
    fi
}

# Sync files from source to target for one folder.
# Accepts pre-computed diffs as $5 to avoid recomputation.
# Returns the number of files copied via stdout (all display output goes to stderr).
sync_folder() {
    local source_dir="$1"
    local target_dir="$2"
    local folder_name="$3"
    local is_dry_run="$4"
    local cached_diffs="${5:-}"
    local source_label="${6:-source}"
    local target_label="${7:-target}"

    if [[ ! -d "$source_dir" ]]; then
        write_info "Skipping ${folder_name} (not in source)" >&2
        echo "0"
        return
    fi

    # Use cached diffs if provided, otherwise compute
    local diffs
    if [[ -n "$cached_diffs" ]]; then
        diffs="$cached_diffs"
    else
        diffs="$(compare_folders "$source_dir" "$target_dir" "$source_label" "$target_label")" || true
    fi

    if [[ -z "$diffs" ]]; then
        write_ok "${folder_name} -- already in sync" >&2
        echo "0"
        return
    fi

    # Split diffs into categories
    local to_copy to_copy_count only_target only_target_count
    to_copy="$(printf '%s\n' "$diffs" | grep -E '^(ONLY_IN_SOURCE|MODIFIED)' || true)"
    to_copy_count="$(printf '%s\n' "$to_copy" | grep -c . || true)"
    only_target="$(printf '%s\n' "$diffs" | grep '^ONLY_IN_TARGET' || true)"
    only_target_count="$(printf '%s\n' "$only_target" | grep -c . || true)"

    if [[ "$to_copy_count" -gt 0 ]]; then
        write_colored "$_color_white" "${folder_name} -- ${to_copy_count} file(s) to copy/update:" >&2
        while IFS=$'\t' read -r status rel_path detail; do
            write_info "$(printf '%-16s %s' "$status" "$rel_path")" >&2
        done <<< "$to_copy"
    fi

    if [[ "$only_target_count" -gt 0 ]]; then
        write_colored "$_color_dark_yellow" "${folder_name} -- ${only_target_count} file(s) only in target (kept):" >&2
        while IFS=$'\t' read -r _ rel_path _; do
            write_warn "$rel_path" >&2
        done <<< "$only_target"
    fi

    if [[ "$is_dry_run" == "true" ]]; then
        echo "0"
        return
    fi

    # Create backup before overwriting
    if [[ -d "$target_dir" ]]; then
        local timestamp backup_name backup_dir
        timestamp="$(date '+%Y%m%d-%H%M%S')"
        backup_name="gh-sync-backup-${folder_name#.}-${timestamp}"
        backup_dir="$(mktemp -d "${TMPDIR:-/tmp}/${backup_name}.XXXXXX")"
        cp -a "$target_dir/." "$backup_dir/" 2>/dev/null || true
    fi

    # Copy files
    local copied_count=0
    if [[ -n "$to_copy" ]]; then
        while IFS=$'\t' read -r _ rel_path _; do
            local src dst dst_dir
            src="${source_dir}/${rel_path}"
            dst="${target_dir}/${rel_path}"
            dst_dir="$(dirname "$dst")"

            if [[ ! -d "$dst_dir" ]]; then
                mkdir -p "$dst_dir" || { write_err "Cannot create directory: ${dst_dir}"; continue; }
            fi

            if cp "$src" "$dst" 2>/dev/null; then
                ((copied_count++)) || true
            else
                write_err "Failed to copy: ${rel_path}"
            fi
        done <<< "$to_copy"
    fi

    write_ok "${folder_name} -- ${copied_count} file(s) synced" >&2
    echo "$copied_count"
}

# Count files in a directory
count_files() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "0"
        return
    fi
    find "$dir" -type f | wc -l | tr -d '[:space:]'
}

# =============================================================================
# CONFIG — Show effective config or generate a project config template
# =============================================================================
do_config() {
    local project_root="$1"
    local subcommand="${2:-}"

    if [[ "$subcommand" == "init" ]]; then
        # Generate a .gh-sync.json template in the project root
        local config_file="${project_root}/.gh-sync.json"
        if [[ -f "$config_file" ]]; then
            write_warn ".gh-sync.json already exists at: ${config_file}"
            printf '  Overwrite? [y/N] '
            read -r ans
            case "$ans" in y|Y|yes|Yes) ;; *) write_warn "Aborted."; return 0 ;; esac
        fi
        cat > "$config_file" <<'TEMPLATE'
{
  "exclude": [],
  "only": [],
  "golden_source": ""
}
TEMPLATE
        write_ok "Created: ${config_file}"
        write_info "Edit the file to set defaults for this project."
        write_info "  exclude     - patterns to skip (e.g. [\"*.log\", \"temp/*\"])"
        write_info "  only        - folders to sync (e.g. [\".github\", \".agents\"])"
        write_info "  golden_source - override golden source path for this project"
        return 0
    fi

    # Default: show effective config
    write_header "CONFIG: Effective Settings"

    # Golden source resolution
    local gs_source gs_value
    if [[ -n "${GH_SYNC_SOURCE:-}" ]]; then
        gs_source="GH_SYNC_SOURCE env var"
        gs_value="$GH_SYNC_SOURCE"
    elif [[ -n "${PROJECT_GOLDEN_SOURCE:-}" ]]; then
        gs_source=".gh-sync.json (golden_source)"
        gs_value="$PROJECT_GOLDEN_SOURCE"
    else
        local cfg_path
        cfg_path="$(head -1 "$CONFIG_FILE" 2>/dev/null | tr -d '[:space:]')" || true
        if [[ -n "$cfg_path" ]]; then
            gs_source="${CONFIG_FILE}"
            gs_value="$cfg_path"
        else
            gs_source="(not configured)"
            gs_value="—"
        fi
    fi

    printf '\n'
    write_colored "$_color_white"   "Golden source"
    write_info "  Value:  ${gs_value}"
    write_info "  Source: ${gs_source}"

    printf '\n'
    write_colored "$_color_white"   "Sync folders"
    write_info "  ${SYNC_FOLDERS[*]}"

    printf '\n'
    write_colored "$_color_white"   "Active filters"
    if [[ ${#ONLY_FOLDERS[@]} -gt 0 ]]; then
        write_info "  --only:    ${ONLY_FOLDERS[*]}"
    else
        write_info "  --only:    (all folders)"
    fi
    if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
        write_info "  --exclude: ${EXCLUDE_PATTERNS[*]}"
    else
        write_info "  --exclude: (none)"
    fi

    printf '\n'
    write_colored "$_color_white"   "Project config file"
    local pconf="${project_root}/.gh-sync.json"
    if [[ -f "$pconf" ]]; then
        write_info "  ${pconf} (loaded)"
    else
        write_info "  ${pconf} (not found)"
    fi

    printf '\n'
    write_info "Run 'gh-sync config init' to generate a .gh-sync.json template."
}

# =============================================================================
# INIT
# =============================================================================
do_init() {
    write_header "INIT: Configure gh-sync"

    local golden_source
    golden_source="$(get_golden_source)"

    if [[ -n "$golden_source" ]]; then
        write_info "Current golden source: ${golden_source}"
    fi

    printf '\n'
    write_colored "$_color_white" "The golden source is a DIRECTORY containing your shared folders:"
    write_colored "$_color_gray" "  .github/  .agent/  .agents/  .claude/"
    printf '\n'

    printf '  Enter the path to your golden source directory: '
    read -r new_path

    # Trim whitespace and quotes
    new_path="$(echo "$new_path" | sed 's/^[[:space:]"]*//;s/[[:space:]"]*$//')"

    if [[ -z "$new_path" ]]; then
        write_err "No path provided. Aborted."
        exit 1
    fi

    # Expand ~ if present
    new_path="${new_path/#\~/$HOME}"

    if [[ ! -d "$new_path" ]]; then
        write_warn "Path does not exist yet. Create it? [y/N]"
        printf '  '
        read -r create_answer
        case "$create_answer" in
            y|Y|yes|Yes)
                mkdir -p "$new_path" || { write_err "Failed to create directory"; exit 1; }
                write_ok "Created: ${new_path}"
                ;;
            *)
                write_err "Aborted. Please create the folder first."
                exit 1
                ;;
        esac
    fi

    # Resolve to absolute path
    new_path="$(cd "$new_path" && pwd -P)"

    # Show which sync folders exist
    printf '\n'
    local folder
    for folder in "${SYNC_FOLDERS[@]}"; do
        local fp="${new_path}/${folder}"
        if [[ -d "$fp" ]]; then
            local count
            count="$(count_files "$fp")"
            write_ok "${folder} (${count} files)"
        else
            write_warn "${folder} (not found -- will be skipped during sync)"
        fi
    done

    # Save config
    printf '%s\n' "$new_path" > "$CONFIG_FILE"

    printf '\n'
    write_ok "Saved config to: ${CONFIG_FILE}"
    write_ok "Golden source set to: ${new_path}"
    printf '\n'
    write_info "You can now use: gh-sync push, pull, diff, status"
}

# =============================================================================
# PUSH
# =============================================================================
do_push() {
    local golden_source="$1"
    local project_root="$2"

    write_header "PUSH: Golden Source -> Project"
    write_info "Source:  ${golden_source}"
    write_info "Target:  ${project_root}"
    printf '\n'

    # Collect diffs ONCE and cache per folder (avoid double computation)
    declare -A cached_diffs
    local total_changes=0
    local folder
    for folder in "${SYNC_FOLDERS[@]}"; do
        should_process_folder "$folder" || continue
        local src="${golden_source}/${folder}"
        local tgt="${project_root}/${folder}"

        if [[ -d "$src" ]]; then
            local diffs
            diffs="$(compare_folders "$src" "$tgt" "Golden" "Project")" || true
            cached_diffs["$folder"]="$diffs"

            if [[ -n "$diffs" ]]; then
                local to_copy_count only_target_count
                to_copy_count="$(printf '%s\n' "$diffs" | grep -cE '^(ONLY_IN_SOURCE|MODIFIED)' || true)"
                only_target_count="$(printf '%s\n' "$diffs" | grep -c '^ONLY_IN_TARGET' || true)"
                write_colored "$_color_white" "${folder} -- ${to_copy_count} to sync, ${only_target_count} only in project"
                total_changes=$((total_changes + to_copy_count + only_target_count))
            fi
        fi
    done

    if [[ "$total_changes" -eq 0 ]]; then
        write_ok "All folders already in sync -- nothing to do."
        exit 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        printf '\n'
        for folder in "${SYNC_FOLDERS[@]}"; do
            should_process_folder "$folder" || continue
            local src="${golden_source}/${folder}"
            local tgt="${project_root}/${folder}"
            if [[ -d "$src" ]]; then
                sync_folder "$src" "$tgt" "$folder" "true" "${cached_diffs[$folder]:-}" "Golden" "Project" > /dev/null
            fi
        done
        write_warn "Dry-run mode -- no files were changed."
        exit 0
    fi

    if [[ "$FORCE" != "true" ]]; then
        printf '\n'
        printf '  Proceed with PUSH? [y/N] '
        read -r answer
        case "$answer" in
            y|Y|yes|Yes) ;;
            *)
                write_warn "Aborted."
                exit 0
                ;;
        esac
    fi

    printf '\n'
    local total_copied=0
    for folder in "${SYNC_FOLDERS[@]}"; do
        should_process_folder "$folder" || continue
        local src="${golden_source}/${folder}"
        local tgt="${project_root}/${folder}"
        local result
        # Pass cached diffs to avoid recomputing
        result="$(sync_folder "$src" "$tgt" "$folder" "false" "${cached_diffs[$folder]:-}" "Golden" "Project")" || true
        result="${result##*$'\n'}"  # last line only (the count)
        [[ "$result" =~ ^[0-9]+$ ]] || result=0
        total_copied=$((total_copied + result))
    done

    printf '\n'
    write_ok "Push complete! (${total_copied} files updated across all folders)"
}

# =============================================================================
# PULL
# =============================================================================
do_pull() {
    local golden_source="$1"
    local project_root="$2"

    write_header "PULL: Project -> Golden Source"
    write_info "Source:  ${project_root}"
    write_info "Target:  ${golden_source}"
    printf '\n'

    # Cache diffs per folder
    declare -A cached_diffs
    local total_changes=0
    local folder
    for folder in "${SYNC_FOLDERS[@]}"; do
        should_process_folder "$folder" || continue
        local src="${project_root}/${folder}"
        local tgt="${golden_source}/${folder}"

        if [[ -d "$src" ]]; then
            local diffs
            diffs="$(compare_folders "$src" "$tgt" "Project" "Golden")" || true
            cached_diffs["$folder"]="$diffs"

            if [[ -n "$diffs" ]]; then
                local to_copy_count
                to_copy_count="$(printf '%s\n' "$diffs" | grep -cE '^(ONLY_IN_SOURCE|MODIFIED)' || true)"
                write_colored "$_color_white" "${folder} -- ${to_copy_count} to pull back"
                total_changes=$((total_changes + to_copy_count))
            fi
        fi
    done

    if [[ "$total_changes" -eq 0 ]]; then
        write_ok "All folders already in sync -- nothing to do."
        exit 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        printf '\n'
        for folder in "${SYNC_FOLDERS[@]}"; do
            should_process_folder "$folder" || continue
            local src="${project_root}/${folder}"
            local tgt="${golden_source}/${folder}"
            if [[ -d "$src" ]]; then
                sync_folder "$src" "$tgt" "$folder" "true" "${cached_diffs[$folder]:-}" "Project" "Golden" > /dev/null
            fi
        done
        write_warn "Dry-run mode -- no files were changed."
        exit 0
    fi

    if [[ "$FORCE" != "true" ]]; then
        printf '\n'
        printf '  Proceed with PULL? [y/N] '
        read -r answer
        case "$answer" in
            y|Y|yes|Yes) ;;
            *)
                write_warn "Aborted."
                exit 0
                ;;
        esac
    fi

    printf '\n'
    local total_copied=0
    for folder in "${SYNC_FOLDERS[@]}"; do
        should_process_folder "$folder" || continue
        local src="${project_root}/${folder}"
        local tgt="${golden_source}/${folder}"
        local result
        result="$(sync_folder "$src" "$tgt" "$folder" "false" "${cached_diffs[$folder]:-}" "Project" "Golden")" || true
        result="${result##*$'\n'}"  # last line only (the count)
        [[ "$result" =~ ^[0-9]+$ ]] || result=0
        total_copied=$((total_copied + result))
    done

    printf '\n'
    write_ok "Pull complete! (${total_copied} files updated in golden source)"
}

# =============================================================================
# DIFF
# =============================================================================
do_diff() {
    local golden_source="$1"
    local project_root="$2"

    write_header "DIFF: Golden Source <-> Project"
    write_info "Golden:  ${golden_source}"
    write_info "Project: ${project_root}"

    local total_diffs=0
    local folder
    for folder in "${SYNC_FOLDERS[@]}"; do
        should_process_folder "$folder" || continue
        local src="${golden_source}/${folder}"
        local tgt="${project_root}/${folder}"

        local src_exists=false tgt_exists=false
        [[ -d "$src" ]] && src_exists=true
        [[ -d "$tgt" ]] && tgt_exists=true

        if [[ "$src_exists" == "false" && "$tgt_exists" == "false" ]]; then
            continue
        fi

        printf '\n'
        write_colored "$_color_cyan" "--- ${folder} ---"

        if [[ "$src_exists" == "false" ]]; then
            write_warn "Only in project (not in golden source)"
            continue
        fi

        if [[ "$tgt_exists" == "false" ]]; then
            local file_count
            file_count="$(count_files "$src")"
            write_warn "Not in project (${file_count} golden files would be pushed)"
            total_diffs=$((total_diffs + file_count))
            continue
        fi

        local diffs
        diffs="$(compare_folders "$src" "$tgt" "Golden" "Project")" || true

        if [[ -z "$diffs" ]]; then
            write_ok "In sync"
        else
            local diff_count
            diff_count="$(printf '%s\n' "$diffs" | grep -c . || true)"
            total_diffs=$((total_diffs + diff_count))

            while IFS=$'\t' read -r status rel_path detail; do
                local icon="?" color="$_color_white"
                case "$status" in
                    ONLY_IN_SOURCE) icon="+"; color="$_color_green" ;;
                    ONLY_IN_TARGET) icon="-"; color="$_color_red" ;;
                    MODIFIED)       icon="~"; color="$_color_yellow" ;;
                esac
                write_colored "$color" "[${icon}] ${rel_path}"
                write_colored "$_color_gray" "    ${detail}"
            done <<< "$diffs"
        fi
    done

    printf '\n'
    if [[ "$total_diffs" -eq 0 ]]; then
        write_ok "All folders fully in sync!"
    else
        write_warn "${total_diffs} total difference(s) found."
    fi
}

# =============================================================================
# STATUS
# =============================================================================
do_status() {
    local golden_source="$1"
    local project_root="$2"

    write_header "STATUS: Sync Overview"
    write_info "Golden:  ${golden_source}"
    write_info "Project: ${project_root}"
    printf '\n'

    local grand_in_sync=0
    local grand_only_golden=0
    local grand_only_project=0
    local grand_modified=0

    local folder
    for folder in "${SYNC_FOLDERS[@]}"; do
        should_process_folder "$folder" || continue
        local src="${golden_source}/${folder}"
        local tgt="${project_root}/${folder}"

        local src_exists=false tgt_exists=false
        [[ -d "$src" ]] && src_exists=true
        [[ -d "$tgt" ]] && tgt_exists=true

        if [[ "$src_exists" == "false" && "$tgt_exists" == "false" ]]; then
            continue
        fi

        write_colored "$_color_cyan" "--- ${folder} ---"

        if [[ "$src_exists" == "false" ]]; then
            write_warn "Only in project"
            printf '\n'
            continue
        fi

        if [[ "$tgt_exists" == "false" ]]; then
            local count
            count="$(count_files "$src")"
            write_warn "Not in project (${count} files to push)"
            grand_only_golden=$((grand_only_golden + count))
            printf '\n'
            continue
        fi

        local diffs
        diffs="$(compare_folders "$src" "$tgt" "Golden" "Project")" || true

        local total_golden only_in_source only_in_target modified identical
        total_golden="$(count_files "$src")"

        if [[ -n "$diffs" ]]; then
            only_in_source="$(printf '%s\n' "$diffs" | grep -c '^ONLY_IN_SOURCE' || true)"
            only_in_target="$(printf '%s\n' "$diffs" | grep -c '^ONLY_IN_TARGET' || true)"
            modified="$(printf '%s\n' "$diffs" | grep -c '^MODIFIED' || true)"
        else
            only_in_source=0
            only_in_target=0
            modified=0
        fi

        identical=$((total_golden - only_in_source - modified))

        write_colored "$_color_green"   "  In sync:         ${identical}"
        write_colored "$_color_cyan"    "  Only in Golden:  ${only_in_source}"
        write_colored "$_color_magenta" "  Only in Project: ${only_in_target}"
        write_colored "$_color_yellow"  "  Modified:        ${modified}"
        printf '\n'

        grand_in_sync=$((grand_in_sync + identical))
        grand_only_golden=$((grand_only_golden + only_in_source))
        grand_only_project=$((grand_only_project + only_in_target))
        grand_modified=$((grand_modified + modified))
    done

    write_colored "$_color_cyan"    "=== TOTAL ==="
    write_colored "$_color_green"   "  In sync:         ${grand_in_sync} files"
    write_colored "$_color_cyan"    "  Only in Golden:  ${grand_only_golden} files"
    write_colored "$_color_magenta" "  Only in Project: ${grand_only_project} files"
    write_colored "$_color_yellow"  "  Modified:        ${grand_modified} files"
}

# =============================================================================
# BACKUPS — List available backups
# =============================================================================
do_backups() {
    write_header "BACKUPS: Available Restore Points"

    local backup_dir="${TMPDIR:-/tmp}"
    local backups
    backups="$(find "$backup_dir" -maxdepth 1 -type d -name 'gh-sync-backup-*' 2>/dev/null | sort -r)"

    if [[ -z "$backups" ]]; then
        write_info "No backups found in: ${backup_dir}"
        return 0
    fi

    local idx=0
    while IFS= read -r bdir; do
        [[ -n "$bdir" ]] || continue
        local bname
        bname="$(basename "$bdir")"

        # Parse folder name and timestamp from: gh-sync-backup-FOLDER-YYYYMMDD-HHMMSS.XXXXXX
        local folder_part timestamp_part
        folder_part="$(echo "$bname" | sed 's/^gh-sync-backup-//;s/-[0-9]\{8\}-[0-9]\{6\}.*$//')"
        timestamp_part="$(echo "$bname" | grep -oP '\d{8}-\d{6}' || echo 'unknown')"

        local file_count
        file_count="$(find "$bdir" -type f 2>/dev/null | wc -l | tr -d '[:space:]')"

        local size
        if command -v du &>/dev/null; then
            size="$(du -sh "$bdir" 2>/dev/null | awk '{print $1}')" || size="?"
        else
            size="?"
        fi

        idx=$((idx + 1))
        write_colored "$_color_cyan" "[${idx}] .${folder_part} — ${timestamp_part} (${file_count} files, ${size})"
        write_colored "$_color_gray" "    ${bdir}"
    done <<< "$backups"

    printf '\n'
    write_info "Total: ${idx} backup(s)"
    write_info "Use 'gh-sync restore --latest' or 'gh-sync restore' to restore."
    write_info "Use 'gh-sync clean --keep N' to remove old backups."
}

# =============================================================================
# RESTORE — Restore from a backup
# =============================================================================
do_restore() {
    local project_root="$1"

    write_header "RESTORE: Recover from Backup"

    local backup_dir="${TMPDIR:-/tmp}"
    local backups
    backups="$(find "$backup_dir" -maxdepth 1 -type d -name 'gh-sync-backup-*' 2>/dev/null | sort -r)"

    if [[ -z "$backups" ]]; then
        write_err "No backups found in: ${backup_dir}"
        exit 1
    fi

    # Build indexed array of backups
    local -a backup_list=()
    while IFS= read -r bdir; do
        [[ -n "$bdir" ]] && backup_list+=("$bdir")
    done <<< "$backups"

    local selected_backup

    if [[ "$LATEST" == "true" ]]; then
        selected_backup="${backup_list[0]}"
        write_info "Using latest backup: $(basename "$selected_backup")"
    else
        # Show list and prompt
        local idx=0
        for bdir in "${backup_list[@]}"; do
            local bname folder_part timestamp_part file_count
            bname="$(basename "$bdir")"
            folder_part="$(echo "$bname" | sed 's/^gh-sync-backup-//;s/-[0-9]\{8\}-[0-9]\{6\}.*$//')"
            timestamp_part="$(echo "$bname" | grep -oP '\d{8}-\d{6}' || echo 'unknown')"
            file_count="$(find "$bdir" -type f 2>/dev/null | wc -l | tr -d '[:space:]')"
            idx=$((idx + 1))
            write_colored "$_color_cyan" "[${idx}] .${folder_part} — ${timestamp_part} (${file_count} files)"
        done

        printf '\n  Select backup number (1-%d): ' "${#backup_list[@]}"
        read -r selection

        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt "${#backup_list[@]}" ]]; then
            write_err "Invalid selection: $selection"
            exit 1
        fi

        selected_backup="${backup_list[$((selection - 1))]}"
    fi

    # Determine target folder from backup name
    local bname folder_part target_dir
    bname="$(basename "$selected_backup")"
    folder_part="$(echo "$bname" | sed 's/^gh-sync-backup-//;s/-[0-9]\{8\}-[0-9]\{6\}.*$//')"
    target_dir="${project_root}/.${folder_part}"

    write_info "Backup:  ${selected_backup}"
    write_info "Target:  ${target_dir}"

    local file_count
    file_count="$(find "$selected_backup" -type f 2>/dev/null | wc -l | tr -d '[:space:]')"
    write_info "Files:   ${file_count}"

    if [[ "$DRY_RUN" == "true" ]]; then
        write_warn "Dry-run mode — no files were restored."
        return 0
    fi

    if [[ "$FORCE" != "true" ]]; then
        printf '\n  Restore will OVERWRITE %s. Proceed? [y/N] ' "$target_dir"
        read -r answer
        case "$answer" in
            y|Y|yes|Yes) ;;
            *) write_warn "Aborted."; exit 0 ;;
        esac
    fi

    # Perform restore
    if [[ -d "$target_dir" ]]; then
        rm -rf "$target_dir"
    fi
    mkdir -p "$target_dir"
    cp -a "$selected_backup/." "$target_dir/" 2>/dev/null || true

    printf '\n'
    write_ok "Restored ${file_count} files to ${target_dir}"
}

# =============================================================================
# CLEAN — Remove old backups
# =============================================================================
do_clean() {
    write_header "CLEAN: Remove Old Backups"

    local backup_dir="${TMPDIR:-/tmp}"
    local backups
    backups="$(find "$backup_dir" -maxdepth 1 -type d -name 'gh-sync-backup-*' 2>/dev/null | sort -r)"

    if [[ -z "$backups" ]]; then
        write_info "No backups found. Nothing to clean."
        return 0
    fi

    # Build indexed array
    local -a backup_list=()
    while IFS= read -r bdir; do
        [[ -n "$bdir" ]] && backup_list+=("$bdir")
    done <<< "$backups"

    local total="${#backup_list[@]}"
    local to_remove=0
    local -a remove_list=()

    if [[ "$KEEP_BACKUPS" -eq 0 ]]; then
        # --all: remove everything
        remove_list=("${backup_list[@]}")
        to_remove="$total"
    else
        # Group backups by folder name, keep N most recent per folder
        # First, get unique folder names
        local -A folder_counts
        for bdir in "${backup_list[@]}"; do
            local bname folder_part
            bname="$(basename "$bdir")"
            folder_part="$(echo "$bname" | sed 's/^gh-sync-backup-//;s/-[0-9]\{8\}-[0-9]\{6\}.*$//')"
            folder_counts["$folder_part"]=$(( ${folder_counts[$folder_part]:-0} + 1 ))

            if [[ ${folder_counts[$folder_part]} -gt $KEEP_BACKUPS ]]; then
                remove_list+=("$bdir")
                to_remove=$((to_remove + 1))
            fi
        done
    fi

    if [[ "$to_remove" -eq 0 ]]; then
        write_ok "Nothing to clean. All ${total} backup(s) within the keep limit."
        return 0
    fi

    write_info "Found ${total} backup(s), will remove ${to_remove}."

    if [[ "$DRY_RUN" == "true" ]]; then
        for bdir in "${remove_list[@]}"; do
            write_colored "$_color_red" "  Would remove: $(basename "$bdir")"
        done
        write_warn "Dry-run mode — no backups were removed."
        return 0
    fi

    if [[ "$FORCE" != "true" ]]; then
        printf '\n  Remove %d backup(s)? [y/N] ' "$to_remove"
        read -r answer
        case "$answer" in
            y|Y|yes|Yes) ;;
            *) write_warn "Aborted."; exit 0 ;;
        esac
    fi

    local removed=0
    for bdir in "${remove_list[@]}"; do
        rm -rf -- "$bdir" && removed=$((removed + 1))
    done

    printf '\n'
    write_ok "Removed ${removed} backup(s). ${total} -> $((total - removed)) remaining."
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    parse_args "$@"

    # Handle init separately (doesn't require golden source to exist)
    if [[ "$ACTION" == "init" ]]; then
        do_init
        exit 0
    fi

    # Handle config (works without golden source; shows current settings)
    if [[ "$ACTION" == "config" ]]; then
        # Resolve project path for config display
        local cfg_project_root="${PROJECT_PATH:-$(pwd)}"
        cfg_project_root="$(normalize_path "$cfg_project_root")"
        [[ -d "$cfg_project_root" ]] && cfg_project_root="$(cd "$cfg_project_root" && pwd -P)"
        load_project_config "$cfg_project_root"
        # Subcommand may be the first positional after 'config'
        local config_sub=""
        # Check if the next positional (stored in PROJECT_PATH after parsing) looks like a subcommand
        if [[ "${PROJECT_PATH:-}" == "init" ]]; then
            config_sub="init"
            cfg_project_root="$(pwd)"
        fi
        do_config "$cfg_project_root" "$config_sub"
        exit 0
    fi

    # Handle clean separately (doesn't require project path or golden source)
    if [[ "$ACTION" == "clean" ]]; then
        do_clean
        exit 0
    fi

    # Handle backups (doesn't require golden source)
    if [[ "$ACTION" == "backups" ]]; then
        do_backups
        exit 0
    fi

    # Resolve project path (normalize Windows backslashes)
    PROJECT_PATH="$(normalize_path "$PROJECT_PATH")"
    if [[ ! -d "$PROJECT_PATH" ]]; then
        write_err "Project path does not exist: ${PROJECT_PATH}"
        exit 1
    fi

    local project_root
    project_root="$(cd "$PROJECT_PATH" && pwd -P)"

    # Load per-project config (.gh-sync.json) — CLI flags override
    load_project_config "$project_root"

    # Validate --only folder names
    validate_only_folders

    # Handle restore (needs project path but not golden source)
    if [[ "$ACTION" == "restore" ]]; then
        do_restore "$project_root"
        exit 0
    fi

    # Resolve golden source: per-project override > env > config file
    local golden_source
    if [[ -n "$PROJECT_GOLDEN_SOURCE" ]]; then
        golden_source="$(normalize_path "$PROJECT_GOLDEN_SOURCE")"
        write_info "Using per-project golden source: ${golden_source}"
    else
        golden_source="$(get_golden_source)"
    fi

    if [[ -z "$golden_source" ]]; then
        write_err "Golden source not configured."
        write_err "Run 'gh-sync init' to set it up, or set GH_SYNC_SOURCE env var."
        exit 1
    fi

    if [[ ! -d "$golden_source" ]]; then
        write_err "Golden source not found: ${golden_source}"
        write_err "Run 'gh-sync init' to reconfigure."
        exit 1
    fi

    # Show active filters
    if [[ ${#ONLY_FOLDERS[@]} -gt 0 ]]; then
        write_info "Syncing only: ${ONLY_FOLDERS[*]}"
    fi
    if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
        write_info "Excluding: ${EXCLUDE_PATTERNS[*]}"
    fi

    # Dispatch
    case "$ACTION" in
        push)   do_push   "$golden_source" "$project_root" ;;
        pull)   do_pull   "$golden_source" "$project_root" ;;
        diff)   do_diff   "$golden_source" "$project_root" ;;
        status) do_status "$golden_source" "$project_root" ;;
        config) do_config "$project_root"  ;;
    esac
}

main "$@"
