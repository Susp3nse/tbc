# Platform Audit — Making the Chrome "Set in Stone" so Classes Just Write Rotations

> Date: 2026-06-14. Read-only investigation by a 4-agent team. Goal: find functionality that is
> still Hunter-only-but-should-be-shared, still duplicated 9×, or quietly leaking memory — so a
> class author writes a *rotation*, not architecture.
>
> Detail lives in the sibling files; this is the synthesis + recommended sequence.
> - `01-duplication.md` — cross-class duplication that should hoist to `common`/`core`
> - `02-diagnostics.md` — Hunter tooling that should become shared platform infra
> - `03-performance.md` — memory leaks + hot-path allocations
> - `04-ergonomics.md` — boilerplate a class author is forced to write

## Headline

The architecture is **sound and already absorbs most boilerplate** — the registry, the shared
schema `SECTIONS`, the recovery/trinket middleware factories, and the just-extracted shared debug
panel are exactly the right pattern. The debug-panel extraction (Hunter → shared, class supplies a
`build_sections(out, ctx)` callback) is the *template* for everything below. No re-architecture is
needed. The residual work is: (a) one urgent memory fix, (b) finish applying patterns that already
exist but aren't used everywhere, and (c) graduate three more Hunter panels onto the shared
panel/window infrastructure.

## Cross-corroborated themes (flagged by ≥2 agents → highest confidence)

1. **Interrupt middleware is hand-rolled in 6/9 classes** — flagged independently by the duplication
   audit (#4) and the ergonomics audit (#5). The simple 4 (mage/rogue/priest/paladin) differ only
   by spell + setting key; warrior/shaman are genuinely complex and stay bespoke (opt-out).
2. **Trinket middleware is opt-in but called by 9/9** — duplication + ergonomics both say make it
   auto-register (opt-out), along with the universal `burst()/dashboard()/debug()` schema tail.
3. **The Hunter adaptive panel is both a duplication target and the #1 perf issue** — diagnostics
   audit (A) wants it on the shared panel widget; perf audit (#1) found its decision-log is the
   single largest sustained GC source. These fixes converge: route the panel through shared infra
   and gate the log buffer.

## Ranked, cross-cut action list

| # | Action | Source | Payoff | Risk | Why now |
|---|--------|--------|--------|------|---------|
| 1 | **Gate `logDecision` on `show_adaptive_panel`** | perf #1 | High | Trivial | Only allocation that scales with fight length on a per-frame path; one-line guard. |
| 2 | **`NS.ShowCopyWindow(title,text)`** — collapse the 2 near-identical export windows | diag B | Med | Zero | Pure dedup, do-first warmup for the panel work. |
| 3 | **Rewrite `NEW_CLASS_GUIDE.md`** — it teaches obsolete boilerplate the platform already absorbed | ergo #1 | High | Zero (docs) | Halves *perceived* boilerplate with no code change; stops new classes copying dead patterns. |
| 4 | **`Menagerie_SECTIONS.immunity()/cooldowns()/spec(opts)`** — 3 byte-identical General-tab sections in 9/9 | dup #3 / ergo #6 | High | Low | Same proven factory pattern as the existing 6 SECTIONS. |
| 5 | **`NS.register_consumable_actions(A)`** — 8 item Actions with literal IDs re-typed in all 9 `class.lua` | dup #2 | Med | Low | Wrong-ID-in-one-class is a silent bug today. |
| 6 | **`NS.create_racial_strategy` — migrate the ~8 hand-rolled spec files** to the existing factory | dup #1 | Med | Low-Med | Factory already exists; 5/9 use it, the rest hand-roll ~200 lines. |
| 7 | **`NS.CreateLivePanel{title,setting_key,build,export}`** — extract adaptivepanel's window/row code | diag A | High | Med | The shared debug panel already solved this data-driven + alloc-free; unlocks live panels for all 9 classes. Pairs with #1, #2. |
| 8 | **`register_interrupt_middleware{spell,setting}`** — covers the simple 4 classes | dup #4 / ergo #5 | Med | Med | Verify against any sim paths; warrior/shaman opt out. |
| 9 | **Registry-owned context cache reset** (epoch counter) — kills the 26 hand-written `ctx._x_valid=false` resets | ergo #3 | Med | Med | Forgetting one silently serves stale combat state every frame — deletes a bug class. |
| 10 | **`learned_immune` empty-bucket prune** + **ClipLog cap/wrap** | perf #2, #3 | Low | Trivial | Real but tiny unbounded growth; one-line each. |
| 11 | **Auto-register trinket + universal schema tail (opt-out)** | dup / ergo #6 | Med | Low | Removes a required-but-identical call from every class. |
| 12 | **Theme consolidation** — 3 Hunter panels hardcode a stale cold-blue palette pre-rebrand | diag D | Low | Low | Falls out of #7 for free; fixes off-brand windows. |

**Deferred (correctly one-consumer today — don't abstract speculatively):** generalizing the
cliptracker *detector* (diag C — wait for a 2nd auto-attack class), the meleeweave traffic-light
*coach* (diag E — 95% irreducible Hunter math), and the HP-threshold defensive middleware factory
(dup #5 — per-class gate variance, needs sim verification).

## Suggested execution order

**Quick wins first (low risk, high clarity):** #1 → #2 → #3 → #10. These are small, independent,
and #3 alone changes the new-author experience the most.

**Then the factory absorptions:** #4 → #5 → #6 → #11. Pure "apply the pattern that already exists."

**Then the platform infra:** #7 (CreateLivePanel) is the keystone — it pairs with #1/#2/#12 and is
the thing that makes *every future class* get a live decision panel for free. #8 and #9 are the
higher-touch items; do them deliberately with sim/regression checks.

This sequence front-loads safe, visible wins and defers anything needing rotation-behavior
verification to the end.
