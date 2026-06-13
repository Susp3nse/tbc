import path from 'node:path';
import type { BuildContext, IniConfig, SavedVariablesTarget } from './types.js';

export function parseINI(text: string): IniConfig {
  const result: IniConfig = {};
  let section = '';

  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line[0] === ';' || line[0] === '#') continue;

    const secMatch = line.match(/^\[(.+)\]$/);
    if (secMatch) {
      section = secMatch[1];
      result[section] = result[section] || {};
      continue;
    }

    const kvMatch = line.match(/^([^=]+)=(.*)$/);
    if (kvMatch && section) {
      result[section][kvMatch[1].trim()] = kvMatch[2].trim();
    }
  }

  return result;
}

export function getAIODir(context: BuildContext, config?: IniConfig | null): string {
  if (config?.paths?.watchdir) {
    return path.resolve(context.projectRoot, config.paths.watchdir);
  }
  return context.aioDir;
}

export function getSavedVariablesPaths(config?: IniConfig | null): SavedVariablesTarget[] {
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
