-- Common Schema Sections
-- Shared section factories used by all class schemas to avoid duplication.
-- Must load before any schema.lua (order 0 in build.ts).

local _G = _G

_G.FluxAIO_SECTIONS = {
    dashboard = function()
        return { header = "Dashboard", settings = {
            { type = "checkbox", key = "show_dashboard", default = false, label = "Show Dashboard",
              tooltip = "Display the combat dashboard overlay (/flux status)." },
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
}
