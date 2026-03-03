# 03 — File Structure

Every file and directory in the gh-sync project, explained in detail.

---

## Root Directory Layout

```
gh-sync/
│
│   ── Core Scripts ──────────────────────────────────────
├── gh-sync.sh            # Main Bash implementation (950 lines)
├── gh-sync.ps1           # Main PowerShell implementation (579 lines)
├── gh-sync.cmd           # Windows CMD wrapper → calls gh-sync.ps1
│
│   ── Installers ────────────────────────────────────────
├── install.sh            # Bash installer for Linux/macOS/WSL (136 lines)
├── install.ps1           # PowerShell installer for Windows (71 lines)
├── install.cmd           # Windows CMD wrapper → calls install.ps1
│
│   ── Documentation ────────────────────────────────────
├── README.md             # End-user documentation (146 lines)
│
│   ── Metadata ──────────────────────────────────────────
├── skills-lock.json      # Lock file for installed agent skills
│
│   ── Golden Source Content (synced folders) ────────────
├── .github/              # GitHub Copilot agents, prompts, instructions
│   ├── agents/           # 10 agent definition files
│   └── prompts/          # 9 prompt template files
│
├── .agent/               # VS Code agent-specific config
│   └── skills/           # VS Code agent skills
│       └── c4-architecture/
│
├── .agents/              # Shared agent skills
│   └── skills/           # 5 installed skills
│       ├── c4-architecture/
│       ├── tailwind-design-system/
│       ├── ui-ux-pro-max/
│       ├── vercel-deployment/
│       └── vercel-react-best-practices/
│
├── .claude/              # Claude Code config
│   └── skills/           # Claude-specific skills
│
│   ── Git / Hidden ──────────────────────────────────────
├── .git/                 # Git repository
└── .claude/              # Claude Code configuration
```

---

## File-by-File Breakdown

### `gh-sync.sh` — Bash Implementation

| Property | Value |
|----------|-------|
| **Language** | Bash 4+ |
| **Size** | ~950 lines, ~32 KB |
| **Platforms** | Linux, macOS, WSL, Git Bash (MINGW64) |
| **Entry point** | `main()` function at line 905 |

This is the **primary** implementation. It contains:
- Constants definition (`SYNC_FOLDERS`, `CONFIG_FILE`, `VERSION`)
- Color-coded logging helpers
- Temp dir management with cleanup traps
- Argument parser (`parse_args`)
- Golden source resolution (`get_golden_source`)
- Path normalization for Windows/MINGW compatibility
- Batched file collection with `find + md5sum/stat + awk` (`get_all_files`)
- Folder comparison using `comm` and `join` (`compare_folders`)
- Sync engine with backup support (`sync_folder`)
- Five action dispatchers: `do_init`, `do_push`, `do_pull`, `do_diff`, `do_status`

### `gh-sync.ps1` — PowerShell Implementation

| Property | Value |
|----------|-------|
| **Language** | PowerShell |
| **Size** | ~579 lines, ~20 KB |
| **Platforms** | Windows (PowerShell 5.1+) |
| **Entry point** | Script-level `param()` block + `if/elseif` action routing |

Feature-parity PowerShell port. Uses:
- `CmdletBinding` with `[ValidateSet]` for action validation
- `Get-ChildItem` + `Get-FileHash` instead of `find + md5sum`
- PowerShell `[PSCustomObject]` arrays for file metadata
- Same `Compare-Folders` / `Invoke-SyncFolder` pattern
- Identical logging function signatures

### `gh-sync.cmd` — Windows CMD Wrapper

| Property | Value |
|----------|-------|
| **Size** | 6 lines |
| **Purpose** | Allows running `gh-sync` from `cmd.exe` |

```bat
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0gh-sync.ps1" %*
```

Simply forwards all arguments to `gh-sync.ps1` via PowerShell. The `-ExecutionPolicy Bypass` flag ensures it works even on systems with restricted script execution policies.

### `install.sh` — Bash Installer

| Property | Value |
|----------|-------|
| **Size** | ~136 lines, ~4.7 KB |
| **Installs to** | `~/.local/bin/gh-sync` (or `~/bin/gh-sync`) |

Steps:
1. Creates bin directory (`~/.local/bin` or `~/bin`)
2. Copies `gh-sync.sh` → `gh-sync` with execute permissions
3. Adds bin directory to `PATH` in the appropriate shell RC file (`.bashrc`, `.zshrc`, `.bash_profile`, `config.fish`)
4. Prints next-step instructions

### `install.ps1` — PowerShell Installer

| Property | Value |
|----------|-------|
| **Size** | ~71 lines, ~2.9 KB |
| **Installs to** | `%USERPROFILE%\bin\` |

Steps:
1. Creates `~/bin` directory
2. Copies `gh-sync.ps1` and `gh-sync.cmd` to `~/bin`
3. Adds `~/bin` to the user-level `PATH` environment variable
4. Prints next-step instructions

### `install.cmd` — Windows CMD Installer Wrapper

| Property | Value |
|----------|-------|
| **Size** | 8 lines |
| **Purpose** | Double-clickable installer for Windows |

Delegates to `install.ps1` and pauses at the end so the user can read the output.

### `README.md` — User-Facing README

| Property | Value |
|----------|-------|
| **Size** | ~146 lines, ~4.1 KB |

Standard GitHub README with:
- Requirements
- Installation instructions (one-liner and manual)
- First-time setup (`gh-sync init`)
- Usage table (push, pull, diff, status, init)
- Options table (--dry-run, --force, --exclude, -h, -v)
- How-it-works summary
- Diff output legend ([+], [-], [~])
- Uninstall instructions

### `skills-lock.json` — Skills Lock File

```json
{
  "version": 1,
  "skills": {
    "c4-architecture": {
      "source": "softaworks/agent-toolkit",
      "sourceType": "github",
      "computedHash": "9192b5d6..."
    }
  }
}
```

Tracks installed agent skills with their source repositories and content hashes. Similar in concept to `package-lock.json` — ensures reproducible skill installations.

---

## Synced Folder Contents

These are the **golden source**'s synced directories. They are themselves part of the gh-sync project repo, acting as the reference copy.

### `.github/agents/` — 10 Copilot Agent Definitions

| File | Size | Purpose |
|------|------|---------|
| `copilot-instructions.md` | 853 B | General Copilot instructions/rules |
| `speckit.analyze.agent.md` | 7.2 KB | SpecKit analysis agent |
| `speckit.checklist.agent.md` | 16.8 KB | SpecKit checklist agent |
| `speckit.clarify.agent.md` | 11.3 KB | SpecKit clarification agent |
| `speckit.constitution.agent.md` | 5.5 KB | SpecKit constitutional rules agent |
| `speckit.implement.agent.md` | 7.5 KB | SpecKit implementation agent |
| `speckit.plan.agent.md` | 3.4 KB | SpecKit planning agent |
| `speckit.specify.agent.md` | 12.9 KB | SpecKit specification agent |
| `speckit.tasks.agent.md` | 6.4 KB | SpecKit task management agent |
| `speckit.taskstoissues.agent.md` | 1.1 KB | SpecKit tasks-to-issues converter agent |

### `.github/prompts/` — 9 Prompt Templates

Each prompt is a minimal trigger file (28–37 bytes) paired with its corresponding agent:

| File | Paired Agent |
|------|-------------|
| `speckit.analyze.prompt.md` | speckit.analyze.agent |
| `speckit.checklist.prompt.md` | speckit.checklist.agent |
| `speckit.clarify.prompt.md` | speckit.clarify.agent |
| `speckit.constitution.prompt.md` | speckit.constitution.agent |
| `speckit.implement.prompt.md` | speckit.implement.agent |
| `speckit.plan.prompt.md` | speckit.plan.agent |
| `speckit.specify.prompt.md` | speckit.specify.agent |
| `speckit.tasks.prompt.md` | speckit.tasks.agent |
| `speckit.taskstoissues.prompt.md` | speckit.taskstoissues.agent |

### `.agents/skills/` — 5 Installed Skills

| Skill | Files | Purpose |
|-------|-------|---------|
| `c4-architecture` | 5 files | Generate C4 architecture diagrams |
| `tailwind-design-system` | 1 file | Build Tailwind CSS v4 design systems |
| `ui-ux-pro-max` | 3 files | UI/UX design intelligence (50 styles, 21 palettes, etc.) |
| `vercel-deployment` | 1 file | Deploy to Vercel with Next.js |
| `vercel-react-best-practices` | 60 files | React/Next.js performance optimization guidelines |

### `.agent/skills/` — VS Code Agent Skills

Contains the `c4-architecture` skill definition for the VS Code agent system.

### `.claude/skills/` — Claude Code Skills

Reserved directory for Claude Code-specific skill definitions.
