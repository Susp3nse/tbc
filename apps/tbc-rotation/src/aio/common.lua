-- Common Schema Sections
-- Shared section factories used by all class schemas to avoid duplication.
-- Must load before any schema.lua (order 0 in build.ts).

local _G = _G

_G.Menagerie_SECTIONS = {
    dashboard = function()
        return { header = "Dashboard", settings = {
            { type = "checkbox", key = "show_dashboard", default = false, label = "Show Dashboard",
              tooltip = "Display the combat dashboard overlay (/menagerie status)." },
        }}
    end,

    burst = function()
        return { header = "Burst Conditions", description = "When to automatically use burst cooldowns.", settings = {
            { type = "checkbox", key = "burst_on_bloodlust", default = false, label = "During Bloodlust/Heroism",
              tooltip = "Auto-burst when Bloodlust or Heroism buff is detected." },
            { type = "checkbox", key = "burst_on_pull", default = false, label = "On Pull (first 5s)",
              tooltip = "Auto-burst within the first 5 seconds of combat." },
            { type = "checkbox", key = "burst_on_execute", default = false, label = "Execute Phase (<20% HP)",
              tooltip = "Auto-burst when target is below 20% health." },
            { type = "checkbox", key = "burst_in_combat", default = false, label = "Always in Combat",
              tooltip = "Always auto-burst when in combat with a valid target (most aggressive)." },
        }}
    end,

    debug = function()
        return { header = "Debug", settings = {
            { type = "checkbox", key = "debug_mode", default = true, label = "Debug Mode",
              tooltip = "Print rotation debug messages." },
            { type = "checkbox", key = "debug_system", default = false, label = "Debug System (Advanced)",
              tooltip = "Print system debug messages (middleware, strategies)." },
            { type = "checkbox", key = "log_context", default = false, label = "Log Context",
              tooltip = "Print full context state to debug log every 2s during combat." },
            { type = "checkbox", key = "show_debug_panel", default = false, label = "Show Debug Panel",
              tooltip = "Enable the live state debug panel, then use /mdebug to open it." },
            { type = "checkbox", key = "suppress_spell_warnings", default = false, label = "Suppress Missing-Spell Warnings",
              tooltip = "Hide the 'missing required/optional spells' chat messages printed on playstyle switch. Useful while leveling when not all spells are trained yet." },
        }}
    end,

    immunity = function()
        return { header = "Immunity Learning", settings = {
            { type = "slider", key = "immune_learn_ttl_min", default = 5, min = 1, max = 60,
              label = "Learned Immunity Memory (min)",
              tooltip = "After a spell is resisted as Immune on a creature, remember it for this long so the rotation stops re-casting it. Learned per creature type, not per individual mob.",
              format = "%d min" },
        }}
    end,

    cooldowns = function(opts)
        opts = opts or {}
        return { header = "Cooldown Management", settings = {
            { type = "slider", key = "cd_min_ttd", default = 0, min = 0, max = 60,
              label = opts.label or "CD Min TTD (sec)",
              tooltip = opts.tooltip or "Don't use major CDs (trinkets, racial) if target dies sooner than this. Set to 0 to disable.",
              format = "%d sec" },
        }}
    end,

    spec = function(opts)
        opts = opts or {}
        return { header = "Spec Selection", settings = {
            { type = "dropdown", key = "playstyle", default = opts.default, label = opts.label or "Active Spec",
              tooltip = opts.tooltip or "Which spec rotation to use.",
              options = opts.options },
        }}
    end,

    trinkets = function(racial_tooltip)
        return { header = "Trinkets & Racial", settings = {
            { type = "dropdown", key = "trinket1_mode", default = "off", label = "Trinket 1",
              tooltip = "Off = never use. Offensive = fires during burst. Defensive = fires during def.",
              options = {
                  { value = "off", text = "Off" },
                  { value = "offensive", text = "Offensive (Burst)" },
                  { value = "defensive", text = "Defensive" },
              }},
            { type = "dropdown", key = "trinket2_mode", default = "off", label = "Trinket 2",
              tooltip = "Off = never use. Offensive = fires during burst. Defensive = fires during def.",
              options = {
                  { value = "off", text = "Off" },
                  { value = "offensive", text = "Offensive (Burst)" },
                  { value = "defensive", text = "Defensive" },
              }},
            { type = "checkbox", key = "use_racial", default = true, label = "Use Racial",
              tooltip = racial_tooltip or "Use racial ability during combat." },
        }}
    end,

    recovery = function(opts)
        opts = opts or {}
        return { header = opts.header or "Recovery", settings = {
            { type = "slider", key = "healthstone_hp", default = opts.healthstone_hp or 35,
              min = opts.healthstone_min or 0, max = opts.healthstone_max or 100,
              label = opts.healthstone_label or "Healthstone HP (%)",
              tooltip = opts.healthstone_tooltip or "Use Healthstone when HP drops below this. Set to 0 to disable.",
              format = opts.healthstone_format or "%d%%" },
            { type = "checkbox", key = "use_healing_potion", default = opts.use_healing_potion ~= false,
              label = opts.healing_potion_toggle_label or "Use Healing Potion",
              tooltip = opts.healing_potion_toggle_tooltip or "Use healing potion when HP drops below threshold." },
            { type = "slider", key = "healing_potion_hp", default = opts.healing_potion_hp or 25,
              min = opts.healing_potion_min or 10, max = opts.healing_potion_max or 50,
              label = opts.healing_potion_label or "Healing Potion HP (%)",
              tooltip = opts.healing_potion_tooltip or "Use Healing Potion below this HP.",
              format = opts.healing_potion_format or "%d%%" },
        }}
    end,

    mana_recovery = function(opts)
        opts = opts or {}
        local settings = {}

        if opts.mana_potion then
            settings[#settings + 1] = { type = "checkbox", key = "use_mana_potion",
              default = opts.use_mana_potion ~= false, label = opts.mana_potion_toggle_label or "Use Mana Potion",
              tooltip = opts.mana_potion_toggle_tooltip or "Use Mana Potion when mana drops below threshold." }
            settings[#settings + 1] = { type = "slider", key = "mana_potion_pct",
              default = opts.mana_potion_pct or 50, min = opts.mana_potion_min or 10,
              max = opts.mana_potion_max or 80, label = opts.mana_potion_label or "Mana Potion Below%",
              tooltip = opts.mana_potion_tooltip or "Use Mana Potion below this mana %.",
              format = opts.mana_potion_format or "%d%%" }
        end

        if opts.dark_rune then
            settings[#settings + 1] = { type = "checkbox", key = "use_dark_rune",
              default = opts.use_dark_rune ~= false, label = opts.dark_rune_toggle_label or "Use Dark Rune",
              tooltip = opts.dark_rune_toggle_tooltip or "Use Dark Rune / Demonic Rune when mana drops below threshold. Costs HP.",
              wide = opts.dark_rune_wide }
            settings[#settings + 1] = { type = "slider", key = "dark_rune_pct",
              default = opts.dark_rune_pct or 50, min = opts.dark_rune_min or 10,
              max = opts.dark_rune_max or 80, label = opts.dark_rune_label or "Dark Rune Below%",
              tooltip = opts.dark_rune_tooltip or "Use Dark Rune below this mana %.",
              format = opts.dark_rune_format or "%d%%" }
            settings[#settings + 1] = { type = "slider", key = "dark_rune_min_hp",
              default = opts.dark_rune_min_hp or 50, min = opts.dark_rune_min_hp_min or 25,
              max = opts.dark_rune_min_hp_max or 75, label = opts.dark_rune_min_hp_label or "Dark Rune Min HP (%)",
              tooltip = opts.dark_rune_min_hp_tooltip or "Only use Dark Rune if HP is above this (rune costs 600-1000 HP).",
              format = opts.dark_rune_min_hp_format or "%d%%" }
        end

        return { header = opts.header or "Mana Recovery", settings = settings }
    end,
}
