# 01 — Project Overview

## What is gh-sync?

**gh-sync** is a cross-platform CLI tool that synchronizes AI-related configuration folders between a single **golden source** directory and any number of project directories.

In modern AI-assisted development, tools like GitHub Copilot, Claude Code, and VS Code agents rely on configuration files stored inside the project (`.github/`, `.agent/`, `.agents/`, `.claude/`). These files define:

- Agent behaviors and rules
- Reusable skills and workflows
- Memory banks and instructions
- Prompt templates

Maintaining these configs individually across dozens of projects is painful. **gh-sync** solves this by introducing a **single source of truth** (the "golden source") and bidirectional sync.

---

## The Problem

Imagine you have 15 projects and you want each to share the same AI agent skills, GitHub Copilot instructions, and Claude prompt templates. Without gh-sync, you would:

1. Manually copy files every time you update an agent skill
2. Forget which projects have the latest version
3. Risk config drift — projects gradually diverge
4. Spend time debugging why Copilot/Claude behaves differently per project

---

## The Solution

```
┌──────────────────────────────────┐
│       GOLDEN SOURCE              │
│  ~/ai-config-hub/                │
│  ├── .github/   (Copilot)        │
│  ├── .agent/    (VS Code)        │
│  ├── .agents/   (Skills)         │
│  └── .claude/   (Claude Code)    │
└──────────┬───────────────────────┘
           │  gh-sync push / pull
           │
    ┌──────┼──────────────────────┐
    │      │                      │
    ▼      ▼                      ▼
┌────────┐ ┌────────┐       ┌────────┐
│ Proj A │ │ Proj B │  ...  │ Proj N │
└────────┘ └────────┘       └────────┘
```

With gh-sync, you:

1. **Edit once** in the golden source
2. `gh-sync push` to propagate to any project
3. `gh-sync pull` to bring project-level improvements back
4. `gh-sync diff` / `gh-sync status` to see what's changed

---

## Key Features

| Feature | Description |
|---------|-------------|
| **Multi-folder sync** | Syncs `.github`, `.agent`, `.agents`, `.claude` in one command |
| **Selective sync** | Sync only specific folders (e.g. `--only .github`) |
| **Hash-based comparison** | Only files that actually changed are copied (MD5/SHA) |
| **Backup management** | Automatically backs up target folders, with CLI commands to list, restore, and clean backups |
| **Per-project config** | Support `.gh-sync.json` for per-project configuration defaults |
| **Non-destructive** | Files that exist only in the target are flagged but **never** deleted |
| **Cross-platform** | Bash (Linux, macOS, WSL, Git Bash) + PowerShell (Windows native) |
| **Dry-run mode** | Preview changes without writing anything |
| **Exclusion patterns** | Skip files matching glob patterns |
| **Per-folder reporting** | Results are broken down per sync folder with a grand total |
| **Defensive coding** | `set -Eeuo pipefail`, error traps, proper quoting |

---

## Design Philosophy

1. **Zero dependencies beyond the OS** — No Node.js, no Python, no package managers. Just bash or PowerShell.
2. **Safety first** — Dry-run, confirmation prompts, automatic backups, non-destructive defaults.
3. **Performance** — Batch hashing and stat calls instead of per-file subprocess spawning.
4. **Simplicity** — A single script per platform. No build step, no compilation.
5. **Portability** — Handles path normalization (Windows backslashes), cross-platform hash commands, Darwin vs GNU differences.

---

## Who Is This For?

- **Solo developers** maintaining AI configs across multiple projects
- **Teams** sharing a standardized AI agent/skill setup
- **AI tool enthusiasts** using Copilot, Claude, and custom VS Code agents who want consistency

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026 | Initial release with push, pull, diff, status, init |
| 2.0.0 | 2026 | Added selective sync (`--only`), backup management (`backups`, `restore`, `clean`), `.gh-sync.json` configs, and PS optimizations |
