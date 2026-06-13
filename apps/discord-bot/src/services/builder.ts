import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { execFile } from 'child_process';
import { promisify } from 'util';
import { config } from '../config.js';

const execFileAsync = promisify(execFile);
const TEMP_PREFIX = 'flux-bot-';

export async function createWorkspace() {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), TEMP_PREFIX));

  const rotRoot = config.rotationRoot;
  const repoRoot = path.resolve(rotRoot, '..', '..');
  const profileBuilderRoot = path.join(repoRoot, 'packages', 'tmw-profile-builder');
  const tempProfileBuilderRoot = path.join(tempDir, 'node_modules', '@flux', 'tmw-profile-builder');

  await fs.cp(
    path.join(rotRoot, 'src', 'tbc', 'aio'),
    path.join(tempDir, 'src', 'tbc', 'aio'),
    { recursive: true },
  );
  await fs.copyFile(
    path.join(rotRoot, 'dist', 'build.js'),
    path.join(tempDir, 'build.js'),
  );
  await fs.copyFile(
    path.join(rotRoot, 'tmw-template.lua'),
    path.join(tempDir, 'tmw-template.lua'),
  );
  await fs.copyFile(
    path.join(rotRoot, 'package.json'),
    path.join(tempDir, 'package.json'),
  );
  await fs.mkdir(tempProfileBuilderRoot, { recursive: true });
  await fs.cp(
    path.join(profileBuilderRoot, 'dist'),
    path.join(tempProfileBuilderRoot, 'dist'),
    { recursive: true },
  );
  await fs.copyFile(
    path.join(profileBuilderRoot, 'package.json'),
    path.join(tempProfileBuilderRoot, 'package.json'),
  );
  await fs.mkdir(path.join(tempDir, 'output'), { recursive: true });

  return tempDir;
}

export async function runBuild(workDir) {
  try {
    const { stdout, stderr } = await execFileAsync(
      process.execPath,
      [path.join(workDir, 'build.js')],
      {
        cwd: workDir,
        env: { ...process.env, ROTATION_ROOT: workDir },
        timeout: 30_000,
      },
    );

    const outputPath = path.join(workDir, 'output', 'TellMeWhen.lua');
    try {
      await fs.access(outputPath);
    } catch {
      return { success: false, error: `Build ran but output not found.\n${stderr || stdout}` };
    }

    return { success: true, outputPath };
  } catch (err) {
    return { success: false, error: `Build failed: ${err.message}${err.stderr ? '\n' + err.stderr : ''}` };
  }
}

export async function cleanup(workDir) {
  try {
    await fs.rm(workDir, { recursive: true, force: true });
  } catch (err) {
    console.error(`Cleanup failed for ${path.basename(workDir)}: ${err.message}`);
  }
}

export async function cleanupStaleWorkspaces() {
  const tmpDir = os.tmpdir();
  try {
    const entries = await fs.readdir(tmpDir);
    const stale = entries.filter(e => e.startsWith(TEMP_PREFIX));
    const oneHourAgo = Date.now() - 3_600_000;

    for (const entry of stale) {
      const fullPath = path.join(tmpDir, entry);
      try {
        const stat = await fs.stat(fullPath);
        if (stat.mtimeMs < oneHourAgo) {
          await fs.rm(fullPath, { recursive: true, force: true });
          console.log(`Cleaned up stale workspace: ${entry}`);
        }
      } catch { /* already gone */ }
    }
  } catch { /* tmpdir read failed, not critical */ }
}
