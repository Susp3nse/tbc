/**
 * Thin ESM wrapper around @flux/tmw-profile-builder.
 */

import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import {
  createBuildContext,
  createRotationBuildApi,
  runCli,
} from '@flux/tmw-profile-builder';

const dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = process.env.ROTATION_ROOT || (
  path.basename(dirname) === 'dist' ? path.resolve(dirname, '..') : dirname
);

const context = createBuildContext({
  projectRoot,
  defaultExpansion: process.env.ROTATION_EXPANSION || 'tbc',
});

const api = createRotationBuildApi(context);

export const discoverClasses = api.discoverClasses;
export const discoverModules = api.discoverModules;
export const getProfileName = api.getProfileName;
export const getAIODir = api.getAIODir;
export const getSavedVariablesPaths = api.getSavedVariablesPaths;
export const syncToSavedVariables = api.syncToSavedVariables;
export const buildOutput = api.buildOutput;
export const readBuildMetadata = api.readBuildMetadata;
export const bumpBuildMetadata = api.bumpBuildMetadata;
export const parseINI = api.parseINI;
export const timestamp = api.timestamp;
export const INI_PATH = api.INI_PATH;
export const PROJECT_ROOT = api.PROJECT_ROOT;

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runCli(context);
}
