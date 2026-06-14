# Hunter Adaptive Simulator

Small offline harness for the Hunter adaptive rotation. It mirrors the timing
model in `apps/tbc-rotation/src/aio/hunter/adaptive.lua` closely enough to regression
test the failure modes that are painful to isolate in raid:

- base/RF windows should not create large Steady clips
- high-haste windows should not starve Steady
- `ULTRA` haste should tolerate more Steady clip than `BASE`

Run all built-in scenarios:

```powershell
corepack pnpm --filter @menagerie/tbc-rotation sim:hunter
```

Trace one scenario:

```powershell
corepack pnpm --filter @menagerie/tbc-rotation sim:hunter -- --trace ultra-15
```

Run an ad-hoc speed:

```powershell
corepack pnpm --filter @menagerie/tbc-rotation sim:hunter -- --speed 1.05 --duration 20
```

Disable spells or start them on cooldown:

```powershell
corepack pnpm --filter @menagerie/tbc-rotation sim:hunter -- --trace ultra-15 --no-arcane
corepack pnpm --filter @menagerie/tbc-rotation sim:hunter -- --trace ultra-15 --no-multi --no-arcane
corepack pnpm --filter @menagerie/tbc-rotation sim:hunter -- --trace ultra-15 --multi-start-cd 4
```

The simulator reads clip budgets directly from `adaptive.lua`, so bucket budget
edits show up without changing the harness. The bucket thresholds themselves are
still duplicated in the sim and should be kept in sync with `clipBudgetForSpeed`.
