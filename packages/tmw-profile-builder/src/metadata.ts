import fs from 'node:fs';
import type { BuildContext, BuildMetadata, MetadataInjection } from './types.js';

/**
 * The build counter (build-version.json) is a LOCAL DEV aid, kept deliberately
 * separate from the hand-edited builder.config.local.json so the tool never
 * rewrites your config. It bumps on every build/sync and is injected into the
 * compiled output (NS.BUILD_NUMBER), so after a /reload in-game you can confirm
 * the latest code actually loaded — if the number went up, you're not stale.
 * Gitignored; NOT a release/semver version. Resetting it is harmless.
 */

const BUILD_VERSION_COMMENT =
  'Local build counter — bumps every build/sync so you can verify in-game (/reload) that the latest code loaded. Gitignored; not a release version. Safe to reset.';

export function readBuildMetadata(context: BuildContext): BuildMetadata {
  const fallback = { build: 0 };
  if (!fs.existsSync(context.buildVersionPath)) return fallback;

  try {
    const parsed = JSON.parse(fs.readFileSync(context.buildVersionPath, 'utf8'));
    return { build: Number.isInteger(parsed.build) ? parsed.build : fallback.build };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.warn(
      `  WARNING: Could not read build-version.json (${message}); using build ${fallback.build}`,
    );
    return fallback;
  }
}

export function writeBuildMetadata(context: BuildContext, metadata: BuildMetadata): void {
  const body = { _comment: BUILD_VERSION_COMMENT, build: metadata.build };
  fs.writeFileSync(context.buildVersionPath, `${JSON.stringify(body, null, 2)}\n`, 'utf8');
}

export function bumpBuildMetadata(context: BuildContext): BuildMetadata {
  const next = { build: readBuildMetadata(context).build + 1 };
  writeBuildMetadata(context, next);
  return next;
}

export function injectBuildMetadata(
  code: string,
  metadata: BuildMetadata | null | undefined,
  injection: MetadataInjection | undefined,
): string {
  if (!metadata || !injection || !code.startsWith(injection.marker)) return code;
  const generated = injection.template.replace(/\{build\}/g, String(metadata.build));
  return code.replace(injection.anchor, `${injection.anchor}\n${generated}`);
}
