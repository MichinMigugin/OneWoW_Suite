-- ============================================================================
-- Prey Hunt Bar — UI layer
-- ============================================================================
-- Builds and lays out the bar using OneWoW_GUI components only (CreateFrame,
-- CreateProgressBar, CreateSkinnedIcon, theme colors, font helpers). The module
-- table, data resolution, and events live in preybar.lua.
-- ============================================================================
local _, ns = ...
local PreyBarModule, L = ns.ModuleRegistry:Current()

local OneWoW_GUI = OneWoW_GUI
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
local BAR_FONT    = 10
local FONT_OUTLINE = "OUTLINE"

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
    NIGHTMARE = { nameKey = "PREYBAR_DIFFICULTY_NIGHTMARE", colorKey = "BTN_DANGER_BORDER_HOVER" },
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
    if self._diffText then OneWoW_GUI:SafeSetFont(self._diffText, fontPath, DIFF_FONT, FONT_OUTLINE) end
    if self._adviceText then OneWoW_GUI:SafeSetFont(self._adviceText, fontPath, ADVICE_FONT, FONT_OUTLINE) end
    if self._bar and self._bar._text then
        OneWoW_GUI:SafeSetFont(self._bar._text, fontPath, BAR_FONT, "")
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
    -- A left-press resets the drag flag; OnDragStart sets it only when an actual
    -- drag begins. OnMouseUp then distinguishes a stationary click (set waypoint)
    -- from the tail of a move (do nothing).
    f:SetScript("OnMouseDown", function() PreyBarModule._dragActive = false end)
    f:SetScript("OnDragStart", function(frame)
        if PreyBarModule.GetToggle("lock") then return end
        PreyBarModule._dragActive = true
        frame:StartMoving()
    end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local storage = PreyBarModule.GetPositionStorage()
        if storage then
            OneWoW_GUI:SaveWindowPosition(frame, storage)
        end
    end)
    f:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or PreyBarModule._dragActive then return end
        if not PreyBarModule.GetToggle("click_waypoint") then return end
        if not PreyBarModule:IsHuntReady() then return end
        PreyBarModule:SetPreyWaypoint()
    end)
    f:SetScript("OnEnter", function(frame)
        local showDrag = not PreyBarModule.GetToggle("lock")
        local showClick = PreyBarModule.GetToggle("click_waypoint") and PreyBarModule:IsHuntReady()
        if not showDrag and not showClick then return end
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        if showDrag then
            GameTooltip:SetText(L["PREYBAR_DRAG_HINT"], 1, 1, 1)
            if showClick then
                GameTooltip:AddLine(L["PREYBAR_CLICK_WAYPOINT_HINT"], 1, 1, 1)
            end
        else
            GameTooltip:SetText(L["PREYBAR_CLICK_WAYPOINT_HINT"], 1, 1, 1)
        end
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
    self:ApplyOpacity()
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
    local barTextOutline = (stateIndex >= 3) and FONT_OUTLINE or ""
    OneWoW_GUI:SafeSetFont(bar._text, OneWoW_GUI:GetFont(), BAR_FONT, barTextOutline)

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
        for _, affixKey in ipairs(affixKeys) do
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
        adviceText, adviceColorKey = L["PREYBAR_ADVICE_AMBUSHED"], "BTN_DANGER_BORDER_HOVER"
    elseif self:IsAmbushed() then
        adviceText, adviceColorKey = L["PREYBAR_ADVICE_AMBUSHED"], "BTN_DANGER_BORDER_HOVER"
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
-- Real hunt always wins. Bar shows only when the prey widget reports Shown
-- (matching Blizzard's icon visibility). A sample bar shows only while the QoL
-- settings panel for this module is open (preview).
function PreyBarModule:Refresh()
    if not self._frame then return end

    local info = self:GetWidgetInfo()
    local huntActive = info and info.shownState == Enum.WidgetShownState.Shown

    if self:WantHideBlizzard() then
        self:SuppressBlizzWidget()
    else
        self:UnsuppressBlizzWidget()
    end

    if huntActive then
        self:Populate(info, false)
        self._frame:Show()
        self:ApplyOpacity()
    elseif self._previewActive then
        self:Populate(nil, true)
        self._frame:Show()
        self:ApplyOpacity()
    else
        self._frame:Hide()
    end
end

-- Session-only collapse for the Sample Bar card (cleared on /reload).
local collapsedSampleCards = {}

-- ---- Settings-panel detail (drives the sample bar) ----
--- Rendered inside the QoL feature detail panel. Sample hint + opacity live in a
--- card so wrap width is available at build time (loose TOPLEFT/TOPRIGHT on the
--- belowHost truncated and then exploded on detail OnSizeChanged).
---@param parent table detail scroll child or Features belowHost
---@param yOffset number
---@return number yOffset
function PreyBarModule:CreateCustomDetail(parent, yOffset, _, registerRefresh)
    local cardsHost = CreateFrame("Frame", nil, parent)
    cardsHost:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    cardsHost:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)

    local stack = OneWoW_GUI:CreateCardStack(cardsHost, {
        getCollapsed = function(key) return collapsedSampleCards[key] end,
        setCollapsed = function(key, collapsed) collapsedSampleCards[key] = collapsed end,
    })

    local function applyHostHeight()
        local h = math.max(1, cardsHost:GetHeight())
        if parent.UpdateDetailHeight then
            -- Features belowHost under Module Toggles cards.
            parent:SetHeight(h)
            parent.UpdateDetailHeight()
        else
            parent:SetHeight(math.abs(yOffset) + h + 20)
            if parent.updateThumb then
                parent.updateThumb()
            end
        end
    end
    stack.OnRelayout = applyHostHeight

    stack:AddCard("preybar:sample", L["PREYBAR_SAMPLE_BAR_HEADER"], function(content, contentWidth)
        local gap = 10
        local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        hint:SetJustifyH("LEFT")
        hint:SetWordWrap(true)
        hint:SetSpacing(3)
        local w = tonumber(contentWidth) or 0
        if w < 1 then
            w = content:GetWidth() or 0
        end
        if w >= 1 then
            hint:SetWidth(w)
        else
            hint:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
        end
        hint:SetText(L["PREYBAR_SETTINGS_HINT"])
        hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local opacityPct = math.floor(self:GetOpacity() * 100 + 0.5)
        local opacityLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        opacityLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -gap)
        opacityLabel:SetText(string.format(L["PREYBAR_OPACITY_FMT"], opacityPct))
        opacityLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local opacitySlider = OneWoW_GUI:CreateSlider(content, {
            width      = 220,
            minVal     = 10,
            maxVal     = 100,
            step       = 5,
            currentVal = opacityPct,
            fmt        = "%d%%",
            onChange   = function(val)
                self:SetOpacity(val / 100)
                opacityLabel:SetText(string.format(L["PREYBAR_OPACITY_FMT"], val))
            end,
        })
        opacitySlider:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 0, -4)

        local hintH = hint:GetStringHeight() or 14
        local labelH = opacityLabel:GetStringHeight() or 12
        local sliderH = opacitySlider:GetHeight() or 36
        return math.max(1, hintH + gap + labelH + 4 + sliderH + 8)
    end)

    stack:Finish()
    applyHostHeight()

    if registerRefresh then
        registerRefresh(applyHostHeight)
    end

    self:StartPreview(parent)

    return yOffset - cardsHost:GetHeight()
end
