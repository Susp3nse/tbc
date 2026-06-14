#!/usr/bin/env tsx
/**
 * publish.ts — finalize a prepared release (the irreversible half of the flow).
 *
 * Run AFTER `pnpm release` (which bumps apps/tbc-rotation/package.json + scaffolds the changelog)
 * and AFTER you've curated the changelog prose. This wraps the commands you'd otherwise type by
 * hand: validate → build → commit → tag → push. The annotated tag triggers release.yml, which
 * publishes the GitHub Release + Discord notification from the changelog entry.
 *
 * The version is read from package.json — there is nothing to pass; whatever `pnpm release` bumped
 * to is what gets tagged.
 *
 *   pnpm release:publish            # validate → build → confirm → commit → tag → push
 *   pnpm release:publish --dry-run  # show what would happen, touch nothing
 *   pnpm release:publish --yes      # skip the confirmation prompt (scripted/CI use)
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import * as readline from 'node:readline/promises';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PKG_PATH = path.join(ROOT, 'apps/tbc-rotation/package.json');
const CHANGELOG_DIR = path.join(ROOT, 'apps/website/src/content/changelog');

const args = new Set(process.argv.slice(2));
const dryRun = args.has('--dry-run');
const skipPrompt = args.has('--yes');

const git = (...a: string[]) =>
  execFileSync('git', a, { cwd: ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();

function fail(msg: string): never {
  console.error(`\n✗ ${msg}`);
  process.exit(1);
}

// ── Resolve what we're releasing ───────────────────────────────────────────────
const version: string = JSON.parse(fs.readFileSync(PKG_PATH, 'utf8')).version;
const tag = `v${version}`;
const changelogPath = path.join(CHANGELOG_DIR, `${tag}.md`);
const changelogRel = path.relative(ROOT, changelogPath);

// ── 1. Validate the changelog exists and is actually curated ───────────────────
if (!fs.existsSync(changelogPath)) {
  fail(`No changelog at ${changelogRel}. Run \`pnpm release\` first, then curate it.`);
}
const raw = fs.readFileSync(changelogPath, 'utf8');
if (raw.includes('_TODO: describe for players_')) {
  fail(`${changelogRel} still has _TODO:_ placeholders — curate the prose before publishing.`);
}
if (raw.includes('SCAFFOLDED by')) {
  fail(`${changelogRel} still has the scaffold note — finish curating and delete that comment.`);
}
// Strip YAML frontmatter; the body becomes the tag message + Release body (mirrors release.yml).
const body = raw.replace(/^---\n[\s\S]*?\n---\n/, '').trim();
if (!body) fail(`${changelogRel} has no body after the frontmatter.`);

// ── 2. Tags are immutable — refuse to re-publish an existing one ───────────────
if (git('tag', '--list', tag)) {
  fail(`Tag ${tag} already exists. Tags are immutable — bump to a new version instead.`);
}

const branch = git('rev-parse', '--abbrev-ref', 'HEAD');

console.log(`Releasing       : ${tag}`);
console.log(`Branch          : ${branch}`);
console.log(`Changelog       : ${changelogRel}`);
console.log(`\n--- release notes (tag message + GitHub Release body) ---\n`);
console.log(body);
console.log('\n---------------------------------------------------------\n');

if (dryRun) {
  console.log('Dry run — would build, commit, tag, and push. Nothing changed.');
  process.exit(0);
}

async function publish(): Promise<void> {
  // ── 3. Verify the build before anything irreversible ─────────────────────────
  console.log('Verifying build (corepack pnpm --filter @menagerie/tbc-rotation build)...');
  try {
    execFileSync('corepack', ['pnpm', '--filter', '@menagerie/tbc-rotation', 'build'], {
      cwd: ROOT,
      stdio: 'inherit',
    });
  } catch {
    fail('Build failed — fix it before publishing.');
  }

  // ── 4. Confirm (the push triggers a live GitHub Release + Discord) ───────────
  if (!skipPrompt) {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    const ans = (await rl.question(`\nPublish ${tag} to origin/${branch} now? [y/N] `)).trim();
    rl.close();
    if (!/^y(es)?$/i.test(ans)) {
      console.log('Aborted — nothing committed, tagged, or pushed.');
      return;
    }
  }

  // ── 5. Commit (only if the bump/changelog aren't already committed, e.g. via PR) ─
  git('add', PKG_PATH, changelogPath);
  const staged = git('diff', '--cached', '--name-only').split('\n').filter(Boolean);
  const expected = [path.relative(ROOT, PKG_PATH), changelogRel];
  const unexpected = staged.filter((f) => !expected.includes(f));
  if (unexpected.length) {
    fail(`Unexpected staged files: ${unexpected.join(', ')}. Unstage them and re-run.`);
  }
  if (staged.length) {
    git('commit', '-m', `chore(workspace): release ${tag}`);
    console.log('✓ Committed release.');
  } else {
    console.log('Release files already committed — tagging current HEAD.');
  }

  // ── 6. Annotated tag + push (push the tag last; it triggers release.yml) ─────
  git('tag', '-a', tag, '-m', body);
  git('push', 'origin', branch);
  git('push', 'origin', tag);

  console.log(
    `\n✓ Published ${tag}. release.yml is now building the addon and cutting the GitHub Release.`,
  );
}

publish().catch((err) => {
  console.error(err);
  process.exit(1);
});
