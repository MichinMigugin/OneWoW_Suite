local _, ns = ...
local BagBarModule, L = ns.ModuleRegistry:Current()

local OneWoW_GUI = OneWoW_GUI

local function GetSettings()
    return BagBarModule.GetSettings()
end

local function ItemTableEntries(itemTable)
    local entries = {}
    for itemID in pairs(itemTable) do
        C_Item.RequestLoadItemDataByID(itemID)
        local itemName = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
        local _, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
        tinsert(entries, { id = itemID, label = itemName, icon = icon })
    end
    return entries
end

local function MacroTableEntries(macroTable)
    local names = {}
    for name in pairs(macroTable) do
        tinsert(names, name)
    end
    sort(names)
    local entries = {}
    for _, macroName in ipairs(names) do
        local mName, mIcon = GetMacroInfo(macroName)
        if mName then
            tinsert(entries, { id = macroName, label = mName, icon = mIcon })
        else
            tinsert(entries, {
                id = macroName,
                label = macroName .. " " .. L["BAGBAR_MACRO_MISSING"],
                icon = mIcon,
            })
        end
    end
    return entries
end

local function BuildContent(container, _)
    local s = GetSettings()
    local uiEnabled = ns.ModuleRegistry:IsEnabled("bagbar")
    local cy = 0

    cy = OneWoW_GUI:CreateSection(container, { title = L["BAR_SETTINGS"], yOffset = cy })

    local previewing = BagBarModule:IsPreviewActive()
    local previewBtn = OneWoW_GUI:CreateFitTextButton(container, {
        text = previewing and L["HIDE_BAR"] or L["SHOW_BAR"],
        height = 26,
    })
    previewBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    previewBtn:SetScript("OnClick", function()
        if BagBarModule:IsPreviewActive() then
            BagBarModule:HidePreview()
        else
            BagBarModule:ShowPreview()
        end
        BagBarModule._refreshCustomDetail()
    end)

    local lockBtn = OneWoW_GUI:CreateFitTextButton(container, {
        text = s.locked and (L["BAGBAR_LOCK_POSITION"] .. " (ON)") or (L["BAGBAR_LOCK_POSITION"] .. " (OFF)"),
        height = 26,
    })
    lockBtn:SetPoint("TOPLEFT", previewBtn, "TOPRIGHT", 12, 0)
    lockBtn:SetScript("OnClick", function()
        BagBarModule:SetLocked(not GetSettings().locked)
        BagBarModule._refreshCustomDetail()
    end)
    cy = cy - 32 - 12

    local GROW_DIRS = { "RIGHT", "LEFT", "DOWN", "UP" }
    local growDirLabels = {
        RIGHT = L["BAGBAR_GROW_RIGHT"],
        LEFT  = L["BAGBAR_GROW_LEFT"],
        DOWN  = L["DOWN"],
        UP    = L["UP"],
    }
    local curDir = s.growDirection or "RIGHT"

    local growDirLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    growDirLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    growDirLabel:SetText(L["GROW_DIRECTION"] .. ":")
    growDirLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local growDirDropdown = OneWoW_GUI:CreateDropdown(container, {
        text   = growDirLabels[curDir] or curDir,
        width  = 120,
        height = 26,
    })
    growDirDropdown:SetPoint("LEFT", growDirLabel, "RIGHT", 8, 0)
    growDirDropdown._activeValue = curDir
    OneWoW_GUI:AttachFilterMenu(growDirDropdown, {
        searchable = false,
        menuHeight = 140,
        buildItems = function()
            local items = {}
            for _, d in ipairs(GROW_DIRS) do
                tinsert(items, { text = growDirLabels[d] or d, value = d })
            end
            return items
        end,
        getActiveValue = function()
            return GetSettings().growDirection or "RIGHT"
        end,
        onSelect = function(value, text)
            GetSettings().growDirection = value
            growDirDropdown._text:SetText(text)
            BagBarModule:ScheduleUpdate()
        end,
    })

    local hideAnchorCheck = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["HIDE_ANCHOR_SHOW_ON_HOVER"],
        checked = s.hideAnchor,
        onClick = function(self)
            GetSettings().hideAnchor = self:GetChecked()
            BagBarModule:ScheduleUpdate()
        end,
    })
    hideAnchorCheck:SetPoint("LEFT", growDirDropdown, "RIGHT", 20, 0)
    hideAnchorCheck:SetPoint("TOP", growDirDropdown, "TOP", 0, 0)
    cy = cy - 32

    local SLIDER_PAIR_GAP = 24
    local SLIDER_WIDTH = 170

    local maxLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    maxLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    maxLabel:SetText(string.format("%s: %d", L["BAGBAR_MAX_BUTTONS"], math.min(s.maxButtons or 12, 24)))
    maxLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    cy = cy - maxLabel:GetStringHeight() - 4

    local maxSlider = CreateFrame("Slider", "OneWoW_QoL_BagBarMaxSlider", container, "OptionsSliderTemplate")
    maxSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    maxSlider:SetWidth(SLIDER_WIDTH)
    maxSlider:SetMinMaxValues(1, 24)
    maxSlider:SetValue(math.min(s.maxButtons or 12, 24))
    maxSlider:SetValueStep(1)
    maxSlider:SetObeyStepOnDrag(true)
    OneWoW_GUI:ConfigureOptionsSliderEnds(maxSlider, "1", "24")
    maxSlider:SetScript("OnValueChanged", function(_, value)
        local v = math.min(math.floor(value + 0.5), 24)
        GetSettings().maxButtons = v
        maxLabel:SetText(string.format("%s: %d", L["BAGBAR_MAX_BUTTONS"], v))
        BagBarModule:ScheduleUpdate()
    end)

    local colsLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colsLabel:SetPoint("TOP", maxLabel, "TOP")
    colsLabel:SetPoint("LEFT", maxSlider, "RIGHT", SLIDER_PAIR_GAP, 0)
    colsLabel:SetText(string.format("%s: %d", L["BAGBAR_COLUMNS"], math.min(s.columns or 12, 24)))
    colsLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local colsSlider = CreateFrame("Slider", "OneWoW_QoL_BagBarColsSlider", container, "OptionsSliderTemplate")
    colsSlider:SetPoint("TOP", maxSlider, "TOP")
    colsSlider:SetPoint("LEFT", maxSlider, "RIGHT", SLIDER_PAIR_GAP, 0)
    colsSlider:SetWidth(SLIDER_WIDTH)
    colsSlider:SetMinMaxValues(1, 24)
    colsSlider:SetValue(math.min(s.columns or 12, 24))
    colsSlider:SetValueStep(1)
    colsSlider:SetObeyStepOnDrag(true)
    OneWoW_GUI:ConfigureOptionsSliderEnds(colsSlider, "1", "24")
    colsSlider:SetScript("OnValueChanged", function(_, value)
        local v = math.min(math.floor(value + 0.5), 24)
        GetSettings().columns = v
        colsLabel:SetText(string.format("%s: %d", L["BAGBAR_COLUMNS"], v))
        BagBarModule:ScheduleUpdate()
    end)
    cy = cy - 46

    local sliderRowY = cy
    local sizeLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, sliderRowY)
    sizeLabel:SetText(string.format("%s: %d", L["BUTTON_SIZE"], s.buttonSize or 36))
    sizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local sizeSlider = CreateFrame("Slider", "OneWoW_QoL_BagBarSizeSlider", container, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, sliderRowY - sizeLabel:GetStringHeight() - 4)
    sizeSlider:SetWidth(SLIDER_WIDTH)
    sizeSlider:SetMinMaxValues(24, 48)
    sizeSlider:SetValue(s.buttonSize or 36)
    sizeSlider:SetValueStep(2)
    sizeSlider:SetObeyStepOnDrag(true)
    OneWoW_GUI:ConfigureOptionsSliderEnds(sizeSlider, "24", "48")
    sizeSlider:SetScript("OnValueChanged", function(_, value)
        local v = math.floor(value + 0.5)
        GetSettings().buttonSize = v
        sizeLabel:SetText(string.format("%s: %d", L["BUTTON_SIZE"], v))
        BagBarModule:ScheduleUpdate()
    end)

    local spacingLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spacingLabel:SetPoint("TOP", sizeLabel, "TOP")
    spacingLabel:SetPoint("LEFT", sizeSlider, "RIGHT", SLIDER_PAIR_GAP, 0)
    spacingLabel:SetText(string.format("%s: %d", L["ICON_SPACING"], s.iconSpacing or 4))
    spacingLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local spacingSlider = CreateFrame("Slider", "OneWoW_QoL_BagBarSpacingSlider", container, "OptionsSliderTemplate")
    spacingSlider:SetPoint("TOP", sizeSlider, "TOP")
    spacingSlider:SetPoint("LEFT", sizeSlider, "RIGHT", SLIDER_PAIR_GAP, 0)
    spacingSlider:SetWidth(SLIDER_WIDTH)
    spacingSlider:SetMinMaxValues(0, 12)
    spacingSlider:SetValue(s.iconSpacing or 4)
    spacingSlider:SetValueStep(1)
    spacingSlider:SetObeyStepOnDrag(true)
    OneWoW_GUI:ConfigureOptionsSliderEnds(spacingSlider, "0", "12")
    spacingSlider:SetScript("OnValueChanged", function(_, value)
        local v = math.floor(value + 0.5)
        GetSettings().iconSpacing = v
        spacingLabel:SetText(string.format("%s: %d", L["ICON_SPACING"], v))
        BagBarModule:ScheduleUpdate()
    end)
    cy = cy - 50

    cy = OneWoW_GUI:CreateSection(container, { title = L["BAGBAR_EXPRESSION_FILTER_HEADER"], yOffset = cy })

    local exprDescToBoxGap = 14
    local exprDesc = container:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    exprDesc:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    exprDesc:SetPoint("TOPRIGHT", container, "TOPRIGHT", -12, cy)
    exprDesc:SetJustifyH("LEFT")
    exprDesc:SetWordWrap(true)
    exprDesc:SetSpacing(2)
    exprDesc:SetText(L["BAGBAR_EXPRESSION_FILTER_DESC"])
    exprDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    cy = cy - exprDesc:GetStringHeight() - exprDescToBoxGap

    local exprBox = OneWoW_GUI:CreateEditBox(container, {
        height = 24,
        placeholderText = L["BAGBAR_EXPRESSION_FILTER_PLACEHOLDER"],
        onTextChanged = function(text)
            local cur = GetSettings()
            cur.expressionFilter = text or ""
            BagBarModule:ScheduleUpdate()
        end,
    })
    exprBox:SetPoint("TOPLEFT", exprDesc, "BOTTOMLEFT", 0, -exprDescToBoxGap)
    exprBox:SetPoint("TOPRIGHT", exprDesc, "BOTTOMRIGHT", -30, -exprDescToBoxGap)

    local exprHelpBtn
    if OneWoW_GUI.CreateKeywordHelpButton then
        exprHelpBtn = OneWoW_GUI:CreateKeywordHelpButton(container, { editBox = exprBox })
        exprHelpBtn:SetPoint("LEFT", exprBox, "RIGHT", 4, 0)
    end

    OneWoW_GUI:AttachSearchTooltip(exprBox)

    exprBox:SetText(s.expressionFilter or "")
    exprBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    cy = cy - exprBox:GetHeight() - 16

    cy = OneWoW_GUI:CreateSection(container, { title = L["BAGBAR_MANUAL_ITEMS_HEADER"], yOffset = cy })

    local manualIntro = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    manualIntro:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    manualIntro:SetPoint("TOPRIGHT", container, "TOPRIGHT", -12, cy)
    manualIntro:SetJustifyH("LEFT")
    manualIntro:SetWordWrap(true)
    manualIntro:SetSpacing(2)
    manualIntro:SetText(L["BAGBAR_MANUAL_DESC"])
    manualIntro:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    cy = cy - manualIntro:GetStringHeight() - 8

    local manualAdd = OneWoW_GUI:CreateValueAddRow(container, {
        yOffset = cy,
        label = L["ITEM_ID"],
        addText = ADD,
        input = { kind = "itemId" },
        drop = { mode = "chip", text = L["DRAG_ITEM_HERE"] },
        onAdd = function(itemID)
            local cur = GetSettings()
            cur.manualItems[itemID] = true
            C_Item.RequestLoadItemDataByID(itemID)
            BagBarModule:ScheduleUpdate()
            C_Timer.After(0, function()
                if BagBarModule._refreshCustomDetail then
                    BagBarModule._refreshCustomDetail()
                end
            end)
            C_Timer.After(0.5, function()
                if BagBarModule._refreshCustomDetail then
                    BagBarModule._refreshCustomDetail()
                end
            end)
        end,
    })
    cy = cy - manualAdd:GetHeight() - 8

    local manualList = OneWoW_GUI:CreateEntryList(container, {
        yOffset = cy,
        grow = true,
        emptyText = L["NO_ITEMS"],
        getEntries = function()
            return ItemTableEntries(GetSettings().manualItems)
        end,
        onRemove = function(itemID)
            GetSettings().manualItems[itemID] = nil
            BagBarModule:ScheduleUpdate()
            C_Timer.After(0, function()
                if BagBarModule._refreshCustomDetail then
                    BagBarModule._refreshCustomDetail()
                end
            end)
        end,
    })
    cy = cy - manualList:GetHeight() - 8

    cy = OneWoW_GUI:CreateSection(container, { title = L["BAGBAR_MACROS_HEADER"], yOffset = cy })

    local macroIntro = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    macroIntro:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    macroIntro:SetPoint("TOPRIGHT", container, "TOPRIGHT", -12, cy)
    macroIntro:SetJustifyH("LEFT")
    macroIntro:SetWordWrap(true)
    macroIntro:SetSpacing(2)
    macroIntro:SetText(L["BAGBAR_MACROS_DESC"])
    macroIntro:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    cy = cy - macroIntro:GetStringHeight() - 8

    local macroAdd = OneWoW_GUI:CreateValueAddRow(container, {
        yOffset = cy,
        label = L["BAGBAR_MACRO_NAME_LABEL"],
        addText = ADD,
        input = { kind = "text", width = 120, maxLetters = 64 },
        drop = {
            mode = "chip",
            text = L["BAGBAR_DRAG_MACRO_HERE"],
            width = 120,
            cursorTypes = { "macro" },
        },
        onAdd = function(macroName)
            if GetMacroIndexByName(macroName) <= 0 then
                return false
            end
            local mName = GetMacroInfo(macroName)
            if not mName then
                return false
            end
            local cur = GetSettings()
            cur.manualMacros[mName] = true
            BagBarModule:ScheduleUpdate()
            C_Timer.After(0, function()
                if BagBarModule._refreshCustomDetail then
                    BagBarModule._refreshCustomDetail()
                end
            end)
            C_Timer.After(0.2, function()
                if BagBarModule._refreshCustomDetail then
                    BagBarModule._refreshCustomDetail()
                end
            end)
        end,
    })
    cy = cy - macroAdd:GetHeight() - 8

    local macroList = OneWoW_GUI:CreateEntryList(container, {
        yOffset = cy,
        grow = true,
        emptyText = L["NO_MACROS"],
        getEntries = function()
            return MacroTableEntries(GetSettings().manualMacros)
        end,
        onRemove = function(macroName)
            GetSettings().manualMacros[macroName] = nil
            BagBarModule:ScheduleUpdate()
            C_Timer.After(0, function()
                if BagBarModule._refreshCustomDetail then
                    BagBarModule._refreshCustomDetail()
                end
            end)
        end,
    })
    cy = cy - macroList:GetHeight() - 8

    cy = OneWoW_GUI:CreateSection(container, { title = L["BLACKLIST"], yOffset = cy })

    local blDesc = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    blDesc:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    blDesc:SetPoint("TOPRIGHT", container, "TOPRIGHT", -12, cy)
    blDesc:SetJustifyH("LEFT")
    blDesc:SetWordWrap(true)
    blDesc:SetSpacing(2)
    blDesc:SetText(L["BAGBAR_BLACKLIST_DESC"])
    blDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    cy = cy - blDesc:GetStringHeight() - 10

    local blAdd = OneWoW_GUI:CreateValueAddRow(container, {
        yOffset = cy,
        label = L["ITEM_ID"],
        addText = ADD,
        input = { kind = "itemId" },
        drop = { mode = "chip", text = L["DRAG_ITEM_HERE"] },
        onAdd = function(itemID)
            local cur = GetSettings()
            cur.blacklist[itemID] = true
            C_Item.RequestLoadItemDataByID(itemID)
            BagBarModule:ScheduleUpdate()
            C_Timer.After(0, function()
                if BagBarModule._refreshCustomDetail then
                    BagBarModule._refreshCustomDetail()
                end
            end)
            C_Timer.After(0.5, function()
                if BagBarModule._refreshCustomDetail then
                    BagBarModule._refreshCustomDetail()
                end
            end)
        end,
    })
    cy = cy - blAdd:GetHeight() - 8

    local blList = OneWoW_GUI:CreateEntryList(container, {
        yOffset = cy,
        grow = true,
        emptyText = L["NO_ITEMS"],
        getEntries = function()
            return ItemTableEntries(GetSettings().blacklist)
        end,
        onRemove = function(itemID)
            GetSettings().blacklist[itemID] = nil
            BagBarModule:ScheduleUpdate()
            C_Timer.After(0, function()
                if BagBarModule._refreshCustomDetail then
                    BagBarModule._refreshCustomDetail()
                end
            end)
        end,
    })
    cy = cy - blList:GetHeight() - 8

    if not uiEnabled then
        previewBtn:Disable()
        lockBtn:Disable()
        hideAnchorCheck:Disable()
        growDirDropdown:Disable()
        maxSlider:Disable()
        sizeSlider:Disable()
        colsSlider:Disable()
        spacingSlider:Disable()
        exprBox:Disable()
        if exprHelpBtn then exprHelpBtn:Disable() end
        manualAdd:SetEnabled(false)
        manualList:SetEnabled(false)
        macroAdd:SetEnabled(false)
        macroList:SetEnabled(false)
        blAdd:SetEnabled(false)
        blList:SetEnabled(false)
    end

    container:SetHeight(math.abs(cy))
    return cy
end

function BagBarModule:CreateCustomDetail(detailScrollChild, yOffset, _, registerRefresh)
    if detailScrollChild._bagbarContainer then
        OneWoW_GUI:ClearFrame(detailScrollChild._bagbarContainer)
    end

    local container = detailScrollChild._bagbarContainer or CreateFrame("Frame", nil, detailScrollChild)
    detailScrollChild._bagbarContainer = container
    container:SetParent(detailScrollChild)
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
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

    if registerRefresh then
        registerRefresh(function()
            if self._refreshCustomDetail then
                self._refreshCustomDetail()
            end
        end)
    end

    local cy = BuildContent(container)

    return yOffset + cy
end
