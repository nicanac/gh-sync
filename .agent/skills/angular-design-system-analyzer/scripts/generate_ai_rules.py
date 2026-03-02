#!/usr/bin/env python3
"""
Generate AI rules for code review and component creation.
Creates guidelines based on detected patterns and conventions.
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Any


def generate_ai_rules(
    structure_file: str,
    components_file: str,
    styles_file: str,
    patterns_file: str,
    output_file: str = "ai_rules.md",
) -> str:
    """
    Generate AI rules based on analysis files.

    Args:
        structure_file: Path to structure analysis JSON
        components_file: Path to components analysis JSON
        styles_file: Path to styles analysis JSON
        patterns_file: Path to patterns analysis JSON
        output_file: Output file path

    Returns:
        Path to generated rules file
    """
    # Load analysis files
    structure = load_json(structure_file)
    components = load_json(components_file)
    styles = load_json(styles_file)
    patterns = load_json(patterns_file)

    # Generate rules document
    rules_md = generate_rules_document(structure, components, styles, patterns)

    # Write to file
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(rules_md)

    return output_file


def load_json(file_path: str) -> Dict[str, Any]:
    """Load JSON file."""
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Warning: {file_path} not found, using empty data")
        return {}
    except json.JSONDecodeError as e:
        print(f"Warning: Error parsing {file_path}: {e}")
        return {}


def generate_rules_document(
    structure: Dict[str, Any],
    components: Dict[str, Any],
    styles: Dict[str, Any],
    patterns: Dict[str, Any],
) -> str:
    """Generate the AI rules markdown document."""

    doc = """# AI Rules for Angular Design System

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

"""

    # Add architecture information
    doc += generate_architecture_section(structure, patterns)

    doc += "\n---\n\n## Naming Conventions\n\n"
    doc += generate_naming_conventions_section(patterns)

    doc += "\n---\n\n## Component Creation Rules\n\n"
    doc += generate_component_rules_section(components, patterns)

    doc += "\n---\n\n## Styling Guidelines\n\n"
    doc += generate_styling_guidelines_section(styles)

    doc += "\n---\n\n## PrimeNG Customization Rules\n\n"
    doc += generate_primeng_rules_section(components, styles)

    doc += "\n---\n\n## Code Review Checklist\n\n"
    doc += generate_code_review_checklist(patterns, components, styles)

    doc += "\n---\n\n## Best Practices\n\n"
    doc += generate_best_practices_section(patterns)

    return doc


def generate_architecture_section(
    structure: Dict[str, Any], patterns: Dict[str, Any]
) -> str:
    """Generate architecture section."""
    section = ""

    folder_patterns = patterns.get("folder_structure_patterns", {})
    org_type = folder_patterns.get("organization_type", "unknown")

    section += f"### Organization Type\n\n"
    section += f"This project follows a **{org_type}** architecture.\n\n"

    if structure.get("statistics"):
        stats = structure["statistics"]
        section += f"### Project Statistics\n\n"
        section += f"- **Modules**: {stats.get('total_modules', 0)}\n"
        section += f"- **Components**: {stats.get('total_components', 0)}\n"
        section += f"- **Services**: {stats.get('total_services', 0)}\n"
        section += f"- **Directives**: {stats.get('total_directives', 0)}\n"
        section += f"- **Pipes**: {stats.get('total_pipes', 0)}\n\n"

    arch_patterns = patterns.get("architectural_patterns", {})
    if arch_patterns:
        section += f"### Architectural Patterns\n\n"
        if arch_patterns.get("uses_services"):
            section += "- ✅ Uses **Services** for business logic and data access\n"
        if arch_patterns.get("uses_state_management"):
            lib = arch_patterns.get("state_management_library", "Unknown")
            section += f"- ✅ Uses **{lib}** for state management\n"
        if arch_patterns.get("uses_lazy_loading"):
            section += "- ✅ Uses **Lazy Loading** for modules\n"
        if arch_patterns.get("uses_standalone_components"):
            section += "- ✅ Uses **Standalone Components**\n"
        if arch_patterns.get("uses_reactive_forms"):
            section += "- ✅ Uses **Reactive Forms**\n"
        section += "\n"

    return section


def generate_naming_conventions_section(patterns: Dict[str, Any]) -> str:
    """Generate naming conventions section."""
    section = ""

    naming = patterns.get("naming_conventions", {})

    section += "### File Naming\n\n"
    file_naming = naming.get("file_naming", {})
    section += f"- **Pattern**: {file_naming.get('pattern', 'kebab-case')}\n"

    common_suffixes = file_naming.get("common_suffixes", {})
    if common_suffixes:
        section += "- **Common suffixes**:\n"
        for suffix, count in list(common_suffixes.items())[:5]:
            section += f"  - `.{suffix}.ts`\n"
    section += "\n"

    section += "### Class Naming\n\n"
    class_naming = naming.get("class_naming", {})
    section += f"- **Pattern**: {class_naming.get('pattern', 'PascalCase')}\n"
    section += "- **Examples**:\n"
    section += "  - Components: `ButtonComponent`, `CardComponent`\n"
    section += "  - Services: `DataService`, `AuthService`\n"
    section += "  - Directives: `HighlightDirective`\n\n"

    section += "### Variable Naming\n\n"
    var_naming = naming.get("variable_naming", {})
    section += f"- **Pattern**: {var_naming.get('pattern', 'camelCase')}\n"
    section += f"- **Constants**: {var_naming.get('constants', 'UPPER_SNAKE_CASE')}\n"
    section += (
        f"- **Private members**: {var_naming.get('private_members', 'camelCase')}\n\n"
    )

    return section


def generate_component_rules_section(
    components: Dict[str, Any], patterns: Dict[str, Any]
) -> str:
    """Generate component creation rules."""
    section = ""

    section += "### Component Structure\n\n"
    section += "Every component MUST include:\n\n"
    section += "1. **TypeScript file** (`.component.ts`)\n"
    section += "2. **Template file** (`.component.html`)\n"
    section += "3. **Style file** (`.component.scss` or `.component.css`)\n"
    section += "4. **Test file** (`.component.spec.ts`) - if testing is configured\n\n"

    section += "### Component Metadata\n\n"
    section += "```typescript\n"
    section += "@Component({\n"
    section += "  selector: 'app-component-name',  // Use kebab-case with app- prefix\n"
    section += "  templateUrl: './component-name.component.html',\n"
    section += "  styleUrls: ['./component-name.component.scss']\n"
    section += "})\n"
    section += "export class ComponentNameComponent implements OnInit {\n"
    section += "  // Component implementation\n"
    section += "}\n"
    section += "```\n\n"

    # Add common inputs/outputs if available
    comp_patterns = components.get("component_patterns", {})
    common_inputs = comp_patterns.get("common_inputs", {})
    common_outputs = comp_patterns.get("common_outputs", {})

    if common_inputs:
        section += "### Common Inputs\n\n"
        section += "These inputs are commonly used across components:\n\n"
        for input_name in list(common_inputs.keys())[:5]:
            section += f"- `@Input() {input_name}`\n"
        section += "\n"

    if common_outputs:
        section += "### Common Outputs\n\n"
        section += "These outputs are commonly used across components:\n\n"
        for output_name in list(common_outputs.keys())[:5]:
            section += f"- `@Output() {output_name}`\n"
        section += "\n"

    # Lifecycle hooks
    common_hooks = comp_patterns.get("common_lifecycle_hooks", {})
    if common_hooks:
        section += "### Common Lifecycle Hooks\n\n"
        for hook in list(common_hooks.keys())[:5]:
            section += f"- `{hook}()`\n"
        section += "\n"

    return section


def generate_styling_guidelines_section(styles: Dict[str, Any]) -> str:
    """Generate styling guidelines."""
    section = ""

    stats = styles.get("statistics", {})

    section += "### Style File Organization\n\n"
    section += f"- **Global styles**: {stats.get('global_styles', 0)} files\n"
    section += f"- **Component styles**: {stats.get('component_styles', 0)} files\n"
    section += f"- **Theme files**: {stats.get('theme_files', 0)} files\n\n"

    section += "### Variables\n\n"
    section += f"- **SCSS variables**: {stats.get('scss_variables', 0)} defined\n"
    section += (
        f"- **CSS custom properties**: {stats.get('css_variables', 0)} defined\n\n"
    )

    # Color palette
    color_palette = styles.get("color_palette", {})
    if color_palette:
        section += "### Color Palette\n\n"
        section += "Use these predefined color variables:\n\n"
        for var_name, var_value in list(color_palette.items())[:10]:
            section += f"- `{var_name}`: {var_value}\n"
        if len(color_palette) > 10:
            section += f"\n... and {len(color_palette) - 10} more color variables\n"
        section += "\n"

    # Mixins
    mixins = styles.get("mixins", [])
    if mixins:
        section += "### Available Mixins\n\n"
        unique_mixins = {m["name"]: m for m in mixins}.values()
        for mixin in list(unique_mixins)[:5]:
            section += f"- `@mixin {mixin['name']}{mixin.get('parameters', '')}`\n"
        section += "\n"

    section += "### Styling Rules\n\n"
    section += "1. **Always use SCSS variables** for colors, spacing, and typography\n"
    section += "2. **Avoid hardcoded values** - use design tokens\n"
    section += "3. **Component styles should be scoped** to the component\n"
    section += "4. **Use mixins** for reusable style patterns\n"
    section += "5. **Follow BEM naming** for CSS classes when appropriate\n\n"

    return section


def generate_primeng_rules_section(
    components: Dict[str, Any], styles: Dict[str, Any]
) -> str:
    """Generate PrimeNG customization rules."""
    section = ""

    primeng_comps = components.get("primeng_components_used", [])

    if primeng_comps:
        section += "### PrimeNG Components Used\n\n"
        section += "This design system uses the following PrimeNG components:\n\n"
        for comp in primeng_comps[:15]:
            section += f"- `{comp}`\n"
        if len(primeng_comps) > 15:
            section += f"\n... and {len(primeng_comps) - 15} more\n"
        section += "\n"

    section += "### Customization Guidelines\n\n"
    section += "1. **Override PrimeNG styles** in dedicated theme files\n"
    section += (
        "2. **Use `::ng-deep`** carefully - prefer component-level customization\n"
    )
    section += (
        "3. **Create wrapper components** for heavily customized PrimeNG components\n"
    )
    section += "4. **Document all customizations** in component comments\n"
    section += "5. **Test customizations** across all PrimeNG themes\n\n"

    # PrimeNG overrides
    primeng_overrides = styles.get("primeng_overrides", [])
    if primeng_overrides:
        section += "### Common PrimeNG Overrides\n\n"
        section += (
            f"Found {len(primeng_overrides)} files with PrimeNG style overrides.\n\n"
        )
        section += "**Example override patterns**:\n\n"
        section += "```scss\n"
        section += "// Override PrimeNG button styles\n"
        section += "::ng-deep .p-button {\n"
        section += "  border-radius: $border-radius;\n"
        section += "  padding: $button-padding;\n"
        section += "}\n"
        section += "```\n\n"

    return section


def generate_code_review_checklist(
    patterns: Dict[str, Any], components: Dict[str, Any], styles: Dict[str, Any]
) -> str:
    """Generate code review checklist."""
    section = ""

    section += "Use this checklist when reviewing code:\n\n"

    section += "### General\n\n"
    section += "- [ ] Code follows naming conventions\n"
    section += "- [ ] No console.log statements in production code\n"
    section += "- [ ] Proper error handling implemented\n"
    section += "- [ ] Code is properly formatted and linted\n\n"

    section += "### Components\n\n"
    section += "- [ ] Component selector follows naming convention (kebab-case)\n"
    section += "- [ ] Component has proper lifecycle hooks\n"
    section += "- [ ] Inputs and outputs are properly typed\n"
    section += "- [ ] Component is properly documented\n"
    section += "- [ ] Template and styles are in separate files\n"
    section += "- [ ] OnPush change detection used when appropriate\n\n"

    section += "### Styles\n\n"
    section += "- [ ] Uses SCSS variables instead of hardcoded values\n"
    section += "- [ ] No !important unless absolutely necessary\n"
    section += "- [ ] Follows established color palette\n"
    section += "- [ ] Responsive design considerations\n"
    section += "- [ ] PrimeNG overrides are properly scoped\n\n"

    section += "### Services\n\n"
    section += "- [ ] Service is properly injectable\n"
    section += "- [ ] Proper dependency injection\n"
    section += "- [ ] Error handling for HTTP calls\n"
    section += "- [ ] Observables properly managed (unsubscribe)\n\n"

    section += "### Testing\n\n"
    section += "- [ ] Unit tests exist and pass\n"
    section += "- [ ] Test coverage is adequate\n"
    section += "- [ ] Edge cases are tested\n\n"

    return section


def generate_best_practices_section(patterns: Dict[str, Any]) -> str:
    """Generate best practices section."""
    section = ""

    section += "### TypeScript\n\n"
    section += "- Use **strict type checking**\n"
    section += "- Prefer **interfaces** over type aliases for object shapes\n"
    section += "- Use **enums** for fixed sets of values\n"
    section += "- Avoid **any** type - use **unknown** if type is truly unknown\n\n"

    section += "### Angular Specific\n\n"
    section += "- Use **OnPush change detection** for performance\n"
    section += "- Implement **trackBy** functions for ngFor loops\n"
    section += "- Use **async pipe** for observables in templates\n"
    section += "- Unsubscribe from observables to prevent memory leaks\n"
    section += "- Use **lazy loading** for feature modules\n\n"

    section += "### RxJS\n\n"
    section += "- Prefer **declarative** approach over imperative\n"
    section += "- Use **operators** like map, filter, switchMap appropriately\n"
    section += "- Handle errors with **catchError** operator\n"
    section += "- Use **shareReplay** to avoid multiple HTTP calls\n\n"

    section += "### Performance\n\n"
    section += "- Minimize **bundle size** - use lazy loading\n"
    section += "- Optimize **change detection** strategy\n"
    section += "- Use **pure pipes** when possible\n"
    section += "- Avoid complex logic in templates\n"
    section += "- Use **virtual scrolling** for long lists\n\n"

    return section


def main():
    if len(sys.argv) < 5:
        print(
            "Usage: python generate_ai_rules.py <structure.json> <components.json> <styles.json> <patterns.json> [output.md]"
        )
        print(
            "Example: python generate_ai_rules.py structure.json components.json styles.json patterns.json ai_rules.md"
        )
        sys.exit(1)

    structure_file = sys.argv[1]
    components_file = sys.argv[2]
    styles_file = sys.argv[3]
    patterns_file = sys.argv[4]
    output_file = sys.argv[5] if len(sys.argv) > 5 else "ai_rules.md"

    try:
        print(f"Generating AI rules from analysis files...")
        output_path = generate_ai_rules(
            structure_file, components_file, styles_file, patterns_file, output_file
        )

        print(f"\n✅ AI rules generated successfully!")
        print(f"   Output: {output_path}")

    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
