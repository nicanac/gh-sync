#!/bin/bash
set -Eeuo pipefail

# =============================================================================
# gh-sync Installer
#
# Copies gh-sync.sh to ~/.local/bin (or ~/bin) and ensures it's on PATH.
# Works on Linux, macOS, and WSL.
# =============================================================================

# -- Logging ------------------------------------------------------------------
_cyan="\033[36m"
_green="\033[32m"
_red="\033[31m"
_gray="\033[90m"
_yellow="\033[33m"
_white="\033[97m"
_reset="\033[0m"

write_ok()  { printf "  ${_green}[OK]${_reset} %s\n" "$1"; }
write_err() { printf "  ${_red}[ERR]${_reset} %s\n" "$1" >&2; }

# -- Error trap ---------------------------------------------------------------
on_error() {
    write_err "Installation failed on line ${BASH_LINENO[0]}"
    exit 1
}
trap on_error ERR

# -- Determine script directory -----------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# -- Determine install directory ----------------------------------------------
# Prefer ~/.local/bin (XDG standard), fall back to ~/bin
if [[ -d "${HOME}/.local/bin" ]] || [[ -n "${XDG_DATA_HOME:-}" ]]; then
    BIN_DIR="${HOME}/.local/bin"
else
    BIN_DIR="${HOME}/bin"
fi

printf '\n'
printf "${_cyan}========================================${_reset}\n"
printf "${_cyan}  gh-sync Installer${_reset}\n"
printf "${_cyan}========================================${_reset}\n"
printf '\n'

# 1. Create bin directory if needed
if [[ ! -d "$BIN_DIR" ]]; then
    mkdir -p "$BIN_DIR"
    write_ok "Created: ${BIN_DIR}"
else
    write_ok "Exists:  ${BIN_DIR}"
fi

# 2. Copy the main script
SRC_FILE="${SCRIPT_DIR}/gh-sync.sh"
DST_FILE="${BIN_DIR}/gh-sync"

if [[ ! -f "$SRC_FILE" ]]; then
    write_err "Missing: ${SRC_FILE}"
    write_err "Make sure gh-sync.sh is in the same directory as this installer."
    exit 1
fi

cp "$SRC_FILE" "$DST_FILE"
chmod +x "$DST_FILE"
write_ok "Installed: gh-sync.sh -> ${DST_FILE}"

# 3. Add bin dir to PATH if not already present
add_to_path() {
    local bin_dir="$1"
    local shell_rc=""

    # Determine which shell config to modify
    case "${SHELL:-/bin/bash}" in
        */zsh)  shell_rc="${HOME}/.zshrc" ;;
        */bash)
            if [[ -f "${HOME}/.bash_profile" ]]; then
                shell_rc="${HOME}/.bash_profile"
            else
                shell_rc="${HOME}/.bashrc"
            fi
            ;;
        */fish)
            # Fish uses a different syntax
            local fish_config="${HOME}/.config/fish/config.fish"
            mkdir -p "$(dirname "$fish_config")"
            if ! grep -qF "$bin_dir" "$fish_config" 2>/dev/null; then
                printf '\n# Added by gh-sync installer\nfish_add_path %s\n' "$bin_dir" >> "$fish_config"
                write_ok "Added ${bin_dir} to ${fish_config}"
            else
                write_ok "PATH already contains ${bin_dir} in ${fish_config}"
            fi
            return
            ;;
        *)
            shell_rc="${HOME}/.profile"
            ;;
    esac

    # Check if already in PATH
    if echo "$PATH" | tr ':' '\n' | grep -qxF "$bin_dir"; then
        write_ok "PATH already contains ${bin_dir}"
        return
    fi

    # Check if the rc file already has a PATH export for this dir
    if [[ -f "$shell_rc" ]] && grep -qF "$bin_dir" "$shell_rc" 2>/dev/null; then
        write_ok "PATH entry already in ${shell_rc}"
        return
    fi

    # Append PATH export
    printf '\n# Added by gh-sync installer\nexport PATH="%s:$PATH"\n' "$bin_dir" >> "$shell_rc"
    write_ok "Added ${bin_dir} to ${shell_rc}"
}

add_to_path "$BIN_DIR"

# 4. Verify installation
printf '\n'
printf "${_cyan}========================================${_reset}\n"
printf "${_green}  Installation complete!${_reset}\n"
printf "${_cyan}========================================${_reset}\n"
printf '\n'
printf "${_white}  Next steps:${_reset}\n"
printf "${_gray}    1. Open a NEW terminal (or run: source ~/.bashrc)${_reset}\n"
printf "${_yellow}    2. Run:  gh-sync init${_reset}\n"
printf "${_gray}       (enter the path to your golden source directory)${_reset}\n"
printf "${_gray}    3. Then from any project folder:${_reset}\n"
printf "${_gray}         gh-sync push    - push golden -> project${_reset}\n"
printf "${_gray}         gh-sync pull    - pull project -> golden${_reset}\n"
printf "${_gray}         gh-sync diff    - preview differences${_reset}\n"
printf "${_gray}         gh-sync status  - sync overview${_reset}\n"
printf '\n'
