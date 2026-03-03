# 🤖 AI and Interactive Git Workflow Documentation

## Overview

This document provides a comprehensive description of the interactive and automated tools that come bundled with **gh-sync**. There are two major components added to improve user experience (both for humans and AI agents):

1. **Interactive TUI Wrappers** (`gh-sync-menu.sh` and `gh-sync-menu.ps1`)
2. **Intelligent Git Workflow Script** (`scripts/git-workflow.js`)

These tools are designed to streamline operations, reduce cognitive load, and provide robust APIs for AI tools to trigger complex multi-step actions effortlessly.

---

## 1. Interactive Menu (TUI Wrappers)

### Goal

To provide a menu-driven terminal interface (TUI) for users who prefer guided navigation rather than memorizing complex CLI commands and their flags.

### Capabilities

- **Cross-Platform**: Provided as both `gh-sync-menu.sh` (Bash) and `gh-sync-menu.ps1` (PowerShell).
- **Guided Workflows**: Interactive menus for running `push`, `pull`, `status`, and `diff`.
- **Advanced Prompts**: Users are natively prompted whether they want to use `--dry-run` or target specific folders (`--only`).
- **Backup Management Submenu**: A dedicated interface to view backups, restore them, or run cleanup tasks (`clean --keep N`).

### AI/Agent Context

As an AI, you generally **should not** invoke these interactive menus since they rely on reading from standard input for prompts. Always use the raw underlying CLI commands (`gh-sync diff`, `gh-sync push --only .github`) instead of the menu files. The menus are specifically for human developers to interact with the system comfortably.

---

## 2. Intelligent Git Workflow Integration (`git-workflow.js`)

### Goal

To enforce robust branching strategies (Git Flow) and message conventions (Conventional Commits) automatically while streamlining the branch -> commit -> push -> PR lifecycle. This directly resolves issues where teams using `gh-sync` misplace structural AI configuration files across badly named branches.

### Core Features

- **Git Flow Branching**: Asks for identifier, issue number, type of change, and a description. Automatically formulates standard branch names like `username/feature/TICKET-123-some-change`.
- **Intelligent Fallbacks**: Analyzes the status of `git diff` to suggest default descriptions or commit types (e.g. if `README.md` changed, it suggests `docs`).
- **Conventional Commits**: Enforces `type(scope): description` naming format for commits.
- **GitHub CLI Integration**: Automatically pushes the branch and can interactively optionally trigger `gh pr create` with metadata populated automatically.

### Usage for Developers (Interactive)

Developers run the script natively to be guided through the commit process:

```bash
node scripts/git-workflow.js
```

### AI Automation Mode (`--auto`)

#### Context for AI Tools
As an AI context agent, you are often requested to "Commit my changes" or "Push my work". This script provides a foolproof alias to do so without requiring multiple fragmented Bash commands.

When executing the script with the `--auto` (or `-y`) parameter, all interactive prompts are completely bypassed. The script will perform the following actions aggressively and safely:

1. Analyze if there are any changes via `git status --porcelain`.
2. Stage all modifications with `git add .`
3. Identify the current branch name.
4. Auto-generate a commit message: `chore: automated auto-commit on {branch_name} [skip ci]`
5. Push to the remote tracking branch via `git push -u origin HEAD`.

**Example AI Execution:**
```bash
node scripts/git-workflow.js --auto
```

This single command allows the AI to back up work intelligently without manual user intervention or managing git lifecycle complexities.
