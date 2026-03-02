# Troubleshooting

## Authentication

| Error | Resolution |
|-------|------------|
| `No subscriptions found` | Run `az login --allow-no-subscriptions` |
| `VSRM auth required` / 401 on release APIs | Run `az devops login --organization https://dev.azure.com/INFRABEL` |
| `TF400813: Resource not available` | Verify PAT has "Work Items: Read & Write" + "Code: Full" scopes |

## Branch creation

| Error | Resolution |
|-------|------------|
| Branch already exists | Switch to it: `git checkout <branch>`, or append suffix to description |
| `npm run branch` fails with invalid type | Valid types: `feature`, `bugfix`, `hotfix`, `chore`, `test`, `documentation` |
| Dirty worktree blocks checkout | Stash first: `git stash push -u -m "pre-task-stash"` |
| Protected branch error | You are on `main`/`master`/`develop` — always create a new branch first |

## Commit

| Error | Resolution |
|-------|------------|
| `commitlint` rejects message | Ensure format: `type(scope): summary (#TICKET)`. Valid types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `ci`, `build`, `style`, `revert` |
| Empty commit | Stage files first: `git add <files>` |

## PR creation

| Error | Resolution |
|-------|------------|
| `TF401179: active PR already exists` | Fetch existing: `az repos pr list --source-branch <branch> --target-branch develop --status active` |
| `--open` flag not working | Remove `--open`; retrieve PR URL from output and return to user |
| Merge conflicts detected | Do not force-merge. Report to user and suggest resolving locally |

## Azure DevOps defaults

Reset defaults if commands target wrong org/project:

```bash
az devops configure --defaults \
  organization=https://dev.azure.com/INFRABEL \
  project=a1831-ds
```

Verify with:

```bash
az devops configure --list
```
