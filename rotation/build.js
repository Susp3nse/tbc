/**
 * Flux AIO Build Script
 *
 * Discovers class modules, builds CodeSnippets, and writes TMW profiles.
 * Used both as a CLI tool and as a module imported by dev-watch.
 *
 * CLI usage:
 *   node build.js              Build TellMeWhen.lua (default)
 *   node build.js --sync       Sync to SavedVariables (requires dev.ini)
 *   node build.js --all        Build + sync
 *
 * Module usage:
 *   const build = require('./build');
 *   build.syncToSavedVariables(config, classes);
 */

const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = process.env.ROTATION_ROOT || __dirname;
const DEFAULT_AIO_DIR = path.join(PROJECT_ROOT, 'source', 'aio');
const TEMPLATE_PATH = path.join(PROJECT_ROOT, 'tmw-template.lua');
const OUTPUT_PATH = path.join(PROJECT_ROOT, 'output', 'TellMeWhen.lua');
const INI_PATH = path.join(PROJECT_ROOT, 'dev.ini');

// ---------------------------------------------------------------------------
// INI Parser
// ---------------------------------------------------------------------------

function parseINI(text) {
  const result = {};
  let section = '';
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line[0] === ';' || line[0] === '#') continue;
    const secMatch = line.match(/^\[(.+)\]$/);
    if (secMatch) { section = secMatch[1]; result[section] = result[section] || {}; continue; }
    const kvMatch = line.match(/^([^=]+)=(.*)$/);
    if (kvMatch && section) { result[section][kvMatch[1].trim()] = kvMatch[2].trim(); }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Lua String Escaping
// ---------------------------------------------------------------------------

function escapeLuaString(content) {
  return content
    .replace(/\\/g, '\\\\')    // Escape backslashes first
    .replace(/"/g, '\\"')      // Escape double quotes
    .replace(/\n/g, '\\n')     // Convert newlines to \n
    .replace(/\r/g, '');       // Remove carriage returns (Windows)
}

// ---------------------------------------------------------------------------
// Path Resolution
// ---------------------------------------------------------------------------

/**
 * Resolve the AIO source directory from config, or use the default.
 */
function getAIODir(config) {
  if (config && config.paths && config.paths.watchdir) {
    return path.resolve(PROJECT_ROOT, config.paths.watchdir);
  }
  return DEFAULT_AIO_DIR;
}

// ---------------------------------------------------------------------------
// Module Discovery & Ordering
// ---------------------------------------------------------------------------

// IMPORTANT: Lua 5.1 table.sort is unstable (quicksort) -- modules sharing
// the same Order value may load in ANY order. Only modules with NO mutual
// dependencies should share an Order value.
const ORDER_MAP = {
  'common.lua':     1,
  'schema.lua':     2,
  'ui.lua':         3,
  'core.lua':       4,
  'class.lua':      5,
  'healing.lua':    6,
  'settings.lua':   6,
  'middleware.lua':  7,
  'dashboard.lua':  8,
  'main.lua':       9,
};

// Fixed load-order slots for known filenames. Unknowns get Order 7, sorted alphabetically.
const LOAD_ORDER = [
  { slot: 'shared', source: 'common.lua' },   // shared schema section factories
  { slot: 'class', source: 'schema.lua' },     // class-specific schema
  { slot: 'shared', source: 'ui.lua' },
  { slot: 'shared', source: 'core.lua' },
  { slot: 'class', source: 'class.lua' },
  { slot: 'class', source: 'healing.lua' },
  { slot: 'shared', source: 'settings.lua' },
  { slot: 'class', source: 'middleware.lua' },
  // ... remaining class files (Order 7) inserted here alphabetically ...
  { slot: 'shared', source: 'dashboard.lua' }, // shared combat dashboard
  { slot: 'shared', source: 'main.lua' },      // always last
];

const NAME_OVERRIDES = { 'ui': 'UI' };

function toPascalCase(filename) {
  const name = filename.replace('.lua', '');
  if (NAME_OVERRIDES[name]) return NAME_OVERRIDES[name];
  return name.charAt(0).toUpperCase() + name.slice(1);
}

/**
 * Build ordered module list for a class.
 * Returns array of { name, order, filePath }.
 */
function discoverModules(className, aioDir) {
  const classDir = path.join(aioDir, className);
  const sharedFiles = fs.readdirSync(aioDir).filter(f => f.endsWith('.lua'));
  const classFiles = fs.existsSync(classDir)
    ? fs.readdirSync(classDir).filter(f => f.endsWith('.lua'))
    : [];

  // Enforce naming convention: no underscores, hyphens, or spaces in filenames
  for (const f of [...sharedFiles, ...classFiles]) {
    const stem = f.replace('.lua', '');
    if (/[_\s-]/.test(stem)) {
      console.error(`ERROR: Bad filename "${f}" — use single lowercase words (no underscores/hyphens/spaces)`);
      process.exit(1);
    }
  }

  // Known-order slots (excluding the "remaining" wildcard)
  const knownClassFiles = new Set(LOAD_ORDER.filter(s => s.slot === 'class').map(s => s.source));
  // Remaining class files = everything not in fixed slots, alphabetical
  const remainingClass = classFiles
    .filter(f => !knownClassFiles.has(f))
    .sort();

  const modules = [];

  // Walk the fixed load order, inserting remaining class files before main.lua
  for (const slot of LOAD_ORDER) {
    if (slot.source === 'main.lua') {
      // Insert remaining class files (Order 7) before main
      for (const f of remainingClass) {
        modules.push({
          name: `Flux_${toPascalCase(className)}_${toPascalCase(f)}`,
          order: ORDER_MAP[f] || 7,
          filePath: path.join(classDir, f),
        });
      }
    }

    if (slot.slot === 'shared') {
      if (sharedFiles.includes(slot.source)) {
        modules.push({
          name: `Flux_${toPascalCase(slot.source)}`,
          order: ORDER_MAP[slot.source],
          filePath: path.join(aioDir, slot.source),
        });
      }
    } else {
      // class-specific
      if (classFiles.includes(slot.source)) {
        modules.push({
          name: `Flux_${toPascalCase(className)}_${toPascalCase(slot.source)}`,
          order: ORDER_MAP[slot.source],
          filePath: path.join(classDir, slot.source),
        });
      }
    }
  }

  return modules;
}

/**
 * Scan aio dir for class subdirectories.
 */
function discoverClasses(aioDir) {
  if (!fs.existsSync(aioDir)) return [];
  return fs.readdirSync(aioDir).filter(entry => {
    return fs.statSync(path.join(aioDir, entry)).isDirectory();
  });
}

/**
 * Get the profile name for a class, respecting config overrides.
 */
function getProfileName(className, config) {
  if (config && config.profiles && config.profiles[className]) {
    return config.profiles[className];
  }
  return `Flux ${className.charAt(0).toUpperCase() + className.slice(1)}`;
}

// ---------------------------------------------------------------------------
// CodeSnippets Builder
// ---------------------------------------------------------------------------

function buildCodeSnippets(modules) {
  const lines = ['["CodeSnippets"] = {'];
  for (const mod of modules) {
    const code = fs.readFileSync(mod.filePath, 'utf8');
    const escaped = escapeLuaString(code);
    lines.push('{');
    lines.push(`["Order"] = ${mod.order},`);
    lines.push(`["Name"] = "${mod.name}",`);
    lines.push(`["Code"] = "${escaped}",`);
    lines.push('},');
  }
  lines.push(`["n"] = ${modules.length},`);
  lines.push('},');
  return lines;
}

// ---------------------------------------------------------------------------
// TellMeWhen.lua Profile Operations
// ---------------------------------------------------------------------------

/**
 * Find a section delimited by braces, starting at a line that matches `startPattern`.
 * Returns { start, end } line indices (inclusive), or null.
 */
function findBracedSection(lines, startPattern) {
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim().match(startPattern)) {
      let braceDepth = 0;
      let foundOpen = false;
      for (let j = i; j < lines.length; j++) {
        for (const ch of lines[j]) {
          if (ch === '{') { braceDepth++; foundOpen = true; }
          if (ch === '}') braceDepth--;
        }
        if (foundOpen && braceDepth <= 0) {
          return { start: i, end: j };
        }
      }
      break;
    }
  }
  return null;
}

/**
 * Find CodeSnippets section within a profile's line range.
 */
function findCodeSnippets(lines, profileStart, profileEnd) {
  for (let i = profileStart; i <= profileEnd; i++) {
    if (lines[i].trim() === '["CodeSnippets"] = {') {
      let braceDepth = 1;
      for (let j = i + 1; j <= profileEnd; j++) {
        for (const ch of lines[j]) {
          if (ch === '{') braceDepth++;
          if (ch === '}') braceDepth--;
        }
        if (braceDepth <= 0) {
          return { start: i, end: j };
        }
      }
    }
  }
  return null;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function findNamedBracedSection(lines, profileStart, profileEnd, sectionName) {
  const pattern = new RegExp(`^\\["${escapeRegExp(sectionName)}"\\]\\s*=\\s*\\{`);
  for (let i = profileStart; i <= profileEnd; i++) {
    if (lines[i].trim().match(pattern)) {
      let braceDepth = 0;
      let foundOpen = false;
      for (let j = i; j <= profileEnd; j++) {
        for (const ch of lines[j]) {
          if (ch === '{') { braceDepth++; foundOpen = true; }
          if (ch === '}') braceDepth--;
        }
        if (foundOpen && braceDepth <= 0) {
          return { start: i, end: j };
        }
      }
      break;
    }
  }
  return null;
}

function findScalarLine(lines, profileStart, profileEnd, keyName) {
  const pattern = new RegExp(`^\\["${escapeRegExp(keyName)}"\\]\\s*=`);
  for (let i = profileStart; i <= profileEnd; i++) {
    if (lines[i].trim().match(pattern)) return i;
  }
  return -1;
}

function replaceNamedBracedSection(targetLines, templateProfileLines, sectionName) {
  const src = findNamedBracedSection(templateProfileLines, 0, templateProfileLines.length - 1, sectionName);
  if (!src) return targetLines;

  const srcLines = templateProfileLines.slice(src.start, src.end + 1);
  const dst = findNamedBracedSection(targetLines, 0, targetLines.length - 1, sectionName);
  if (dst) {
    return [
      ...targetLines.slice(0, dst.start),
      ...srcLines,
      ...targetLines.slice(dst.end + 1),
    ];
  }

  // Insert before the profile-closing brace when the target profile lacks this section.
  return [
    ...targetLines.slice(0, -1),
    ...srcLines,
    targetLines[targetLines.length - 1],
  ];
}

function replaceScalarFromTemplate(targetLines, templateProfileLines, keyName) {
  const srcIndex = findScalarLine(templateProfileLines, 0, templateProfileLines.length - 1, keyName);
  if (srcIndex < 0) return targetLines;

  const dstIndex = findScalarLine(targetLines, 0, targetLines.length - 1, keyName);
  if (dstIndex >= 0) {
    const result = [...targetLines];
    result[dstIndex] = templateProfileLines[srcIndex];
    return result;
  }

  return [
    targetLines[0],
    templateProfileLines[srcIndex],
    ...targetLines.slice(1),
  ];
}

function loadTemplateProfileLines(templatePath) {
  const effectiveTemplatePath = templatePath && fs.existsSync(templatePath)
    ? templatePath
    : (fs.existsSync(TEMPLATE_PATH) ? TEMPLATE_PATH : null);
  if (!effectiveTemplatePath) return null;

  const templateLines = fs.readFileSync(effectiveTemplatePath, 'utf8').split(/\r?\n/);
  const tmplProfilesSection = findBracedSection(templateLines, /^\["profiles"\]\s*=\s*\{/);
  if (!tmplProfilesSection) {
    console.error('  ERROR: No ["profiles"] section in template');
    return null;
  }

  for (let i = tmplProfilesSection.start + 1; i <= tmplProfilesSection.end; i++) {
    if (templateLines[i].trim().match(/^\[".+"\]\s*=\s*\{/)) {
      let depth = 0;
      for (let j = i; j <= tmplProfilesSection.end; j++) {
        for (const ch of templateLines[j]) {
          if (ch === '{') depth++;
          if (ch === '}') depth--;
        }
        if (depth <= 0) {
          return templateLines.slice(i, j + 1);
        }
      }
      break;
    }
  }

  console.error('  ERROR: Could not find profile skeleton in template');
  return null;
}

function refreshManagedProfileScaffold(profileLines, templateProfileLines) {
  let result = profileLines;
  result = replaceNamedBracedSection(result, templateProfileLines, 'Groups');
  result = replaceScalarFromTemplate(result, templateProfileLines, 'NumGroups');
  result = replaceScalarFromTemplate(result, templateProfileLines, 'TextureName');
  return result;
}

/**
 * Find a profile by name inside ["profiles"] = { ... }.
 * Returns { start, end } or null.
 */
function findProfile(lines, profileName) {
  const profilesSection = findBracedSection(lines, /^\["profiles"\]\s*=\s*\{/);
  if (!profilesSection) return null;

  const escaped = profileName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = new RegExp(`^\\["${escaped}"\\]\\s*=\\s*\\{`);

  for (let i = profilesSection.start + 1; i <= profilesSection.end; i++) {
    if (lines[i].trim().match(pattern)) {
      let braceDepth = 0;
      for (let j = i; j <= profilesSection.end; j++) {
        for (const ch of lines[j]) {
          if (ch === '{') braceDepth++;
          if (ch === '}') braceDepth--;
        }
        if (braceDepth <= 0) {
          return { start: i, end: j };
        }
      }
    }
  }
  return null;
}

/**
 * Ensure profileKeys contains the profile name.
 */
function ensureProfileKey(lines, profileName) {
  const keysSection = findBracedSection(lines, /^\["profileKeys"\]\s*=\s*\{/);
  if (!keysSection) return lines;

  const escaped = profileName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const keyPattern = new RegExp(`\\["${escaped}"\\]`);

  // Check if already exists
  for (let i = keysSection.start; i <= keysSection.end; i++) {
    if (lines[i].match(keyPattern)) return lines;
  }

  // Insert before closing brace
  const result = [...lines];
  result.splice(keysSection.end, 0, `["${profileName}"] = "${profileName}",`);
  return result;
}

/**
 * Remove a profile key from profileKeys.
 */
function removeProfileKey(lines, profileName) {
  const keysSection = findBracedSection(lines, /^\["profileKeys"\]\s*=\s*\{/);
  if (!keysSection) return lines;

  const escaped = profileName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const keyPattern = new RegExp(`^\\["${escaped}"\\]\\s*=`);

  const result = [...lines];
  for (let i = keysSection.end; i >= keysSection.start; i--) {
    if (result[i].trim().match(keyPattern)) {
      result.splice(i, 1);
    }
  }
  return result;
}

/**
 * Remove a profile entirely from the profiles section.
 */
function removeProfile(lines, profileName) {
  const profile = findProfile(lines, profileName);
  if (!profile) return lines;

  const result = [...lines];
  result.splice(profile.start, profile.end - profile.start + 1);
  return result;
}

/**
 * Sync modules for a single class into TellMeWhen.lua content.
 * Returns the updated lines array.
 */
function syncProfile(lines, profileName, modules, templatePath) {
  const snippetLines = buildCodeSnippets(modules);
  const profile = findProfile(lines, profileName);
  const templateProfileLines = loadTemplateProfileLines(templatePath);

  if (profile) {
    // Profile exists — replace CodeSnippets and the managed TMW scaffold.
    let existingProfileLines = lines.slice(profile.start, profile.end + 1);
    const cs = findCodeSnippets(existingProfileLines, 0, existingProfileLines.length - 1);
    if (!cs) {
      // Profile is incomplete (no CodeSnippets) — strip it and rebuild from template
      // so it gets proper Groups, Icons, Conditions, and ActionDB
      console.log(`  Profile "${profileName}" missing CodeSnippets — rebuilding from template`);
      lines = [
        ...lines.slice(0, profile.start),
        ...lines.slice(profile.end + 1),
      ];
      // Fall through to create-from-template below
    } else {
      existingProfileLines = [
        ...existingProfileLines.slice(0, cs.start),
        ...snippetLines,
        ...existingProfileLines.slice(cs.end + 1),
      ];
      if (templateProfileLines) {
        existingProfileLines = refreshManagedProfileScaffold(existingProfileLines, templateProfileLines);
      }
      return [
        ...lines.slice(0, profile.start),
        ...existingProfileLines,
        ...lines.slice(profile.end + 1),
      ];
    }
  }

  // Profile doesn't exist — create from template
  console.log(`  Creating new profile "${profileName}" from template...`);

  if (!templateProfileLines) {
    // Minimal profile if no template
    console.log('  WARNING: No template found, creating minimal profile');
    const newProfile = [
      `["${profileName}"] = {`,
      '["Version"] = 12000703,',
      ...snippetLines,
      '},',
    ];

    const profilesSection = findBracedSection(lines, /^\["profiles"\]\s*=\s*\{/);
    if (!profilesSection) {
      console.error('  ERROR: No ["profiles"] section found in TellMeWhen.lua');
      return lines;
    }

    let result = [
      ...lines.slice(0, profilesSection.end),
      ...newProfile,
      ...lines.slice(profilesSection.end),
    ];
    result = ensureProfileKey(result, profileName);
    return result;
  }

  // Clone the template profile, rename it, replace CodeSnippets
  let profileLines = [...templateProfileLines];
  profileLines[0] = `["${profileName}"] = {`;

  const clonedCS = findCodeSnippets(profileLines, 0, profileLines.length - 1);
  if (clonedCS) {
    profileLines = [
      ...profileLines.slice(0, clonedCS.start),
      ...snippetLines,
      ...profileLines.slice(clonedCS.end + 1),
    ];
  }

  // Insert into profiles section of target
  const profilesSection = findBracedSection(lines, /^\["profiles"\]\s*=\s*\{/);
  if (!profilesSection) {
    console.error('  ERROR: No ["profiles"] section in TellMeWhen.lua');
    return lines;
  }

  let result = [
    ...lines.slice(0, profilesSection.end),
    ...profileLines,
    ...lines.slice(profilesSection.end),
  ];
  result = ensureProfileKey(result, profileName);
  return result;
}

/**
 * Find all profile names in the profiles section.
 */
function listProfileNames(lines) {
  const profilesSection = findBracedSection(lines, /^\["profiles"\]\s*=\s*\{/);
  if (!profilesSection) return [];

  const names = [];
  for (let i = profilesSection.start + 1; i <= profilesSection.end; i++) {
    const m = lines[i].trim().match(/^\["(.+)"\]\s*=\s*\{/);
    if (m) names.push(m[1]);
  }
  return names;
}

/**
 * Purge profiles from SV that don't match any discovered class.
 * Only purges profiles matching the "Flux *" naming convention.
 */
function purgeStaleProfiles(lines, validNames, config) {
  const allNames = listProfileNames(lines);
  let result = lines;

  for (const name of allNames) {
    if (name === '__template__') continue;
    if (validNames.has(name)) continue;

    // Check if this is a managed profile (matches our naming convention or config overrides)
    const isManaged = name.startsWith('Flux ') ||
      (config && config.profiles && Object.values(config.profiles).includes(name));

    if (!isManaged) continue;

    console.log(`  Purging stale profile: "${name}"`);
    result = removeProfile(result, name);
    result = removeProfileKey(result, name);
  }

  return result;
}

// ---------------------------------------------------------------------------
// Account / SavedVariables Path Resolution
// ---------------------------------------------------------------------------

/**
 * Resolve all SavedVariables paths from config.
 * Prefers [accounts] section (name = path). Falls back to [paths] savedvariables.
 * Returns array of { name, svPath }.
 */
function getSavedVariablesPaths(config) {
  if (config && config.accounts) {
    const entries = Object.entries(config.accounts);
    if (entries.length > 0) {
      return entries.map(([name, svPath]) => ({ name, svPath }));
    }
  }
  // Backward compat: single path from [paths]
  if (config && config.paths && config.paths.savedvariables) {
    return [{ name: 'default', svPath: config.paths.savedvariables }];
  }
  return [];
}

// ---------------------------------------------------------------------------
// Write Helpers
// ---------------------------------------------------------------------------

function writeWithRetry(filePath, content, attempts = 3, delay = 500) {
  for (let i = 0; i < attempts; i++) {
    try {
      fs.writeFileSync(filePath, content, 'utf8');
      return;
    } catch (err) {
      if (i < attempts - 1 && (err.code === 'EBUSY' || err.code === 'EPERM')) {
        console.log(`  File locked, retrying in ${delay}ms...`);
        const waitUntil = Date.now() + delay;
        while (Date.now() < waitUntil) { /* busy wait */ }
      } else {
        console.error(`  ERROR writing ${filePath}: ${err.message}`);
        return;
      }
    }
  }
}

function timestamp() {
  return new Date().toLocaleTimeString('en-US', { hour12: false });
}

// ---------------------------------------------------------------------------
// Build Modes
// ---------------------------------------------------------------------------

/**
 * Build the distributable output file (TellMeWhen.lua).
 * Clones the template for each discovered class, inserts CodeSnippets.
 */
function buildOutput(classes, config) {
  if (!fs.existsSync(TEMPLATE_PATH)) {
    console.error(`Error: Template not found: ${TEMPLATE_PATH}`);
    return false;
  }

  const aioDir = getAIODir(config);
  const template = fs.readFileSync(TEMPLATE_PATH, 'utf8');
  const hasWindows = template.includes('\r\n');
  let lines = template.split(/\r?\n/);

  // Remove the __template__ profile — real class profiles replace it
  lines = removeProfile(lines, '__template__');
  lines = removeProfileKey(lines, '__template__');

  for (const className of classes) {
    const profileName = getProfileName(className, config);
    const modules = discoverModules(className, aioDir);
    if (modules.length === 0) {
      console.log(`  Skipping ${className}: no modules found`);
      continue;
    }
    lines = syncProfile(lines, profileName, modules, TEMPLATE_PATH);
    console.log(`  Built: ${profileName} (${modules.length} modules)`);
  }

  const output = lines.join(hasWindows ? '\r\n' : '\n');
  const outputDir = path.dirname(OUTPUT_PATH);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  fs.writeFileSync(OUTPUT_PATH, output, 'utf8');
  console.log(`\nWrote ${OUTPUT_PATH}`);
  return true;
}

/**
 * Sync CodeSnippets to the game's TellMeWhen.lua SavedVariables.
 * Creates profiles for discovered classes, purges stale ones.
 * @param {object} config - Parsed INI config
 * @param {string[]} classNames - Classes to sync
 * @param {string} [svPathOverride] - Explicit SV path (overrides config)
 */
function syncToSavedVariables(config, classNames, svPathOverride) {
  const svPath = svPathOverride || config.paths.savedvariables;

  const aioDir = getAIODir(config);
  const templatePath = config.paths.template
    ? path.resolve(PROJECT_ROOT, config.paths.template)
    : null;

  if (!fs.existsSync(svPath)) {
    console.log(`[${timestamp()}] SavedVariables not found — creating from template: ${svPath}`);
    // Ensure parent directory exists
    const svDir = path.dirname(svPath);
    if (!fs.existsSync(svDir)) {
      fs.mkdirSync(svDir, { recursive: true });
    }
    // Seed from template
    const seedPath = templatePath || TEMPLATE_PATH;
    if (!fs.existsSync(seedPath)) {
      console.error(`[${timestamp()}] ERROR: Template not found: ${seedPath}`);
      return false;
    }
    fs.copyFileSync(seedPath, svPath);
  }

  const start = Date.now();
  const content = fs.readFileSync(svPath, 'utf8');
  const hasWindows = content.includes('\r\n');
  let lines = content.split(/\r?\n/);

  // Remove template placeholder profile (present when seeded from template)
  lines = removeProfile(lines, '__template__');
  lines = removeProfileKey(lines, '__template__');

  // Build set of valid profile names
  const validNames = new Set();
  for (const className of classNames) {
    validNames.add(getProfileName(className, config));
  }

  // Sync each class profile
  for (const className of classNames) {
    const profileName = getProfileName(className, config);
    const modules = discoverModules(className, aioDir);

    if (modules.length === 0) {
      console.log(`[${timestamp()}] Skipping ${className}: no modules found`);
      continue;
    }

    lines = syncProfile(lines, profileName, modules, templatePath);
    console.log(`[${timestamp()}] Synced: ${profileName} (${modules.length} modules, ${Date.now() - start}ms)`);
  }

  // Purge stale profiles
  lines = purgeStaleProfiles(lines, validNames, config);

  const output = lines.join(hasWindows ? '\r\n' : '\n');
  writeWithRetry(svPath, output);
  return true;
}

// ---------------------------------------------------------------------------
// Exports (for dev-watch)
// ---------------------------------------------------------------------------

module.exports = {
  discoverClasses,
  discoverModules,
  getProfileName,
  getAIODir,
  getSavedVariablesPaths,
  syncToSavedVariables,
  buildOutput,
  parseINI,
  timestamp,
  INI_PATH,
  PROJECT_ROOT,
};

// ---------------------------------------------------------------------------
// CLI Entry Point
// ---------------------------------------------------------------------------

if (require.main === module) {
  const args = new Set(process.argv.slice(2));
  const doSync = args.has('--sync') || args.has('--all');
  const doBuild = args.has('--build') || args.has('--all') || (!doSync);

  // Load config for path overrides, profile names, and SV sync
  let config = null;
  if (fs.existsSync(INI_PATH)) {
    config = parseINI(fs.readFileSync(INI_PATH, 'utf8'));
  }

  const aioDir = getAIODir(config);

  if (!fs.existsSync(aioDir)) {
    console.error(`Error: Source directory not found: ${aioDir}`);
    process.exit(1);
  }

  const allClasses = discoverClasses(aioDir);
  if (allClasses.length === 0) {
    console.error(`Error: No class directories found in ${aioDir}`);
    process.exit(1);
  }

  // Apply class exclusions from package.json (ignored by dev-watch.js)
  const pkgPath = path.join(PROJECT_ROOT, 'package.json');
  const pkg = fs.existsSync(pkgPath) ? JSON.parse(fs.readFileSync(pkgPath, 'utf8')) : {};
  const excludeClasses = pkg.excludeClasses || [];
  const classes = excludeClasses.length > 0
    ? allClasses.filter(c => !excludeClasses.includes(c))
    : allClasses;

  if (excludeClasses.length > 0) {
    const excluded = allClasses.filter(c => excludeClasses.includes(c));
    if (excluded.length > 0) {
      console.log(`Excluding classes: ${excluded.join(', ')}`);
    }
  }

  if (classes.length === 0) {
    console.error(`Error: All discovered classes were excluded`);
    process.exit(1);
  }

  const summary = classes.map(c => {
    const mods = discoverModules(c, aioDir);
    return `${c}: ${mods.length} modules`;
  }).join(', ');
  console.log(`Discovered ${classes.length} class(es): ${summary}\n`);

  if (doBuild) {
    console.log('--- Building distributable ---');
    buildOutput(classes, config);
  }

  if (doSync) {
    const svPaths = getSavedVariablesPaths(config);
    if (svPaths.length === 0) {
      console.error('Error: --sync requires dev.ini with [accounts] or [paths] savedvariables');
      console.error('Create dev.ini from dev.ini.example');
      process.exit(1);
    }
    console.log('\n--- Syncing to SavedVariables ---');
    for (const { name, svPath } of svPaths) {
      if (svPaths.length > 1) console.log(`\n  Account: ${name}`);
      syncToSavedVariables(config, classes, svPath);
    }
  }

  console.log('\nDone!');
}
