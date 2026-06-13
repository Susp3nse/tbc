import fs from 'node:fs';
import type { BuildContext, BuildMetadata } from './types.js';

export function readBuildMetadata(context: BuildContext): BuildMetadata {
  const fallback = { build: 0 };
  if (!fs.existsSync(context.buildVersionPath)) return fallback;

  try {
    const parsed = JSON.parse(fs.readFileSync(context.buildVersionPath, 'utf8'));
    return {
      build: Number.isInteger(parsed.build) ? parsed.build : fallback.build,
    };
  } catch (err) {
    console.warn(`  WARNING: Could not read build-version.json (${err.message}); using build ${fallback.build}`);
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

export function injectBuildMetadata(code: string, metadata?: BuildMetadata | null): string {
  if (!metadata || !code.startsWith('-- Flux AIO - Core Module')) return code;
  const generated = [
    `NS.BUILD_NUMBER = ${metadata.build}`,
    `NS.BUILD_LABEL = "#${metadata.build}"`,
  ].join('\n');
  return code.replace('local NS = _G.FluxAIO', `local NS = _G.FluxAIO\n${generated}`);
}
