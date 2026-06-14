# Rename: Flux AIO → Menagerie

> Status: planned (not started). Owner: Bryan. Created 2026-06-14.

## Context

The project is currently branded **Flux AIO** with npm scope `@flux/`, the Lua global
`_G.FluxAIO`, and GitHub Pages hosting at `flux-rotations.github.io/tbc`. The owner now holds
**menagerie.dev** and wants to ship under that brand. This is a full rebrand across **120 files
(465 case-sensitive "Flux" hits; 722 case-insensitive)**, plus first-class **attribution** crediting
the original Flux codebase so the fork is properly acknowledged.

### Decisions locked in
1. **Name mapping:** display `Flux AIO` → `Menagerie`; npm scope `@flux/` → `@menagerie/`.
2. **Lua namespace:** rename everything — `_G.FluxAIO` → `_G.Menagerie`, `_G.FluxAIO_SETTINGS_SCHEMA`
   → `_G.Menagerie_SETTINGS_SCHEMA`, slash commands `/fluxlog` `/flog` → `/menagerielog` `/mlog`
   (and `/flux*` → `/menagerie*`). Accepted consequence: existing users must reinstall the schema
   snippet (settings reset) — a clean break, no back-compat aliases.
3. **Repo & hosting:** update in-code refs only. New repo + **menagerie.dev custom domain**
   (base path `/`). GitHub org settings / DNS are done by the owner, not in this change.
4. **Attribution:** a dedicated **NOTICE** file + a credit section in **README** + a credit line
   on the **website**.

> **ASSUMPTION (confirm):** new GitHub slug = `menagerie-dev/tbc`. Used only for in-code URLs
> (download links, clone URL) in `apps/website/src/config.ts` (`GITHUB_REPO`) and the bot deploy
> script. If the real owner/repo differs it's a trivial one-line change.

---

## Categories of change (each is handled differently — NOT one blind find/replace)

### A. npm package scope `@flux/*` → `@menagerie/*`  (mechanical, build-critical)
Five packages: `@flux/tbc-rotation`, `@flux/website`, `@flux/bot`, `@flux/log-analyzer`,
`@flux/tmw-profile-builder`. Rename in:
- every `package.json` `name` + every workspace `dependencies`/`devDependencies` reference
- every `import ... from '@flux/...'` in `.ts` (`apps/tbc-rotation/build.ts`, `dev-watch.ts`, sim
  files, bot services)
- every `pnpm --filter @flux/...` in scripts, `.github/workflows/*.yml`, `docs/RELEASING.md`, all
  `AGENTS.md`/`CLAUDE.md`
- root `package.json` `"name": "gg-rotations"` → `"menagerie"`
- **Regenerate** `pnpm-lock.yaml` via `pnpm install` (do NOT hand-edit it).

### B. Lua runtime identifiers (build-critical — source + builder.config in lockstep)
- `_G.FluxAIO` → `_G.Menagerie` (~61 refs), `_G.FluxAIO_SETTINGS_SCHEMA`, `_G.FluxAIO_SECTIONS`
  (note: **caps** — not `_Sections`; 10 refs), `_G.FluxAIOClipDumps`, frame names
  (`FluxAIOSettingsFrame`, `FluxAIONotification`, `FluxAIODebugFrame`, `FluxAIOCopyPopup`,
  `FluxAIODashboard`), locals like `FluxAIO_ResyncFired`.
  > A single case-sensitive `FluxAIO` → `Menagerie` covers every PascalCase identifier above
  > (incl. `_G.FluxAIO`); the underscore/suffix forms ride along.
- Slash commands — **all** of them, not just the log one:
  - `core.lua`: `SLASH_FLUXLOG1/2` (`/fluxlog`, `/flog`) + `SlashCmdList["FLUXLOG"]` → `/menagerielog`,
    `/mlog`.
  - `settings.lua`: `SLASH_FLUXAIO1/2` (`/flux`, `/faio`) + `SlashCmdList["FLUXAIO"]` (opens settings;
    sub-commands `/flux burst|def|gap|status|help`) → `/menagerie`, `/maio`; and
    `SLASH_FLUXTICKS1` (`/fticks`) + `SlashCmdList["FLUXTICKS"]` → `/mticks`.
- **Event-listener string literals** (hunter): `FLUX_HUNTER_WEAVE_CLEU` (meleeweave.lua) and the six
  `FLUX_HUNTER_ADAPTIVE_*` registration strings (adaptive.lua) → `MENAGERIE_HUNTER_*`. Internal-only
  but must move together or the listeners desync.
- **`apps/tbc-rotation/.luacheckrc`** — the luacheck globals allowlist hard-codes every Flux global
  + slash constant (`FluxAIO`, `FluxAIO_ResyncFired`, `FluxAIO_SECTIONS`, `FluxAIO_SETTINGS_SCHEMA`,
  `FluxAIOClipDumps`, `SLASH_FLUXAIO1/2`, `SLASH_FLUXLOG1/2`, `SLASH_FLUXTICKS1`) plus a
  `@flux/tbc-rotation` lint command in a comment. Rename in lockstep or `pnpm lint:lua` fails.
- **`apps/tbc-rotation/builder.config.json`** must move in lockstep (the build contract):
  - `"modulePrefix": "Flux_"` → `"Menagerie_"`
  - `"profileNamePrefix": "Flux "` → `"Menagerie "`
  - `"marker": "-- Flux AIO - Core Module"` → must match new first line of `core.lua`
  - `"anchor": "local NS = _G.FluxAIO"` → must match new anchor in `core.lua`
  - `"_comment": "Flux AIO build conventions..."` → reword
- `modulePrefix`/`profileNamePrefix` are user-visible (TMW module/profile names in-game) — same
  clean break.

### C. Display / branding strings (user-facing prose)
- Lua `print()` tags `[Flux AIO]` across `core.lua` + class files → `[Menagerie]`; "Flux AIO Debug
  Log" title.
- `apps/website/src/layouts/Base.astro`: `pageTitle`, `<meta author>`, `og:site_name`, nav logo
  `Flux <span>AIO</span>`, footer `Flux AIO — WoW TBC rotation addon`.
- **`apps/website/public/og.svg`** — social-share card with hardcoded `Flux <tspan>AIO</tspan>` text
  (+ the `#6c63ff` accent fill — see Scope H). Re-letter to Menagerie.
- Class/guide pages, `faq.astro`, `index.astro`, changelog entries that say "Flux AIO" in prose.
  > Historical changelog files (`v1.6.0.md`, `v1.7.0.md`, `v1.15.0.md`) are release records — rename
  > brand mentions but do NOT rewrite history/version numbers.

### D. Hosting / URLs (custom-domain move)
- `apps/website/astro.config.mjs`: `site` → `'https://menagerie.dev'`; **remove `base: '/tbc'`**
  (custom domain serves from root; the `url()` helper in `config.ts` derives from `BASE_URL`, so
  dropping `base` is sufficient).
- **Add `apps/website/public/CNAME`** containing `menagerie.dev`.
- `apps/website/src/config.ts`: `GITHUB_REPO = 'flux-rotations/tbc'` → new slug (see assumption).
- `README.md` website links, `apps/website/AGENTS.md`/`CLAUDE.md` hosting note,
  `apps/discord-bot/deploy/migrate-rename.sh` remote URL.

### E. File / path renames (`git mv`)
- `docs/reference/FluxAIO_API_Reference.md` → `Menagerie_API_Reference.md`; update inbound refs in
  `docs/NEW_CLASS_GUIDE.md` and elsewhere.
- Bot temp prefix `flux-bot-` (`apps/discord-bot/src/services/builder.ts`) → `menagerie-bot-`.

### F. Docs & agent context (`AGENTS.md`/`CLAUDE.md`, `docs/`)
- Root `CLAUDE.md`/`AGENTS.md` title + workspace map + version notes; every nested `AGENTS.md`
  (`apps/*`, `packages/*`, per-class) mentioning Flux/`@flux`.
- `docs/RELEASING.md`, `docs/GETTING_STARTED.md`, `docs/NEW_CLASS_GUIDE.md`, plan/research docs.
  > `docs/plans/*` are historical notes — update brand/scope refs for correctness, don't rewrite intent.

### G. Build artifact (do NOT hand-edit)
- `apps/tbc-rotation/output/TellMeWhen.lua` is generated; it keeps old strings until rebuilt.
  Regenerate via `pnpm --filter @menagerie/tbc-rotation build` after source changes — never sed it.

### H. Brand palette — purple → warm "menagerie" earth tones (website only)
The website's brand accent is purple (`--accent: #6c63ff` in `apps/website/src/styles/global.css`,
plus a purple radial glow on `body` and `.hero h1 span`). Rebrand to a **warm-dark** palette drawn
from the cottage icon: terracotta-orange primary, teal + green secondaries, warmed neutrals. Dark
theme is **kept** (low-risk); the **9 class colors stay unchanged** (they're WoW-canonical and must
remain readable on a dark bg).

Token changes in `:root` (`global.css`):
| token | old | new |
|-------|-----|-----|
| `--bg` | `#08080a` | `#16130f` |
| `--bg-raised` | `#0c0c0f` | `#1e1a14` |
| `--bg-hover` | `#131316` | `#26201a` |
| `--border` | `#1e1e26` | `#332b20` |
| `--text` | `#dcdce4` | `#ece3d2` |
| `--text-dim` | `#9494a8` | `#b3a587` |
| `--text-faint` | `#787892` | `#8c7f6a` |
| `--accent` | `#6c63ff` | `#e08a3c` |
| `--accent-hover` | `#8078ff` | `#f3a55a` |
| `--accent-dark` | `#6058f0` | `#c5722a` |
| `--accent-bg` | `#141327` | `#241a10` |
| `--accent-border` | `#211f47` | `#43321d` |
| `--green` | `#34d399` | `#7fae54` |
| `--gold` | `#fbbf24` | `#e6b84a` |
| (new) `--teal` | — | `#4fa3a0` |

Also: the two hardcoded `rgba(108, 99, 255, …)` purple glows (`body` background gradient,
`.hero h1 span` text-shadow) → warm `rgba(224, 138, 60, …)`; `og.svg` accent fill `#6c63ff` →
`#e08a3c` (folds into Scope C). The Lua addon has no themeable palette — this scope is website-only.

---

## Attribution (the "forked from Flux" credit)

1. **`NOTICE`** (new, repo root): state Menagerie is derived from the Flux AIO TBC rotation codebase,
   with credit/link to the original project and author(s). License-style and factual.
   > There is currently **no `LICENSE`** file in the repo — flag to owner; adding one is out of
   > scope unless wanted.
2. **`README.md`** — a `## Credits` / `## Attribution` section: "Menagerie is a fork of **Flux
   AIO**…" linking upstream + to `NOTICE`.
3. **Website** — a credit line in `Base.astro` footer (e.g. "Forked from Flux AIO" with link), so
   attribution is visible to players, not just on GitHub.

---

## Execution order

1. **Scope A (packages)** — rename `@flux/*` → `@menagerie/*` + root name, then `pnpm install` to
   regenerate the lockfile and confirm the workspace resolves.
2. **Scope B (Lua + builder.config)** — rename runtime identifiers and the four
   `builder.config.json` anchors together; verify marker/anchor match `core.lua` exactly.
3. **Scopes C/D/E/F/H** — branding strings, hosting/URLs, file renames, docs, brand palette.
4. **Attribution** — `NOTICE`, README section, footer credit.
5. **Rebuild artifact (Scope G)** + full verification.
6. Residual `grep -rniE flux --exclude-dir={node_modules,dist,.git}` sweep; only deliberate
   attribution + historical changelog mentions should remain.

> Apply edits as scoped, case-sensitive replacements per category (`FluxAIO`, `Flux AIO`, `@flux/`,
> `Flux_`, lowercased `fluxaio` forms), each followed by a diff review — never one global replace,
> since "Flux" appears as identifier vs prose vs URL vs build-anchor and each needs a different target.

---

## Verification

- `pnpm install` — lockfile regenerates, no unresolved `@flux/*` workspace deps.
- `pnpm --filter @menagerie/tbc-rotation build` — succeeds; `output/TellMeWhen.lua` shows
  `_G.Menagerie`, `Menagerie_` module prefix, `Menagerie ` profile prefix, **zero** `Flux`.
- `pnpm --filter @menagerie/log-analyzer test` — green.
- `pnpm check` (lint + format:check + typecheck) — green.
- `pnpm --filter @menagerie/tbc-rotation lint:lua` — green (`.luacheckrc` allowlist renamed; needs
  the `luacheck` binary).
- `pnpm --filter @menagerie/website build` — succeeds; `dist/` has `CNAME`, internal links resolve
  at root (no `/tbc`), title/footer say Menagerie + Flux credit.
- (Optional, in-game) load rebuilt `TellMeWhen.lua`: `/menagerielog` toggles the log; print tags
  show `[Menagerie]`.
- Final `grep -rniE flux` returns only deliberate attribution + historical changelog records.

## Out of scope (owner does these)
- Creating/renaming the GitHub repo + org, DNS for menagerie.dev, Pages custom-domain config.
- Reinstalling the schema snippet in-game (settings reset is the accepted consequence).
- Confirming the GitHub slug assumption (`menagerie-dev/tbc`).
- Deciding whether to add a `LICENSE` file (none exists today).
