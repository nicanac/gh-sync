#!/usr/bin/env python3
"""
Analyze CSS/SCSS styles in an Angular design system.
Extracts variables, theming system, and PrimeNG customizations.
"""

import os
import json
import sys
import re
from pathlib import Path
from typing import Dict, List, Any, Set


def analyze_styles(repo_path: str) -> Dict[str, Any]:
    """
    Analyze all style files in the repository.

    Args:
        repo_path: Path to the Angular repository

    Returns:
        Dictionary containing style analysis
    """
    repo_path = Path(repo_path).resolve()

    if not repo_path.exists():
        raise ValueError(f"Repository path does not exist: {repo_path}")

    analysis = {
        "global_styles": [],
        "component_styles": [],
        "css_variables": {},
        "scss_variables": {},
        "color_palette": {},
        "primeng_overrides": [],
        "theme_files": [],
        "mixins": [],
        "functions": [],
    }

    src_path = repo_path / "src"
    if not src_path.exists():
        raise ValueError(f"src directory not found in {repo_path}")

    # Analyze all style files
    for ext in ["*.css", "*.scss", "*.sass", "*.less"]:
        for style_file in src_path.rglob(ext):
            relative_path = style_file.relative_to(repo_path)

            # Classify as global or component style
            is_component_style = ".component." in style_file.name

            style_info = {
                "name": style_file.name,
                "path": str(relative_path),
                "type": style_file.suffix[1:],
                "is_component_style": is_component_style,
            }

            # Read and analyze content
            try:
                content = style_file.read_text(encoding="utf-8")

                # Extract variables
                if style_file.suffix in [".scss", ".sass"]:
                    scss_vars = extract_scss_variables(content)
                    if scss_vars:
                        style_info["variables"] = scss_vars
                        analysis["scss_variables"].update(scss_vars)

                    # Extract mixins and functions
                    mixins = extract_scss_mixins(content)
                    if mixins:
                        style_info["mixins"] = mixins
                        analysis["mixins"].extend(mixins)

                    functions = extract_scss_functions(content)
                    if functions:
                        style_info["functions"] = functions
                        analysis["functions"].extend(functions)

                # Extract CSS custom properties (variables)
                css_vars = extract_css_variables(content)
                if css_vars:
                    style_info["css_variables"] = css_vars
                    analysis["css_variables"].update(css_vars)

                # Detect PrimeNG overrides
                primeng_overrides = detect_primeng_overrides(content)
                if primeng_overrides:
                    style_info["primeng_overrides"] = primeng_overrides
                    analysis["primeng_overrides"].append(
                        {"file": str(relative_path), "overrides": primeng_overrides}
                    )

                # Detect theme files
                if is_theme_file(style_file.name, content):
                    analysis["theme_files"].append(style_info)

            except Exception as e:
                print(f"Warning: Could not read {style_file}: {e}")
                continue

            if is_component_style:
                analysis["component_styles"].append(style_info)
            else:
                analysis["global_styles"].append(style_info)

    # Extract color palette from variables
    analysis["color_palette"] = extract_color_palette(
        analysis["scss_variables"], analysis["css_variables"]
    )

    # Add statistics
    analysis["statistics"] = {
        "total_style_files": len(analysis["global_styles"])
        + len(analysis["component_styles"]),
        "global_styles": len(analysis["global_styles"]),
        "component_styles": len(analysis["component_styles"]),
        "scss_variables": len(analysis["scss_variables"]),
        "css_variables": len(analysis["css_variables"]),
        "colors_in_palette": len(analysis["color_palette"]),
        "primeng_override_files": len(analysis["primeng_overrides"]),
        "theme_files": len(analysis["theme_files"]),
        "mixins": len(analysis["mixins"]),
        "functions": len(analysis["functions"]),
    }

    return analysis


def extract_scss_variables(content: str) -> Dict[str, str]:
    """Extract SCSS variables ($variable: value;)."""
    variables = {}
    pattern = r"\$([a-zA-Z0-9_-]+)\s*:\s*([^;]+);"
    matches = re.findall(pattern, content)

    for var_name, var_value in matches:
        variables[var_name] = var_value.strip()

    return variables


def extract_css_variables(content: str) -> Dict[str, str]:
    """Extract CSS custom properties (--variable: value;)."""
    variables = {}
    pattern = r"--([a-zA-Z0-9_-]+)\s*:\s*([^;]+);"
    matches = re.findall(pattern, content)

    for var_name, var_value in matches:
        variables[var_name] = var_value.strip()

    return variables


def extract_scss_mixins(content: str) -> List[Dict[str, str]]:
    """Extract SCSS mixins."""
    mixins = []
    pattern = r"@mixin\s+([a-zA-Z0-9_-]+)\s*(\([^)]*\))?\s*{"
    matches = re.findall(pattern, content)

    for mixin_name, params in matches:
        mixins.append(
            {"name": mixin_name, "parameters": params.strip() if params else ""}
        )

    return mixins


def extract_scss_functions(content: str) -> List[Dict[str, str]]:
    """Extract SCSS functions."""
    functions = []
    pattern = r"@function\s+([a-zA-Z0-9_-]+)\s*(\([^)]*\))\s*{"
    matches = re.findall(pattern, content)

    for func_name, params in matches:
        functions.append({"name": func_name, "parameters": params.strip()})

    return functions


def detect_primeng_overrides(content: str) -> List[str]:
    """
    Detect PrimeNG component style overrides.

    Args:
        content: Style file content

    Returns:
        List of PrimeNG selectors being overridden
    """
    overrides = []

    # Common PrimeNG class patterns
    primeng_patterns = [
        r"\.p-[a-z-]+",  # PrimeNG classes start with .p-
        r"::ng-deep\s+\.p-[a-z-]+",  # Deep selectors
        r":host\s+::ng-deep\s+\.p-[a-z-]+",
    ]

    for pattern in primeng_patterns:
        matches = re.findall(pattern, content)
        overrides.extend(matches)

    # Remove duplicates and return
    return list(set(overrides))


def is_theme_file(filename: str, content: str) -> bool:
    """
    Determine if a file is a theme file.

    Args:
        filename: Name of the file
        content: File content

    Returns:
        True if file appears to be a theme file
    """
    # Check filename
    theme_keywords = ["theme", "variables", "colors", "palette"]
    if any(keyword in filename.lower() for keyword in theme_keywords):
        return True

    # Check content for theme-related patterns
    # Many color variables or CSS custom properties
    color_pattern = r"(#[0-9a-fA-F]{3,6}|rgb|hsl|var\(--)"
    color_matches = re.findall(color_pattern, content)

    # If file has many color definitions, likely a theme file
    return len(color_matches) > 10


def extract_color_palette(
    scss_vars: Dict[str, str], css_vars: Dict[str, str]
) -> Dict[str, str]:
    """
    Extract color palette from variables.

    Args:
        scss_vars: SCSS variables
        css_vars: CSS custom properties

    Returns:
        Dictionary of color variables
    """
    color_palette = {}

    # Color patterns
    color_pattern = r"^(#[0-9a-fA-F]{3,6}|rgb|rgba|hsl|hsla)"

    # Check SCSS variables
    for var_name, var_value in scss_vars.items():
        if re.match(color_pattern, var_value.strip()) or "color" in var_name.lower():
            color_palette[f"${var_name}"] = var_value

    # Check CSS variables
    for var_name, var_value in css_vars.items():
        if re.match(color_pattern, var_value.strip()) or "color" in var_name.lower():
            color_palette[f"--{var_name}"] = var_value

    return color_palette


def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_styles.py <repo_path> [output_file]")
        print("Example: python analyze_styles.py /path/to/angular-project styles.json")
        sys.exit(1)

    repo_path = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else "styles_analysis.json"

    try:
        print(f"Analyzing styles in: {repo_path}")
        analysis = analyze_styles(repo_path)

        # Write to output file
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(analysis, f, indent=2, ensure_ascii=False)

        print(f"\n✅ Analysis complete! Results saved to: {output_file}")
        print(f"\nStatistics:")
        for key, value in analysis["statistics"].items():
            print(f"  {key}: {value}")

        if analysis["color_palette"]:
            print(f"\nSample colors from palette:")
            for i, (var_name, var_value) in enumerate(
                list(analysis["color_palette"].items())[:5]
            ):
                print(f"  {var_name}: {var_value}")
            if len(analysis["color_palette"]) > 5:
                print(f"  ... and {len(analysis['color_palette']) - 5} more")

    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
