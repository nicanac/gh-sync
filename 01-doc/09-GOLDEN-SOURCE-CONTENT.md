# 09 — Golden Source Content

This document describes what the synced AI configuration folders contain and how they are used by different AI tools.

---

## Overview

The gh-sync golden source directory contains up to four folders, each targeting a different AI coding assistant ecosystem:

```
golden-source/
├── .github/     →  GitHub Copilot
├── .agent/      →  VS Code Agent (Antigravity)
├── .agents/     →  Cross-platform agent skills
└── .claude/     →  Claude Code
```

---

## `.github/` — GitHub Copilot Configuration

### Purpose

GitHub Copilot looks for configuration in the `.github/` directory of each repository. This includes **Copilot agents** (custom AI personas with specific instructions) and **prompts** (reusable prompt templates).

### Structure

```
.github/
├── agents/                         # Agent definitions
│   ├── copilot-instructions.md     # General Copilot instructions
│   ├── speckit.analyze.agent.md    # Analysis agent
│   ├── speckit.checklist.agent.md  # Checklist agent
│   ├── speckit.clarify.agent.md    # Clarification agent
│   ├── speckit.constitution.agent.md  # Constitutional rules agent
│   ├── speckit.implement.agent.md  # Implementation agent
│   ├── speckit.plan.agent.md       # Planning agent
│   ├── speckit.specify.agent.md    # Specification agent
│   ├── speckit.tasks.agent.md      # Task management agent
│   └── speckit.taskstoissues.agent.md  # Tasks-to-issues converter
│
└── prompts/                        # Prompt templates
    ├── speckit.analyze.prompt.md
    ├── speckit.checklist.prompt.md
    ├── speckit.clarify.prompt.md
    ├── speckit.constitution.prompt.md
    ├── speckit.implement.prompt.md
    ├── speckit.plan.prompt.md
    ├── speckit.specify.prompt.md
    ├── speckit.tasks.prompt.md
    └── speckit.taskstoissues.prompt.md
```

### Agent Files Explained

Each `.agent.md` file follows GitHub Copilot's agent protocol. They define a specialized AI persona with specific instructions. The naming convention is:

```
<namespace>.<role>.agent.md
```

For this golden source, all agents belong to the **SpecKit** namespace — a structured software specification toolkit:

| Agent | Role | Description |
|-------|------|-------------|
| `speckit.analyze` | Analyzer | Analyzes codebases and identifies patterns, issues, and opportunities |
| `speckit.checklist` | Checklist Generator | Creates comprehensive checklists for development tasks |
| `speckit.clarify` | Clarifier | Helps clarify ambiguous requirements and specifications |
| `speckit.constitution` | Constitutional Rules | Defines fundamental rules and constraints for the project |
| `speckit.implement` | Implementer | Guides step-by-step code implementation |
| `speckit.plan` | Planner | Creates development plans and strategies |
| `speckit.specify` | Specifier | Writes detailed technical specifications |
| `speckit.tasks` | Task Manager | Breaks down work into actionable tasks |
| `speckit.taskstoissues` | Issue Converter | Converts task lists into GitHub Issues |

### Prompt Files Explained

Each `.prompt.md` file is a minimal trigger paired with its agent. These are very small files (28–37 bytes) that serve as entry points for invoking the corresponding agent through Copilot's prompt system.

### `copilot-instructions.md`

This is the **general Copilot instructions** file (~853 bytes). GitHub Copilot reads this file from `.github/agents/copilot-instructions.md` to apply project-wide instructions to all Copilot interactions (coding suggestions, chat, etc.).

---

## `.agent/` — VS Code Agent Configuration

### Purpose

The `.agent/` directory is used by VS Code agent extensions (like Antigravity by Google DeepMind) to define skills, workflows, and rules.

### Structure

```
.agent/
└── skills/
    └── c4-architecture/
        └── SKILL.md       # Skill definition file
```

### Skills

Skills are structured instruction sets that extend the AI agent's capabilities:

| Skill | Purpose | Key Feature |
|-------|---------|-------------|
| `c4-architecture` | Generate C4 architecture diagrams | Mermaid C4 syntax, 4 levels (Context, Container, Component, Deployment) |

Each skill contains a `SKILL.md` file with:
- YAML frontmatter (`name`, `description`)
- Detailed instructions in Markdown
- Examples and templates
- Optional: `references/`, `scripts/`, `examples/` subdirectories

---

## `.agents/` — Cross-Platform Agent Skills

### Purpose

The `.agents/` directory holds additional skills that are shared across multiple AI tool ecosystems. This is the largest synced directory.

### Structure

```
.agents/
└── skills/
    ├── c4-architecture/         # 5 files — Architecture diagrams
    ├── tailwind-design-system/  # 1 file  — Tailwind CSS v4 design system
    ├── ui-ux-pro-max/           # 3 files — UI/UX design intelligence
    ├── vercel-deployment/       # 1 file  — Vercel deployment guide
    └── vercel-react-best-practices/  # 60 files — React/Next.js patterns
```

### Skill Breakdown

#### `c4-architecture` (5 files)

Generates software architecture documentation using C4 model diagrams in Mermaid syntax. Supports all four C4 levels:
- Level 1: System Context
- Level 2: Container
- Level 3: Component
- Level 4: Deployment

Plus dynamic (request flow) diagrams.

#### `tailwind-design-system` (1 file)

Build scalable design systems with Tailwind CSS v4, including design tokens, component libraries, and responsive patterns.

#### `ui-ux-pro-max` (3 files)

Comprehensive UI/UX design intelligence covering:
- 50 design styles (glassmorphism, brutalism, neumorphism, etc.)
- 21 color palettes
- 50 font pairings
- 20 chart types
- 9 framework stacks (React, Next.js, Vue, Svelte, SwiftUI, React Native, Flutter, Tailwind, shadcn/ui)

#### `vercel-deployment` (1 file)

Expert knowledge for deploying applications to Vercel, specifically with Next.js.

#### `vercel-react-best-practices` (60 files)

Extensive React and Next.js performance optimization guidelines from Vercel Engineering. Covers:
- Component architecture
- Data fetching patterns
- Bundle optimization
- Server vs client components
- Performance best practices

---

## `.claude/` — Claude Code Configuration

### Purpose

The `.claude/` directory is used by Anthropic's Claude Code extension to define skills specific to the Claude AI model.

### Structure

```
.claude/
└── skills/
    └── (skill directories)
```

This folder follows the same skill structure as `.agents/` but targets the Claude Code toolchain specifically.

---

## How Skills Work

### Skill File Format

Every skill must contain a `SKILL.md` file at its root. This file uses:

```markdown
---
name: skill-name
description: When and how to use this skill
---

# Skill Title

## Workflow
1. Step one
2. Step two

## Examples
...
```

### Trigger Mechanism

Skills are triggered by the AI agent based on keyword matching in the `description` field. For example, the `c4-architecture` skill triggers on words like:
- "architecture diagram"
- "C4 diagram"
- "system context"
- "container diagram"
- "document architecture"

### Skill Installation Tracking

The `skills-lock.json` file in the project root tracks installed skills:

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

This is similar to `package-lock.json` — it ensures that:
- Skills are reproducibly installable
- Updates are tracked by content hash
- Sources are documented for provenance

---

## Why Sync These?

The power of gh-sync is that **all of these configurations stay consistent** across every project. When you:

1. **Add a new skill** → `gh-sync push` deploys it everywhere
2. **Update a SpecKit agent** → all projects get the updated persona
3. **Fix a design system template** → one `push` updates all projects
4. **Customize a project's agent** → `gh-sync pull` brings improvements back

This eliminates "works on my project but not yours" for AI tool configurations.
