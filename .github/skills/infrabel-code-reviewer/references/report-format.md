# Report Format — Infrabel Code Reviewer

---

## Severity Levels

| Severity | Badge | Meaning | Must Fix Before Merge? |
|----------|-------|---------|------------------------|
| **Critical** | 🔴 | Security risk, broken functionality, or major design system violation | Yes |
| **High** | 🟠 | Performance regression, hardcoded tokens, missing mandatory pattern | Yes |
| **Medium** | 🟡 | Code quality, accessibility gap, naming convention mismatch | Strongly recommended |
| **Low** | 🔵 | Minor style issue, optional improvement, best-practice suggestion | Optional |
| **Info** | ℹ️ | Noteworthy finding, no action required | No |

---

## Remark Block Format

Every finding must be written as the following block:

```
### [SEVERITY_BADGE] [RULE-ID] · Short title

**File:** `path/to/file.ts` · **Line(s):** 42–45

**Offending code:**
```[language]
// exact snippet from the file
```

**Explanation:**
Clear, developer-facing description of what is wrong, why it matters, and what rule is violated.

**Suggested fix:**
```[language]
// corrected version of the snippet
```

**Rule reference:** `[RULE-ID]` from `references/library-rules.md` or `references/general-frontend-rules.md`
```

---

## Scoring Guide

### Per-Section Score

After all remarks are listed, compute the section score:

| Result | Criteria |
|--------|----------|
| 🟢 Pass | 0 Critical, 0 High, ≤ 3 Medium |
| 🟡 Needs Work | 0 Critical, 1–3 High OR 4–9 Medium |
| 🔴 Fail | ≥ 1 Critical OR ≥ 4 High |

### Overall Score

The lower of the two section scores determines the overall score.

---

## Executive Summary Format

```
## Executive Summary

| | Section A — Library | Section B — General Frontend |
|-|---------------------|------------------------------|
| Score | 🟢/🟡/🔴 | 🟢/🟡/🔴 |
| 🔴 Critical | N | N |
| 🟠 High | N | N |
| 🟡 Medium | N | N |
| 🔵 Low | N | N |
| ℹ️ Info | N | N |

**Overall:** 🟢/🟡/🔴

Top 3 issues to fix immediately:
1. [RULE-ID] — short description — `file.ts:line`
2. ...
3. ...
```

---

## Positive Highlights Format

```
## Section C — Positive Highlights

Commend specific, concrete good practices found. Minimum 3 items. Be specific about file and line.

- ✅ `src/app/core/app.component.ts:12` — `InfUtils.handleInputFocus` correctly called in `ngOnInit`.
- ✅ `src/app/features/dashboard/dashboard.component.ts:1` — OnPush strategy applied consistently.
- ✅ `src/app/shared/styles/tokens.scss` — All spacing uses `--spacing-*` tokens throughout.
```

---

## Review Metadata Block

Open every report with:

```
## Review Metadata

| Field | Value |
|-------|-------|
| Reviewed project | `<project name or path>` |
| Library version | `@infrabel/infrabel-components-angular` vX.X.X |
| Angular version | vX |
| Files scanned | N |
| Date | YYYY-MM-DD |
| Reviewer | Claude (AI assistant) |
```
