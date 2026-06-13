/**
 * Thin ESM wrapper around @flux/tmw-profile-builder dev watch.
 */

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createBuildContext, runDevWatch } from '@flux/tmw-profile-builder';

const dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot =
  process.env.ROTATION_ROOT ||
  (path.basename(dirname) === 'dist' ? path.resolve(dirname, '..') : dirname);

const context = createBuildContext({ projectRoot });

runDevWatch(context);
