---
description: gh-sync project rules and git workflow guidelines
---

# gh-sync Project Rules and Operational Guidelines

This workflow defines the operational rules for contributing to and manipulating the `gh-sync` project. As an AI agent, you MUST follow these instructions when working on this repository to maintain code parity, project consistency, and git history standards.

## 1. Core Project Mission
`gh-sync` is a robust, cross-platform synchronization tool specifically engineered for AI configuration folders (`.github`, `.agent`, `.agents`, `.claude`). It relies on strict file comparisons (via MD5 hashing or equivalent) and enforces non-destructive backup protocols before applying any changes.

## 2. Dual Platform Implementation
The core principle of `gh-sync` is complete parity across operating systems.
- **Bash Implementation**: `gh-sync.sh` handles Linux, macOS, WSL, and Git Bash.
- **PowerShell Implementation**: `gh-sync.ps1` handles native Windows environments.
- **If you implement a new feature, fix a bug, or change a CLI flag in one file, you MUST implement the exact same behavior in the other file.**

## 3. Git Workflow and Branching Rules
You *MUST* adhere closely to the Git Flow model:
1. **Never make untested changes directly to `main` or `master`.**
2. **Branching Format Required**: `username/<type>/[optional-ticket-]description`
   - Allowed Types: `feature` (or `feat`), `bugfix` (or `fix`), `hotfix`, `release`, `docs`, `chore`.
   - Examples: `dev/feature/add-sync-filters`, `ai/hotfix/fix-broken-powershell`
3. If not already on a feature branch, create one before starting significant work.

## 4. Committing and Pushing Changes (Using Automotive Tools)
This project enforces Conventional Commits (`type(scope): description`) and includes a custom automation pipeline. 
As an AI agent, **you should NOT use raw `git commit` and `git push` commands.**

Instead, use the included interactive script in unattended automation mode:
```bash
node scripts/git-workflow.js --auto
```
This automated command will:
1. Intelligently determine the files that have changed.
2. Stage all modifications automatically.
3. Determine your current operational branch.
4. Generate a valid, AI-compliant Conventional Commit (`chore: automated auto-commit on [branch]`).
5. Push the changes to the remote branch instantly.

## 5. Defensive Design Principles
- **Always back up before writing**: Never overwrite files in the golden source or destination without taking a timestamped backup in the system `$TMPDIR`.
- **Read-Only Diffs**: The `diff` and `status` commands must never make modifications to the system.
- **Interactive UI**: The `gh-sync-menu.sh` and `gh-sync-menu.ps1` wrappers provide guided experiences for humans. If you add heavy structural CLI flags, ensure these menus receive the new prompts.
- **Documentation**: All new features must be documented in the `01-doc/` folder and registered in the `00-INDEX.md` and `README.md`.