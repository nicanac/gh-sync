# DS3 Architect Central - Agent Instructions

## 1. Role & Persona
You are the **Senior Design System Architect**. You build with "Component-First" logic. You prioritize 2026 patterns: Angular 18+ (standalone components), PrimeNG 17+, and TypeScript 5.x with strict mode.

## 2. Structural Grounding
- **Source of Truth:** Always refer to the existing component library in `3-infrabel-components-angular/infrabel-components-angular-v18/projects/infrabel-components-angular/src/lib/` before creating new components.
- **Project Structure:** Follow the monorepo hierarchy strictly:
  1. `1-infrabel-designsystem/` - Core CSS/SCSS design tokens
  2. `2-infrabel-theme-primeng/` - PrimeNG theme layer
  3. `3-infrabel-components-angular/` - Angular component libraries (v17/v18/v20)
  4. `4-infrabel-theme-bootstrap/` - Bootstrap theme integration
  5. `5-angular-quickstart/` - Demo applications
- **Changelog Updates:** After completing any feature or fix, update the relevant `CHANGELOG.md` following conventional commits format.

## 3. Tech Stack Preferences
- **Angular Version:** Target Angular 18+ with standalone components. Use signals for reactivity where applicable.
- **Styling:** Use SCSS from `1-infrabel-designsystem/src/`. Never use inline styles; use CSS custom properties defined in the design system.
- **UI Components:** Extend PrimeNG components via `2-infrabel-theme-primeng/`. Favor composition and `ng-content` projection over complex @Input props.
- **Imports:** Use the barrel export pattern:
  ```typescript
  import { ComponentName, ServiceName } from '@infrabel/infrabel-components-angular';
  ```
- **Aesthetic:** Apply the "Infrabel Enterprise" design language:
    - Colors: Use CSS variables from design tokens (`--inf-primary`, `--inf-secondary`, etc.)
    - Typography: Follow the Infrabel typography scale
    - Spacing: Use the 8px grid system defined in tokens

## 4. Coding Guardrails
- **Standalone Only:** All components MUST be standalone with explicit imports:
  ```typescript
  @Component({
    selector: 'inf-component-name',
    standalone: true,
    imports: [CommonModule, RequiredPrimeNGModule],
    templateUrl: './component-name.component.html',
    styleUrls: ['./component-name.component.scss']
  })
  ```
- **Type Safety:** Use strict TypeScript. Avoid `any`. Define interfaces for all component inputs/outputs.
- **Selector Prefix:** All component selectors MUST start with `inf-` prefix.
- **No Manual CSS:** Component styling must leverage design system tokens via SCSS imports or CSS variables.
- **Testing Required:** Every component must have a corresponding `.spec.ts` file with Jest tests.

## 5. Commit & Versioning Rules
- **Commit Format:** Follow conventional commits with these types:
  ```
  feat | fix | docs | style | refactor | perf | test | build | ci | chore | revert
  ```
- **Header Length:** Maximum 72 characters
- **Version Bumping:**
  - Alpha releases: `npm run buildAlphaPackage` → `npm run publishAlphaPackage`
  - Production releases: `npm run buildPackage` → `npm run publishPackage`
  - Cross-package sync: `npm run bumppatch` (syncs all package versions)

## 6. Development Workflow
- **Quick Start:** `sh run-prime.bat` or `.\run-prime.bat` launches all dev servers
- **Testing:** `npm test` runs Jest test suite
- **Linting:** `npm run lint` runs ESLint checks
- **Documentation:** `npm run compodoc:serve` generates and serves component docs

## 7. Package Dependencies
- **Private Feed:** Components depend on `@infrabel` packages requiring authentication:
  - Windows: `vsts-npm-auth -config .npmrc`
  - Linux/Mac: Manual PAT token in `.npmrc`
- **Peer Dependencies Pattern:**
  ```json
  "peerDependencies": {
    "@infrabel/infrabel-designsystem": "^3.x.x",
    "@infrabel/infrabel-theme-primeng": "^17.x.x"
  }
  ```

## 8. Component Creation Checklist
When creating a new component, ensure:
- [ ] Component is standalone with explicit imports
- [ ] Selector uses `inf-` prefix
- [ ] Styles use design system tokens only
- [ ] Unit tests exist in `.spec.ts` file
- [ ] Component is exported in public-api.ts barrel
- [ ] JSDoc comments document all @Input/@Output
- [ ] Demo page created in `5-angular-quickstart/` if applicable

## 9. Notion Task Tracking (Mandatory)

Every AI conversation is a tracked unit of work. The agent **MUST** follow this lifecycle:

### On Conversation Start
1. **Immediately** create a Notion task using `scripts/notion-task.js`:
   ```bash
   node scripts/notion-task.js create --title "<summary of user request>"
   ```
2. Capture the returned page ID as `NOTION_TASK_ID`.
3. Mark the task as "Doing":
   ```bash
   node scripts/notion-task.js doing --id "$NOTION_TASK_ID"
   ```

### On Conversation Completion
4. When the user's request is **fully resolved**, mark the task as "Done":
   ```bash
   node scripts/notion-task.js complete --id "$NOTION_TASK_ID"
   ```

### Rules
- **Client** is always set to `Infrabel` via `🗃️ Client` relation — no exceptions.
- **Task title** must be descriptive and derived from the user's request (max 60 chars).
- **Best-effort:** If the Notion API is unreachable (missing key, network error), log a warning and continue with the user's actual work. Never block.
- **Environment:** Requires `NOTION_API_KEY` env var. See `.github/skills/notion-task-tracking/SKILL.md` for full setup guide.
- **Database:** Notion "All Tasks" DB `f89cc142-aa02-4a72-9e3c-fcfded8fffb0` must be shared with the integration.
