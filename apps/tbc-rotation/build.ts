/**
 * Thin ESM wrapper around @flux/tmw-profile-builder.
 *
 * Runs the build/sync CLI. The discord-bot invokes the compiled `dist/build.js`
 * directly with ROTATION_ROOT pointed at a temp workspace.
 */

import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { createBuildContext, runCli } from '@flux/tmw-profile-builder';

const dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot =
  process.env.ROTATION_ROOT ||
  (path.basename(dirname) === 'dist' ? path.resolve(dirname, '..') : dirname);

const context = createBuildContext({ projectRoot });

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runCli(context);
}
