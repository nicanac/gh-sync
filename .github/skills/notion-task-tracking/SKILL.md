---
name: notion-task-tracking
description: "Automatically tracks AI conversation tasks in a Notion database. Creates a task at the start of every new conversation and marks it as 'Done' when the conversation goal is achieved. Every task is labeled with the 'Infrabel' project. Trigger phrases: 'track task', 'notion task', 'start tracking'. This skill is implicitly activated at the START of every new conversation — no trigger phrase needed."
---

# Notion Task Tracking — Conversation Lifecycle

## Purpose

Every AI conversation in this workspace represents a unit of work.
This skill ensures that work is **visible** in the team's Notion task board by:

1. **Creating** a Notion task at the **start** of each new conversation
2. **Updating** the task to "Doing" while work is being done
3. **Marking** the task as "Done" when the conversation goal is **completed**

All tasks are automatically linked to **🗃️ Client = Infrabel**.

---

## Prerequisites

| Requirement                      | How to set up                                                                                                                       |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `NOTION_API_KEY` env var         | Create an integration at [notion.so/my-integrations](https://www.notion.so/my-integrations), then `export NOTION_API_KEY="ntn_..."` |
| Database shared with integration | Open the Notion database → **...** → **Connect to** → select your integration                                                       |
| `@notionhq/client` package       | Already in `package.json` dependencies                                                                                              |
| Script                           | `scripts/notion-task.js` — CLI and module for Notion operations                                                                     |

### Notion Database

- **Database:** "All Tasks"
- **Database ID:** `f89cc142-aa02-4a72-9e3c-fcfded8fffb0`
- **URL:** https://www.notion.so/f89cc142aa024a729e3cfcfded8fffb0?v=d1dd0e25b907484e8586090d4fb06259
- **Client DB:** `773ff087-8e0a-494c-a664-a1e777aad3ea` (Infrabel page ID: `e45357fa-81f3-4497-8da8-1300ec93840f`)

### Database Properties Used

| Property       | Type         | Notes                                                             |
| -------------- | ------------ | ----------------------------------------------------------------- |
| Task           | Title        | Task name / conversation summary                                 |
| Checked        | Checkbox     | Primary completion flag                                           |
| Done           | Checkbox     | Secondary done flag                                               |
| Due            | Date         | Due date (defaults to today)                                      |
| Start          | Date         | Start date (defaults to today)                                    |
| Priority       | Select       | `🧀 Medium` (default), `🚨HIGH`, `🧊 Low`                         |
| Kanban - State | Select       | `To Do` → `Doing` → `Done`                                       |
| Context        | Multi-select | Defaults to `@computer`                                           |
| 🗃️ Client      | Relation     | Always linked to **Infrabel** (`e45357fa-81f3-4497-8da8-1300ec93840f`) |
| URL            | URL          | Optional link                                                     |

---

## Workflow

### Step 1 — Conversation Start (MANDATORY)

At the **very beginning** of every new conversation, **before** doing any other work:

```bash
node scripts/notion-task.js create --title "<concise summary of user request>"
```

- Extract a concise title from the user's first message (max 60 chars)
- If the request is unclear, use a generic title like "DS3: AI conversation task"
- The task is automatically linked to Infrabel client, set to "To Do", with today's date
- **Capture the returned `id`** — you need it to update/complete the task later

Store the task page ID in your working context:

```
NOTION_TASK_ID=<returned-page-id>
```

### Step 2 — Mark In Progress

Once you begin working on the actual task:

```bash
node scripts/notion-task.js doing --id "$NOTION_TASK_ID"
```

### Step 3 — Mark Complete (when task is done)

When the user's request is **fully resolved**:

```bash
node scripts/notion-task.js complete --id "$NOTION_TASK_ID"
```

This sets `Checked = true`, `Done = true`, and `Kanban - State = "Done"`.

### Querying Existing Tasks

To check existing tasks (e.g., to avoid duplicates):

```bash
node scripts/notion-task.js query --state "To Do"
node scripts/notion-task.js query --completed false
```

---

## Error Handling

- If `NOTION_API_KEY` is not set, **warn the user** and continue with the main task. Do NOT block work.
- If the Notion API call fails (network, auth, schema mismatch), **log a warning** and continue. Task tracking is best-effort — never let it block the user's actual request.
- If the database schema doesn't match (e.g., property names differ), suggest the user check their Notion database columns.

---

## Rules

1. **Every conversation = one Notion task.** No exceptions.
2. **Client is always Infrabel.** The `🗃️ Client` relation is automatically set — never omit or change this.
3. **Task title must be descriptive.** Derive it from the user's request, not a generic placeholder.
4. **Complete only when done.** Don't mark a task as "Done" if the work is still in progress or if you're unsure.
5. **Best-effort tracking.** If Notion is unreachable, proceed with the user's actual work. Log the failure but don't halt.
6. **Never hardcode the API key.** Always use `$NOTION_API_KEY` environment variable.
