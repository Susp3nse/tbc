# Context Docs Hierarchy — Design Spec

- **Date:** 2026-06-13
- **Status:** Draft for approval (execute after sign-off)
- **Goal in one line:** Replace the monolithic root `CLAUDE.md` with a hierarchy of scoped, single-source context docs so an agent working in any one area loads only what that area needs.

---

## 1. Motivation

Today all project knowledge lives in a single 498-line root `CLAUDE.md` (23.5 KB): a global senior-engineer behavioral prompt **plus** the full workspace architecture **plus** every class's rotation detail. Two problems:

1. **No scoping.** Working on Druid forces the model to carry website, Discord-bot, and eight other classes' context. That's wasted context budget and noise.
2. **Duplication / drift already happening.** A separate root `AGENTS.md` (4.2 KB) exists with overlapping-but-different content, and the two files already disagree (see §7 conflicts). Maintaining two parallel docs is exactly what we want to eliminate.

The product structure is now stable (9 classes, a profile-builder package, a log-analyzer package, a website, a bot). The next phase of work is optimizing the AIO core/utilities and refining classes — work that is naturally *area-scoped*. The docs should match that shape.

## 2. Principles

- **One source of truth per directory.** No content lives in two files.
- **Scope = directory.** A doc describes its own directory's concerns and nothing above it. Shared/global rules live once, at the root.
- **Read down, not across.** An agent in `druid/` reads root → tbc-rotation → druid. It does not read `hunter/`, `website/`, or `discord-bot/` unless told to.
- **Pointers over copies.** When a class needs a util, the class doc says *where the util doc is*, it does not restate the util.
- **Thin and current beats thorough and stale.** Each doc earns its lines.

## 3. Locked decisions

| # | Decision | Choice |
|---|----------|--------|
| 1 | AGENTS.md vs CLAUDE.md | **`AGENTS.md` is canonical** (real file). `CLAUDE.md` is a **symlink → `AGENTS.md`** in every directory that has one. Edit one file; both Claude Code and other agent tools resolve it. |
| 2 | Granularity | **Full depth now:** root + per-app + per-package + per-class (~15 docs). |
| 3 | Sequencing | Config fixes first (done this session, see Appendix A), then this hierarchy. |

## 4. Target structure

```
AGENTS.md                                  <- root: GLOBAL only (behavior + workspace map)
CLAUDE.md -> AGENTS.md                      (symlink)

apps/
  tbc-rotation/
    AGENTS.md          + CLAUDE.md symlink   <- addon-wide: build system, load order,
                                                strategy/middleware arch, slash cmds, schema
    src/aio/
      druid/   AGENTS.md + CLAUDE.md symlink  <- Druid: playstyles, spell IDs, rotation theory
      hunter/  AGENTS.md + CLAUDE.md symlink
      mage/    AGENTS.md + CLAUDE.md symlink
      paladin/ AGENTS.md + CLAUDE.md symlink
      priest/  AGENTS.md + CLAUDE.md symlink
      rogue/   AGENTS.md + CLAUDE.md symlink
      shaman/  AGENTS.md + CLAUDE.md symlink
      warlock/ AGENTS.md + CLAUDE.md symlink
      warrior/ AGENTS.md + CLAUDE.md symlink
  website/      AGENTS.md + CLAUDE.md symlink <- Astro: pages/layouts/data, deploy
  discord-bot/  AGENTS.md + CLAUDE.md symlink <- bot: services, deploy, secrets

packages/
  tmw-profile-builder/ AGENTS.md + CLAUDE.md symlink <- builder API, config contract
  log-analyzer/        AGENTS.md + CLAUDE.md symlink <- analyzer lib + CLI, specs
```

**Total:** 1 root + 3 app + 2 package + 9 class = **15 `AGENTS.md` files**, each with a sibling `CLAUDE.md` symlink.

> Note on `src/aio/` shared modules (`core.lua`, `common.lua`, `main.lua`, `ui.lua`, `settings.lua`, `dashboard.lua`): these are documented inside `apps/tbc-rotation/AGENTS.md` (the "AIO core" section), **not** a separate per-file doc. A class doc points here when it touches shared code.

## 5. Content model — what each tier owns

Each tier documents **only its own** concerns. Lower tiers assume the reader has already read upward.

### Root `AGENTS.md` (global, area-agnostic)
- The senior-engineer behavioral prompt (assumption surfacing, scope discipline, push-back, simplicity) — currently the top half of `CLAUDE.md`. **This is the only place it lives.**
- One-paragraph workspace map + the directory table (which area is what).
- Cross-cutting rules that apply everywhere: commit convention (see §7 conflict), file-naming rules, "never commit secrets/local config," the build-version/`dev_revision` policy.
- A "where to look" index pointing at each area's `AGENTS.md`.
- **Removed from root:** all per-class detail, the strategy-registry deep dive, slash-command tables, schema mechanics → these move to `apps/tbc-rotation/AGENTS.md`.

### `apps/tbc-rotation/AGENTS.md` (addon-wide)
- What the app is: **a Lua rotation addon plus a thin Node build layer** whose only output is `output/TellMeWhen.lua`. (Not a TS/React app — the TS exists only to bundle Lua.)
- Build system: the `build`/`watch`/`sync` commands, `builder.config.json` contract, `tmw-template.lua` (now in `src/`), ORDER_MAP / module load order.
- AIO architecture: Strategy Registry pattern, middleware vs strategies, `register_class()` contract, context object, force-bypass & burst context, dashboard.
- Shared modules (`core/common/main/ui/settings/dashboard.lua`) — what each owns.
- Settings schema mechanics (snake_case keys, the three consumers).
- Lua/WoW constraints (Lua 5.1, 200-local limit, no inline tables in combat, no load-time settings capture).
- Slash commands, debugging.
- Release workflow (the version-bump + changelog + tag steps) — or keep at root if treated as global; decide in §7.

### `apps/website/AGENTS.md`
- Astro app: `src/pages/`, `src/layouts/`, `src/components/`, `src/data/`, `public/`.
- Build/dev/preview/typecheck commands; deploy workflow (`deploy-website.yml`); "website-only changes don't need a rotation tag."
- Changelog page location + format (currently described in root release workflow).

### `apps/discord-bot/AGENTS.md`
- Bot services in `src/services/`, deploy files, required secrets/env (never commit `.env`).
- The key integration fact: the bot invokes the rotation's compiled `dist/build.js` with `ROTATION_ROOT` pointing at a temp workspace, and copies `builder.config.json` + `src/tmw-template.lua` + `src/aio` into it. (This is *why* the rotation ships a built `dist`.)
- Deploy workflow (`deploy-bot.yml`); bot-only changes don't need a rotation tag.

### `packages/tmw-profile-builder/AGENTS.md`
- Purpose: content-agnostic build/watch/sync engine. Ships compiled (`dist/`, consumed via `exports`).
- The config contract: it reads the consuming app's `builder.config.json`; it ships **no** defaults. `createBuildContext`, path resolution, load-order conventions.
- This is where the *reusable core* work (per the user's next phase) is documented as it evolves.

### `packages/log-analyzer/AGENTS.md`
- Purpose: Warcraft Logs analyzer lib + `tsx`-run CLI (never emits).
- CLI commands (`discover`/`fetch`/`analyze`/`compare`) and the **correct invocation form** (no stray `--`; see Appendix A #4).
- `exports` map, the hand-written `index.d.ts` caveat, specs in `src/specs/`.
- Where `analyze` writes output (`reports/`).

### Per-class `AGENTS.md` (×9) — the payoff tier
Template (kept tight — link out, don't restate the framework):
```
# <Class> — Rotation Context

## Playstyles
<list of registered playstyles and when each is active>

## Files
<one line per file in this folder: what each owns>

## Key spell IDs / ranks
<the IDs and rank tables this class relies on>

## Rotation theory / priorities
<the actual decision logic, per playstyle; the "why">

## Class-specific context extensions
<what extend_context adds for this class>

## Gotchas
<stance/form quirks, secure-combat constraints specific to this class, known edge cases>

## See also
- Framework/registry: ../../AGENTS.md
- Research: docs/<CLASS>_RESEARCH.md
```
Source material already exists: `docs/<CLASS>_RESEARCH.md` files + the class's `class.lua`/`middleware.lua`/playstyle files. The class doc is a **distilled index**, not a copy of the research doc — it points at the research doc for depth.

## 6. Symlink & tooling mechanics

- Create the symlink relatively, per directory: `ln -s AGENTS.md CLAUDE.md` (run inside each dir so the link is `CLAUDE.md -> AGENTS.md`, not an absolute path). Symlinks are committed to git and resolve on read.
- Claude Code reads `CLAUDE.md` up the directory tree from the cwd/edited file, and subdirectory docs when files in them are touched; resolving the symlink yields the `AGENTS.md` content. Other agent tools read `AGENTS.md` directly. One edit, both satisfied.
- **`.gitignore`:** confirm symlinks aren't ignored (they won't be — only `dist/`, logs, local config are ignored).
- **Verification step:** after creating links, `readlink` each `CLAUDE.md` and confirm `git status` shows them as symlinks (mode `120000`), not copied regular files.

## 7. Open questions / conflicts to resolve before/while executing

1. **Commit-message convention — RESOLVED.**
   - **Decision:** Conventional Commits with scope = builder / app / class:
     `<type>(<scope>): <description>`
     where `<type>` ∈ {feat, fix, refactor, chore, docs, …} and `<scope>` is `builder`, an app/area (`website`, `bot`, `analyzer`), or a class name.
     Examples: `refactor(builder): …`, `fix(druid): …`, `feat(website): …`, `chore(analyzer): …`.
   - The old `[<Expansion>] (<Class or Area>) <type>: <desc>` form in root `AGENTS.md` is dropped. State the new convention **once** in the root `AGENTS.md`; remove it everywhere else.

2. **Release workflow placement.** It's a multi-step process spanning rotation version bumps, the website changelog, and tagging. Is it *global* (stays in root) or *tbc-rotation-scoped* (moves into the app doc, with the website-changelog substep cross-referenced)? **Recommendation:** keep the release workflow in root (it's cross-area orchestration), but have `apps/tbc-rotation/AGENTS.md` and `apps/website/AGENTS.md` reference it. *Needs your call.*

3. **`dev_revision` vs ephemeral build number.** Root `AGENTS.md` §"Agent-Specific Instructions" describes a `dev_revision` workflow; recent commits made the build number an *ephemeral per-session counter* (`dbf4a7a`). Verify the `dev_revision` guidance is still accurate before copying it into the new root, or it ports a stale instruction forward. *Verify against current builder behavior.*

4. **`docs/*_RESEARCH.md` relationship.** Per-class docs should *link* to the research docs, not duplicate them. Decide whether research docs stay in `docs/` (recommended — they're long-form reference) or move under each class folder. **Recommendation:** leave in `docs/`, link from the class `AGENTS.md`.

## 8. Execution phases

- **Phase 0 — Foundation (DONE this session).** Config fixes #2–#5 applied & verified; #1 (`noCheck` removal) applied and the latent type errors it exposed are catalogued in Appendix A (decision pending).
- **Phase 1 — Resolve §7 conflicts.** Lock commit convention, release-workflow placement, `dev_revision` accuracy. (Cheap, blocks clean root authoring.)
- **Phase 2 — Root + app + package docs (6 files).** Author root `AGENTS.md` (global only), the 3 app docs, the 2 package docs. Create the `CLAUDE.md` symlinks. Delete migrated content from the old root doc. Verify nothing global was lost.
- **Phase 3 — Per-class docs (9 files).** Distill each from `class.lua` + playstyle files + `docs/<CLASS>_RESEARCH.md`. Create symlinks. Spot-check one class end-to-end (e.g. Druid: confirm an agent opening `druid/cat.lua` gets exactly the right scoped context).
- **Phase 4 — Sweep.** Grep the repo for now-stale references to the old monolithic `CLAUDE.md` structure; update `NEW_CLASS_GUIDE.md` to mention adding a class `AGENTS.md`.

## 9. Acceptance criteria

- Every directory in §4 has an `AGENTS.md` (real) + `CLAUDE.md` (symlink, mode 120000, committed).
- No sentence of content appears in two `AGENTS.md` files (no duplication).
- Root doc contains *only* global behavior + workspace map + cross-cutting rules + an index; zero per-class or per-area implementation detail.
- Opening any class file and asking "what do I need to know" yields root + app + that class — and nothing from sibling classes or other apps.
- `git grep` finds no dangling references to content that moved.
- The §7 conflicts are resolved and stated once, in the correct tier.

---

## Appendix A — Phase 0 config-fix results & the pending type-error decision

Applied & verified this session:
- **#2** removed dead `@menagerie/log-analyzer` dep from `tbc-rotation` (its typecheck still passes).
- **#3** website `typecheck` = `astro check` (+ `@astrojs/check`); passes.
- **#4** hardened `log-analyzer` CLI to ignore a stray `--`; both `cli -- <cmd>` and `cli <cmd>` now dispatch; help text corrected.
- **#5** root `test` → `pnpm -r --if-present test`.
- **#1** removed `noCheck: true` from `discord-bot` and `log-analyzer` tsconfigs.

**Pending decision — `noCheck` removal surfaced pre-existing, previously-hidden type errors:**
- `log-analyzer` (~35 errors): almost all *implicit `never`* from untyped empty collections in `process-fight.ts`, `hunter-review.ts`, `top-hunter-clips.ts`, + 3 in tests. Fix = annotate the literals/accumulators (mechanical).
- `discord-bot` (5 errors): 3× same implicit-`never` (`guardrails.ts`, `webhook.ts`); **2 genuine latent bugs in `webhook.ts`** — `string | null` → `crypto.createHmac` (key can't be null) and `string | string[]` header → `Buffer.from` (array case unhandled).
- `tbc-rotation`, `tmw-profile-builder`, `website`: pass.

Options: (a) fix all now (mostly annotations + 2 real guards in `webhook.ts`), or (b) defer as tracked tasks and leave `pnpm typecheck` red until then. **Recommendation: fix now** — it's the foundation, and the `webhook.ts` issues are real correctness smells in the Discord signature-verification path.
