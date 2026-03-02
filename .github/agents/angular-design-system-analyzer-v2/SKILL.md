---
name: angular-design-system-analyzer-v2
description: Analyze and document Angular design systems based on PrimeNG with custom CSS. Detects architecture patterns, components, styling conventions, and generates AI rules for code review and component creation. Use for analyzing Angular design systems, onboarding developers, performing code reviews, generating conformant components, and understanding PrimeNG customizations. This v2 uses Node.js scripts instead of Python for Windows compatibility.
---

# Angular Design System Analyzer v2 (Node.js)

This skill provides comprehensive analysis capabilities for Angular design systems, particularly those built on PrimeNG with custom CSS customizations.

> **v2 Note**: This version uses **Node.js** scripts instead of Python, making it compatible with Windows environments where only Node.js is available.

## Capabilities

1. **Architecture Analysis** - Map project structure, modules, components, and dependencies
2. **Component Extraction** - Analyze all components, detect PrimeNG usage and customizations
3. **Style Analysis** - Extract theming system, CSS/SCSS variables, and PrimeNG overrides
4. **Pattern Detection** - Identify coding conventions, architectural patterns, and best practices
5. **AI Rules Generation** - Create comprehensive guidelines for code review and development

## When to Use This Skill

Use this skill when you need to:

- Analyze an Angular design system repository
- Document architecture and patterns for developer onboarding
- Perform code review on Angular components
- Generate new components conforming to existing patterns
- Understand PrimeNG customizations and theming
- Create development guidelines based on existing codebase

## Prerequisites

- **Node.js** (v16+) must be installed and available on the system PATH

## Workflow

### Phase 1: Repository Analysis

1. **Clone or access the Angular design system repository**
   - If given a GitHub URL, clone it: `git clone <url> <destination>`
   - If given a local path, use it directly

2. **Run structure analysis**

   ```bash
   node .agent/skills/angular-design-system-analyzer-v2/scripts/analyze_structure.mjs <repo_path> structure.json
   ```

   This generates a JSON file containing:
   - Project folder structure
   - Module organization
   - Component, service, directive, and pipe inventory
   - Naming pattern detection
   - Configuration files

3. **Extract component information**

   ```bash
   node .agent/skills/angular-design-system-analyzer-v2/scripts/extract_components.mjs <repo_path> components.json
   ```

   This generates:
   - Complete component catalog with metadata
   - PrimeNG components used
   - Custom vs. PrimeNG-wrapped components
   - Input/output patterns
   - Service dependencies

4. **Analyze styles and theming**

   ```bash
   node .agent/skills/angular-design-system-analyzer-v2/scripts/analyze_styles.mjs <repo_path> styles.json
   ```

   This extracts:
   - SCSS/CSS variables
   - Color palette
   - Theme files
   - PrimeNG style overrides
   - Mixins and functions

5. **Detect code patterns**

   ```bash
   node .agent/skills/angular-design-system-analyzer-v2/scripts/detect_patterns.mjs <repo_path> patterns.json
   ```

   This identifies:
   - Naming conventions
   - Architectural patterns (services, state management, lazy loading)
   - Import patterns
   - Code standards
   - RxJS usage patterns

### Phase 2: Generate AI Rules and Documentation

6. **Generate AI rules for code review**

   ```bash
   node .agent/skills/angular-design-system-analyzer-v2/scripts/generate_ai_rules.mjs structure.json components.json styles.json patterns.json ai_rules.md
   ```

   This creates a comprehensive markdown document with:
   - Architecture overview
   - Naming conventions
   - Component creation rules
   - Styling guidelines
   - PrimeNG customization rules
   - Code review checklist
   - Best practices

### Phase 3: Apply Knowledge

7. **Use the generated documentation**
   - Read `ai_rules.md` for comprehensive guidelines
   - Reference JSON files for specific component or style information
   - Use templates in `templates/` for creating new components

## Code Review Usage

When reviewing Angular code:

1. **Load the AI rules**: Read the generated `ai_rules.md` file
2. **Check compliance**:
   - Verify naming conventions match project standards
   - Ensure component structure follows established patterns
   - Validate style usage (variables, not hardcoded values)
   - Check PrimeNG customizations follow guidelines
3. **Reference specific patterns**: Consult JSON files for details on common inputs, outputs, services
4. **Suggest improvements**: Based on detected best practices

## Component Creation Usage

When creating new components:

1. **Use the component template**:

   ```bash
   cp .agent/skills/angular-design-system-analyzer-v2/templates/component-template.component.* <destination>/
   ```

2. **Follow naming conventions** from `ai_rules.md`

3. **Reference existing components**: Check `components.json` for similar components and their patterns

4. **Use established styles**: Reference `styles.json` for available variables, mixins, and color palette

5. **Follow PrimeNG patterns**: If wrapping PrimeNG components, check `components.json` for existing customization examples

## PrimeNG Customization Guidelines

When customizing PrimeNG components:

1. **Check existing customizations**: Review `styles.json` for PrimeNG overrides already in place
2. **Use theme variables**: Apply SCSS variables from the design system
3. **Create wrapper components**: For heavily customized components, create wrapper components (see examples in `components.json`)
4. **Document overrides**: Add comments explaining why overrides are necessary
5. **Test across themes**: Ensure customizations work with all PrimeNG themes used

## Output Files Reference

| File              | Content                                                | Usage                                |
| ----------------- | ------------------------------------------------------ | ------------------------------------ |
| `structure.json`  | Project architecture, folder structure, file inventory | Understanding project organization   |
| `components.json` | Component catalog, PrimeNG usage, patterns             | Component creation, code review      |
| `styles.json`     | Variables, theming, PrimeNG overrides                  | Styling, theming, customization      |
| `patterns.json`   | Naming conventions, architectural patterns             | Code standards, best practices       |
| `ai_rules.md`     | Comprehensive guidelines document                      | Code review, onboarding, development |

## Tips

- **Run all analysis scripts** to get complete picture of the design system
- **Keep analysis up-to-date**: Re-run scripts when significant changes are made to the codebase
- **Use JSON files for automation**: Parse JSON files programmatically for automated checks
- **Customize templates**: Adapt component templates based on project-specific patterns
- **Share ai_rules.md**: Use as onboarding documentation for new developers

## Limitations

- Analysis is based on static code analysis and naming patterns
- May not detect runtime behaviors or dynamic patterns
- PrimeNG detection relies on import statements and class names
- Large repositories (>1000 files) may take longer to analyze
- Requires TypeScript and standard Angular project structure
