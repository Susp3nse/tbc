import fs from 'node:fs';
import path from 'node:path';
import type { BuildContext, LocalConfig, SavedVariablesTarget } from './types.js';

/**
 * Read the gitignored local config (builder.config.local.json) holding this
 * machine's sync targets and any per-class profile-name overrides. Returns
 * null when absent — a plain `build` does not require it.
 */
export function readLocalConfig(context: BuildContext): LocalConfig | null {
  if (!fs.existsSync(context.localConfigPath)) return null;
  return JSON.parse(fs.readFileSync(context.localConfigPath, 'utf8')) as LocalConfig;
}

export function getAIODir(context: BuildContext, config?: LocalConfig | null): string {
  if (config?.paths?.watchdir) {
    return path.resolve(context.projectRoot, config.paths.watchdir);
  }
  return context.aioDir;
}

export function getSavedVariablesPaths(config?: LocalConfig | null): SavedVariablesTarget[] {
  if (config?.accounts) {
    const entries = Object.entries(config.accounts);
    if (entries.length > 0) {
      return entries.map(([name, svPath]) => ({ name, svPath }));
    }
  }

  if (config?.paths?.savedvariables) {
    return [{ name: 'default', svPath: config.paths.savedvariables }];
  }

  return [];
}
