local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI and OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local function GetSettings()
    return ns.MinimapButtonsModule.GetSettings()
end

-- ─── String list management (whitelist / blacklist) ─────────────────────────

local function MakeStringListEditor(parent, listKey, yOffset, refreshFn)
    local L = ns.L
    local s = GetSettings()
    local list = s[listKey] or {}

    local headerKey = listKey == "whitelist" and "MMBTNS_WHITELIST_HEADER" or "MMBTNS_BLACKLIST_HEADER"
    local descKey   = listKey == "whitelist" and "MMBTNS_WHITELIST_DESC"   or "MMBTNS_BLACKLIST_DESC"
    local addKey    = listKey == "whitelist" and "MMBTNS_WHITELIST_ADD"    or "MMBTNS_BLACKLIST_ADD"
    local phKey     = listKey == "whitelist" and "MMBTNS_WHITELIST_PLACEHOLDER" or "MMBTNS_BLACKLIST_PLACEHOLDER"

    local sectionLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sectionLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    sectionLabel:SetText(L[headerKey] or listKey)
    sectionLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - sectionLabel:GetStringHeight() - 4

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    desc:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetSpacing(2)
    desc:SetText(L[descKey] or "")
    desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    yOffset = yOffset - desc:GetStringHeight() - 8

    local inputBox = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    inputBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    inputBox:SetSize(180, 22)
    inputBox:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    inputBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    inputBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    inputBox:SetFontObject(GameFontHighlight)
    inputBox:SetTextInsets(4, 4, 0, 0)
    inputBox:SetAutoFocus(false)
    inputBox:SetMaxLetters(80)
    inputBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    inputBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    inputBox:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
    end)
    inputBox:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    local ph = inputBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 6, 0)
    ph:SetText(L[phKey] or "Frame name...")
    inputBox:SetScript("OnTextChanged", function(self)
        ph:SetShown((self:GetText() or "") == "")
    end)

    local addBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = L[addKey] or "Add", height = 24 })
    addBtn:SetPoint("LEFT", inputBox, "RIGHT", 6, 0)
    addBtn:SetScript("OnClick", function()
        local name = strtrim(inputBox:GetText() or "")
        if name ~= "" then
            table.insert(s[listKey], name)
            inputBox:SetText("")
            ns.MinimapButtonsModule:Refresh()
            if refreshFn then refreshFn() end
        end
    end)
    yOffset = yOffset - 30

    local listFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    listFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    listFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    listFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    listFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local rowOff = -5
    local hasItems = false

    for i, name in ipairs(list) do
        hasItems = true
        local row = CreateFrame("Frame", nil, listFrame)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT",  listFrame, "TOPLEFT",  10, rowOff)
        row:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -10, rowOff)

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT",  row, "LEFT",  0, 0)
        nameText:SetPoint("RIGHT", row, "RIGHT", -20, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(name)
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local removeBtn = CreateFrame("Button", nil, row)
        removeBtn:SetSize(16, 16)
        removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        removeBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
        local idx = i
        removeBtn:SetScript("OnClick", function()
            table.remove(s[listKey], idx)
            ns.MinimapButtonsModule:Refresh()
            if refreshFn then refreshFn() end
        end)

        rowOff = rowOff - 22
    end

    local frameHeight = hasItems and (math.abs(rowOff) + 8) or 28
    listFrame:SetHeight(frameHeight)

    if not hasItems then
        local emptyText = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        emptyText:SetPoint("CENTER")
        emptyText:SetText("---")
        emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    yOffset = yOffset - frameHeight - 8
    return yOffset
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
    -- Whitelist / Blacklist Section
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMBTNS_LISTS_HEADER"] or "Whitelist / Blacklist", yOffset = cy })

    cy = MakeStringListEditor(container, "whitelist", cy, function()
        ns.MinimapButtonsModule._refreshCustomDetail()
    end)

    cy = cy - 8

    cy = MakeStringListEditor(container, "blacklist", cy, function()
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
