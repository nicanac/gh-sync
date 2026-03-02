#!/usr/bin/env python3
"""
Detect code patterns and conventions in an Angular design system.
Analyzes coding standards, architectural patterns, and best practices.
"""

import os
import json
import sys
import re
from pathlib import Path
from typing import Dict, List, Any
from collections import Counter


def detect_patterns(repo_path: str) -> Dict[str, Any]:
    """
    Detect patterns and conventions in the Angular project.

    Args:
        repo_path: Path to the Angular repository

    Returns:
        Dictionary containing pattern analysis
    """
    repo_path = Path(repo_path).resolve()

    if not repo_path.exists():
        raise ValueError(f"Repository path does not exist: {repo_path}")

    analysis = {
        "naming_conventions": {},
        "folder_structure_patterns": {},
        "import_patterns": {},
        "architectural_patterns": {},
        "code_standards": {},
        "common_decorators": {},
        "rxjs_patterns": [],
    }

    src_path = repo_path / "src"
    if not src_path.exists():
        raise ValueError(f"src directory not found in {repo_path}")

    # Collect all TypeScript files
    ts_files = list(src_path.rglob("*.ts"))

    # Analyze naming conventions
    analysis["naming_conventions"] = analyze_naming_conventions(ts_files, repo_path)

    # Analyze folder structure
    analysis["folder_structure_patterns"] = analyze_folder_structure(
        src_path, repo_path
    )

    # Analyze imports
    analysis["import_patterns"] = analyze_import_patterns(ts_files)

    # Detect architectural patterns
    analysis["architectural_patterns"] = detect_architectural_patterns(
        ts_files, repo_path
    )

    # Analyze code standards
    analysis["code_standards"] = analyze_code_standards(ts_files)

    # Detect common decorators
    analysis["common_decorators"] = detect_common_decorators(ts_files)

    # Detect RxJS patterns
    analysis["rxjs_patterns"] = detect_rxjs_patterns(ts_files)

    return analysis


def analyze_naming_conventions(ts_files: List[Path], repo_root: Path) -> Dict[str, Any]:
    """Analyze naming conventions used in the project."""
    conventions = {
        "file_naming": {},
        "class_naming": {},
        "variable_naming": {},
        "examples": {},
    }

    file_patterns = Counter()
    class_patterns = Counter()

    for ts_file in ts_files[:100]:  # Sample first 100 files
        # Analyze file naming
        file_name = ts_file.stem
        if "." in file_name:
            parts = file_name.split(".")
            if len(parts) >= 2:
                suffix = parts[-1]
                file_patterns[suffix] += 1

        # Analyze class naming
        try:
            content = ts_file.read_text(encoding="utf-8")
            class_matches = re.findall(r"export\s+class\s+(\w+)", content)
            for class_name in class_matches:
                # Detect naming pattern (PascalCase, camelCase, etc.)
                if class_name[0].isupper():
                    class_patterns["PascalCase"] += 1
                else:
                    class_patterns["camelCase"] += 1
        except:
            continue

    conventions["file_naming"] = {
        "pattern": "kebab-case with type suffix",
        "common_suffixes": dict(file_patterns.most_common(10)),
    }

    conventions["class_naming"] = {
        "pattern": (
            "PascalCase"
            if class_patterns.get("PascalCase", 0) > class_patterns.get("camelCase", 0)
            else "camelCase"
        ),
        "distribution": dict(class_patterns),
    }

    conventions["variable_naming"] = {
        "pattern": "camelCase (Angular standard)",
        "constants": "UPPER_SNAKE_CASE",
        "private_members": "prefixed with underscore or camelCase",
    }

    return conventions


def analyze_folder_structure(src_path: Path, repo_root: Path) -> Dict[str, Any]:
    """Analyze folder organization patterns."""
    structure = {
        "organization_type": "unknown",
        "common_folders": [],
        "depth_analysis": {},
        "module_organization": "unknown",
    }

    # Find common top-level folders in src
    if src_path.exists():
        folders = [
            d.name
            for d in src_path.iterdir()
            if d.is_dir() and not d.name.startswith(".")
        ]
        structure["common_folders"] = folders

        # Detect organization type
        if "app" in folders:
            app_path = src_path / "app"
            app_folders = [d.name for d in app_path.iterdir() if d.is_dir()]

            # Feature-based if has multiple feature folders
            feature_indicators = ["features", "modules", "pages", "views"]
            if any(indicator in app_folders for indicator in feature_indicators):
                structure["organization_type"] = "feature-based"
            # Shared/Core pattern
            elif "shared" in app_folders or "core" in app_folders:
                structure["organization_type"] = "shared-core pattern"
            else:
                structure["organization_type"] = "component-based"

    return structure


def analyze_import_patterns(ts_files: List[Path]) -> Dict[str, Any]:
    """Analyze import statement patterns."""
    patterns = {
        "relative_imports": 0,
        "absolute_imports": 0,
        "barrel_imports": 0,
        "most_imported_modules": Counter(),
        "import_aliases": {},
    }

    for ts_file in ts_files[:100]:  # Sample
        try:
            content = ts_file.read_text(encoding="utf-8")

            # Find all imports
            import_matches = re.findall(
                r'import\s+.*\s+from\s+[\'"]([^\'"]+)[\'"]', content
            )

            for import_path in import_matches:
                if import_path.startswith("."):
                    patterns["relative_imports"] += 1
                elif import_path.startswith("@"):
                    patterns["absolute_imports"] += 1
                    # Extract module name
                    module = import_path.split("/")[0]
                    patterns["most_imported_modules"][module] += 1
                else:
                    patterns["most_imported_modules"][import_path.split("/")[0]] += 1

                # Detect barrel imports (index files)
                if import_path.endswith("/index") or import_path.endswith(""):
                    patterns["barrel_imports"] += 1
        except:
            continue

    patterns["most_imported_modules"] = dict(
        patterns["most_imported_modules"].most_common(10)
    )

    return patterns


def detect_architectural_patterns(
    ts_files: List[Path], repo_root: Path
) -> Dict[str, Any]:
    """Detect architectural patterns used."""
    patterns = {
        "uses_services": False,
        "uses_state_management": False,
        "state_management_library": None,
        "uses_lazy_loading": False,
        "uses_standalone_components": False,
        "uses_dependency_injection": False,
        "uses_reactive_forms": False,
        "uses_template_driven_forms": False,
    }

    all_content = ""
    for ts_file in ts_files[:50]:  # Sample
        try:
            all_content += ts_file.read_text(encoding="utf-8")
        except:
            continue

    # Detect patterns
    if ".service" in all_content or "Injectable" in all_content:
        patterns["uses_services"] = True
        patterns["uses_dependency_injection"] = True

    if "ngrx" in all_content.lower() or "@ngrx" in all_content:
        patterns["uses_state_management"] = True
        patterns["state_management_library"] = "NgRx"
    elif "akita" in all_content.lower():
        patterns["uses_state_management"] = True
        patterns["state_management_library"] = "Akita"

    if "loadChildren" in all_content:
        patterns["uses_lazy_loading"] = True

    if "standalone: true" in all_content:
        patterns["uses_standalone_components"] = True

    if "FormGroup" in all_content or "FormControl" in all_content:
        patterns["uses_reactive_forms"] = True

    if "ngModel" in all_content:
        patterns["uses_template_driven_forms"] = True

    return patterns


def analyze_code_standards(ts_files: List[Path]) -> Dict[str, Any]:
    """Analyze code quality and standards."""
    standards = {
        "uses_typescript_strict": False,
        "uses_linting": False,
        "uses_prettier": False,
        "average_file_length": 0,
        "uses_jsdoc": False,
        "uses_interfaces": False,
        "uses_enums": False,
        "uses_type_aliases": False,
    }

    total_lines = 0
    file_count = 0

    for ts_file in ts_files[:50]:  # Sample
        try:
            content = ts_file.read_text(encoding="utf-8")
            lines = content.split("\n")
            total_lines += len(lines)
            file_count += 1

            # Detect standards
            if "interface " in content:
                standards["uses_interfaces"] = True
            if "enum " in content:
                standards["uses_enums"] = True
            if "type " in content and "=" in content:
                standards["uses_type_aliases"] = True
            if "/**" in content or "/*" in content:
                standards["uses_jsdoc"] = True
        except:
            continue

    if file_count > 0:
        standards["average_file_length"] = total_lines // file_count

    return standards


def detect_common_decorators(ts_files: List[Path]) -> Dict[str, int]:
    """Detect commonly used decorators."""
    decorators = Counter()

    decorator_pattern = r"@(\w+)\("

    for ts_file in ts_files[:100]:  # Sample
        try:
            content = ts_file.read_text(encoding="utf-8")
            matches = re.findall(decorator_pattern, content)
            decorators.update(matches)
        except:
            continue

    return dict(decorators.most_common(15))


def detect_rxjs_patterns(ts_files: List[Path]) -> List[Dict[str, Any]]:
    """Detect RxJS usage patterns."""
    patterns = []

    rxjs_operators = Counter()

    for ts_file in ts_files[:50]:  # Sample
        try:
            content = ts_file.read_text(encoding="utf-8")

            # Detect RxJS imports
            rxjs_import_match = re.search(
                r'import\s+{([^}]+)}\s+from\s+[\'"]rxjs', content
            )
            if rxjs_import_match:
                operators = [op.strip() for op in rxjs_import_match.group(1).split(",")]
                rxjs_operators.update(operators)
        except:
            continue

    if rxjs_operators:
        patterns.append(
            {
                "pattern": "RxJS Observables",
                "common_operators": dict(rxjs_operators.most_common(10)),
            }
        )

    return patterns


def main():
    if len(sys.argv) < 2:
        print("Usage: python detect_patterns.py <repo_path> [output_file]")
        print(
            "Example: python detect_patterns.py /path/to/angular-project patterns.json"
        )
        sys.exit(1)

    repo_path = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else "patterns_analysis.json"

    try:
        print(f"Detecting patterns in: {repo_path}")
        analysis = detect_patterns(repo_path)

        # Write to output file
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(analysis, f, indent=2, ensure_ascii=False)

        print(f"\n✅ Analysis complete! Results saved to: {output_file}")
        print(f"\nKey Findings:")
        print(
            f"  Organization: {analysis['folder_structure_patterns'].get('organization_type', 'unknown')}"
        )
        print(
            f"  Uses Services: {analysis['architectural_patterns'].get('uses_services', False)}"
        )
        print(
            f"  State Management: {analysis['architectural_patterns'].get('state_management_library', 'None')}"
        )

    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
