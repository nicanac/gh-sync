#!/usr/bin/env node

/**
 * Analyze CSS/SCSS styles in an Angular design system.
 * Extracts variables, theming system, and PrimeNG customizations.
 */

import fs from 'node:fs';
import path from 'node:path';

/**
 * Recursively find files matching given extensions.
 * @param {string} dir - Directory to search
 * @param {string[]} exts - File extensions to match (e.g. ['.css', '.scss'])
 * @returns {string[]} Array of matching file paths
 */
function rglobMulti(dir, exts) {
  const results = [];
  const skipDirs = new Set(['node_modules', 'dist', 'coverage', '.git', '.angular']);

  function walk(currentDir) {
    let entries;
    try {
      entries = fs.readdirSync(currentDir, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      if (entry.name.startsWith('.') && entry.name !== '.') continue;
      if (skipDirs.has(entry.name) && entry.isDirectory()) continue;

      const fullPath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        walk(fullPath);
      } else if (entry.isFile() && exts.some((ext) => entry.name.endsWith(ext))) {
        results.push(fullPath);
      }
    }
  }

  walk(dir);
  return results;
}

/**
 * Analyze all style files in the repository.
 * @param {string} repoPath - Path to the Angular repository
 * @returns {object} Style analysis
 */
function analyzeStyles(repoPath) {
  const resolvedPath = path.resolve(repoPath);

  if (!fs.existsSync(resolvedPath)) {
    throw new Error(`Repository path does not exist: ${resolvedPath}`);
  }

  const analysis = {
    global_styles: [],
    component_styles: [],
    css_variables: {},
    scss_variables: {},
    color_palette: {},
    primeng_overrides: [],
    theme_files: [],
    mixins: [],
    functions: [],
  };

  const srcPath = path.join(resolvedPath, 'src');
  if (!fs.existsSync(srcPath)) {
    throw new Error(`src directory not found in ${resolvedPath}`);
  }

  // Analyze all style files
  const styleFiles = rglobMulti(srcPath, ['.css', '.scss', '.sass', '.less']);

  for (const styleFile of styleFiles) {
    const relativePath = path.relative(resolvedPath, styleFile);
    const fileName = path.basename(styleFile);
    const ext = path.extname(styleFile);

    // Classify as global or component style
    const isComponentStyle = fileName.includes('.component.');

    const styleInfo = {
      name: fileName,
      path: relativePath,
      type: ext.slice(1),
      is_component_style: isComponentStyle,
    };

    // Read and analyze content
    let content;
    try {
      content = fs.readFileSync(styleFile, 'utf-8');
    } catch (e) {
      console.warn(`Warning: Could not read ${styleFile}: ${e.message}`);
      continue;
    }

    // Extract variables
    if (ext === '.scss' || ext === '.sass') {
      const scssVars = extractScssVariables(content);
      if (Object.keys(scssVars).length > 0) {
        styleInfo.variables = scssVars;
        Object.assign(analysis.scss_variables, scssVars);
      }

      // Extract mixins and functions
      const mixins = extractScssMixins(content);
      if (mixins.length > 0) {
        styleInfo.mixins = mixins;
        analysis.mixins.push(...mixins);
      }

      const functions = extractScssFunctions(content);
      if (functions.length > 0) {
        styleInfo.functions = functions;
        analysis.functions.push(...functions);
      }
    }

    // Extract CSS custom properties (variables)
    const cssVars = extractCssVariables(content);
    if (Object.keys(cssVars).length > 0) {
      styleInfo.css_variables = cssVars;
      Object.assign(analysis.css_variables, cssVars);
    }

    // Detect PrimeNG overrides
    const primengOverrides = detectPrimengOverrides(content);
    if (primengOverrides.length > 0) {
      styleInfo.primeng_overrides = primengOverrides;
      analysis.primeng_overrides.push({
        file: relativePath,
        overrides: primengOverrides,
      });
    }

    // Detect theme files
    if (isThemeFile(fileName, content)) {
      analysis.theme_files.push(styleInfo);
    }

    if (isComponentStyle) {
      analysis.component_styles.push(styleInfo);
    } else {
      analysis.global_styles.push(styleInfo);
    }
  }

  // Extract color palette from variables
  analysis.color_palette = extractColorPalette(analysis.scss_variables, analysis.css_variables);

  // Add statistics
  analysis.statistics = {
    total_style_files: analysis.global_styles.length + analysis.component_styles.length,
    global_styles: analysis.global_styles.length,
    component_styles: analysis.component_styles.length,
    scss_variables: Object.keys(analysis.scss_variables).length,
    css_variables: Object.keys(analysis.css_variables).length,
    colors_in_palette: Object.keys(analysis.color_palette).length,
    primeng_override_files: analysis.primeng_overrides.length,
    theme_files: analysis.theme_files.length,
    mixins: analysis.mixins.length,
    functions: analysis.functions.length,
  };

  return analysis;
}

/**
 * Extract SCSS variables ($variable: value;).
 * @param {string} content - Style file content
 * @returns {object} Map of variable names to values
 */
function extractScssVariables(content) {
  const variables = {};
  const pattern = /\$([a-zA-Z0-9_-]+)\s*:\s*([^;]+);/g;
  let match;
  while ((match = pattern.exec(content)) !== null) {
    variables[match[1]] = match[2].trim();
  }
  return variables;
}

/**
 * Extract CSS custom properties (--variable: value;).
 * @param {string} content - Style file content
 * @returns {object} Map of variable names to values
 */
function extractCssVariables(content) {
  const variables = {};
  const pattern = /--([a-zA-Z0-9_-]+)\s*:\s*([^;]+);/g;
  let match;
  while ((match = pattern.exec(content)) !== null) {
    variables[match[1]] = match[2].trim();
  }
  return variables;
}

/**
 * Extract SCSS mixins.
 * @param {string} content - Style file content
 * @returns {object[]}
 */
function extractScssMixins(content) {
  const mixins = [];
  const pattern = /@mixin\s+([a-zA-Z0-9_-]+)\s*(\([^)]*\))?\s*\{/g;
  let match;
  while ((match = pattern.exec(content)) !== null) {
    mixins.push({
      name: match[1],
      parameters: match[2] ? match[2].trim() : '',
    });
  }
  return mixins;
}

/**
 * Extract SCSS functions.
 * @param {string} content - Style file content
 * @returns {object[]}
 */
function extractScssFunctions(content) {
  const functions = [];
  const pattern = /@function\s+([a-zA-Z0-9_-]+)\s*(\([^)]*\))\s*\{/g;
  let match;
  while ((match = pattern.exec(content)) !== null) {
    functions.push({
      name: match[1],
      parameters: match[2].trim(),
    });
  }
  return functions;
}

/**
 * Detect PrimeNG component style overrides.
 * @param {string} content - Style file content
 * @returns {string[]} PrimeNG selectors being overridden
 */
function detectPrimengOverrides(content) {
  const overrides = new Set();

  const primengPatterns = [
    /\.p-[a-z-]+/g, // PrimeNG classes start with .p-
    /::ng-deep\s+\.p-[a-z-]+/g, // Deep selectors
    /:host\s+::ng-deep\s+\.p-[a-z-]+/g,
  ];

  for (const pattern of primengPatterns) {
    let match;
    while ((match = pattern.exec(content)) !== null) {
      overrides.add(match[0]);
    }
  }

  return [...overrides];
}

/**
 * Determine if a file is a theme file.
 * @param {string} filename - Name of the file
 * @param {string} content - File content
 * @returns {boolean}
 */
function isThemeFile(filename, content) {
  // Check filename
  const themeKeywords = ['theme', 'variables', 'colors', 'palette'];
  if (themeKeywords.some((kw) => filename.toLowerCase().includes(kw))) {
    return true;
  }

  // Check content for theme-related patterns
  const colorPattern = /(#[0-9a-fA-F]{3,6}|rgb|hsl|var\(--)/g;
  const colorMatches = content.match(colorPattern) || [];

  // If file has many color definitions, likely a theme file
  return colorMatches.length > 10;
}

/**
 * Extract color palette from variables.
 * @param {object} scssVars - SCSS variables
 * @param {object} cssVars - CSS custom properties
 * @returns {object} Color palette
 */
function extractColorPalette(scssVars, cssVars) {
  const colorPalette = {};
  const colorPattern = /^(#[0-9a-fA-F]{3,6}|rgb|rgba|hsl|hsla)/;

  // Check SCSS variables
  for (const [varName, varValue] of Object.entries(scssVars)) {
    if (colorPattern.test(varValue.trim()) || varName.toLowerCase().includes('color')) {
      colorPalette[`$${varName}`] = varValue;
    }
  }

  // Check CSS variables
  for (const [varName, varValue] of Object.entries(cssVars)) {
    if (colorPattern.test(varValue.trim()) || varName.toLowerCase().includes('color')) {
      colorPalette[`--${varName}`] = varValue;
    }
  }

  return colorPalette;
}

// --- Main ---
function main() {
  const args = process.argv.slice(2);

  if (args.length < 1) {
    console.log('Usage: node analyze_styles.mjs <repo_path> [output_file]');
    console.log('Example: node analyze_styles.mjs /path/to/angular-project styles.json');
    process.exit(1);
  }

  const repoPath = args[0];
  const outputFile = args[1] || 'styles_analysis.json';

  try {
    console.log(`Analyzing styles in: ${repoPath}`);
    const analysis = analyzeStyles(repoPath);

    // Write to output file
    fs.writeFileSync(outputFile, JSON.stringify(analysis, null, 2), 'utf-8');

    console.log(`\n✅ Analysis complete! Results saved to: ${outputFile}`);
    console.log('\nStatistics:');
    for (const [key, value] of Object.entries(analysis.statistics)) {
      console.log(`  ${key}: ${value}`);
    }

    const palette = Object.entries(analysis.color_palette);
    if (palette.length > 0) {
      console.log('\nSample colors from palette:');
      for (const [varName, varValue] of palette.slice(0, 5)) {
        console.log(`  ${varName}: ${varValue}`);
      }
      if (palette.length > 5) {
        console.log(`  ... and ${palette.length - 5} more`);
      }
    }
  } catch (e) {
    console.error(`❌ Error: ${e.message}`);
    process.exit(1);
  }
}

main();
