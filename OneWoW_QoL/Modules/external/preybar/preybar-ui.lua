-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/preybar/preybar-ui.lua
-- Created by MichinMuggin (Ricky)
-- ============================================================================
-- Prey Hunt Bar — UI layer
-- ============================================================================
-- Builds and lays out the bar using OneWoW_GUI components only (CreateFrame,
-- CreateProgressBar, CreateSkinnedIcon, theme colors, font helpers). The module
-- table, data resolution, and events live in preybar.lua.
-- ============================================================================
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local PreyBarModule = ns.PreyBarModule
local C = OneWoW_GUI.Constants
local format = string.format

-- ---- Layout constants ----
local BAR_WIDTH   = 220
local BAR_HEIGHT  = 16
local PADDING     = 8
local LINE_GAP    = 3
local AFFIX_SIZE  = 22
local AFFIX_GAP   = 4
local BOSS_FONT   = 13
local DIFF_FONT   = 11
local ADVICE_FONT = 12

-- ---- Display data ----
-- Progress states map the widget's Enum.PreyHuntProgressState (0..3) onto a fill
-- percentage, a localized label, and a theme color key (cold > warm > hot > ready).
local PROGRESS_STATES = {
    [0] = { pct = 0,   nameKey = "PREYBAR_STATE_COLD",  colorKey = "ACCENT_MUTED" },
    [1] = { pct = 34,  nameKey = "PREYBAR_STATE_WARM",  colorKey = "TEXT_WARNING" },
    [2] = { pct = 67,  nameKey = "PREYBAR_STATE_HOT",   colorKey = "BTN_DANGER_NORMAL" },
    [3] = { pct = 100, nameKey = "PREYBAR_STATE_READY", colorKey = "TEXT_FEATURES_ENABLED" },
}

local DIFFICULTY_INFO = {
    NORMAL    = { nameKey = "PREYBAR_DIFFICULTY_NORMAL",    colorKey = "TEXT_SECONDARY" },
    HARD      = { nameKey = "PREYBAR_DIFFICULTY_HARD",      colorKey = "TEXT_WARNING" },
    NIGHTMARE = { nameKey = "PREYBAR_DIFFICULTY_NIGHTMARE", colorKey = "BTN_DANGER_NORMAL" },
}

-- Affix data is factual game data: icon fileIDs plus the affix spell ID per
-- difficulty (used for the real in-game spell tooltip and for reading live
-- stack counts off the player's aura). hasStacks marks affixes that ramp up.
local AFFIX_DEFS = {
    AMBUSH       = { labelKey = "PREYBAR_AFFIX_AMBUSH",       icon = 132292,  spellByDifficulty = { NORMAL = 1271757, NIGHTMARE = 1271757 } },
    TORMENT      = { labelKey = "PREYBAR_AFFIX_TORMENT",      icon = 1035037, hasStacks = true, spellByDifficulty = { HARD = 1245570, NIGHTMARE = 1245522 } },
    SEEPING_GORE = { labelKey = "PREYBAR_AFFIX_SEEPING_GORE", icon = 1029738, spellByDifficulty = { HARD = 1282499, NIGHTMARE = 1282499 } },
    ECHO         = { labelKey = "PREYBAR_AFFIX_ECHO",         icon = 3565723, spellByDifficulty = { NIGHTMARE = 1245792 } },
    BLOODY       = { labelKey = "PREYBAR_AFFIX_BLOODY",       icon = 1029718, spellByDifficulty = { NIGHTMARE = 1245779 } },
}

-- Affix set is determined solely by difficulty (every hunt of a given difficulty
-- shares the same affixes), so no per-boss lookup is required.
local AFFIX_BY_DIFFICULTY = {
    NORMAL    = { "AMBUSH" },
    HARD      = { "TORMENT", "SEEPING_GORE" },
    NIGHTMARE = { "AMBUSH", "TORMENT", "SEEPING_GORE", "ECHO", "BLOODY" },
}

-- ---- Theme & fonts ----
function PreyBarModule:ApplyThemeColors()
    local f = self._frame
    if not f then return end
    f:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    f:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
    if self._bossText then
        self._bossText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
end

function PreyBarModule:ApplyFonts()
    local fontPath = OneWoW_GUI:GetFont()
    if self._bossText then OneWoW_GUI:SafeSetFont(self._bossText, fontPath, BOSS_FONT, "") end
    if self._diffText then OneWoW_GUI:SafeSetFont(self._diffText, fontPath, DIFF_FONT, "") end
    if self._adviceText then OneWoW_GUI:SafeSetFont(self._adviceText, fontPath, ADVICE_FONT, "OUTLINE") end
    if self._bar and self._bar._text then
        OneWoW_GUI:SafeSetFont(self._bar._text, fontPath, 10, "")
    end
end

-- ---- Frame construction ----
function PreyBarModule:CreateFrame()
    if self._frame then return end

    local f = OneWoW_GUI:CreateFrame(UIParent, {
        name     = "OneWoW_QoL_PreyBarFrame",
        width    = BAR_WIDTH + PADDING * 2,
        height   = BAR_HEIGHT + PADDING * 2,
        backdrop = C.BACKDROP_INNER_NO_INSETS,
    })
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(frame)
        if PreyBarModule.GetToggle("lock") then return end
        frame:StartMoving()
    end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local storage = PreyBarModule.GetPositionStorage()
        if storage then
            OneWoW_GUI:SaveWindowPosition(frame, storage)
        end
    end)
    f:SetScript("OnEnter", function(frame)
        if PreyBarModule.GetToggle("lock") then return end
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:SetText(ns.L["PREYBAR_DRAG_HINT"], 1, 1, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local storage = self:GetPositionStorage()
    if not storage or not OneWoW_GUI:RestoreWindowPosition(f, storage) then
        f:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end

    local bossText = f:CreateFontString(nil, "OVERLAY")
    bossText:SetJustifyH("CENTER")
    bossText:SetWordWrap(false)
    bossText:SetWidth(BAR_WIDTH)
    self._bossText = bossText

    local diffText = f:CreateFontString(nil, "OVERLAY")
    diffText:SetJustifyH("CENTER")
    diffText:SetWordWrap(false)
    diffText:SetWidth(BAR_WIDTH)
    self._diffText = diffText

    local bar = OneWoW_GUI:CreateProgressBar(f, { height = BAR_HEIGHT, min = 0, max = 100, value = 0 })
    bar:SetWidth(BAR_WIDTH)
    self._bar = bar

    local adviceText = f:CreateFontString(nil, "OVERLAY")
    adviceText:SetJustifyH("CENTER")
    adviceText:SetWordWrap(false)
    adviceText:SetWidth(BAR_WIDTH)
    self._adviceText = adviceText

    self._affixIcons = {}
    self._frame = f

    self:ApplyFonts()
    self:ApplyThemeColors()
end

-- ---- Affix icon pool ----
---@param index number
---@return table iconFrame
function PreyBarModule:EnsureAffixIcon(index)
    if self._affixIcons[index] then return self._affixIcons[index] end

    local icon = OneWoW_GUI:CreateSkinnedIcon(self._frame, {
        size   = AFFIX_SIZE,
        preset = "clean",
    })

    -- Numeric stack badge (e.g. Torment x3). ARIALN is the standard count font;
    -- this is a numeric utility overlay, not user-facing copy.
    local stackText = icon:CreateFontString(nil, "OVERLAY")
    stackText:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
    stackText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    stackText:SetTextColor(1, 1, 1, 1)
    stackText:Hide()
    icon._stackText = stackText

    icon:EnableMouse(true)
    icon:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        if myself._affixSpellID then
            GameTooltip:SetSpellByID(myself._affixSpellID)
        elseif myself._affixLabel then
            GameTooltip:SetText(myself._affixLabel, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self._affixIcons[index] = icon
    return icon
end

-- ---- Populate + layout ----
--- Fill the bar from a widget info table (real hunt) or sample data (demo).
---@param info table|nil prey widget visualization info
---@param isDemo boolean
function PreyBarModule:Populate(info, isDemo)
    local L = ns.L

    local stateIndex = isDemo and 1 or (info and info.progressState) or 0
    if not PROGRESS_STATES[stateIndex] then stateIndex = 0 end
    local stateData = PROGRESS_STATES[stateIndex]

    local difficultyKey, bossName
    if isDemo then
        difficultyKey = "NIGHTMARE"
        bossName = L["PREYBAR_DEMO_BOSS"]
    else
        difficultyKey, bossName = self:GetActiveHunt()
    end

    local bar = self._bar
    bar:SetValue(stateData.pct)
    bar:SetStatusBarColor(OneWoW_GUI:GetThemeColor(stateData.colorKey))
    bar._text:SetText(format(L["PREYBAR_STATE_LABEL"], L[stateData.nameKey], stateData.pct))

    local showBoss = self.GetToggle("show_boss") and bossName and bossName ~= ""
    if showBoss then
        self._bossText:SetText(bossName)
        self._bossText:Show()
    else
        self._bossText:Hide()
    end

    local diffInfo = difficultyKey and DIFFICULTY_INFO[difficultyKey]
    local showDiff = self.GetToggle("show_difficulty") and diffInfo
    if showDiff then
        self._diffText:SetText(L[diffInfo.nameKey])
        self._diffText:SetTextColor(OneWoW_GUI:GetThemeColor(diffInfo.colorKey))
        self._diffText:Show()
    else
        self._diffText:Hide()
    end

    local affixKeys = difficultyKey and AFFIX_BY_DIFFICULTY[difficultyKey]
    local affixCount = 0
    if self.GetToggle("show_affixes") and affixKeys then
        for i, affixKey in ipairs(affixKeys) do
            local def = AFFIX_DEFS[affixKey]
            if def then
                affixCount = affixCount + 1
                local icon = self:EnsureAffixIcon(affixCount)
                local spellID = def.spellByDifficulty and def.spellByDifficulty[difficultyKey]
                icon._skinnedIcon:SetTexture(def.icon)
                icon._affixLabel = L[def.labelKey]
                icon._affixSpellID = spellID

                local stacks
                if def.hasStacks then
                    if isDemo then
                        stacks = 3
                    elseif spellID then
                        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
                        stacks = aura and aura.applications
                    end
                end
                if stacks and stacks > 1 then
                    icon._stackText:SetText(stacks)
                    icon._stackText:Show()
                else
                    icon._stackText:Hide()
                end

                icon:Show()
            end
        end
    end
    for i = affixCount + 1, #self._affixIcons do
        self._affixIcons[i]:Hide()
    end

    -- Advice line — highest-urgency actionable hint for the current hunt state.
    local adviceText, adviceColorKey
    if isDemo then
        adviceText, adviceColorKey = L["PREYBAR_ADVICE_AMBUSHED"], "BTN_DANGER_NORMAL"
    elseif self:IsAmbushed() then
        adviceText, adviceColorKey = L["PREYBAR_ADVICE_AMBUSHED"], "BTN_DANGER_NORMAL"
    elseif self:IsKillSomethingActive() then
        adviceText, adviceColorKey = L["PREYBAR_ADVICE_KILL"], "TEXT_WARNING"
    elseif stateIndex >= 3 then
        adviceText, adviceColorKey = L["PREYBAR_ADVICE_READY"], "TEXT_FEATURES_ENABLED"
    end

    if adviceText then
        self._adviceText:SetText(adviceText)
        self._adviceText:SetTextColor(OneWoW_GUI:GetThemeColor(adviceColorKey))
        self._adviceText:Show()
    else
        self._adviceText:Hide()
    end

    self:LayoutBar(affixCount)
end

--- Reposition visible elements top-to-bottom and resize the frame to fit.
---@param affixCount number
function PreyBarModule:LayoutBar(affixCount)
    local f = self._frame
    local y = -PADDING

    if self._bossText:IsShown() then
        self._bossText:ClearAllPoints()
        self._bossText:SetPoint("TOP", f, "TOP", 0, y)
        y = y - (self._bossText:GetStringHeight() or BOSS_FONT) - LINE_GAP
    end

    if self._diffText:IsShown() then
        self._diffText:ClearAllPoints()
        self._diffText:SetPoint("TOP", f, "TOP", 0, y)
        y = y - (self._diffText:GetStringHeight() or DIFF_FONT) - LINE_GAP
    end

    self._bar:ClearAllPoints()
    self._bar:SetPoint("TOP", f, "TOP", 0, y)
    y = y - BAR_HEIGHT

    if affixCount > 0 then
        y = y - LINE_GAP
        local rowWidth = affixCount * AFFIX_SIZE + (affixCount - 1) * AFFIX_GAP
        local startX = -rowWidth / 2
        for i = 1, affixCount do
            local icon = self._affixIcons[i]
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", f, "TOP", startX + (i - 1) * (AFFIX_SIZE + AFFIX_GAP), y)
        end
        y = y - AFFIX_SIZE
    end

    if self._adviceText:IsShown() then
        y = y - LINE_GAP
        self._adviceText:ClearAllPoints()
        self._adviceText:SetPoint("TOP", f, "TOP", 0, y)
        y = y - (self._adviceText:GetStringHeight() or ADVICE_FONT)
    end

    y = y - PADDING
    f:SetHeight(math.max(-y, BAR_HEIGHT + PADDING * 2))
end

-- ---- Refresh (visibility decision) ----
-- Real hunt always wins. A sample bar shows only while the QoL settings panel
-- for this module is open (preview), so the bar never appears in town with no
-- prey data. Otherwise the bar is hidden — matching Blizzard's own behavior.
function PreyBarModule:Refresh()
    if not self._frame then return end

    local info = self:GetWidgetInfo()
    -- The prey widget frame only exists in the power-bar container during an
    -- active hunt, so a non-nil info that is not explicitly Hidden means "show".
    local huntActive = info and info.shownState ~= Enum.WidgetShownState.Hidden

    if self:WantHideBlizzard() then
        self:SuppressBlizzWidget()
    else
        self:UnsuppressBlizzWidget()
    end

    if huntActive then
        self:Populate(info, false)
        self._frame:Show()
    elseif self._previewActive then
        self:Populate(nil, true)
        self._frame:Show()
    else
        self._frame:Hide()
    end
end

-- ---- Settings-panel detail (drives the sample bar) ----
--- Rendered inside the QoL feature detail panel. Shows a positioning hint and
--- starts the sample-bar preview; preview ends when the panel closes.
---@param parent table detail scroll child
---@param yOffset number
---@return number yOffset
function PreyBarModule:CreateCustomDetail(parent, yOffset, _isEnabled, _registerRefresh, _rightStatusBar)
    local L = ns.L

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    hint:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetSpacing(3)
    hint:SetText(L["PREYBAR_SETTINGS_HINT"])
    hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    yOffset = yOffset - hint:GetStringHeight() - 10

    self:StartPreview(parent)

    return yOffset
end
