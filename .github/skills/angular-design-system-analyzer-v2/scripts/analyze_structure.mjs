#!/usr/bin/env node

/**
 * Analyze the structure of an Angular design system repository.
 * Generates a comprehensive JSON report of the project architecture.
 */

import fs from "node:fs";
import path from "node:path";

/**
 * Analyze the structure of an Angular project.
 * @param {string} repoPath - Path to the Angular repository
 * @returns {object} Structure analysis
 */
function analyzeAngularStructure(repoPath) {
  const resolvedPath = path.resolve(repoPath);

  if (!fs.existsSync(resolvedPath)) {
    throw new Error(`Repository path does not exist: ${resolvedPath}`);
  }

  const structure = {
    root_path: resolvedPath,
    project_name: path.basename(resolvedPath),
    modules: [],
    components: [],
    services: [],
    directives: [],
    pipes: [],
    models: [],
    config_files: [],
    style_files: [],
    naming_patterns: {},
    folder_structure: {},
  };

  // Find key configuration files
  const configFiles = [
    "package.json",
    "angular.json",
    "tsconfig.json",
    "tsconfig.app.json",
    "tsconfig.spec.json",
  ];

  for (const configFile of configFiles) {
    const configPath = path.join(resolvedPath, configFile);
    if (fs.existsSync(configPath)) {
      structure.config_files.push({
        name: configFile,
        path: configFile,
      });
    }
  }

  // Analyze src directory
  const srcPath = path.join(resolvedPath, "src");
  if (fs.existsSync(srcPath)) {
    structure.folder_structure = buildFolderTree(srcPath, resolvedPath);

    // Find all TypeScript files
    for (const tsFile of rglob(srcPath, ".ts")) {
      const relativePath = path.relative(resolvedPath, tsFile);
      const fileName = path.basename(tsFile, ".ts");

      // Classify files by naming convention
      if (fileName.endsWith(".component")) {
        structure.components.push({
          name: fileName.replace(".component", ""),
          path: relativePath,
          directory: path.dirname(relativePath),
        });
      } else if (fileName.endsWith(".service")) {
        structure.services.push({
          name: fileName.replace(".service", ""),
          path: relativePath,
        });
      } else if (fileName.endsWith(".directive")) {
        structure.directives.push({
          name: fileName.replace(".directive", ""),
          path: relativePath,
        });
      } else if (fileName.endsWith(".pipe")) {
        structure.pipes.push({
          name: fileName.replace(".pipe", ""),
          path: relativePath,
        });
      } else if (fileName.endsWith(".module")) {
        structure.modules.push({
          name: fileName.replace(".module", ""),
          path: relativePath,
        });
      } else if (
        fileName.endsWith(".model") ||
        relativePath.includes("models")
      ) {
        structure.models.push({
          name: fileName,
          path: relativePath,
        });
      }
    }

    // Find all style files
    for (const ext of [".css", ".scss", ".sass", ".less"]) {
      for (const styleFile of rglob(srcPath, ext)) {
        const relativePath = path.relative(resolvedPath, styleFile);
        structure.style_files.push({
          name: path.basename(styleFile),
          path: relativePath,
          type: ext.slice(1), // Remove the dot
        });
      }
    }
  }

  // Detect naming patterns
  structure.naming_patterns = detectNamingPatterns(structure);

  // Add statistics
  structure.statistics = {
    total_modules: structure.modules.length,
    total_components: structure.components.length,
    total_services: structure.services.length,
    total_directives: structure.directives.length,
    total_pipes: structure.pipes.length,
    total_style_files: structure.style_files.length,
  };

  return structure;
}

/**
 * Recursively find files with a given extension.
 * @param {string} dir - Directory to search
 * @param {string} ext - File extension to match (e.g. '.ts')
 * @returns {string[]} Array of matching file paths
 */
function rglob(dir, ext) {
  const results = [];
  const skipDirs = new Set([
    "node_modules",
    "dist",
    "coverage",
    ".git",
    ".angular",
  ]);

  function walk(currentDir) {
    let entries;
    try {
      entries = fs.readdirSync(currentDir, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      if (entry.name.startsWith(".") && entry.name !== ".") continue;
      if (skipDirs.has(entry.name) && entry.isDirectory()) continue;

      const fullPath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        walk(fullPath);
      } else if (entry.isFile() && entry.name.endsWith(ext)) {
        results.push(fullPath);
      }
    }
  }

  walk(dir);
  return results;
}

/**
 * Build a tree structure of folders.
 * @param {string} dirPath - Current path to analyze
 * @param {string} root - Root path for relative paths
 * @param {number} maxDepth - Maximum depth to traverse
 * @param {number} currentDepth - Current depth level
 * @returns {object} Folder tree
 */
function buildFolderTree(dirPath, root, maxDepth = 5, currentDepth = 0) {
  if (currentDepth >= maxDepth) {
    return {};
  }

  const tree = {
    name: path.basename(dirPath),
    path: path.relative(root, dirPath),
    children: [],
  };

  try {
    const items = fs.readdirSync(dirPath, { withFileTypes: true });
    // Sort: directories first, then alphabetically
    items.sort((a, b) => {
      if (a.isDirectory() && !b.isDirectory()) return -1;
      if (!a.isDirectory() && b.isDirectory()) return 1;
      return a.name.localeCompare(b.name);
    });

    for (const item of items) {
      // Skip node_modules, dist, and hidden folders
      if (item.name.startsWith(".")) continue;
      if (["node_modules", "dist", "coverage"].includes(item.name)) continue;

      if (item.isDirectory()) {
        tree.children.push(
          buildFolderTree(
            path.join(dirPath, item.name),
            root,
            maxDepth,
            currentDepth + 1,
          ),
        );
      }
    }
  } catch {
    // PermissionError or similar
  }

  return tree;
}

/**
 * Detect naming patterns used in the project.
 * @param {object} structure - Structure dictionary
 * @returns {object} Detected patterns
 */
function detectNamingPatterns(structure) {
  const patterns = {
    component_naming: "kebab-case with .component suffix",
    service_naming: "kebab-case with .service suffix",
    module_naming: "kebab-case with .module suffix",
    uses_standalone_components: false,
    folder_organization: "feature-based",
  };

  // Detect if components are in their own folders
  if (structure.components.length > 0) {
    const componentDirs = structure.components.map((c) => c.directory);
    // Check if most components have their own folder
    const uniqueDirs = new Set(componentDirs).size;
    if (uniqueDirs > structure.components.length * 0.7) {
      patterns.folder_organization = "component-per-folder";
    }
  }

  return patterns;
}

// --- Main ---
function main() {
  const args = process.argv.slice(2);

  if (args.length < 1) {
    console.log("Usage: node analyze_structure.mjs <repo_path> [output_file]");
    console.log(
      "Example: node analyze_structure.mjs /path/to/angular-project structure.json",
    );
    process.exit(1);
  }

  const repoPath = args[0];
  const outputFile = args[1] || "structure_analysis.json";

  try {
    console.log(`Analyzing Angular project at: ${repoPath}`);
    const structure = analyzeAngularStructure(repoPath);

    // Write to output file
    fs.writeFileSync(outputFile, JSON.stringify(structure, null, 2), "utf-8");

    console.log(`\n✅ Analysis complete! Results saved to: ${outputFile}`);
    console.log("\nStatistics:");
    for (const [key, value] of Object.entries(structure.statistics)) {
      console.log(`  ${key}: ${value}`);
    }
  } catch (e) {
    console.error(`❌ Error: ${e.message}`);
    process.exit(1);
  }
}

main();
