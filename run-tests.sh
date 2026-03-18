#!/usr/bin/env bash
# =============================================================================
# run-tests.sh — Run the gh-sync BATS test suite
#
# Usage:
#   ./run-tests.sh               # run all tests
#   ./run-tests.sh tests/01-*   # run specific test file(s)
#   ./run-tests.sh --tap         # TAP output (for CI)
#   ./run-tests.sh --help
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
TESTS_DIR="${SCRIPT_DIR}/tests"

# -- Colours ------------------------------------------------------------------
_red="\033[31m" _green="\033[32m" _yellow="\033[33m" _cyan="\033[36m" _reset="\033[0m"
info()  { printf "${_cyan}  ->  %s${_reset}\n" "$*"; }
ok()    { printf "${_green}  [OK]${_reset} %s\n" "$*"; }
warn()  { printf "${_yellow}  [!!]${_reset} %s\n" "$*"; }
err()   { printf "${_red}  [ERR]${_reset} %s\n" "$*" >&2; }

# -- Locate bats --------------------------------------------------------------
find_bats() {
    # 1. System bats
    if command -v bats &>/dev/null; then
        echo "bats"
        return
    fi
    # 2. Local bats (installed via npm or git submodule)
    local candidates=(
        "${SCRIPT_DIR}/node_modules/.bin/bats"
        "${SCRIPT_DIR}/tests/bats/bin/bats"
        "${SCRIPT_DIR}/.bats/bin/bats"
        "/usr/local/bin/bats"
    )
    for c in "${candidates[@]}"; do
        if [[ -x "$c" ]]; then
            echo "$c"
            return
        fi
    done
    echo ""
}

BATS="$(find_bats)"

if [[ -z "$BATS" ]]; then
    err "BATS not found. Install it with one of:"
    err "  sudo apt install bats           (Debian/Ubuntu)"
    err "  brew install bats-core          (macOS)"
    err "  npm install -g bats             (cross-platform)"
    err "  git clone https://github.com/bats-core/bats-core && ./bats-core/install.sh ~/.local"
    exit 1
fi

info "Using bats: $BATS  ($(${BATS} --version))"

# -- Parse arguments ----------------------------------------------------------
BATS_ARGS=()
TEST_FILES=()
TAP_MODE=false

for arg in "$@"; do
    case "$arg" in
        --tap|-t)
            TAP_MODE=true
            BATS_ARGS+=(--formatter tap)
            ;;
        --help|-h)
            echo "Usage: $0 [--tap] [test_files...]"
            echo ""
            echo "Options:"
            echo "  --tap   TAP-compatible output for CI"
            echo ""
            echo "Examples:"
            echo "  $0                        # run all tests"
            echo "  $0 tests/01-push-pull.bats  # run one file"
            exit 0
            ;;
        *.bats)
            TEST_FILES+=("$arg")
            ;;
        tests/*)
            TEST_FILES+=("$arg")
            ;;
        *)
            BATS_ARGS+=("$arg")
            ;;
    esac
done

# Default: all test files
if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
    while IFS= read -r f; do
        TEST_FILES+=("$f")
    done < <(find "$TESTS_DIR" -name '*.bats' | sort)
fi

if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
    warn "No test files found in ${TESTS_DIR}"
    exit 0
fi

# -- Run tests ----------------------------------------------------------------
printf "\n${_cyan}=== gh-sync test suite ===${_reset}\n\n"
info "Running ${#TEST_FILES[@]} test file(s)..."
printf '\n'

"$BATS" "${BATS_ARGS[@]}" "${TEST_FILES[@]}"
EXIT_CODE=$?

printf '\n'
if [[ $EXIT_CODE -eq 0 ]]; then
    ok "All tests passed!"
else
    err "Some tests failed (exit code: ${EXIT_CODE})"
fi

exit $EXIT_CODE
