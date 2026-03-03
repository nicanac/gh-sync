# gh-sync — AI Config Folders Sync Tool

Synchronize shared AI configuration folders across all your projects.

One **golden source** directory is the single source of truth. It contains up to four folders:

| Folder | Purpose |
|--------|---------|
| `.github/` | GitHub Copilot agents, skills, memory-bank, instructions |
| `.agent/` | VS Code agent rules, skills, workflows |
| `.agents/` | Additional agent skills |
| `.claude/` | Claude Code skills |

Push them all to any project in one command, or pull changes back.

---

## Requirements

- **Bash 4+** (macOS: install via `brew install bash`)
- Standard Unix utilities: `find`, `stat`, `md5sum` (or `md5` on macOS), `awk`, `sort`
- Works on: Linux, macOS, WSL, Git Bash (Windows)

---

## Installation

### Option A: One-liner

```bash
bash install.sh
```

### Option B: Manual

```bash
cp gh-sync.sh ~/.local/bin/gh-sync
chmod +x ~/.local/bin/gh-sync
# Ensure ~/.local/bin is on your PATH
```

---

## First-time Setup

After installing, run this once in any terminal:

```bash
gh-sync init
```

It will ask you for the path to your golden source **directory** (the parent folder that contains `.github/`, `.agent/`, etc.).
Example: `~/code/ai-startup`

This saves the path in `~/.gh-sync-config` so it persists globally.

> **Project-Level Override:** Create a `.gh-sync.json` file in a project's root folder to define project-specific defaults:
> ```json
> {
>   "golden_source": "~/alternative-golden-source",
>   "exclude": ["*.log", "temp/*"],
>   "only": [".github", ".agents"]
> }
> ```
> CLI flags always override configuration file settings.

> **Alternative:** Set the environment variable `GH_SYNC_SOURCE` instead.

The `init` command shows which of the four folders exist in your golden source and how many files each has.

---

## Usage

Open any terminal, `cd` into a project folder, then:

| Command | Description |
|---------|-------------|
| `gh-sync push` | Copy all golden folders → current project |
| `gh-sync pull` | Copy current project folders → golden source |
| `gh-sync diff` | Show file-by-file differences per folder |
| `gh-sync status` | Quick overview (in-sync, modified, missing — per folder + totals) |
| `gh-sync init` | (Re)configure the golden source path |
| `gh-sync backups` | List available restore points |
| `gh-sync restore` | Restore a specific backup |
| `gh-sync clean` | Manage and rotate old backups |

### Options

| Flag | Description |
|------|-------------|
| `--dry-run` | Preview what would change, without modifying files |
| `--force` | Skip the "Proceed? [y/N]" confirmation prompt |
| `--exclude pat1,pat2` | Exclude files matching patterns (comma-separated) |
| `--only f1,f2` | Sync only specified folders (e.g., `.github,.agents`) |
| `-h`, `--help` | Show help message |
| `-v`, `--version` | Show version |

### Examples

```bash
# Push all golden folders to the current project
gh-sync push

# Push to a specific project
gh-sync push ~/projects/my-app

# See what's different across all folders
gh-sync diff

# Preview a push without making changes
gh-sync push --dry-run

# Push without confirmation
gh-sync push --force

# Pull project changes back into golden source
gh-sync pull

# Exclude files matching patterns
gh-sync push --exclude "*.log,node_modules/*"

# Sync ONLY the .github folder (ignore .agent, .agents, .claude)
gh-sync push --only .github

# Check sync status for specific folders
gh-sync status --only .github,.agents

# List available backups and restore one
gh-sync backups
gh-sync restore 1
gh-sync restore .github --latest

# Keep only the 5 most recent backups per folder
gh-sync clean --keep 5
```

---

## How it works

- **Multi-folder sync** — syncs `.github`, `.agent`, `.agents`, `.claude` in one go
- **Hash comparison** — only files that actually changed are copied (md5sum / md5 / shasum)
- **Backup before sync** — a timestamped backup per folder is saved in `$TMPDIR/gh-sync-backup-*`
- **Non-destructive** — files that exist only in the target are flagged but never deleted
- **No hardcoded paths** — each user configures their own golden source via `gh-sync init`
- **Per-folder reporting** — diff, status and push/pull show results per folder plus a grand total
- **Cross-platform** — works on Linux, macOS, WSL, and Git Bash on Windows
- **Defensive coding** — strict mode (`set -Eeuo pipefail`), error traps, proper quoting

---

## File legend in diff output

| Symbol | Meaning |
|--------|---------|
| `[+]` | File only in golden source (will be copied on push) |
| `[-]` | File only in project (won't be deleted) |
| `[~]` | File modified (shows which side is newer) |

---

## Uninstall

```bash
rm -f ~/.local/bin/gh-sync    # or ~/bin/gh-sync
rm -f ~/.gh-sync-config
```

Optionally remove the PATH line added to your shell RC file (`~/.bashrc`, `~/.zshrc`, etc.).
