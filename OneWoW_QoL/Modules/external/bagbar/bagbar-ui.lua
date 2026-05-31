local _, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

StaticPopupDialogs["ONEWOW_QOL_CLEAR_BAGBAR_BLACKLIST"] = {
    text = "",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        local addon = _G.OneWoW_QoL
        if addon and addon.db and addon.db.global.modules and addon.db.global.modules["bagbar"] then
            wipe(addon.db.global.modules["bagbar"].blacklist)
        end
        ns.BagBarModule:ClearTempBlacklist()
        if ns.ModuleRegistry:IsEnabled("bagbar") then
            ns.BagBarModule:ScheduleUpdate()
        end
        print("|cFF00FF00" .. (ns.L["BAGBAR_BLACKLIST_CLEARED"] or "Bag Bar blacklist cleared.") .. "|r")
        if ns.BagBarModule._refreshCustomDetail then
            ns.BagBarModule._refreshCustomDetail()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function GetSettings()
    return ns.BagBarModule.GetSettings()
end

local function MakeItemDropZone(parent, label, yOffset, onReceive)
    local itemIDLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemIDLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    itemIDLabel:SetText(label)
    itemIDLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local itemIDBox = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    itemIDBox:SetPoint("LEFT", itemIDLabel, "RIGHT", 8, 0)
    itemIDBox:SetSize(90, 22)
    itemIDBox:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    itemIDBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    itemIDBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    itemIDBox:SetFontObject(GameFontHighlight)
    itemIDBox:SetTextInsets(4, 4, 0, 0)
    itemIDBox:SetAutoFocus(false)
    itemIDBox:SetMaxLetters(10)
    itemIDBox:SetNumeric(true)
    itemIDBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    itemIDBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    itemIDBox:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
    end)
    itemIDBox:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    local addBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = ns.L["BAGBAR_ADD_BUTTON"], height = 24 })
    addBtn:SetPoint("LEFT", itemIDBox, "RIGHT", 6, 0)
    addBtn:SetScript("OnClick", function()
        local id = tonumber(itemIDBox:GetText())
        if id and id > 0 then
            onReceive(id)
            itemIDBox:SetText("")
        end
    end)

    local dropZone = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    dropZone:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
    dropZone:SetSize(110, 24)
    dropZone:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    dropZone:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    dropZone:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    dropZone:EnableMouse(true)

    local dropText = dropZone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropText:SetPoint("CENTER")
    dropText:SetText(ns.L["BAGBAR_DRAG_ITEM_HERE"])
    dropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local function handleDrop()
        local infoType, itemID = GetCursorInfo()
        if infoType == "item" and itemID and itemID > 0 then
            ClearCursor()
            onReceive(itemID)
        end
    end

    dropZone:SetScript("OnReceiveDrag", handleDrop)
    dropZone:SetScript("OnMouseUp",     handleDrop)
    dropZone:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
    end)
    dropZone:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    return yOffset - 30, itemIDBox, addBtn, dropZone
end

local function MakeItemList(parent, itemTable, yOffset, onRemove, uiEnabled)
    local listFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    listFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    listFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    listFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    listFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local rowOffset = -5
    local hasItems  = false

    for itemID, _ in pairs(itemTable) do
        hasItems = true
        C_Item.RequestLoadItemDataByID(itemID)
        local itemName = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
        local _, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)

        local row = CreateFrame("Frame", nil, listFrame)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT",  listFrame, "TOPLEFT",  10, rowOffset)
        row:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -10, rowOffset)

        if icon then
            local iconTex = row:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(16, 16)
            iconTex:SetPoint("LEFT", row, "LEFT", 0, 0)
            iconTex:SetTexture(icon)
            iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", row, "LEFT", 22, 0)
        nameText:SetPoint("RIGHT", row, "RIGHT", -20, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(itemName)
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local removeBtn = CreateFrame("Button", nil, row)
        removeBtn:SetSize(16, 16)
        removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        removeBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
        local capturedID = itemID
        removeBtn:SetScript("OnClick", function()
            onRemove(capturedID)
        end)
        if not uiEnabled then
            removeBtn:Disable()
        end

        rowOffset = rowOffset - 22
    end

    local frameHeight = hasItems and (math.abs(rowOffset) + 8) or 28
    listFrame:SetHeight(frameHeight)

    if not hasItems then
        local emptyText = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        emptyText:SetPoint("CENTER")
        emptyText:SetText("---")
        emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    return yOffset - frameHeight - 8
end

local function BuildContent(container, _)
    local L = ns.L
    local s = GetSettings()
    local uiEnabled = ns.ModuleRegistry:IsEnabled("bagbar")
    local cy = 0

    cy = OneWoW_GUI:CreateSection(container, { title = L["BAGBAR_SETTINGS_HEADER"], yOffset = cy })

    local previewing = ns.BagBarModule:IsPreviewActive()
    local previewBtn = OneWoW_GUI:CreateFitTextButton(container, {
        text = previewing and L["BAGBAR_HIDE_BAR"] or L["BAGBAR_SHOW_BAR"],
        height = 26,
    })
    previewBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    previewBtn:SetScript("OnClick", function()
        if ns.BagBarModule:IsPreviewActive() then
            ns.BagBarModule:HidePreview()
        else
            ns.BagBarModule:ShowPreview()
        end
        ns.BagBarModule._refreshCustomDetail()
    end)

    local lockBtn = OneWoW_GUI:CreateFitTextButton(container, {
        text = s.locked and (L["BAGBAR_LOCK_POSITION"] .. " (ON)") or (L["BAGBAR_LOCK_POSITION"] .. " (OFF)"),
        height = 26,
    })
    lockBtn:SetPoint("TOPLEFT", previewBtn, "TOPRIGHT", 12, 0)
    lockBtn:SetScript("OnClick", function()
        ns.BagBarModule:SetLocked(not GetSettings().locked)
        ns.BagBarModule._refreshCustomDetail()
    end)
    cy = cy - 32 - 12

    local GROW_DIRS = { "RIGHT", "LEFT", "DOWN", "UP" }
    local growDirLabels = {
        RIGHT = L["BAGBAR_GROW_RIGHT"],
        LEFT  = L["BAGBAR_GROW_LEFT"],
        DOWN  = L["BAGBAR_GROW_DOWN"],
        UP    = L["BAGBAR_GROW_UP"],
    }
    local curDir = s.growDirection or "RIGHT"

    local growDirLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    growDirLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    growDirLabel:SetText(L["BAGBAR_GROW_DIRECTION"] .. ":")
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
            ns.BagBarModule:ScheduleUpdate()
        end,
    })

    local hideAnchorCheck = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["BAGBAR_HIDE_ANCHOR"],
        checked = s.hideAnchor,
        onClick = function(self)
            GetSettings().hideAnchor = self:GetChecked()
            ns.BagBarModule:ScheduleUpdate()
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
        ns.BagBarModule:ScheduleUpdate()
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
        ns.BagBarModule:ScheduleUpdate()
    end)
    cy = cy - 46

    local sliderRowY = cy
    local sizeLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, sliderRowY)
    sizeLabel:SetText(string.format("%s: %d", L["BAGBAR_BUTTON_SIZE"], s.buttonSize or 36))
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
        sizeLabel:SetText(string.format("%s: %d", L["BAGBAR_BUTTON_SIZE"], v))
        ns.BagBarModule:ScheduleUpdate()
    end)

    local spacingLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spacingLabel:SetPoint("TOP", sizeLabel, "TOP")
    spacingLabel:SetPoint("LEFT", sizeSlider, "RIGHT", SLIDER_PAIR_GAP, 0)
    spacingLabel:SetText(string.format("%s: %d", L["BAGBAR_ICON_SPACING"], s.iconSpacing or 4))
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
        spacingLabel:SetText(string.format("%s: %d", L["BAGBAR_ICON_SPACING"], v))
        ns.BagBarModule:ScheduleUpdate()
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
            ns.BagBarModule:ScheduleUpdate()
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

    local manualItemBox, manualAddBtn, manualDrop
    cy, manualItemBox, manualAddBtn, manualDrop = MakeItemDropZone(container, L["BAGBAR_ITEM_ID_LABEL"], cy,
        function(itemID)
            local cur = GetSettings()
            cur.manualItems[itemID] = true
            C_Item.RequestLoadItemDataByID(itemID)
            ns.BagBarModule:ScheduleUpdate()
            C_Timer.After(0.5, function() ns.BagBarModule._refreshCustomDetail() end)
        end)

    cy = MakeItemList(container, s.manualItems, cy,
        function(itemID)
            GetSettings().manualItems[itemID] = nil
            ns.BagBarModule:ScheduleUpdate()
            ns.BagBarModule._refreshCustomDetail()
        end, uiEnabled)

    cy = OneWoW_GUI:CreateSection(container, { title = L["BAGBAR_BLACKLIST_HEADER"], yOffset = cy })

    local blDesc = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    blDesc:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    blDesc:SetPoint("TOPRIGHT", container, "TOPRIGHT", -12, cy)
    blDesc:SetJustifyH("LEFT")
    blDesc:SetWordWrap(true)
    blDesc:SetSpacing(2)
    blDesc:SetText(L["BAGBAR_BLACKLIST_DESC"])
    blDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    cy = cy - blDesc:GetStringHeight() - 10

    local blItemBox, blAddBtn, blDrop
    cy, blItemBox, blAddBtn, blDrop = MakeItemDropZone(container, L["BAGBAR_ITEM_ID_LABEL"], cy,
        function(itemID)
            local cur = GetSettings()
            cur.blacklist[itemID] = true
            C_Item.RequestLoadItemDataByID(itemID)
            ns.BagBarModule:ScheduleUpdate()
            C_Timer.After(0.5, function() ns.BagBarModule._refreshCustomDetail() end)
        end)

    cy = MakeItemList(container, s.blacklist, cy,
        function(itemID)
            GetSettings().blacklist[itemID] = nil
            ns.BagBarModule:ScheduleUpdate()
            ns.BagBarModule._refreshCustomDetail()
        end, uiEnabled)

    local clearBtn = OneWoW_GUI:CreateFitTextButton(container, { text = L["BAGBAR_CLEAR_BLACKLIST"], height = 26 })
    clearBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    clearBtn:SetScript("OnClick", function()
        StaticPopupDialogs["ONEWOW_QOL_CLEAR_BAGBAR_BLACKLIST"].text = L["BAGBAR_CLEAR_BLACKLIST_CONFIRM"]
        StaticPopup_Show("ONEWOW_QOL_CLEAR_BAGBAR_BLACKLIST")
    end)
    cy = cy - 34

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
        manualItemBox:Disable()
        manualAddBtn:Disable()
        manualDrop:EnableMouse(false)
        blItemBox:Disable()
        blAddBtn:Disable()
        blDrop:EnableMouse(false)
        clearBtn:Disable()
    end

    container:SetHeight(math.abs(cy))
    return cy
end

function ns.BagBarModule:CreateCustomDetail(detailScrollChild, yOffset, _, registerRefresh)
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
