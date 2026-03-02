---
description: Autonomous task execution loop - picks next task, branches, brainstorms, codes, commits, PRs, syncs
---

// turbo-all

## Objective

Execute the complete task loop from `memory-bank/TASKS.md`:
1. Review documentation for updates
2. Create feature branch
3. Brainstorm and research
4. Implement with atomic commits
5. Create PR
6. Sync completion to TASKS.md, Pinecone, and Notion
7. Loop to next task
**CRITICAL: This loop must NEVER stop before completing ALL tasks marked as incomplete in `memory-bank/TASKS.md`.**

## Pre-Flight Check

1. **Review docs for updates needed:**
   - Read `.gemini/rules/architecture.md` - verify tech stack, guardrails are current
   - Read `memory-bank/PRD.md`, `memory-bank/TSD.md`, `memory-bank/activeContext.md`
   - If updates needed, make them before proceeding

2. **Find next task:**
   - Read `memory-bank/TASKS.md`
   - Find first task marked `[ ]` (uncompleted)
   - Note the task ID and description

## Execution Loop

3. **Create branch:**
   - Run: `node scripts/create-branch.js --type "feature" --desc "<task-description>" --yes`

4. **Mark in progress:**
   - Update task in `memory-bank/TASKS.md` from `[ ]` to `[/]`

5. **Brainstorm:**
   - Run `/brainstorm` workflow with task context
   - Gather all relevant docs, patterns, and implementation approach
   - Query Pinecone for related knowledge

6. **Implement:**
   - Code the feature following TSD.md architecture
   - After each logical sub-task, commit:
     ```bash
     git add .
     git commit -m "feat(scope): description"
     ```

7. **Push and PR:**
   ```bash
   git push origin <branch-name>
   gh pr create --title "feat: <task-description>" --body "## Changes\n- <summary>\n\nCloses #<issue-if-any>"
   ```

8. **Complete and sync:**
   - Update task in `memory-bank/TASKS.md` from `[/]` to `[x]`
   - Upsert completion to Pinecone (`airecord-meme` index, `meetflow-docs` namespace)
   - Sync to Notion (page ID: `2ed9555c-6779-8034-9e0a-d76d1dbfff2e`)
   - Update `memory-bank/activeContext.md` with recent changes

9. **Next task:**
   ```bash
   git checkout main
   git pull origin main
   ```
   - Return to Step 1

## Success Criteria

- Task branch created and checked out
- `/brainstorm` research completed before coding
- Atomic commits made during implementation
- PR created with meaningful description
- Task marked `[x]` in TASKS.md
- Completion synced to Pinecone and Notion
- Ready for next task iteration
