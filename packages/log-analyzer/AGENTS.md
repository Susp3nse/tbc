# log-analyzer — Warcraft Logs Analyzer

> Scope: the WCL analyzer library + CLI. Read the root `AGENTS.md` first for global behavior + the
> workspace map.

A TypeScript library + CLI for fetching and analyzing Warcraft Logs (WCL) combat logs — used to mine
top-parse rotations and compare your play against them, informing rotation tuning. It is **run with
`tsx`, never compiled** (`typecheck` runs `tsc` only for checking, the CLI and exports point at
`.ts` source directly).

## CLI

Run via the `cli` script. **Invocation form matters**: `parseArgs` skips a stray `--`, so both
`pnpm cli compare` and `pnpm cli -- compare` dispatch — but pass the command + flags directly, do
not bury them after extra `--` separators.

```bash
corepack pnpm --filter @menagerie/log-analyzer cli discover --expansion tbc
corepack pnpm --filter @menagerie/log-analyzer cli fetch --boss <encounterID> --class Druid --spec Feral --count 10
corepack pnpm --filter @menagerie/log-analyzer cli fetch --report <code> --fight <id> [--player <name>] [--class Druid --spec Feral]
corepack pnpm --filter @menagerie/log-analyzer cli fetch --report <code> --trash
corepack pnpm --filter @menagerie/log-analyzer cli analyze --report <code> --fight <id> [--player <name>] [--class Druid --spec Feral]
corepack pnpm --filter @menagerie/log-analyzer cli compare --baseline <file> --yours <file>
```

- `discover` — list encounter IDs for an expansion (default `tbc`).
- `fetch` — pull top parses by boss, or a specific report fight (or list trash fights).
- `analyze` — process a report fight and **write JSON to `reports/`** (resolved against `cwd`,
  created if missing): `reports/<reportCode>-fight-<id>[-<player>].json`.
- `compare` — diff a baseline parse JSON against yours.

Needs WCL API credentials (see `src/auth.ts` / `src/config.ts`; loaded via `dotenv` — never commit
the `.env`).

## Layout

```
src/
  cli.ts            CLI dispatcher (parseArgs + command switch)
  index.ts          Library entry (resolveSpec, analyzeReportFight, ...)
  index.d.ts        HAND-WRITTEN public types (see caveat below)
  auth.ts/config.ts WCL OAuth + config
  api.ts/queries.ts WCL GraphQL client + queries
  discover.ts, fetch-*.ts, process-fight.ts, compare*.ts, detect-role.ts, ...
  specs/            Per-spec analyzer definitions: bear-druid.ts, cat-druid.ts, hunter.ts
test/               process-fight + compare tests (tsx)
```

## Caveats

- **`index.d.ts` is hand-written**, not generated. The `exports` map points every subpath's `types`
  at this single `src/index.d.ts`. If you change a public function's shape in `index.ts` (or a
  subpath export), update `index.d.ts` by hand to match.
- `exports` exposes `.`, `./compare`, `./process-fight`, and `./specs/*`.
- Specs in `src/specs/` define what each role's analysis tracks (uptimes, cast weighting). Add a new
  spec here and wire it into `resolveSpec`.

## Tests

```bash
pnpm --filter @menagerie/log-analyzer test       # process-fight + compare tests
pnpm --filter @menagerie/log-analyzer typecheck
```
