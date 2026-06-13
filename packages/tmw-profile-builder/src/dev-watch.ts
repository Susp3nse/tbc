import fs from 'node:fs';
import type { BuildContext, IniConfig, SavedVariablesTarget, WatchOptions } from './types.js';
import { RotationBuilder } from './tmw-profile-builder.js';

const DEFAULT_SOURCE_DEBOUNCE_MS = 300;
const DEFAULT_SAVED_VARIABLES_DEBOUNCE_MS = 500;
const DEFAULT_OUR_WRITE_COOLDOWN_MS = 2000;

export class DevWatcher {
  private readonly sourceDebounceMs: number;
  private readonly savedVariablesDebounceMs: number;
  private readonly ourWriteCooldownMs: number;
  private readonly builder: RotationBuilder;
  private readonly lastOurWriteTime = new Map<string, number>();
  private readonly pendingChanges = new Set<string>();
  private sourceDebounceTimer: NodeJS.Timeout | null = null;
  private classes: string[] = [];

  constructor(
    private readonly context: BuildContext,
    options: WatchOptions = {},
  ) {
    this.builder = new RotationBuilder(context);
    this.sourceDebounceMs = options.sourceDebounceMs ?? DEFAULT_SOURCE_DEBOUNCE_MS;
    this.savedVariablesDebounceMs = options.savedVariablesDebounceMs ?? DEFAULT_SAVED_VARIABLES_DEBOUNCE_MS;
    this.ourWriteCooldownMs = options.ourWriteCooldownMs ?? DEFAULT_OUR_WRITE_COOLDOWN_MS;
  }

  run(): void {
    const config = this.readConfig();
    const savedVariablesTargets = this.resolveSavedVariablesTargets(config);
    const aioDir = this.builder.getAIODir(config);

    this.classes = this.resolveInitialClasses(aioDir);
    this.logStartup(aioDir, savedVariablesTargets);
    this.syncAndMark(config, savedVariablesTargets, this.classes);

    fs.watch(aioDir, { recursive: true }, (_eventType, filename) => {
      this.handleSourceChange(config, savedVariablesTargets, aioDir, filename);
    });

    for (const target of savedVariablesTargets) {
      this.watchSavedVariables(config, target, savedVariablesTargets.length);
    }

    console.log(`[${this.builder.timestamp()}] Watching for changes... (Ctrl+C to stop)`);
    for (const { name } of savedVariablesTargets) {
      const label = savedVariablesTargets.length > 1 ? ` [${name}]` : '';
      console.log(`[${this.builder.timestamp()}] Watching SavedVariables${label} for external changes (e.g. /reload)`);
    }
  }

  private readConfig(): IniConfig {
    if (!fs.existsSync(this.context.iniPath)) {
      console.error('Error: dev.ini not found in project root.');
      console.error('');
      console.error('Create dev.ini from the example:');
      console.error('  cp dev.ini.example dev.ini');
      console.error('');
      console.error('Then edit it with your SavedVariables path(s).');
      process.exit(1);
    }

    return this.builder.parseINI(fs.readFileSync(this.context.iniPath, 'utf8'));
  }

  private resolveSavedVariablesTargets(config: IniConfig): SavedVariablesTarget[] {
    const targets = this.builder.getSavedVariablesPaths(config);
    if (targets.length > 0) return targets;

    console.error('Error: dev.ini has no SavedVariables paths.');
    console.error('Add an [accounts] section or set [paths] savedvariables.');
    process.exit(1);
  }

  private resolveInitialClasses(aioDir: string): string[] {
    const classes = this.builder.discoverClasses(aioDir);
    if (classes.length === 0) {
      console.error(`Error: No class directories found in ${aioDir}`);
      process.exit(1);
    }
    return classes;
  }

  private logStartup(aioDir: string, targets: SavedVariablesTarget[]): void {
    const classSummary = this.classes.map((className) => {
      const modules = this.builder.discoverModules(className, aioDir);
      return `${className}: ${modules.length} modules`;
    }).join(', ');

    const accountSummary = targets.map((target) => target.name).join(', ');
    console.log(`[${this.builder.timestamp()}] Watching ${aioDir} - ${this.classes.length} class(es) (${classSummary})`);
    console.log(`[${this.builder.timestamp()}] Syncing to ${targets.length} account(s): ${accountSummary}`);
  }

  private syncAndMark(config: IniConfig, targets: SavedVariablesTarget[], classNames: string[]): void {
    for (const { name, svPath } of targets) {
      if (targets.length > 1) {
        console.log(`[${this.builder.timestamp()}] Syncing account: ${name}`);
      }
      this.builder.syncToSavedVariables(config, classNames, svPath);
      this.lastOurWriteTime.set(svPath, Date.now());
    }
  }

  private handleSourceChange(
    config: IniConfig,
    targets: SavedVariablesTarget[],
    aioDir: string,
    filename: string | Buffer | null,
  ): void {
    if (typeof filename !== 'string' || !filename.endsWith('.lua')) return;

    this.pendingChanges.add(filename);

    if (this.sourceDebounceTimer) clearTimeout(this.sourceDebounceTimer);
    this.sourceDebounceTimer = setTimeout(() => {
      this.flushSourceChanges(config, targets, aioDir);
    }, this.sourceDebounceMs);
  }

  private flushSourceChanges(config: IniConfig, targets: SavedVariablesTarget[], aioDir: string): void {
    const changes = [...this.pendingChanges];
    this.pendingChanges.clear();
    this.sourceDebounceTimer = null;

    const affectedClasses = new Set<string>();
    let isShared = false;

    for (const file of changes) {
      const normalized = file.replace(/\\/g, '/');
      const parts = normalized.split('/');

      if (parts.length === 1) {
        isShared = true;
        console.log(`[${this.builder.timestamp()}] Changed: ${file} (shared)`);
      } else {
        affectedClasses.add(parts[0]);
        console.log(`[${this.builder.timestamp()}] Changed: ${parts.join('/')}`);
      }
    }

    const currentClasses = this.builder.discoverClasses(aioDir);
    for (const className of currentClasses) {
      if (!this.classes.includes(className)) {
        this.classes.push(className);
        affectedClasses.add(className);
        console.log(`[${this.builder.timestamp()}] [NEW CLASS] Detected ${className}/ - creating profile`);
      }
    }

    if (isShared || affectedClasses.size > 0) {
      this.syncAndMark(config, targets, this.classes);
    }
  }

  private watchSavedVariables(config: IniConfig, target: SavedVariablesTarget, targetCount: number): void {
    let savedVariablesDebounceTimer: NodeJS.Timeout | null = null;

    const handleSavedVariablesChange = () => {
      if (Date.now() - (this.lastOurWriteTime.get(target.svPath) || 0) < this.ourWriteCooldownMs) return;

      if (savedVariablesDebounceTimer) clearTimeout(savedVariablesDebounceTimer);
      savedVariablesDebounceTimer = setTimeout(() => {
        savedVariablesDebounceTimer = null;

        if (Date.now() - (this.lastOurWriteTime.get(target.svPath) || 0) < this.ourWriteCooldownMs) return;
        if (!fs.existsSync(target.svPath)) return;

        const label = targetCount > 1 ? ` (${target.name})` : '';
        console.log(`[${this.builder.timestamp()}] [RELOAD] SavedVariables overwritten externally${label} - re-syncing all classes`);
        this.builder.syncToSavedVariables(config, this.classes, target.svPath);
        this.lastOurWriteTime.set(target.svPath, Date.now());
      }, this.savedVariablesDebounceMs);
    };

    fs.watchFile(target.svPath, { interval: 1000 }, (current, previous) => {
      if (current.mtimeMs !== previous.mtimeMs) {
        handleSavedVariablesChange();
      }
    });
  }
}

export function runDevWatch(context: BuildContext, options?: WatchOptions): void {
  new DevWatcher(context, options).run();
}
