#!/usr/bin/env tsx
/**
 * release.ts — single-version release helper.
 *
 * Reads the conventional commits since the last `v*` tag, computes the next platform
 * version (semver), bumps `apps/tbc-rotation/package.json`, and scaffolds the changelog
 * content-collection entry (`apps/website/src/content/changelog/v<next>.md`) grouped by
 * scope for you to curate into player-facing prose.
 *
 * This is the *mechanical* half of the release flow (version math + scaffolding). The curated
 * prose, the tag, and the GitHub Release stay human-reviewed — see root AGENTS.md → Release Workflow.
 * The build injects the bumped package.json version into the addon as NS.VERSION; there are no
 * per-class versions to touch.
 *
 *   pnpm release              # bump + scaffold locally for review
 *   pnpm release --dry-run    # print what would change, write nothing
 *   pnpm release --pr         # also create a release/v<next> branch, commit, push, open a PR
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PKG_PATH = path.join(ROOT, 'apps/tbc-rotation/package.json');
const CHANGELOG_DIR = path.join(ROOT, 'apps/website/src/content/changelog');

const args = new Set(process.argv.slice(2));
const dryRun = args.has('--dry-run');
const openPr = args.has('--pr');

const git = (...a: string[]) =>
  execFileSync('git', a, { cwd: ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();

/** Scope (commit scope / class folder) → changelog section heading. */
const SCOPE_HEADINGS: Record<string, string> = {
  builder: 'Build System',
  build: 'Build System',
  aio: 'Core',
  workspace: 'Workspace',
  website: 'Website',
  bot: 'Discord Bot',
  analyzer: 'Log Analyzer',
};
const headingFor = (scope: string) =>
  SCOPE_HEADINGS[scope] ?? scope.charAt(0).toUpperCase() + scope.slice(1);

type Commit = { type: string; scope: string; breaking: boolean; description: string };

function lastTag(): string | null {
  try {
    return git('describe', '--tags', '--abbrev=0', '--match', 'v*');
  } catch {
    return null; // no tags yet
  }
}

function commitsSince(tag: string | null): Commit[] {
  const range = tag ? `${tag}..HEAD` : 'HEAD';
  // Unit-sep (\x1f) between fields, record-sep (\x1e) between commits.
  const raw = git('log', range, '--no-merges', '--format=%s%x1f%b%x1e');
  const parsed: Commit[] = [];
  for (const record of raw.split('\x1e')) {
    const [subject = '', body = ''] = record.replace(/^\n+/, '').split('\x1f');
    const m = subject.match(/^(\w+)(?:\(([^)]+)\))?(!)?:\s*(.+)$/);
    if (!m) continue; // not a conventional commit — skip
    parsed.push({
      type: m[1],
      scope: m[2] ?? '',
      breaking: Boolean(m[3]) || /BREAKING[ -]CHANGE/.test(body),
      description: m[4].trim(),
    });
  }
  return parsed;
}

function bumpLevel(commits: Commit[]): 'major' | 'minor' | 'patch' | null {
  if (commits.some((c) => c.breaking)) return 'major';
  if (commits.some((c) => c.type === 'feat')) return 'minor';
  if (commits.some((c) => c.type === 'fix')) return 'patch';
  return null;
}

function nextVersion(current: string, level: 'major' | 'minor' | 'patch'): string {
  const [maj, min, pat] = current.split('.').map(Number);
  if (level === 'major') return `${maj + 1}.0.0`;
  if (level === 'minor') return `${maj}.${min + 1}.0`;
  return `${maj}.${min}.${pat + 1}`;
}

/** Build the scaffolded changelog markdown from the release-worthy (feat/fix/breaking) commits. */
function scaffoldChangelog(version: string, commits: Commit[]): string {
  const worthy = commits.filter((c) => c.breaking || c.type === 'feat' || c.type === 'fix');
  const tags = [
    ...(worthy.some((c) => c.breaking) ? ['major'] : []),
    ...(worthy.some((c) => c.type === 'feat') ? ['feature'] : []),
    ...(worthy.some((c) => c.type === 'fix') ? ['fix'] : []),
  ];

  const byScope = new Map<string, Commit[]>();
  for (const c of worthy) {
    const key = c.scope || 'general';
    (byScope.get(key) ?? byScope.set(key, []).get(key)!).push(c);
  }

  const lines = [
    '---',
    `version: '${version}'`,
    `year: '${new Date().getFullYear()}'`,
    `tags: [${tags.map((t) => `'${t}'`).join(', ')}]`,
    '---',
    '',
    '<!-- SCAFFOLDED by `pnpm release` — rewrite each bullet into curated, player-facing prose,',
    '     drop any non-player-facing scopes (workspace / builder / analyzer), then delete this note. -->',
    '',
  ];
  for (const [scope, list] of byScope) {
    lines.push(`### ${headingFor(scope)}`, '');
    for (const c of list) {
      const title = c.description.charAt(0).toUpperCase() + c.description.slice(1);
      lines.push(`- **${title}** — _TODO: describe for players_`);
    }
    lines.push('');
  }
  return lines.join('\n').trim() + '\n';
}

// ── Run ──────────────────────────────────────────────────────────────────────
const pkg = JSON.parse(fs.readFileSync(PKG_PATH, 'utf8'));
const current: string = pkg.version;
const tag = lastTag();
const commits = commitsSince(tag);
const level = bumpLevel(commits);

console.log(`Current version : v${current}`);
console.log(`Last tag        : ${tag ?? '(none)'}`);
console.log(`Commits scanned : ${commits.length}`);

if (!level) {
  console.log(
    '\nNo release-worthy commits (feat / fix / breaking) since the last tag. Nothing to do.',
  );
  process.exit(0);
}

const next = nextVersion(current, level);
const changelogPath = path.join(CHANGELOG_DIR, `v${next}.md`);
const changelog = scaffoldChangelog(next, commits);

console.log(`Bump            : ${level} → v${next}`);
console.log(`Changelog       : ${path.relative(ROOT, changelogPath)}`);

if (dryRun) {
  console.log('\n--- changelog scaffold (dry run) ---\n');
  console.log(changelog);
  process.exit(0);
}

if (fs.existsSync(changelogPath)) {
  console.error(
    `\nRefusing to overwrite existing ${path.relative(ROOT, changelogPath)}. Remove it first.`,
  );
  process.exit(1);
}

pkg.version = next;
fs.writeFileSync(PKG_PATH, JSON.stringify(pkg, null, 2) + '\n');
fs.writeFileSync(changelogPath, changelog);
console.log(`\n✓ Bumped package.json and wrote the changelog scaffold.`);

if (openPr) {
  const branch = `release/v${next}`;
  git('checkout', '-b', branch);
  git('add', PKG_PATH, changelogPath);
  git('commit', '-m', `chore(workspace): release v${next}`);
  git('push', '-u', 'origin', branch);
  execFileSync('gh', ['pr', 'create', '--fill', '--title', `Release v${next}`], {
    cwd: ROOT,
    stdio: 'inherit',
  });
  console.log(`\n✓ Opened release PR from ${branch}.`);
}

console.log(`
Next steps:
  1. Curate ${path.relative(ROOT, changelogPath)} into player-facing prose.
  2. Verify the build:  corepack pnpm --filter @menagerie/tbc-rotation build
  3. Merge, then tag:   git tag -a v${next} -m "<release notes>" && git push origin v${next}
     (the tag triggers release.yml, which uses the changelog entry as the Release + Discord body)
`);
