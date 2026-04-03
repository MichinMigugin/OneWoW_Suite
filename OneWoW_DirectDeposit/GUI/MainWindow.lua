local ADDON_NAME, OneWoW_DirectDeposit = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_DirectDeposit.GUI = OneWoW_DirectDeposit.GUI or {}

local GUI      = OneWoW_DirectDeposit.GUI
local Constants = OneWoW_DirectDeposit.Constants
local L        = OneWoW_DirectDeposit.L

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local MainWindow    = nil
local isInitialized = false
local currentTab    = 1
local tabPanels     = {}
local tabButtons    = {}
local isRefreshing  = false
local pendingRefresh = nil

function GUI:InitMainWindow()
    if isInitialized then return end
    if not Constants or not Constants.GUI then return end

    local C = Constants.GUI

    MainWindow = OneWoW_GUI:CreateFrame(UIParent, {
        name     = "OneWoW_DirectDepositMainWindow",
        width    = C.WINDOW_WIDTH,
        height   = C.WINDOW_HEIGHT,
        backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT,
    })
    if not MainWindow then return end

    MainWindow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    MainWindow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    if not OneWoW_GUI:RestoreWindowPosition(MainWindow, OneWoW_DirectDeposit.db.global.mainFramePosition or {}) then
        MainWindow:SetPoint("CENTER")
    end
    MainWindow:SetMovable(true)
    MainWindow:EnableMouse(true)
    MainWindow:RegisterForDrag("LeftButton")
    MainWindow:SetScript("OnDragStart", MainWindow.StartMoving)
    MainWindow:SetScript("OnDragStop",  MainWindow.StopMovingOrSizing)
    MainWindow:SetClampedToScreen(true)
    MainWindow:SetFrameStrata("MEDIUM")
    MainWindow:SetToplevel(true)
    MainWindow:SetScript("OnHide", function()
        local db = OneWoW_DirectDeposit.db.global
        db.mainFramePosition = db.mainFramePosition or {}
        OneWoW_GUI:SaveWindowPosition(MainWindow, db.mainFramePosition)
    end)
    MainWindow:Hide()

    local titleBar = OneWoW_GUI:CreateTitleBar(MainWindow, {
        title     = L["ADDON_TITLE"],
        showBrand = true,
        onClose   = function() MainWindow:Hide() end,
    })
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() MainWindow:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function() MainWindow:StopMovingOrSizing() end)
    MainWindow.titleBar = titleBar

    local content = CreateFrame("Frame", nil, MainWindow)
    content:SetPoint("TOPLEFT",     titleBar,   "BOTTOMLEFT",  OneWoW_GUI:GetSpacing("XS"), 0)
    content:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("XS"), OneWoW_GUI:GetSpacing("XS"))
    MainWindow.content = content

    GUI:CreateTabSystem(content)

    tinsert(UISpecialFrames, "OneWoW_DirectDepositMainWindow")
    isInitialized = true
end

function GUI:CreateTabSystem(parent)
    local tabContainer = CreateFrame("Frame", nil, parent)
    tabContainer:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    tabContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    tabContainer:SetHeight(35)

    local tabDefs = {
        { text = L["TAB_GOLD"],     id = 1 },
        { text = L["TAB_ITEMS"],    id = 2 },
        { text = L["TAB_SETTINGS"], id = 3 },
    }

    local prevTab = nil
    wipe(tabButtons)
    for _, def in ipairs(tabDefs) do
        local btn = OneWoW_GUI:CreateFitTextButton(tabContainer, { text = def.text, height = 26 })
        if not prevTab then
            btn:SetPoint("BOTTOMLEFT", tabContainer, "BOTTOMLEFT", 0, 0)
        else
            btn:SetPoint("LEFT", prevTab, "RIGHT", 4, 0)
        end
        btn.tabID = def.id
        btn:SetScript("OnClick", function(self) GUI:SelectTab(self.tabID) end)
        tabButtons[def.id] = btn
        prevTab = btn
    end

    local depositNowBtn = OneWoW_GUI:CreateFitTextButton(tabContainer, { text = L["DEPOSIT_NOW"], height = 26 })
    depositNowBtn:SetPoint("BOTTOMRIGHT", tabContainer, "BOTTOMRIGHT", 0, 0)
    depositNowBtn:SetScript("OnClick", function()
        OneWoW_DirectDeposit.DirectDeposit:ManualDeposit()
    end)
    MainWindow.depositNowBtn = depositNowBtn

    local pauseBtn = OneWoW_GUI:CreateFitTextButton(tabContainer, { text = L["PAUSE"], height = 26 })
    pauseBtn:SetPoint("RIGHT", depositNowBtn, "LEFT", -4, 0)
    pauseBtn:Hide()
    pauseBtn:SetScript("OnClick", function()
        OneWoW_DirectDeposit.DirectDeposit:StopDeposit()
    end)
    MainWindow.pauseBtn = pauseBtn

    local progressText = OneWoW_GUI:CreateFS(tabContainer, 10)
    progressText:SetPoint("RIGHT", pauseBtn, "LEFT", -8, 0)
    progressText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    progressText:Hide()
    MainWindow.progressText = progressText

    OneWoW_DirectDeposit.DirectDeposit:SetProgressCallback(function(current, total, itemName)
        if not current or not total then
            progressText:Hide()
            depositNowBtn:Show()
            pauseBtn:Hide()
        else
            local shortName = itemName or "..."
            if #shortName > 20 then shortName = shortName:sub(1, 17) .. "..." end
            progressText:SetText(current .. "/" .. total .. ": " .. shortName)
            progressText:Show()
            depositNowBtn:Hide()
            pauseBtn:Show()
        end
    end)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT",     tabContainer, "BOTTOMLEFT",  0, -4)
    contentArea:SetPoint("BOTTOMRIGHT", parent,       "BOTTOMRIGHT", 0, 36)
    MainWindow.contentArea = contentArea

    tabPanels[1] = GUI:CreateGoldPanel(contentArea)
    tabPanels[2] = GUI:CreateItemsPanel(contentArea)
    tabPanels[3] = GUI:CreateSettingsPanel(contentArea)

    local bottomBar = CreateFrame("Frame", nil, parent)
    bottomBar:SetHeight(36)
    bottomBar:SetPoint("BOTTOMLEFT",  parent, "BOTTOMLEFT",  0, 0)
    bottomBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local statusText = OneWoW_GUI:CreateFS(bottomBar, 12)
    statusText:SetPoint("LEFT", OneWoW_GUI:GetSpacing("MD"), 0)
    statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    MainWindow.statusText = statusText

    local clearBtn = OneWoW_GUI:CreateFitTextButton(bottomBar, { text = L["CLEAR"], height = Constants.GUI.BUTTON_HEIGHT })
    clearBtn:SetPoint("RIGHT", bottomBar, "RIGHT", -OneWoW_GUI:GetSpacing("SM"), 0)
    clearBtn:SetScript("OnClick", function()
        local dd = OneWoW_DirectDeposit.db.global.directDeposit
        local ch = OneWoW_DirectDeposit.db.char.directDeposit
        dd.targetGold       = 0
        dd.depositEnabled   = false
        dd.withdrawEnabled  = false
        dd.itemDepositEnabled = false
        ch.targetGold       = 0
        ch.depositEnabled   = false
        ch.withdrawEnabled  = false
        GUI:RefreshCurrentTab()
    end)

    GUI:SelectTab(1)
    GUI:UpdateStatusText()
end

function GUI:SelectTab(tabID)
    currentTab = tabID

    for id, btn in pairs(tabButtons) do
        if id == tabID then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end

    for i, panel in ipairs(tabPanels) do
        if i == tabID then panel:Show() else panel:Hide() end
    end

    GUI:UpdateStatusText()
end

function GUI:CreateGoldPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel.widgets = {}

    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(panel, {
        name = "OneWoW_DirectDepositGoldSettings",
    })

    local yOffset = -15

    local accountSection = OneWoW_GUI:CreateSectionHeader(scrollContent, {
        title   = L["ACCOUNT_SETTINGS"],
        yOffset = yOffset,
    })
    yOffset = accountSection.bottomY - 10

    local accountEnabled = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["DIRECT_DEPOSIT_ENABLE"] })
    accountEnabled:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 20, yOffset)
    accountEnabled:SetChecked(OneWoW_DirectDeposit.db.global.directDeposit.enabled)
    accountEnabled:SetScript("OnClick", function(self)
        OneWoW_DirectDeposit.db.global.directDeposit.enabled = self:GetChecked()
        GUI:UpdateStatusText()
    end)
    panel.accountEnabled = accountEnabled
    yOffset = yOffset - 30

    local targetGoldLabel = OneWoW_GUI:CreateFS(scrollContent, 12)
    targetGoldLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 40, yOffset)
    targetGoldLabel:SetText(L["TARGET_GOLD"] .. ":")
    targetGoldLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local targetGoldBox = OneWoW_GUI:CreateEditBox(scrollContent, { width = 100, height = 26 })
    targetGoldBox:SetPoint("LEFT", targetGoldLabel, "RIGHT", 10, 0)
    targetGoldBox:SetText(tostring(OneWoW_DirectDeposit.db.global.directDeposit.targetGold or 0))
    targetGoldBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText()) or 0
        OneWoW_DirectDeposit.db.global.directDeposit.targetGold = value
    end)
    targetGoldBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    panel.targetGoldBox = targetGoldBox

    local goldText = OneWoW_GUI:CreateFS(scrollContent, 12)
    goldText:SetPoint("LEFT", targetGoldBox, "RIGHT", 5, 0)
    goldText:SetText(L["GOLD"])
    goldText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    yOffset = yOffset - 38

    local depositCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["DEPOSIT_ENABLE"] })
    depositCheck:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 40, yOffset)
    depositCheck:SetChecked(OneWoW_DirectDeposit.db.global.directDeposit.depositEnabled)
    depositCheck:SetScript("OnClick", function(self)
        OneWoW_DirectDeposit.db.global.directDeposit.depositEnabled = self:GetChecked()
    end)
    panel.depositCheck = depositCheck
    yOffset = yOffset - 28

    local withdrawCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["WITHDRAW_ENABLE"] })
    withdrawCheck:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 40, yOffset)
    withdrawCheck:SetChecked(OneWoW_DirectDeposit.db.global.directDeposit.withdrawEnabled)
    withdrawCheck:SetScript("OnClick", function(self)
        OneWoW_DirectDeposit.db.global.directDeposit.withdrawEnabled = self:GetChecked()
    end)
    panel.withdrawCheck = withdrawCheck
    yOffset = yOffset - 48

    local charSection = OneWoW_GUI:CreateSectionHeader(scrollContent, {
        title   = L["CHARACTER_SETTINGS"],
        yOffset = yOffset,
    })
    yOffset = charSection.bottomY - 10

    local useCharSettings = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["USE_CHAR_SETTINGS"] })
    useCharSettings:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 20, yOffset)
    useCharSettings:SetChecked(not OneWoW_DirectDeposit.db.char.directDeposit.useAccountSettings)
    useCharSettings:SetScript("OnClick", function(self)
        OneWoW_DirectDeposit.db.char.directDeposit.useAccountSettings = not self:GetChecked()
        GUI:RefreshGoldPanel()
    end)
    panel.useCharSettings = useCharSettings
    yOffset = yOffset - 38

    panel.charSettingsStart = yOffset
    scrollContent.charSettingsFrames = {}

    if not OneWoW_DirectDeposit.db.char.directDeposit.useAccountSettings then
        yOffset = GUI:CreateCharacterSettings(scrollContent, yOffset, scrollContent.charSettingsFrames, panel)
    end

    scrollContent:SetHeight(math.abs(yOffset) + 40)
    panel.scrollContent = scrollContent

    return panel
end

function GUI:CreateCharacterSettings(scrollContent, yOffset, framesTable, panel)
    local charTargetGoldLabel = OneWoW_GUI:CreateFS(scrollContent, 12)
    charTargetGoldLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 40, yOffset)
    charTargetGoldLabel:SetText(L["TARGET_GOLD"] .. ":")
    charTargetGoldLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    table.insert(framesTable, charTargetGoldLabel)

    local charTargetGoldBox = OneWoW_GUI:CreateEditBox(scrollContent, { width = 100, height = 26 })
    charTargetGoldBox:SetPoint("LEFT", charTargetGoldLabel, "RIGHT", 10, 0)
    charTargetGoldBox:SetText(tostring(OneWoW_DirectDeposit.db.char.directDeposit.targetGold or 0))
    charTargetGoldBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText()) or 0
        OneWoW_DirectDeposit.db.char.directDeposit.targetGold = value
    end)
    charTargetGoldBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    table.insert(framesTable, charTargetGoldBox)
    if panel then panel.charTargetGoldBox = charTargetGoldBox end

    local charGoldText = OneWoW_GUI:CreateFS(scrollContent, 12)
    charGoldText:SetPoint("LEFT", charTargetGoldBox, "RIGHT", 5, 0)
    charGoldText:SetText(L["GOLD"])
    charGoldText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    table.insert(framesTable, charGoldText)

    yOffset = yOffset - 38

    local charDepositCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["DEPOSIT_ENABLE"] })
    charDepositCheck:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 40, yOffset)
    charDepositCheck:SetChecked(OneWoW_DirectDeposit.db.char.directDeposit.depositEnabled)
    charDepositCheck:SetScript("OnClick", function(self)
        OneWoW_DirectDeposit.db.char.directDeposit.depositEnabled = self:GetChecked()
    end)
    table.insert(framesTable, charDepositCheck)
    if panel then panel.charDepositCheck = charDepositCheck end
    yOffset = yOffset - 28

    local charWithdrawCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["WITHDRAW_ENABLE"] })
    charWithdrawCheck:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 40, yOffset)
    charWithdrawCheck:SetChecked(OneWoW_DirectDeposit.db.char.directDeposit.withdrawEnabled)
    charWithdrawCheck:SetScript("OnClick", function(self)
        OneWoW_DirectDeposit.db.char.directDeposit.withdrawEnabled = self:GetChecked()
    end)
    table.insert(framesTable, charWithdrawCheck)
    if panel then panel.charWithdrawCheck = charWithdrawCheck end
    yOffset = yOffset - 38

    return yOffset
end

function GUI:RefreshGoldPanel()
    local panel = tabPanels[1]
    if not panel or not panel.scrollContent then return end

    local scrollContent = panel.scrollContent

    if scrollContent.charSettingsFrames then
        for _, frame in ipairs(scrollContent.charSettingsFrames) do
            frame:Hide()
            frame:SetParent(nil)
        end
        scrollContent.charSettingsFrames = {}
    end

    local yOffset = panel.charSettingsStart

    if not OneWoW_DirectDeposit.db.char.directDeposit.useAccountSettings then
        yOffset = GUI:CreateCharacterSettings(scrollContent, yOffset, scrollContent.charSettingsFrames, panel)
    end

    scrollContent:SetHeight(math.abs(yOffset) + 40)
end

function GUI:CreateItemsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()

    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(panel, {
        name = "OneWoW_DirectDepositItemSettings",
    })

    local yOffset = -15

    local itemSection = OneWoW_GUI:CreateSectionHeader(scrollContent, {
        title   = L["ITEM_DEPOSIT"],
        yOffset = yOffset,
    })
    yOffset = itemSection.bottomY - 10

    local itemDepositCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["ITEM_DEPOSIT_ENABLE"] })
    itemDepositCheck:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 20, yOffset)
    itemDepositCheck:SetChecked(OneWoW_DirectDeposit.db.global.directDeposit.itemDepositEnabled)
    itemDepositCheck:SetScript("OnClick", function(self)
        OneWoW_DirectDeposit.db.global.directDeposit.itemDepositEnabled = self:GetChecked()
    end)
    panel.itemDepositCheck = itemDepositCheck
    yOffset = yOffset - 38

    local dropZoneFrame = OneWoW_GUI:CreateFrame(scrollContent, {
        backdrop     = BACKDROP_INNER_NO_INSETS,
        bgColor      = "BG_SECONDARY",
        borderColor  = "BORDER_SUBTLE",
    })
    dropZoneFrame:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  20, yOffset)
    dropZoneFrame:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -20, yOffset)
    dropZoneFrame:SetHeight(340)
    dropZoneFrame:EnableMouse(true)
    dropZoneFrame:RegisterForDrag("LeftButton")

    local function AddItemFromCursor()
        local infoType, itemID = GetCursorInfo()
        if infoType == "item" and itemID then
            local success, msg = OneWoW_DirectDeposit.DirectDeposit:AddItemToList(itemID, "personal")
            if success then
                GUI:RefreshItemList(panel)
            else
                print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF0000" .. (msg or "Failed to add item") .. "|r")
            end
            ClearCursor()
        end
    end

    dropZoneFrame:SetScript("OnReceiveDrag", AddItemFromCursor)
    dropZoneFrame:SetScript("OnMouseUp",     AddItemFromCursor)

    local dropHintText = OneWoW_GUI:CreateFS(dropZoneFrame, 10)
    dropHintText:SetPoint("TOPRIGHT", dropZoneFrame, "TOPRIGHT", -10, -8)
    dropHintText:SetText(L["ITEM_DRAG_HINT"])
    dropHintText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local addItemLabel = OneWoW_GUI:CreateFS(dropZoneFrame, 12)
    addItemLabel:SetPoint("TOPLEFT", dropZoneFrame, "TOPLEFT", 10, -10)
    addItemLabel:SetText(L["ITEM_ID_LABEL"])
    addItemLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local itemInputBox = OneWoW_GUI:CreateEditBox(dropZoneFrame, { width = 100, height = 26 })
    itemInputBox:SetPoint("LEFT", addItemLabel, "RIGHT", 10, 0)
    itemInputBox:SetNumeric(true)

    local addBtn = OneWoW_GUI:CreateFitTextButton(dropZoneFrame, { text = L["ITEM_DEPOSIT_ADD"], height = 26 })
    addBtn:SetPoint("LEFT", itemInputBox, "RIGHT", 10, 0)
    addBtn:SetScript("OnClick", function()
        local itemIDText = itemInputBox:GetText()
        if itemIDText and itemIDText ~= "" then
            local itemID = tonumber(itemIDText)
            if itemID then
                local success, msg = OneWoW_DirectDeposit.DirectDeposit:AddItemToList(itemID, "personal")
                if success then
                    itemInputBox:SetText("")
                    GUI:RefreshItemList(panel)
                else
                    print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF0000" .. (msg or "Failed to add item") .. "|r")
                end
            else
                print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF0000Invalid item ID|r")
            end
        end
        itemInputBox:ClearFocus()
    end)

    itemInputBox:SetScript("OnEnterPressed", function(self)
        addBtn:Click()
    end)

    local scrollAreaFrame = CreateFrame("Frame", nil, dropZoneFrame)
    scrollAreaFrame:SetPoint("TOPLEFT",     dropZoneFrame, "TOPLEFT",     10, -44)
    scrollAreaFrame:SetPoint("BOTTOMRIGHT", dropZoneFrame, "BOTTOMRIGHT", -10, 10)

    local itemScrollFrame, itemScrollChild = OneWoW_GUI:CreateScrollFrame(scrollAreaFrame, {
        name = "OneWoW_DirectDepositItemList",
    })
    itemScrollFrame:SetScript("OnReceiveDrag", AddItemFromCursor)
    itemScrollFrame:SetScript("OnMouseUp",     AddItemFromCursor)

    panel.itemScrollChild = itemScrollChild
    panel.itemScrollFrame = itemScrollFrame
    panel.scrollContent   = scrollContent
    panel.dropZoneFrame   = dropZoneFrame

    GUI:RefreshItemList(panel)

    yOffset = yOffset - 350
    scrollContent:SetHeight(math.abs(yOffset) + 40)

    return panel
end

function GUI:RefreshItemList(panel, preserveScrollPos)
    if not panel or not panel.itemScrollChild then return end

    if isRefreshing then
        pendingRefresh = panel
        return
    end

    isRefreshing = true
    local itemScrollChild = panel.itemScrollChild

    local savedScrollPos = 0
    if preserveScrollPos and panel.itemScrollFrame then
        local scrollBar = panel.itemScrollFrame.ScrollBar
        if scrollBar then savedScrollPos = scrollBar:GetValue() end
    end

    local itemList = OneWoW_DirectDeposit.DirectDeposit:GetItemList()
    local sortedItems = {}
    for itemID, itemData in pairs(itemList) do
        C_Item.RequestLoadItemDataByID(tonumber(itemID))
        table.insert(sortedItems, { id = tonumber(itemID), data = itemData })
    end
    table.sort(sortedItems, function(a, b) return (a.data.addedTime or 0) < (b.data.addedTime or 0) end)

    C_Timer.After(0.1, function()
        for i = 1, itemScrollChild:GetNumChildren() do
            local child = select(i, itemScrollChild:GetChildren())
            if child then
                child:Hide()
                child:SetParent(nil)
            end
        end

        local scrollWidth = panel.dropZoneFrame:GetWidth() - 40
        itemScrollChild:SetWidth(scrollWidth)

        local yOffset = 0

        for _, item in ipairs(sortedItems) do
            local itemRow = OneWoW_GUI:CreateFrame(itemScrollChild, {
                backdrop    = BACKDROP_INNER_NO_INSETS,
                bgColor     = "BG_TERTIARY",
                borderColor = "BORDER_SUBTLE",
            })
            itemRow:SetPoint("TOPLEFT",  itemScrollChild, "TOPLEFT",  5, yOffset)
            itemRow:SetPoint("TOPRIGHT", itemScrollChild, "TOPRIGHT", -5, yOffset)
            itemRow:SetHeight(32)

            local removeBtn = OneWoW_GUI:CreateButton(itemRow, { text = "X", width = 22, height = 22 })
            removeBtn:SetPoint("LEFT", itemRow, "LEFT", 5, 0)
            removeBtn:SetScript("OnClick", function()
                itemRow:Hide()
                OneWoW_DirectDeposit.DirectDeposit:RemoveItemFromList(item.id)
                GUI:RefreshItemList(panel)
            end)

            local itemNameFrame = CreateFrame("Frame", nil, itemRow)
            itemNameFrame:SetPoint("LEFT",  removeBtn, "RIGHT",  5, 0)
            itemNameFrame:SetPoint("RIGHT", itemRow,   "RIGHT", -280, 0)
            itemNameFrame:SetHeight(32)
            itemNameFrame:EnableMouse(true)
            itemNameFrame:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(item.id)
                GameTooltip:Show()
            end)
            itemNameFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

            local itemNameText = OneWoW_GUI:CreateFS(itemNameFrame, 12)
            itemNameText:SetPoint("LEFT",  itemNameFrame, "LEFT",  0, 0)
            itemNameText:SetPoint("RIGHT", itemNameFrame, "RIGHT", 0, 0)
            itemNameText:SetText(item.data.itemName or ("Item " .. item.id))
            itemNameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            itemNameText:SetJustifyH("LEFT")
            itemNameText:SetWordWrap(false)

            local bindingInfo = item.data.bindingInfo
            if not bindingInfo then
                bindingInfo = OneWoW_DirectDeposit.DirectDeposit:GetItemBindingInfo(item.id)
            end

            local canWarband = bindingInfo == nil or bindingInfo.canUseWarband ~= false
            local canPersonal = bindingInfo == nil or bindingInfo.canUsePersonal ~= false
            local canGuild    = bindingInfo == nil or bindingInfo.canUseGuild ~= false

            local warbandRadio = CreateFrame("CheckButton", nil, itemRow, "UIRadioButtonTemplate")
            warbandRadio:SetPoint("RIGHT", itemRow, "RIGHT", -230, 0)
            warbandRadio:SetChecked(item.data.bankType == "warband")
            warbandRadio:SetEnabled(canWarband)

            local warbandLabel = OneWoW_GUI:CreateFS(itemRow, 10)
            warbandLabel:SetPoint("LEFT", warbandRadio, "RIGHT", 3, 0)
            warbandLabel:SetText(L["ITEM_DEPOSIT_WARBAND"])
            if canWarband then
                warbandLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                warbandLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end

            local personalRadio = CreateFrame("CheckButton", nil, itemRow, "UIRadioButtonTemplate")
            personalRadio:SetPoint("RIGHT", itemRow, "RIGHT", -135, 0)
            personalRadio:SetChecked(item.data.bankType == "personal")
            personalRadio:SetEnabled(canPersonal)

            local personalLabel = OneWoW_GUI:CreateFS(itemRow, 10)
            personalLabel:SetPoint("LEFT", personalRadio, "RIGHT", 3, 0)
            personalLabel:SetText(L["ITEM_DEPOSIT_PERSONAL"])
            if canPersonal then
                personalLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                personalLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end

            local guildRadio = CreateFrame("CheckButton", nil, itemRow, "UIRadioButtonTemplate")
            guildRadio:SetPoint("RIGHT", itemRow, "RIGHT", -55, 0)
            guildRadio:SetChecked(item.data.bankType == "guild")
            guildRadio:SetEnabled(canGuild)

            local guildLabel = OneWoW_GUI:CreateFS(itemRow, 10)
            guildLabel:SetPoint("LEFT", guildRadio, "RIGHT", 3, 0)
            guildLabel:SetText(L["ITEM_DEPOSIT_GUILD"])
            if canGuild then
                guildLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
            else
                guildLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end

            warbandRadio:SetScript("OnClick", function()
                if canWarband then
                    warbandRadio:SetChecked(true)
                    personalRadio:SetChecked(false)
                    guildRadio:SetChecked(false)
                    OneWoW_DirectDeposit.DirectDeposit:UpdateItemBankType(item.id, "warband")
                    GUI:RefreshItemList(panel, true)
                else
                    warbandRadio:SetChecked(false)
                end
            end)

            personalRadio:SetScript("OnClick", function()
                if canPersonal then
                    personalRadio:SetChecked(true)
                    warbandRadio:SetChecked(false)
                    guildRadio:SetChecked(false)
                    OneWoW_DirectDeposit.DirectDeposit:UpdateItemBankType(item.id, "personal")
                    GUI:RefreshItemList(panel, true)
                else
                    personalRadio:SetChecked(false)
                end
            end)

            guildRadio:SetScript("OnClick", function()
                if canGuild then
                    guildRadio:SetChecked(true)
                    warbandRadio:SetChecked(false)
                    personalRadio:SetChecked(false)
                    OneWoW_DirectDeposit.DirectDeposit:UpdateItemBankType(item.id, "guild")
                    GUI:RefreshItemList(panel, true)
                else
                    guildRadio:SetChecked(false)
                end
            end)

            itemRow:Show()
            yOffset = yOffset - 35
        end

        if #sortedItems == 0 then
            local noItemsText = OneWoW_GUI:CreateFS(itemScrollChild, 10)
            noItemsText:SetPoint("TOP", itemScrollChild, "TOP", 0, -10)
            noItemsText:SetText(L["ITEM_EMPTY_LIST"])
            noItemsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            noItemsText:SetJustifyH("CENTER")
            yOffset = yOffset - 40
        end

        itemScrollChild:SetHeight(math.max(math.abs(yOffset) + 10, 1))

        if preserveScrollPos and panel.itemScrollFrame and savedScrollPos > 0 then
            C_Timer.After(0.05, function()
                local scrollBar = panel.itemScrollFrame.ScrollBar
                if scrollBar then scrollBar:SetValue(savedScrollPos) end
            end)
        end

        isRefreshing = false

        if pendingRefresh then
            local nextPanel = pendingRefresh
            pendingRefresh = nil
            GUI:RefreshItemList(nextPanel, true)
        end
    end)
end

function GUI:CreateSettingsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()

    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(panel, {
        name = "OneWoW_DirectDepositSettings",
    })

    local yOffset = OneWoW_GUI:CreateSettingsPanel(scrollContent, { yOffset = -15, addonName = "OneWoW_DirectDeposit" })

    yOffset = yOffset - 10

    local aboutSection = OneWoW_GUI:CreateSectionHeader(scrollContent, {
        title   = L["ABOUT_SECTION"],
        yOffset = yOffset,
    })
    yOffset = aboutSection.bottomY - 10

    local aboutContainer = OneWoW_GUI:CreateFrame(scrollContent, {
        backdrop    = BACKDROP_INNER_NO_INSETS,
        bgColor     = "BG_TERTIARY",
        borderColor = "BORDER_SUBTLE",
    })
    aboutContainer:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  20, yOffset)
    aboutContainer:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -20, yOffset)
    aboutContainer:SetHeight(120)

    local aboutText = OneWoW_GUI:CreateFS(aboutContainer, 12)
    aboutText:SetPoint("TOPLEFT",  aboutContainer, "TOPLEFT",  15, -15)
    aboutText:SetPoint("TOPRIGHT", aboutContainer, "TOPRIGHT", -15, -15)
    aboutText:SetJustifyH("LEFT")
    aboutText:SetWordWrap(true)
    aboutText:SetText(L["ABOUT_TEXT"])
    aboutText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    aboutText:SetSpacing(3)

    C_Timer.After(0.01, function()
        aboutContainer:SetHeight(aboutText:GetStringHeight() + 35)
    end)

    yOffset = yOffset - 140

    local linksSection = OneWoW_GUI:CreateSectionHeader(scrollContent, {
        title   = L["LINKS_SECTION"],
        yOffset = yOffset,
    })
    yOffset = linksSection.bottomY - 10

    local function CreateLinkBox(parent, labelKey, urlKey, yOff)
        local container = OneWoW_GUI:CreateFrame(parent, {
            backdrop    = BACKDROP_INNER_NO_INSETS,
            bgColor     = "BG_TERTIARY",
            borderColor = "BORDER_SUBTLE",
        })
        container:SetPoint("TOPLEFT",  parent, "TOPLEFT",  20, yOff)
        container:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOff)
        container:SetHeight(85)

        local lbl = OneWoW_GUI:CreateFS(container, 12)
        lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 15, -10)
        lbl:SetText(L[labelKey])
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local box = OneWoW_GUI:CreateEditBox(container, { height = 26 })
        box:SetPoint("TOPLEFT",  container, "TOPLEFT",  15, -33)
        box:SetPoint("TOPRIGHT", container, "TOPRIGHT", -15, -33)
        box:SetText(L[urlKey])
        box:SetAutoFocus(false)
        box:SetScript("OnEditFocusGained", function(self)
            self:HighlightText()
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        end)
        box:SetScript("OnEditFocusLost", function(self)
            self:HighlightText(0, 0)
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end)
        box:SetScript("OnMouseDown", function(self)
            self:SetFocus()
            self:HighlightText()
        end)

        local hint = OneWoW_GUI:CreateFS(container, 10)
        hint:SetPoint("TOPLEFT", container, "TOPLEFT", 15, -66)
        hint:SetText(L["COPY_HINT"])
        hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        return container
    end

    CreateLinkBox(scrollContent, "DISCORD_LABEL", "DISCORD_URL", yOffset)
    yOffset = yOffset - 95

    CreateLinkBox(scrollContent, "WEBSITE_LABEL", "WEBSITE_URL", yOffset)
    yOffset = yOffset - 95

    scrollContent:SetHeight(math.abs(yOffset) + 40)
    panel.scrollContent = scrollContent

    return panel
end

function GUI:RefreshCurrentTab()
    if currentTab == 1 then
        GUI:RefreshGoldPanel()
    elseif currentTab == 2 then
        GUI:RefreshItemList(tabPanels[2])
    end
    GUI:UpdateStatusText()
end

function GUI:UpdateStatusText()
    if not MainWindow or not MainWindow.statusText then return end
    local status = OneWoW_DirectDeposit.db.global.directDeposit.enabled and L["ENABLED"] or L["DISABLED"]
    MainWindow.statusText:SetText(L["STATUS"] .. ": " .. status)
end

function GUI:Show()
    if not isInitialized then
        local success, err = pcall(function() GUI:InitMainWindow() end)
        if not success then
            print("|cffff0000Direct Deposit ERROR:|r " .. tostring(err))
            return
        end
    end
    if not MainWindow then return end
    MainWindow:Show()
end

function GUI:Hide()
    if MainWindow then MainWindow:Hide() end
end

function GUI:Toggle()
    if MainWindow and MainWindow:IsShown() then
        GUI:Hide()
    else
        GUI:Show()
    end
end

function GUI:GetMainWindow()
    return MainWindow
end

function GUI:FullReset()
    if MainWindow then
        MainWindow:Hide()
        MainWindow:SetParent(nil)
    end
    MainWindow     = nil
    isInitialized  = false
    currentTab     = 1
    tabPanels      = {}
    tabButtons     = {}
    isRefreshing   = false
    pendingRefresh = nil
end
