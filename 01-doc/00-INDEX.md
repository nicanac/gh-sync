# 📚 gh-sync — Complete Project Documentation

> **Last Updated:** 2026-03-03  
> **Project Version:** 1.0.0  
> **Purpose:** Synchronize shared AI configuration folders across all your projects.

---

## Documentation Index

This folder contains a comprehensive documentation suite for the **gh-sync** project. Each document covers a specific aspect in depth so that any new developer can get up to speed quickly.

| # | Document | Description |
|---|----------|-------------|
| 01 | [Project Overview](./01-PROJECT-OVERVIEW.md) | What gh-sync is, why it exists, and the problem it solves |
| 02 | [Architecture](./02-ARCHITECTURE.md) | C4 diagrams, system design, and data flow |
| 03 | [File Structure](./03-FILE-STRUCTURE.md) | Every file and directory explained |
| 04 | [Core Concepts](./04-CORE-CONCEPTS.md) | Golden source, sync folders, hash comparison, backups |
| 05 | [CLI Reference](./05-CLI-REFERENCE.md) | All commands, options, and examples |
| 06 | [Bash Implementation](./06-BASH-IMPLEMENTATION.md) | Deep dive into `gh-sync.sh` (~950 lines) |
| 07 | [PowerShell Implementation](./07-POWERSHELL-IMPLEMENTATION.md) | Deep dive into `gh-sync.ps1` (~579 lines) |
| 08 | [Installation Guide](./08-INSTALLATION-GUIDE.md) | All install methods on every platform |
| 09 | [Golden Source Content](./09-GOLDEN-SOURCE-CONTENT.md) | What the synced folders contain (agents, skills, prompts) |
| 10 | [Developer Guide](./10-DEVELOPER-GUIDE.md) | How to contribute, coding conventions, extending the tool |
| 11 | [Improvement Plan](./11-IMPROVEMENT-PLAN.md) | 5 prioritized improvements with 25 sub-tasks |

---

## Quick Start

```bash
# 1. Install (Linux/macOS/WSL)
bash install.sh

# 2. Configure golden source
gh-sync init

# 3. Sync to a project
cd ~/projects/my-app
gh-sync push
```

```powershell
# 1. Install (Windows)
.\install.cmd

# 2. Configure golden source
gh-sync init

# 3. Sync to a project
cd C:\Projects\MyApp
gh-sync push
```

---

## At a Glance

```
gh-sync
├── gh-sync.sh        # Bash implementation (Linux/macOS/WSL/Git Bash)
├── gh-sync.ps1       # PowerShell implementation (Windows native)
├── gh-sync.cmd       # Windows CMD wrapper for PowerShell
├── install.sh        # Bash installer
├── install.ps1       # PowerShell installer
├── install.cmd       # Windows CMD installer wrapper
├── README.md         # End-user README
├── skills-lock.json  # Lockfile for installed agent skills
├── .github/          # GitHub Copilot agents & prompts (synced content)
├── .agent/           # VS Code agent config (synced content)
├── .agents/          # Additional agent skills (synced content)
└── .claude/          # Claude Code skills (synced content)
```
