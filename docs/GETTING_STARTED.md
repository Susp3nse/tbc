# Getting Started

A practical onboarding tour for the Menagerie monorepo — clone to first build, the everyday dev loop,
and where to read next. For deep architecture and conventions, see the root [`AGENTS.md`](../AGENTS.md)
(symlinked as `CLAUDE.md`) and the per-area `AGENTS.md` files it indexes.

## 1. Prerequisites

- **Node.js** ≥ 20 (the package engines allow ≥ 18; CI runs on 20).
- **corepack** — ships with Node; activates the pinned pnpm. No global pnpm install needed.

```bash
corepack enable          # one time — activates pnpm@11.6.0 pinned in package.json
pnpm install             # install all workspace dependencies
```

That's the whole setup. The repo is a **pnpm + corepack monorepo** (ESM TypeScript run via `tsx`/`tsc`,
plus the Lua rotation source).

## 2. The mental model

The product is a **WoW TBC rotation addon** — a single `TellMeWhen.lua` profile that players import.
Everything else exists to build, ship, and support it.

| Path | What it is |
|------|------------|
| `apps/tbc-rotation/` | The addon. Modular Lua under `src/aio/<class>/` compiled to one `output/TellMeWhen.lua`. |
| `apps/website/` | Astro static site — distribution + docs + changelog. |
| `packages/tmw-profile-builder/` | The build/watch/sync engine the rotation app drives (ships compiled `dist/`). |
| `packages/log-analyzer/` | Warcraft Logs analyzer library + CLI. |

**Scope = directory.** When you work in an area, read that area's `AGENTS.md`; you shouldn't need to
read sibling classes or unrelated apps.

## 3. Everyday workflows

Prefer the **per-package `pnpm --filter` scripts** below over ad-hoc commands — they're the supported
entry points. (The root `package.json` also exposes shortcuts like `pnpm build:rotation`,
`build:website`, `build:bot` for convenience.)

### Build the rotation

```bash
pnpm --filter @menagerie/tbc-rotation build        # compile → apps/tbc-rotation/output/TellMeWhen.lua
pnpm --filter @menagerie/tbc-rotation build:sync   # build + sync into your WoW SavedVariables
pnpm --filter @menagerie/tbc-rotation watch         # watch mode: auto-rebuild + sync on every save
```

`build:sync`/`watch` need a local sync target. Copy the template and fill in your WoW path:

```bash
cp apps/tbc-rotation/builder.config.local.example.json apps/tbc-rotation/builder.config.local.json
# edit it to point at your SavedVariables — this file is gitignored, never commit it
```

The build is a **deterministic concatenation**: `builder.config.json` declares the module load order
and a template; the `@menagerie/tmw-profile-builder` engine assembles the classes into one profile. See
[`apps/tbc-rotation/AGENTS.md`](../apps/tbc-rotation/AGENTS.md) and
[`packages/tmw-profile-builder/AGENTS.md`](../packages/tmw-profile-builder/AGENTS.md).

### Run the website

```bash
pnpm --filter @menagerie/website dev        # local dev server
pnpm --filter @menagerie/website build      # static build → apps/website/dist
```

The changelog is a content collection — add a release by dropping a
`src/content/changelog/v<X.Y.Z>.md` file (see [`apps/website/AGENTS.md`](../apps/website/AGENTS.md)).

### Analyze Warcraft Logs

```bash
pnpm --filter @menagerie/log-analyzer analyze:report -- --report <code> --fight <id> --player <name> --class Druid --spec Cat
```

## 4. Quality gates

Run before pushing non-trivial changes:

```bash
pnpm check        # lint (oxlint) + format:check (oxfmt) + typecheck, across the workspace
pnpm test         # recursive tests (analyzer, rotation guardrails)
```

Lua source has its own linter: `pnpm --filter @menagerie/tbc-rotation lint:lua` (luacheck).

## 5. Cut a release

Releases are two commands bracketing one human step — you never hand-type a `git tag`:

```bash
pnpm release            # 1. bump the version + scaffold the changelog from your commits
#                          2. curate apps/website/src/content/changelog/v<X.Y.Z>.md into player prose
pnpm release:publish    # 3. validate → build → confirm → commit → tag → push (triggers the release)
```

`pnpm release` reads the conventional commits since the last tag, computes the next semver, bumps
`apps/tbc-rotation/package.json`, and writes a draft changelog with `_TODO:` placeholders. You rewrite
those into player-facing prose (that's the only manual step — your commit subjects are engineer-speak).
`pnpm release:publish` refuses to proceed while any placeholder remains, so half-written notes can't
ship. Preview either with `--dry-run`. Full runbook — from-main flow, PR-based variant, CI behavior,
hard rules: [`docs/RELEASING.md`](./RELEASING.md).

## 6. Where to go next

- **Architecture, conventions, release workflow:** root [`AGENTS.md`](../AGENTS.md).
- **Touching a class rotation:** `apps/tbc-rotation/src/aio/<class>/AGENTS.md`.
- **Adding a new class:** [`docs/NEW_CLASS_GUIDE.md`](./NEW_CLASS_GUIDE.md).
- **Build engine internals:** [`packages/tmw-profile-builder/AGENTS.md`](../packages/tmw-profile-builder/AGENTS.md).
