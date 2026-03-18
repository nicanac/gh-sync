#!/usr/bin/env bats
# =============================================================================
# 04-backup-restore.bats — Tests for backups, restore, and clean commands
# =============================================================================

load "test_helper"

setup()    { setup_fixture; }
teardown() {
    teardown_fixture
    # Clean up any test backups created during tests
    find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'gh-sync-backup-*' -newer /tmp 2>/dev/null | \
        xargs rm -rf 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Backups
# ---------------------------------------------------------------------------
@test "push: creates a backup before syncing" {
    # First push: populate project
    run_gh_sync push "${PROJECT_ROOT}" --force

    # Modify project and push again to trigger backup
    echo "modified" > "${PROJECT_ROOT}/.github/copilot-instructions.md"
    run_gh_sync push "${PROJECT_ROOT}" --force

    # A backup should exist
    local backup_count
    backup_count="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'gh-sync-backup-github-*' 2>/dev/null | wc -l | tr -d '[:space:]')"
    [ "$backup_count" -ge 1 ]
}

@test "backups: lists available backups" {
    run_gh_sync push "${PROJECT_ROOT}" --force
    echo "modified" > "${PROJECT_ROOT}/.github/copilot-instructions.md"
    run_gh_sync push "${PROJECT_ROOT}" --force

    run_gh_sync backups

    [ "$status" -eq 0 ]
}

@test "backups: reports no backups when none exist" {
    # Clean all backups first
    find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'gh-sync-backup-*' 2>/dev/null | xargs rm -rf 2>/dev/null || true

    run_gh_sync backups

    [ "$status" -eq 0 ]
    [[ "$output" == *"No backups"* ]] || [[ "$output" == *"no backups"* ]]
}

# ---------------------------------------------------------------------------
# Restore
# ---------------------------------------------------------------------------
@test "restore --dry-run: does not modify project" {
    # Populate and create a backup
    run_gh_sync push "${PROJECT_ROOT}" --force
    echo "v2" > "${PROJECT_ROOT}/.github/copilot-instructions.md"
    run_gh_sync push "${PROJECT_ROOT}" --force

    # Get current state
    local before_content
    before_content="$(cat "${PROJECT_ROOT}/.github/copilot-instructions.md")"

    run_gh_sync restore "${PROJECT_ROOT}" --latest --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" == *"Dry-run"* ]] || [[ "$output" == *"dry-run"* ]]

    # Project should be unchanged
    local after_content
    after_content="$(cat "${PROJECT_ROOT}/.github/copilot-instructions.md")"
    [ "$before_content" = "$after_content" ]
}

@test "restore --latest: restores most recent backup" {
    # Push v1 to project
    run_gh_sync push "${PROJECT_ROOT}" --force

    # Overwrite with v2 and push again (creates backup of v1)
    echo "v2" > "${GOLDEN_SOURCE}/.github/copilot-instructions.md"
    run_gh_sync push "${PROJECT_ROOT}" --force

    # Project now has v2; latest backup has v1
    assert_file_contains "${PROJECT_ROOT}/.github/copilot-instructions.md" "v2"

    # Restore from latest backup
    run_gh_sync restore "${PROJECT_ROOT}" --latest --force

    [ "$status" -eq 0 ]
    # After restore, file should be from backup (v1 content)
    assert_file_contains "${PROJECT_ROOT}/.github/copilot-instructions.md" "github-file-v1"
}

# ---------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------
@test "clean --all --dry-run: reports backups that would be removed" {
    run_gh_sync push "${PROJECT_ROOT}" --force
    echo "v2" > "${GOLDEN_SOURCE}/.github/copilot-instructions.md"
    run_gh_sync push "${PROJECT_ROOT}" --force

    run_gh_sync clean --all --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" == *"Dry-run"* ]] || [[ "$output" == *"dry-run"* ]] || [[ "$output" == *"Would remove"* ]]
}

@test "clean --all: removes all backups" {
    run_gh_sync push "${PROJECT_ROOT}" --force
    echo "v2" > "${GOLDEN_SOURCE}/.github/copilot-instructions.md"
    run_gh_sync push "${PROJECT_ROOT}" --force

    # Verify at least one backup exists
    local before
    before="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'gh-sync-backup-*' 2>/dev/null | wc -l | tr -d '[:space:]')"
    [ "$before" -ge 1 ]

    run_gh_sync clean --all --force

    [ "$status" -eq 0 ]

    local after
    after="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'gh-sync-backup-*' 2>/dev/null | wc -l | tr -d '[:space:]')"
    [ "$after" -eq 0 ]
}

@test "clean: nothing to clean when no backups exist" {
    find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'gh-sync-backup-*' 2>/dev/null | xargs rm -rf 2>/dev/null || true

    run_gh_sync clean --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing to clean"* ]] || [[ "$output" == *"no backups"* ]] || [[ "$output" == *"No backups"* ]]
}
