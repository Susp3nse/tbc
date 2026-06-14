# DRY Readability Pass Verification Notes

- Date: 2026-06-14
- Plan: `docs/plans/2026-06-14-dry-readability-plan.md`
- Status: implementation and automated verification complete; manual in-game smoke not performed in this environment.

## Automated evidence

- `corepack pnpm --filter @flux/tbc-rotation build` passed and wrote `apps/tbc-rotation/output/TellMeWhen.lua`.
- `corepack pnpm --filter @flux/tbc-rotation lint:lua` passed with `0 warnings / 0 errors in 70 files`.
- `corepack pnpm --filter @flux/tbc-rotation sim:hunter` matched the pre-change baseline exactly.
- `corepack pnpm check` passed.
- `corepack pnpm test` passed.
- `git diff --check` passed.
- `corepack pnpm --filter @flux/tbc-rotation build:sync` was attempted and failed before sync because `builder.config.local.json` is absent:
  `Error: --sync requires builder.config.local.json with "accounts" or "paths.savedvariables"`.
- A temporary `ROTATION_ROOT` copy with a throwaway `builder.config.local.json` and SavedVariables path synced successfully through `node apps/tbc-rotation/dist/build.js --sync`.
  The generated throwaway SavedVariables file contained `NS.BUILD_NUMBER = 1` and profile entries for `Flux Druid` through `Flux Warrior`.
- `ps aux | rg -i "World of Warcraft|Wow|warcraft|tbc"` found no running WoW client process.

## Requirement audits

- P1 residual `context.ttd < min_ttd` sites are limited to the shared predicate, the 3 rogue rupture gates, and the warrior shout gate.
- P3 old recovery keys are absent from runtime code except the 4-key migration table:
  hunter `use_mana_rune` -> `use_dark_rune`, hunter `mana_rune_mana` -> `dark_rune_pct`,
  druid `mana_potion_mana` -> `mana_potion_pct`, druid `dark_rune_mana` -> `dark_rune_pct`.
- P3 factory override hatches remain in the shared factory, but initial class wiring does not use `skip_stealthed = false` or `require_exists = false`.
- P4 has exactly 10 migrated `create_racial_strategy(...)` call sites outside `core.lua`.
- P5 R-c stayed dropped/rescoped; `dashboard.lua` still keeps the hand-tuned `content_y = -40`.

## Manual in-game smoke still required

1. Create `apps/tbc-rotation/builder.config.local.json` from `builder.config.local.example.json` and point it at the live TMW SavedVariables file.
2. Start `corepack pnpm --filter @flux/tbc-rotation watch` for an incrementing `NS.BUILD_NUMBER`, or run `corepack pnpm --filter @flux/tbc-rotation build:sync` for a one-shot sync.
3. In game, run `/reload` and confirm the printed `Build:` number advanced from the previously loaded build.
4. Migration scenario:
   - Seed hunter old keys: `use_mana_rune=false`, `mana_rune_mana=15`.
   - Seed druid old key: `dark_rune_mana=22`.
   - `/reload`.
   - Confirm hunter `use_dark_rune=false`, hunter `dark_rune_pct=15`, druid `dark_rune_pct=22`, and the old keys are cleared.
   - `/reload` again and confirm the values do not change.
5. Recovery spot checks:
   - For a factory-wired class, set recovery thresholds above current HP/mana and confirm the expected Healthstone, potion, or rune middleware fires with the original name/log label.
   - Confirm recovery does not fire while stealthed and does not fire out of combat.
   - Confirm rune use respects `dark_rune_min_hp`.
6. Force/burst smoke:
   - `/flux burst` still force-fires burst-tagged entries when ready.
   - `/flux def` still force-fires defensive entries when ready.
   - Auto-burst disabled still blocks unforced burst entries.
7. Racial smoke:
   - For migrated racial classes, confirm firing order and log tags match the original strategy order.
   - Confirm excluded outliers remain bespoke: mage arcane burn gate, shaman restoration no burst flag, priest availability guards, and paladin HP/heal-target gates.
