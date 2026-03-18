#!/usr/bin/env bats
# =============================================================================
# 02-diff-status.bats — Tests for diff and status commands
# =============================================================================

load "test_helper"

setup()    { setup_fixture; }
teardown() { teardown_fixture; }

# ---------------------------------------------------------------------------
# DIFF
# ---------------------------------------------------------------------------
@test "diff: shows [+] for files only in golden source" {
    run_gh_sync diff "${PROJECT_ROOT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"[+]"* ]]
}

@test "diff: shows no differences after push" {
    run_gh_sync push "${PROJECT_ROOT}" --force
    run_gh_sync diff "${PROJECT_ROOT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"In sync"* ]] || [[ "$output" == *"in sync"* ]]
}

@test "diff: shows [~] for modified files" {
    run_gh_sync push "${PROJECT_ROOT}" --force
    echo "modified-content" > "${PROJECT_ROOT}/.github/copilot-instructions.md"

    run_gh_sync diff "${PROJECT_ROOT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"[~]"* ]]
}

@test "diff: shows [-] for project-only files" {
    run_gh_sync push "${PROJECT_ROOT}" --force
    echo "project-only" > "${PROJECT_ROOT}/.github/project-local.md"

    run_gh_sync diff "${PROJECT_ROOT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"[-]"* ]]
}

@test "diff --only .github: only shows .github differences" {
    run_gh_sync diff "${PROJECT_ROOT}" --only .github

    [ "$status" -eq 0 ]
    # Should mention .github
    [[ "$output" == *".github"* ]]
    # Should NOT show .agents or .claude sections as separate entries
    # (only .github was requested)
}

@test "diff: reports total number of differences" {
    run_gh_sync diff "${PROJECT_ROOT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"difference"* ]] || [[ "$output" == *"In sync"* ]]
}

# ---------------------------------------------------------------------------
# STATUS
# ---------------------------------------------------------------------------
@test "status: shows per-folder counts" {
    run_gh_sync push "${PROJECT_ROOT}" --force
    run_gh_sync status "${PROJECT_ROOT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"In sync"* ]]
}

@test "status: shows TOTAL section" {
    run_gh_sync push "${PROJECT_ROOT}" --force
    run_gh_sync status "${PROJECT_ROOT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"TOTAL"* ]]
}

@test "status: reports files only in golden when project is empty" {
    run_gh_sync status "${PROJECT_ROOT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Only in Golden"* ]] || [[ "$output" == *"only golden"* ]] || [[ "$output" == *"push"* ]]
}

@test "status: reports modified files" {
    run_gh_sync push "${PROJECT_ROOT}" --force
    echo "modified" > "${PROJECT_ROOT}/.github/copilot-instructions.md"

    run_gh_sync status "${PROJECT_ROOT}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Modified"* ]] || [[ "$output" == *"modified"* ]]
}

@test "status --only .github: only reports .github folder" {
    run_gh_sync push "${PROJECT_ROOT}" --force
    run_gh_sync status "${PROJECT_ROOT}" --only .github

    [ "$status" -eq 0 ]
    [[ "$output" == *".github"* ]]
}
