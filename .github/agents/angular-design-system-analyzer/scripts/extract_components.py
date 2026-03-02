#!/usr/bin/env python3
"""
Extract and analyze Angular components from a design system.
Detects component metadata, PrimeNG usage, and customizations.
"""

import os
import json
import sys
import re
from pathlib import Path
from typing import Dict, List, Any, Optional


def extract_components(repo_path: str) -> Dict[str, Any]:
    """
    Extract all components and their metadata.

    Args:
        repo_path: Path to the Angular repository

    Returns:
        Dictionary containing component analysis
    """
    repo_path = Path(repo_path).resolve()

    if not repo_path.exists():
        raise ValueError(f"Repository path does not exist: {repo_path}")

    analysis = {
        "components": [],
        "primeng_components_used": set(),
        "custom_components": [],
        "component_patterns": {},
        "primeng_customizations": [],
    }

    src_path = repo_path / "src"
    if not src_path.exists():
        raise ValueError(f"src directory not found in {repo_path}")

    # Find all component TypeScript files
    for ts_file in src_path.rglob("*.component.ts"):
        component_info = analyze_component_file(ts_file, repo_path)
        if component_info:
            analysis["components"].append(component_info)

            # Track PrimeNG components
            for primeng_comp in component_info.get("primeng_components", []):
                analysis["primeng_components_used"].add(primeng_comp)

            # Detect customizations
            if component_info.get("is_primeng_customization"):
                analysis["primeng_customizations"].append(component_info)
            elif not component_info.get("uses_primeng"):
                analysis["custom_components"].append(component_info)

    # Convert set to list for JSON serialization
    analysis["primeng_components_used"] = sorted(
        list(analysis["primeng_components_used"])
    )

    # Detect common patterns
    analysis["component_patterns"] = detect_component_patterns(analysis["components"])

    # Add statistics
    analysis["statistics"] = {
        "total_components": len(analysis["components"]),
        "primeng_components_used": len(analysis["primeng_components_used"]),
        "custom_components": len(analysis["custom_components"]),
        "primeng_customizations": len(analysis["primeng_customizations"]),
    }

    return analysis


def analyze_component_file(
    file_path: Path, repo_root: Path
) -> Optional[Dict[str, Any]]:
    """
    Analyze a single component TypeScript file.

    Args:
        file_path: Path to the component file
        repo_root: Root path of the repository

    Returns:
        Dictionary with component information
    """
    try:
        content = file_path.read_text(encoding="utf-8")
    except Exception as e:
        print(f"Warning: Could not read {file_path}: {e}")
        return None

    component_name = file_path.stem.replace(".component", "")
    relative_path = file_path.relative_to(repo_root)

    component_info = {
        "name": component_name,
        "path": str(relative_path),
        "directory": str(relative_path.parent),
        "selector": extract_selector(content),
        "inputs": extract_inputs(content),
        "outputs": extract_outputs(content),
        "imports": extract_imports(content),
        "primeng_components": extract_primeng_components(content),
        "uses_primeng": False,
        "is_primeng_customization": False,
        "injected_services": extract_injected_services(content),
        "lifecycle_hooks": extract_lifecycle_hooks(content),
        "has_template": False,
        "has_styles": False,
    }

    # Check for associated template and style files
    template_file = file_path.parent / f"{component_name}.component.html"
    component_info["has_template"] = template_file.exists()

    for ext in [".scss", ".css", ".sass", ".less"]:
        style_file = file_path.parent / f"{component_name}.component{ext}"
        if style_file.exists():
            component_info["has_styles"] = True
            component_info["style_type"] = ext[1:]
            break

    # Detect PrimeNG usage
    if component_info["primeng_components"]:
        component_info["uses_primeng"] = True

        # Check if this is a customization wrapper
        if is_primeng_wrapper(content, component_name):
            component_info["is_primeng_customization"] = True

    return component_info


def extract_selector(content: str) -> Optional[str]:
    """Extract component selector from @Component decorator."""
    match = re.search(r"selector:\s*['\"]([^'\"]+)['\"]", content)
    return match.group(1) if match else None


def extract_inputs(content: str) -> List[str]:
    """Extract @Input() properties."""
    # Match @Input() or @Input('alias')
    pattern = r"@Input\(['\"]?(\w+)?['\"]?\)\s+(\w+)"
    matches = re.findall(pattern, content)
    return [alias or name for alias, name in matches]


def extract_outputs(content: str) -> List[str]:
    """Extract @Output() properties."""
    pattern = r"@Output\(['\"]?(\w+)?['\"]?\)\s+(\w+)"
    matches = re.findall(pattern, content)
    return [alias or name for alias, name in matches]


def extract_imports(content: str) -> List[str]:
    """Extract import statements."""
    imports = []
    pattern = r"import\s+{([^}]+)}\s+from\s+['\"]([^'\"]+)['\"]"
    matches = re.findall(pattern, content)

    for symbols, module in matches:
        imports.append(
            {"module": module, "symbols": [s.strip() for s in symbols.split(",")]}
        )

    return imports


def extract_primeng_components(content: str) -> List[str]:
    """Extract PrimeNG components used in imports."""
    primeng_components = []
    pattern = r"import\s+{([^}]+)}\s+from\s+['\"]primeng/([^'\"]+)['\"]"
    matches = re.findall(pattern, content)

    for symbols, module in matches:
        # Extract component names from symbols
        components = [s.strip() for s in symbols.split(",")]
        primeng_components.extend(components)

    return primeng_components


def extract_injected_services(content: str) -> List[str]:
    """Extract services injected in constructor."""
    services = []

    # Find constructor
    constructor_match = re.search(r"constructor\s*\(([^)]*)\)", content, re.DOTALL)
    if constructor_match:
        params = constructor_match.group(1)
        # Extract parameter types
        param_pattern = r"(?:private|public|protected)?\s*(\w+)\s*:\s*(\w+)"
        matches = re.findall(param_pattern, params)
        services = [service_type for _, service_type in matches]

    return services


def extract_lifecycle_hooks(content: str) -> List[str]:
    """Extract Angular lifecycle hooks implemented."""
    hooks = [
        "ngOnInit",
        "ngOnChanges",
        "ngDoCheck",
        "ngAfterContentInit",
        "ngAfterContentChecked",
        "ngAfterViewInit",
        "ngAfterViewChecked",
        "ngOnDestroy",
    ]

    implemented_hooks = []
    for hook in hooks:
        if re.search(rf"\b{hook}\s*\(", content):
            implemented_hooks.append(hook)

    return implemented_hooks


def is_primeng_wrapper(content: str, component_name: str) -> bool:
    """
    Detect if component is a wrapper/customization of a PrimeNG component.

    Args:
        content: Component file content
        component_name: Name of the component

    Returns:
        True if this appears to be a PrimeNG wrapper
    """
    # Check if component extends a PrimeNG component
    if re.search(r"extends\s+\w+", content):
        return True

    # Check if template uses a single PrimeNG component with property binding
    # This is a heuristic - may need refinement
    primeng_pattern = r"<p-\w+"
    matches = re.findall(primeng_pattern, content)

    # If there's exactly one PrimeNG component reference, likely a wrapper
    return len(set(matches)) == 1


def detect_component_patterns(components: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Detect common patterns across components.

    Args:
        components: List of component information

    Returns:
        Dictionary of detected patterns
    """
    patterns = {
        "common_inputs": {},
        "common_outputs": {},
        "common_services": {},
        "common_lifecycle_hooks": {},
        "selector_pattern": "kebab-case",
    }

    # Count occurrences
    for component in components:
        for input_name in component.get("inputs", []):
            patterns["common_inputs"][input_name] = (
                patterns["common_inputs"].get(input_name, 0) + 1
            )

        for output_name in component.get("outputs", []):
            patterns["common_outputs"][output_name] = (
                patterns["common_outputs"].get(output_name, 0) + 1
            )

        for service in component.get("injected_services", []):
            patterns["common_services"][service] = (
                patterns["common_services"].get(service, 0) + 1
            )

        for hook in component.get("lifecycle_hooks", []):
            patterns["common_lifecycle_hooks"][hook] = (
                patterns["common_lifecycle_hooks"].get(hook, 0) + 1
            )

    # Keep only common ones (used in >20% of components)
    threshold = len(components) * 0.2
    patterns["common_inputs"] = {
        k: v for k, v in patterns["common_inputs"].items() if v > threshold
    }
    patterns["common_outputs"] = {
        k: v for k, v in patterns["common_outputs"].items() if v > threshold
    }
    patterns["common_services"] = {
        k: v for k, v in patterns["common_services"].items() if v > threshold
    }

    return patterns


def main():
    if len(sys.argv) < 2:
        print("Usage: python extract_components.py <repo_path> [output_file]")
        print(
            "Example: python extract_components.py /path/to/angular-project components.json"
        )
        sys.exit(1)

    repo_path = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else "components_analysis.json"

    try:
        print(f"Extracting components from: {repo_path}")
        analysis = extract_components(repo_path)

        # Write to output file
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(analysis, f, indent=2, ensure_ascii=False)

        print(f"\n✅ Analysis complete! Results saved to: {output_file}")
        print(f"\nStatistics:")
        for key, value in analysis["statistics"].items():
            print(f"  {key}: {value}")

        print(
            f"\nPrimeNG components used: {', '.join(analysis['primeng_components_used'][:10])}"
        )
        if len(analysis["primeng_components_used"]) > 10:
            print(f"  ... and {len(analysis['primeng_components_used']) - 10} more")

    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
