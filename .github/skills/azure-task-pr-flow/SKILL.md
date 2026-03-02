---
name: azure-task-pr-flow
description: "Automate the full Azure DevOps developer flow: create a work item (Feature/Task), start a convention-compliant branch from develop, commit with conventional commit format and ticket reference, push, and open a PR to develop. Trigger phrases: 'create task and PR', 'start feature flow', 'open work item + branch + PR', 'azure devops task to PR', 'commit and create PR for ticket'. Use when user wants to go from idea to pull request in one shot. DO NOT USE for release automation (use automate-release.sh), pipeline troubleshooting, or general Azure CLI queries."
---

# Azure Task-to-PR Flow

## Inputs

Gather before starting (propose sensible defaults, confirm with user):

| Input              | Required | Default   | Example                                                 |
| ------------------ | -------- | --------- | ------------------------------------------------------- |
| Work item type     | yes      | `Task`    | `Feature`, `Task`                                       |
| Work item title    | yes      | —         | `Add carousel component`                                |
| Branch type        | yes      | `feature` | `feature`, `bugfix`, `chore`, `hotfix`, `documentation` |
| Branch description | yes      | —         | `add-carousel-component` (kebab-case)                   |
| Files to commit    | yes      | —         | staged files or explicit list                           |
| Commit type        | yes      | `feat`    | `feat`, `fix`, `chore`, `docs`, `refactor`, `test`      |
| Commit scope       | no       | —         | `release`, `scripts`, `components`                      |
| Commit summary     | yes      | —         | `add carousel component`                                |
| PR target branch   | no       | `develop` | `develop`                                               |

## Workflow

Execute steps sequentially. Stop on any failure and report the exact error.

### 1. Verify environment

```bash
az devops configure --defaults organization=https://dev.azure.com/INFRABEL project=a1831-ds
```

### 2. Handle dirty worktree

If `git status --porcelain` shows changes, ask user to stash or abort:

```bash
git stash push -u -m "auto-stash-before-task-$(date +%Y%m%d-%H%M%S)"
```

### 3. Create work item

```bash
WORK_ITEM_ID=$(az boards work-item create \
  --org "https://dev.azure.com/INFRABEL" \
  --project "a1831-ds" \
  --type "<type>" \
  --title "<title>" \
  --query id -o tsv)
```

### 4. Create branch

Use the non-interactive helper (preferred for automation):

```bash
npm run branch -- <branch-type> "$WORK_ITEM_ID" <description>
```

This produces branch: `username/type/#TICKET_description`

Example: `nicolas_bruyere/feature/#186499_add-carousel-component`

If the helper fails, create manually:

```bash
git checkout develop && git pull origin develop
USER=$(git config user.name | tr '[:upper:]' '[:lower:]' | sed 's/[\s.]\+/_/g')
git checkout -b "${USER}/<type>/#${WORK_ITEM_ID}_<description>"
```

### 5. Stage and commit

Stage only intended files — never include unrelated changes:

```bash
git add <specific-files>
git commit -m "<type>(<scope>): <summary> (#$WORK_ITEM_ID)"
```

### 6. Push and create PR

```bash
SOURCE_BRANCH=$(git branch --show-current)
git push -u origin "$SOURCE_BRANCH"

# Check for existing PR first
EXISTING_PR=$(az repos pr list \
  --repository a1831-ds \
  --source-branch "$SOURCE_BRANCH" \
  --target-branch develop \
  --status active \
  --query "[0].pullRequestId" -o tsv 2>/dev/null)

if [ -n "$EXISTING_PR" ]; then
  echo "PR already exists: $EXISTING_PR"
else
  az repos pr create \
    --repository a1831-ds \
    --source-branch "$SOURCE_BRANCH" \
    --target-branch develop \
    --title "<type>(<scope>): <summary> (#$WORK_ITEM_ID)" \
    --description "<what changed and why>" \
    --work-items "$WORK_ITEM_ID"
fi
```

## Output

Report to user after completion:

```
Work item: #<ID> — https://dev.azure.com/INFRABEL/a1831-ds/_workitems/edit/<ID>
Branch:    <branch-name>
Commit:    <hash> — <message>
PR:        #<PR_ID> — <url>
Warnings:  <any stash, conflict, or reuse notes>
```

## Safety

- Never commit on `main`, `master`, or `develop` directly.
- Never stage/commit unrelated files.
- If PR exists for same source → target, return existing PR URL (no duplicate).
- If any command fails, report exact error and suggest corrective action.

## Troubleshooting

See [references/troubleshooting.md](references/troubleshooting.md) for common errors and resolutions.
