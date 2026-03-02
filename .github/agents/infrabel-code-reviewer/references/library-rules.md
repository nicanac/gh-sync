# Library Compliance Rules — @infrabel/infrabel-components-angular v18

Reference: `ai_rules.md` in `3-infrabel-components-angular/infrabel-components-angular-v18/`

---

## LIB-01 · Component Import Source

**Rule:** All Infrabel components must be imported from `@infrabel/infrabel-components-angular`, never from deep paths.

**Violation:**
```typescript
import { ToastComponent } from '@infrabel/infrabel-components-angular/lib/toast/toast.component';
```
**Correct:**
```typescript
import { ToastComponent } from '@infrabel/infrabel-components-angular';
```

---

## LIB-02 · Selector Prefix

**Rule:** Infrabel component selectors use the `inf-` prefix (kebab-case). Directive selectors use the `inf` prefix (camelCase attribute). Never replicate or shadow these selectors in consumer code.

**Violation:** A consumer defines `selector: 'inf-button'` in their own component.

---

## LIB-03 · No Hardcoded Design Tokens

**Rule:** Color, spacing, radius, and layout values must use CSS custom properties from the design system, never hardcoded values.

**Severity:** High

**Violations to flag:**
- `color: #025697` → use `var(--theme-primary)`
- `padding: 16px` → use `var(--spacing-5)` (= 1.6rem)
- `border-radius: 8px` → use `var(--radius-m)` (= 0.8rem)
- `color: white` on themed surfaces → use `var(--theme-text-invert)`
- `background: #f2f2f2` → use `var(--theme-surface-100)`

**Allowed exceptions:** SVG viewport/stroke attributes, `z-index`, `transition` durations.

---

## LIB-04 · Toast Usage via ToastComponent + ToastSeverity

**Rule:** Use `<inf-toast>` + `MessageService` from PrimeNG. Use `ToastSeverity` enum for severity values.

**Violation:** Hardcoded string `severity: 'success'` → use `ToastSeverity.SUCCESS`.

---

## LIB-05 · Error Pages via InfErrorPageComponent

**Rule:** HTTP error pages (401, 404, 500, 504) must use `<inf-error-page [statusCode]="...">` or the specific error page components. Do not build custom error pages from scratch.

---

## LIB-06 · Correct InfMenuItem Shape

**Rule:** Navigation model passed to `inf-nav`, `inf-mega-menu`, `inf-side-menu` must use the `InfMenuItem` interface. Do not extend or replace it with custom interfaces.

**Key properties:** `label`, `routerLink`, `icon`, `items`, `active`, `disabled`, `separator`.

---

## LIB-07 · Theme Tokens for Dark/Light

**Rule:** Consumer components that need to support dark/light themes must use `--theme-*` tokens. Never use `prefers-color-scheme` media queries directly in component SCSS — the library handles theme switching via `ThemeSwitchService` and CSS class on the root element.

---

## LIB-08 · Language via LanguageService

**Rule:** Language selection must use `LanguageService.setLanguage(Language.XX)`. Use the `Language` enum. Do not write to `localStorage` key `'lang'` directly.

---

## LIB-09 · StorageKey Enum

**Rule:** Any access to the library's localStorage keys must use the `StorageKey` enum:
- `StorageKey.LANG` (`'lang'`)
- `StorageKey.THEME` (`'inf-theme'`)
- `StorageKey.CONFIGURATION` (`'configuration'`)

**Violation:** `localStorage.getItem('inf-theme')` → use `StorageKey.THEME`.

---

## LIB-10 · PrimeNG Not Imported Directly for Infrabel-Wrapped Components

**Rule:** If the library ships a wrapper for a PrimeNG component, consumers must use the wrapper, not PrimeNG directly.

| Infrabel wrapper | Do NOT use directly |
|-----------------|---------------------|
| `inf-calendar` | `p-calendar` for date selection |
| `inf-upload` | `p-fileUpload` for file upload |
| `inf-loader` | `p-progressSpinner` for loading states |
| `inf-toast` | `p-toast` for notifications |
| `inf-message` | `p-messages` for inline messages |
| `inf-table-filter` | raw `p-sidebar` for table filters |

---

## LIB-11 · ChangeData Model for Phone Input

**Rule:** The `(onChangeData)` output of `inf-phone-input` emits `ChangeData`. Consumers must type their handler accordingly:
```typescript
onPhoneChange(data: ChangeData): void { ... }
```

---

## LIB-12 · Upload Interface Compliance

**Rule:** `inf-upload` event handlers must use typed interfaces:
- `(onSelect)` → `{ files: File[] }`
- `(onRename)` → `FileRenameEvent`
- Files in progress → `InProgressFile`
- Completed files → `UploadFile`

---

## LIB-13 · InfUtils Destroy Pattern

**Rule:** Components consuming library services via Observables must use `InfUtils.destroy()` for cleanup, not a manual `Subject<void>`.

**Violation:**
```typescript
private destroy$ = new Subject<void>();
ngOnDestroy() { this.destroy$.next(); this.destroy$.complete(); }
```
**Correct:**
```typescript
private destroy$ = InfUtils.destroy();
```

---

## LIB-14 · InfUtils.handleInputFocus in AppComponent

**Rule:** Consumer `AppComponent` must call `InfUtils.handleInputFocus(document, renderer)` in `ngOnInit` to enable keyboard focus rings across the app.

---

## LIB-15 · Transloco for i18n (not Angular built-in)

**Rule:** Consumer apps that use Infrabel components must also use Transloco for i18n consistency. Do not mix Angular's built-in i18n (`$localize`) with Transloco.

---

## LIB-16 · ::ng-deep Scoping

**Rule:** Any `::ng-deep` present in consumer SCSS must be scoped to `:host`. Unscoped `::ng-deep` at global level risks overriding library internals unintentionally.

**Violation:**
```scss
::ng-deep .p-button { ... }  // global — FORBIDDEN
```
**Correct:**
```scss
:host { ::ng-deep .p-button { ... } }
```

---

## LIB-17 · Standalone Components Required in Consumer

**Rule:** Consumer components that directly import Infrabel components must themselves be `standalone: true`. NgModule imports of Infrabel artifacts are not supported.
