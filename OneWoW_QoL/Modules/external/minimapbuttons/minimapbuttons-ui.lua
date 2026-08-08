local _, ns = ...
local MinimapButtonsModule, L = ns.ModuleRegistry:Current()

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI and OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local function GetSettings()
    return MinimapButtonsModule.GetSettings()
end

-- ─── Detected minimap icons (per-button Collector / Map / Hide) ────────────

-- Build one row for a single detected (or previously-detected) minimap icon:
--
--   [X]  Outfitter             Enabled    [Collector ▼]
--
-- The X drops the entry from the DB (useful for stale addons that were
-- uninstalled). The dropdown sets the user's preference; ApplyButtonPref
-- moves the button between the collector panel, the minimap, or an offscreen
-- hidden frame. Enabled/Disabled reflects whether the owning addon is loaded.
local ROW_PADDING_X   = 12
local ICON_ROW_HEIGHT = 28
local ICON_ROW_GAP    = 4

local function PrefLabel(pref)
    if pref == "mini" then return L["MMBTNS_ICONS_MINI"] end
    if pref == "map" then return L["MMBTNS_ICONS_MAP"] end
    if pref == "hide" then return HIDE end
    return L["MMBTNS_ICONS_MINI"]
end

local function BuildIconRow(parent, info, yOffset, refreshFn)
    local capturedName = info.name
    local pref = info.pref or "mini"

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
            GameTooltip:AddLine(L["MMBTNS_ICONS_REMOVE_LOCKED_TT"], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
        removeBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["MMBTNS_ICONS_REMOVE_TT"])
            GameTooltip:Show()
        end)
        removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        removeBtn:SetScript("OnClick", function()
            MinimapButtonsModule.RemoveKnownButton(capturedName)
            if refreshFn then refreshFn() end
        end)
    end

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", removeBtn, "RIGHT", 8, 0)
    label:SetJustifyH("LEFT")
    label:SetText(info.displayName or capturedName)
    label:SetTextColor(OneWoW_GUI:GetThemeColor(info.seen and "TEXT_PRIMARY" or "TEXT_MUTED"))

    local prefDropdown, prefDropdownText = OneWoW_GUI:CreateDropdown(row, {
        width = 110,
        height = 22,
        text = PrefLabel(pref),
    })
    prefDropdown:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    prefDropdown._activeValue = pref

    OneWoW_GUI:AttachFilterMenu(prefDropdown, {
        searchable = false,
        menuHeight = 110,
        buildItems = function()
            return {
                { value = "mini", text = L["MMBTNS_ICONS_MINI"] },
                { value = "map", text = L["MMBTNS_ICONS_MAP"] },
                { value = "hide", text = HIDE },
            }
        end,
        getActiveValue = function()
            return prefDropdown._activeValue
        end,
        onSelect = function(value, text)
            prefDropdown._activeValue = value
            prefDropdownText:SetText(text)
            MinimapButtonsModule:ApplyButtonPref(capturedName, value)
        end,
    })

    local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("RIGHT", prefDropdown, "LEFT", -10, 0)
    statusText:SetJustifyH("RIGHT")
    statusText:SetText(info.seen and L["MMBTNS_ICONS_ENABLED"] or L["MMBTNS_ICONS_DISABLED"])
    statusText:SetTextColor(OneWoW_GUI:GetThemeColor(
        info.seen and "TEXT_FEATURES_ENABLED" or "TEXT_FEATURES_DISABLED"))

    label:SetPoint("RIGHT", statusText, "LEFT", -8, 0)

    return yOffset - ICON_ROW_HEIGHT - ICON_ROW_GAP
end

local function BuildMinimapIconsSection(parent, yOffset, refreshFn)

    local sectionLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sectionLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_PADDING_X, yOffset)
    sectionLabel:SetText(L["MMBTNS_ICONS_HEADER"])
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
    MinimapButtonsModule:DiscoverButtons()

    local buttons = MinimapButtonsModule:GetKnownButtons()

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

local function BuildContent(container)
    local s = GetSettings()
    local cy = 0

    -- ═══════════════════════════════════════════════════════════════════════
    -- Behavior Section
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMBTNS_BEHAVIOR_HEADER"], yOffset = cy })

    -- Close Behavior dropdown (Stay Open / Auto Close)
    local closeMode = s.closeMode or "autoclose"
    local closeLabels = {
        stayopen = L["MMBTNS_STAY_OPEN"],
        autoclose = L["MMBTNS_AUTO_CLOSE"],
    }

    local closeLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    closeLabel:SetText(L["MMBTNS_CLOSE_MODE"] .. ":")
    closeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local closeDropdown, closeDropdownText = OneWoW_GUI:CreateDropdown(container, {
        width = 140,
        height = 26,
        text = closeLabels[closeMode] or closeLabels.autoclose,
    })
    closeDropdown:SetPoint("LEFT", closeLabel, "RIGHT", 8, 0)
    closeDropdown._activeValue = closeMode

    OneWoW_GUI:AttachFilterMenu(closeDropdown, {
        searchable = false,
        menuHeight = 90,
        buildItems = function()
            return {
                { value = "stayopen", text = L["MMBTNS_STAY_OPEN"] },
                { value = "autoclose", text = L["MMBTNS_AUTO_CLOSE"] },
            }
        end,
        getActiveValue = function()
            return GetSettings().closeMode or "autoclose"
        end,
        onSelect = function(value, text)
            local prev = s.closeMode
            s.closeMode = value
            closeDropdown._activeValue = value
            closeDropdownText:SetText(text)
            if value == "stayopen" then
                MinimapButtonsModule:CancelAutoCloseTimer()
            end
            if prev ~= value then
                MinimapButtonsModule._refreshCustomDetail()
            end
        end,
    })
    cy = cy - 32

    -- Auto-close delay slider (only when autoclose is active)
    if s.closeMode == "autoclose" then
        local delayLabel
        delayLabel, cy = AddLabel(container, cy,
            string.format("%s: %d", L["MMBTNS_AUTO_CLOSE_DELAY"], s.autoCloseDelay or 3))

        local delaySlider = OneWoW_GUI:CreateSlider(container, {
            minVal     = 1,
            maxVal     = 10,
            step       = 1,
            currentVal = s.autoCloseDelay or 3,
            width      = 260,
            fmt        = "%d",
            onChange    = function(val)
                s.autoCloseDelay = val
                delayLabel:SetText(string.format("%s: %d", L["MMBTNS_AUTO_CLOSE_DELAY"], val))
            end,
        })
        delaySlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
        cy = cy - SLIDER_HEIGHT
    end

    -- Enhanced OneWoW Menu
    local enhCB = OneWoW_GUI:CreateCheckbox(container, {
        label  = L["MMBTNS_ENHANCED_MENU"],
        checked = s.enhancedMenu,
        onClick = function(self)
            s.enhancedMenu = self:GetChecked()
            MinimapButtonsModule:Refresh()
        end,
    })
    enhCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    cy = cy - ROW_HEIGHT

    local _, descCy = AddDescription(container, cy, L["MMBTNS_ENHANCED_MENU_DESC"])
    cy = descCy

    -- Lock position
    local lockCB = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMBTNS_LOCK_POSITION"],
        checked = s.locked,
        onClick = function(self)
            s.locked = self:GetChecked()
        end,
    })
    lockCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    cy = cy - ROW_HEIGHT

    -- Also Show on Minimap: collected buttons keep their normal entry in the
    -- collector AND get a click-through copy back on the minimap edge.
    local alsoShowCB = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMBTNS_ALSO_SHOW_ON_MINIMAP"],
        checked = s.alsoShowOnMinimap,
        onClick = function(self)
            s.alsoShowOnMinimap = self:GetChecked()
            MinimapButtonsModule:Refresh()
        end,
    })
    alsoShowCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    cy = cy - ROW_HEIGHT

    local _, alsoDescCy = AddDescription(container, cy, L["MMBTNS_ALSO_SHOW_ON_MINIMAP_DESC"])
    cy = alsoDescCy

    -- Show tooltips
    local tipCB = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMBTNS_SHOW_TOOLTIPS"],
        checked = s.showTooltips,
        onClick = function(self)
            s.showTooltips = self:GetChecked()
        end,
    })
    tipCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    cy = cy - ROW_HEIGHT

    -- Grow direction dropdown
    local growDir = s.growDirection or "down"
    local growDirLabels = {
        down = L["DOWN"],
        up = L["UP"],
        left = L["MMBTNS_GROW_LEFT"],
        right = L["MMBTNS_GROW_RIGHT"],
    }

    local growDirLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    growDirLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    growDirLabel:SetText(L["GROW_DIRECTION"] .. ":")
    growDirLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local growDirDropdown, growDirDropdownText = OneWoW_GUI:CreateDropdown(container, {
        width = 120,
        height = 26,
        text = growDirLabels[growDir] or growDirLabels.down,
    })
    growDirDropdown:SetPoint("LEFT", growDirLabel, "RIGHT", 8, 0)
    growDirDropdown._activeValue = growDir

    OneWoW_GUI:AttachFilterMenu(growDirDropdown, {
        searchable = false,
        menuHeight = 140,
        buildItems = function()
            return {
                { value = "down", text = L["DOWN"] },
                { value = "up", text = L["UP"] },
                { value = "left", text = L["MMBTNS_GROW_LEFT"] },
                { value = "right", text = L["MMBTNS_GROW_RIGHT"] },
            }
        end,
        getActiveValue = function()
            return GetSettings().growDirection or "down"
        end,
        onSelect = function(value, text)
            s.growDirection = value
            growDirDropdown._activeValue = value
            growDirDropdownText:SetText(text)
            MinimapButtonsModule:LayoutContainer()
        end,
    })
    cy = cy - 32

    -- ═══════════════════════════════════════════════════════════════════════
    -- Layout Section
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMBTNS_LAYOUT_HEADER"], yOffset = cy })

    -- Max Columns
    local colsLabel
    colsLabel, cy = AddLabel(container, cy,
        string.format("%s: %d", L["MMBTNS_MAX_COLUMNS"], s.maxColumns))

    local colsSlider = OneWoW_GUI:CreateSlider(container, {
        minVal     = 1,
        maxVal     = 20,
        step       = 1,
        currentVal = s.maxColumns,
        width      = 260,
        fmt        = "%d",
        onChange    = function(val)
            s.maxColumns = val
            colsLabel:SetText(string.format("%s: %d", L["MMBTNS_MAX_COLUMNS"], val))
            MinimapButtonsModule:LayoutContainer()
        end,
    })
    colsSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    cy = cy - SLIDER_HEIGHT

    -- Max Rows
    local rowsDisplay = s.maxRows == 0 and "∞" or tostring(s.maxRows)
    local rowsLabel
    rowsLabel, cy = AddLabel(container, cy,
        string.format("%s: %s", L["MMBTNS_MAX_ROWS"], rowsDisplay))

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
            rowsLabel:SetText(string.format("%s: %s", L["MMBTNS_MAX_ROWS"], display))
            MinimapButtonsModule:LayoutContainer()
        end,
    })
    rowsSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    cy = cy - SLIDER_HEIGHT

    local rowsDesc = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rowsDesc:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    rowsDesc:SetText(L["MMBTNS_MAX_ROWS_DESC"])
    rowsDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    cy = cy - rowsDesc:GetStringHeight() - 10

    -- Button Size
    local sizeLabel
    sizeLabel, cy = AddLabel(container, cy,
        string.format("%s: %d", L["BUTTON_SIZE"], s.buttonSize))

    local sizeSlider = OneWoW_GUI:CreateSlider(container, {
        minVal     = 24,
        maxVal     = 48,
        step       = 2,
        currentVal = s.buttonSize,
        width      = 260,
        fmt        = "%d",
        onChange    = function(val)
            s.buttonSize = val
            sizeLabel:SetText(string.format("%s: %d", L["BUTTON_SIZE"], val))
            MinimapButtonsModule:LayoutContainer()
        end,
    })
    sizeSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    cy = cy - SLIDER_HEIGHT

    -- Collected icon scale (MinimapButtonButton-style: stored as tenths, e.g. 10 = 1.0 scale)
    local scaleLabel
    scaleLabel, cy = AddLabel(container, cy,
        string.format("%s: %.1f", L["MMBTNS_BUTTON_SCALE"], (s.buttonScale or 10) / 10))

    local scaleSlider = OneWoW_GUI:CreateSlider(container, {
        minVal     = 1,
        maxVal     = 50,
        step       = 1,
        currentVal = s.buttonScale or 10,
        width      = 260,
        fmt        = "%d",
        onChange    = function(val)
            s.buttonScale = val
            scaleLabel:SetText(string.format("%s: %.1f", L["MMBTNS_BUTTON_SCALE"], val / 10))
            MinimapButtonsModule:ApplyButtonScale()
        end,
    })
    scaleSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    cy = cy - SLIDER_HEIGHT

    -- Button Spacing
    local spacingLabel
    spacingLabel, cy = AddLabel(container, cy,
        string.format("%s: %d", L["MMBTNS_BUTTON_SPACING"], s.buttonSpacing))

    local spacingSlider = OneWoW_GUI:CreateSlider(container, {
        minVal     = 0,
        maxVal     = 8,
        step       = 1,
        currentVal = s.buttonSpacing,
        width      = 260,
        fmt        = "%d",
        onChange    = function(val)
            s.buttonSpacing = val
            spacingLabel:SetText(string.format("%s: %d", L["MMBTNS_BUTTON_SPACING"], val))
            MinimapButtonsModule:LayoutContainer()
        end,
    })
    spacingSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    cy = cy - SLIDER_HEIGHT + 4

    -- ═══════════════════════════════════════════════════════════════════════
    -- Detected Minimap Icons Section
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMBTNS_ICONS_HEADER"], yOffset = cy })

    cy = BuildMinimapIconsSection(container, cy, function()
        MinimapButtonsModule._refreshCustomDetail()
    end)

    container:SetHeight(math.abs(cy))
    return cy
end

-- ─── CreateCustomDetail (called by the module feature panel framework) ──────

function MinimapButtonsModule:CreateCustomDetail(detailScrollChild, yOffset, _)
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
        local cy = BuildContent(container)
        detailScrollChild:SetHeight(math.abs(capturedYOffset) + math.abs(cy) + 20)
        if detailScrollChild.updateThumb then
            detailScrollChild.updateThumb()
        end
    end

    local cy = BuildContent(container)

    return yOffset + cy
end
