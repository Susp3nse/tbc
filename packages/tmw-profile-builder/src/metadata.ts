import type { BuildMetadata, MetadataInjection } from './types.js';

/**
 * The build number is an ephemeral per-session counter, not a persisted file or
 * a release version. The build/watch process owns it in memory: it starts at 0,
 * increments on each sync, and resets when the process restarts. Injected into
 * the compiled output (NS.BUILD_NUMBER), it lets you confirm in-game (after a
 * /reload) that your latest change actually loaded — if the number went up,
 * you're not looking at a stale sync.
 */
export function injectBuildMetadata(
  code: string,
  metadata: BuildMetadata | null | undefined,
  injection: MetadataInjection | undefined,
): string {
  if (!metadata || !injection || !code.startsWith(injection.marker)) return code;
  const generated = injection.template.replace(/\{build\}/g, String(metadata.build));
  return code.replace(injection.anchor, `${injection.anchor}\n${generated}`);
}
