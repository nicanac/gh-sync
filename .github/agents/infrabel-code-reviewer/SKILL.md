---
name: infrabel-code-reviewer
description: Performs structured code reviews of Angular projects that consume the @infrabel/infrabel-components-angular library. Produces a detailed report with two distinct sections: (1) library compliance review covering correct usage of Infrabel components, tokens, directives, services and patterns; (2) general frontend review covering Angular best practices, TypeScript quality, performance, accessibility and security. Every remark includes file path, line number(s), the offending code, a clear explanation, and an actionable fix. Use when reviewing PRs, auditing feature branches, or onboarding new developers to the design system.
---

# Infrabel Code Reviewer

Produces a two-section code review report for Angular projects using `@infrabel/infrabel-components-angular` v18.

## When to Use

- Reviewing a PR or feature branch against the design system rules
- Auditing an existing project for library compliance
- Onboarding developers to library and Angular conventions

## Workflow

### Step 1 — Discover the target project

Determine the project root from the user's input (path or context).

### Step 2 — Load review rules

Read both reference files before starting analysis:

- `references/library-rules.md` — Infrabel library compliance rules
- `references/general-frontend-rules.md` — General Angular / frontend rules

### Step 3 — Scan the project

For each Angular source file (`.ts`, `.html`, `.scss`) in the project:

1. Read the file fully
2. Flag every violation of rules in both reference files
3. Record: **file path**, **line range**, **offending snippet**, **rule violated**, **explanation**, **suggested fix**

Prioritise files that import or use `@infrabel/infrabel-components-angular`.

### Step 4 — Produce the report

Use the template in `assets/review-report-template.md`.

The report **must** contain:

1. **Executive Summary** — overall score (🟢/🟡/🔴 per section), total issue counts by severity
2. **Section A — Library Compliance Review** — all library-specific remarks
3. **Section B — General Frontend Review** — all general Angular/frontend remarks
4. **Section C — Positive Highlights** — notable good practices found (min. 3 items)

Each remark must follow the remark block format defined in `references/report-format.md`.

### Step 5 — Deliver

Output the full report as Markdown. If the report exceeds context limits, summarise by file and offer to expand individual sections on request.

## References

- `references/library-rules.md` — Infrabel v18 library compliance rules (component usage, tokens, patterns)
- `references/general-frontend-rules.md` — Angular, TypeScript, SCSS and security rules
- `references/report-format.md` — Severity levels, remark block format, scoring guide
- `assets/review-report-template.md` — Full report skeleton to fill in
