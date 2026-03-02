# General Frontend Review Rules

These rules apply regardless of library usage. They cover Angular architecture, TypeScript quality, SCSS hygiene, performance, accessibility, and security.

---

## ANGULAR ARCHITECTURE

### GEN-A01 · Standalone Components

**Rule:** All components must be `standalone: true`. NgModule-based declarations are legacy and must not be introduced unless wrapping a third-party module that requires it.

### GEN-A02 · ChangeDetectionStrategy.OnPush

**Rule:** Every component must declare `changeDetection: ChangeDetectionStrategy.OnPush`. Default (CheckAlways) is a performance anti-pattern.

**Violation:** No `changeDetection` property on the `@Component` decorator.

### GEN-A03 · Signal-First Local State

**Rule:** Component-local state must use `signal()`. Use `@Input()` only when `input()` (signal input) is not feasible (e.g., form ControlValueAccessor). Use `model()` for two-way bindings.

**Violation:** `isOpen = false;` as a plain property updated in methods → use `isOpen = signal(false)`.

### GEN-A04 · Lifecycle Interface Declaration

**Rule:** Implemented lifecycle hooks must be declared in the `implements` clause.

**Violation:**
```typescript
export class MyComponent { ngOnInit() { ... } }  // missing implements OnInit
```

### GEN-A05 · Inject Function Over Constructor Injection

**Rule:** Prefer `inject()` for dependency injection over constructor parameters to reduce boilerplate and improve tree-shaking in standalone components.

**Preferred:**
```typescript
private readonly router = inject(Router);
```

### GEN-A06 · No Direct DOM Manipulation

**Rule:** Never use `document.querySelector`, `document.getElementById`, or direct `nativeElement` mutation outside of `AfterViewInit`/`AfterViewChecked`. Use `Renderer2` for DOM mutations.

### GEN-A07 · Lazy Loading for Feature Routes

**Rule:** Feature routes must use `loadComponent` or `loadChildren` (lazy loading). Eagerly loaded routes are only acceptable for the shell/root routes.

**Violation:**
```typescript
{ path: 'dashboard', component: DashboardComponent }
```
**Correct:**
```typescript
{ path: 'dashboard', loadComponent: () => import('./dashboard/dashboard.component').then(m => m.DashboardComponent) }
```

### GEN-A08 · No Logic in Templates

**Rule:** Template expressions must not contain complex logic. Extract to `computed()` signals or component methods.

**Violation:** `*ngIf="items.length > 0 && !isLoading && user?.role === 'admin'"` inline.

### GEN-A09 · TrackBy / track in @for

**Rule:** `@for` loops over object arrays must provide a `track` expression to avoid full DOM re-renders.

**Violation:** `@for (item of items; track $index)` on object arrays — use `track item.id`.

---

## TYPESCRIPT QUALITY

### GEN-T01 · No `any` Type

**Rule:** Do not use `any`. Use `unknown` and narrow with type guards, or type the data explicitly.

### GEN-T02 · No Non-Null Assertions Without Justification

**Rule:** `!` operator is forbidden without an explanatory comment. Use optional chaining `?.` or explicit null checks.

### GEN-T03 · Explicit Return Types on Public Methods

**Rule:** Public and protected methods must have explicit return types.

**Violation:** `getData() { return this.http.get(...); }` — missing `: Observable<MyType>`.

### GEN-T04 · Const Over Let

**Rule:** Use `const` for all variables that are not reassigned.

### GEN-T05 · No `var`

**Rule:** `var` is forbidden. Use `const` or `let`.

### GEN-T06 · Interface Over Type Alias for Object Shapes

**Rule:** Use `interface` for object shape definitions. Use `type` only for unions, intersections, or primitives.

### GEN-T07 · UPPER_CASE for Enum Members

**Rule:** Enum members must be UPPER_CASE.

**Violation:** `enum Status { active = 'active' }` → `enum Status { ACTIVE = 'active' }`.

### GEN-T08 · No `console.log` in Production Code

**Rule:** `console.log` and `console.debug` must not be present in committed code. `console.warn` and `console.error` are acceptable on error boundaries.

### GEN-T09 · No Unused Imports or Variables

**Rule:** Unused imports and variables must be removed. ESLint `unused-imports` plugin enforces this.

### GEN-T10 · RxJS Unsubscription

**Rule:** Every subscription in a component must be cleaned up. Acceptable patterns:
- `takeUntilDestroyed()` (Angular 16+)
- `InfUtils.destroy()` (library pattern)
- `async` pipe for template subscriptions

**Violation:** `this.service.data$.subscribe(...)` with no cleanup.

---

## SCSS / STYLING

### GEN-S01 · No Hardcoded Colors

**Rule:** Colors must come from CSS custom properties or SCSS variables from the design system. No hex, rgb, or named literals.

### GEN-S02 · :host for Component Encapsulation

**Rule:** Every component SCSS must wrap its selectors in `:host { }`. Top-level bare selectors affect global scope.

### GEN-S03 · No Inline Styles in Templates

**Rule:** `[style.color]="..."` or `style="..."` must not be used. Prefer CSS class binding `[class]` or `[ngClass]`.

**Exception:** Dynamic values that cannot be expressed as predefined classes (e.g., dynamic widths from user input).

### GEN-S04 · BEM Naming Consistency

**Rule:** CSS class names follow BEM: `block__element--modifier`. Abbreviations or random names are rejected.

### GEN-S05 · No !important

**Rule:** `!important` is forbidden except for third-party override last resort, which must be documented with a comment.

### GEN-S06 · Responsive via Media Query Mixin

**Rule:** Use the `@include media(...)` mixin from the design system. Do not write raw `@media` queries manually.

---

## PERFORMANCE

### GEN-P01 · No Heavy Computations in Template Expressions

**Rule:** Expressions inside templates calling functions (`{{ computeTotal() }}`) re-evaluate on every change detection cycle. Use `computed()` signal or a pipe.

### GEN-P02 · Image Optimization

**Rule:** Images must specify `width` and `height` attributes to prevent layout shifts (CLS). Use `loading="lazy"` for below-the-fold images.

### GEN-P03 · Avoid Memory Leaks in Services

**Rule:** Services that subscribe to observables (timers, WebSocket, router events) must implement `OnDestroy` or use `takeUntilDestroyed`.

---

## ACCESSIBILITY

### GEN-ACC01 · Interactive Elements Must Be Focusable

**Rule:** All clickable elements must use `<button>` or `<a>` (not `<div>` / `<span>`). Custom elements must have `role`, `tabindex=0`, and keyboard handlers.

### GEN-ACC02 · Images Must Have alt Text

**Rule:** `<img>` without `alt` or with `alt=""` only for decorative images. Informational images must have descriptive `alt`.

### GEN-ACC03 · Form Fields Need Labels

**Rule:** Every `<input>`, `<select>`, `<textarea>` must have an associated `<label>` via `for`/`id` or `aria-label`.

### GEN-ACC04 · Color Contrast

**Rule:** Text on backgrounds must meet WCAG AA contrast (4.5:1 for normal text, 3:1 for large text). Flag when tokens are mixed without checking contrast (e.g., muted text on surface-100).

### GEN-ACC05 · ARIA Role Misuse

**Rule:** Do not add `role="button"` to `<button>` elements (redundant). Do not put interactive elements inside `role="presentation"` or `aria-hidden="true"` containers.

---

## SECURITY

### GEN-SEC01 · No innerHTML / bypassSecurityTrust Without Comment

**Rule:** Any use of `[innerHTML]`, `DomSanitizer.bypassSecurityTrustHtml()`, or `bypassSecurityTrustUrl()` must be accompanied by a comment explaining why it is safe and what the input source is.

### GEN-SEC02 · No `eval` or `Function()` Constructor

**Rule:** Dynamic code execution is forbidden.

### GEN-SEC03 · No Hardcoded Secrets

**Rule:** API keys, tokens, passwords must not appear in source files. Use environment variables (`environment.ts`).

### GEN-SEC04 · HTTP Interceptors for Auth Headers

**Rule:** Authentication tokens must be injected via an `HttpInterceptor`, not manually set on every HTTP call.

### GEN-SEC05 · Route Guards for Protected Pages

**Rule:** All routes requiring authentication must have a `canActivate` guard. Do not rely solely on UI hiding.
