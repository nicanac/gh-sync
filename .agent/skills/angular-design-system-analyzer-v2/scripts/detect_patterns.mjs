#!/usr/bin/env node
/**
 * Detect code patterns and conventions in an Angular design system.
 */
import fs from 'node:fs';
import path from 'node:path';

function rglob(dir, ext) {
  const results = [];
  const skip = new Set(['node_modules', 'dist', 'coverage', '.git', '.angular']);
  function walk(d) {
    let entries;
    try { entries = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      if (e.name.startsWith('.') && e.name !== '.') continue;
      if (skip.has(e.name) && e.isDirectory()) continue;
      const fp = path.join(d, e.name);
      if (e.isDirectory()) walk(fp);
      else if (e.isFile() && e.name.endsWith(ext)) results.push(fp);
    }
  }
  walk(dir);
  return results;
}

function inc(o, k) { o[k] = (o[k] || 0) + 1; }
function topN(o, n) {
  return Object.fromEntries(Object.entries(o).sort((a, b) => b[1] - a[1]).slice(0, n));
}

function detectPatterns(repoPath) {
  const rp = path.resolve(repoPath);
  if (!fs.existsSync(rp)) throw new Error(`Path does not exist: ${rp}`);
  const srcPath = path.join(rp, 'src');
  if (!fs.existsSync(srcPath)) throw new Error(`src directory not found in ${rp}`);
  const tsFiles = rglob(srcPath, '.ts');

  return {
    naming_conventions: analyzeNaming(tsFiles),
    folder_structure_patterns: analyzeFolders(srcPath),
    import_patterns: analyzeImports(tsFiles),
    architectural_patterns: detectArch(tsFiles),
    code_standards: analyzeStandards(tsFiles),
    common_decorators: detectDecorators(tsFiles),
    rxjs_patterns: detectRxjs(tsFiles),
  };
}

function analyzeNaming(tsFiles) {
  const fp = {}, cp = {};
  for (const f of tsFiles.slice(0, 100)) {
    const fn = path.basename(f, '.ts');
    if (fn.includes('.')) { const s = fn.split('.'); inc(fp, s[s.length - 1]); }
    try {
      const c = fs.readFileSync(f, 'utf-8');
      for (const m of c.matchAll(/export\s+class\s+(\w+)/g)) {
        inc(cp, m[1][0] === m[1][0].toUpperCase() ? 'PascalCase' : 'camelCase');
      }
    } catch { continue; }
  }
  return {
    file_naming: { pattern: 'kebab-case with type suffix', common_suffixes: topN(fp, 10) },
    class_naming: { pattern: (cp.PascalCase || 0) > (cp.camelCase || 0) ? 'PascalCase' : 'camelCase', distribution: cp },
    variable_naming: { pattern: 'camelCase (Angular standard)', constants: 'UPPER_SNAKE_CASE', private_members: 'prefixed with underscore or camelCase' },
    examples: {},
  };
}

function analyzeFolders(srcPath) {
  const s = { organization_type: 'unknown', common_folders: [], depth_analysis: {}, module_organization: 'unknown' };
  if (!fs.existsSync(srcPath)) return s;
  const folders = fs.readdirSync(srcPath, { withFileTypes: true }).filter(d => d.isDirectory() && !d.name.startsWith('.')).map(d => d.name);
  s.common_folders = folders;
  if (folders.includes('app')) {
    const af = fs.readdirSync(path.join(srcPath, 'app'), { withFileTypes: true }).filter(d => d.isDirectory()).map(d => d.name);
    if (['features', 'modules', 'pages', 'views'].some(i => af.includes(i))) s.organization_type = 'feature-based';
    else if (af.includes('shared') || af.includes('core')) s.organization_type = 'shared-core pattern';
    else s.organization_type = 'component-based';
  }
  return s;
}

function analyzeImports(tsFiles) {
  const p = { relative_imports: 0, absolute_imports: 0, barrel_imports: 0, most_imported_modules: {}, import_aliases: {} };
  for (const f of tsFiles.slice(0, 100)) {
    let c; try { c = fs.readFileSync(f, 'utf-8'); } catch { continue; }
    for (const m of c.matchAll(/import\s+.*\s+from\s+['"]([^'"]+)['"]/g)) {
      const ip = m[1];
      if (ip.startsWith('.')) p.relative_imports++;
      else if (ip.startsWith('@')) { p.absolute_imports++; inc(p.most_imported_modules, ip.split('/')[0]); }
      else inc(p.most_imported_modules, ip.split('/')[0]);
      if (ip.endsWith('/index')) p.barrel_imports++;
    }
  }
  p.most_imported_modules = topN(p.most_imported_modules, 10);
  return p;
}

function detectArch(tsFiles) {
  const p = { uses_services: false, uses_state_management: false, state_management_library: null, uses_lazy_loading: false, uses_standalone_components: false, uses_dependency_injection: false, uses_reactive_forms: false, uses_template_driven_forms: false };
  let all = '';
  for (const f of tsFiles.slice(0, 50)) { try { all += fs.readFileSync(f, 'utf-8'); } catch { continue; } }
  if (all.includes('.service') || all.includes('Injectable')) { p.uses_services = true; p.uses_dependency_injection = true; }
  if (all.toLowerCase().includes('ngrx') || all.includes('@ngrx')) { p.uses_state_management = true; p.state_management_library = 'NgRx'; }
  else if (all.toLowerCase().includes('akita')) { p.uses_state_management = true; p.state_management_library = 'Akita'; }
  if (all.includes('loadChildren')) p.uses_lazy_loading = true;
  if (all.includes('standalone: true')) p.uses_standalone_components = true;
  if (all.includes('FormGroup') || all.includes('FormControl')) p.uses_reactive_forms = true;
  if (all.includes('ngModel')) p.uses_template_driven_forms = true;
  return p;
}

function analyzeStandards(tsFiles) {
  const s = { uses_typescript_strict: false, uses_linting: false, uses_prettier: false, average_file_length: 0, uses_jsdoc: false, uses_interfaces: false, uses_enums: false, uses_type_aliases: false };
  let tl = 0, fc = 0;
  for (const f of tsFiles.slice(0, 50)) {
    let c; try { c = fs.readFileSync(f, 'utf-8'); } catch { continue; }
    tl += c.split('\n').length; fc++;
    if (c.includes('interface ')) s.uses_interfaces = true;
    if (c.includes('enum ')) s.uses_enums = true;
    if (c.includes('type ') && c.includes('=')) s.uses_type_aliases = true;
    if (c.includes('/**') || c.includes('/*')) s.uses_jsdoc = true;
  }
  if (fc > 0) s.average_file_length = Math.floor(tl / fc);
  return s;
}

function detectDecorators(tsFiles) {
  const d = {};
  for (const f of tsFiles.slice(0, 100)) {
    let c; try { c = fs.readFileSync(f, 'utf-8'); } catch { continue; }
    for (const m of c.matchAll(/@(\w+)\(/g)) inc(d, m[1]);
  }
  return topN(d, 15);
}

function detectRxjs(tsFiles) {
  const ops = {};
  for (const f of tsFiles.slice(0, 50)) {
    let c; try { c = fs.readFileSync(f, 'utf-8'); } catch { continue; }
    const m = c.match(/import\s+{([^}]+)}\s+from\s+['"]rxjs/);
    if (m) for (const op of m[1].split(',').map(s => s.trim())) inc(ops, op);
  }
  if (Object.keys(ops).length > 0) return [{ pattern: 'RxJS Observables', common_operators: topN(ops, 10) }];
  return [];
}

// --- Main ---
const args = process.argv.slice(2);
if (args.length < 1) { console.log('Usage: node detect_patterns.mjs <repo_path> [output_file]'); process.exit(1); }
const repoPath = args[0], outputFile = args[1] || 'patterns_analysis.json';
try {
  console.log(`Detecting patterns in: ${repoPath}`);
  const analysis = detectPatterns(repoPath);
  fs.writeFileSync(outputFile, JSON.stringify(analysis, null, 2), 'utf-8');
  console.log(`\n✅ Analysis complete! Results saved to: ${outputFile}`);
  console.log(`\nKey Findings:`);
  console.log(`  Organization: ${analysis.folder_structure_patterns.organization_type || 'unknown'}`);
  console.log(`  Uses Services: ${analysis.architectural_patterns.uses_services}`);
  console.log(`  State Management: ${analysis.architectural_patterns.state_management_library || 'None'}`);
} catch (e) { console.error(`❌ Error: ${e.message}`); process.exit(1); }
