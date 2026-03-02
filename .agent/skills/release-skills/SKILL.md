---
name: release-skills
description: Release workflow for Infrabel Design System v3 monorepo. Use when user says "release", "new version", "bump version", or wants to publish changes. Bumps versions in each package.json separately, creates version tags, and compares tags to generate the changelog. MUST be used before any git push with uncommitted changes.
---

# Release Skills - Infrabel Design System v3

Automate the release process for the Infrabel Design System monorepo: bump versions in each package separately, create tags, compare tags, and generate changelog.

## CRITICAL: Mandatory Release Checklist

**NEVER skip these steps when releasing:**

1. ✅ Bump version in each package.json separately
2. ✅ Commit version changes
3. ✅ Create version tag
4. ✅ Compare with previous tag to update CHANGELOG.md
5. ✅ Commit changelog updates
6. ✅ Create final release tag

**If user says "just push" - STILL follow all steps above first!**

## When to Use

Trigger this skill when user requests:

- "release", "create release", "new version"
- "bump version", "update version"
- "prepare release"
- "push to remote" (with uncommitted changes)

## Package Structure

The monorepo contains these packages that need version management:

| Package                          | Location                                                                                                            | Current Version Pattern |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| **Root**                         | `./package.json`                                                                                                    | `18.x.x`                |
| **Components Angular v18**       | `./3-infrabel-components-angular/infrabel-components-angular-v18/package.json`                                      | `18.x.x`                |
| **Components Angular v18 (lib)** | `./3-infrabel-components-angular/infrabel-components-angular-v18/projects/infrabel-components-angular/package.json` | `18.x.x`                |
| **Design System Core**           | `./1-infrabel-designsystem/package.json`                                                                            | `3.0.x`                 |
| **PrimeNG Theme**                | `./2-infrabel-theme-primeng/infrabel-theme-primeng-v17/package.json`                                                | `17.0.x`                |

## Workflow

### Step 1: Analyze Changes Between Tags

```bash
# Get the latest version tags
LAST_TAG=$(git tag --sort=-v:refname | head -1)
PREVIOUS_TAG=$(git tag --sort=-v:refname | head -2 | tail -1)

# Show changes since last tag (for new release)
git log ${LAST_TAG}..HEAD --oneline
git diff ${LAST_TAG}..HEAD --stat

# Compare two specific tags (for changelog generation)
git log ${PREVIOUS_TAG}..${LAST_TAG} --oneline
```

Categorize changes by type based on commit messages:

| Type     | Prefix      | Emoji | Description              |
| -------- | ----------- | ----- | ------------------------ |
| feat     | `feat:`     | ✨    | New features, components |
| fix      | `fix:`      | 🐛    | Bug fixes                |
| style    | `style:`    | 🎨    | Style/CSS changes        |
| ci       | `ci:`       | 👷    | CI/CD updates            |
| chore    | `chore:`    | 🔧    | Maintenance              |
| docs     | `docs:`     | 📚    | Documentation            |
| refactor | `refactor:` | ♻️    | Code refactoring         |
| test     | `test:`     | ✅    | Test updates             |
| perf     | `perf:`     | ⚡    | Performance              |

### Step 2: Determine Version Bump Type

Version rules:

- **Patch** (18.0.18 → 18.0.19): Bug fixes, style updates, minor improvements
- **Minor** (18.0.x → 18.1.0): New components, significant features
- **Major** (18.x → 19.0): Breaking changes, Angular version upgrades

Default behavior:

- If changes include `feat:` with new components → Minor bump
- Otherwise → Patch bump

### Step 3: Bump Versions in Each Package Separately

**IMPORTANT**: Update each package.json individually, confirming each one before proceeding.

#### 3.1 Root package.json

```bash
cd .
npm version patch --no-git-tag-version
# Current: 18.0.18 → New: 18.0.19
```

#### 3.2 Components Angular v18 (main)

```bash
cd ./3-infrabel-components-angular/infrabel-components-angular-v18
npm version patch --no-git-tag-version
# Current: 18.0.18 → New: 18.0.19
```

#### 3.3 Components Angular v18 (library)

```bash
cd ./3-infrabel-components-angular/infrabel-components-angular-v18/projects/infrabel-components-angular
npm version patch --no-git-tag-version
# Current: 18.0.18 → New: 18.0.19
```

#### 3.4 Design System Core

```bash
cd ./1-infrabel-designsystem
npm version patch --no-git-tag-version
# Current: 3.0.24 → New: 3.0.25
```

#### 3.5 PrimeNG Theme

```bash
cd ./2-infrabel-theme-primeng/infrabel-theme-primeng-v17
npm version patch --no-git-tag-version
# Current: 17.0.28 → New: 17.0.29
```

**Alternative**: Use the existing bumppatch script for synchronized updates:

```bash
npm run bumppatch
```

### Step 4: Commit Version Changes & Create Pre-Changelog Tag

```bash
git add -A
git commit -m "chore(release): bump versions to {NEW_VERSION}"
git tag v{NEW_VERSION}-pre
```

### Step 5: Compare Tags and Generate Changelog

Compare the new pre-tag with the previous release tag to identify all changes:

```bash
# Get previous release tag
PREV_RELEASE=$(git tag --sort=-v:refname | grep -v "pre" | head -1)

# Generate changelog content from comparison
git log ${PREV_RELEASE}..v{NEW_VERSION}-pre --pretty=format:"%s ([%h](https://dev.azure.com/INFRABEL/a1831-ds/_git/a1831-ds/commit/%H))"
```

### Step 6: Update CHANGELOG.md

Insert new section after the header, following this format:

```markdown
## [{NEW_VERSION}] - {YYYY-MM-DD}

### Features

- feat: description of feature ([commit_hash](https://dev.azure.com/INFRABEL/a1831-ds/_git/a1831-ds/commit/full_commit_hash))

### Bug Fixes

- fix(scope): description of fix ([commit_hash](https://dev.azure.com/INFRABEL/a1831-ds/_git/a1831-ds/commit/full_commit_hash))

### Styles

- style(component): description of style change ([commit_hash](https://dev.azure.com/INFRABEL/a1831-ds/_git/a1831-ds/commit/full_commit_hash))

### CI/CD

- ci: description of CI change ([commit_hash](https://dev.azure.com/INFRABEL/a1831-ds/_git/a1831-ds/commit/full_commit_hash))

### Chore

- chore: description of maintenance ([commit_hash](https://dev.azure.com/INFRABEL/a1831-ds/_git/a1831-ds/commit/full_commit_hash))

### Documentation

- docs: description of docs change ([commit_hash](https://dev.azure.com/INFRABEL/a1831-ds/_git/a1831-ds/commit/full_commit_hash))

### Refactor

- refactor: description of refactoring ([commit_hash](https://dev.azure.com/INFRABEL/a1831-ds/_git/a1831-ds/commit/full_commit_hash))

### Tests

- test: description of test change ([commit_hash](https://dev.azure.com/INFRABEL/a1831-ds/_git/a1831-ds/commit/full_commit_hash))

### Performance

- perf: description of perf improvement ([commit_hash](https://dev.azure.com/INFRABEL/a1831-ds/_git/a1831-ds/commit/full_commit_hash))
```

Only include sections that have changes. Omit empty sections.

### Step 7: Commit Changelog & Create Final Tag

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): update changelog for v{NEW_VERSION}"
git tag v{NEW_VERSION}
git tag -d v{NEW_VERSION}-pre  # Remove pre-tag
```

## Options

| Flag               | Description                         |
| ------------------ | ----------------------------------- |
| `--dry-run`        | Preview changes without executing   |
| `--major`          | Force major version bump            |
| `--minor`          | Force minor version bump            |
| `--patch`          | Force patch version bump (default)  |
| `--alpha`          | Create alpha prerelease version     |
| `--from-tag <tag>` | Specify starting tag for comparison |
| `--to-tag <tag>`   | Specify ending tag for comparison   |
| `--package <name>` | Bump only specific package          |

## Dry-Run Mode

When `--dry-run` is specified:

1. Show all changes since last tag
2. Show proposed version bumps for each package
3. Show draft changelog entries
4. Show files that would be modified
5. Do NOT make any actual changes

Output format:

```
=== DRY RUN MODE ===

Last release tag: v18.0.18
Proposed version: v18.0.19

Package versions to update:
┌─────────────────────────────────┬─────────────┬─────────────┐
│ Package                         │ Current     │ New         │
├─────────────────────────────────┼─────────────┼─────────────┤
│ Root                            │ 18.0.18     │ 18.0.19     │
│ Components Angular v18          │ 18.0.18     │ 18.0.19     │
│ Components Angular v18 (lib)    │ 18.0.18     │ 18.0.19     │
│ Design System Core              │ 3.0.24      │ 3.0.25      │
│ PrimeNG Theme                   │ 17.0.28     │ 17.0.29     │
└─────────────────────────────────┴─────────────┴─────────────┘

Changes detected:
- feat(component): new data-tag component
- fix(core): fixing non correct scss
- style(table): surface colors update

Changelog preview:
## [18.0.19] - 2026-01-22
### Features
- feat(component): new data-tag component ([a1171649](https://dev.azure.com/INFRABEL/a1831-ds/_git/a1831-ds/commit/full_hash_here))
### Bug Fixes
- fix(core): fixing non correct scss ([63326c6b](https://dev.azure.com/INFRABEL/a1831-ds/_git/a1831-ds/commit/full_hash_here))
### Styles
- style(table): surface colors update ([58c44a81](https://dev.azure.com/INFRABEL/a1831-ds/_git/a1831-ds/commit/full_hash_here))

No changes made. Run without --dry-run to execute.
```

## Alpha Release Workflow

For alpha/prerelease versions:

```bash
# Bump to alpha version
npm version prerelease --preid=alpha --no-git-tag-version

# Example: 18.0.19 → 18.0.20-alpha.0
```

## Example Usage

```
/release              # Auto-detect version bump, update all packages
/release --dry-run    # Preview only
/release --minor      # Force minor bump across all packages
/release --alpha      # Create alpha prerelease
/release --from-tag v18.0.17 --to-tag v18.0.18  # Compare specific tags
```

## Post-Release Reminder

After successful release, remind user:

```
Release v{NEW_VERSION} created locally.

To publish:
  git push origin main
  git push origin v{NEW_VERSION}

To publish packages:
  npm run publishPackage        # For production
  npm run publishAlphaPackage   # For alpha releases
```

## Changelog Generation Script

For automated changelog generation, use the existing script:

```bash
./generate-changelog.sh components --from-tag v18.0.17 --to-tag v18.0.18
```

See `docs/CHANGELOG-GENERATION-GUIDE.md` for full documentation.

