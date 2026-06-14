/**
 * Thin ESM wrapper around @menagerie/tmw-profile-builder. Run directly via tsx
 * (see this app's package.json scripts); it builds against its own directory.
 */

import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { createBuildContext, runCli } from '@menagerie/tmw-profile-builder';

const projectRoot = path.dirname(fileURLToPath(import.meta.url));
const context = createBuildContext({ projectRoot });

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runCli(context);
}
