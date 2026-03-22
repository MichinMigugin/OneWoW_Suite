local ADDON_NAME, OneWoW_DirectDeposit = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_DirectDeposit.GUI = OneWoW_DirectDeposit.GUI or {}

local GUI = OneWoW_DirectDeposit.GUI
local Constants = OneWoW_DirectDeposit.Constants
local L = OneWoW_DirectDeposit.L

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local DEFAULT_THEME_ICON = OneWoW_GUI.Constants.DEFAULT_THEME_ICON

local backdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

StaticPopupDialogs["DIRECTDEPOSIT_RELOAD_THEME"] = {
    text = "Theme changed. Reload UI to apply changes?",
    button1 = "Reload",
    button2 = "Cancel",
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["DIRECTDEPOSIT_IMPORT_SUCCESS"] = {
    text = "Import successful! %s items imported from WoWNotes.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["DIRECTDEPOSIT_IMPORT_FAILED"] = {
    text = "Import failed: %s",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local MainWindow = nil
local isInitialized = false
local currentTab = 1
local tabPanels = {}
local isRefreshing = false
local pendingRefresh = nil

function GUI:InitMainWindow()
    if isInitialized then return end

    if not Constants or not Constants.GUI then return end

    local C = Constants.GUI

    MainWindow = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_DirectDepositMainWindow",
        width = C.WINDOW_WIDTH,
        height = C.WINDOW_HEIGHT,
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
    MainWindow:SetScript("OnDragStop", MainWindow.StopMovingOrSizing)
    MainWindow:SetClampedToScreen(true)
    MainWindow:SetFrameStrata("MEDIUM")
    MainWindow:SetToplevel(true)
    MainWindow:SetScript("OnHide", function()
        local db = OneWoW_DirectDeposit.db.global
        db.mainFramePosition = db.mainFramePosition or {}
        OneWoW_GUI:SaveWindowPosition(MainWindow, db.mainFramePosition)
    end)
    MainWindow:Hide()

    local titleBar = CreateFrame("Frame", nil, MainWindow, "BackdropTemplate")
    titleBar:SetHeight(20)
    titleBar:SetPoint("TOPLEFT",  MainWindow, "TOPLEFT",  OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))
    titleBar:SetPoint("TOPRIGHT", MainWindow, "TOPRIGHT", -OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))
    titleBar:SetBackdrop(BACKDROP_SIMPLE)
    titleBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("TITLEBAR_BG"))
    titleBar:SetFrameLevel(MainWindow:GetFrameLevel() + 1)

    local brandIcon = titleBar:CreateTexture(nil, "OVERLAY")
    brandIcon:SetSize(14, 14)
    brandIcon:SetPoint("LEFT", titleBar, "LEFT", OneWoW_GUI:GetSpacing("SM"), 0)
    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or DEFAULT_THEME_ICON
    brandIcon:SetTexture(OneWoW_GUI:GetBrandIcon(factionTheme))
    MainWindow.brandIcon = brandIcon

    local brandText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    brandText:SetPoint("LEFT", brandIcon, "RIGHT", 4, 0)
    brandText:SetText("OneWoW")
    brandText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    titleText:SetText(L["ADDON_TITLE"])
    titleText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local closeBtn = OneWoW_GUI:CreateButton(titleBar, { text = "X", width = 20, height = 20 })
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -OneWoW_GUI:GetSpacing("XS") / 2, 0)
    closeBtn:SetScript("OnClick", function() MainWindow:Hide() end)

    local content = CreateFrame("Frame", nil, MainWindow)
    content:SetPoint("TOPLEFT",     MainWindow, "TOPLEFT",     OneWoW_GUI:GetSpacing("XS"), -(OneWoW_GUI:GetSpacing("XS") + 20 + OneWoW_GUI:GetSpacing("XS")))
    content:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("XS"), OneWoW_GUI:GetSpacing("XS"))
    MainWindow.content = content

    GUI:CreateTabSystem(content)

    tinsert(UISpecialFrames, "OneWoW_DirectDepositMainWindow")
    isInitialized = true
end

function GUI:CreateWoWNotesDetectedPanel(parent)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetAllPoints()

    local warningFrame = OneWoW_GUI:CreateFrame(panel, {
        width = 500,
        height = 200,
        backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT,
    })
    warningFrame:SetPoint("CENTER", 0, 50)
    warningFrame:SetBackdropColor(0.15, 0.05, 0.05, 0.95)
    warningFrame:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)

    local icon = warningFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(48, 48)
    icon:SetPoint("TOP", 0, -20)
    icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")

    local titleText = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    titleText:SetPoint("TOP", icon, "BOTTOM", 0, -15)
    titleText:SetText(L["WOWNOTES_DETECTED_TITLE"])
    titleText:SetTextColor(1, 0.8, 0)

    local messageText = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    messageText:SetPoint("TOP", titleText, "BOTTOM", 0, -15)
    messageText:SetPoint("LEFT", warningFrame, "LEFT", 20, 0)
    messageText:SetPoint("RIGHT", warningFrame, "RIGHT", -20, 0)
    messageText:SetJustifyH("CENTER")
    messageText:SetWordWrap(true)
    messageText:SetText(L["WOWNOTES_DETECTED_MESSAGE"])
    messageText:SetTextColor(0.9, 0.9, 0.9)
    messageText:SetSpacing(2)

    local okBtn = OneWoW_GUI:CreateButton(warningFrame, { text = L["OK"], width = 120, height = 30 })
    okBtn:SetPoint("BOTTOM", 0, 15)
    okBtn:SetScript("OnClick", function() MainWindow:Hide() end)
end

function GUI:CreateTabSystem(parent)
    local tabContainer = CreateFrame("Frame", nil, parent)
    tabContainer:SetPoint("TOPLEFT", OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))
    tabContainer:SetPoint("TOPRIGHT", -OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))
    tabContainer:SetHeight(35)

    MainWindow.tabs = {}

    local tab1 = GUI:CreateTabButton(tabContainer, L["TAB_GOLD"], 1)
    tab1:SetPoint("BOTTOMLEFT", tabContainer, "BOTTOMLEFT", 5, 0)

    local tab2 = GUI:CreateTabButton(tabContainer, L["TAB_ITEMS"], 2)
    tab2:SetPoint("LEFT", tab1, "RIGHT", 5, 0)

    local tab3 = GUI:CreateTabButton(tabContainer, L["TAB_SETTINGS"], 3)
    tab3:SetPoint("LEFT", tab2, "RIGHT", 5, 0)

    table.insert(MainWindow.tabs, tab1)
    table.insert(MainWindow.tabs, tab2)
    table.insert(MainWindow.tabs, tab3)

    local depositNowBtn = OneWoW_GUI:CreateButton(tabContainer, { text = "Deposit Now", width = 120, height = 30 })
    depositNowBtn:SetPoint("BOTTOMRIGHT", tabContainer, "BOTTOMRIGHT", -5, 0)
    depositNowBtn:SetScript("OnClick", function()
        OneWoW_DirectDeposit.DirectDeposit:ManualDeposit()
    end)
    MainWindow.depositNowBtn = depositNowBtn

    local pauseBtn = OneWoW_GUI:CreateButton(tabContainer, { text = "Pause", width = 80, height = 30 })
    pauseBtn:SetPoint("RIGHT", depositNowBtn, "LEFT", -5, 0)
    pauseBtn:Hide()
    pauseBtn:SetScript("OnClick", function()
        OneWoW_DirectDeposit.DirectDeposit:StopDeposit()
    end)
    MainWindow.pauseBtn = pauseBtn

    local progressText = tabContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progressText:SetPoint("RIGHT", depositNowBtn, "LEFT", -10, 0)
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
            if #shortName > 20 then
                shortName = shortName:sub(1, 17) .. "..."
            end
            progressText:SetText("Depositing " .. current .. " of " .. total .. ": " .. shortName)
            progressText:Show()
            depositNowBtn:Hide()
            pauseBtn:Show()
        end
    end)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", tabContainer, "BOTTOMLEFT", 0, -5)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 40)
    MainWindow.contentArea = contentArea

    tabPanels[1] = GUI:CreateGoldPanel(contentArea)
    tabPanels[2] = GUI:CreateItemsPanel(contentArea)
    tabPanels[3] = GUI:CreateSettingsPanel(contentArea)

    local bottomBar = CreateFrame("Frame", nil, parent)
    bottomBar:SetHeight(40)
    bottomBar:SetPoint("BOTTOMLEFT", 0, 0)
    bottomBar:SetPoint("BOTTOMRIGHT", 0, 0)

    local statusText = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("LEFT", OneWoW_GUI:GetSpacing("LG"), 0)
    statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    MainWindow.statusText = statusText

    local clearBtn = OneWoW_GUI:CreateButton(bottomBar, { text = L["CLEAR"], width = 100, height = Constants.GUI.BUTTON_HEIGHT })
    clearBtn:SetPoint("RIGHT", -OneWoW_GUI:GetSpacing("SM"), 0)
    clearBtn:SetScript("OnClick", function()
        OneWoW_DirectDeposit.db.global.directDeposit.targetGold = 0
        OneWoW_DirectDeposit.db.global.directDeposit.depositEnabled = false
        OneWoW_DirectDeposit.db.global.directDeposit.withdrawEnabled = false
        OneWoW_DirectDeposit.db.global.directDeposit.itemDepositEnabled = false
        OneWoW_DirectDeposit.db.char.directDeposit.targetGold = 0
        OneWoW_DirectDeposit.db.char.directDeposit.depositEnabled = false
        OneWoW_DirectDeposit.db.char.directDeposit.withdrawEnabled = false
        GUI:RefreshCurrentTab()
    end)

    GUI:SelectTab(1)
    GUI:UpdateStatusText()
end

function GUI:CreateTabButton(parent, text, tabID)
    local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
    tab:SetSize(100, 30)
    tab:SetBackdrop(BACKDROP_INNER_NO_INSETS)

    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.text:SetPoint("CENTER")
    tab.text:SetText(text)

    tab.tabID = tabID

    tab:SetScript("OnClick", function(self)
        GUI:SelectTab(self.tabID)
    end)

    tab:SetScript("OnEnter", function(self)
        if currentTab ~= self.tabID then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        end
    end)

    tab:SetScript("OnLeave", function(self)
        if currentTab ~= self.tabID then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        end
    end)

    return tab
end

function GUI:SelectTab(tabID)
    currentTab = tabID

    for i, tab in ipairs(MainWindow.tabs) do
        if i == tabID then
            tab:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            tab:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            tab.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            tab:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            tab:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            tab.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end

    for i, panel in ipairs(tabPanels) do
        if i == tabID then
            panel:Show()
        else
            panel:Hide()
        end
    end

    GUI:UpdateStatusText()
end

function GUI:CreateGoldPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel.widgets = {}

    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(panel, {
        name = "OneWoW_DirectDepositGoldSettings",
        width = Constants.GUI.WINDOW_WIDTH - 20,
        height = Constants.GUI.WINDOW_HEIGHT - 135,
    })

    local yOffset = -15

    local accountSection = GUI:CreateSettingsSection(scrollContent, L["ACCOUNT_SETTINGS"], yOffset)
    yOffset = accountSection.bottomY - 15

    local accountEnabled = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["DIRECT_DEPOSIT_ENABLE"] })
    accountEnabled:SetPoint("TOPLEFT", 20, yOffset)
    accountEnabled:SetChecked(OneWoW_DirectDeposit.db.global.directDeposit.enabled)
    accountEnabled:SetScript("OnClick", function(self)
        OneWoW_DirectDeposit.db.global.directDeposit.enabled = self:GetChecked()
        GUI:UpdateStatusText()
    end)
    panel.accountEnabled = accountEnabled
    yOffset = yOffset - 30

    local targetGoldLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetGoldLabel:SetPoint("TOPLEFT", 40, yOffset)
    targetGoldLabel:SetText(L["TARGET_GOLD"] .. ":")
    targetGoldLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local targetGoldBox = OneWoW_GUI:CreateEditBox(scrollContent, { width = 100, height = 28 })
    targetGoldBox:SetPoint("LEFT", targetGoldLabel, "RIGHT", 10, 0)
    targetGoldBox:SetText(tostring(OneWoW_DirectDeposit.db.global.directDeposit.targetGold or 0))
    targetGoldBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText()) or 0
        OneWoW_DirectDeposit.db.global.directDeposit.targetGold = value
    end)
    targetGoldBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    panel.targetGoldBox = targetGoldBox

    local goldText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    goldText:SetPoint("LEFT", targetGoldBox, "RIGHT", 5, 0)
    goldText:SetText(L["GOLD"])
    goldText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    yOffset = yOffset - 40

    local depositCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["DEPOSIT_ENABLE"] })
    depositCheck:SetPoint("TOPLEFT", 40, yOffset)
    depositCheck:SetChecked(OneWoW_DirectDeposit.db.global.directDeposit.depositEnabled)
    depositCheck:SetScript("OnClick", function(self)
        OneWoW_DirectDeposit.db.global.directDeposit.depositEnabled = self:GetChecked()
    end)
    panel.depositCheck = depositCheck
    yOffset = yOffset - 30

    local withdrawCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["WITHDRAW_ENABLE"] })
    withdrawCheck:SetPoint("TOPLEFT", 40, yOffset)
    withdrawCheck:SetChecked(OneWoW_DirectDeposit.db.global.directDeposit.withdrawEnabled)
    withdrawCheck:SetScript("OnClick", function(self)
        OneWoW_DirectDeposit.db.global.directDeposit.withdrawEnabled = self:GetChecked()
    end)
    panel.withdrawCheck = withdrawCheck
    yOffset = yOffset - 50

    local charSection = GUI:CreateSettingsSection(scrollContent, L["CHARACTER_SETTINGS"], yOffset)
    yOffset = charSection.bottomY - 15

    local useCharSettings = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["USE_CHAR_SETTINGS"] })
    useCharSettings:SetPoint("TOPLEFT", 20, yOffset)
    useCharSettings:SetChecked(not OneWoW_DirectDeposit.db.char.directDeposit.useAccountSettings)
    useCharSettings:SetScript("OnClick", function(self)
        OneWoW_DirectDeposit.db.char.directDeposit.useAccountSettings = not self:GetChecked()
        GUI:RefreshGoldPanel()
    end)
    panel.useCharSettings = useCharSettings
    yOffset = yOffset - 40

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
    local charTargetGoldLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    charTargetGoldLabel:SetPoint("TOPLEFT", 40, yOffset)
    charTargetGoldLabel:SetText(L["TARGET_GOLD"] .. ":")
    charTargetGoldLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    table.insert(framesTable, charTargetGoldLabel)

    local charTargetGoldBox = OneWoW_GUI:CreateEditBox(scrollContent, { width = 100, height = 28 })
    charTargetGoldBox:SetPoint("LEFT", charTargetGoldLabel, "RIGHT", 10, 0)
    charTargetGoldBox:SetText(tostring(OneWoW_DirectDeposit.db.char.directDeposit.targetGold or 0))
    charTargetGoldBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText()) or 0
        OneWoW_DirectDeposit.db.char.directDeposit.targetGold = value
    end)
    charTargetGoldBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    table.insert(framesTable, charTargetGoldBox)
    if panel then panel.charTargetGoldBox = charTargetGoldBox end

    local charGoldText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    charGoldText:SetPoint("LEFT", charTargetGoldBox, "RIGHT", 5, 0)
    charGoldText:SetText(L["GOLD"])
    charGoldText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    table.insert(framesTable, charGoldText)

    yOffset = yOffset - 40

    local charDepositCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["DEPOSIT_ENABLE"] })
    charDepositCheck:SetPoint("TOPLEFT", 40, yOffset)
    charDepositCheck:SetChecked(OneWoW_DirectDeposit.db.char.directDeposit.depositEnabled)
    charDepositCheck:SetScript("OnClick", function(self)
        OneWoW_DirectDeposit.db.char.directDeposit.depositEnabled = self:GetChecked()
    end)
    table.insert(framesTable, charDepositCheck)
    if panel then panel.charDepositCheck = charDepositCheck end
    yOffset = yOffset - 30

    local charWithdrawCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["WITHDRAW_ENABLE"] })
    charWithdrawCheck:SetPoint("TOPLEFT", 40, yOffset)
    charWithdrawCheck:SetChecked(OneWoW_DirectDeposit.db.char.directDeposit.withdrawEnabled)
    charWithdrawCheck:SetScript("OnClick", function(self)
        OneWoW_DirectDeposit.db.char.directDeposit.withdrawEnabled = self:GetChecked()
    end)
    table.insert(framesTable, charWithdrawCheck)
    if panel then panel.charWithdrawCheck = charWithdrawCheck end
    yOffset = yOffset - 40

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
        width = Constants.GUI.WINDOW_WIDTH - 20,
        height = Constants.GUI.WINDOW_HEIGHT - 135,
    })

    local yOffset = -15

    local itemSection = GUI:CreateSettingsSection(scrollContent, L["ITEM_DEPOSIT"], yOffset)
    yOffset = itemSection.bottomY - 15

    local itemDepositCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["ITEM_DEPOSIT_ENABLE"] })
    itemDepositCheck:SetPoint("TOPLEFT", 20, yOffset)
    itemDepositCheck:SetChecked(OneWoW_DirectDeposit.db.global.directDeposit.itemDepositEnabled)
    itemDepositCheck:SetScript("OnClick", function(self)
        OneWoW_DirectDeposit.db.global.directDeposit.itemDepositEnabled = self:GetChecked()
    end)
    panel.itemDepositCheck = itemDepositCheck
    yOffset = yOffset - 40

    local dropZoneFrame = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    dropZoneFrame:SetPoint("TOPLEFT", 20, yOffset)
    dropZoneFrame:SetPoint("TOPRIGHT", -20, yOffset)
    dropZoneFrame:SetHeight(340)
    dropZoneFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    dropZoneFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    dropZoneFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    dropZoneFrame:EnableMouse(true)
    dropZoneFrame:RegisterForDrag("LeftButton")

    dropZoneFrame:SetScript("OnReceiveDrag", function(self)
        local infoType, itemID = GetCursorInfo()
        if infoType == "item" and itemID then
            local success, msg = OneWoW_DirectDeposit.DirectDeposit:AddItemToList(itemID, "personal")
            if success then
                GUI:RefreshItemList(panel)
            else
                print("|cFFFFD100Direct Deposit:|r |cFFFF0000" .. (msg or "Failed to add item") .. "|r")
            end
            ClearCursor()
        end
    end)

    dropZoneFrame:SetScript("OnMouseUp", function(self)
        local infoType, itemID = GetCursorInfo()
        if infoType == "item" and itemID then
            local success, msg = OneWoW_DirectDeposit.DirectDeposit:AddItemToList(itemID, "personal")
            if success then
                GUI:RefreshItemList(panel)
            else
                print("|cFFFFD100Direct Deposit:|r |cFFFF0000" .. (msg or "Failed to add item") .. "|r")
            end
            ClearCursor()
        end
    end)

    local dropHintText = dropZoneFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropHintText:SetPoint("TOPRIGHT", dropZoneFrame, "TOPRIGHT", -10, -8)
    dropHintText:SetText("|cFF808080Drag items here to add|r")
    dropHintText:SetTextColor(0.5, 0.5, 0.5)

    local addItemLabel = dropZoneFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addItemLabel:SetPoint("TOPLEFT", dropZoneFrame, "TOPLEFT", 10, -10)
    addItemLabel:SetText("Item ID:")
    addItemLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local itemInputBox = OneWoW_GUI:CreateEditBox(dropZoneFrame, { width = 100, height = 28 })
    itemInputBox:SetPoint("LEFT", addItemLabel, "RIGHT", 10, 0)
    itemInputBox:SetNumeric(true)

    itemInputBox:SetScript("OnEnterPressed", function(self)
        local itemIDText = self:GetText()
        if itemIDText and itemIDText ~= "" then
            local itemID = tonumber(itemIDText)
            if itemID then
                local success, msg = OneWoW_DirectDeposit.DirectDeposit:AddItemToList(itemID, "personal")
                if success then
                    self:SetText("")
                    GUI:RefreshItemList(panel)
                else
                    print("|cFFFFD100Direct Deposit:|r |cFFFF0000" .. (msg or "Failed to add item") .. "|r")
                end
            else
                print("|cFFFFD100Direct Deposit:|r |cFFFF0000Invalid item ID|r")
            end
        end
        self:ClearFocus()
    end)

    local addBtn = OneWoW_GUI:CreateButton(dropZoneFrame, { text = L["ITEM_DEPOSIT_ADD"], width = 80, height = 28 })
    addBtn:SetPoint("LEFT", itemInputBox, "RIGHT", 10, 0)
    addBtn:SetScript("OnClick", function()
        itemInputBox:GetScript("OnEnterPressed")(itemInputBox)
    end)

    local itemScrollFrame = CreateFrame("ScrollFrame", nil, dropZoneFrame, "UIPanelScrollFrameTemplate")
    itemScrollFrame:SetPoint("TOPLEFT", dropZoneFrame, "TOPLEFT", 10, -45)
    itemScrollFrame:SetPoint("BOTTOMRIGHT", dropZoneFrame, "BOTTOMRIGHT", -30, 10)
    itemScrollFrame:EnableMouse(true)
    itemScrollFrame:RegisterForDrag("LeftButton")

    itemScrollFrame:SetScript("OnReceiveDrag", function(self)
        local infoType, itemID = GetCursorInfo()
        if infoType == "item" and itemID then
            local success, msg = OneWoW_DirectDeposit.DirectDeposit:AddItemToList(itemID, "personal")
            if success then
                GUI:RefreshItemList(panel)
            else
                print("|cFFFFD100Direct Deposit:|r |cFFFF0000" .. (msg or "Failed to add item") .. "|r")
            end
            ClearCursor()
        end
    end)

    itemScrollFrame:SetScript("OnMouseUp", function(self)
        local infoType, itemID = GetCursorInfo()
        if infoType == "item" and itemID then
            local success, msg = OneWoW_DirectDeposit.DirectDeposit:AddItemToList(itemID, "personal")
            if success then
                GUI:RefreshItemList(panel)
            else
                print("|cFFFFD100Direct Deposit:|r |cFFFF0000" .. (msg or "Failed to add item") .. "|r")
            end
            ClearCursor()
        end
    end)

    local itemScrollChild = CreateFrame("Frame", nil, itemScrollFrame)
    itemScrollChild:SetSize(1, 1)
    itemScrollFrame:SetScrollChild(itemScrollChild)
    panel.itemScrollChild = itemScrollChild
    panel.itemScrollFrame = itemScrollFrame

    panel.scrollContent = scrollContent
    panel.dropZoneFrame = dropZoneFrame

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
        if scrollBar then
            savedScrollPos = scrollBar:GetValue()
        end
    end

    local itemList = OneWoW_DirectDeposit.DirectDeposit:GetItemList()
    local sortedItems = {}
    for itemID, itemData in pairs(itemList) do
        C_Item.RequestLoadItemDataByID(tonumber(itemID))
        table.insert(sortedItems, {id = tonumber(itemID), data = itemData})
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
        local itemRow = CreateFrame("Frame", nil, itemScrollChild, "BackdropTemplate")
        itemRow:SetPoint("TOPLEFT", itemScrollChild, "TOPLEFT", 5, yOffset)
        itemRow:SetPoint("TOPRIGHT", itemScrollChild, "TOPRIGHT", -5, yOffset)
        itemRow:SetHeight(32)
        itemRow:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        itemRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        itemRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local removeBtn = OneWoW_GUI:CreateButton(itemRow, { text = "X", width = 22, height = 22 })
        removeBtn:SetPoint("LEFT", itemRow, "LEFT", 5, 0)
        removeBtn:SetScript("OnClick", function()
            print("|cFFFFD100DirectDeposit:|r Delete button clicked for item ID: " .. tostring(item.id))
            itemRow:Hide()
            OneWoW_DirectDeposit.DirectDeposit:RemoveItemFromList(item.id)
            GUI:RefreshItemList(panel)
        end)

        local itemNameFrame = CreateFrame("Frame", nil, itemRow)
        itemNameFrame:SetPoint("LEFT", removeBtn, "RIGHT", 5, 0)
        itemNameFrame:SetPoint("RIGHT", itemRow, "RIGHT", -280, 0)
        itemNameFrame:SetHeight(32)
        itemNameFrame:EnableMouse(true)
        itemNameFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(item.id)
            GameTooltip:Show()
        end)
        itemNameFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        local itemNameText = itemNameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        itemNameText:SetPoint("LEFT", itemNameFrame, "LEFT", 0, 0)
        itemNameText:SetPoint("RIGHT", itemNameFrame, "RIGHT", 0, 0)
        itemNameText:SetText(item.data.itemName or ("Item " .. item.id))
        itemNameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        itemNameText:SetJustifyH("LEFT")
        itemNameText:SetWordWrap(false)

        local bindingInfo = item.data.bindingInfo
        if not bindingInfo then
            bindingInfo = OneWoW_DirectDeposit.DirectDeposit:GetItemBindingInfo(item.id)
        end

        local canWarband = true
        local canPersonal = true
        local canGuild = true

        if bindingInfo then
            canWarband = bindingInfo.canUseWarband ~= false
            canPersonal = bindingInfo.canUsePersonal ~= false
            canGuild = bindingInfo.canUseGuild ~= false
        end

        local warbandRadio = CreateFrame("CheckButton", nil, itemRow, "UIRadioButtonTemplate")
        warbandRadio:SetPoint("RIGHT", itemRow, "RIGHT", -230, 0)
        warbandRadio:SetChecked(item.data.bankType == "warband")
        warbandRadio:SetEnabled(canWarband)
        warbandRadio:SetScript("OnClick", function()
            if canWarband then
                OneWoW_DirectDeposit.DirectDeposit:UpdateItemBankType(item.id, "warband")
                GUI:RefreshItemList(panel, true)
            end
        end)

        local warbandLabel = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        warbandLabel:SetPoint("LEFT", warbandRadio, "RIGHT", 3, 0)
        warbandLabel:SetText(L["ITEM_DEPOSIT_WARBAND"])
        warbandLabel:SetTextColor(canWarband and 0.31 or 0.3, canWarband and 0.78 or 0.3, canWarband and 0.47 or 0.3)

        local personalRadio = CreateFrame("CheckButton", nil, itemRow, "UIRadioButtonTemplate")
        personalRadio:SetPoint("RIGHT", itemRow, "RIGHT", -135, 0)
        personalRadio:SetChecked(item.data.bankType == "personal")
        personalRadio:SetEnabled(canPersonal)
        personalRadio:SetScript("OnClick", function()
            if canPersonal then
                OneWoW_DirectDeposit.DirectDeposit:UpdateItemBankType(item.id, "personal")
                GUI:RefreshItemList(panel, true)
            end
        end)

        local personalLabel = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        personalLabel:SetPoint("LEFT", personalRadio, "RIGHT", 3, 0)
        personalLabel:SetText(L["ITEM_DEPOSIT_PERSONAL"])
        personalLabel:SetTextColor(canPersonal and 0.29 or 0.3, canPersonal and 0.56 or 0.3, canPersonal and 0.88 or 0.3)

        local guildRadio = CreateFrame("CheckButton", nil, itemRow, "UIRadioButtonTemplate")
        guildRadio:SetPoint("RIGHT", itemRow, "RIGHT", -55, 0)
        guildRadio:SetChecked(item.data.bankType == "guild")
        guildRadio:SetEnabled(canGuild)
        guildRadio:SetScript("OnClick", function()
            if canGuild then
                OneWoW_DirectDeposit.DirectDeposit:UpdateItemBankType(item.id, "guild")
                GUI:RefreshItemList(panel, true)
            end
        end)

        local guildLabel = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        guildLabel:SetPoint("LEFT", guildRadio, "RIGHT", 3, 0)
        guildLabel:SetText(L["ITEM_DEPOSIT_GUILD"])
        guildLabel:SetTextColor(canGuild and 1.0 or 0.3, canGuild and 0.5 or 0.3, canGuild and 0.0 or 0.3)

        itemRow:Show()
        yOffset = yOffset - 35
    end

        if #sortedItems == 0 then
            local noItemsText = itemScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            noItemsText:SetPoint("TOP", itemScrollChild, "TOP", 0, -10)
            noItemsText:SetText("No items in auto-deposit list\nDrag items here to add them")
            noItemsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            yOffset = yOffset - 40
        end

        itemScrollChild:SetHeight(math.max(math.abs(yOffset) + 10, 1))

        if preserveScrollPos and panel.itemScrollFrame and savedScrollPos > 0 then
            C_Timer.After(0.05, function()
                local scrollBar = panel.itemScrollFrame.ScrollBar
                if scrollBar then
                    scrollBar:SetValue(savedScrollPos)
                end
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
        width = Constants.GUI.WINDOW_WIDTH - 20,
        height = Constants.GUI.WINDOW_HEIGHT - 135,
    })

    local yOffset = OneWoW_GUI:CreateSettingsPanel(scrollContent, { yOffset = -15, addonName = "OneWoW_DirectDeposit" })

    yOffset = yOffset - 10

    local aboutSection = GUI:CreateSettingsSection(scrollContent, L["ABOUT_SECTION"], yOffset)
    yOffset = aboutSection.bottomY - 15

    local aboutContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    aboutContainer:SetPoint("TOPLEFT", 20, yOffset)
    aboutContainer:SetPoint("TOPRIGHT", -20, yOffset)
    aboutContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    aboutContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    aboutContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local aboutText = aboutContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    aboutText:SetPoint("TOPLEFT", 15, -15)
    aboutText:SetPoint("TOPRIGHT", -15, -15)
    aboutText:SetJustifyH("LEFT")
    aboutText:SetWordWrap(true)
    aboutText:SetText(L["ABOUT_TEXT"])
    aboutText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    aboutText:SetSpacing(3)

    C_Timer.After(0.01, function()
        local aboutTextHeight = aboutText:GetStringHeight()
        aboutContainer:SetHeight(aboutTextHeight + 35)
    end)
    aboutContainer:SetHeight(120)

    yOffset = yOffset - 140

    local linksSection = GUI:CreateSettingsSection(scrollContent, L["LINKS_SECTION"], yOffset)
    yOffset = linksSection.bottomY - 15

    local discordContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    discordContainer:SetPoint("TOPLEFT", 20, yOffset)
    discordContainer:SetPoint("TOPRIGHT", -20, yOffset)
    discordContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    discordContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    discordContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local discordLabel = discordContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    discordLabel:SetPoint("TOPLEFT", 15, -10)
    discordLabel:SetText(L["DISCORD_LABEL"])
    discordLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local discordBox = OneWoW_GUI:CreateEditBox(discordContainer, { width = scrollFrame:GetWidth() - 70, height = 28 })
    discordBox:SetPoint("TOPLEFT", 15, -35)
    discordBox:SetPoint("TOPRIGHT", -15, -35)
    discordBox:SetText(L["DISCORD_URL"])
    discordBox:SetAutoFocus(false)
    discordBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    end)
    discordBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)
    discordBox:SetScript("OnMouseDown", function(self)
        self:SetFocus()
        self:HighlightText()
    end)

    local discordHint = discordContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    discordHint:SetPoint("TOPLEFT", 15, -68)
    discordHint:SetText(L["COPY_HINT"])
    discordHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    discordContainer:SetHeight(85)
    yOffset = yOffset - 95

    local websiteContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    websiteContainer:SetPoint("TOPLEFT", 20, yOffset)
    websiteContainer:SetPoint("TOPRIGHT", -20, yOffset)
    websiteContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    websiteContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    websiteContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local websiteLabel = websiteContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    websiteLabel:SetPoint("TOPLEFT", 15, -10)
    websiteLabel:SetText(L["WEBSITE_LABEL"])
    websiteLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local websiteBox = OneWoW_GUI:CreateEditBox(websiteContainer, { width = scrollFrame:GetWidth() - 70, height = 28 })
    websiteBox:SetPoint("TOPLEFT", 15, -35)
    websiteBox:SetPoint("TOPRIGHT", -15, -35)
    websiteBox:SetText(L["WEBSITE_URL"])
    websiteBox:SetAutoFocus(false)
    websiteBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    end)
    websiteBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)
    websiteBox:SetScript("OnMouseDown", function(self)
        self:SetFocus()
        self:HighlightText()
    end)

    local websiteHint = websiteContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    websiteHint:SetPoint("TOPLEFT", 15, -68)
    websiteHint:SetText(L["COPY_HINT"])
    websiteHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    websiteContainer:SetHeight(85)
    yOffset = yOffset - 95

    local importSection = GUI:CreateSettingsSection(scrollContent, L["IMPORT_SECTION"], yOffset)
    yOffset = importSection.bottomY - 15

    local importDesc = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importDesc:SetPoint("TOPLEFT", 20, yOffset)
    importDesc:SetPoint("TOPRIGHT", -20, yOffset)
    importDesc:SetJustifyH("LEFT")
    importDesc:SetWordWrap(true)
    importDesc:SetText(L["IMPORT_DESC"])
    importDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    local importDescHeight = importDesc:GetStringHeight()
    yOffset = yOffset - importDescHeight - 20

    local importBtn = OneWoW_GUI:CreateButton(scrollContent, { text = L["IMPORT_BUTTON"], width = 240, height = 30 })
    importBtn:SetPoint("TOPLEFT", 40, yOffset)
    importBtn:SetScript("OnClick", function()
        local success, result = OneWoW_DirectDeposit:ImportFromWoWNotes()
        if success then
            OneWoW_DirectDeposit:ValidateAndCleanItemList()
            StaticPopup_Show("DIRECTDEPOSIT_IMPORT_SUCCESS", tostring(result))
            if MainWindow then
                MainWindow:Hide()
            end
            isInitialized = false
            MainWindow = nil
            C_Timer.After(0.1, function()
                GUI:Show()
            end)
        else
            StaticPopup_Show("DIRECTDEPOSIT_IMPORT_FAILED", result)
        end
    end)

    yOffset = yOffset - 50

    scrollContent:SetHeight(math.abs(yOffset) + 40)
    panel.scrollContent = scrollContent

    return panel
end

function GUI:CreateSettingsSection(parent, title, yOffset)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", 10, yOffset)
    section:SetPoint("TOPRIGHT", -10, yOffset)
    section:SetHeight(40)
    section:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    section:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    section:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local titleText = section:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", 15, 0)
    titleText:SetText(title)
    titleText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    section.bottomY = yOffset - 50

    return section
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
    MainWindow = nil
    isInitialized = false
    currentTab = 1
    tabPanels = {}
    isRefreshing = false
    pendingRefresh = nil
end
