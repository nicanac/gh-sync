#!/usr/bin/env bash
# =============================================================================
# test_helper.bash — Shared fixtures and utilities for BATS tests
# =============================================================================

# -- Path to the script under test --------------------------------------------
GH_SYNC="${BATS_TEST_DIRNAME}/../gh-sync.sh"

# -- Temp directories created per-test ----------------------------------------
GOLDEN_SOURCE=""
PROJECT_ROOT=""
SECOND_PROJECT=""

# -- Setup: create isolated temp dirs and a minimal golden source -------------
setup_fixture() {
    GOLDEN_SOURCE="$(mktemp -d)"
    PROJECT_ROOT="$(mktemp -d)"
    SECOND_PROJECT="$(mktemp -d)"

    # Create a golden source with two sync folders
    mkdir -p "${GOLDEN_SOURCE}/.github/agents"
    mkdir -p "${GOLDEN_SOURCE}/.agents/skills"
    mkdir -p "${GOLDEN_SOURCE}/.claude"

    echo "github-file-v1" > "${GOLDEN_SOURCE}/.github/copilot-instructions.md"
    echo "agent-skill-v1" > "${GOLDEN_SOURCE}/.github/agents/my-agent.md"
    echo "skill-content-v1" > "${GOLDEN_SOURCE}/.agents/skills/my-skill.md"
    echo "claude-content-v1" > "${GOLDEN_SOURCE}/.claude/settings.json"

    # Point gh-sync at our fixture golden source
    export GH_SYNC_SOURCE="${GOLDEN_SOURCE}"
}

# -- Teardown: remove all temp dirs -------------------------------------------
teardown_fixture() {
    [[ -n "${GOLDEN_SOURCE}" && -d "${GOLDEN_SOURCE}" ]] && rm -rf -- "${GOLDEN_SOURCE}"
    [[ -n "${PROJECT_ROOT}"  && -d "${PROJECT_ROOT}"  ]] && rm -rf -- "${PROJECT_ROOT}"
    [[ -n "${SECOND_PROJECT}" && -d "${SECOND_PROJECT}" ]] && rm -rf -- "${SECOND_PROJECT}"
    unset GH_SYNC_SOURCE
}

# -- Run gh-sync with force (no confirmation prompts) -------------------------
run_gh_sync() {
    run bash "${GH_SYNC}" "$@"
}

# -- Assert file exists with optional content ---------------------------------
assert_file_exists() {
    local path="$1"
    [[ -f "$path" ]] || { echo "Expected file to exist: $path" >&3; return 1; }
}

assert_file_not_exists() {
    local path="$1"
    [[ ! -f "$path" ]] || { echo "Expected file NOT to exist: $path" >&3; return 1; }
}

assert_file_contains() {
    local path="$1"
    local content="$2"
    assert_file_exists "$path"
    grep -qF "$content" "$path" || { echo "Expected '$content' in $path" >&3; return 1; }
}

# -- Count files in a directory -----------------------------------------------
count_files_in() {
    find "$1" -type f 2>/dev/null | wc -l | tr -d '[:space:]'
}
