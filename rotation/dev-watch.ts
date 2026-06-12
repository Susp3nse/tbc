/**
 * Dev Watcher — Watches for .lua changes and rebuilds on change
 *
 * Thin file watcher that delegates all build logic to build.ts.
 * Detects .lua file changes, determines affected classes, and triggers
 * a sync to TellMeWhen SavedVariables.
 *
 * Supports multiple WoW accounts via [accounts] section in dev.ini.
 * Falls back to single [paths] savedvariables for backward compat.
 *
 * Also watches the SavedVariables file(s). When the game overwrites
 * them (e.g. on /reload), re-syncs our code immediately.
 *
 * Usage: corepack pnpm --filter @flux/rotation watch
 *
 * Requires dev.ini in project root (see dev.ini.example).
 */

const fs = require('fs');

const build = require('./build');

const { INI_PATH } = build;

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

if (!fs.existsSync(INI_PATH)) {
  console.error('Error: dev.ini not found in project root.');
  console.error('');
  console.error('Create dev.ini from the example:');
  console.error('  cp dev.ini.example dev.ini');
  console.error('');
  console.error('Then edit it with your SavedVariables path(s).');
  process.exit(1);
}

const config = build.parseINI(fs.readFileSync(INI_PATH, 'utf8'));

const svAccounts = build.getSavedVariablesPaths(config);
if (svAccounts.length === 0) {
  console.error('Error: dev.ini has no SavedVariables paths.');
  console.error('Add an [accounts] section or set [paths] savedvariables.');
  process.exit(1);
}

const aioDir = build.getAIODir(config);

// ---------------------------------------------------------------------------
// Write Tracking — distinguish our writes from game writes (per SV path)
// ---------------------------------------------------------------------------

const lastOurWriteTime = {};  // svPath → timestamp
const OUR_WRITE_COOLDOWN_MS = 2000;

/** Wrapper that syncs all accounts and marks writes as "ours". */
function syncAndMark(classNames) {
  for (const { name, svPath } of svAccounts) {
    if (svAccounts.length > 1) {
      console.log(`[${build.timestamp()}] Syncing account: ${name}`);
    }
    build.syncToSavedVariables(config, classNames, svPath);
    lastOurWriteTime[svPath] = Date.now();
  }
}

// ---------------------------------------------------------------------------
// Initial State
// ---------------------------------------------------------------------------

let classes = build.discoverClasses(aioDir);
if (classes.length === 0) {
  console.error(`Error: No class directories found in ${aioDir}`);
  process.exit(1);
}

const classSummary = classes.map(c => {
  const mods = build.discoverModules(c, aioDir);
  return `${c}: ${mods.length} modules`;
}).join(', ');

const accountSummary = svAccounts.map(a => a.name).join(', ');
console.log(`[${build.timestamp()}] Watching ${aioDir} — ${classes.length} class(es) (${classSummary})`);
console.log(`[${build.timestamp()}] Syncing to ${svAccounts.length} account(s): ${accountSummary}`);

// Initial full sync
syncAndMark(classes);

// ---------------------------------------------------------------------------
// Source File Watcher
// ---------------------------------------------------------------------------

let debounceTimer = null;
let pendingChanges = new Set<string>();

function handleChange(_eventType, filename) {
  if (typeof filename !== 'string' || !filename.endsWith('.lua')) return;

  pendingChanges.add(filename);

  if (debounceTimer) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    const changes = [...pendingChanges];
    pendingChanges.clear();
    debounceTimer = null;

    // Determine which classes need rebuild
    const affectedClasses = new Set();
    let isShared = false;

    for (const file of changes) {
      const normalized = file.replace(/\\/g, '/');
      const parts = normalized.split('/');

      if (parts.length === 1) {
        isShared = true;
        console.log(`[${build.timestamp()}] Changed: ${file} (shared)`);
      } else {
        affectedClasses.add(parts[0]);
        console.log(`[${build.timestamp()}] Changed: ${parts.join('/')}`);
      }
    }

    // Check for new class directories
    const currentClasses = build.discoverClasses(aioDir);
    for (const c of currentClasses) {
      if (!classes.includes(c)) {
        classes.push(c);
        affectedClasses.add(c);
        console.log(`[${build.timestamp()}] [NEW CLASS] Detected ${c}/ — creating profile`);
      }
    }

    // syncToSavedVariables purges Flux profiles not included in classNames, so
    // always sync the full class set even when the source change is class-local.
    if (isShared || affectedClasses.size > 0) {
      syncAndMark(classes);
    }
  }, 300);
}

fs.watch(aioDir, { recursive: true }, handleChange);

// ---------------------------------------------------------------------------
// SavedVariables Watcher — re-sync after game overwrites (e.g. /reload)
// ---------------------------------------------------------------------------

for (const { name, svPath } of svAccounts) {
  let svDebounceTimer = null;

  function handleSVChange() {
    // Ignore changes we just caused
    if (Date.now() - (lastOurWriteTime[svPath] || 0) < OUR_WRITE_COOLDOWN_MS) return;

    if (svDebounceTimer) clearTimeout(svDebounceTimer);
    svDebounceTimer = setTimeout(() => {
      svDebounceTimer = null;

      // Double-check the cooldown (might have been set during debounce wait)
      if (Date.now() - (lastOurWriteTime[svPath] || 0) < OUR_WRITE_COOLDOWN_MS) return;

      if (!fs.existsSync(svPath)) return;

      const label = svAccounts.length > 1 ? ` (${name})` : '';
      console.log(`[${build.timestamp()}] [RELOAD] SavedVariables overwritten externally${label} — re-syncing all classes`);
      build.syncToSavedVariables(config, classes, svPath);
      lastOurWriteTime[svPath] = Date.now();
    }, 500);
  }

  // fs.watchFile uses polling — more reliable than fs.watch for files modified
  // by external programs (especially games that do atomic write-replace).
  fs.watchFile(svPath, { interval: 1000 }, (curr, prev) => {
    if (curr.mtimeMs !== prev.mtimeMs) {
      handleSVChange();
    }
  });
}

console.log(`[${build.timestamp()}] Watching for changes... (Ctrl+C to stop)`);
for (const { name } of svAccounts) {
  const label = svAccounts.length > 1 ? ` [${name}]` : '';
  console.log(`[${build.timestamp()}] Watching SavedVariables${label} for external changes (e.g. /reload)`);
}
