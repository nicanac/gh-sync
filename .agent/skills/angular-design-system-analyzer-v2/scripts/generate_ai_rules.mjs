#!/usr/bin/env node
/**
 * Generate AI rules for code review and component creation.
 * Creates guidelines based on detected patterns and conventions.
 */
import fs from 'node:fs';

function loadJson(filePath) {
  try { return JSON.parse(fs.readFileSync(filePath, 'utf-8')); }
  catch (e) {
    if (e.code === 'ENOENT') { console.warn(`Warning: ${filePath} not found, using empty data`); return {}; }
    console.warn(`Warning: Error parsing ${filePath}: ${e.message}`); return {};
  }
}

function generateAiRules(structureFile, componentsFile, stylesFile, patternsFile, outputFile = 'ai_rules.md') {
  const structure = loadJson(structureFile);
  const components = loadJson(componentsFile);
  const styles = loadJson(stylesFile);
  const patterns = loadJson(patternsFile);
  const rulesMd = generateRulesDocument(structure, components, styles, patterns);
  fs.writeFileSync(outputFile, rulesMd, 'utf-8');
  return outputFile;
}

function generateRulesDocument(structure, components, styles, patterns) {
  let doc = `# AI Rules for Angular Design System

This document contains rules and guidelines for code review and component creation in this Angular design system.

## Table of Contents

1. [Project Architecture](#project-architecture)
2. [Naming Conventions](#naming-conventions)
3. [Component Creation Rules](#component-creation-rules)
4. [Styling Guidelines](#styling-guidelines)
5. [PrimeNG Customization Rules](#primeng-customization-rules)
6. [Code Review Checklist](#code-review-checklist)
7. [Best Practices](#best-practices)

---

## Project Architecture

`;
  doc += genArchSection(structure, patterns);
  doc += '\n---\n\n## Naming Conventions\n\n';
  doc += genNamingSection(patterns);
  doc += '\n---\n\n## Component Creation Rules\n\n';
  doc += genComponentSection(components, patterns);
  doc += '\n---\n\n## Styling Guidelines\n\n';
  doc += genStylingSection(styles);
  doc += '\n---\n\n## PrimeNG Customization Rules\n\n';
  doc += genPrimengSection(components, styles);
  doc += '\n---\n\n## Code Review Checklist\n\n';
  doc += genChecklist(patterns, components, styles);
  doc += '\n---\n\n## Best Practices\n\n';
  doc += genBestPractices(patterns);
  return doc;
}

function genArchSection(structure, patterns) {
  let s = '';
  const fp = patterns.folder_structure_patterns || {};
  s += `### Organization Type\n\nThis project follows a **${fp.organization_type || 'unknown'}** architecture.\n\n`;
  const stats = structure.statistics;
  if (stats) {
    s += '### Project Statistics\n\n';
    s += `- **Modules**: ${stats.total_modules || 0}\n`;
    s += `- **Components**: ${stats.total_components || 0}\n`;
    s += `- **Services**: ${stats.total_services || 0}\n`;
    s += `- **Directives**: ${stats.total_directives || 0}\n`;
    s += `- **Pipes**: ${stats.total_pipes || 0}\n\n`;
  }
  const ap = patterns.architectural_patterns || {};
  if (Object.keys(ap).length) {
    s += '### Architectural Patterns\n\n';
    if (ap.uses_services) s += '- ✅ Uses **Services** for business logic and data access\n';
    if (ap.uses_state_management) s += `- ✅ Uses **${ap.state_management_library || 'Unknown'}** for state management\n`;
    if (ap.uses_lazy_loading) s += '- ✅ Uses **Lazy Loading** for modules\n';
    if (ap.uses_standalone_components) s += '- ✅ Uses **Standalone Components**\n';
    if (ap.uses_reactive_forms) s += '- ✅ Uses **Reactive Forms**\n';
    s += '\n';
  }
  return s;
}

function genNamingSection(patterns) {
  let s = '';
  const n = patterns.naming_conventions || {};
  const fn = n.file_naming || {};
  s += '### File Naming\n\n';
  s += `- **Pattern**: ${fn.pattern || 'kebab-case'}\n`;
  const cs = fn.common_suffixes || {};
  if (Object.keys(cs).length) { s += '- **Common suffixes**:\n'; for (const sf of Object.keys(cs).slice(0, 5)) s += `  - \`.${sf}.ts\`\n`; }
  s += '\n### Class Naming\n\n';
  const cn = n.class_naming || {};
  s += `- **Pattern**: ${cn.pattern || 'PascalCase'}\n`;
  s += '- **Examples**:\n  - Components: `ButtonComponent`, `CardComponent`\n  - Services: `DataService`, `AuthService`\n  - Directives: `HighlightDirective`\n\n';
  s += '### Variable Naming\n\n';
  const vn = n.variable_naming || {};
  s += `- **Pattern**: ${vn.pattern || 'camelCase'}\n`;
  s += `- **Constants**: ${vn.constants || 'UPPER_SNAKE_CASE'}\n`;
  s += `- **Private members**: ${vn.private_members || 'camelCase'}\n\n`;
  return s;
}

function genComponentSection(components, patterns) {
  let s = '### Component Structure\n\nEvery component MUST include:\n\n';
  s += '1. **TypeScript file** (`.component.ts`)\n';
  s += '2. **Template file** (`.component.html`)\n';
  s += '3. **Style file** (`.component.scss` or `.component.css`)\n';
  s += '4. **Test file** (`.component.spec.ts`) - if testing is configured\n\n';
  s += `### Component Metadata

\`\`\`typescript
@Component({
  selector: 'app-component-name',
  templateUrl: './component-name.component.html',
  styleUrls: ['./component-name.component.scss']
})
export class ComponentNameComponent implements OnInit {
  // Component implementation
}
\`\`\`

`;
  const cp = components.component_patterns || {};
  const ci = cp.common_inputs || {};
  if (Object.keys(ci).length) { s += '### Common Inputs\n\nThese inputs are commonly used across components:\n\n'; for (const i of Object.keys(ci).slice(0, 5)) s += `- \`@Input() ${i}\`\n`; s += '\n'; }
  const co = cp.common_outputs || {};
  if (Object.keys(co).length) { s += '### Common Outputs\n\nThese outputs are commonly used across components:\n\n'; for (const o of Object.keys(co).slice(0, 5)) s += `- \`@Output() ${o}\`\n`; s += '\n'; }
  const ch = cp.common_lifecycle_hooks || {};
  if (Object.keys(ch).length) { s += '### Common Lifecycle Hooks\n\n'; for (const h of Object.keys(ch).slice(0, 5)) s += `- \`${h}()\`\n`; s += '\n'; }
  return s;
}

function genStylingSection(styles) {
  let s = '';
  const st = styles.statistics || {};
  s += '### Style File Organization\n\n';
  s += `- **Global styles**: ${st.global_styles || 0} files\n`;
  s += `- **Component styles**: ${st.component_styles || 0} files\n`;
  s += `- **Theme files**: ${st.theme_files || 0} files\n\n`;
  s += '### Variables\n\n';
  s += `- **SCSS variables**: ${st.scss_variables || 0} defined\n`;
  s += `- **CSS custom properties**: ${st.css_variables || 0} defined\n\n`;
  const cp = styles.color_palette || {};
  const entries = Object.entries(cp);
  if (entries.length) {
    s += '### Color Palette\n\nUse these predefined color variables:\n\n';
    for (const [vn, vv] of entries.slice(0, 10)) s += `- \`${vn}\`: ${vv}\n`;
    if (entries.length > 10) s += `\n... and ${entries.length - 10} more color variables\n`;
    s += '\n';
  }
  const mx = styles.mixins || [];
  if (mx.length) {
    const unique = Object.values(mx.reduce((a, m) => { a[m.name] = m; return a; }, {}));
    s += '### Available Mixins\n\n';
    for (const m of unique.slice(0, 5)) s += `- \`@mixin ${m.name}${m.parameters || ''}\`\n`;
    s += '\n';
  }
  s += `### Styling Rules

1. **Always use SCSS variables** for colors, spacing, and typography
2. **Avoid hardcoded values** - use design tokens
3. **Component styles should be scoped** to the component
4. **Use mixins** for reusable style patterns
5. **Follow BEM naming** for CSS classes when appropriate

`;
  return s;
}

function genPrimengSection(components, styles) {
  let s = '';
  const pc = components.primeng_components_used || [];
  if (pc.length) {
    s += '### PrimeNG Components Used\n\nThis design system uses the following PrimeNG components:\n\n';
    for (const c of pc.slice(0, 15)) s += `- \`${c}\`\n`;
    if (pc.length > 15) s += `\n... and ${pc.length - 15} more\n`;
    s += '\n';
  }
  s += `### Customization Guidelines

1. **Override PrimeNG styles** in dedicated theme files
2. **Use \`::ng-deep\`** carefully - prefer component-level customization
3. **Create wrapper components** for heavily customized PrimeNG components
4. **Document all customizations** in component comments
5. **Test customizations** across all PrimeNG themes

`;
  const po = styles.primeng_overrides || [];
  if (po.length) {
    s += `### Common PrimeNG Overrides

Found ${po.length} files with PrimeNG style overrides.

**Example override patterns**:

\`\`\`scss
// Override PrimeNG button styles
::ng-deep .p-button {
  border-radius: $border-radius;
  padding: $button-padding;
}
\`\`\`

`;
  }
  return s;
}

function genChecklist() {
  return `Use this checklist when reviewing code:

### General

- [ ] Code follows naming conventions
- [ ] No console.log statements in production code
- [ ] Proper error handling implemented
- [ ] Code is properly formatted and linted

### Components

- [ ] Component selector follows naming convention (kebab-case)
- [ ] Component has proper lifecycle hooks
- [ ] Inputs and outputs are properly typed
- [ ] Component is properly documented
- [ ] Template and styles are in separate files
- [ ] OnPush change detection used when appropriate

### Styles

- [ ] Uses SCSS variables instead of hardcoded values
- [ ] No !important unless absolutely necessary
- [ ] Follows established color palette
- [ ] Responsive design considerations
- [ ] PrimeNG overrides are properly scoped

### Services

- [ ] Service is properly injectable
- [ ] Proper dependency injection
- [ ] Error handling for HTTP calls
- [ ] Observables properly managed (unsubscribe)

### Testing

- [ ] Unit tests exist and pass
- [ ] Test coverage is adequate
- [ ] Edge cases are tested

`;
}

function genBestPractices() {
  return `### TypeScript

- Use **strict type checking**
- Prefer **interfaces** over type aliases for object shapes
- Use **enums** for fixed sets of values
- Avoid **any** type - use **unknown** if type is truly unknown

### Angular Specific

- Use **OnPush change detection** for performance
- Implement **trackBy** functions for ngFor loops
- Use **async pipe** for observables in templates
- Unsubscribe from observables to prevent memory leaks
- Use **lazy loading** for feature modules

### RxJS

- Prefer **declarative** approach over imperative
- Use **operators** like map, filter, switchMap appropriately
- Handle errors with **catchError** operator
- Use **shareReplay** to avoid multiple HTTP calls

### Performance

- Minimize **bundle size** - use lazy loading
- Optimize **change detection** strategy
- Use **pure pipes** when possible
- Avoid complex logic in templates
- Use **virtual scrolling** for long lists

`;
}

// --- Main ---
const args = process.argv.slice(2);
if (args.length < 4) {
  console.log('Usage: node generate_ai_rules.mjs <structure.json> <components.json> <styles.json> <patterns.json> [output.md]');
  process.exit(1);
}
try {
  console.log('Generating AI rules from analysis files...');
  const out = generateAiRules(args[0], args[1], args[2], args[3], args[4] || 'ai_rules.md');
  console.log(`\n✅ AI rules generated successfully!\n   Output: ${out}`);
} catch (e) { console.error(`❌ Error: ${e.message}`); process.exit(1); }
