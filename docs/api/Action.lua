---@meta
--- GGL Action Framework - EmmyLua Stubs for VS Code IntelliSense
--- Auto-generated from API_Source_Index.json

---@class ActionCreateArgs
---@field Type string Action type: "Spell", "SpellSingleColor", "Item", "ItemSingleColor", "Potion", "Trinket", "TrinketBySlot", "SwapEquip", "Script"
---@field ID number Required: Spell ID or Item ID
---@field Color? string Optional: Display color (e.g., "RED", "GREEN", "BLUE")
---@field Desc? string Optional: Tooltip description
---@field Hidden? boolean Optional: Hide from UI
---@field isTalent? boolean Optional: Check if talent is learned
---@field isReplacement? boolean Optional: Check for spell replacement
---@field useMaxRank? boolean Optional: Use highest rank (Classic)
---@field skipRange? boolean Optional: Skip range checks
---@field QueueForbidden? boolean Optional: Prevent queueing
---@field BlockForbidden? boolean Optional: Prevent blocking
---@field MetaSlot? number Optional: Fixed meta slot for queue (1-10)
---@field IsAntiFake? boolean Optional: For slots [1],[2],[7]-[10]
---@field Click? ActionClickConfig Optional: MetaEngine click configuration
---@field Macro? string Optional: Custom macro string

---@class ActionClickConfig
---@field autounit? string Targeting mode: "help", "harm", "both"
---@field unit? string Specific unitID target
---@field type? string Action type: "spell", "item", "toy"
---@field typerelease? string Action type on key release
---@field spell? number|string Spell ID or name
---@field item? number|string Item ID or name
---@field macrobefore? string Macro commands before action
---@field macroafter? string Macro commands after action

---@class Action
---@field Player Player Player system API
---@field MultiUnits MultiUnits Multi-target system
---@field LossOfControl LossOfControl CC tracking system
---@field TeamCache TeamCache Group/enemy cache
---@field CombatTracker CombatTracker Combat event tracker
---@field Bit BitUtils Bitfield utilities
---@field Pet Pet Pet utilities
---@field HealingEngine HealingEngine Healing target selection
---@field Data table Profile data storage
---@field Listener table Event listener system
---@field PlayerClass string Current player class (e.g., "HUNTER")
---@field PlayerSpec number Current specialization ID
---@field PlayerRace string Current player race
---@field PlayerGUID string Current player GUID
---@field IamHealer boolean Player is a healer spec
---@field IamTank boolean Player is a tank spec
---@field IamMelee boolean Player is melee spec
---@field ZoneID number Current zone ID
---@field InstanceInfo table Instance information
---@field IsInPvP boolean Player is in PvP content
---@field IsInInstance boolean Player is in an instance
---@field IsInRaid boolean Player is in a raid
---@field IsInDungeon boolean Player is in a dungeon
Action = {}

--- Creates a new action object (Spell, Item, Trinket, etc.)
---@param args ActionCreateArgs Configuration table
---@return ActionObject action The created action object
---@see ActionObject
function Action.Create(args) end

--- Get toggle value from user settings
---@param tab number|string Tab index or name
---@param key string Setting key
---@return any value The setting value
function Action.GetToggle(tab, key) end

--- Set toggle value in user settings
---@param arg table|string Toggle identifier
---@param custom? any Custom value
---@param opposite? boolean Set opposite value
function Action.SetToggle(arg, custom, opposite) end

--- Check if burst mode is enabled for unit
---@param unit? string Unit ID (default: "target")
---@return boolean enabled Burst mode active
function Action.BurstIsON(unit) end

--- Get total GCD duration
---@return number duration GCD duration in seconds
function Action.GetGCD() end

--- Get remaining GCD time
---@return number remaining Remaining GCD in seconds
function Action.GetCurrentGCD() end

--- Check if GCD is active
---@return boolean active GCD is currently active
function Action.IsActiveGCD() end

--- Get network latency
---@return number latency Latency in seconds
function Action.GetPing() end

--- Get latency (alias for GetPing)
---@return number latency Latency in seconds
function Action.GetLatency() end

--- Check if player is casting (should stop rotation)
---@return boolean casting Player is casting
function Action.ShouldStop() end

--- Main rotation entry point
---@param icon any Icon frame reference
---@return any result Rotation result
function Action.Rotation(icon) end

--- Hide icon display
---@param icon any Icon frame reference
function Action.Hide(icon) end

--- Check if unit is a valid enemy
---@param unitID string Unit ID to check
---@return boolean isEnemy Unit is attackable enemy
function Action.IsUnitEnemy(unitID) end

--- Check if unit is a valid friendly
---@param unitID string Unit ID to check
---@return boolean isFriendly Unit is friendly
function Action.IsUnitFriendly(unitID) end

--- Get aura list by category key
---@param key string Aura category (e.g., "Stuned", "TotalImun")
---@return table auras List of spell IDs
function Action.GetAuraList(key) end

--- Add action to queue via macro
---@param key string Action key identifier
---@param args? table Optional queue arguments
function Action.MacroQueue(key, args) end

--- Toggle action blocker via macro
---@param key string Action key identifier
function Action.MacroBlocker(key) end

--- Check if any queue is running
---@return boolean running Queue has items
function Action.IsQueueRunning() end

--- Check if auto queue is active
---@return boolean running Auto queue active
function Action.IsQueueRunningAuto() end

--- Clear all queued actions
function Action.CancelAllQueue() end

--- Validate interrupt opportunity
---@param unit string Unit to interrupt
---@param toggle? boolean Check toggle setting
---@param ignore? boolean Ignore blacklist
---@param countGCD? number GCDs to account for
---@return boolean kick Can kick
---@return boolean cc Can CC
---@return boolean racial Can use racial
---@return boolean notPossible Not possible
---@return number remain Cast remaining
---@return string doneBy Who will interrupt
function Action.InterruptIsValid(unit, toggle, ignore, countGCD) end

--- Check if spell is in interrupt list
---@param category string Interrupt category
---@param spellName string Spell name
---@return boolean enabled Spell should be interrupted
function Action.InterruptEnabled(category, spellName) end

--- Check if unit/spell is blacklisted from interrupt
---@param unit string Unit ID
---@param spellName string Spell name
---@return boolean blacklisted Is blacklisted
function Action.InterruptIsBlackListed(unit, spellName) end

--- Toggle PvE/PvP mode
function Action.ToggleMode() end

--- Toggle AoE mode
function Action.ToggleAoE() end

--- Toggle burst mode
---@param fixed? boolean Fixed value
---@param between? table Range values
function Action.ToggleBurst(fixed, between) end

--- Toggle role
---@param fixed? boolean Fixed value
---@param between? table Range values
function Action.ToggleRole(fixed, between) end

--- Set a timer
---@param name string Timer name
---@param timer number Duration in seconds
---@param callback function Callback function
---@param nodestroy? boolean Don't auto-destroy
function Action.TimerSet(name, timer, callback, nodestroy) end

--- Set a ticker timer
---@param name string Timer name
---@param timer number Interval in seconds
---@param callback function Callback function
---@param iterations? number Max iterations
function Action.TimerSetTicker(name, timer, callback, iterations) end

--- Set a refreshable timer
---@param name string Timer name
---@param timer number Duration in seconds
---@param callback function Callback function
function Action.TimerSetRefreshAble(name, timer, callback) end

--- Get timer remaining time
---@param name string Timer name
---@return number|nil remaining Remaining time or nil
function Action.TimerGetTime(name) end

--- Destroy a timer
---@param name string Timer name
function Action.TimerDestroy(name) end

--- Trim whitespace from left of string
---@param s string Input string
---@return string trimmed Trimmed string
function Action.LTrim(s) end

--- Make a table read-only
---@param tabl table Table to protect
---@return table readonly Read-only table
function Action.MakeTableReadOnly(tabl) end

--- Create a cached function (static interval)
---@param func function Function to cache
---@param interval? number Cache duration (optional)
---@return function cached Cached function
function Action.MakeFunctionCachedStatic(func, interval) end

--- Create a cached function (dynamic interval)
---@param func function Function to cache
---@param interval? number Cache duration (optional)
---@return function cached Cached function
function Action.MakeFunctionCachedDynamic(func, interval) end

--- Check if mouse is over a frame
---@return boolean hasFrame Mouse over UI frame
function Action.MouseHasFrame() end

--- Check if frame has specific spell
---@param frame any Frame reference
---@param spellID number Spell ID to check
---@return boolean hasSpell Frame shows spell
function Action.FrameHasSpell(frame, spellID) end

--- Check if frame has specific object
---@param frame any Frame reference
---@param ... any Objects to check
---@return boolean hasObject Frame shows object
function Action.FrameHasObject(frame, ...) end

--- Insert multiple values into table
---@param t table Target table
---@param ... any Values to insert
function Action.TableInsertMulti(t, ...) end

--- Check/set black background visibility
---@return boolean shown Background is shown
function Action.BlackBackgroundIsShown() end

--- Set black background visibility
---@param bool boolean Show/hide background
function Action.BlackBackgroundSet(bool) end

--- Update spell book cache
---@param IsLoadingProfileOrPetUPDOWN? boolean Loading context
function Action.UpdateSpellBook(IsLoadingProfileOrPetUPDOWN) end

--- Determine usable object from list
---@param unitID string Target unit
---@param skipRange? boolean Skip range check
---@param skipLua? boolean Skip Lua check
---@param skipShouldStop? boolean Skip casting check
---@param skipUsable? boolean Skip usable check
---@param ... ActionObject Actions to check
---@return ActionObject|nil usable First usable action
function Action.DetermineUsableObject(unitID, skipRange, skipLua, skipShouldStop, skipUsable, ...) end

--- Determine heal object from list
---@param unitID string Target unit
---@param skipRange? boolean Skip range check
---@param skipLua? boolean Skip Lua check
---@param skipShouldStop? boolean Skip casting check
---@param skipUsable? boolean Skip usable check
---@param ... ActionObject Actions to check
---@return ActionObject|nil usable First usable heal action
function Action.DetermineHealObject(unitID, skipRange, skipLua, skipShouldStop, skipUsable, ...) end

--- Check if any object is current cast
---@param ... ActionObject Actions to check
---@return boolean isCurrent One of actions is current
function Action.DetermineIsCurrentObject(...) end

--- Count GCDs worth of actions
---@param ... ActionObject Actions to count
---@return number count GCD count
function Action.DetermineCountGCDs(...) end

--- Get total power cost of actions
---@param ... ActionObject Actions to check
---@return number cost Total power cost
function Action.DeterminePowerCost(...) end

--- Get shortest cooldown from actions
---@param ... ActionObject Actions to check
---@return number cooldown Shortest cooldown
function Action.DetermineCooldown(...) end

--- Get average cooldown from actions
---@param ... ActionObject Actions to check
---@return number cooldown Average cooldown
function Action.DetermineCooldownAVG(...) end

-- Consumable helpers
---@param icon any Icon reference
---@return boolean canUse Can use mana rune
function Action.CanUseManaRune(icon) end

---@param icon any Icon reference
---@return boolean canUse Can use healing potion
function Action.CanUseHealingPotion(icon) end

---@param icon any Icon reference
---@return boolean canUse Can use limited invulnerability potion
function Action.CanUseLimitedInvulnerabilityPotion(icon) end

---@param icon any Icon reference
---@param inRange? boolean Check range
---@return boolean canUse Can use living action potion
function Action.CanUseLivingActionPotion(icon, inRange) end

---@param icon any Icon reference
---@param toggle? boolean Check toggle
---@return boolean canUse Can use restorative potion
function Action.CanUseRestorativePotion(icon, toggle) end

---@param icon any Icon reference
---@param unitID? string Target unit
---@param range? number Range check
---@return boolean canUse Can use swiftness potion
function Action.CanUseSwiftnessPotion(icon, unitID, range) end

---@param icon any Icon reference
---@return boolean canUse Can use stoneform for defense
function Action.CanUseStoneformDefense(icon) end

---@param icon any Icon reference
---@param toggle? boolean Check toggle
---@return boolean canUse Can use stoneform for dispel
function Action.CanUseStoneformDispel(icon, toggle) end

--- Get Unit API for a unit
---@param unitID string Unit ID (e.g., "target", "player", "focus")
---@return Unit unit Unit API object
function Action.Unit(unitID) end

--- Friendly-team selection API for a role. Iterates allies matching ROLE and
--- returns selection helpers (GetUnitID, GetCC, GetBuffs, GetTTD, ...).
---@param ROLE? string "TANK" | "HEALER" | "DAMAGER" | "DAMAGER_MELEE" | "DAMAGER_RANGE" | nil (any). Unit-not-found returns "none".
---@return FriendlyTeam team Friendly-team selection API
function Action.FriendlyTeam(ROLE) end

--- Enemy-team selection API for a role. Iterates enemies matching ROLE and
--- returns selection helpers (GetUnitID, IsBreakAble, PlayersInRange, FocusingUnitIDByClasses, ...).
---@param ROLE? string "TANK" | "HEALER" | "DAMAGER" | "DAMAGER_MELEE" | "DAMAGER_RANGE" | nil (any). Unit-not-found returns "none".
---@return EnemyTeam team Enemy-team selection API
function Action.EnemyTeam(ROLE) end
