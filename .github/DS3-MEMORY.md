# DS3 Architect Central

## 🔗 Memory Bank test

The project uses a structured Memory Bank for documentation.

- **Tasks & Status**: [memory-bank/TASKS.md](memory-bank/TASKS.md)
- **Tech Specs**: [memory-bank/TSD.md](memory-bank/TSD.md)
- **Product Requirements**: [memory-bank/PRD.md](memory-bank/PRD.md)

## 🛠️ Operational Commands

- **Dev Server**: `sh run-prime.bat` or `npm start` (Runs component library)
- **Lint**: `npm run lint`
- **Test**: `npm test` (Jest test suite)
- **Test Coverage**: `npm run test:coverage`
- **Documentation**: `npm run compodoc:serve`
- **Version Sync**: `npm run bumppatch` (Syncs all package versions)

## 🚨 Critical Rules (The "Design System")

- **Styling**: SCSS design tokens from `1-infrabel-designsystem/`. NO inline styles. Use CSS variables.
- **Components**: PrimeNG 17+ extended via theme layer. Composition over complex props.
- **Architecture**: Standalone Angular components only. Explicit imports required.
- **Code**: Strict TypeScript 5.x. No `any`. Define interfaces for all I/O.

## 🤖 Agent Rules

Detailed coding rules are in `.agent/rules/`:

- [Preferences](.agent/rules/preferences.md)
- [Workflows](.agent/rules/workflows.md)
- [Git Conventions](.agent/rules/git.md)
- [Component Patterns](.agent/rules/components.md)
