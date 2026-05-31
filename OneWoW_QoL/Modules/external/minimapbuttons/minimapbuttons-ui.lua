local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI and OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local function GetSettings()
    return ns.MinimapButtonsModule.GetSettings()
end

-- ─── Detected minimap icons (per-button Mini / Map / Hide) ─────────────────

-- Build one row for a single detected (or previously-detected) minimap icon:
--
--   [X]  Outfitter             Enabled : Mini    [Mini][Map][Hide]
--
-- The X drops the entry from the DB (useful for stale addons that were
-- uninstalled). The three toggleable buttons set the user's preference; the
-- module's ApplyButtonPref moves the button between the collector panel
-- (Mini), the minimap (Map), or an offscreen hidden frame (Hide).
local ROW_PADDING_X   = 12
local ICON_ROW_HEIGHT = 26
local ICON_ROW_GAP    = 4
-- The "Collector" label is the widest of the three, so minWidth covers it
-- (CreateFitTextButton grows further to fit any localized text).
local TOGGLE_BTN_W    = 70
local TOGGLE_BTN_H    = 20

local function LabelForPref(L, pref)
    if pref == "mini" then return L["MMBTNS_ICONS_MINI_STATE"] or "Collector" end
    if pref == "map"  then return L["MMBTNS_ICONS_MAP_STATE"]  or "Map"       end
    if pref == "hide" then return L["MMBTNS_ICONS_HIDE_STATE"] or "Hide"      end
    return tostring(pref)
end

local function BuildIconRow(parent, info, yOffset, refreshFn)
    local L = ns.L
    local capturedName = info.name

    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(ICON_ROW_HEIGHT)
    row:SetPoint("TOPLEFT",  parent, "TOPLEFT",   ROW_PADDING_X, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -ROW_PADDING_X, yOffset)
    row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    -- Removal is only allowed for stale entries (addon currently disabled /
    -- unloaded). Enabled rows keep the X visible for alignment but greyed out
    -- and non-clickable, so the user can't accidentally drop a row they're
    -- actively using.
    local removeBtn = CreateFrame("Button", nil, row)
    removeBtn:SetSize(14, 14)
    removeBtn:SetPoint("LEFT", row, "LEFT", 6, 0)
    removeBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    if info.seen then
        removeBtn:EnableMouse(false)
        local tex = removeBtn:GetNormalTexture()
        if tex then tex:SetVertexColor(0.4, 0.4, 0.4, 0.6) end
        removeBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L["MMBTNS_ICONS_REMOVE_LOCKED_TT"]
                or "This addon is currently loaded. Hide its icon if you don't want it collected; you can only remove the entry once the addon is disabled.",
                1, 1, 1, true)
            GameTooltip:Show()
        end)
        removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
        removeBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["MMBTNS_ICONS_REMOVE_TT"] or "Remove this entry from the list")
            GameTooltip:Show()
        end)
        removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        removeBtn:SetScript("OnClick", function()
            ns.MinimapButtonsModule.RemoveKnownButton(capturedName)
            if refreshFn then refreshFn() end
        end)
    end

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", removeBtn, "RIGHT", 8, 0)
    label:SetJustifyH("LEFT")
    label:SetText(info.displayName or capturedName)
    label:SetTextColor(OneWoW_GUI:GetThemeColor(info.seen and "TEXT_PRIMARY" or "TEXT_MUTED"))

    -- Right-to-left: Hide, Map, Mini, then the status text.
    local hideBtn = OneWoW_GUI:CreateFitTextButton(row, {
        text       = L["MMBTNS_ICONS_HIDE"] or "Hide",
        height     = TOGGLE_BTN_H,
        minWidth   = TOGGLE_BTN_W,
        toggleable = true,
    })
    hideBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)

    local mapBtn = OneWoW_GUI:CreateFitTextButton(row, {
        text       = L["MMBTNS_ICONS_MAP"] or "Map",
        height     = TOGGLE_BTN_H,
        minWidth   = TOGGLE_BTN_W,
        toggleable = true,
    })
    mapBtn:SetPoint("RIGHT", hideBtn, "LEFT", -3, 0)

    local miniBtn = OneWoW_GUI:CreateFitTextButton(row, {
        text       = L["MMBTNS_ICONS_MINI"] or "Collector",
        height     = TOGGLE_BTN_H,
        minWidth   = TOGGLE_BTN_W,
        toggleable = true,
    })
    miniBtn:SetPoint("RIGHT", mapBtn, "LEFT", -3, 0)

    local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("RIGHT", miniBtn, "LEFT", -10, 0)
    statusText:SetJustifyH("RIGHT")
    -- Stop the label from running into the status text on narrow detail panels.
    label:SetPoint("RIGHT", statusText, "LEFT", -8, 0)

    local function refresh(pref)
        miniBtn:SetActive(pref == "mini")
        mapBtn:SetActive(pref == "map")
        hideBtn:SetActive(pref == "hide")

        local seenLbl = info.seen
            and (L["MMBTNS_ICONS_ENABLED"]  or "Enabled")
            or  (L["MMBTNS_ICONS_DISABLED"] or "Disabled")
        statusText:SetText(seenLbl .. " : " .. LabelForPref(L, pref))

        local color = info.seen and "TEXT_FEATURES_ENABLED" or "TEXT_FEATURES_DISABLED"
        statusText:SetTextColor(OneWoW_GUI:GetThemeColor(color))
    end

    miniBtn:SetScript("OnClick", function()
        ns.MinimapButtonsModule:ApplyButtonPref(capturedName, "mini")
        refresh("mini")
    end)
    mapBtn:SetScript("OnClick", function()
        ns.MinimapButtonsModule:ApplyButtonPref(capturedName, "map")
        refresh("map")
    end)
    hideBtn:SetScript("OnClick", function()
        ns.MinimapButtonsModule:ApplyButtonPref(capturedName, "hide")
        refresh("hide")
    end)

    refresh(info.pref or "mini")

    return yOffset - ICON_ROW_HEIGHT - ICON_ROW_GAP
end

local function BuildMinimapIconsSection(parent, yOffset, refreshFn)
    local L = ns.L

    local sectionLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sectionLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_PADDING_X, yOffset)
    sectionLabel:SetText(L["MMBTNS_ICONS_HEADER"] or "Detected Minimap Icons")
    sectionLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - sectionLabel:GetStringHeight() - 4

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT",  parent, "TOPLEFT",   ROW_PADDING_X, yOffset)
    desc:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -ROW_PADDING_X, yOffset)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetSpacing(2)
    desc:SetText(L["MMBTNS_ICONS_DESC"]
        or "Each detected minimap icon is listed here. Pick where it should live: Collector (inside the OneWoW panel), Map (back on the minimap), or Hide (out of sight entirely). The X removes a stale entry for an addon you've uninstalled.")
    desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    -- Re-scan every time the settings panel is rebuilt so the Enabled /
    -- Disabled status reflects the current addon state, not whatever was
    -- cached at module load time.
    ns.MinimapButtonsModule:DiscoverButtons()

    local buttons = ns.MinimapButtonsModule:GetKnownButtons()

    -- IMPORTANT: never anchor the next element with yOffset arithmetic off a
    -- wrapped FontString — GetStringHeight() can return the unwrapped (single
    -- line) value if the parent's width hasn't propagated at build time,
    -- which makes the rows render on top of the description. Anchor the rows
    -- container to desc:BOTTOMLEFT/RIGHT instead so layout follows whatever
    -- the engine actually paints.
    local rowsContainer = CreateFrame("Frame", nil, parent)
    rowsContainer:SetPoint("TOPLEFT",  desc, "BOTTOMLEFT",  0, -10)
    rowsContainer:SetPoint("TOPRIGHT", desc, "BOTTOMRIGHT", 0, -10)

    if #buttons == 0 then
        local empty = rowsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        empty:SetPoint("TOPLEFT",  rowsContainer, "TOPLEFT",  0, 0)
        empty:SetPoint("TOPRIGHT", rowsContainer, "TOPRIGHT", 0, 0)
        empty:SetJustifyH("CENTER")
        empty:SetWordWrap(true)
        empty:SetText(L["MMBTNS_ICONS_EMPTY"]
            or "No minimap icons detected yet. Open the collector to trigger a scan, then re-open Settings.")
        empty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        rowsContainer:SetHeight((empty:GetStringHeight() or 14) + 8)
    else
        local localY = 0
        for _, info in ipairs(buttons) do
            localY = BuildIconRow(rowsContainer, info, localY, refreshFn)
        end
        rowsContainer:SetHeight(math.abs(localY) + 4)
    end

    -- For the outer yOffset accounting we still need *some* estimate of the
    -- description's rendered height. GetStringHeight may under-report on
    -- first build; pad generously so the scroll area is never shorter than
    -- the content. The rows themselves are positioned correctly regardless
    -- because rowsContainer is anchored relative to desc, not via this math.
    local descH = desc:GetStringHeight() or 14
    if descH < 28 then descH = 28 end
    return yOffset - descH - 10 - rowsContainer:GetHeight() - 4
end

-- ─── Helpers ────────────────────────────────────────────────────────────────

local ROW_HEIGHT   = 28
local SLIDER_HEIGHT = 42

local function AddLabel(parent, cy, text, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, cy)
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor(color or "TEXT_SECONDARY"))
    return fs, cy - fs:GetStringHeight() - 4
end

local function AddDescription(parent, cy, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 36, cy)
    fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, cy)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetSpacing(2)
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    return fs, cy - fs:GetStringHeight() - 8
end

-- ─── Main settings content builder ─────────────────────────────────────────

local function BuildContent(container, isEnabled)
    local L = ns.L
    local s = GetSettings()
    local cy = 0

    -- ═══════════════════════════════════════════════════════════════════════
    -- Behavior Section
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMBTNS_BEHAVIOR_HEADER"] or "Behavior", yOffset = cy })

    -- Close mode label
    local _, newCy = AddLabel(container, cy, L["MMBTNS_CLOSE_MODE"] or "Close Behavior")
    cy = newCy

    -- Close mode radios (manual mutual exclusion)
    local radioStay, radioAuto

    radioStay = OneWoW_GUI:CreateCheckbox(container, {
        label  = L["MMBTNS_STAY_OPEN"] or "Stay Open",
        checked = s.closeMode == "stayopen",
        onClick = function(self)
            s.closeMode = "stayopen"
            self:SetChecked(true)
            if radioAuto then radioAuto:SetChecked(false) end
            ns.MinimapButtonsModule:CancelAutoCloseTimer()
            ns.MinimapButtonsModule._refreshCustomDetail()
        end,
    })
    radioStay:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)

    radioAuto = OneWoW_GUI:CreateCheckbox(container, {
        label  = L["MMBTNS_AUTO_CLOSE"] or "Auto Close",
        checked = s.closeMode == "autoclose",
        onClick = function(self)
            s.closeMode = "autoclose"
            self:SetChecked(true)
            if radioStay then radioStay:SetChecked(false) end
            ns.MinimapButtonsModule._refreshCustomDetail()
        end,
    })
    radioAuto:SetPoint("TOPLEFT", container, "TOPLEFT", 160, cy)
    cy = cy - ROW_HEIGHT

    -- Auto-close delay slider (only when autoclose is active)
    if s.closeMode == "autoclose" then
        local delayLabel
        delayLabel, cy = AddLabel(container, cy,
            string.format("%s: %d", L["MMBTNS_AUTO_CLOSE_DELAY"] or "Delay", s.autoCloseDelay or 3))

        local delaySlider = OneWoW_GUI:CreateSlider(container, {
            minVal     = 1,
            maxVal     = 10,
            step       = 1,
            currentVal = s.autoCloseDelay or 3,
            width      = 260,
            fmt        = "%d",
            onChange    = function(val)
                s.autoCloseDelay = val
                delayLabel:SetText(string.format("%s: %d", L["MMBTNS_AUTO_CLOSE_DELAY"] or "Delay", val))
            end,
        })
        delaySlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
        cy = cy - SLIDER_HEIGHT
    end

    -- Enhanced OneWoW Menu
    local enhCB = OneWoW_GUI:CreateCheckbox(container, {
        label  = L["MMBTNS_ENHANCED_MENU"] or "Enhanced OneWoW Menu",
        checked = s.enhancedMenu,
        onClick = function(self)
            s.enhancedMenu = self:GetChecked()
            ns.MinimapButtonsModule:Refresh()
        end,
    })
    enhCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    cy = cy - ROW_HEIGHT

    local _, descCy = AddDescription(container, cy, L["MMBTNS_ENHANCED_MENU_DESC"] or "")
    cy = descCy

    -- Lock position
    local lockCB = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMBTNS_LOCK_POSITION"] or "Lock Position",
        checked = s.locked,
        onClick = function(self)
            s.locked = self:GetChecked()
        end,
    })
    lockCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    cy = cy - ROW_HEIGHT

    -- Hide collected from minimap
    local hideCB = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMBTNS_HIDE_COLLECTED"] or "Hide Collected from Minimap",
        checked = s.hideCollected,
        onClick = function(self)
            s.hideCollected = self:GetChecked()
            ns.MinimapButtonsModule:Refresh()
        end,
    })
    hideCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    cy = cy - ROW_HEIGHT

    -- Show tooltips
    local tipCB = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMBTNS_SHOW_TOOLTIPS"] or "Show Tooltips",
        checked = s.showTooltips,
        onClick = function(self)
            s.showTooltips = self:GetChecked()
        end,
    })
    tipCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    cy = cy - ROW_HEIGHT

    -- Grow direction (4-way radio: Down / Up / Left / Right)
    local growLabel
    growLabel, cy = AddLabel(container, cy, L["MMBTNS_GROW_DIRECTION"] or "Grow Direction")

    local growDown, growUp, growLeft, growRight

    local function SetGrowDir(dir, self)
        s.growDirection = dir
        if growDown  then growDown:SetChecked(dir  == "down")  end
        if growUp    then growUp:SetChecked(dir    == "up")    end
        if growLeft  then growLeft:SetChecked(dir   == "left")  end
        if growRight then growRight:SetChecked(dir  == "right") end
    end

    growDown = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMBTNS_GROW_DOWN"] or "Down",
        checked = s.growDirection == "down",
        onClick = function(self) SetGrowDir("down", self) end,
    })
    growDown:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)

    growUp = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMBTNS_GROW_UP"] or "Up",
        checked = s.growDirection == "up",
        onClick = function(self) SetGrowDir("up", self) end,
    })
    growUp:SetPoint("TOPLEFT", container, "TOPLEFT", 110, cy)

    growLeft = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMBTNS_GROW_LEFT"] or "Left",
        checked = s.growDirection == "left",
        onClick = function(self) SetGrowDir("left", self) end,
    })
    growLeft:SetPoint("TOPLEFT", container, "TOPLEFT", 190, cy)

    growRight = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMBTNS_GROW_RIGHT"] or "Right",
        checked = s.growDirection == "right",
        onClick = function(self) SetGrowDir("right", self) end,
    })
    growRight:SetPoint("TOPLEFT", container, "TOPLEFT", 280, cy)
    cy = cy - ROW_HEIGHT

    -- ═══════════════════════════════════════════════════════════════════════
    -- Layout Section
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMBTNS_LAYOUT_HEADER"] or "Layout", yOffset = cy })

    -- Max Columns
    local colsLabel
    colsLabel, cy = AddLabel(container, cy,
        string.format("%s: %d", L["MMBTNS_MAX_COLUMNS"] or "Max Columns", s.maxColumns))

    local colsSlider = OneWoW_GUI:CreateSlider(container, {
        minVal     = 1,
        maxVal     = 20,
        step       = 1,
        currentVal = s.maxColumns,
        width      = 260,
        fmt        = "%d",
        onChange    = function(val)
            s.maxColumns = val
            colsLabel:SetText(string.format("%s: %d", L["MMBTNS_MAX_COLUMNS"] or "Max Columns", val))
            ns.MinimapButtonsModule:LayoutContainer()
        end,
    })
    colsSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    cy = cy - SLIDER_HEIGHT

    -- Max Rows
    local rowsDisplay = s.maxRows == 0 and "∞" or tostring(s.maxRows)
    local rowsLabel
    rowsLabel, cy = AddLabel(container, cy,
        string.format("%s: %s", L["MMBTNS_MAX_ROWS"] or "Max Rows", rowsDisplay))

    local rowsSlider = OneWoW_GUI:CreateSlider(container, {
        minVal     = 0,
        maxVal     = 10,
        step       = 1,
        currentVal = s.maxRows,
        width      = 260,
        fmt        = "%d",
        onChange    = function(val)
            s.maxRows = val
            local display = val == 0 and "∞" or tostring(val)
            rowsLabel:SetText(string.format("%s: %s", L["MMBTNS_MAX_ROWS"] or "Max Rows", display))
            ns.MinimapButtonsModule:LayoutContainer()
        end,
    })
    rowsSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    cy = cy - SLIDER_HEIGHT

    local rowsDesc = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rowsDesc:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    rowsDesc:SetText(L["MMBTNS_MAX_ROWS_DESC"] or "0 = unlimited.")
    rowsDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    cy = cy - rowsDesc:GetStringHeight() - 10

    -- Button Size
    local sizeLabel
    sizeLabel, cy = AddLabel(container, cy,
        string.format("%s: %d", L["MMBTNS_BUTTON_SIZE"] or "Button Size", s.buttonSize))

    local sizeSlider = OneWoW_GUI:CreateSlider(container, {
        minVal     = 24,
        maxVal     = 48,
        step       = 2,
        currentVal = s.buttonSize,
        width      = 260,
        fmt        = "%d",
        onChange    = function(val)
            s.buttonSize = val
            sizeLabel:SetText(string.format("%s: %d", L["MMBTNS_BUTTON_SIZE"] or "Button Size", val))
            ns.MinimapButtonsModule:LayoutContainer()
        end,
    })
    sizeSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    cy = cy - SLIDER_HEIGHT

    -- Collected icon scale (MinimapButtonButton-style: stored as tenths, e.g. 10 = 1.0 scale)
    local scaleLabel
    scaleLabel, cy = AddLabel(container, cy,
        string.format("%s: %.1f", L["MMBTNS_BUTTON_SCALE"] or "Collected icon scale", (s.buttonScale or 10) / 10))

    local scaleSlider = OneWoW_GUI:CreateSlider(container, {
        minVal     = 1,
        maxVal     = 50,
        step       = 1,
        currentVal = s.buttonScale or 10,
        width      = 260,
        fmt        = "%d",
        onChange    = function(val)
            s.buttonScale = val
            scaleLabel:SetText(string.format("%s: %.1f", L["MMBTNS_BUTTON_SCALE"] or "Collected icon scale", val / 10))
            ns.MinimapButtonsModule:ApplyButtonScale()
        end,
    })
    scaleSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    cy = cy - SLIDER_HEIGHT

    -- Button Spacing
    local spacingLabel
    spacingLabel, cy = AddLabel(container, cy,
        string.format("%s: %d", L["MMBTNS_BUTTON_SPACING"] or "Spacing", s.buttonSpacing))

    local spacingSlider = OneWoW_GUI:CreateSlider(container, {
        minVal     = 0,
        maxVal     = 8,
        step       = 1,
        currentVal = s.buttonSpacing,
        width      = 260,
        fmt        = "%d",
        onChange    = function(val)
            s.buttonSpacing = val
            spacingLabel:SetText(string.format("%s: %d", L["MMBTNS_BUTTON_SPACING"] or "Spacing", val))
            ns.MinimapButtonsModule:LayoutContainer()
        end,
    })
    spacingSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    cy = cy - SLIDER_HEIGHT + 4

    -- ═══════════════════════════════════════════════════════════════════════
    -- Detected Minimap Icons Section
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMBTNS_ICONS_HEADER"] or "Minimap Icons", yOffset = cy })

    cy = BuildMinimapIconsSection(container, cy, function()
        ns.MinimapButtonsModule._refreshCustomDetail()
    end)

    container:SetHeight(math.abs(cy))
    return cy
end

-- ─── CreateCustomDetail (called by the module feature panel framework) ──────

function ns.MinimapButtonsModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled)
    if detailScrollChild._mmbtnContainer then
        OneWoW_GUI:ClearFrame(detailScrollChild._mmbtnContainer)
    end

    local container = detailScrollChild._mmbtnContainer or CreateFrame("Frame", nil, detailScrollChild)
    detailScrollChild._mmbtnContainer = container
    container:SetParent(detailScrollChild)
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT",  detailScrollChild, "TOPLEFT",  0, yOffset)
    container:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)
    container:Show()

    local capturedYOffset = yOffset

    self._refreshCustomDetail = function()
        OneWoW_GUI:ClearFrame(container)
        local cy = BuildContent(container, isEnabled)
        detailScrollChild:SetHeight(math.abs(capturedYOffset) + math.abs(cy) + 20)
        if detailScrollChild.updateThumb then
            detailScrollChild.updateThumb()
        end
    end

    local cy = BuildContent(container, isEnabled)

    return yOffset + cy
end
