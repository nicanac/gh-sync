#!/usr/bin/env bats
# =============================================================================
# 03-edge-cases.bats — Edge case tests (spaces, unicode, binary, empty dirs)
# =============================================================================

load "test_helper"

setup()    { setup_fixture; }
teardown() { teardown_fixture; }

# ---------------------------------------------------------------------------
# Filenames with spaces and special characters
# ---------------------------------------------------------------------------
@test "push: handles filenames with spaces" {
    echo "content with spaces" > "${GOLDEN_SOURCE}/.github/my file with spaces.md"

    run_gh_sync push "${PROJECT_ROOT}" --force

    assert_file_exists "${PROJECT_ROOT}/.github/my file with spaces.md"
    assert_file_contains "${PROJECT_ROOT}/.github/my file with spaces.md" "content with spaces"
}

@test "push: handles filenames with parentheses and brackets" {
    echo "special chars" > "${GOLDEN_SOURCE}/.github/file(1)[test].md"

    run_gh_sync push "${PROJECT_ROOT}" --force

    assert_file_exists "${PROJECT_ROOT}/.github/file(1)[test].md"
}

@test "push: handles deeply nested directory structures" {
    mkdir -p "${GOLDEN_SOURCE}/.github/a/b/c/d/e"
    echo "deep-nested" > "${GOLDEN_SOURCE}/.github/a/b/c/d/e/deep.md"

    run_gh_sync push "${PROJECT_ROOT}" --force

    assert_file_exists "${PROJECT_ROOT}/.github/a/b/c/d/e/deep.md"
    assert_file_contains "${PROJECT_ROOT}/.github/a/b/c/d/e/deep.md" "deep-nested"
}

@test "push: handles unicode filenames" {
    echo "unicode content" > "${GOLDEN_SOURCE}/.github/日本語.md"

    run_gh_sync push "${PROJECT_ROOT}" --force

    assert_file_exists "${PROJECT_ROOT}/.github/日本語.md"
}

# ---------------------------------------------------------------------------
# Binary files
# ---------------------------------------------------------------------------
@test "push: handles binary files (PNG)" {
    # Create a minimal binary file (8 bytes of arbitrary data)
    printf '\x89PNG\r\n\x1a\n' > "${GOLDEN_SOURCE}/.github/image.png"

    run_gh_sync push "${PROJECT_ROOT}" --force

    assert_file_exists "${PROJECT_ROOT}/.github/image.png"
}

# ---------------------------------------------------------------------------
# Empty directory behaviour
# ---------------------------------------------------------------------------
@test "push: skips folders not present in golden source" {
    # Only .github exists in our fixture golden source (no .agent folder)
    run_gh_sync push "${PROJECT_ROOT}" --only .agent --force

    [ "$status" -eq 0 ]
    # Should not error — just skip the missing folder
    [[ "$output" == *"Skipping"* ]] || [[ "$output" == *"nothing"* ]] || [[ "$output" == *"in sync"* ]]
}

@test "push: golden source with no files in a folder completes cleanly" {
    # Create an empty .agent folder
    mkdir -p "${GOLDEN_SOURCE}/.agent"

    run_gh_sync push "${PROJECT_ROOT}" --only .agent --force

    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Idempotency
# ---------------------------------------------------------------------------
@test "push is idempotent: running twice gives same result" {
    run_gh_sync push "${PROJECT_ROOT}" --force
    local count_after_first
    count_after_first="$(count_files_in "${PROJECT_ROOT}")"

    run_gh_sync push "${PROJECT_ROOT}" --force
    local count_after_second
    count_after_second="$(count_files_in "${PROJECT_ROOT}")"

    [ "$count_after_first" -eq "$count_after_second" ]
}

@test "push then pull restores golden source to original state" {
    # Capture original golden source state
    local before_count
    before_count="$(count_files_in "${GOLDEN_SOURCE}")"

    # Push to project, then pull back
    run_gh_sync push "${PROJECT_ROOT}" --force
    run_gh_sync pull "${PROJECT_ROOT}" --force

    local after_count
    after_count="$(count_files_in "${GOLDEN_SOURCE}")"

    [ "$before_count" -eq "$after_count" ]
}

# ---------------------------------------------------------------------------
# Config and validation
# ---------------------------------------------------------------------------
@test "missing golden source: exits with non-zero status and helpful message" {
    unset GH_SYNC_SOURCE

    run_gh_sync push "${PROJECT_ROOT}" --force

    [ "$status" -ne 0 ]
    [[ "$output" == *"not configured"* ]] || [[ "$output" == *"Golden source"* ]]
}

@test "missing project path: exits with non-zero status" {
    run_gh_sync push "/nonexistent/path/$(date +%s)" --force

    [ "$status" -ne 0 ]
}

@test "unknown action: exits with non-zero status" {
    run_gh_sync notanaction

    [ "$status" -ne 0 ]
}

@test "--help: exits with zero status and shows usage" {
    run_gh_sync --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]]
}

@test "--version: shows version string" {
    run_gh_sync --version

    [ "$status" -eq 0 ]
    [[ "$output" == *"gh-sync"* ]]
}

# ---------------------------------------------------------------------------
# Per-project config file
# ---------------------------------------------------------------------------
@test ".gh-sync.json: exclude patterns are respected" {
    echo "temp-data" > "${GOLDEN_SOURCE}/.github/temp.log"

    # Create per-project config
    cat > "${PROJECT_ROOT}/.gh-sync.json" <<'EOF'
{"exclude": ["*.log"]}
EOF

    run_gh_sync push "${PROJECT_ROOT}" --force

    assert_file_exists "${PROJECT_ROOT}/.github/copilot-instructions.md"
    assert_file_not_exists "${PROJECT_ROOT}/.github/temp.log"
}

@test ".gh-sync.json: only folders setting is respected" {
    cat > "${PROJECT_ROOT}/.gh-sync.json" <<'EOF'
{"only": [".github"]}
EOF

    run_gh_sync push "${PROJECT_ROOT}" --force

    assert_file_exists "${PROJECT_ROOT}/.github/copilot-instructions.md"
    assert_file_not_exists "${PROJECT_ROOT}/.agents/skills/my-skill.md"
}

@test "CLI flags override .gh-sync.json settings" {
    # Config says only .github
    cat > "${PROJECT_ROOT}/.gh-sync.json" <<'EOF'
{"only": [".github"]}
EOF

    # CLI says sync .agents — CLI should win
    run_gh_sync push "${PROJECT_ROOT}" --only .agents --force

    assert_file_not_exists "${PROJECT_ROOT}/.github/copilot-instructions.md"
    assert_file_exists "${PROJECT_ROOT}/.agents/skills/my-skill.md"
}
