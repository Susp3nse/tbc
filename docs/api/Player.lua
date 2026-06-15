---@meta
--- GGL Action Framework - Player System Stubs
--- Singleton engine: `self.UnitID` is always "player". Invoke as `A.Player:Method(...)`.
---
--- Power-accessor note: all *Max / current / *Percentage / *Deficit / *DeficitPercentage methods are
--- thin uncached wrappers over UnitPowerMax/UnitPower + arithmetic. On TBC only Mana/Rage/Energy/
--- ComboPoints are live; the retail-compat powers (Focus, RunicPower, SoulShards, AstralPower,
--- HolyPower, Maelstrom, Chi, Insanity, ArcaneCharges, Fury, Pain, Essence) exist for cross-expansion
--- source compatibility and return 0 on TBC.

---@class Player
local Player = {}

--- Register bag tracking
---@param name string Matcher name.
---@param data table Matcher spec (itemID / itemEquipLoc / itemClassID / itemSubClassID / isEquippableItem).
---@return nil
function Player:AddBag(name, data) end

--- Register inv slot
---@param name string Matcher name.
---@param slot? number Inventory slot; nil scans all equipped slots.
---@param data table Matcher spec.
---@return nil
function Player:AddInv(name, slot, data) end

--- Register tier set
---@param tier string Tier-set name.
---@param items number[] itemIDs to track equipped count.
---@return nil
function Player:AddTier(tier, items) end

--- Current charges (retail-compat; 0 on TBC).
---@return number
function Player:ArcaneCharges() end

---@return number
function Player:ArcaneChargesDeficit() end

---@return number
function Player:ArcaneChargesDeficitPercentage() end

--- Max charges (retail-compat; 0 on TBC).
---@return number
function Player:ArcaneChargesMax() end

---@return number
function Player:ArcaneChargesPercentage() end

--- Current astral power, or the override value if `OverrideFutureAstralPower` is truthy (returned
--- verbatim, bypassing the live read). Retail-compat; 0 on TBC.
---@param OverrideFutureAstralPower? number Override value returned as-is when truthy.
---@return number
function Player:AstralPower(OverrideFutureAstralPower) end

--- Missing AP (retail-compat; 0 on TBC).
---@param OverrideFutureAstralPower? number Override value when truthy.
---@return number
function Player:AstralPowerDeficit(OverrideFutureAstralPower) end

---@param OverrideFutureAstralPower? number Override value when truthy.
---@return number
function Player:AstralPowerDeficitPercentage(OverrideFutureAstralPower) end

--- Max AP (retail-compat; 0 on TBC).
---@return number
function Player:AstralPowerMax() end

--- AP % (retail-compat; 0 on TBC).
---@param OverrideFutureAstralPower? number Override value when truthy.
---@return number
function Player:AstralPowerPercentage(OverrideFutureAstralPower) end

--- AP-based weapon damage modifier.
---@param offHand? boolean True = use off-hand stats.
---@return number
function Player:AttackPowerDamageMod(offHand) end

--- Cancels a buff via CancelSpellByName (only out of combat or if secure).
---@param buffName string Buff name.
---@return nil
function Player:CancelBuff(buffName) end

--- Power cost of the spell currently being cast (real-time, **uncached**), else 0.
---@return number
function Player:CastCost() end

--- Cached counterpart of CastCost: power cost of the spell currently being cast, else 0.
---@return number
function Player:CastCostCache() end

--- Remaining cast time; delegates to Unit:IsCastingRemains(spellID).
---@param spellID? number With no arg, returns the current cast's remaining time.
---@return number
function Player:CastRemains(spellID) end

--- Seconds since the last cast-start event (UNIT_SPELLCAST_START/CHANNEL_START).
---@return number
function Player:CastTimeSinceStart() end

--- Current chi (retail-compat; 0 on TBC).
---@return number
function Player:Chi() end

---@return number
function Player:ChiDeficit() end

---@return number
function Player:ChiDeficitPercentage() end

--- Max chi (retail-compat; 0 on TBC).
---@return number
function Player:ChiMax() end

---@return number
function Player:ChiPercentage() end

--- Combo points on `unitID` via GetComboPoints.
---@param unitID? string Default "target".
---@return number
function Player:ComboPoints(unitID) end

--- Missing combo points.
---@param unitID? string Default "target".
---@return number
function Player:ComboPointsDeficit(unitID) end

--- Max combo points.
---@return number
function Player:ComboPointsMax() end

--- Melee crit chance percent (GetCritChance()).
---@return number
function Player:CritChancePct() end

--- Current energy.
---@return number
function Player:Energy() end

--- Missing energy.
---@return number
function Player:EnergyDeficit() end

--- Missing energy %.
---@return number
function Player:EnergyDeficitPercentage() end

--- Predicted deficit (floored at 0).
---@param Offset? number
---@return number
function Player:EnergyDeficitPredicted(Offset) end

--- Max energy.
---@return number
function Player:EnergyMax() end

--- Energy %.
---@return number
function Player:EnergyPercentage() end

--- Predicted energy at cast/GCD end (capped).
---@param Offset? number
---@return number
function Player:EnergyPredicted(Offset) end

--- Energy/second.
---@return number
function Player:EnergyRegen() end

--- Regen as % of max.
---@return number
function Player:EnergyRegenPercentage() end

--- Energy over remaining cast/channel/GCD + `Offset`.
---@param Offset? number
---@return number
function Player:EnergyRemainingCastRegen(Offset) end

--- Seconds to full energy.
---@return number
function Player:EnergyTimeToMax() end

--- Predicted time to max.
---@return number
function Player:EnergyTimeToMaxPredicted() end

--- Seconds to reach `Amount` energy.
---@param Amount number Target energy.
---@param Offset? number Regen-rate multiplier: effective regen is scaled by (1 - Offset), not a flat time offset.
---@return number
function Player:EnergyTimeToX(Amount, Offset) end

--- Seconds to reach `Amount`%.
---@param Amount number Target energy percent.
---@return number
function Player:EnergyTimeToXPercentage(Amount) end

--- Current essence (retail-compat; 0 on TBC).
---@return number
function Player:Essence() end

---@return number
function Player:EssenceDeficit() end

---@return number
function Player:EssenceDeficitPercentage() end

--- Max essence (retail-compat; 0 on TBC).
---@return number
function Player:EssenceMax() end

--- max(GCD, castTime) for `spellID`.
---@param spellID number
---@return number
function Player:Execute_Time(spellID) end

--- Current focus (retail-compat; 0 on TBC).
---@return number
function Player:Focus() end

--- Focus regained over `CastTime`.
---@param CastTime number
---@return number
function Player:FocusCastRegen(CastTime) end

--- Missing focus.
---@return number
function Player:FocusDeficit() end

--- Missing focus %.
---@return number
function Player:FocusDeficitPercentage() end

--- Predicted deficit.
---@param Offset? number
---@return number
function Player:FocusDeficitPredicted(Offset) end

--- Focus cost of the in-progress cast (else 0).
---@return number
function Player:FocusLossOnCastEnd() end

--- Max focus (retail-compat; 0 on TBC).
---@return number
function Player:FocusMax() end

--- Focus %.
---@return number
function Player:FocusPercentage() end

--- Predicted focus at cast/GCD end.
---@param Offset? number
---@return number
function Player:FocusPredicted(Offset) end

--- Focus/second.
---@return number
function Player:FocusRegen() end

--- Regen as % of max.
---@return number
function Player:FocusRegenPercentage() end

--- Focus over remaining cast/GCD + `Offset`.
---@param Offset? number
---@return number
function Player:FocusRemainingCastRegen(Offset) end

--- Seconds to full focus.
---@return number
function Player:FocusTimeToMax() end

--- Predicted time to max.
---@return number
function Player:FocusTimeToMaxPredicted() end

--- Seconds to reach `Amount` focus.
---@param Amount number
---@return number
function Player:FocusTimeToX(Amount) end

--- Seconds to reach `Amount`%.
---@param Amount number
---@return number
function Player:FocusTimeToXPercentage(Amount) end

--- Current fury (retail-compat; 0 on TBC).
---@return number
function Player:Fury() end

---@return number
function Player:FuryDeficit() end

---@return number
function Player:FuryDeficitPercentage() end

--- Max fury (retail-compat; 0 on TBC).
---@return number
function Player:FuryMax() end

---@return number
function Player:FuryPercentage() end

--- Remaining GCD (A.GetCurrentGCD()).
---@return number
function Player:GCDRemains() end

--- Remaining ammo (arrow or bullet, whichever found).
---@return number
function Player:GetAmmo() end

--- Remaining arrows (0 if none).
---@return number
function Player:GetArrow() end

--- Bag match info `{ count, itemID }` or nil.
---@param name string Matcher name.
---@return table|nil
function Player:GetBag(name) end

--- For varargs (spellID / spellName / action object): [1] total units the listed buffs are applied
--- to, [2] how many of the varargs were found applied. Combat-log tracked.
---@param ... number|string Spell IDs / names / action objects.
---@return number units, number found
function Player:GetBuffsUnitCount(...) end

--- Remaining bullets (0 if none).
---@return number
function Player:GetBullet() end

--- Same as GetBuffsUnitCount but for debuffs the player applied.
---@param ... number|string Spell IDs / names / action objects.
---@return number units, number found
function Player:GetDeBuffsUnitCount(...) end

--- Seconds falling (select(2, self:IsFalling())).
---@return number
function Player:GetFalling() end

--- Inv match info `{ slot, itemID }` or nil.
---@param name string Matcher name.
---@return table|nil
function Player:GetInv(name) end

--- Current shapeshift form index (Data.Stance, from GetShapeshiftForm()).
---@return number
function Player:GetStance() end

--- Current swing time (s) for slot.
---@param inv number 1=mainhand, 2=offhand, 3=ranged, 4=max(main,off), 5=max(all), or a CONST slot.
---@return number
function Player:GetSwing(inv) end

--- Max/total duration of the last swing for that slot (same `inv` semantics as GetSwing).
---@param inv number
---@return number
function Player:GetSwingMax(inv) end

--- Time remaining until next auto-shot tick (0 if none pending).
---@return number
function Player:GetSwingShoot() end

--- Start timestamp of the last swing for that slot (same `inv` semantics as GetSwing).
---@param inv number
---@return number
function Player:GetSwingStart(inv) end

--- Remaining thrown items (0 if none).
---@return number
function Player:GetThrown() end

--- Equipped piece count for a tier.
---@param tier string Tier-set name.
---@return number
function Player:GetTier(tier) end

--- Passthrough of GetTotemInfo(i): haveTotem, name, startTime, duration, icon.
---@param i number Totem slot.
---@return boolean haveTotem, string name, number startTime, number duration, string icon
function Player:GetTotemInfo(i) end

--- Passthrough of GetTotemTimeLeft(i).
---@param i number Totem slot.
---@return number
function Player:GetTotemTimeLeft(i) end

--- White-hit weapon damage: [1] full avg damage, [2] avg DPS.
---@param inv? number 1=main, 2=off, nil=both.
---@param mod? number Modifies attack speed (default 1).
---@return number damage, number dps
function Player:GetWeaponMeleeDamage(inv, mod) end

--- True if glyph is active.
---@param spell number|string Glyph spellName / spellID / glyphID (WOTLK-BFA builds).
---@return boolean
function Player:HasGlyph(spell) end

--- itemID of shield in bag (default) or equipped, or nil.
---@param isEquiped? boolean True = check equipped instead of bag.
---@return number|nil itemID
function Player:HasShield(isEquiped) end

--- True if `>= count` tier pieces equipped (disabled in MoP Proving Grounds, ZoneID 480).
---@param tier string Tier-set name.
---@param count number Required piece count.
---@return boolean
function Player:HasTier(tier, count) end

--- itemID of main-hand dagger (bag or equipped), or nil.
---@param isEquiped? boolean True = check equipped instead of bag.
---@return number|nil itemID
function Player:HasWeaponMainOneHandDagger(isEquiped) end

--- itemID of main-hand 1H sword (bag or equipped), or nil.
---@param isEquiped? boolean True = check equipped instead of bag.
---@return number|nil itemID
function Player:HasWeaponMainOneHandSword(isEquiped) end

--- itemID of off-hand weapon (bag or equipped), or nil.
---@param isEquiped? boolean True = check equipped instead of bag.
---@return number|nil itemID
function Player:HasWeaponOffHand(isEquiped) end

--- itemID of off-hand 1H sword (bag or equipped), or nil.
---@param isEquiped? boolean True = check equipped instead of bag.
---@return number|nil itemID
function Player:HasWeaponOffOneHandSword(isEquiped) end

--- itemID of a two-hand weapon (bag or equipped), or nil.
---@param isEquiped? boolean True = check equipped instead of bag.
---@return number|nil itemID
function Player:HasWeaponTwoHand(isEquiped) end

--- Haste percent (GetHaste()).
---@return number
function Player:HastePct() end

--- Current holy power (retail-compat; 0 on TBC).
---@return number
function Player:HolyPower() end

---@return number
function Player:HolyPowerDeficit() end

---@return number
function Player:HolyPowerDeficitPercentage() end

--- Max holy power (retail-compat; 0 on TBC).
---@return number
function Player:HolyPowerMax() end

---@return number
function Player:HolyPowerPercentage() end

--- Current insanity (retail-compat; 0 on TBC).
---@return number
function Player:Insanity() end

---@return number
function Player:InsanityDeficit() end

---@return number
function Player:InsanityDeficitPercentage() end

--- Max insanity (retail-compat; 0 on TBC).
---@return number
function Player:InsanityMax() end

---@return number
function Player:InsanityPercentage() end

--- Insanity **drain** rate (units/sec) derived from Voidform stacks, not a resource amount.
--- (Method name is misspelled in source — missing the "D".)
---@return number
function Player:Insanityrain() end

--- Melee auto-attack active (combat-log driven).
---@return boolean
function Player:IsAttacking() end

--- True if player has been behind the target for `x` seconds (UI-error tracking).
---@param x? number Seconds threshold (default 2.5).
---@return boolean
function Player:IsBehind(x) end

--- Seconds since the last "not behind" UI error.
---@return number
function Player:IsBehindTime() end

--- Name of the current non-channel cast, else nil.
---@return string|nil
function Player:IsCasting() end

--- Name of the current channel, else nil.
---@return string|nil
function Player:IsChanneling() end

--- More accurate fall check (excludes jumps; only true after >1.7s falling).
---@return boolean isFalling, number secondsFalling
function Player:IsFalling() end

--- True if mounted, excluding druid travel/aquatic forms that read as mounted.
---@return boolean
function Player:IsMounted() end

--- True if currently moving.
---@return boolean
function Player:IsMoving() end

--- Seconds since movement started (0 if stationary).
---@return number
function Player:IsMovingTime() end

--- True if pet behind target for `x` sec.
---@param x? number Seconds threshold (default 2.5).
---@return boolean
function Player:IsPetBehind(x) end

--- Seconds since last pet "not behind" error.
---@return number
function Player:IsPetBehindTime() end

--- Auto-shoot (auto-repeat) active.
---@return boolean
function Player:IsShooting() end

--- True if current shapeshift form equals `x`.
---@param x number Shapeshift form index.
---@return boolean
function Player:IsStance(x) end

--- True if currently stationary.
---@return boolean
function Player:IsStaying() end

--- Seconds since stopped moving (0 if moving).
---@return number
function Player:IsStayingTime() end

--- True if stealthed (incl. class prowl/stealth/vanish auras and NightElf Shadowmeld).
---@return boolean
function Player:IsStealthed() end

--- True while an equip swap is in progress (must be checked before any swap).
---@return boolean
function Player:IsSwapLocked() end

--- IsSwimming() or IsSubmerged().
---@return boolean
function Player:IsSwimming() end

--- Current maelstrom (retail-compat; 0 on TBC).
---@return number
function Player:Maelstrom() end

---@return number
function Player:MaelstromDeficit() end

---@return number
function Player:MaelstromDeficitPercentage() end

--- Max maelstrom (retail-compat; 0 on TBC).
---@return number
function Player:MaelstromMax() end

---@return number
function Player:MaelstromPercentage() end

--- Current mana.
---@return number
function Player:Mana() end

--- Mana regained over `CastTime`; -1 if regen is 0.
---@param CastTime number
---@return number
function Player:ManaCastRegen(CastTime) end

--- Missing mana.
---@return number
function Player:ManaDeficit() end

--- Predicted missing mana.
---@return number
function Player:ManaDeficitP() end

--- Missing mana %.
---@return number
function Player:ManaDeficitPercentage() end

--- Predicted missing mana %.
---@return number
function Player:ManaDeficitPercentageP() end

--- Max mana.
---@return number
function Player:ManaMax() end

--- Predicted mana after current cast (cost subtracted + cast regen, capped).
---@return number
function Player:ManaP() end

--- Mana %.
---@return number
function Player:ManaPercentage() end

--- Predicted mana %.
---@return number
function Player:ManaPercentageP() end

--- Mana/sec (floor(GetPowerRegen)).
---@return number
function Player:ManaRegen() end

--- Mana regained over remaining cast (or GCD if not casting) + `Offset`; -1 if no regen.
---@param Offset? number
---@return number
function Player:ManaRemainingCastRegen(Offset) end

--- Seconds to full mana; -1 if no regen.
---@return number
function Player:ManaTimeToMax() end

--- Seconds to reach `Amount` mana; -1 if no regen, 0 if already there.
---@param Amount number
---@return number
function Player:ManaTimeToX(Amount) end

--- Current pain (retail-compat; 0 on TBC).
---@return number
function Player:Pain() end

---@return number
function Player:PainDeficit() end

---@return number
function Player:PainDeficitPercentage() end

--- Max pain (retail-compat; 0 on TBC).
---@return number
function Player:PainMax() end

---@return number
function Player:PainPercentage() end

--- Current rage.
---@return number
function Player:Rage() end

--- Missing rage.
---@return number
function Player:RageDeficit() end

--- Missing rage %.
---@return number
function Player:RageDeficitPercentage() end

--- Max rage.
---@return number
function Player:RageMax() end

--- Rage %.
---@return number
function Player:RagePercentage() end

--- Registers arrow + bullet bag trackers (AMMO1/AMMO2).
---@return nil
function Player:RegisterAmmo() end

--- Registers shield bag + offhand inventory trackers.
---@return nil
function Player:RegisterShield() end

--- Registers thrown-weapon bag tracker.
---@return nil
function Player:RegisterThrown() end

--- Registers main-hand dagger trackers.
---@return nil
function Player:RegisterWeaponMainOneHandDagger() end

--- Registers main-hand 1H sword trackers.
---@return nil
function Player:RegisterWeaponMainOneHandSword() end

--- Registers off-hand weapon trackers (5 bag subclasses + inv).
---@return nil
function Player:RegisterWeaponOffHand() end

--- Registers off-hand 1H sword trackers.
---@return nil
function Player:RegisterWeaponOffOneHandSword() end

--- Registers two-hand weapon trackers (5 bag + 5 inv subclasses).
---@return nil
function Player:RegisterWeaponTwoHand() end

--- Unregister bag matcher.
---@param name string
---@return nil
function Player:RemoveBag(name) end

--- Unregister inventory matcher.
---@param name string
---@return nil
function Player:RemoveInv(name) end

--- Unregister tier set.
---@param tier string
---@return nil
function Player:RemoveTier(tier) end

--- Overrides the tracked swing duration for the slot(s).
---@param inv number Slot (same semantics as GetSwing).
---@param dur number New duration.
---@return nil
function Player:ReplaceSwingDuration(inv, dur) end

--- Count of ready runes of `presence` plus death runes; applies recovery offset. Retail-compat.
---@param presence number|string Rune presence (name/const).
---@return number
function Player:Rune(presence) end

--- Seconds until `Value`-th rune is ready; errors if out of range. Retail-compat.
---@param Value number Rune index 1-6.
---@return number
function Player:RuneTimeToX(Value) end

--- Current runic power (retail-compat; 0 on TBC).
---@return number
function Player:RunicPower() end

--- Missing runic power.
---@return number
function Player:RunicPowerDeficit() end

--- Missing runic power %.
---@return number
function Player:RunicPowerDeficitPercentage() end

--- Max runic power (retail-compat; 0 on TBC).
---@return number
function Player:RunicPowerMax() end

--- Runic power %.
---@return number
function Player:RunicPowerPercentage() end

--- Current soul shards (retail-compat; 0 on TBC).
---@return number
function Player:SoulShards() end

--- Missing soul shards.
---@return number
function Player:SoulShardsDeficit() end

--- Max soul shards (retail-compat; 0 on TBC).
---@return number
function Player:SoulShardsMax() end

--- Predicted shards (default = current; overridden per spec).
---@return number
function Player:SoulShardsP() end

--- Spell-haste multiplier 1/(1+haste%/100).
---@return number
function Player:SpellHaste() end

--- Current stagger (UnitStagger). Retail-compat; 0 on TBC.
---@return number
function Player:Stagger() end

--- Max stagger (= Unit:HealthMax()).
---@return number
function Player:StaggerMax() end

--- Stagger as % of max health.
---@return number
function Player:StaggerPercentage() end

--- True if target is behind the player within `x` sec, guarded by target GUID.
---@param x? number Seconds threshold (default 2.5).
---@return boolean
function Player:TargetIsBehind(x) end

--- Seconds since target was behind player (GUID-guarded).
---@return number
function Player:TargetIsBehindTime() end
