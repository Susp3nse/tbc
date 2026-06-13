import path from 'node:path';
import type { BuildContext } from './types.js';

export function createBuildContext(options: { projectRoot: string; defaultExpansion?: string }): BuildContext {
  const defaultExpansion = options.defaultExpansion || process.env.ROTATION_EXPANSION || 'tbc';
  const projectRoot = options.projectRoot;

  return {
    projectRoot,
    defaultExpansion,
    defaultAioDir: path.join(projectRoot, 'src', defaultExpansion, 'aio'),
    templatePath: path.join(projectRoot, 'tmw-template.lua'),
    outputPath: path.join(projectRoot, 'output', 'TellMeWhen.lua'),
    iniPath: path.join(projectRoot, 'dev.ini'),
    buildVersionPath: path.join(projectRoot, 'build-version.json'),
  };
}
