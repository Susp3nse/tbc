import type { BuildMetadata, MetadataInjection } from './types.js';

/**
 * Injects two distinct stamps into the marked module (both via the same anchor):
 *
 * - `{version}` → the release version from the app's package.json (NS.VERSION). This is the
 *   single source of the in-game version label; it is present on every build.
 * - `{build}` → an ephemeral per-session counter (NS.BUILD_NUMBER), not a persisted file or a
 *   release version. The build/watch process owns it in memory: it starts at 0, increments on each
 *   sync, and resets when the process restarts. After a /reload it lets you confirm your latest
 *   change actually loaded — if the number went up, you're not looking at a stale sync.
 */
export function injectBuildMetadata(
  code: string,
  metadata: BuildMetadata | null | undefined,
  injection: MetadataInjection | undefined,
): string {
  if (!metadata || !injection || !code.startsWith(injection.marker)) return code;
  const generated = injection.template
    .replace(/\{build\}/g, String(metadata.build))
    .replace(/\{version\}/g, metadata.version ?? '');
  return code.replace(injection.anchor, `${injection.anchor}\n${generated}`);
}
