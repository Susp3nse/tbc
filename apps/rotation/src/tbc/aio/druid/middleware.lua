--- Middleware Module
--- Cross-form middleware (recovery items, offensive CDs)
--- Part of the modular rotation system
--- Loads after: core.lua, healing.lua

-- ============================================================
-- Middleware runs before strategies every frame, regardless of
-- active playstyle. Only cross-form concerns belong here.
-- Caster-specific abilities (heals, dispels, innervate, self-buffs)
-- are in caster.lua as caster strategies.
--
-- IMPORTANT: NEVER capture settings values at load time!
-- Settings can change at runtime (e.g., playstyle switching).
-- Always access settings through context.settings in matches/execute.
-- ============================================================

-- Get namespace from Core module
local NS = _G.FluxAIO
if not NS then
   print("|cFFFF0000[Flux AIO Middleware]|r Core module not loaded!")
   return
end

-- Validate dependencies
if not NS.rotation_registry then
   print("|cFFFF0000[Flux AIO Middleware]|r Registry not found in Core!")
   return
end
-- Import commonly used references
local A = NS.A
local Constants = NS.Constants
local Priority = NS.Priority
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local RACE_TROLL = NS.RACE_TROLL
local RACE_ORC = NS.RACE_ORC
local get_form_cost = NS.get_form_cost

-- Lua optimizations
local format = string.format
local GetTime = GetTime

-- ============================================================================
-- CONSUMABLE HELPERS
-- ============================================================================

-- Stances where consumable use is allowed
-- Caster(0), Cat(3) always; stance 5 only if moonkin/tree (not flight)
-- Blocked: Bear(1), Aquatic(2), Travel(4), Flight(5 without talent), Swift Flight(6)
local ITEM_ALLOWED_STANCE = {
   [0] = true,
   [3] = true,
}

--- Check if current stance allows consumable use
local function can_use_items(stance)
   if ITEM_ALLOWED_STANCE[stance] then return true end
   if stance == 5 then
      return _G.IsSpellKnown(24858) or _G.IsSpellKnown(33891)
   end
   return false
end

-- Stance-to-form-spell lookup for shifting back after item use
local STANCE_FORM_SPELL = {
   [Constants.STANCE.CAT]  = A.CatForm,
   [Constants.STANCE.BEAR] = A.BearForm,
}

--- Check if we can afford to shift back after using an item in a shifted form
--- In caster form no reshift is needed; in cat/bear we need mana for the form spell
local function can_afford_reshift(stance)
   local form_spell = STANCE_FORM_SPELL[stance]
   if not form_spell then return true end  -- caster/moonkin: no reshift needed
   return Player:Mana() >= get_form_cost(form_spell)
end

-- ============================================================================
-- FORM-AWARE CONSUMABLE LOOKUP
-- Maps base item actions to their spell-based form variants.
-- Form variants use the form spell as primary action with macrobefore to
-- /cancelform + /use ItemName, attempting single-click use + reshift.
-- ============================================================================
local CAT_VARIANT = {
   [A.HealthstoneMaster]  = A.HealthstoneMasterCat,
   [A.HealthstoneMajor]   = A.HealthstoneMajorCat,
   [A.SuperHealingPotion]  = A.SuperHealingPotionCat,
   [A.MajorHealingPotion]  = A.MajorHealingPotionCat,
   [A.SuperManaPotion]     = A.SuperManaPotionCat,
   [A.DarkRune]            = A.DarkRuneCat,
   [A.DemonicRune]         = A.DemonicRuneCat,
}

local BEAR_VARIANT = {
   [A.HealthstoneMaster]  = A.HealthstoneMasterBear,
   [A.HealthstoneMajor]   = A.HealthstoneMajorBear,
   [A.SuperHealingPotion]  = A.SuperHealingPotionBear,
   [A.MajorHealingPotion]  = A.MajorHealingPotionBear,
   [A.SuperManaPotion]     = A.SuperManaPotionBear,
   [A.DarkRune]            = A.DarkRuneBear,
   [A.DemonicRune]         = A.DemonicRuneBear,
}

--- Get the form-appropriate action for a consumable.
--- In Cat/Bear, returns the spell-based variant (single-click reshift).
--- In Caster/Moonkin/etc, returns the base item action.
local function form_action(base, stance)
   if stance == Constants.STANCE.CAT then
      return CAT_VARIANT[base] or base
   elseif stance == Constants.STANCE.BEAR then
      return BEAR_VARIANT[base] or base
   end
   return base
end

-- ============================================================================
-- FORM RE-SHIFT STATE (safety net for consumable form-shifting)
-- Primary approach: spell-based form variants (Cat Form / Dire Bear Form as
-- primary action with macrobefore to /cancelform + /use ItemName). This
-- attempts single-click item use + reshift.
-- Safety net: if the form cast doesn't fire (WoW secure action limitation),
-- schedule_reshift records which form to return to, and FormReshift
-- middleware shows the form spell on the next frame.
-- ============================================================================
local pending_reshift = nil -- { spell = A.CatForm/A.BearForm, expire = time }

--- Schedule a form re-shift after consumable use
--- @param stance number The stance the player WAS in before item use
local function schedule_reshift(stance)
   local spell = STANCE_FORM_SPELL[stance]
   if spell then
      pending_reshift = { spell = spell, expire = GetTime() + 3 }
   end
end

-- ============================================================================
-- FORM RE-SHIFT MIDDLEWARE (highest priority -- fires after consumable use)
-- ============================================================================
do
   rotation_registry:register_middleware({
      name = "FormReshift",
      priority = Priority.MIDDLEWARE.FORM_RESHIFT,

      matches = function(context)
         if not pending_reshift then return false end

         -- Expired? Clear and skip
         if GetTime() > pending_reshift.expire then
            pending_reshift = nil
            return false
         end

         -- Only fire if we're in caster form (item cancelled our form)
         if context.stance ~= Constants.STANCE.CASTER then
            -- Already back in a form (player shifted manually?) -- clear
            pending_reshift = nil
            return false
         end

         return true
      end,

      execute = function(icon, context)
         local spell = pending_reshift.spell

         if spell:IsReady(PLAYER_UNIT) then
            local result = spell:Show(icon)
            if result then
               pending_reshift = nil
               return result, format("[RESHIFT] Shifting back to %s", spell.Desc or "form")
            end
         end

         -- Leave pending_reshift alive so we retry next frame (expiry handles cleanup)
         return nil
      end,
   })
end

-- ============================================================================
-- RECOVERY ITEMS MIDDLEWARE
-- ============================================================================
do
   rotation_registry:register_middleware({
      name = "RecoveryItems",
      priority = Priority.MIDDLEWARE.RECOVERY_ITEMS,

      matches = function(context)
         if not context.in_combat or context.is_stealthed or not can_use_items(context.stance) then
            return false
         end

         -- Don't use items if we can't afford to shift back afterward
         if not can_afford_reshift(context.stance) then
            return false
         end

         local settings = context.settings

         -- Check if healthstone needed AND exists
         if settings.use_healthstone and context.hp <= settings.healthstone_hp then
            if (A.HealthstoneMaster:IsExists() and A.HealthstoneMaster:IsReady(PLAYER_UNIT)) or
               (A.HealthstoneMajor:IsExists() and A.HealthstoneMajor:IsReady(PLAYER_UNIT)) then
               return true
            end
         end

         -- Check if healing potion needed AND exists
         if settings.use_healing_potion and context.hp <= settings.healing_potion_hp then
            if (A.SuperHealingPotion:IsExists() and A.SuperHealingPotion:IsReady(PLAYER_UNIT)) or
               (A.MajorHealingPotion:IsExists() and A.MajorHealingPotion:IsReady(PLAYER_UNIT)) then
               return true
            end
         end

         return false
      end,

      execute = function(icon, context)
         local settings = context.settings
         local stance = context.stance

         -- Safety net: schedule form re-shift in case the spell-based variant
         -- doesn't fire the form cast (WoW secure action limitation)
         schedule_reshift(stance)

         -- Healthstone (matches already verified exists and ready)
         if settings.use_healthstone and context.hp <= settings.healthstone_hp then
            if A.HealthstoneMaster:IsExists() then
               local action = form_action(A.HealthstoneMaster, stance)
               local result = action:Show(icon)
               if result then
                  return result, format("[ITEM] Using Master Healthstone - HP: %.1f%%", context.hp)
               end
            elseif A.HealthstoneMajor:IsExists() then
               local action = form_action(A.HealthstoneMajor, stance)
               local result = action:Show(icon)
               if result then
                  return result, format("[ITEM] Using Major Healthstone - HP: %.1f%%", context.hp)
               end
            end
         end

         -- Healing Potion (matches already verified exists and ready)
         if settings.use_healing_potion and context.hp <= settings.healing_potion_hp then
            if A.SuperHealingPotion:IsExists() then
               local action = form_action(A.SuperHealingPotion, stance)
               local result = action:Show(icon)
               if result then
                  return result, format("[ITEM] Using Super Healing Potion - HP: %.1f%%", context.hp)
               end
            elseif A.MajorHealingPotion:IsExists() then
               local action = form_action(A.MajorHealingPotion, stance)
               local result = action:Show(icon)
               if result then
                  return result, format("[ITEM] Using Major Healing Potion - HP: %.1f%%", context.hp)
               end
            end
         end

         return nil
      end,
   })
end

-- ============================================================================
-- MANA RECOVERY MIDDLEWARE (mana potion + dark/demonic rune)
-- ============================================================================
do
   rotation_registry:register_middleware({
      name = "ManaRecovery",
      priority = Priority.MIDDLEWARE.MANA_RECOVERY,

      matches = function(context)
         if not context.in_combat or context.is_stealthed or not can_use_items(context.stance) then
            return false
         end

         -- Mana items skip the reshift mana check -- the potion/rune itself
         -- provides more than enough mana (~1800+) to cover the ~435 shift cost.
         -- The reshift retry loop handles the 1-frame delay for mana to land.

         local settings = context.settings

         -- Check mana potion (shares potion cooldown with healing pots)
         if settings.use_mana_potion and context.mana_pct <= settings.mana_potion_mana then
            if A.SuperManaPotion:IsExists() and A.SuperManaPotion:IsReady(PLAYER_UNIT) then
               return true
            end
         end

         -- Check dark rune / demonic rune (own cooldown, separate from potions)
         if settings.use_dark_rune and context.mana_pct <= settings.dark_rune_mana then
            if (A.DarkRune:IsExists() and A.DarkRune:IsReady(PLAYER_UNIT)) or
               (A.DemonicRune:IsExists() and A.DemonicRune:IsReady(PLAYER_UNIT)) then
               -- Dark Rune costs HP -- only if HP is safe
               if context.hp > settings.dark_rune_min_hp then
                  return true
               end
            end
         end

         return false
      end,

      execute = function(icon, context)
         local settings = context.settings
         local stance = context.stance

         -- Safety net: schedule form re-shift in case the spell-based variant
         -- doesn't fire the form cast (WoW secure action limitation)
         schedule_reshift(stance)

         -- Super Mana Potion (try first -- no HP cost)
         if settings.use_mana_potion and context.mana_pct <= settings.mana_potion_mana then
            if A.SuperManaPotion:IsExists() and A.SuperManaPotion:IsReady(PLAYER_UNIT) then
               local action = form_action(A.SuperManaPotion, stance)
               local result = action:Show(icon)
               if result then
                  return result, format("[ITEM] Using Super Mana Potion - Mana: %.1f%%", context.mana_pct)
               end
            end
         end

         -- Dark Rune / Demonic Rune (costs 600-1000 HP for 900-1500 mana)
         if settings.use_dark_rune and context.mana_pct <= settings.dark_rune_mana
            and context.hp > settings.dark_rune_min_hp then
            if A.DarkRune:IsExists() and A.DarkRune:IsReady(PLAYER_UNIT) then
               local action = form_action(A.DarkRune, stance)
               local result = action:Show(icon)
               if result then
                  return result, format("[ITEM] Using Dark Rune - Mana: %.1f%%, HP: %.1f%%", context.mana_pct, context.hp)
               end
            elseif A.DemonicRune:IsExists() and A.DemonicRune:IsReady(PLAYER_UNIT) then
               local action = form_action(A.DemonicRune, stance)
               local result = action:Show(icon)
               if result then
                  return result, format("[ITEM] Using Demonic Rune - Mana: %.1f%%, HP: %.1f%%", context.mana_pct, context.hp)
               end
            end
         end

         return nil
      end,
   })
end

-- ============================================================================
-- BARKSKIN DEFENSIVE MIDDLEWARE (off-GCD, usable in all forms)
-- ============================================================================
do
   local is_spell_available = NS.is_spell_available
   local is_buff_active = NS.is_buff_active

   rotation_registry:register_middleware({
      name = "Barkskin",
      priority = 310,
      is_defensive = true,
      is_gcd_gated = false,
      setting_key = "use_barkskin",

      matches = function(context)
         if not context.in_combat then return false end
         -- Barkskin drops bear/cat forms on this server; block during reshift window
         if pending_reshift then return false end
         local stance = context.stance
         if stance == Constants.STANCE.BEAR or stance == Constants.STANCE.CAT then return false end
         if not is_spell_available(A.SelfBarkskin) then return false end
         local threshold = context.settings.barkskin_hp or 40
         if context.hp > threshold then return false end
         if is_buff_active(A.SelfBarkskin, PLAYER_UNIT) then return false end
         if not A.SelfBarkskin:IsReady(PLAYER_UNIT) then return false end
         return true
      end,

      execute = function(icon, context)
         local result = A.SelfBarkskin:Show(icon)
         if result then
            return result, format("[MW] Barkskin - HP: %.0f%%", context.hp)
         end
         return nil
      end,
   })
end

-- Shared trinket middleware (burst + defensive, schema-driven)
NS.register_trinket_middleware()

print("|cFF00FF00[Flux AIO Middleware]|r " .. #rotation_registry.middleware .. " middleware handlers registered.")
