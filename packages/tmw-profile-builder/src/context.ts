import path from 'node:path';
import type { BuildContext, BuildConventions } from './types.js';

/** Default conventions. These reproduce the historical Flux AIO build behavior exactly. */
export const DEFAULT_CONVENTIONS: BuildConventions = {
  modulePrefix: 'Flux_',
  profileNamePrefix: 'Flux ',
  nameOverrides: { ui: 'UI' },
  defaultModuleOrder: 7,
  templateProfileKey: '__template__',
  loadOrder: [
    { slot: 'shared', source: 'common.lua', order: 1 },
    { slot: 'class', source: 'schema.lua', order: 2 },
    { slot: 'shared', source: 'ui.lua', order: 3 },
    { slot: 'shared', source: 'core.lua', order: 4 },
    { slot: 'class', source: 'class.lua', order: 5 },
    { slot: 'class', source: 'healing.lua', order: 6 },
    { slot: 'shared', source: 'settings.lua', order: 6 },
    { slot: 'class', source: 'middleware.lua', order: 7 },
    { slot: 'shared', source: 'dashboard.lua', order: 8 },
    { slot: 'shared', source: 'main.lua', order: 9 },
  ],
  metadata: {
    marker: '-- Flux AIO - Core Module',
    anchor: 'local NS = _G.FluxAIO',
    render: (build) => [`NS.BUILD_NUMBER = ${build}`, `NS.BUILD_LABEL = "#${build}"`].join('\n'),
  },
};

export function createBuildContext(options: {
  projectRoot: string;
  conventions?: Partial<BuildConventions>;
}): BuildContext {
  const projectRoot = options.projectRoot;

  return {
    projectRoot,
    aioDir: path.join(projectRoot, 'src', 'aio'),
    templatePath: path.join(projectRoot, 'tmw-template.lua'),
    outputPath: path.join(projectRoot, 'output', 'TellMeWhen.lua'),
    iniPath: path.join(projectRoot, 'dev.ini'),
    buildVersionPath: path.join(projectRoot, 'build-version.json'),
    conventions: { ...DEFAULT_CONVENTIONS, ...options.conventions },
  };
}
