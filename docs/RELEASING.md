# Releasing

The single canonical runbook for cutting a Menagerie release. The root [`AGENTS.md`](../AGENTS.md)
→ Release Workflow and [`GETTING_STARTED.md`](./GETTING_STARTED.md) §5 both point here; the steps
live only in this file.

## Scope — what gets a release

**Only rotation code changes get a tag/release.** Website-only changes deploy through their own
workflow (`deploy-website.yml`) and need no tag or version bump. Doc-only PRs that happen to touch
the rotation tree don't need a bump either.

There is **one** platform version — `apps/tbc-rotation/package.json` `"version"`, injected into the
build as `NS.VERSION`. No per-class versions exist.

## The flow

Two commands bracketing one human step. You never hand-type a `git tag`.

```bash
pnpm release            # 1. bump version + scaffold the changelog from your commits
#                          2. curate the scaffolded changelog into player-facing prose
pnpm release:publish    # 3. validate → build → confirm → commit → tag → push
#                          4. CI (release.yml) cuts the GitHub Release
```

### 0. Land the work on `main` first

`pnpm release` reads conventional commits **since the last `v*` tag on the current branch**, so the
feature work must be merged and you must be on an up-to-date main:

```bash
git checkout main && git pull origin main
```

### 1. Bump + scaffold — `pnpm release`

- Reads the conventional commits since the last tag and computes the next semver:
  `feat` → minor, `fix` → patch, `!` / `BREAKING CHANGE` → major.
- Bumps `apps/tbc-rotation/package.json` `"version"`.
- Writes `apps/website/src/content/changelog/v<X.Y.Z>.md` with `_TODO:` placeholders, grouped by scope.
- Writes locally; **does not commit**. Preview with `pnpm release --dry-run`.

### 2. Curate the changelog — the only manual step

Open the new `apps/website/src/content/changelog/v<X.Y.Z>.md` and:

- Rewrite each `_TODO:` bullet into player-facing prose (commit subjects are engineer-speak).
- Drop non-player scopes (workspace / builder / analyzer).
- Delete the `<!-- SCAFFOLDED by … -->` comment.

This file is the **single source** for the release notes — the website renders it and `release.yml`
uses it as the GitHub Release body. Body format lives in
[`apps/website/AGENTS.md`](../apps/website/AGENTS.md).

### 3. Publish — `pnpm release:publish`

Wraps the whole irreversible tail in one guarded command:

- **Validates** the changelog — hard-fails while any `_TODO:` placeholder or the scaffold note
  remains, so half-written notes can't ship.
- **Builds** the rotation (`@menagerie/tbc-rotation build`); aborts on failure.
- Prints the final notes and prompts `Publish vX.Y.Z? [y/N]`.
- On `y`: commits `chore(workspace): release vX.Y.Z`, creates the **annotated** tag from the changelog
  body, and pushes branch + tag.
- `--dry-run` previews everything and touches nothing; `--yes` skips the prompt (scripted use).
- If the bump/changelog were already committed (e.g. via the PR variant below), it skips the commit
  and just tags the current HEAD.

### 4. CI publishes (automatic)

The tag push triggers `release.yml`, which builds the addon, creates the GitHub Release using
`v<X.Y.Z>.md` as the body (the annotated tag message is only a fallback if the file is missing),
and attaches `TellMeWhen.lua`. Nothing to do by hand.

## Variant — PR-based review

`pnpm release --pr` (instead of step 1) creates a `release/v<X.Y.Z>` branch, commits the bump +
scaffold, pushes, and opens a PR. Curate the changelog **on the branch**, merge it, then run
`pnpm release:publish` from main — it detects the files are already committed and just tags HEAD.

## Agent task: "review PR ##, merge, and tag a release"

When the user asks an agent to review a PR and tag a release in one go, perform every step without
re-prompting:

1. **Review** — `gh pr view <#>` and `gh pr diff <#>`. Summarize scope, flag risks (security,
   breakage, unverified assumptions), give an LGTM or hold. Trivial / mechanical PRs get a
   one-paragraph LGTM and proceed.
2. **Merge** — `gh pr merge <#> --merge --delete-branch`. Always `--merge` (not `--squash` /
   `--rebase`) so commit attribution is preserved on main. Then `git checkout main && git pull
   origin main`.
3. Continue with the flow above (`pnpm release` → curate → `pnpm release:publish`).

## Hard rules

- **Never tag without explicit user approval.** "Tag a release" in the request counts; absent that
  phrase, stop after curating (step 2) and ask before running `release:publish`.
- **Annotated tags only** (`-a` + `-m`). Never lightweight tags.
- **Tags are immutable releases** — never force-push or move an existing tag. To fix something, ship
  a new patch version.
- **Only bump rotation versions when rotation code changes.**
