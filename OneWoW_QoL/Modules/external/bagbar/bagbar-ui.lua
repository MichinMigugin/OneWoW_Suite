-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/bagbar/bagbar-ui.lua
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

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

    local addBtn = OneWoW_GUI:CreateButton(nil, parent, ns.L["BAGBAR_ADD_BUTTON"], 60, 24)
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

    local function handleDrop(self)
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

    return yOffset - 30
end

local function MakeItemList(parent, itemTable, yOffset, onRemove)
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

local function BuildContent(container, isEnabled)
    local L = ns.L
    local s = GetSettings()
    local cy = 0

    cy = OneWoW_GUI:CreateSection(container, L["BAGBAR_SETTINGS_HEADER"], cy)

    local previewing = ns.BagBarModule:IsPreviewActive()
    local previewBtn = OneWoW_GUI:CreateButton(nil, container,
        previewing and L["BAGBAR_HIDE_BAR"] or L["BAGBAR_SHOW_BAR"],
        120, 26)
    previewBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    previewBtn:SetScript("OnClick", function()
        if ns.BagBarModule:IsPreviewActive() then
            ns.BagBarModule:HidePreview()
        else
            ns.BagBarModule:ShowPreview()
        end
        ns.BagBarModule._refreshCustomDetail()
    end)
    cy = cy - 32

    local lockBtn = OneWoW_GUI:CreateButton(nil, container,
        s.locked and (L["BAGBAR_LOCK_POSITION"] .. " (ON)") or (L["BAGBAR_LOCK_POSITION"] .. " (OFF)"),
        180, 26)
    lockBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    lockBtn:SetScript("OnClick", function()
        ns.BagBarModule:SetLocked(not GetSettings().locked)
        ns.BagBarModule._refreshCustomDetail()
    end)
    cy = cy - 32

    local usableCheck = CreateFrame("CheckButton", nil, container, "InterfaceOptionsCheckButtonTemplate")
    usableCheck:SetPoint("TOPLEFT", container, "TOPLEFT", 8, cy)
    usableCheck.Text:SetText(L["BAGBAR_SHOW_USABLE_ITEMS"])
    usableCheck.Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    usableCheck:SetChecked(s.showUsableItems)
    usableCheck:SetScript("OnClick", function(self)
        GetSettings().showUsableItems = self:GetChecked()
        ns.BagBarModule:ScheduleUpdate()
    end)
    cy = cy - 28

    local maxLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    maxLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    maxLabel:SetText(string.format("%s: %d", L["BAGBAR_MAX_BUTTONS"], s.maxButtons or 12))
    maxLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    cy = cy - maxLabel:GetStringHeight() - 4

    local maxSlider = CreateFrame("Slider", "OneWoW_QoL_BagBarMaxSlider", container, "OptionsSliderTemplate")
    maxSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    maxSlider:SetWidth(220)
    maxSlider:SetMinMaxValues(1, 12)
    maxSlider:SetValue(s.maxButtons or 12)
    maxSlider:SetValueStep(1)
    maxSlider:SetObeyStepOnDrag(true)
    _G["OneWoW_QoL_BagBarMaxSliderLow"]:SetText("1")
    _G["OneWoW_QoL_BagBarMaxSliderHigh"]:SetText("12")
    maxSlider:SetScript("OnValueChanged", function(self, value)
        local v = math.floor(value + 0.5)
        GetSettings().maxButtons = v
        maxLabel:SetText(string.format("%s: %d", L["BAGBAR_MAX_BUTTONS"], v))
        ns.BagBarModule:ScheduleUpdate()
    end)
    cy = cy - 46

    local sizeLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    sizeLabel:SetText(string.format("%s: %d", L["BAGBAR_BUTTON_SIZE"], s.buttonSize or 36))
    sizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    cy = cy - sizeLabel:GetStringHeight() - 4

    local sizeSlider = CreateFrame("Slider", "OneWoW_QoL_BagBarSizeSlider", container, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    sizeSlider:SetWidth(220)
    sizeSlider:SetMinMaxValues(24, 48)
    sizeSlider:SetValue(s.buttonSize or 36)
    sizeSlider:SetValueStep(2)
    sizeSlider:SetObeyStepOnDrag(true)
    _G["OneWoW_QoL_BagBarSizeSliderLow"]:SetText("24")
    _G["OneWoW_QoL_BagBarSizeSliderHigh"]:SetText("48")
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        local v = math.floor(value + 0.5)
        GetSettings().buttonSize = v
        sizeLabel:SetText(string.format("%s: %d", L["BAGBAR_BUTTON_SIZE"], v))
        ns.BagBarModule:ScheduleUpdate()
    end)
    cy = cy - 50

    local descText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descText:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    descText:SetPoint("TOPRIGHT", container, "TOPRIGHT", -12, cy)
    descText:SetJustifyH("LEFT")
    descText:SetWordWrap(true)
    descText:SetSpacing(2)
    descText:SetText(L["BAGBAR_MANUAL_DESC"])
    descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    cy = cy - 14

    cy = OneWoW_GUI:CreateSection(container, L["BAGBAR_MANUAL_ITEMS_HEADER"], cy)

    cy = MakeItemDropZone(container, L["BAGBAR_ITEM_ID_LABEL"], cy,
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
        end)

    cy = OneWoW_GUI:CreateSection(container, L["BAGBAR_BLACKLIST_HEADER"], cy)

    local blDesc = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    blDesc:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    blDesc:SetPoint("TOPRIGHT", container, "TOPRIGHT", -12, cy)
    blDesc:SetJustifyH("LEFT")
    blDesc:SetWordWrap(true)
    blDesc:SetSpacing(2)
    blDesc:SetText(L["BAGBAR_BLACKLIST_DESC"])
    blDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    cy = cy - blDesc:GetStringHeight() - 10

    cy = MakeItemDropZone(container, L["BAGBAR_ADD_ITEM_ID_LABEL"], cy,
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
        end)

    local clearBtn = OneWoW_GUI:CreateButton(nil, container, L["BAGBAR_CLEAR_BLACKLIST"], 160, 26)
    clearBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    clearBtn:SetScript("OnClick", function()
        local cur = GetSettings()
        wipe(cur.blacklist)
        ns.BagBarModule:ClearTempBlacklist()
        ns.BagBarModule:ScheduleUpdate()
        print("|cFF00FF00" .. L["BAGBAR_BLACKLIST_CLEARED"] .. "|r")
        ns.BagBarModule._refreshCustomDetail()
    end)
    cy = cy - 34

    container:SetHeight(math.abs(cy))
    return cy
end

function ns.BagBarModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled)
    if detailScrollChild._bagbarContainer then
        OneWoW_GUI:ClearFrame(detailScrollChild._bagbarContainer)
    end

    local container = detailScrollChild._bagbarContainer or CreateFrame("Frame", nil, detailScrollChild)
    detailScrollChild._bagbarContainer = container
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
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
