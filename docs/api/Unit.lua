---@meta
--- GGL Action Framework - Unit System Stubs
---
--- Verified against source: action/Modules/Engines/Unit.lua.
--- The engine exports THREE distinct PseudoClasses, each invoked as `Class(arg):Method(...)`:
---   * `Unit`         — `Unit(unitID):Method(...)`        (unit state + targeting surface)
---   * `FriendlyTeam` — `FriendlyTeam(ROLE):Method(...)`  (friendly selection helpers)
---   * `EnemyTeam`    — `EnemyTeam(ROLE):Method(...)`      (enemy selection helpers)
--- The previous stub wrongly flattened all three onto a single `Unit` class; they are split here.

---------------------------------------------------------------------------
-- Unit — Unit(unitID):Method()
---------------------------------------------------------------------------

---@class Unit
local Unit = {}

-- Auras — buffs / debuffs / tooltip numbers ------------------------------

--- Packed tooltip number for the matched aura by kindKey/requestedIndex; 0 if not found.
---@param spell any aura group name, spellID, or list (AssociativeTables key)
---@param filter? string aura filter (default "HELPFUL"; caster truthy adds " PLAYER")
---@param caster? any truthy restricts to player-cast auras
---@param byID? any truthy matches by spellID instead of name
---@param kindKey? any tooltip value selector key
---@param requestedIndex? number which packed value to return (default 1)
---@return number tooltipNumber
function Unit:AuraTooltipNumberByIndex(spell, filter, caster, byID, kindKey, requestedIndex) end

--- First non-zero value in the matched aura's points table; 0 if none.
---@param spell any aura group name, spellID, or list
---@param filter? string aura filter (default "HELPFUL")
---@param caster? any truthy restricts to player-cast auras
---@param byID? any truthy matches by spellID instead of name
---@return number value
function Unit:AuraVariableNumber(spell, filter, caster, byID) end

--- Buff info for an aura table {[spellID or name]=rank}; 0,0,0,0 if absent.
---@param auraTable any {[spellID or name]=rank} (HELPFUL filter)
---@param caster? any truthy restricts to player-cast auras
---@return number rank
---@return number remain
---@return number total
---@return number stacks
function Unit:GetBuffInfo(auraTable, caster) end

--- Buff info for an exact-name match; 0,0,0,0 if absent.
---@param auraName string exact aura name string
---@param caster? any truthy restricts to player-cast auras
---@return number spellID
---@return number remain
---@return number total
---@return number stacks
function Unit:GetBuffInfoByName(auraName, caster) end

--- Debuff info for an aura table (HARMFUL filter); 0,0,0,0 if absent.
---@param auraTable any {[spellID or name]=rank}
---@param caster? any truthy restricts to player-cast auras
---@return number rank
---@return number remain
---@return number total
---@return number stacks
function Unit:GetDeBuffInfo(auraTable, caster) end

--- Debuff info for an exact-name match; 0,0,0,0 if absent.
---@param auraName string exact debuff name string
---@param caster? any truthy restricts to player-cast auras
---@return number spellID
---@return number remain
---@return number total
---@return number stacks
function Unit:GetDeBuffInfoByName(auraName, caster) end

--- Remain, total duration of first matching buff (huge if permanent); 0,0 if absent.
---@param spell any aura group name, spellID, or list
---@param caster? any truthy restricts to player-cast auras
---@param byID? any truthy matches by spellID instead of name
---@return number remain
---@return number total
function Unit:HasBuffs(spell, caster, byID) end

--- Like HasBuffs but returns the highest-remaining matching buff.
---@param spell any aura group name, spellID, or list
---@param caster? any truthy restricts to player-cast auras
---@param byID? any truthy matches by spellID instead of name
---@return number remain
---@return number total
function Unit:SortBuffs(spell, caster, byID) end

--- Stack count of first matching buff (1 if charges==0); 0 if absent.
---@param spell any aura group name, spellID, or list
---@param caster? any truthy restricts to player-cast auras
---@param byID? any truthy matches by spellID instead of name
---@return number stacks
function Unit:HasBuffsStacks(spell, caster, byID) end

--- Highest-remaining matching debuff: remain, total duration. Scans limited to 1 (single) or 3 (table).
---@param spell any aura group name, spellID, or list
---@param caster? any truthy restricts to player-cast auras
---@param byID? any truthy matches by spellID instead of name
---@return number remain
---@return number total
function Unit:SortDeBuffs(spell, caster, byID) end

--- Alias of SortDeBuffs: highest-remaining matching debuff (remain, total).
---@param spell any aura group name, spellID, or list
---@param caster? any truthy restricts to player-cast auras
---@param byID? any truthy matches by spellID instead of name
---@return number remain
---@return number total
function Unit:HasDeBuffs(spell, caster, byID) end

--- Stack count of first matching debuff; 0 if absent.
---@param spell any aura group name, spellID, or list
---@param caster? any truthy restricts to player-cast auras
---@param byID? any truthy matches by spellID instead of name
---@return number stacks
function Unit:HasDeBuffsStacks(spell, caster, byID) end

--- Pandemic threshold: true if a matching aura's remaining <=30% of its duration.
---@param spell any aura group name, spellID, or list
---@param debuff? any truthy -> HARMFUL PLAYER, else HELPFUL
---@param byID? any truthy matches by spellID instead of name
---@return boolean
function Unit:PT(spell, debuff, byID) end

--- True if debuff count >= AURAS_MAX_LIMIT; also returns the count.
---@return boolean limited
---@return number count
function Unit:IsDeBuffsLimited() end

--- Stub: always 0 (no such effects in this build).
---@return number
function Unit:DeBuffCyclone() end

--- Carrying a BG flag (HasBuffs(AuraList.Flags) > 0).
---@return boolean
function Unit:HasFlags() end

-- Health & power & HP ---------------------------------------------------

--- Current health.
---@return number
function Unit:Health() end

--- Maximum health.
---@return number
function Unit:HealthMax() end

--- Missing health (HealthMax - Health).
---@return number
function Unit:HealthDeficit() end

--- Missing health % (100 - HealthPercent).
---@return number
function Unit:HealthDeficitPercent() end

--- Health % (0-100); raw UnitHealth for units without real health values.
---@return number
function Unit:HealthPercent() end

--- HP% lost per second (max(GetDMG% - GetHEAL%, 0)).
---@return number
function Unit:HealthPercentLosePerSecond() end

--- HP% gained per second (max(GetHEAL% - GetDMG%, 0)).
---@return number
function Unit:HealthPercentGainPerSecond() end

--- Current power.
---@return number
function Unit:Power() end

--- Power token (MANA/ENERGY/RAGE...). Returns a string, not a number.
---@return string
function Unit:PowerType() end

--- Maximum power.
---@return number
function Unit:PowerMax() end

--- Missing power (PowerMax - Power).
---@return number
function Unit:PowerDeficit() end

--- Missing power % (PowerDeficit*100/PowerMax).
---@return number
function Unit:PowerDeficitPercent() end

--- Current power % (Power*100/PowerMax).
---@return number
function Unit:PowerPercent() end

--- Healing the unit will absorb without gaining HP.
---@return number
function Unit:GetTotalHealAbsorbs() end

--- Heal absorb as % of max HP.
---@return number
function Unit:GetTotalHealAbsorbsPercent() end

--- Has incoming resurrection (UnitHasIncomingResurrection).
---@return boolean
function Unit:GetIncomingResurrection() end

--- Predicted others' heals landing within castTime (HealComm); 0 if castTime<=0.
---@param castTime number window in seconds
---@param unitGUID? string GUID override
---@return number
function Unit:GetIncomingHeals(castTime, unitGUID) end

--- Like GetIncomingHeals but includes your own incoming heals.
---@param castTime number window in seconds
---@param unitGUID? string GUID override
---@return number
function Unit:GetIncomingHealsIncSelf(castTime, unitGUID) end

-- Range, LoS, movement & interaction ------------------------------------

--- Max range, min range (LibRangeCheck); huge if unknown.
---@return number maxRange
---@return number minRange
function Unit:GetRange() end

--- True if min range >0 and (<=range OR orBooleanInRange).
---@param range number range cap in yards
---@param orBooleanInRange? any truthy bypasses the range check
---@return boolean
function Unit:CanInterract(range, orBooleanInRange) end

--- Is player or UnitInRange.
---@return boolean
function Unit:InRange() end

--- UnitInLOS(unitID, unitGUID).
---@param unitGUID? string GUID override
---@return boolean
function Unit:InLOS(unitGUID) end

--- In player's group; includeAnyGroups -> UnitInAnyGroup.
---@param includeAnyGroups? any truthy widens to any group
---@param unitGUID? string GUID override
---@return boolean
function Unit:InGroup(includeAnyGroups, unitGUID) end

--- UnitPlayerOrPetInParty.
---@return boolean
function Unit:InParty() end

--- UnitPlayerOrPetInRaid.
---@return boolean
function Unit:InRaid() end

--- UnitInVehicle.
---@return boolean
function Unit:InVehicle() end

--- Enemy-plate match -> true + nameplate unitID.
---@return boolean isNameplate
---@return string? nameplateUnitID
function Unit:IsNameplate() end

--- Any-plate match -> true + nameplate unitID.
---@return boolean isNameplate
---@return string? nameplateUnitID
function Unit:IsNameplateAny() end

--- UnitIsVisible.
---@return boolean
function Unit:IsVisible() end

--- UnitExists.
---@return boolean
function Unit:IsExists() end

--- UnitIsConnected.
---@return boolean
function Unit:IsConnected() end

--- Current speed %, max speed % (run=100).
---@return number currentSpeed
---@return number maxSpeed
function Unit:GetCurrentSpeed() end

--- Max movement speed % (select(2, GetCurrentSpeed)).
---@return number
function Unit:GetMaxSpeed() end

--- Player -> Player:IsMounted; else maxSpeed >= 200.
---@return boolean
function Unit:IsMounted() end

--- Current speed ~= 0 (player uses Player:IsMoving).
---@return boolean
function Unit:IsMoving() end

--- Seconds spent continuously moving; -1 if not moving.
---@return number
function Unit:IsMovingTime() end

--- Current speed == 0.
---@return boolean
function Unit:IsStaying() end

--- Seconds stationary; -1 if moving.
---@return number
function Unit:IsStayingTime() end

--- Moving toward player (player always true).
---@param snap_timer? number snapshot window in seconds (default 0.2)
---@return boolean
function Unit:IsMovingIn(snap_timer) end

--- Moving away from player.
---@param snap_timer? number snapshot window in seconds (default 0.2)
---@return boolean
function Unit:IsMovingOut(snap_timer) end

--- UnitCanCooperate(unitID, otherunit).
---@param otherunit string other unit token
---@return boolean
function Unit:CanCooperate(otherunit) end

-- Casting / interrupt ---------------------------------------------------

--- Raw cast/channel info; notInterruptable recomputed from KickImun buffs.
---@return string castName
---@return number castStartTime
---@return number castEndTime
---@return boolean notInterruptable
---@return number spellID
---@return boolean isChannel
function Unit:IsCasting() end

--- Cast info (7 returns). remainSec counts X->0; donePercent 0->100.
---@param argSpellID? number expected spellID filter
---@return number total
---@return number remainSec
---@return number donePercent
---@return number spellID
---@return string castName
---@return boolean notInterruptable
---@return boolean isChannel
function Unit:CastTime(argSpellID) end

--- select(2, CastTime): drops total.
---@param argSpellID? number expected spellID filter
---@return number remainSec
---@return number donePercent
---@return number spellID
---@return string castName
---@return boolean notInterruptable
---@return boolean isChannel
function Unit:IsCastingRemains(argSpellID) end

--- Cast info only if the cast matches spells (table) or AuraList.CastBarsCC; else 0,0,0.
---@param spells? any table of spells to match
---@param range? number range filter in yards
---@return number total
---@return number remain
---@return number percent
---@return number spellID
---@return string name
---@return boolean notInterruptable
function Unit:MultiCast(spells, range) end

--- True once cast progress passes a randomized minX-maxX% threshold (humanized kick).
---@param kickAble? any truthy requires interruptable
---@param auras? any matched auras block the interrupt
---@param minX? number lower threshold % (default 34)
---@param maxX? number upper threshold % (default 68)
---@return boolean
function Unit:CanInterrupt(kickAble, auras, minX, maxX) end

-- Threat & combat state -------------------------------------------------

--- status (0-3), scaledPercent, threatValue. Percent/value meaningful only with ThreatLib.
---@param otherunitID? string attacker token (default "target")
---@return number status
---@return number scaledPercent
---@return number threatValue
function Unit:ThreatSituation(otherunitID) end

--- PvP: target-of-target check; PvE: threat >=3 OR IsTankingAoE.
---@param otherunitID? string attacker token
---@param range? number range filter in yards
---@return boolean
function Unit:IsTanking(otherunitID, range) end

--- True if tanking any active enemy nameplate (within range).
---@param range? number range filter in yards
---@return boolean
function Unit:IsTankingAoE(range) end

--- Seconds in combat, unitGUID (CombatTracker:CombatTime).
---@return number combatTime
---@return string unitGUID
function Unit:CombatTime() end

--- Diminishing-returns state. DR_Tick 100->50->25->0 (taunt 100->65->42->27->0).
---@param drCat string DR category key
---@return number DR_Tick
---@return number DR_Remain
---@return number DR_Application
---@return number DR_ApplicationMax
function Unit:GetDR(drCat) end

--- Whether CC of drCat will still apply (DR above tick), with immunity guards.
---@param drCat string DR category key
---@param DR_Tick? number minimum acceptable DR tick (default 0)
---@return boolean
function Unit:IsControlAble(drCat, DR_Tick) end

--- Damage taken (smoothed): total, hits, phys, magic. select(index,...) if index given.
---@param index? number which component to return
---@return number total
---@return number hits
---@return number phys
---@return number magic
function Unit:GetDMG(index) end

--- Damage done (smoothed): total, hits, phys, magic.
---@param index? number which component to return
---@return number total
---@return number hits
---@return number phys
---@return number magic
function Unit:GetDPS(index) end

--- Healing taken: total, hits.
---@param index? number which component to return
---@return number total
---@return number hits
function Unit:GetHEAL(index) end

--- Healing done: total, hits.
---@param index? number which component to return
---@return number total
---@return number hits
function Unit:GetHPS(index) end

--- Real-time damage taken: total, hits, phys, magic, swing.
---@param index? number which component to return
---@return number total
---@return number hits
---@return number phys
---@return number magic
---@return number swing
function Unit:GetRealTimeDMG(index) end

--- Real-time damage done: total, hits, phys, magic, swing.
---@param index? number which component to return
---@return number total
---@return number hits
---@return number phys
---@return number magic
---@return number swing
function Unit:GetRealTimeDPS(index) end

--- Damage by school: Holy, Fire, Nature, Frost, Shadow, Arcane (player only).
---@param index? number which school to return
---@return number holy
---@return number fire
---@return number nature
---@return number frost
---@return number shadow
---@return number arcane
function Unit:GetSchoolDMG(index) end

--- Damage taken in last x seconds.
---@param x number lookback window in seconds
---@return number
function Unit:GetLastTimeDMGX(x) end

--- Amount taken from spell in last x seconds.
---@param spell any spell key
---@param x number lookback window in seconds
---@return number
function Unit:GetSpellAmountX(spell, x) end

--- Total amount taken from spell this fight.
---@param spell any spell key
---@return number
function Unit:GetSpellAmount(spell) end

--- Seconds since last cast, start timestamp.
---@param spell any spell key
---@return number sinceSeconds
---@return number startTimestamp
function Unit:GetSpellLastCast(spell) end

--- Total casts of spell this fight.
---@param spell any spell key
---@return number
function Unit:GetSpellCounter(spell) end

--- Absorb taken total (or by spell).
---@param spell? any spell key
---@return number
function Unit:GetAbsorb(spell) end

--- True if unit level >0 and < playerLevel-10 (heal/damage penalty).
---@return boolean
function Unit:IsPenalty() end

--- UnitLevel or 0 (-1 = boss/skull).
---@return number
function Unit:GetLevel() end

-- UnitCooldown (enemy spell-cooldown tracking) --------------------------

--- Remaining CD seconds, start timestamp.
---@param spellName string spell name
---@return number remain
---@return number startTimestamp
function Unit:GetCooldown(spellName) end

--- Max CD of the spell on the unit.
---@param spellName string spell name
---@return number
function Unit:GetMaxDuration(spellName) end

--- Who last cast spellName (else nil). UnitCooldown variant, distinct from the team GetUnitID(range).
---@param spellName string spell name
---@return string? unitID
function Unit:GetUnitID(spellName) end

--- charges, current CD, summary CD.
---@return number charges
---@return number currentCD
---@return number summaryCD
function Unit:GetBlinkOrShrimmer() end

--- Spell currently mid-flight.
---@param spellName string spell name
---@return boolean
function Unit:IsSpellInFly(spellName) end

-- Time-to-die / TTD -----------------------------------------------------

--- Seconds until 0% (CombatTracker:TimeToDie).
---@return number
function Unit:TimeToDie() end

--- Seconds until x% HP.
---@param x number target HP %
---@return number
function Unit:TimeToDieX(x) end

--- TTD from magic damage only.
---@return number
function Unit:TimeToDieMagic() end

--- TTD-magic to x%.
---@param x number target HP %
---@return number
function Unit:TimeToDieMagicX(x) end

--- TimeToDieX(20) <= GCD + currentGCD (in execute window).
---@return boolean
function Unit:IsExecuted() end

-- Role / class / spec / GUID identity -----------------------------------

--- UnitName or "none".
---@return string
function Unit:Name() end

--- Non-localized race token; "none" fallback.
---@return string
function Unit:Race() end

--- Uppercase class token (WARRIOR...); "none" fallback.
---@return string
function Unit:Class() end

--- Without hasRole: role string (TANK/HEALER/DAMAGER/NONE). With hasRole string: boolean match.
---@param hasRole? string role to test for
---@return boolean|string
function Unit:Role(hasRole) end

--- UnitClassification (elite/worldboss/rare...) or empty.
---@return string
function Unit:Classification() end

--- English creature type (Beast/Demon/Humanoid...) or empty.
---@return string
function Unit:CreatureType() end

--- English creature family (Wolf/Cat/Imp...) or empty.
---@return string
function Unit:CreatureFamily() end

--- Parses GUID into 7 fields; nil if no GUID.
---@param unitGUID? string GUID override
---@return string utype
---@return number n1
---@return number n2
---@return number n3
---@return number n4
---@return number? npc_id
---@return string? spawn_uid
function Unit:InfoGUID(unitGUID) end

--- Spec match (player via A.PlayerSpec; others via heuristics). specID may be number or table.
---@param specID number|table spec ID or table of IDs
---@return boolean
function Unit:HasSpec(specID) end

--- Multi-strategy healer detection (team cache, role, power/offhand/shield, DPS-vs-HPS heuristic).
---@param class? string class token hint
---@return boolean
function Unit:IsHealer(class) end

--- Multi-strategy tank detection (team cache, role, shield/stance, threat, DMG-taken heuristic).
---@param class? string class token hint
---@return boolean
function Unit:IsTank(class) end

--- Multi-strategy DPS detection (mirror of IsTank/IsHealer).
---@param class? string class token hint
---@return boolean
function Unit:IsDamager(class) end

--- Melee detection (class + role + power/offhand + spell-counter heuristics).
---@param class? string class token hint
---@return boolean
function Unit:IsMelee(class) end

--- Class CAN be healer (lookup only).
---@return boolean
function Unit:IsHealerClass() end

--- Class can be tank.
---@return boolean
function Unit:IsTankClass() end

--- Class can be melee.
---@return boolean
function Unit:IsMeleeClass() end

--- Hostile (UnitCanAttack/UnitIsEnemy); isPlayer requires it be a player.
---@param isPlayer? any truthy requires the unit to be a player
---@return boolean
function Unit:IsEnemy(isPlayer) end

--- UnitIsPlayer.
---@return boolean
function Unit:IsPlayer() end

--- Player-controlled non-player.
---@return boolean
function Unit:IsPet() end

--- Player or player-controlled.
---@return boolean
function Unit:IsPlayerOrPet() end

--- Not player-controlled.
---@return boolean
function Unit:IsNPC() end

--- DeadOrGhost and not feign-death.
---@return boolean
function Unit:IsDead() end

--- UnitIsGhost.
---@return boolean
function Unit:IsGhost() end

--- UnitIsCharmed.
---@return boolean
function Unit:IsCharmed() end

--- npc_id/boss-frame/level-skull boss detection.
---@return boolean
function Unit:IsBoss() end

--- npc_id in InfoIsDummy.
---@return boolean
function Unit:IsDummy() end

--- CreatureType() == Undead.
---@return boolean
function Unit:IsUndead() end

--- CreatureType() == Demon.
---@return boolean
function Unit:IsDemon() end

--- CreatureType() == Humanoid.
---@return boolean
function Unit:IsHumanoid() end

--- CreatureType() == Elemental.
---@return boolean
function Unit:IsElemental() end

--- CreatureType() == Totem.
---@return boolean
function Unit:IsTotem() end

--- Remaining CC seconds (scans InfoAllCC from index); 0 if none.
---@param index? number scan start index (default 1)
---@return number
function Unit:InCC(index) end

-- Focus / burst / defensive decision helpers ----------------------------

--- True if a friendly/arena damager/melee is targeting this unit, optionally gated.
---@param burst? any gate by attacker burst buffs
---@param deffensive? any gate by this unit's defensive buffs
---@param range? number range filter in yards
---@param isMelee? any require a melee attacker
---@return boolean
function Unit:IsFocused(burst, deffensive, range, isMelee) end

--- Whether to burst this unit (enemy-player TTD/healer-CC/focus logic, or healer logic).
---@param pBurst? any burst-profile hint
---@return boolean
function Unit:UseBurst(pBurst) end

--- Whether to pop defensives (executed / heavily focused / low TTD + focused).
---@return boolean
function Unit:UseDeff() end

---------------------------------------------------------------------------
-- FriendlyTeam — FriendlyTeam(ROLE):Method()
---------------------------------------------------------------------------
--
-- The bound arg is a ROLE string: "TANK"|"HEALER"|"DAMAGER"|"DAMAGER_MELEE"|
-- "DAMAGER_RANGE"|nil. Unit-not-found returns "none".

---@class FriendlyTeam
local FriendlyTeam = {}

--- First alive, in-range friendly of ROLE (<=range); "none" otherwise.
---@param range? number range cap in yards
---@return string unitID
function FriendlyTeam:GetUnitID(range) end

--- First friendly of ROLE under CC (or matching spells debuff): remaining, unit. 0,"none" if none.
---@param spells? any debuff spells to match
---@return number remain
---@return string unitID
function FriendlyTeam:GetCC(spells) end

--- First friendly of ROLE (in range) with matching buff: remaining, unit.
---@param spells any buff spells to match
---@param range? number range filter in yards
---@param source? any caster filter
---@return number remain
---@return string unitID
function FriendlyTeam:GetBuffs(spells, range, source) end

--- First friendly of ROLE with matching debuff: remaining, unit.
---@param spells any debuff spells to match
---@param range? number range filter in yards
---@return number remain
---@return string unitID
function FriendlyTeam:GetDeBuffs(spells, range) end

--- True once count friendlies of ROLE have TTD <= seconds; returns count + (last) unit.
---@param count number how many must qualify
---@param seconds number TTD threshold
---@param range? number range filter in yards
---@return boolean reached
---@return number count
---@return string unitID
function FriendlyTeam:GetTTD(count, seconds, range) end

--- Average TTD of valid friendlies of ROLE, and their count.
---@param range? number range filter in yards
---@return number averageTTD
---@return number count
function FriendlyTeam:AverageTTD(range) end

--- First friendly of ROLE MISSING spells buff: true, unit.
---@param spells any buff spells expected
---@param source? any caster filter
---@return boolean missing
---@return string unitID
function FriendlyTeam:MissedBuffs(spells, source) end

--- First friendly of ROLE in combat (optionally combatTime <= combatTime): true, unit.
---@param range? number range filter in yards
---@param combatTime? number max combat time in seconds
---@return boolean inCombat
---@return string unitID
function FriendlyTeam:PlayersInCombat(range, combatTime) end

--- First HEALER (ROLE forced) being focused (Unit:IsFocused): true, unit.
---@param burst? any gate by attacker burst buffs
---@param deffensive? any gate by healer's defensive buffs
---@param range? number range filter in yards
---@param isMelee? any require a melee attacker
---@return boolean focused
---@return string unitID
function FriendlyTeam:HealerIsFocused(burst, deffensive, range, isMelee) end

---------------------------------------------------------------------------
-- EnemyTeam — EnemyTeam(ROLE):Method()
---------------------------------------------------------------------------
--
-- The bound arg is a ROLE string: "TANK"|"HEALER"|"DAMAGER"|"DAMAGER_MELEE"|
-- "DAMAGER_RANGE"|nil. Unit-not-found returns "none".

---@class EnemyTeam
local EnemyTeam = {}

--- First alive, in-range enemy of ROLE; "none" otherwise.
---@param range? number range cap in yards
---@return string unitID
function EnemyTeam:GetUnitID(range) end

--- First enemy of ROLE under CC (HEALER role skips current target): remaining, unit.
---@param spells? any debuff spells to match
---@return number remain
---@return string unitID
function EnemyTeam:GetCC(spells) end

--- First enemy of ROLE (in range) with matching buff.
---@param spells any buff spells to match
---@param range? number range filter in yards
---@param source? any caster filter
---@return number remain
---@return string unitID
function EnemyTeam:GetBuffs(spells, range, source) end

--- First enemy of ROLE with matching debuff.
---@param spells any debuff spells to match
---@param range? number range filter in yards
---@return number remain
---@return string unitID
function EnemyTeam:GetDeBuffs(spells, range) end

--- True once count enemies of ROLE have TTD <= seconds.
---@param count number how many must qualify
---@param seconds number TTD threshold
---@param range? number range filter in yards
---@return boolean reached
---@return number count
---@return string unitID
function EnemyTeam:GetTTD(count, seconds, range) end

--- Average enemy TTD + count. (Source bug: references undeclared arena/arenas.)
---@param range? number range filter in yards
---@return number averageTTD
---@return number count
function EnemyTeam:AverageTTD(range) end

--- First non-target enemy of ROLE with a "BreakAble" debuff (don't break CC on your kill target).
---@param range? number range filter in yards
---@return boolean breakable
---@return string unitID
function EnemyTeam:IsBreakAble(range) end

--- Counts enemies of ROLE in range; returns true once count >= stop.
---@param stop number count threshold
---@param range? number range filter in yards
---@return boolean reached
---@return number count
---@return string unitID
function EnemyTeam:PlayersInRange(stop, range) end

--- Counts enemies of ROLE & class-in-(...) whose target is unitID; true once count >= stop.
---@param unitID string the unit being focused
---@param stop number count threshold
---@param range? number range filter in yards
---@param ... string class tokens to match
---@return boolean reached
---@return number count
---@return string unitID
function EnemyTeam:FocusingUnitIDByClasses(unitID, stop, range, ...) end

--- Any alive ROGUE/DRUID enemy (optionally only if not visible): true, unit, class. (No ROLE.)
---@param checkVisible? any truthy restricts to currently-invisible units
---@return boolean found
---@return string unitID
---@return string class
function EnemyTeam:HasInvisibleUnits(checkVisible) end

--- First enemy pet (optionally in range of object): true, pet.
---@param object? string anchor unit for the range check
---@param range? number range filter in yards
---@return boolean found
---@return string unitID
function EnemyTeam:IsTauntPetAble(object, range) end

--- Enemy finishing (<=offset s) a cast matching AuraList.Premonition in range: true, unit.
---@param offset? number seconds-to-finish window (default 0.5)
---@return boolean found
---@return string unitID
function EnemyTeam:IsCastingBreakAble(offset) end

--- Enemy about to finish (<= GCD+offset) an AuraList.Reshift cast, when player isn't melee-focused.
---@param offset? number seconds-to-finish window (default 0.05)
---@return boolean found
---@return string unitID
function EnemyTeam:IsReshiftAble(offset) end

--- Enemy about to finish (<= GCD+offset) an AuraList.Premonition cast: true, unit.
---@param offset? number seconds-to-finish window (default 0.05)
---@return boolean found
---@return string unitID
function EnemyTeam:IsPremonitionAble(offset) end
