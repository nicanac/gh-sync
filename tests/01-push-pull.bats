#!/usr/bin/env bats
# =============================================================================
# 01-push-pull.bats — Tests for push and pull operations
# =============================================================================

load "test_helper"

setup()    { setup_fixture; }
teardown() { teardown_fixture; }

# ---------------------------------------------------------------------------
# PUSH: new files are copied
# ---------------------------------------------------------------------------
@test "push: new files from golden source are copied to project" {
    run_gh_sync push "${PROJECT_ROOT}" --force

    assert_file_exists "${PROJECT_ROOT}/.github/copilot-instructions.md"
    assert_file_exists "${PROJECT_ROOT}/.github/agents/my-agent.md"
    assert_file_exists "${PROJECT_ROOT}/.agents/skills/my-skill.md"
    assert_file_exists "${PROJECT_ROOT}/.claude/settings.json"
}

@test "push: file content is preserved correctly" {
    run_gh_sync push "${PROJECT_ROOT}" --force

    assert_file_contains "${PROJECT_ROOT}/.github/copilot-instructions.md" "github-file-v1"
    assert_file_contains "${PROJECT_ROOT}/.agents/skills/my-skill.md" "skill-content-v1"
}

@test "push: modified files in golden source overwrite project files" {
    # First push to populate project
    run_gh_sync push "${PROJECT_ROOT}" --force

    # Update golden source
    echo "github-file-v2" > "${GOLDEN_SOURCE}/.github/copilot-instructions.md"

    # Push again
    run_gh_sync push "${PROJECT_ROOT}" --force

    assert_file_contains "${PROJECT_ROOT}/.github/copilot-instructions.md" "github-file-v2"
}

@test "push: target-only files are NOT deleted" {
    # Populate project first
    run_gh_sync push "${PROJECT_ROOT}" --force

    # Add a file only in the project
    echo "project-only-file" > "${PROJECT_ROOT}/.github/local-override.md"

    # Push again — should not delete the project-only file
    run_gh_sync push "${PROJECT_ROOT}" --force

    assert_file_exists "${PROJECT_ROOT}/.github/local-override.md"
}

@test "push: no-op when everything is in sync" {
    run_gh_sync push "${PROJECT_ROOT}" --force
    run_gh_sync push "${PROJECT_ROOT}" --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"already in sync"* ]]
}

@test "push --dry-run: does not modify files" {
    run_gh_sync push "${PROJECT_ROOT}" --dry-run

    # Project should still be empty after dry-run
    local count
    count="$(count_files_in "${PROJECT_ROOT}")"
    [ "$count" -eq 0 ]
}

@test "push --dry-run: reports what would be done" {
    run_gh_sync push "${PROJECT_ROOT}" --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" == *"Dry-run"* ]] || [[ "$output" == *"dry-run"* ]]
}

@test "push --only .github: only syncs .github folder" {
    run_gh_sync push "${PROJECT_ROOT}" --only .github --force

    assert_file_exists "${PROJECT_ROOT}/.github/copilot-instructions.md"
    assert_file_not_exists "${PROJECT_ROOT}/.agents/skills/my-skill.md"
    assert_file_not_exists "${PROJECT_ROOT}/.claude/settings.json"
}

@test "push --only .github,.agents: syncs two folders only" {
    run_gh_sync push "${PROJECT_ROOT}" --only .github,.agents --force

    assert_file_exists "${PROJECT_ROOT}/.github/copilot-instructions.md"
    assert_file_exists "${PROJECT_ROOT}/.agents/skills/my-skill.md"
    assert_file_not_exists "${PROJECT_ROOT}/.claude/settings.json"
}

@test "push --only with invalid folder name: exits with error" {
    run_gh_sync push "${PROJECT_ROOT}" --only .nonexistent --force

    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"invalid"* ]]
}

@test "push --exclude: excluded files are not copied" {
    echo "temp-data" > "${GOLDEN_SOURCE}/.github/temp.log"

    run_gh_sync push "${PROJECT_ROOT}" --exclude "*.log" --force

    assert_file_exists "${PROJECT_ROOT}/.github/copilot-instructions.md"
    assert_file_not_exists "${PROJECT_ROOT}/.github/temp.log"
}

# ---------------------------------------------------------------------------
# PULL: project changes go back to golden source
# ---------------------------------------------------------------------------
@test "pull: project files are copied to golden source" {
    # Populate project first
    run_gh_sync push "${PROJECT_ROOT}" --force

    # Modify a file in the project
    echo "project-modified-v2" > "${PROJECT_ROOT}/.github/copilot-instructions.md"

    # Pull back to golden
    run_gh_sync pull "${PROJECT_ROOT}" --force

    assert_file_contains "${GOLDEN_SOURCE}/.github/copilot-instructions.md" "project-modified-v2"
}

@test "pull: new project files are copied to golden source" {
    # Populate project first
    run_gh_sync push "${PROJECT_ROOT}" --force

    # Add a new file in the project
    echo "new-project-file" > "${PROJECT_ROOT}/.github/new-agent.md"

    # Pull back to golden
    run_gh_sync pull "${PROJECT_ROOT}" --force

    assert_file_exists "${GOLDEN_SOURCE}/.github/new-agent.md"
}

@test "pull --dry-run: does not modify golden source" {
    # Populate project first
    run_gh_sync push "${PROJECT_ROOT}" --force

    # Get current golden source hash
    local before_hash
    before_hash="$(find "${GOLDEN_SOURCE}" -type f -exec md5sum {} + 2>/dev/null | sort | md5sum)"

    # Modify project file and dry-run pull
    echo "project-modified" > "${PROJECT_ROOT}/.github/copilot-instructions.md"
    run_gh_sync pull "${PROJECT_ROOT}" --dry-run

    # Golden source should be unchanged
    local after_hash
    after_hash="$(find "${GOLDEN_SOURCE}" -type f -exec md5sum {} + 2>/dev/null | sort | md5sum)"
    [ "$before_hash" = "$after_hash" ]
}

@test "pull: no-op when everything is in sync" {
    run_gh_sync push "${PROJECT_ROOT}" --force
    run_gh_sync pull "${PROJECT_ROOT}" --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"already in sync"* ]]
}
