import type { BuildConventions, IniConfig } from './types.js';
import { getProfileName } from './discovery.js';
import { listProfileNames, removeProfile, removeProfileKey } from './tmw-profile.js';

export function purgeStaleProfiles(
  lines: string[],
  validNames: Set<string>,
  conventions: BuildConventions,
  config?: IniConfig | null,
): string[] {
  const allNames = listProfileNames(lines);
  let result = lines;

  for (const name of allNames) {
    if (name === conventions.templateProfileKey) continue;
    if (validNames.has(name)) continue;

    const isManaged =
      name.startsWith(conventions.profileNamePrefix) ||
      Boolean(config?.profiles && Object.values(config.profiles).includes(name));

    if (!isManaged) continue;

    console.log(`  Purging stale profile: "${name}"`);
    result = removeProfile(result, name);
    result = removeProfileKey(result, name);
  }

  return result;
}

export function buildValidProfileNames(
  classNames: string[],
  conventions: BuildConventions,
  config?: IniConfig | null,
): Set<string> {
  const validNames = new Set<string>();
  for (const className of classNames) {
    validNames.add(getProfileName(className, conventions, config));
  }
  return validNames;
}
