/**
 * Thin ESM wrapper around @menagerie/tmw-profile-builder dev watch. Run directly
 * via tsx (see this app's package.json scripts).
 */

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createBuildContext, runDevWatch } from '@menagerie/tmw-profile-builder';

const projectRoot = path.dirname(fileURLToPath(import.meta.url));
const context = createBuildContext({ projectRoot });

runDevWatch(context);
