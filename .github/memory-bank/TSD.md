# DS3 Technical Specification Document

## 📁 Project Structure

```
a1831-ds/
├── 1-infrabel-designsystem/          # Core design tokens & assets
│   ├── src/
│   │   ├── scss/                     # SCSS variables, mixins, utilities
│   │   ├── fonts/                    # Typography assets
│   │   └── icons/                    # Icon library
│   └── dist/                         # Compiled CSS output
│
├── 2-infrabel-theme-primeng/         # PrimeNG theme layer
│   └── infrabel-theme-primeng-v17/   # Theme for PrimeNG 17.x
│
├── 3-infrabel-components-angular/    # Angular component libraries
│   ├── infrabel-components-angular-v17/
│   ├── infrabel-components-angular-v18/  # PRIMARY DEVELOPMENT TARGET
│   │   └── projects/
│   │       ├── infrabel-components-angular/
│   │       │   └── src/lib/          # 50+ production components
│   │       └── infrabel-demo-app/    # Component showcase
│   └── infrabel-components-angular-v20/
│
├── 4-infrabel-theme-bootstrap/       # Bootstrap theme integration
│
├── 5-angular-quickstart/             # Demo & example applications
│
├── 6-wiki/                           # Documentation
│
└── scripts/                          # Build & utility scripts
```

## 🔧 Technology Stack

| Layer | Technology | Version |
|-------|------------|---------|
| Framework | Angular | 18.x (primary), 17.x, 20.x |
| UI Library | PrimeNG | 17.x |
| Styling | SCSS + CSS Variables | - |
| Testing | Jest | Latest |
| Documentation | Compodoc | Latest |
| Bundler | Angular CLI | 18.x |
| Package Manager | npm | 10.x |

## 📦 Package Architecture

### Dependency Flow
```
┌─────────────────────────┐
│  1-infrabel-designsystem │  ◄── Foundation (CSS tokens)
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ 2-infrabel-theme-primeng │  ◄── Theme Layer (PrimeNG styling)
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│3-infrabel-components-ang │  ◄── Component Library (Angular)
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│   Consumer Applications  │  ◄── End-user apps
└─────────────────────────┘
```

### Peer Dependencies
```json
{
  "@infrabel/infrabel-designsystem": "^3.x.x",
  "@infrabel/infrabel-theme-primeng": "^17.x.x",
  "@angular/core": "^18.x.x",
  "primeng": "^17.x.x"
}
```

## 🏗️ Component Architecture

### Standalone Component Pattern
```typescript
@Component({
  selector: 'inf-[component-name]',
  standalone: true,
  imports: [CommonModule, /* PrimeNG modules */],
  templateUrl: './[component-name].component.html',
  styleUrls: ['./[component-name].component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class [ComponentName]Component {
  // Use signals for reactive state (Angular 18+)
  readonly value = signal<T>(initialValue);
  
  // Typed inputs/outputs
  @Input() config: ComponentConfig;
  @Output() change = new EventEmitter<ChangeEvent>();
}
```

### File Naming Convention
```
component-name/
├── component-name.component.ts       # Component class
├── component-name.component.html     # Template
├── component-name.component.scss     # Styles (design tokens only)
├── component-name.component.spec.ts  # Unit tests
├── component-name.model.ts           # Interfaces/types
└── index.ts                          # Barrel export
```

## 🎨 Design Token Structure

### CSS Variable Naming
```scss
// Colors
--inf-primary: #...;
--inf-secondary: #...;
--inf-surface: #...;
--inf-border: #...;

// Typography
--inf-font-family: ...;
--inf-font-size-sm: ...;
--inf-font-size-md: ...;
--inf-font-size-lg: ...;

// Spacing (8px grid)
--inf-spacing-xs: 4px;
--inf-spacing-sm: 8px;
--inf-spacing-md: 16px;
--inf-spacing-lg: 24px;
--inf-spacing-xl: 32px;
```

## 🔒 Security & Authentication

### NPM Feed Access
- **Registry**: Azure DevOps Artifacts (@infrabel scope)
- **Windows Auth**: `vsts-npm-auth -config .npmrc`
- **Unix Auth**: PAT token in `.npmrc`

## 📚 API Documentation
- Generated via Compodoc: `npm run compodoc:serve`
- Available at: http://localhost:8080 (when running)
