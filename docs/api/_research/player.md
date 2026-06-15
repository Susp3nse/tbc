# Player Engine — Real Public API

**Source:** `/Users/traveler/Repos/tbc/docs/action/Modules/Engines/Player.lua` (1973 lines)
**Stub:** `/Users/traveler/Repos/tbc/docs/api/Player.lua`

## Registration / invocation

The engine is a **singleton table** created at line 450:

```lua
A.Player = { UnitID = "player" }
local Player = A.Player
```

Methods are defined as `function Player:Method(...)` and invoked as `Player:Method(...)`
or `A.Player:Method(...)`. `self.UnitID` is always `"player"`. The engine drives itself off a
local `Data` table updated by event `Listener`s (movement, casting, auras, shoot/attack, behind
UI errors, level, equip-swap lock, stance, glyphs) — these `Data.*` functions are **private**, not
part of the public API.

**Note on power functions:** All `*Max`, current, `*Percentage`, `*Deficit`, `*DeficitPercentage`
methods are thin wrappers over `UnitPowerMax`/`UnitPower(self.UnitID, <PowerType>)` and arithmetic.
They are **not cached** (live Blizzard API reads). The TBC build only really has Mana/Rage/Energy/
ComboPoints live; the retail-power methods (Focus, RunicPower, SoulShards, AstralPower, HolyPower,
Maelstrom, Chi, Insanity, ArcaneCharges, Fury, Pain, Essence) exist for cross-expansion source
compatibility and return 0 on TBC.

---

## Movement & State

| Method | Signature | Returns | Description |
|---|---|---|---|
| IsStance | `IsStance(x)` | boolean | True if current shapeshift form equals `x`. |
| GetStance | `GetStance()` | number | Current shapeshift form index (`Data.Stance`, from `GetShapeshiftForm()`). |
| IsFalling | `IsFalling()` | boolean, number | More accurate fall check (excludes jumps; only true after >1.7s falling). Multi-return: isFalling, secondsFalling. |
| GetFalling | `GetFalling()` | number | Seconds falling (`select(2, self:IsFalling())`). |
| IsMoving | `IsMoving()` | boolean | True if currently moving. |
| IsMovingTime | `IsMovingTime()` | number | Seconds since movement started (0 if stationary). |
| IsStaying | `IsStaying()` | boolean | True if currently stationary. |
| IsStayingTime | `IsStayingTime()` | number | Seconds since stopped moving (0 if moving). |
| IsMounted | `IsMounted()` | boolean | True if mounted, excluding druid travel/aquatic forms that read as mounted. |
| IsSwimming | `IsSwimming()` | boolean | `IsSwimming() or IsSubmerged()`. |
| IsStealthed | `IsStealthed()` | boolean | True if stealthed (incl. class prowl/stealth/vanish auras and NightElf Shadowmeld). |
| IsShooting | `IsShooting()` | boolean | Auto-shoot (auto-repeat) active. |
| IsAttacking | `IsAttacking()` | boolean | Melee auto-attack active (combat-log driven). |
| IsBehind | `IsBehind(x)` | boolean | True if player has been behind the target for `x` seconds (default 2.5), via UI-error tracking. |
| IsBehindTime | `IsBehindTime()` | number | Seconds since the last "not behind" UI error. |
| IsPetBehind | `IsPetBehind(x)` | boolean | True if pet behind target for `x` sec (default 2.5). |
| IsPetBehindTime | `IsPetBehindTime()` | number | Seconds since last pet "not behind" error. |
| TargetIsBehind | `TargetIsBehind(x)` | boolean | True if target is behind the player within `x` sec (default 2.5), guarded by target GUID. |
| TargetIsBehindTime | `TargetIsBehindTime()` | number | Seconds since target was behind player (GUID-guarded). |

---

## Casting & GCD

| Method | Signature | Returns | Description |
|---|---|---|---|
| IsCasting | `IsCasting()` | string\|nil | Name of the current non-channel cast, else nil. |
| IsChanneling | `IsChanneling()` | string\|nil | Name of the current channel, else nil. |
| CastTimeSinceStart | `CastTimeSinceStart()` | number | Seconds since the last cast-start event (`UNIT_SPELLCAST_START`/`CHANNEL_START`). |
| CastRemains | `CastRemains(spellID)` | number | Remaining cast time; delegates to `Unit:IsCastingRemains(spellID)`. `spellID` optional. |
| CastCost | `CastCost()` | number | Power cost of the spell currently being cast (real-time, **uncached**), else 0. |
| CastCostCache | `CastCostCache()` | number | Cached power cost of the spell currently being cast, else 0. |
| Execute_Time | `Execute_Time(spellID)` | number | `max(GCD, castTime)` for `spellID`. |
| GCDRemains | `GCDRemains()` | number | Remaining GCD (`A.GetCurrentGCD()`). |
| SpellHaste | `SpellHaste()` | number | Spell-haste multiplier `1/(1+haste%/100)`. |
| HastePct | `HastePct()` | number | Haste percent (`GetHaste()`). |
| CritChancePct | `CritChancePct()` | number | Melee crit chance percent (`GetCritChance()`). |

---

## Buffs / Auras on Self

| Method | Signature | Returns | Description |
|---|---|---|---|
| CancelBuff | `CancelBuff(buffName)` | nil | Cancels a buff via `CancelSpellByName` (only out of combat or if secure). |
| GetBuffsUnitCount | `GetBuffsUnitCount(...)` | number, number | For varargs (spellID / spellName / action object): [1] total units the listed buffs are applied to, [2] how many of the varargs were found applied. Combat-log tracked. |
| GetDeBuffsUnitCount | `GetDeBuffsUnitCount(...)` | number, number | Same as above but for debuffs the player applied. |

---

## Cooldowns / Swing / Totems

| Method | Signature | Returns | Description |
|---|---|---|---|
| GetSwing | `GetSwing(inv)` | number | Current swing time (s) for slot. `inv`: 1=mainhand, 2=offhand, 3=ranged, 4=max(main,off), 5=max(all), or a CONST slot. |
| GetSwingMax | `GetSwingMax(inv)` | number | Max/total duration of the last swing for that slot (same `inv` semantics). |
| GetSwingStart | `GetSwingStart(inv)` | number | Start timestamp of the last swing for that slot. |
| GetSwingShoot | `GetSwingShoot()` | number | Time remaining until next auto-shot tick (0 if none pending). |
| ReplaceSwingDuration | `ReplaceSwingDuration(inv, dur)` | nil | Overrides the tracked swing `duration` for the slot(s). |
| GetTotemInfo | `GetTotemInfo(i)` | boolean, string, number, number, string | Passthrough of `GetTotemInfo(i)`: haveTotem, name, startTime, duration, icon. |
| GetTotemTimeLeft | `GetTotemTimeLeft(i)` | number | Passthrough of `GetTotemTimeLeft(i)`. |
| Rune | `Rune(presence)` | number | Count of ready runes of `presence` (name/const) plus death runes; applies recovery offset. |
| RuneTimeToX | `RuneTimeToX(Value)` | number | Seconds until `Value`-th rune (1–6) is ready; errors if out of range. |

---

## Gear / Bags / Inventory / Tier sets

| Method | Signature | Returns | Description |
|---|---|---|---|
| AddTier | `AddTier(tier, items)` | nil | Registers a tier-set name → list of itemIDs to track equipped count. |
| RemoveTier | `RemoveTier(tier)` | nil | Unregisters a tier set. |
| GetTier | `GetTier(tier)` | number | Equipped piece count for a tier. |
| HasTier | `HasTier(tier, count)` | boolean | True if `>= count` pieces equipped (disabled in MoP Proving Grounds, ZoneID 480). |
| AddBag | `AddBag(name, data)` | nil | Registers a bag-item matcher (`itemID`/`itemEquipLoc`/`itemClassID`/`itemSubClassID`/`isEquippableItem`). |
| RemoveBag | `RemoveBag(name)` | nil | Unregisters a bag matcher. |
| GetBag | `GetBag(name)` | table\|nil | Match info `{ count, itemID }` or nil. |
| AddInv | `AddInv(name, slot, data)` | nil | Registers an equipped/inventory matcher. `slot` optional (nil scans all equipped slots). |
| RemoveInv | `RemoveInv(name)` | nil | Unregisters an inventory matcher. |
| GetInv | `GetInv(name)` | table\|nil | Match info `{ slot, itemID }` or nil. |
| IsSwapLocked | `IsSwapLocked()` | boolean | True while an equip swap is in progress (must be checked before any swap). |
| RegisterAmmo | `RegisterAmmo()` | nil | Registers arrow + bullet bag trackers (AMMO1/AMMO2). |
| RegisterThrown | `RegisterThrown()` | nil | Registers thrown-weapon bag tracker. |
| RegisterShield | `RegisterShield()` | nil | Registers shield bag + offhand inventory trackers. |
| RegisterWeaponOffHand | `RegisterWeaponOffHand()` | nil | Registers off-hand weapon trackers (5 bag subclasses + inv). |
| RegisterWeaponTwoHand | `RegisterWeaponTwoHand()` | nil | Registers two-hand weapon trackers (5 bag + 5 inv subclasses). |
| RegisterWeaponMainOneHandDagger | `RegisterWeaponMainOneHandDagger()` | nil | Registers main-hand dagger trackers. |
| RegisterWeaponMainOneHandSword | `RegisterWeaponMainOneHandSword()` | nil | Registers main-hand 1H sword trackers. |
| RegisterWeaponOffOneHandSword | `RegisterWeaponOffOneHandSword()` | nil | Registers off-hand 1H sword trackers. |
| GetAmmo | `GetAmmo()` | number | Remaining ammo (arrow or bullet, whichever found). |
| GetArrow | `GetArrow()` | number | Remaining arrows (0 if none). |
| GetBullet | `GetBullet()` | number | Remaining bullets (0 if none). |
| GetThrown | `GetThrown()` | number | Remaining thrown items (0 if none). |
| HasShield | `HasShield(isEquiped)` | number\|nil | itemID of shield in bag (default) or equipped (`isEquiped` true). |
| HasWeaponOffHand | `HasWeaponOffHand(isEquiped)` | number\|nil | itemID of off-hand weapon, bag or equipped. |
| HasWeaponTwoHand | `HasWeaponTwoHand(isEquiped)` | number\|nil | itemID of a two-hand weapon, bag or equipped. |
| HasWeaponMainOneHandDagger | `HasWeaponMainOneHandDagger(isEquiped)` | number\|nil | itemID of main-hand dagger, bag or equipped. |
| HasWeaponMainOneHandSword | `HasWeaponMainOneHandSword(isEquiped)` | number\|nil | itemID of main-hand 1H sword, bag or equipped. |
| HasWeaponOffOneHandSword | `HasWeaponOffOneHandSword(isEquiped)` | number\|nil | itemID of off-hand 1H sword, bag or equipped. |
| GetWeaponMeleeDamage | `GetWeaponMeleeDamage(inv, mod)` | number, number | White-hit weapon damage: [1] full avg damage, [2] avg DPS. `inv` 1=main, 2=off, nil=both; `mod` modifies attack speed (default 1). |
| AttackPowerDamageMod | `AttackPowerDamageMod(offHand)` | number | AP-based weapon damage modifier; `offHand` true uses off-hand stats. |

---

## Spec / Talents / Class / Glyphs

| Method | Signature | Returns | Description |
|---|---|---|---|
| HasGlyph | `HasGlyph(spell)` | boolean | True if glyph is active. `spell` = glyph spellName / spellID / glyphID (WOTLK–BFA builds). |

No spec/talent-detection methods live on the `Player` engine itself in TBC; class/spec lives on
`A.PlayerClass` / `A` globals (out of scope for this file).

---

## Resources — Mana

| Method | Signature | Returns | Description |
|---|---|---|---|
| ManaMax | `ManaMax()` | number | Max mana. |
| Mana | `Mana()` | number | Current mana. |
| ManaPercentage | `ManaPercentage()` | number | Mana %. |
| ManaDeficit | `ManaDeficit()` | number | Missing mana. |
| ManaDeficitPercentage | `ManaDeficitPercentage()` | number | Missing mana %. |
| ManaRegen | `ManaRegen()` | number | Mana/sec (`floor(GetPowerRegen)`). |
| ManaCastRegen | `ManaCastRegen(CastTime)` | number | Mana regained over `CastTime`; −1 if regen is 0. |
| ManaRemainingCastRegen | `ManaRemainingCastRegen(Offset)` | number | Mana regained over remaining cast (or GCD if not casting) + `Offset`; −1 if no regen. |
| ManaTimeToMax | `ManaTimeToMax()` | number | Seconds to full mana; −1 if no regen. |
| ManaTimeToX | `ManaTimeToX(Amount)` | number | Seconds to reach `Amount` mana; −1 if no regen, 0 if already there. |
| ManaP | `ManaP()` | number | Predicted mana after current cast (cost subtracted + cast regen, capped). |
| ManaPercentageP | `ManaPercentageP()` | number | Predicted mana %. |
| ManaDeficitP | `ManaDeficitP()` | number | Predicted missing mana. |
| ManaDeficitPercentageP | `ManaDeficitPercentageP()` | number | Predicted missing mana %. |

## Resources — Rage

| Method | Signature | Returns | Description |
|---|---|---|---|
| RageMax | `RageMax()` | number | Max rage. |
| Rage | `Rage()` | number | Current rage. |
| RagePercentage | `RagePercentage()` | number | Rage %. |
| RageDeficit | `RageDeficit()` | number | Missing rage. |
| RageDeficitPercentage | `RageDeficitPercentage()` | number | Missing rage %. |

## Resources — Focus

| Method | Signature | Returns | Description |
|---|---|---|---|
| FocusMax / Focus / FocusPercentage / FocusDeficit / FocusDeficitPercentage | `()` | number | Standard power accessors. |
| FocusRegen | `FocusRegen()` | number | Focus/sec. |
| FocusRegenPercentage | `FocusRegenPercentage()` | number | Regen as % of max. |
| FocusTimeToMax | `FocusTimeToMax()` | number | Seconds to full; −1 if no regen. |
| FocusTimeToX | `FocusTimeToX(Amount)` | number | Seconds to reach `Amount`. |
| FocusTimeToXPercentage | `FocusTimeToXPercentage(Amount)` | number | Seconds to reach `Amount`%. |
| FocusCastRegen | `FocusCastRegen(CastTime)` | number | Focus regained over `CastTime`. |
| FocusRemainingCastRegen | `FocusRemainingCastRegen(Offset)` | number | Focus over remaining cast/GCD + `Offset`. |
| FocusLossOnCastEnd | `FocusLossOnCastEnd()` | number | Focus cost of the in-progress cast (else 0). |
| FocusPredicted | `FocusPredicted(Offset)` | number | Predicted focus at cast/GCD end. |
| FocusDeficitPredicted | `FocusDeficitPredicted(Offset)` | number | Predicted deficit. |
| FocusTimeToMaxPredicted | `FocusTimeToMaxPredicted()` | number | Predicted time to max. |

## Resources — Energy

| Method | Signature | Returns | Description |
|---|---|---|---|
| EnergyMax / Energy / EnergyPercentage / EnergyDeficit / EnergyDeficitPercentage | `()` | number | Standard accessors. |
| EnergyRegen | `EnergyRegen()` | number | Energy/sec. |
| EnergyRegenPercentage | `EnergyRegenPercentage()` | number | Regen as % of max. |
| EnergyTimeToMax | `EnergyTimeToMax()` | number | Seconds to full. |
| EnergyTimeToX | `EnergyTimeToX(Amount, Offset)` | number | Seconds to `Amount` energy; `Offset` scales the effective regen rate. |
| EnergyTimeToXPercentage | `EnergyTimeToXPercentage(Amount)` | number | Seconds to `Amount`%. |
| EnergyRemainingCastRegen | `EnergyRemainingCastRegen(Offset)` | number | Energy over remaining cast/channel/GCD + `Offset`. |
| EnergyPredicted | `EnergyPredicted(Offset)` | number | Predicted energy at cast/GCD end (capped). |
| EnergyDeficitPredicted | `EnergyDeficitPredicted(Offset)` | number | Predicted deficit (floored at 0). |
| EnergyTimeToMaxPredicted | `EnergyTimeToMaxPredicted()` | number | Predicted time to max. |

## Resources — Combo Points

| Method | Signature | Returns | Description |
|---|---|---|---|
| ComboPointsMax | `ComboPointsMax()` | number | Max combo points. |
| ComboPoints | `ComboPoints(unitID)` | number | CP on `unitID` (default `"target"`) via `GetComboPoints`. |
| ComboPointsDeficit | `ComboPointsDeficit(unitID)` | number | Missing CP. |

## Resources — Other Powers (retail-compat; mostly 0 on TBC)

| Method | Signature | Returns | Description |
|---|---|---|---|
| RunicPowerMax / RunicPower / RunicPowerPercentage / RunicPowerDeficit / RunicPowerDeficitPercentage | `()` | number | Death-knight runic power accessors. |
| SoulShardsMax / SoulShards / SoulShardsDeficit | `()` | number | Warlock soul shards. |
| SoulShardsP | `SoulShardsP()` | number | Predicted shards (default = current; overridden per spec). |
| AstralPowerMax | `AstralPowerMax()` | number | Max astral power (LunarPower). |
| AstralPower | `AstralPower(OverrideFutureAstralPower)` | number | Current AP, or the override value if passed. |
| AstralPowerPercentage | `AstralPowerPercentage(OverrideFutureAstralPower)` | number | AP %. |
| AstralPowerDeficit | `AstralPowerDeficit(OverrideFutureAstralPower)` | number | Missing AP. |
| AstralPowerDeficitPercentage | `AstralPowerDeficitPercentage(OverrideFutureAstralPower)` | number | Missing AP %. |
| HolyPowerMax / HolyPower / HolyPowerPercentage / HolyPowerDeficit / HolyPowerDeficitPercentage | `()` | number | Paladin holy power accessors. |
| MaelstromMax / Maelstrom / MaelstromPercentage / MaelstromDeficit / MaelstromDeficitPercentage | `()` | number | Shaman maelstrom accessors. |
| ChiMax / Chi / ChiPercentage / ChiDeficit / ChiDeficitPercentage | `()` | number | Monk chi accessors. |
| StaggerMax | `StaggerMax()` | number | = `Unit:HealthMax()`. |
| Stagger | `Stagger()` | number | `UnitStagger`. |
| StaggerPercentage | `StaggerPercentage()` | number | Stagger as % of max health. |
| InsanityMax / Insanity / InsanityPercentage / InsanityDeficit / InsanityDeficitPercentage | `()` | number | Shadow priest insanity accessors. |
| Insanityrain | `Insanityrain()` | number | Insanity **drain** rate from Voidform stacks (note the typo'd name). |
| ArcaneChargesMax / ArcaneCharges / ArcaneChargesPercentage / ArcaneChargesDeficit / ArcaneChargesDeficitPercentage | `()` | number | Arcane mage charges. |
| FuryMax / Fury / FuryPercentage / FuryDeficit / FuryDeficitPercentage | `()` | number | Demon hunter fury. |
| PainMax / Pain / PainPercentage / PainDeficit / PainDeficitPercentage | `()` | number | Vengeance DH pain. |
| EssenceMax / Essence / EssenceDeficit / EssenceDeficitPercentage | `()` | number | Evoker essence. |

## Resource Maps (table fields, not methods)

| Field | Type | Description |
|---|---|---|
| `Player.UnitID` | string | Always `"player"`. |
| `Player.PredictedResourceMap` | table | `[powerType] → function` returning the predicted value for that power (-2 health, -1 generic, 0 mana … 18 pain). |
| `Player.TimeToXResourceMap` | table | `[powerType] → function(Value)` returning time-to-X; most non-regen powers return nil. |

---

## Stub discrepancies

**Systemic issues with the auto-generated stub:**

1. **Pervasive `any` params.** Every parameter is typed `any` and marked optional (`?`), even where
   the body shows a concrete type and required usage (e.g. `IsStance(x)` x is a number; `AddTier(tier, items)`
   are string + table[]; `RuneTimeToX(Value)` errors unless 1–6). Real param types are recoverable
   from the source and listed above.

2. **`...` varargs lost.** `GetBuffsUnitCount` / `GetDeBuffsUnitCount` are documented `()` with no
   params; they actually take varargs of spellID / spellName / action object. Both return
   `number, number` (units, count) — the multi-return is at least captured.

3. **Nil-union returns flattened.** Many methods can return `nil`: `IsCasting`/`IsChanneling`
   (`string|nil`, stub says `string`), `GetBag`/`GetInv` (`table|nil`, stub says `table`), all the
   `HasWeapon*`/`HasShield` (`number|nil` itemID, stub says `number`).

4. **Missing/garbled methods.** The stub omits the live combat methods `Player:GetWeaponMeleeDamage`
   is present but `Player:Runes()` (referenced in `PredictedResourceMap[5]` and `TimeToXResourceMap`)
   is **never defined in this file** — likely provided by a spec/class override; the stub's `Rune`
   (singular) is the only one present. The Insanity drain method is misnamed **`Insanityrain`** in
   source (missing the "D") — the stub faithfully copies the typo.

**High-value methods whose real signature/return differs notably from the stub:**

- `IsFalling()` → real return is **`boolean, number`** (the stub gets this right, but `GetFalling`
  is the documented single-value accessor — worth noting they share an implementation).
- `GetTotemInfo(i)` → `haveTotem(bool), name(string), startTime(number), duration(number), icon(string)` — accurate in stub.
- `CastRemains(spellID)` → `spellID` is **optional**; with no arg it returns the current cast's remaining time.
- `ComboPoints(unitID)` → defaults `unitID` to `"target"`; not arbitrary.
- `EnergyTimeToX(Amount, Offset)` → `Offset` is a **regen-rate multiplier** `(1 - Offset)`, not a flat time offset like the other `*TimeToX` methods — easy to misuse.
- `AstralPower(OverrideFutureAstralPower)` → the arg, if truthy, is returned verbatim (override), bypassing the live read.
- `Insanityrain()` → returns a **drain rate** (units/sec) derived from Voidform stacks, not a resource amount; stub return `any` and method is misspelled.

**Caching wrappers:** `CastCost()` is explicitly the **uncached** real-time cost; `CastCostCache()`
is the cached counterpart. All power/resource accessors are uncached live API reads.
