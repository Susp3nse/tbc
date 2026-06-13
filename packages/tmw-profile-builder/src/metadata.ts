import fs from 'node:fs';
import type { BuildContext, BuildMetadata, MetadataInjection } from './types.js';

export function readBuildMetadata(context: BuildContext): BuildMetadata {
  const fallback = { build: 0 };
  if (!fs.existsSync(context.buildVersionPath)) return fallback;

  try {
    const parsed = JSON.parse(fs.readFileSync(context.buildVersionPath, 'utf8'));
    return {
      build: Number.isInteger(parsed.build) ? parsed.build : fallback.build,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.warn(
      `  WARNING: Could not read build-version.json (${message}); using build ${fallback.build}`,
    );
    return fallback;
  }
}

export function writeBuildMetadata(context: BuildContext, metadata: BuildMetadata): void {
  fs.writeFileSync(context.buildVersionPath, `${JSON.stringify(metadata, null, 2)}\n`, 'utf8');
}

export function bumpBuildMetadata(context: BuildContext): BuildMetadata {
  const metadata = readBuildMetadata(context);
  const next = { ...metadata, build: metadata.build + 1 };
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
