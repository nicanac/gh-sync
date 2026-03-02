# UX Post-Migration Checklist (Angular v20)

## Purpose
Use this checklist to validate that the Angular v20 migration did not change user experience, accessibility, or visual behavior in `infrabel-components-angular-v20`.

## Scope
- In scope: `3-infrabel-components-angular/infrabel-components-angular-v20`
- Out of scope: v17 and v18 folders (do not compare by editing them; use as visual reference only)
- Constraint: PrimeNG version stays unchanged (`17.18.5`)

---

## How to run checks (quick)
- Start app and navigate through key pages/components in the demo app.
- Validate in at least:
  - Desktop (Chrome/Edge)
  - Mobile viewport (responsive mode)
  - Keyboard-only navigation
- Focus on high-impact components first, then spot-check the rest.

---

## 1) Global UX & Visual Consistency

- [ ] Typography, spacing, and sizing look identical to pre-migration reference
- [ ] Theme colors and contrast look unchanged
- [ ] No layout shifts on initial load
- [ ] No broken icons, missing images, or placeholder artifacts
- [ ] Animations/transitions still feel natural (no jank/flicker)
- [ ] Toasts, overlays, and dialogs appear in correct stacking order
- [ ] No unexpected console UI warnings during normal interactions

**Pass criteria:** No visible regressions in global styling, layout, or motion.

---

## 2) Navigation & Information Architecture

- [ ] Main nav renders all expected items
- [ ] Active/selected states are visually correct
- [ ] Hover/focus/pressed states are consistent
- [ ] Breadcrumb, side menu, and mega menu flows still match expected behavior
- [ ] Route transitions preserve scroll/focus expectations
- [ ] Mobile nav (burger/menu) opens/closes correctly

**Pass criteria:** Users can reach all key destinations with unchanged behavior.

---

## 3) Forms & Inputs (highest risk area)

Validate these interactions on representative forms and input-heavy pages:

- [ ] Labels, placeholders, helper text, and errors display correctly
- [ ] Required/optional indicators are correct
- [ ] Input states: default, focus, error, disabled, readonly
- [ ] Keyboard typing, tab order, and enter/escape behaviors
- [ ] Date/calendar input:
  - [ ] Open/close behavior
  - [ ] Date/time selection
  - [ ] Clear/reset behavior
  - [ ] Validation message behavior
- [ ] Upload / drag-drop:
  - [ ] Drag-over visual state
  - [ ] Drop behavior
  - [ ] Error/success messages
  - [ ] Disabled mode
- [ ] Autocomplete/search:
  - [ ] Results rendering
  - [ ] Empty state
  - [ ] Keyboard selection

**Pass criteria:** No loss in form usability, validation clarity, or keyboard flow.

---

## 4) Overlays, Menus, and Popups

- [ ] Overlay opens at correct anchor/position
- [ ] Overlay closes correctly (outside click, escape, close action)
- [ ] Action menu, user menu, and contextual menus render correct options
- [ ] Mobile sort dropdown behavior is correct (including “none”/reset option)
- [ ] Push notifications UI:
  - [ ] Correct rendering of link vs overlay mode
  - [ ] Close/dismiss interactions
- [ ] No clipped overlays due to container/scroll issues

**Pass criteria:** Popup/overlay interactions are predictable and visually correct.

---

## 5) Data Display Components

- [ ] Table headers, separators, filters, sorting states are correct
- [ ] Paginators (top + standard):
  - [ ] Page change controls
  - [ ] Disabled states
  - [ ] Invalid page input handling
- [ ] Badge/tag/message/severity visuals are consistent
- [ ] Loader/spinner/progress states are correct
- [ ] Empty/loading/error states still provide clear guidance

**Pass criteria:** Data exploration behaviors and states are unchanged.

---

## 6) Responsiveness

Check at minimum these breakpoints:
- Mobile (~360–430px)
- Tablet (~768–1024px)
- Desktop (>=1280px)

- [ ] No overlap/cutoff of controls or text
- [ ] Menus and drawers adapt correctly
- [ ] Tables and forms remain usable without horizontal breakage (unless expected)
- [ ] Touch targets remain comfortable on mobile

**Pass criteria:** Core journeys are fully usable on all target breakpoints.

---

## 7) Accessibility (WCAG AA practical checks)

- [ ] Visible focus indicator on all interactive elements
- [ ] Keyboard-only flow covers nav, forms, overlays, and submit actions
- [ ] Logical tab order and focus trapping in overlays/dialogs
- [ ] ARIA labels/roles for toggles, menus, popups, and custom controls
- [ ] Error messages are perceivable and associated to inputs
- [ ] Color contrast appears sufficient in default and error states
- [ ] Screen reader spot-check on key flows (optional but recommended)

**Pass criteria:** No critical keyboard/focus/aria regressions.

---

## 8) Content & Internationalization

- [ ] No missing translation keys shown in UI
- [ ] Plurals, dates, and formatting look correct
- [ ] Truncated text still has proper tooltip/overflow behavior
- [ ] Important labels/messages are still business-correct

**Pass criteria:** UI copy quality and localization behavior are intact.

---

## 9) Performance Perception (quick UX checks)

- [ ] First meaningful screen appears without unusual delay
- [ ] Menu open/close and typing interactions feel responsive
- [ ] No repeated spinner flashes during simple interactions
- [ ] No visible freezes when opening heavy components (calendar/table/upload)

**Pass criteria:** No noticeable perceived performance regression for end users.

---

## 10) High-Priority Component Spot-Check List

Prioritize these first (most impacted during migration):
- [ ] Calendar
- [ ] Upload + file-upload-drag-drop
- [ ] Top paginator / paginator
- [ ] Push notifications
- [ ] Action menu / user menu / base overlay panel wrappers
- [ ] Input expand / input wrapper
- [ ] Search bar / mobile sort dropdown
- [ ] Env directive visuals (chip/tag rendering)

**Pass criteria:** All high-priority components pass interaction + visual checks.

---

## Defect Logging Template (lightweight)

Use this format per issue:

- **ID:** UX-MIG-###
- **Component/Page:**
- **Viewport:** Desktop / Tablet / Mobile
- **Severity:** Critical / Major / Minor
- **Observed behavior:**
- **Expected behavior:**
- **Repro steps:**
- **Screenshot/Video:**
- **Linked ticket:**

---

## Suggested Execution Plan (not overload)

- Pass 1 (60–90 min): High-priority components only
- Pass 2 (45–60 min): Cross-cutting A11y + responsive checks
- Pass 3 (30 min): Retest reported fixes

If time is limited, complete Pass 1 + A11y keyboard flow first.
