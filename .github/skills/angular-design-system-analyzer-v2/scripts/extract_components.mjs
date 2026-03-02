#!/usr/bin/env node

/**
 * Extract and analyze Angular components from a design system.
 * Detects component metadata, PrimeNG usage, and customizations.
 */

import fs from 'node:fs';
import path from 'node:path';

/**
 * Recursively find files with a given extension.
 * @param {string} dir - Directory to search
 * @param {string} ext - File extension to match (e.g. '.component.ts')
 * @returns {string[]} Array of matching file paths
 */
function rglob(dir, ext) {
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
      } else if (entry.isFile() && entry.name.endsWith(ext)) {
        results.push(fullPath);
      }
    }
  }

  walk(dir);
  return results;
}

/**
 * Extract all components and their metadata.
 * @param {string} repoPath - Path to the Angular repository
 * @returns {object} Component analysis
 */
function extractComponents(repoPath) {
  const resolvedPath = path.resolve(repoPath);

  if (!fs.existsSync(resolvedPath)) {
    throw new Error(`Repository path does not exist: ${resolvedPath}`);
  }

  const analysis = {
    components: [],
    primeng_components_used: new Set(),
    custom_components: [],
    component_patterns: {},
    primeng_customizations: [],
  };

  const srcPath = path.join(resolvedPath, 'src');
  if (!fs.existsSync(srcPath)) {
    throw new Error(`src directory not found in ${resolvedPath}`);
  }

  // Find all component TypeScript files
  for (const tsFile of rglob(srcPath, '.component.ts')) {
    const componentInfo = analyzeComponentFile(tsFile, resolvedPath);
    if (componentInfo) {
      analysis.components.push(componentInfo);

      // Track PrimeNG components
      for (const primengComp of componentInfo.primeng_components || []) {
        analysis.primeng_components_used.add(primengComp);
      }

      // Detect customizations
      if (componentInfo.is_primeng_customization) {
        analysis.primeng_customizations.push(componentInfo);
      } else if (!componentInfo.uses_primeng) {
        analysis.custom_components.push(componentInfo);
      }
    }
  }

  // Convert Set to sorted array for JSON serialization
  analysis.primeng_components_used = [...analysis.primeng_components_used].sort();

  // Detect common patterns
  analysis.component_patterns = detectComponentPatterns(analysis.components);

  // Add statistics
  analysis.statistics = {
    total_components: analysis.components.length,
    primeng_components_used: analysis.primeng_components_used.length,
    custom_components: analysis.custom_components.length,
    primeng_customizations: analysis.primeng_customizations.length,
  };

  return analysis;
}

/**
 * Analyze a single component TypeScript file.
 * @param {string} filePath - Path to the component file
 * @param {string} repoRoot - Root path of the repository
 * @returns {object|null} Component information
 */
function analyzeComponentFile(filePath, repoRoot) {
  let content;
  try {
    content = fs.readFileSync(filePath, 'utf-8');
  } catch (e) {
    console.warn(`Warning: Could not read ${filePath}: ${e.message}`);
    return null;
  }

  const fileName = path.basename(filePath, '.ts');
  const componentName = fileName.replace('.component', '');
  const relativePath = path.relative(repoRoot, filePath);

  const componentInfo = {
    name: componentName,
    path: relativePath,
    directory: path.dirname(relativePath),
    selector: extractSelector(content),
    inputs: extractInputs(content),
    outputs: extractOutputs(content),
    imports: extractImports(content),
    primeng_components: extractPrimengComponents(content),
    uses_primeng: false,
    is_primeng_customization: false,
    injected_services: extractInjectedServices(content),
    lifecycle_hooks: extractLifecycleHooks(content),
    has_template: false,
    has_styles: false,
  };

  // Check for associated template and style files
  const dir = path.dirname(filePath);
  const templateFile = path.join(dir, `${componentName}.component.html`);
  componentInfo.has_template = fs.existsSync(templateFile);

  for (const ext of ['.scss', '.css', '.sass', '.less']) {
    const styleFile = path.join(dir, `${componentName}.component${ext}`);
    if (fs.existsSync(styleFile)) {
      componentInfo.has_styles = true;
      componentInfo.style_type = ext.slice(1);
      break;
    }
  }

  // Detect PrimeNG usage
  if (componentInfo.primeng_components.length > 0) {
    componentInfo.uses_primeng = true;

    // Check if this is a customization wrapper
    if (isPrimengWrapper(content, componentName)) {
      componentInfo.is_primeng_customization = true;
    }
  }

  return componentInfo;
}

/**
 * Extract component selector from @Component decorator.
 * @param {string} content - File content
 * @returns {string|null}
 */
function extractSelector(content) {
  const match = content.match(/selector:\s*['"]([^'"]+)['"]/);
  return match ? match[1] : null;
}

/**
 * Extract @Input() properties.
 * @param {string} content - File content
 * @returns {string[]}
 */
function extractInputs(content) {
  const pattern = /@Input\(['"]?(\w+)?['"]?\)\s+(\w+)/g;
  const inputs = [];
  let match;
  while ((match = pattern.exec(content)) !== null) {
    inputs.push(match[1] || match[2]);
  }
  return inputs;
}

/**
 * Extract @Output() properties.
 * @param {string} content - File content
 * @returns {string[]}
 */
function extractOutputs(content) {
  const pattern = /@Output\(['"]?(\w+)?['"]?\)\s+(\w+)/g;
  const outputs = [];
  let match;
  while ((match = pattern.exec(content)) !== null) {
    outputs.push(match[1] || match[2]);
  }
  return outputs;
}

/**
 * Extract import statements.
 * @param {string} content - File content
 * @returns {object[]}
 */
function extractImports(content) {
  const imports = [];
  const pattern = /import\s+{([^}]+)}\s+from\s+['"]([^'"]+)['"]/g;
  let match;
  while ((match = pattern.exec(content)) !== null) {
    imports.push({
      module: match[2],
      symbols: match[1].split(',').map((s) => s.trim()),
    });
  }
  return imports;
}

/**
 * Extract PrimeNG components used in imports.
 * @param {string} content - File content
 * @returns {string[]}
 */
function extractPrimengComponents(content) {
  const primengComponents = [];
  const pattern = /import\s+{([^}]+)}\s+from\s+['"]primeng\/([^'"]+)['"]/g;
  let match;
  while ((match = pattern.exec(content)) !== null) {
    const components = match[1].split(',').map((s) => s.trim());
    primengComponents.push(...components);
  }
  return primengComponents;
}

/**
 * Extract services injected in constructor.
 * @param {string} content - File content
 * @returns {string[]}
 */
function extractInjectedServices(content) {
  const constructorMatch = content.match(/constructor\s*\(([^)]*)\)/s);
  if (!constructorMatch) return [];

  const params = constructorMatch[1];
  const paramPattern = /(?:private|public|protected)?\s*(\w+)\s*:\s*(\w+)/g;
  const services = [];
  let match;
  while ((match = paramPattern.exec(params)) !== null) {
    services.push(match[2]);
  }
  return services;
}

/**
 * Extract Angular lifecycle hooks implemented.
 * @param {string} content - File content
 * @returns {string[]}
 */
function extractLifecycleHooks(content) {
  const hooks = [
    'ngOnInit',
    'ngOnChanges',
    'ngDoCheck',
    'ngAfterContentInit',
    'ngAfterContentChecked',
    'ngAfterViewInit',
    'ngAfterViewChecked',
    'ngOnDestroy',
  ];

  return hooks.filter((hook) => new RegExp(`\\b${hook}\\s*\\(`).test(content));
}

/**
 * Detect if component is a wrapper/customization of a PrimeNG component.
 * @param {string} content - Component file content
 * @param {string} componentName - Name of the component
 * @returns {boolean}
 */
function isPrimengWrapper(content, componentName) {
  // Check if component extends a PrimeNG component
  if (/extends\s+\w+/.test(content)) {
    return true;
  }

  // Check if template uses a single PrimeNG component with property binding
  const primengPattern = /<p-\w+/g;
  const matches = content.match(primengPattern) || [];
  const uniqueMatches = new Set(matches);

  // If there's exactly one PrimeNG component reference, likely a wrapper
  return uniqueMatches.size === 1;
}

/**
 * Detect common patterns across components.
 * @param {object[]} components - List of component information
 * @returns {object} Detected patterns
 */
function detectComponentPatterns(components) {
  const patterns = {
    common_inputs: {},
    common_outputs: {},
    common_services: {},
    common_lifecycle_hooks: {},
    selector_pattern: 'kebab-case',
  };

  // Count occurrences
  for (const component of components) {
    for (const inputName of component.inputs || []) {
      patterns.common_inputs[inputName] = (patterns.common_inputs[inputName] || 0) + 1;
    }

    for (const outputName of component.outputs || []) {
      patterns.common_outputs[outputName] = (patterns.common_outputs[outputName] || 0) + 1;
    }

    for (const service of component.injected_services || []) {
      patterns.common_services[service] = (patterns.common_services[service] || 0) + 1;
    }

    for (const hook of component.lifecycle_hooks || []) {
      patterns.common_lifecycle_hooks[hook] = (patterns.common_lifecycle_hooks[hook] || 0) + 1;
    }
  }

  // Keep only common ones (used in >20% of components)
  const threshold = components.length * 0.2;

  patterns.common_inputs = filterByThreshold(patterns.common_inputs, threshold);
  patterns.common_outputs = filterByThreshold(patterns.common_outputs, threshold);
  patterns.common_services = filterByThreshold(patterns.common_services, threshold);

  return patterns;
}

/**
 * Filter an object keeping only entries above a threshold.
 * @param {object} obj
 * @param {number} threshold
 * @returns {object}
 */
function filterByThreshold(obj, threshold) {
  const result = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v > threshold) result[k] = v;
  }
  return result;
}

// --- Main ---
function main() {
  const args = process.argv.slice(2);

  if (args.length < 1) {
    console.log('Usage: node extract_components.mjs <repo_path> [output_file]');
    console.log('Example: node extract_components.mjs /path/to/angular-project components.json');
    process.exit(1);
  }

  const repoPath = args[0];
  const outputFile = args[1] || 'components_analysis.json';

  try {
    console.log(`Extracting components from: ${repoPath}`);
    const analysis = extractComponents(repoPath);

    // Write to output file
    fs.writeFileSync(outputFile, JSON.stringify(analysis, null, 2), 'utf-8');

    console.log(`\n✅ Analysis complete! Results saved to: ${outputFile}`);
    console.log('\nStatistics:');
    for (const [key, value] of Object.entries(analysis.statistics)) {
      console.log(`  ${key}: ${value}`);
    }

    const used = analysis.primeng_components_used.slice(0, 10);
    console.log(`\nPrimeNG components used: ${used.join(', ')}`);
    if (analysis.primeng_components_used.length > 10) {
      console.log(`  ... and ${analysis.primeng_components_used.length - 10} more`);
    }
  } catch (e) {
    console.error(`❌ Error: ${e.message}`);
    process.exit(1);
  }
}

main();
