import type { IniConfig } from './types.js';
import { getProfileName } from './discovery.js';
import { listProfileNames, removeProfile, removeProfileKey } from './tmw-profile.js';

export function purgeStaleProfiles(lines: string[], validNames: Set<string>, config?: IniConfig | null): string[] {
  const allNames = listProfileNames(lines);
  let result = lines;

  for (const name of allNames) {
    if (name === '__template__') continue;
    if (validNames.has(name)) continue;

    const isManaged = name.startsWith('Flux ')
      || Boolean(config?.profiles && Object.values(config.profiles).includes(name));

    if (!isManaged) continue;

    console.log(`  Purging stale profile: "${name}"`);
    result = removeProfile(result, name);
    result = removeProfileKey(result, name);
  }

  return result;
}

export function buildValidProfileNames(classNames: string[], config?: IniConfig | null): Set<string> {
  const validNames = new Set<string>();
  for (const className of classNames) {
    validNames.add(getProfileName(className, config));
  }
  return validNames;
}
