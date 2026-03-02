# AI Agent Context: CI/CD Pipeline & Release System

> **Purpose**: Hand this document to any AI agent to give it full operational awareness of the Infrabel Design System v3 CI/CD system.
> **Last updated**: 2026-02-23
> **Maintainer**: nicolas.bruyere@infrabel.be
> **Related docs**: [release-workflow-reference.md](release-workflow-reference.md) | [release-process-improvements.md](release-process-improvements.md)

---

## 1. Project Identity

| Key | Value |
|-----|-------|
| **Repo** | `a1831-ds` (Azure DevOps: `https://dev.azure.com/INFRABEL/a1831-ds`) |
| **Type** | Monorepo with 5 packages |
| **Tech** | Angular 18, PrimeNG 17, SCSS, Webpack |
| **Node** | 18.19 (used by all pipelines) |
| **npm scope** | `@infrabel/*` |
| **Current version** | Root: `18.0.22`, CSS: `3.0.28`, PrimeNG Theme: `17.0.32`, Angular v18: `18.0.22` |

---

## 2. Package Map

```
a1831-ds/
├── 1-infrabel-designsystem/          → @infrabel/infrabel-designsystem (CSS/SCSS)
├── 2-infrabel-theme-primeng/v17/     → @infrabel/infrabel-theme-primeng (PrimeNG theme)
├── 3-infrabel-components-angular/v18/→ @infrabel/infrabel-components-angular (Angular lib)
├── 3-infrabel-components-angular/v20/→ Future Angular 20 migration (not released yet)
├── 4-infrabel-theme-bootstrap/v5/    → Bootstrap theme (not in active release cycle)
├── 7-release/                        → All pipeline YAML definitions (9 files)
└── scripts/automate-release.sh       → Release automation script
```

---

## 3. Release Flow (Current State)

```
LOCAL                          AZURE DEVOPS                         NPM
─────                          ────────────                         ───
automate-release.sh            Tag push triggers:
  ├─ bump versions               ├─ Pipeline 1852 → build PrimeNG ─→ Release Def 1 → npm publish
  ├─ changelog                   ├─ Pipeline 1853 → build Angular ─→ Release Def 2 → npm publish
  ├─ commit + tag                └─ Pipeline 1855 → build CSS ────→ Release Def 3 → npm publish
  └─ MANUAL: push branch+tag
```

### Tag Convention

| Pattern | Scope | Triggers pipelines? |
|---------|-------|:---:|
| `release-vX.Y.Z` | Stable release | Yes — all 3 build pipelines |
| `release-alpha-vX.Y.Z` | Alpha/test release | Yes — all 3 build pipelines |
| `vX.Y.Z` | Legacy (pre-2026) | No — pipelines expect `release-v*` prefix |

**IMPORTANT**: Before Feb 2026, tags used `v{version}` pattern. The script was fixed to use `release-v{version}`. Old tags like `v18.0.22` still exist but do NOT trigger current pipelines.

---

## 4. Pipeline Inventory

### Build Pipelines (YAML)

| ID | Name | YAML | Triggers | Artifact | Status |
|----|------|------|----------|----------|--------|
| **1852** | `designsystemv3_infrabel-theme-primeng` | `infrabel-theme-primeng-v17-official.yaml` | `develop` (path) + tags `release-*` | `infrabel-theme-primeng` | **Active** — but triggers too broadly (`release-*` instead of `release-v*`) |
| **1853** | `release-infrabel-components-angular-v18` | `infrabel-components-angular-v18-release-official.yaml` | Tags: `release-v*`, `release-alpha-v*` | `infrabel-components` | **Active** — has lockfile normalization workaround |
| **1854** | `designsystemv3_infrabel-css-style` | `designsystemv3_infrabel-css-style.yml` | Tags: `release-v*`, `release-alpha-v*` | `infrabel-designsystem` | **Active but redundant** — duplicates pipeline 1855 |
| **1855** | `release-infrabel-designsystem-v3` | `infrabel-designsystem-v3-release.yaml` | Tags: `release-v*`, `release-alpha-v*` | `infrabel-designsystem` | **Active** — THE CSS release pipeline |

### Classic Release Definitions (UI-only, no YAML)

| ID | Consumes Build | Artifact Alias | Action |
|----|---------------|----------------|--------|
| **1** | Pipeline 1852 | `_designsystemv3_infrabel-theme-primeng` | `npm publish` PrimeNG theme |
| **2** | Pipeline 1853 | `_release-infrabel-components-angular-v18` | `npm publish` Angular components |
| **3** | Pipeline 1855 | `_release-infrabel-designsystem-v3` | `npm publish` CSS package |

### Duplicate/Variant YAML Files (inactive or CI-only)

| File | Related To | Notes |
|------|-----------|-------|
| `infrabel-theme-primeng-v17.yaml` | PrimeNG | CI variant, triggers on `develop` |
| `infrabel-theme-primeng-v17-release.yaml` | PrimeNG | Release variant, not used by pipeline 1852 |
| `infrabel-components-angular-v18.yaml` | Angular v18 | CI variant, triggers on `develop` |
| `infrabel-components-angular-v18-release.yaml` | Angular v18 | Release variant, not used by 1853 |
| `infrabel-designsystem-v3.yaml` | CSS | Variant, overlaps with 1854/1855 |
| `infrabel-components-vanilla.yaml` | Vanilla | Website build, separate |
| `designsystemv3_snippets_website.yml` | Website | Snippets/docs site |

---

## 5. Known Issues (Ranked by Impact)

### CRITICAL

| # | Issue | Detail | Workaround |
|---|-------|--------|------------|
| **K1** | Old Artifactory URLs in lockfile | Angular v18 `package-lock.json` has ~92 refs to `artifactory.msnet.railb.be` (dead host) | PowerShell normalization step in pipeline 1853 rewrites URLs at build time |
| **K2** | Tag naming mismatch (legacy) | Tags `v18.0.22` etc. exist but don't trigger pipelines expecting `release-v*` | Script now creates `release-v*` tags. Manual rerun tags exist: `release-v18.0.22-rerun1` through `-rerun4` |
| **K3** | No automated push | `automate-release.sh` stops before pushing. Developer must manually run 2 git push commands | Planned: `--push` flag |

### HIGH

| # | Issue | Detail |
|---|-------|--------|
| **K4** | No pipeline monitoring | After push, zero feedback. Must poll Azure DevOps UI for 3 build + 3 release pipelines |
| **K5** | No build validation before tag | If build breaks, tag already exists. v18.0.22 needed 5 retry tags |
| **K6** | No rollback mechanism | If one package publishes but another fails, manual npm unpublish required |
| **K7** | Classic Release definitions can't be automated | `az pipelines release` fails due to vsrm auth scope. Config locked in UI |

### MEDIUM

| # | Issue | Detail |
|---|-------|--------|
| **K8** | Duplicate CSS pipelines | 1854 and 1855 both build same CSS package; 1854 uses `buildAlphaPackage`, 1855 uses `buildPackage` |
| **K9** | Inconsistent tag triggers | Pipeline 1852 matches `release-*` (too broad), others match `release-v*` (correct) |
| **K10** | 9 YAML files for 3 packages | Confusing; changes must be replicated across variants |
| **K11** | PrimeNG pipeline rebuilds CSS | Pipeline 1852 builds CSS as dependency, but 1855 also builds CSS independently |

---

## 6. What Works Well

- `automate-release.sh` reliably bumps versions, generates changelogs, and creates tags
- `--dry-run` and `--test-release` modes work correctly
- `--packages` flag allows scoping (v18-only, all, custom)
- Branch naming convention enforced: `username/type/#ticket_description`
- Commit convention respected: `type(scope): summary (#ticket)`
- CD triggers on Classic Release definitions work once build succeeds
- Lockfile normalization workaround unblocks Angular v18 builds

---

## 7. Improvement Roadmap

### Phase 1: Quick Wins (est. 1 day)
- [ ] Add `--push` flag to automate-release.sh (K3)
- [ ] Add `--create-pr` flag with auto-complete (K4)
- [ ] Standardize all pipelines to `release-v*` / `release-alpha-v*` triggers (K9)
- [ ] Regenerate Angular v18 `package-lock.json` with correct registry (K1)
- [ ] Designate pipeline 1854 as CI-only, remove tag triggers (K8)

### Phase 2: Safety & Monitoring (est. 2-3 days)
- [ ] Add `--monitor` flag: poll build status via `az pipelines build show` (K4)
- [ ] Add local build verification before tagging (K5)
- [ ] Configure Azure DevOps build failure notifications
- [ ] Add `--rollback <version>` command (K6)

### Phase 3: Pipeline Consolidation (est. 3-5 days)
- [ ] Consolidate 9 YAML files to 3 multi-stage + 1 orchestrator (K10)
- [ ] Migrate Classic Releases to YAML deploy stages (K7)
- [ ] CSS built once, shared via artifacts to PrimeNG (K11)

### Phase 4: Full Automation (est. 1-2 days)
- [ ] Single `automate-release.sh --push --monitor` command does everything
- [ ] Orchestrator pipeline handles build, publish, summary
- [ ] Script receives pipeline result and exits 0/1

---

## 8. Architecture Diagrams

### Current (as of v18.0.22)

```
automate-release.sh
    │
    ├── Creates: Azure Boards Task
    ├── Creates: Branch from develop
    ├── Bumps: 5 package.json files
    ├── Generates: CHANGELOG.md + CHANGELOG.html
    ├── Tags: release-vX.Y.Z
    └── Prints: manual push instructions
         │
    [MANUAL] git push origin <branch> + git push origin <tag>
         │
    ┌────┴─────────────────────────────────┐
    │        Azure DevOps (triggered)       │
    ├───────────────────────────────────────┤
    │  Build 1852 ──→ Release Def 1 ──→ npm│  (PrimeNG)
    │  Build 1853 ──→ Release Def 2 ──→ npm│  (Angular v18)
    │  Build 1855 ──→ Release Def 3 ──→ npm│  (CSS)
    │  Build 1854 (redundant, same as 1855)│
    └───────────────────────────────────────┘
```

### Target (after Phase 4)

```
automate-release.sh --push --monitor
    │
    ├── Bump + changelog + tag + push + PR (all automated)
    │
    └── Triggers: release-orchestrator.yaml
         │
         ├── Stage: Build_CSS → Publish_CSS
         ├── Stage: Build_PrimeNG (needs CSS) → Publish_PrimeNG
         ├── Stage: Build_Angular → Publish_Angular
         └── Stage: Release_Summary → exit 0/1
```

---

## 9. Key Commands for Agents

```bash
# Azure DevOps defaults (ALWAYS set first)
az devops configure --defaults organization=https://dev.azure.com/INFRABEL project=a1831-ds

# Release (interactive)
bash ./scripts/automate-release.sh
bash ./scripts/automate-release.sh --dry-run        # simulate
bash ./scripts/automate-release.sh --test-release    # alpha tags

# Branch creation
npm run branch -- <type> <ticket-id> <description>

# Monitor builds
az pipelines build list --definition-ids 1852 --top 3 \
  --query "[].{id:id,result:result,branch:sourceBranch}" -o table
az pipelines build list --definition-ids 1853 --top 3 \
  --query "[].{id:id,result:result,branch:sourceBranch}" -o table
az pipelines build list --definition-ids 1855 --top 3 \
  --query "[].{id:id,result:result,branch:sourceBranch}" -o table

# Check build artifacts
az rest --method get --resource "499b84ac-1321-427f-aa17-267ca6975798" \
  --url "https://dev.azure.com/INFRABEL/a1831-ds/_apis/build/builds/<ID>/artifacts?api-version=7.1" \
  --query "value[].name" -o table

# Create PR
az repos pr create --repository a1831-ds --source-branch <branch> \
  --target-branch develop --title "<title>" --work-items <ticket>
```

---

## 10. Critical Rules for Any Agent Working on This Repo

1. **Never push directly to `main`, `master`, or `develop`** — always use a feature/chore/documentation branch.
2. **Branch naming**: `username/type/#ticket_description` (enforced by `scripts/create-branch.js`).
3. **Commit format**: `type(scope): summary (#ticket)` (enforced by commitlint).
4. **Release tags MUST use `release-v` prefix** — bare `v18.0.X` tags won't trigger any pipeline.
5. **Angular v18 lockfile** is fragile — if you run `npm install`, the lockfile may revert to old Artifactory URLs. Always verify.
6. **Pipeline 1854 vs 1855**: Both build CSS. Only 1855 feeds Release Def 3. Don't confuse them.
7. **Classic Release definitions cannot be modified via CLI** — use the Azure DevOps web UI.
8. **The `vsrm` API requires a separate auth scope** — `az pipelines release` will fail without it. Use REST API with resource ID `499b84ac-1321-427f-aa17-267ca6975798` instead.
9. **After any pipeline change**, test with `--test-release` (alpha tag) before a real release.
10. **Azure DevOps org**: `INFRABEL`, project: `a1831-ds`, repo: `a1831-ds` — always set defaults with `az devops configure`.
