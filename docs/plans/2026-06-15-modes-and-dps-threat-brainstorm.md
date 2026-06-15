# Modes Axis + DPS Threat Management — Brainstorm

**Date:** 2026-06-15
**Status:** Brainstorm / exploration — not a build spec
**Companion to:** `2026-06-15-role-services-design.md` (the Role Services layer this builds on)
**Scope:** Two new ideas — (1) **modes** (solo / dungeon / raid / pvp / leveling) as an axis *orthogonal*
to roles, and (2) the **DPS threat-management service** ("should I hit this target?") as the first
concrete piece of the DPS role.

> **Note (2026-06-15):** Druid Bear has since been migrated onto the shared `make_threat_tab` factory
> (commit `c7f5d1b`) — all three melee tanks already share the threat brain. §4's "tank service shipped"
> framing holds; the build order lives in `2026-06-15-role-engines-build-plan.md`.

---

## 0. TL;DR

- Add a **mode** axis: `solo | dungeon | raid | pvp | leveling`. It is **orthogonal** to role
  (tank/heal/dps) and to spec. A mode is a *policy/heuristic swap inside a role service*, **not** a new
  module tree. Most logic is shared; the mode only tweaks thresholds, target ranking, and which
  behaviors switch on.
- Resolve mode once per frame onto `context.mode`, from a small **rules engine** (`IsInInstance()` +
  group composition) with a **settings dropdown** (`Auto` + manual override).
- Build the **DPS threat service** first: a query `Roles.DPS.should_attack(context)` /
  `threat_headroom(context)` answered by `UnitDetailedThreatSituation` (already used in
  `protection.lua`). In group modes it throttles/suggests a target swap before you rip threat off the
  tank; in solo/pvp it's a no-op or a different ranking entirely. The class still owns *what to press*.
- **Don't** conditionally *load* role modules — conditionally *consume* them. A class declares the roles
  it supports and only registers those adapters; unused shared factories cost ~nothing (see §6).

---

## 1. The big picture: three axes, not one

Today the rotation is selected on one axis: **playstyle/spec** (ret/prot/holy, ele/enh/resto). The full
model the user is describing is actually **three independent axes** that compose:

```
   MODE  ×  ROLE  ×  SPEC  →  the buttons a class presses
 (situation) (job)  (kit)
```

- **Mode** = *what situation am I in* → solo / dungeon / raid / pvp / leveling. Sets the **policy**:
  how aggressive, what to prioritize, what to protect.
- **Role** = *what is my job* → tank / heal / dps. Owns *who* (target/situation assessment) — the Role
  Services from the companion doc.
- **Spec** = *what is my kit* → the existing playstyle. Owns *what* (the actual spell choices).
- **Class** = the actions/buttons.

Crucially these are **independent**: a Holy Paladin (role=heal) can be in dungeon mode or raid mode; the
*role service* answers "who needs healing" the same way, but the *mode* changes the heuristic (5-man
triage vs 25-man assignment). So mode doesn't multiply the codebase — it's a parameter threaded through
the services that already exist.

This generalizes the "PvP = a mode flag on the query, not a parallel module" idea already in the
companion doc (§8). PvP was the first mode; the user is right that there's a whole family.

---

## 2. The mode axis

### What a "mode" actually is

A mode is **a small bundle of policy values + heuristic choices** that a role service reads. It is *not* a
separate implementation. Concretely, a role service method branches on `context.mode` to pick:

- thresholds (threat ceiling %, heal-urgency cutoffs, AoE target counts),
- ranking heuristics (assist-tank vs free target; lowest-HP vs assignment),
- which sub-behaviors are enabled (taunt rotation on/off, threat throttle on/off).

### The role × mode matrix (what changes where)

| | **solo** | **dungeon (5)** | **raid (10/25)** | **pvp** | **leveling** |
|---|---|---|---|---|---|
| **tank** | rare (self-pull) | pick up loose mobs, taunt off DPS/healer, threat-tab | threat equalization, tank assignment, big-pull control | duel/BG bruiser | pull packs efficiently, survive |
| **heal** | self/pet only | 5-man triage (lowest effective HP) | 25-man: assignment, raid-wide vs tank, mana economy | focus self/ally, dispel priority, LoS | efficient, low downtime |
| **dps** | free — hit anything | **threat-capped** + assist tank's kill target | **threat-capped** (higher stakes) + kill order | target priority (healers/squishies), no threat | efficient, survival-first |

The **green thread** through every cell of the dps row is the same service — only the *threat policy* and
*target ranking* differ. That's the proof modes are parameters, not modules.

### Resolving the mode (rules engine + override)

Resolve once per frame → `context.mode`. The cleanest signal is **`IsInInstance()`** (returns
`inInstance, instanceType` where `instanceType ∈ {none, party, raid, pvp, arena, scenario}`), refined by
group composition:

```
setting "rotation_mode" = Auto | Solo | Dungeon | Raid | PvP | Leveling   (default Auto)

if setting ~= Auto: context.mode = setting           -- manual wins
else:
   local _, itype = IsInInstance()
   if itype == "arena" or itype == "pvp"          then mode = "pvp"
   elseif itype == "raid"                          then mode = "raid"
   elseif itype == "party"                         then mode = "dungeon"
   elseif IsInRaid()                               then mode = "raid"      -- outdoor raid (world boss)
   elseif IsInGroup()                              then mode = "dungeon"   -- outdoor group
   elseif (UnitLevel("player") < MAX_LEVEL)        then mode = "leveling"
   else                                                 mode = "solo"
```

Notes / open questions:
- `IsInInstance` is a better primary signal than raw group size (handles 5-man-as-raid, outdoor raids).
- Group size can sub-split raid into 10 vs 25 *if* a policy ever needs it (probably not at first — keep
  `raid` singular until something demands the split).
- Always keep the **manual dropdown** — auto-detect will be wrong sometimes (world bosses, premade
  testing, "I'm leveling but in a dungeon"). Manual override is the escape hatch, same philosophy as
  `playstyle` being a setting, not pure detection.
- Mode is **global**, not per-role (you're in one situation at a time). The *role* you're playing is
  already your spec.

---

## 3. DPS threat management — the first concrete build

This is the buildable near-term piece. It's a **query service** (answers "should I hit this?"), with the
class still owning the actual button (which dump, whether to soft-cast).

### The question

> *As a non-tank in a group, am I about to pull this mob off the tank — and if so, what should I do?*

### The primitive (already in use)

`UnitDetailedThreatSituation("player", target)` → `isTanking, status, scaledPercent, rawThreat,
threatValue`. **`scaledPercent`** is the gold: your threat as a percentage of the amount needed to pull
(100 = melee pull, 130 = ranged pull). `protection.lua` already calls this API, so it's available here.

### The policy per mode

| mode | DPS threat policy |
|---|---|
| solo / leveling | **off** — you have aggro by design; `should_attack` always true |
| dungeon | **throttle near ceiling.** Above `dps_threat_soft` (e.g. 80%): stop *non-essential* GCDs / hard casts. Above `dps_threat_hard` (e.g. 90%): suggest swap to a lower-threat mob (if mode allows multi-target) or hold. |
| raid | same shape, **lower ceiling / earlier throttle** (a boss pull = a wipe). Bias toward the assigned kill target; respect tricks/MD windows (class-owned). |
| pvp | **not threat at all** — `should_attack` becomes target-priority (focus healers, kill squishies, LoS). Different heuristic, same entry point. |

### The queries (what strategies call)

```lua
-- Headroom: how close am I to pulling? (nil in solo/pvp = "don't care")
local pct = NS.Roles.DPS.threat_headroom(context)        -- scaledPercent or nil

-- The gate most DPS strategies wrap their matches() in:
if not NS.Roles.DPS.should_attack(context) then return false end  -- false = back off this GCD

-- Dungeon multi-target: is there a better mob to spend threat on right now?
local swap = NS.Roles.DPS.suggest_target(context)        -- unit or nil
```

`should_attack` returns false when over the hard ceiling *and* the class has no cheaper option — the
strategy then yields the GCD (or the class's threat-dump middleware, see below, fires instead).

### How the pieces split (query vs act)

- **Service (shared):** the threat math, the ceiling policy per mode, the target-swap *suggestion*.
- **Middleware (class, mostly existing):** the actual **threat dump** — Feign Death / Soulshatter /
  Feint / Fade — already designed in `2025-02-25-shared-middleware-design.md` §2. The service answers
  "you're overthreat"; the dump middleware acts. Two halves of the same feature.
- **Class strategies:** decide *which* spell to soften to (e.g. cast a lower-threat filler) and own any
  spec-specific threat tech.

### Why this is the right first slice

It's high-value (prevents wipes / tank frustration), it reuses an API already wired in, it has a crisp
WHO/WHAT boundary, and it's the seed that forces `context.mode` into existence — which unlocks the rest of
the mode axis. Build the dungeon policy first (most common), then raid (tweak thresholds), then pvp
(different heuristic), leaving solo/leveling as the trivial no-op default.

---

## 4. The "tanking gets all the threat / dps manages it" symmetry

The user framed it well: **tanking maximizes threat, dps caps it, healing stays under both.** The Role
Services make this a clean duality:

- **Tank service** (`make_threat_tab`, already shipped): "go *get* threat — grab the loose mob, taunt
  what slipped." Maximize.
- **DPS service** (§3, new): "stay *under* the tank's threat — throttle/swap before you pull." Cap.
- **Heal service** (shipped): implicitly threat-aware via `unit_has_aggro` already decorated on targets;
  in raid mode this becomes assignment-aware.

Same threat API, three role-specific intents, mode-tuned ceilings. That symmetry is a good north star and
a good sanity check: if a proposed method doesn't fit "get threat / cap threat / heal under threat," it
probably belongs in the class, not the service.

---

## 5. Composition: how a frame actually resolves

```
A[3](icon)                      -- main.lua dispatcher (unchanged)
  └─ create_context(icon)
       ├─ context.mode  = resolve_mode(setting, IsInInstance, group)   -- NEW, once per frame
       └─ class extend_context(ctx)                                     -- existing
  └─ middleware  (recovery, dispels, interrupts, threat-DUMP)           -- existing + dump
  └─ strategies for active spec
       └─ each strategy.matches() may ask a role service:
            heal:  NS.Roles.Healing.lowest(context)        -- mode tunes urgency
            tank:  NS.Roles.Tanking.should_switch(context) -- mode tunes pickup vs equalize
            dps:   NS.Roles.DPS.should_attack(context)      -- mode tunes threat ceiling
```

No new dispatch stage. `context.mode` is just another field; services branch on it. The existing
middleware→strategy flow is untouched. This is the whole point of keeping modes as *parameters*.

---

## 6. Loading & "don't load modules the class can't use" (pushback)

The user wants unused role modules not loaded (e.g. no tanking module for a Mage) and load order
optimized. Two clarifications:

1. **The build is one concatenated file** (`output/TellMeWhen.lua`), loaded by static `loadOrder`. There
   is no runtime module loader; "not loading" a shared file isn't a runtime decision. So the lever is
   **build-time inclusion + registration-time consumption**, not dynamic loading.
2. **Defining an unused factory costs ~nothing.** `make_threat_tab` etc. are just function definitions on
   `NS`; the work happens only when a class *calls* them. A Mage that never calls the tanking service
   pays only the one-time cost of the definition existing (a few KB, parsed once at load). Nine *copies*
   would be the problem — one shared definition consumed selectively is the fix, and that's already how
   `make_threat_tab` works.

**So the real mechanism is declaration, not loading.** Extend `register_class`:

```lua
register_class({
   name = "Paladin",
   roles = { "healing", "tanking", "dps" },   -- which role services this class adapts
   ...
})
-- Each class's <role>.lua registers its adapter ONLY for roles in that list.
-- A class with roles = {"dps"} never registers a tank adapter → tank service idle for it.
```

If we later want to *physically* drop a service from a class's build, the build layer could include role
service files per-class based on `roles` — but that's a build optimization for output size, not a
runtime/perf need. **Recommendation:** start with registration-time consumption (zero build changes);
revisit per-class file inclusion only if output size becomes a real concern.

---

## 7. Risks, tensions, open questions

| Topic | Note / open question |
|---|---|
| Combinatorial blowup | The whole bet is "mode = policy params, not module trees." Police this hard: a mode should be ~a table of thresholds + a couple of heuristic branches, never a forked service. If a mode needs its own 200-line implementation, reconsider. |
| Auto-detect wrong | World bosses, outdoor raids, premades, dungeon-while-leveling. Mitigation: `IsInInstance` primary signal + always-available manual dropdown. |
| Raid 10 vs 25 | Keep `raid` singular until a policy genuinely needs the split. Group size is available if so. |
| Threat ceiling tuning | `dps_threat_soft`/`dps_threat_hard` defaults need real numbers (start ~80/90% melee, lower for raid). Sim/log validation. |
| pvp "should_attack" is a different shape | It returns target-priority, not threat. Same method name, mode-branched body — or a separate `Roles.PvP` service? Lean toward one DPS service with a pvp branch until pvp grows enough to warrant its own home. |
| Settings surface | One global `rotation_mode` dropdown (Auto + 5 modes). Per-role threshold keys live in the shared role schema sections (companion doc §10). |
| `context.mode` consumers | Dashboard/debug panel should *show* the resolved mode (cheap, high-value for "why is it doing that?"). |
| Mode-change churn | Mode can flip mid-session (zone in/out). Services must read `context.mode` live, never capture it — same rule as settings. |

---

## 8. Suggested staging (folds into the companion doc's §11)

1. **Introduce `context.mode`** + the resolve rules engine + the `rotation_mode` setting (Auto default).
   Show it on the dashboard. Behavior-neutral until something reads it.
2. **DPS threat service — dungeon policy** (`should_attack` / `threat_headroom`). Wire one DPS spec's
   strategies to gate on it; validate it actually holds threat in a 5-man.
3. **Raid policy** = threshold tweak on the same service.
4. **Wire threat-dump middleware** (from the 2025 shared-middleware design) as the "act" half.
5. **PvP branch** when a pvp playstyle ships.
6. **Mode-tune the heal & tank services** (5-man vs 25-man heuristics) — last, lowest urgency, since both
   already work mode-agnostically today.

---

## 9. Assumptions I'm making

```
1. Mode is a GLOBAL, single-valued situation (you're in one at a time), resolved onto context.mode —
   not a per-role selection. Role = your spec; mode = your environment.
2. Modes are POLICY PARAMETERS threaded through the existing role services, NOT separate module trees.
   If you actually picture full separate implementations per mode, that's a much heavier design — flag it.
3. Auto-detect is best-effort (IsInInstance + group comp) with a manual override that always wins.
   Same "spec is a setting, detection assists" philosophy already in the codebase.
4. "Don't load unused modules" is satisfied by registration-time consumption (class declares its roles),
   not by dynamic/per-class file loading — because the build is one static concatenated file and unused
   factory definitions are ~free. Correct me if you specifically want per-class build trimming.
5. This is a brainstorm to align direction. The first buildable slice (context.mode + DPS dungeon threat)
   would get its own -impl.md when greenlit.
→ Push back on any of these before code.
```

## See also

- `2026-06-15-role-services-design.md` — the Role Services layer (healing/tanking shipped, dps is the gap).
- `2025-02-25-shared-middleware-design.md` — the threat-DUMP middleware that pairs with §3's threat query.
- `core.lua` `UnitThreatSituation` / `make_threat_tab`; `protection.lua` `UnitDetailedThreatSituation`
  (the threat primitives this reuses).
