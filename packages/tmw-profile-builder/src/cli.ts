import childProcess from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import type { BuildContext, IniConfig } from './types.js';
import { ProfileBuilder } from './tmw-profile-builder.js';
import { getSavedVariablesPaths } from './ini.js';

function isWowRunning(): boolean {
  if (process.platform !== 'win32') return false;
  try {
    const output = childProcess.execFileSync('tasklist', {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    return /(^|\r?\n)\s*(Wow|WowClassic|World of Warcraft)\.exe\s/i.test(output);
  } catch {
    return false;
  }
}

function resolveClasses(builder: ProfileBuilder, config: IniConfig | null): string[] {
  const aioDir = builder.getAIODir(config);

  if (!fs.existsSync(aioDir)) {
    throw new Error(`Source directory not found: ${aioDir}`);
  }

  const allClasses = builder.discoverClasses(aioDir);
  if (allClasses.length === 0) {
    throw new Error(`No class directories found in ${aioDir}`);
  }

  const pkgPath = path.join(builder.projectRoot, 'package.json');
  const pkg = fs.existsSync(pkgPath) ? JSON.parse(fs.readFileSync(pkgPath, 'utf8')) : {};
  const excludeClasses = pkg.excludeClasses || [];
  const classes =
    excludeClasses.length > 0
      ? allClasses.filter((className) => !excludeClasses.includes(className))
      : allClasses;

  if (excludeClasses.length > 0) {
    const excluded = allClasses.filter((className) => excludeClasses.includes(className));
    if (excluded.length > 0) {
      console.log(`Excluding classes: ${excluded.join(', ')}`);
    }
  }

  if (classes.length === 0) {
    throw new Error('All discovered classes were excluded');
  }

  const summary = classes
    .map((className) => {
      const mods = builder.discoverModules(className, aioDir);
      return `${className}: ${mods.length} modules`;
    })
    .join(', ');
  console.log(`Discovered ${classes.length} class(es): ${summary}\n`);

  return classes;
}

export function runCli(context: BuildContext, argv = process.argv.slice(2)): void {
  const builder = new ProfileBuilder(context);
  const args = new Set(argv);
  const doSync = args.has('--sync') || args.has('--all');
  const doBuild = args.has('--build') || args.has('--all') || !doSync;

  let config: IniConfig | null = null;
  if (fs.existsSync(context.iniPath)) {
    config = builder.parseINI(fs.readFileSync(context.iniPath, 'utf8'));
  }

  let classes: string[];
  try {
    classes = resolveClasses(builder, config);
  } catch (err) {
    console.error(`Error: ${err instanceof Error ? err.message : String(err)}`);
    process.exit(1);
  }

  if (doBuild) {
    console.log('--- Building distributable ---');
    builder.buildOutput(classes, config);
  }

  if (doSync) {
    const svPaths = getSavedVariablesPaths(config);
    if (svPaths.length === 0) {
      console.error('Error: --sync requires dev.ini with [accounts] or [paths] savedvariables');
      console.error('Create dev.ini from dev.ini.example');
      process.exit(1);
    }

    console.log('\n--- Syncing to SavedVariables ---');
    if (isWowRunning()) {
      console.log('  WARNING: World of Warcraft appears to be running.');
      console.log(
        '  SavedVariables are loaded from disk at startup; /reload may overwrite external sync changes with in-memory addon data.',
      );
    }

    let syncFailed = false;
    for (const { name, svPath } of svPaths) {
      if (svPaths.length > 1) console.log(`\n  Account: ${name}`);
      if (!builder.syncToSavedVariables(config || {}, classes, svPath)) {
        syncFailed = true;
      }
    }
    if (syncFailed) process.exit(1);
  }

  console.log('\nDone!');
}
