# gh-sync - .github Folder Sync Tool

Synchronize a shared `.github` folder (agents, skills, memory-bank, instructions) across all your projects.

One **golden source** folder is the single source of truth. Push it to any project, or pull changes back.

---

## Installation

### Option A: Double-click (easiest)
1. Double-click **`install.cmd`**
2. Done! Open a **new terminal**.

### Option B: PowerShell
```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

---

## First-time Setup

After installing, run this once in any terminal:

```bash
gh-sync init
```

It will ask you for the path to your golden `.github` folder.  
Example: `C:\Users\YourName\Documents\code\ai-startup\.github`

This saves the path in `~\.gh-sync-config` so it persists.

> **Alternative:** Set the environment variable `GH_SYNC_SOURCE` instead.

---

## Usage

Open any terminal, `cd` into a project folder, then:

| Command | Description |
|---------|-------------|
| `gh-sync push` | Copy golden `.github` -> current project |
| `gh-sync pull` | Copy current project `.github` -> golden source |
| `gh-sync diff` | Show file-by-file differences |
| `gh-sync status` | Quick overview (how many in-sync, modified, etc.) |
| `gh-sync init` | (Re)configure the golden source path |

### Options

| Flag | Description |
|------|-------------|
| `-DryRun` | Preview what would change, without modifying files |
| `-Force` | Skip the "Proceed? [y/N]" confirmation prompt |
| `-Exclude pattern1,pattern2` | Exclude files matching wildcard patterns |

### Examples

```bash
# Push golden source to the current project
gh-sync push

# Push to a specific project
gh-sync push C:\Projects\MyApp

# See what's different before pushing
gh-sync diff

# Preview a push without making changes
gh-sync push -DryRun

# Push without confirmation
gh-sync push -Force

# Pull project changes back into golden source
gh-sync pull
```

---

## How it works

- **MD5 hash comparison** -- only files that actually changed are copied
- **Backup before sync** -- a timestamped backup is saved in `%TEMP%\gh-sync-backup-*`
- **Non-destructive** -- files that exist only in the target are flagged but never deleted
- **No hardcoded paths** -- each user configures their own golden source via `gh-sync init`

---

## File legend in diff output

| Symbol | Meaning |
|--------|---------|
| `[+]` | File only in golden source (will be copied on push) |
| `[-]` | File only in project (won't be deleted) |
| `[~]` | File modified (shows which side is newer) |

---

## Uninstall

Delete these files:
- `%USERPROFILE%\bin\gh-sync.ps1`
- `%USERPROFILE%\bin\gh-sync.cmd`
- `%USERPROFILE%\.gh-sync-config`

Optionally remove `%USERPROFILE%\bin` from your PATH (System > Environment Variables).
