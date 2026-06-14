import fs from 'node:fs';
import path from 'node:path';
import type { BuildContext, BuildConventions, BuilderPaths } from './types.js';

/** The shape of builder.config.json: naming/load-order conventions plus root-relative paths. */
type BuilderConfigFile = BuildConventions & { paths?: BuilderPaths };

/**
 * Build a BuildContext by loading the project's builder.config.json.
 *
 * This package is content-agnostic: it ships no naming/load-order/path defaults.
 * The consuming app owns builder.config.json (see apps/tbc-rotation/builder.config.json);
 * the package only reads it. `configPath` overrides the default <projectRoot>/builder.config.json.
 */
export function createBuildContext(options: {
  projectRoot: string;
  configPath?: string;
}): BuildContext {
  const projectRoot = options.projectRoot;
  const configPath = options.configPath ?? path.join(projectRoot, 'builder.config.json');

  if (!fs.existsSync(configPath)) {
    throw new Error(`Builder config not found: ${configPath}`);
  }

  const { paths = {}, ...conventions } = JSON.parse(
    fs.readFileSync(configPath, 'utf8'),
  ) as BuilderConfigFile;
  const resolve = (rel: string | undefined, fallback: string) =>
    path.join(projectRoot, rel ?? fallback);

  // Release version comes from the app's package.json — the single source of the in-game label.
  const pkgPath = path.join(projectRoot, 'package.json');
  const version = fs.existsSync(pkgPath)
    ? ((JSON.parse(fs.readFileSync(pkgPath, 'utf8')).version as string | undefined) ?? '')
    : '';

  return {
    projectRoot,
    aioDir: resolve(paths.aioDir, 'src/aio'),
    templatePath: resolve(paths.template, 'tmw-template.lua'),
    outputPath: resolve(paths.output, 'output/TellMeWhen.lua'),
    localConfigPath: resolve(paths.local, 'builder.config.local.json'),
    conventions,
    version,
  };
}
