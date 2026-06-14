-- Menagerie - ProfileUI Generator
-- Reads _G.Menagerie_SETTINGS_SCHEMA and generates A.Data.ProfileUI[2]
-- Generic: works for any class that provides a schema

local _G = _G
local A = _G.Action
if not A then return end

local schema = _G.Menagerie_SETTINGS_SCHEMA
if not schema then return end

-- Inject internal position storage into the schema so it flows through the
-- exact same build_widget → ProfileUI → pActionDB pipeline as every other setting.
-- The custom settings UI skips entries with hidden = true.
if schema[1] and schema[1].sections and schema[1].sections[1] then
    local s = schema[1].sections[1].settings
    s[#s + 1] = { type = "slider", key = "_btn_x", label = "", default = -1, min = -10000, max = 10000, hidden = true }
    s[#s + 1] = { type = "slider", key = "_btn_y", label = "", default = -1, min = -10000, max = 10000, hidden = true }
    s[#s + 1] = { type = "slider", key = "_dash_x", label = "", default = -1, min = -10000, max = 10000, hidden = true }
    s[#s + 1] = { type = "slider", key = "_dash_y", label = "", default = -1, min = -10000, max = 10000, hidden = true }
end

-- ============================================================================
-- PROFILE UI GENERATOR
-- ============================================================================
-- Builds A.Data.ProfileUI[2] from the schema so the framework's built-in UI
-- has all settings registered with correct keys, defaults, and types.

local function build_widget(st, empty)
    if st.type == "dropdown" then
        local ot = {}
        for j, opt in ipairs(st.options) do
            ot[j] = { text = opt.text, value = opt.value }
        end
        return { E = "Dropdown", DB = st.key, DBV = st.default, OT = ot,
            L = { ANY = st.label }, TT = { ANY = st.tooltip }, M = empty }
    elseif st.type == "checkbox" then
        return { E = "Checkbox", DB = st.key, DBV = st.default,
            L = { enUS = st.label }, TT = { enUS = st.tooltip }, M = empty }
    elseif st.type == "slider_decimal" then
        -- Decimal slider: legacy GGL StdUi takes Precision (decimal count).
        -- Schema's `precision` field maps directly (default 1 = 0.1 step).
        return { E = "Slider", DB = st.key, DBV = st.default,
            MIN = st.min, MAX = st.max, Precision = st.precision or 1,
            L = { enUS = st.label }, TT = { enUS = st.tooltip }, M = empty }
    else
        return { E = "Slider", DB = st.key, DBV = st.default,
            MIN = st.min, MAX = st.max,
            L = { enUS = st.label }, TT = { enUS = st.tooltip }, M = empty }
    end
end

local function generate_profile_ui(s)
    local profile_ui = {}
    local empty = {}

    -- Title header
    profile_ui[#profile_ui + 1] = {
        { E = "Header", L = { enUS = "Menagerie Rotation Settings" }, S = 16 }
    }

    -- Iterate all tabs in the schema
    for _, tab_def in ipairs(s) do
        if tab_def.sections then
            -- Tab header
            profile_ui[#profile_ui + 1] = {
                { E = "Header", L = { enUS = tab_def.name .. " Settings" }, S = 14 }
            }

            for _, section in ipairs(tab_def.sections) do
                -- Section header
                profile_ui[#profile_ui + 1] = {
                    { E = "Header", L = { enUS = section.header }, S = 12 }
                }

                -- Group settings into rows of 2
                local settings = section.settings
                local i = 1
                while i <= #settings do
                    local st = settings[i]
                    local row = { build_widget(st, empty) }

                    if not st.wide and i + 1 <= #settings then
                        local next_st = settings[i + 1]
                        if not next_st.wide then
                            i = i + 1
                            row[#row + 1] = build_widget(next_st, empty)
                        end
                    end

                    profile_ui[#profile_ui + 1] = row
                    i = i + 1
                end
            end
        end
    end

    return profile_ui
end

-- ============================================================================
-- GENERATE PROFILE UI
-- ============================================================================
A.Data.ProfileUI = {
    DateTime = "v2.5 (17.02.2026)",
    [2] = generate_profile_ui(schema),
}

print("|cFF00FF00[Menagerie]|r ProfileUI generated")
