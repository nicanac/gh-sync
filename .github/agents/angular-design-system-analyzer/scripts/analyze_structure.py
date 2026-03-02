#!/usr/bin/env python3
"""
Analyze the structure of an Angular design system repository.
Generates a comprehensive JSON report of the project architecture.
"""

import os
import json
import sys
from pathlib import Path
from typing import Dict, List, Any


def analyze_angular_structure(repo_path: str) -> Dict[str, Any]:
    """
    Analyze the structure of an Angular project.

    Args:
        repo_path: Path to the Angular repository

    Returns:
        Dictionary containing structure analysis
    """
    repo_path = Path(repo_path).resolve()

    if not repo_path.exists():
        raise ValueError(f"Repository path does not exist: {repo_path}")

    structure = {
        "root_path": str(repo_path),
        "project_name": repo_path.name,
        "modules": [],
        "components": [],
        "services": [],
        "directives": [],
        "pipes": [],
        "models": [],
        "config_files": [],
        "style_files": [],
        "naming_patterns": {},
        "folder_structure": {},
    }

    # Find key configuration files
    config_files = [
        "package.json",
        "angular.json",
        "tsconfig.json",
        "tsconfig.app.json",
        "tsconfig.spec.json",
    ]

    for config_file in config_files:
        config_path = repo_path / config_file
        if config_path.exists():
            structure["config_files"].append(
                {"name": config_file, "path": str(config_path.relative_to(repo_path))}
            )

    # Analyze src directory
    src_path = repo_path / "src"
    if src_path.exists():
        structure["folder_structure"] = build_folder_tree(src_path, repo_path)

        # Find all TypeScript files
        for ts_file in src_path.rglob("*.ts"):
            relative_path = ts_file.relative_to(repo_path)
            file_name = ts_file.stem

            # Classify files by naming convention
            if file_name.endswith(".component"):
                structure["components"].append(
                    {
                        "name": file_name.replace(".component", ""),
                        "path": str(relative_path),
                        "directory": str(relative_path.parent),
                    }
                )
            elif file_name.endswith(".service"):
                structure["services"].append(
                    {
                        "name": file_name.replace(".service", ""),
                        "path": str(relative_path),
                    }
                )
            elif file_name.endswith(".directive"):
                structure["directives"].append(
                    {
                        "name": file_name.replace(".directive", ""),
                        "path": str(relative_path),
                    }
                )
            elif file_name.endswith(".pipe"):
                structure["pipes"].append(
                    {"name": file_name.replace(".pipe", ""), "path": str(relative_path)}
                )
            elif file_name.endswith(".module"):
                structure["modules"].append(
                    {
                        "name": file_name.replace(".module", ""),
                        "path": str(relative_path),
                    }
                )
            elif file_name.endswith(".model") or "models" in str(relative_path):
                structure["models"].append(
                    {"name": file_name, "path": str(relative_path)}
                )

        # Find all style files
        for style_ext in ["*.css", "*.scss", "*.sass", "*.less"]:
            for style_file in src_path.rglob(style_ext):
                relative_path = style_file.relative_to(repo_path)
                structure["style_files"].append(
                    {
                        "name": style_file.name,
                        "path": str(relative_path),
                        "type": style_file.suffix[1:],  # Remove the dot
                    }
                )

    # Detect naming patterns
    structure["naming_patterns"] = detect_naming_patterns(structure)

    # Add statistics
    structure["statistics"] = {
        "total_modules": len(structure["modules"]),
        "total_components": len(structure["components"]),
        "total_services": len(structure["services"]),
        "total_directives": len(structure["directives"]),
        "total_pipes": len(structure["pipes"]),
        "total_style_files": len(structure["style_files"]),
    }

    return structure


def build_folder_tree(
    path: Path, root: Path, max_depth: int = 5, current_depth: int = 0
) -> Dict[str, Any]:
    """
    Build a tree structure of folders.

    Args:
        path: Current path to analyze
        root: Root path for relative paths
        max_depth: Maximum depth to traverse
        current_depth: Current depth level

    Returns:
        Dictionary representing folder tree
    """
    if current_depth >= max_depth:
        return {}

    tree = {"name": path.name, "path": str(path.relative_to(root)), "children": []}

    try:
        items = sorted(path.iterdir(), key=lambda x: (not x.is_dir(), x.name))
        for item in items:
            # Skip node_modules, dist, and hidden folders
            if item.name.startswith(".") or item.name in [
                "node_modules",
                "dist",
                "coverage",
            ]:
                continue

            if item.is_dir():
                tree["children"].append(
                    build_folder_tree(item, root, max_depth, current_depth + 1)
                )
    except PermissionError:
        pass

    return tree


def detect_naming_patterns(structure: Dict[str, Any]) -> Dict[str, Any]:
    """
    Detect naming patterns used in the project.

    Args:
        structure: Structure dictionary

    Returns:
        Dictionary of detected patterns
    """
    patterns = {
        "component_naming": "kebab-case with .component suffix",
        "service_naming": "kebab-case with .service suffix",
        "module_naming": "kebab-case with .module suffix",
        "uses_standalone_components": False,
        "folder_organization": "feature-based",
    }

    # Detect if components are in their own folders
    if structure["components"]:
        component_dirs = [c["directory"] for c in structure["components"]]
        # Check if most components have their own folder
        unique_dirs = len(set(component_dirs))
        if unique_dirs > len(structure["components"]) * 0.7:
            patterns["folder_organization"] = "component-per-folder"

    return patterns


def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_structure.py <repo_path> [output_file]")
        print(
            "Example: python analyze_structure.py /path/to/angular-project structure.json"
        )
        sys.exit(1)

    repo_path = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else "structure_analysis.json"

    try:
        print(f"Analyzing Angular project at: {repo_path}")
        structure = analyze_angular_structure(repo_path)

        # Write to output file
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(structure, f, indent=2, ensure_ascii=False)

        print(f"\n✅ Analysis complete! Results saved to: {output_file}")
        print(f"\nStatistics:")
        for key, value in structure["statistics"].items():
            print(f"  {key}: {value}")

    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
