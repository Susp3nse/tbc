-- Hunter Debug Panel (AIO)
-- Adapted from standalone Hunter_Debug_UI.lua
--
-- Visual debug panel with real-time Player/Target/Debuffs/PvP/Pet state.
-- Toggle via schema setting "show_debug_panel" (Tab 5 "Pet & Diag")
-- or /flux debug panel.

local _G, string = _G, string

local A = _G.Action

if not A then return end
if A.PlayerClass ~= "HUNTER" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Hunter Debug]|r Core module not loaded!")
    return
end

local HA                    = NS.A  -- Hunter action metatable (spell references)
local Player                = NS.Player
local Unit                  = NS.Unit
local GetGCD                = A.GetGCD
local Pet                   = LibStub("PetLibrary")
local UnitIsDeadOrGhost     = _G.UnitIsDeadOrGhost
local GetNumGroupMembers    = _G.GetNumGroupMembers
local CreateFrame           = _G.CreateFrame
local UIParent              = _G.UIParent

-- ============================================================================
-- THEME (matches settings.lua for visual consistency)
-- ============================================================================
local THEME = {
    bg          = { 0.031, 0.031, 0.039, 0.97 },
    bg_light    = { 0.047, 0.047, 0.059, 1 },
    bg_widget   = { 0.059, 0.059, 0.075, 1 },
    bg_hover    = { 0.075, 0.075, 0.086, 1 },
    border      = { 0.118, 0.118, 0.149, 1 },
    accent      = { 0.424, 0.388, 1.0, 1 },
    text        = { 0.863, 0.863, 0.894, 1 },
    text_dim    = { 0.580, 0.580, 0.659, 1 },
}

local BACKDROP_THIN = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

-- ============================================================================
-- STATE & CONFIG
-- ============================================================================

local HunterDebug = {
    Frame = nil,
    Lines = {},
    IsVisible = false,
}

-- Section header colors
local COLORS = {
    green   = "|cff00ff00",
    red     = "|cffff0000",
    yellow  = "|cffffff00",
    white   = "|cffffffff",
    orange  = "|cffff8800",
    cyan    = "|cff00ffff",
    header_player  = "|cff00ff00",   -- green
    header_target  = "|cffffff00",   -- yellow
    header_debuffs = "|cffff8800",   -- orange
    header_pvp     = "|cffff4444",   -- red
    header_pet     = "|cff00ffff",   -- cyan
}

local function yn(val)
    return val and (COLORS.green .. "YES") or (COLORS.red .. "NO")
end

local function fmt(val)
    return string.format("%.1f", val or 0)
end

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

function HunterDebug:CreateFrame()
    if self.Frame then return self.Frame end

    local f = CreateFrame("Frame", "HunterDebugPanel", UIParent, "BackdropTemplate")
    f:SetSize(440, 480)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -200)
    f:SetBackdrop(BACKDROP_THIN)
    f:SetBackdropColor(THEME.bg[1], THEME.bg[2], THEME.bg[3], THEME.bg[4])
    f:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], THEME.border[4])
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    f:Hide()

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 12, -8)
    f.title:SetText("Hunter Debug")
    f.title:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])

    -- Close button
    local close = CreateFrame("Button", nil, f)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -6, -6)
    local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeText:SetPoint("CENTER")
    closeText:SetText("x")
    closeText:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function() closeText:SetTextColor(1, 0.3, 0.3) end)
    close:SetScript("OnLeave", function() closeText:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3]) end)

    -- Separator below title
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 1, -28)
    sep:SetPoint("TOPRIGHT", -1, -28)
    sep:SetHeight(1)
    sep:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 1)

    -- Content starts below title + separator
    local content_top = -32

    -- Create debug lines
    self.Lines = {}
    local lineIndex = 0

    local function AddLine(fontTemplate)
        lineIndex = lineIndex + 1
        local line = f:CreateFontString(nil, "OVERLAY", fontTemplate or "GameFontHighlight")
        line:SetPoint("TOPLEFT", f, "TOPLEFT", 12, content_top - 8 - (lineIndex - 1) * 15)
        line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, content_top - 8 - (lineIndex - 1) * 15)
        line:SetJustifyH("LEFT")
        self.Lines[lineIndex] = line
        return lineIndex
    end

    local function AddSectionHeader()
        lineIndex = lineIndex + 1
        local line = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line:SetPoint("TOPLEFT", f, "TOPLEFT", 12, content_top - 8 - (lineIndex - 1) * 15 - 3)
        line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, content_top - 8 - (lineIndex - 1) * 15 - 3)
        line:SetJustifyH("LEFT")
        self.Lines[lineIndex] = line
        return lineIndex
    end

    -- Section 1: Player (3 lines: header + 2 data)
    AddSectionHeader()  -- 1: Player header
    AddLine()           -- 2: GCD, Mana
    AddLine()           -- 3: Context

    -- Section 2: Target (4 lines: header + 3 data)
    AddSectionHeader()  -- 4: Target header
    AddLine()           -- 5: Exists, HP%
    AddLine()           -- 6: Range, Mode
    AddLine()           -- 7: AtRange, InMelee

    -- Section 3: Debuffs (4 lines: header + 3 data)
    AddSectionHeader()  -- 8: Debuffs header
    AddLine()           -- 9: Serpent, Mark
    AddLine()           -- 10: WingClip, Concussive
    AddLine()           -- 11: Viper

    -- Section 4: PvP (7 lines: header + 6 data)
    AddSectionHeader()  -- 12: PvP header
    AddLine()           -- 13: Viper: Class, IsPlayer, IsMana
    AddLine()           -- 14: Viper: HP threshold, Priority, Ready
    AddLine()           -- 15: Viper: DebuffOK, verdict
    AddLine()           -- 16: Concussive: RangeOK, Ready, verdict
    AddLine()           -- 17: WingClip: Context, thresholds
    AddLine()           -- 18: WingClip: Priority, Ready, Imun

    -- Section 5: Pet State (5 lines: header + 4 data)
    AddSectionHeader()  -- 19: Pet header
    AddLine()           -- 20: Exists, HP%, Mending
    AddLine()           -- 21: Dead(API), Dead(Unit)
    AddLine()           -- 22: PetLib Active, CanCall, Attacking
    AddLine()           -- 23: Alive verdict

    self.Frame = f
    return f
end

-- ============================================================================
-- UPDATE DISPLAY
-- ============================================================================

function HunterDebug:UpdateDisplay()
    local L = self.Lines
    if not L[1] then return end

    local green = COLORS.green
    local red = COLORS.red
    local yellow = COLORS.yellow
    local white = COLORS.white

    local unit = "target"
    local pet = "pet"

    -- Gather data
    local targetExists = Unit(unit):IsExists() or false
    local targetHP = targetExists and (Unit(unit):HealthPercent() or 0) or 0
    local gcd = GetGCD and GetGCD() or 0
    local mana = Player and Player:ManaPercentage() or 0

    local atRange = targetExists and HA.ArcaneShot and HA.ArcaneShot:IsInRange(unit) or false
    local inMelee = targetExists and HA.WingClip and HA.WingClip:IsInRange(unit) or false
    local targetRange = targetExists and NS.GetRange and NS.GetRange(unit) or 0
    local rangeMode = inMelee and "MELEE" or (atRange and "RANGED" or "OUT OF RANGE")

    local inPvP = HA.IsInPvP or false
    local inGroup = GetNumGroupMembers() > 0
    local context = inPvP and "PvP" or (inGroup and "PvE Group" or "PvE Solo")

    -- Debuffs
    local serpentSting = 0
    local huntersMark = 0
    local wingClip = 0
    local concussive = 0
    local viperSting = 0

    if targetExists then
        serpentSting = Unit(unit):HasDeBuffs(HA.SerpentSting and HA.SerpentSting.ID or 1978, true) or 0
        huntersMark = Unit(unit):HasDeBuffs(HA.HuntersMark and HA.HuntersMark.ID or 1130) or 0
        wingClip = Unit(unit):HasDeBuffs(HA.WingClip and HA.WingClip.ID or 2974, true) or 0
        concussive = Unit(unit):HasDeBuffs(HA.ConcussiveShot and HA.ConcussiveShot.ID or 5116, true) or 0
        viperSting = Unit(unit):HasDeBuffs(HA.ViperSting and HA.ViperSting.ID or 3034, true) or 0
    end

    -- PvP checks
    local s = NS.cached_settings
    local concussiveRangeOK = targetRange > 0 and (targetRange < 10 or targetRange > 25)
    local concussiveReady = targetExists and HA.ConcussiveShot and HA.ConcussiveShot:IsReady(unit) or false
    local concussiveDebuffOK = concussive < 2
    local shouldConcussive = inPvP and concussiveRangeOK and concussiveDebuffOK and concussiveReady

    local viperHPThreshold = s.viper_sting_hp_threshold or 30
    local wcHPPvP = s.wing_clip_hp_pvp or 20
    local wcHPPvE = s.wing_clip_hp_pve or 20
    local wcHPThreshold = inPvP and wcHPPvP or wcHPPvE
    local targetClass = targetExists and Unit(unit):Class() or "NONE"
    local targetIsPlayer = targetExists and Unit(unit):IsPlayer() or false
    local targetPowerType = targetExists and Unit(unit):PowerType() or "NONE"
    local isManaUser = targetPowerType == "MANA"
    local viperHPok = targetHP >= viperHPThreshold
    local viperDebuffOK = viperSting <= gcd
    local viperReady = targetExists and HA.ViperSting and HA.ViperSting:IsReady(unit) or false
    local viperPriority = targetExists and HA.ShouldUseViperSting and HA.ShouldUseViperSting(unit) or false
    local shouldViper = inPvP and viperPriority and viperDebuffOK and viperReady

    -- WingClip checks
    local wcReady = targetExists and HA.WingClip and HA.WingClip:IsReady(unit) or false
    local wcImun = targetExists and HA.WingClip and HA.WingClip:AbsentImun(unit, {"TotalImun", "DamagePhysImun", "CCTotalImun"}) or false
    local wcPriority = targetExists and HA.ShouldUseWingClip and HA.ShouldUseWingClip(unit) or false

    -- Pet state
    local petExists = Unit(pet):IsExists() or false
    local petHP = petExists and (Unit(pet):HealthPercent() or 0) or 0
    local petIsDeadAPI = UnitIsDeadOrGhost("pet") or false
    local petIsDead = petExists and (Unit(pet):IsDead() or false) or false
    local petLibActive = Pet and Pet:IsActive() or false
    local petLibCanCall = Pet and Pet:CanCall() or false
    local petLibIsAttacking = Pet and Pet:IsAttacking() or false
    local petAlive = petLibActive or (petExists and not petIsDeadAPI)
    local mendPetBuff = petExists and HA.MendPet and (Unit(pet):HasBuffs(HA.MendPet.ID, true) or 0) or 0

    -- Format debuff helper
    local function debuff(val)
        return val > 0 and (green .. fmt(val) .. "s") or (red .. "NONE")
    end

    -------------------------------------------------------
    -- Section 1: Player
    -------------------------------------------------------
    L[1]:SetText(COLORS.header_player .. "--- PLAYER ---|r")
    L[2]:SetText(white .. "GCD: " .. yellow .. fmt(gcd) .. "s" .. white .. "  Mana: " .. yellow .. fmt(mana) .. "%")
    L[3]:SetText(white .. "Context: " .. yellow .. context)

    -------------------------------------------------------
    -- Section 2: Target
    -------------------------------------------------------
    L[4]:SetText(COLORS.header_target .. "--- TARGET ---|r")
    L[5]:SetText(white .. "Exists: " .. yn(targetExists) .. white .. "  HP: " .. yellow .. fmt(targetHP) .. "%")
    L[6]:SetText(white .. "Range: " .. yellow .. fmt(targetRange) .. "y" .. white .. "  Mode: " .. yellow .. rangeMode)
    L[7]:SetText(white .. "AtRange: " .. yn(atRange) .. white .. "  InMelee: " .. yn(inMelee))

    -------------------------------------------------------
    -- Section 3: Debuffs
    -------------------------------------------------------
    L[8]:SetText(COLORS.header_debuffs .. "--- DEBUFFS ---|r")
    L[9]:SetText(white .. "Serpent: " .. debuff(serpentSting) .. white .. "  Mark: " .. debuff(huntersMark))
    L[10]:SetText(white .. "WingClip: " .. debuff(wingClip) .. white .. "  Concuss: " .. debuff(concussive))
    L[11]:SetText(white .. "Viper: " .. debuff(viperSting))

    -------------------------------------------------------
    -- Section 4: PvP
    -------------------------------------------------------
    L[12]:SetText(COLORS.header_pvp .. "--- PVP ---|r")
    L[13]:SetText(white .. "Class: " .. yellow .. targetClass .. white .. "  IsPlayer: " .. yn(targetIsPlayer) .. white .. "  IsMana: " .. yn(isManaUser))
    L[14]:SetText(white .. "Viper HP>=" .. fmt(viperHPThreshold) .. "%: " .. yn(viperHPok) .. white .. "  Priority: " .. yn(viperPriority) .. white .. "  Ready: " .. yn(viperReady))
    L[15]:SetText(white .. "DebuffOK(<=" .. fmt(gcd) .. "s): " .. yn(viperDebuffOK) .. white .. "  ==> VIPER: " .. yn(shouldViper))
    L[16]:SetText(white .. "RangeOK(<10/>25): " .. yn(concussiveRangeOK) .. white .. "  Ready: " .. yn(concussiveReady) .. white .. "  ==> CONCUSSIVE: " .. yn(shouldConcussive))
    L[17]:SetText(white .. "WC Thresholds  PvP:" .. yellow .. fmt(wcHPPvP) .. "%" .. white .. "  PvE:" .. yellow .. fmt(wcHPPvE) .. "%")
    L[18]:SetText(white .. "WC Priority: " .. yn(wcPriority) .. white .. "  Active:" .. yellow .. fmt(wcHPThreshold) .. "%" .. white .. "  Ready:" .. yn(wcReady) .. "  Imun:" .. yn(wcImun))

    -------------------------------------------------------
    -- Section 5: Pet State
    -------------------------------------------------------
    L[19]:SetText(COLORS.header_pet .. "--- PET STATE ---|r")
    L[20]:SetText(white .. "Exists: " .. yn(petExists) .. white .. "  HP: " .. yellow .. fmt(petHP) .. "%" .. white .. "  Mending: " .. (mendPetBuff > 0 and (green .. fmt(mendPetBuff) .. "s") or (red .. "NO")))
    L[21]:SetText(white .. "Dead(API): " .. yn(petIsDeadAPI) .. white .. "  Dead(Unit): " .. yn(petIsDead))
    L[22]:SetText(white .. "PetLib Active: " .. yn(petLibActive) .. white .. "  CanCall: " .. yn(petLibCanCall) .. white .. "  Attacking: " .. yn(petLibIsAttacking))
    L[23]:SetText(white .. "==> Alive: " .. yn(petAlive))
end

-- ============================================================================
-- TOGGLE / SHOW / HIDE
-- ============================================================================

function HunterDebug:Show()
    if not self.Frame then
        self:CreateFrame()
    end
    self.Frame:Show()
    self.IsVisible = true
end

function HunterDebug:Hide()
    if self.Frame then
        self.Frame:Hide()
    end
    self.IsVisible = false
end

-- ============================================================================
-- ONUPDATE (10 Hz)
-- ============================================================================

local updateFrame = CreateFrame("Frame")
updateFrame.elapsed = 0
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= 0.1 then
        self.elapsed = 0
        if HunterDebug.Frame and HunterDebug.Frame:IsShown() then
            HunterDebug:UpdateDisplay()
        end
    end
end)

-- ============================================================================
-- TOGGLE WATCHER (schema key: show_debug_panel)
-- ============================================================================

local lastToggleState = nil
local function CheckToggleState()
    local showPanel = NS.cached_settings.show_debug_panel or false

    if showPanel ~= lastToggleState then
        lastToggleState = showPanel
        if showPanel then
            HunterDebug:Show()
        else
            HunterDebug:Hide()
        end
    end
end

local watchFrame = CreateFrame("Frame")
watchFrame.elapsed = 0
watchFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= 0.5 then
        self.elapsed = 0
        CheckToggleState()
    end
end)

-- ============================================================================
-- NAMESPACE REGISTRATION
-- ============================================================================

NS.HunterDebug = HunterDebug

print("|cFF00FF00[Flux AIO Hunter]|r Debug panel loaded")
