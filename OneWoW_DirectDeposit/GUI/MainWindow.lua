local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

ns.GUI = ns.GUI or {}

local GUI = ns.GUI
local Constants = ns.Constants
local L = ns.L

local function GetDB()
    return ns.db
end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local strtrim, tonumber, tostring = strtrim, tonumber, tostring

local function FormatTargetGoldForEditBox(value)
    if value == nil then
        return ""
    end
    return tostring(value)
end

---@class DirectDepositMainWindowFrame : Frame
---@field titleBar table
---@field content Frame
---@field depositNowBtn table
---@field pauseBtn table
---@field progressText FontString
---@field contentArea Frame
local MainWindow = nil ---@type DirectDepositMainWindowFrame?
local isInitialized = false
local currentTab    = 1
local tabPanels     = {}
local tabButtons    = {}

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
    if not OneWoW_GUI:RestoreWindowPosition(MainWindow, GetDB().global.mainFramePosition) then
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
        local db = GetDB().global
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
    if not MainWindow then return end

    local tabContainer = CreateFrame("Frame", nil, parent)
    tabContainer:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    tabContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    tabContainer:SetHeight(35)

    local tabDefs = {
        { text = L["TAB_GOLD"],     id = 1 },
        { text = ITEMS,             id = 2 },
        { text = L["TAB_KEYBINDS"], id = 3 },
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
        btn:SetScript("OnClick", function(myself) GUI:SelectTab(myself.tabID) end)
        tabButtons[def.id] = btn
        prevTab = btn
    end

    local depositNowBtn = OneWoW_GUI:CreateFitTextButton(tabContainer, { text = L["DEPOSIT_NOW"], height = 26 })
    depositNowBtn:SetPoint("BOTTOMRIGHT", tabContainer, "BOTTOMRIGHT", 0, 0)
    depositNowBtn:SetScript("OnClick", function()
        ns.DirectDeposit:ManualDeposit()
    end)
    MainWindow.depositNowBtn = depositNowBtn

    local pauseBtn = OneWoW_GUI:CreateFitTextButton(tabContainer, { text = L["PAUSE"], height = 26 })
    pauseBtn:SetPoint("RIGHT", depositNowBtn, "LEFT", -4, 0)
    pauseBtn:Hide()
    pauseBtn:SetScript("OnClick", function()
        ns.DirectDeposit:StopDeposit()
    end)
    MainWindow.pauseBtn = pauseBtn

    local progressText = OneWoW_GUI:CreateFS(tabContainer, 10)
    progressText:SetPoint("RIGHT", pauseBtn, "LEFT", -8, 0)
    progressText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    progressText:Hide()
    MainWindow.progressText = progressText

    ns.DirectDeposit:SetProgressCallback(function(current, total, itemName)
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
    tabPanels[3] = GUI:CreateKeybindsPanel(contentArea)

    local bottomBar = CreateFrame("Frame", nil, parent)
    bottomBar:SetHeight(36)
    bottomBar:SetPoint("BOTTOMLEFT",  parent, "BOTTOMLEFT",  0, 0)
    bottomBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local closeBtn = OneWoW_GUI:CreateFitTextButton(bottomBar, { text = CLOSE, height = Constants.GUI.BUTTON_HEIGHT })
    closeBtn:SetPoint("RIGHT", bottomBar, "RIGHT", -OneWoW_GUI:GetSpacing("SM"), 0)
    closeBtn:SetScript("OnClick", function()
        MainWindow:Hide()
    end)

    GUI:SelectTab(1)
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
end

function GUI:CreateGoldPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel.widgets = {}

    local _, scrollContent = OneWoW_GUI:CreateScrollFrame(panel, {
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
    accountEnabled:SetChecked(GetDB().global.directDeposit.enabled)
    accountEnabled:SetScript("OnClick", function(myself)
        GetDB().global.directDeposit.enabled = myself:GetChecked()
    end)
    panel.accountEnabled = accountEnabled
    yOffset = yOffset - 30

    local targetGoldLabel = OneWoW_GUI:CreateFS(scrollContent, 12)
    targetGoldLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 40, yOffset)
    targetGoldLabel:SetText(L["TARGET_GOLD"] .. ":")
    targetGoldLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local targetGoldBox = OneWoW_GUI:CreateEditBox(scrollContent, { width = 100, height = 26 })
    targetGoldBox:SetPoint("LEFT", targetGoldLabel, "RIGHT", 10, 0)
    targetGoldBox:SetText(FormatTargetGoldForEditBox(GetDB().global.directDeposit.targetGold))
    targetGoldBox:SetScript("OnTextChanged", function(myself)
        local trimmed = strtrim(myself:GetText() or "")
        if trimmed == "" then
            GetDB().global.directDeposit.targetGold = nil
            return
        end
        local value = tonumber(trimmed)
        if value ~= nil then
            GetDB().global.directDeposit.targetGold = value
        end
    end)
    targetGoldBox:SetScript("OnEnterPressed", function(myself) myself:ClearFocus() end)
    panel.targetGoldBox = targetGoldBox

    local goldText = OneWoW_GUI:CreateFS(scrollContent, 12)
    goldText:SetPoint("LEFT", targetGoldBox, "RIGHT", 5, 0)
    goldText:SetText(L["GOLD"])
    goldText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    yOffset = yOffset - 38

    local depositCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["DEPOSIT_ENABLE"] })
    depositCheck:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 40, yOffset)
    depositCheck:SetChecked(GetDB().global.directDeposit.depositEnabled)
    depositCheck:SetScript("OnClick", function(myself)
        GetDB().global.directDeposit.depositEnabled = myself:GetChecked()
    end)
    panel.depositCheck = depositCheck
    yOffset = yOffset - 28

    local withdrawCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["WITHDRAW_ENABLE"] })
    withdrawCheck:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 40, yOffset)
    withdrawCheck:SetChecked(GetDB().global.directDeposit.withdrawEnabled)
    withdrawCheck:SetScript("OnClick", function(myself)
        GetDB().global.directDeposit.withdrawEnabled = myself:GetChecked()
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
    useCharSettings:SetChecked(not GetDB().char.directDeposit.useAccountSettings)
    useCharSettings:SetScript("OnClick", function(myself)
        GetDB().char.directDeposit.useAccountSettings = not myself:GetChecked()
        GUI:RefreshGoldPanel()
    end)
    panel.useCharSettings = useCharSettings
    yOffset = yOffset - 38

    panel.charSettingsStart = yOffset
    scrollContent.charSettingsFrames = {}

    if not GetDB().char.directDeposit.useAccountSettings then
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
    charTargetGoldBox:SetText(FormatTargetGoldForEditBox(GetDB().char.directDeposit.targetGold))
    charTargetGoldBox:SetScript("OnTextChanged", function(myself)
        local trimmed = strtrim(myself:GetText() or "")
        if trimmed == "" then
            GetDB().char.directDeposit.targetGold = nil
            return
        end
        local value = tonumber(trimmed)
        if value ~= nil then
            GetDB().char.directDeposit.targetGold = value
        end
    end)
    charTargetGoldBox:SetScript("OnEnterPressed", function(myself) myself:ClearFocus() end)
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
    charDepositCheck:SetChecked(GetDB().char.directDeposit.depositEnabled)
    charDepositCheck:SetScript("OnClick", function(myself)
        GetDB().char.directDeposit.depositEnabled = myself:GetChecked()
    end)
    table.insert(framesTable, charDepositCheck)
    if panel then panel.charDepositCheck = charDepositCheck end
    yOffset = yOffset - 28

    local charWithdrawCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["WITHDRAW_ENABLE"] })
    charWithdrawCheck:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 40, yOffset)
    charWithdrawCheck:SetChecked(GetDB().char.directDeposit.withdrawEnabled)
    charWithdrawCheck:SetScript("OnClick", function(myself)
        GetDB().char.directDeposit.withdrawEnabled = myself:GetChecked()
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

    if not GetDB().char.directDeposit.useAccountSettings then
        yOffset = GUI:CreateCharacterSettings(scrollContent, yOffset, scrollContent.charSettingsFrames, panel)
    end

    scrollContent:SetHeight(math.abs(yOffset) + 40)
end

function GUI:CreateItemsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()

    local _, scrollContent = OneWoW_GUI:CreateScrollFrame(panel, {
        name = "OneWoW_DirectDepositItemSettings",
    })

    local yOffset = -15

    local warboundSection = OneWoW_GUI:CreateSectionHeader(scrollContent, {
        title   = L["WARBOUND_SECTION"],
        yOffset = yOffset,
    })
    yOffset = warboundSection.bottomY - 10

    local warboundCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["WARBOUND_ENABLE"] })
    warboundCheck:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 20, yOffset)
    warboundCheck:SetChecked(GetDB().global.directDeposit.warboundAutoDeposit)
    warboundCheck:SetScript("OnClick", function(myself)
        GetDB().global.directDeposit.warboundAutoDeposit = myself:GetChecked()
    end)
    panel.warboundCheck = warboundCheck
    yOffset = yOffset - 30

    local warboundDesc = OneWoW_GUI:CreateFS(scrollContent, 11)
    warboundDesc:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  40, yOffset)
    warboundDesc:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -20, yOffset)
    warboundDesc:SetText(L["WARBOUND_ENABLE_DESC"])
    warboundDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    warboundDesc:SetJustifyH("LEFT")
    warboundDesc:SetWordWrap(true)
    yOffset = yOffset - 52
    yOffset = yOffset - 14

    local excludeKwLabel = OneWoW_GUI:CreateFS(scrollContent, 12)
    excludeKwLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 40, yOffset)
    excludeKwLabel:SetText(L["WARBOUND_EXCLUDE_KEYWORD_LABEL"])
    excludeKwLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - 24

    local excludeKwBox = OneWoW_GUI:CreateEditBox(scrollContent, { width = 300, height = 26 })
    excludeKwBox:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 40, yOffset)
    excludeKwBox:SetText(GetDB().global.directDeposit.warboundExcludeExpr)
    excludeKwBox:SetScript("OnTextChanged", function(myself)
        GetDB().global.directDeposit.warboundExcludeExpr = strtrim(myself:GetText() or "")
    end)
    excludeKwBox:SetScript("OnEnterPressed", function(myself) myself:ClearFocus() end)
    panel.excludeKwBox = excludeKwBox
    yOffset = yOffset - 34

    local excludeKwDesc = OneWoW_GUI:CreateFS(scrollContent, 11)
    excludeKwDesc:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  40, yOffset)
    excludeKwDesc:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -20, yOffset)
    excludeKwDesc:SetText(L["WARBOUND_EXCLUDE_KEYWORD_DESC"])
    excludeKwDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    excludeKwDesc:SetJustifyH("LEFT")
    excludeKwDesc:SetWordWrap(true)
    yOffset = yOffset - 64

    local excludeItemsLabel = OneWoW_GUI:CreateFS(scrollContent, 12)
    excludeItemsLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 40, yOffset)
    excludeItemsLabel:SetText(L["WARBOUND_EXCLUDE_ITEMS_LABEL"])
    excludeItemsLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - 24

    local excludeBox = OneWoW_GUI:CreateFrame(scrollContent, {
        backdrop     = BACKDROP_INNER_NO_INSETS,
        bgColor      = "BG_SECONDARY",
        borderColor  = "BORDER_SUBTLE",
    })
    excludeBox:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  40, yOffset)
    excludeBox:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -20, yOffset)
    excludeBox:SetHeight(180)
    excludeBox:EnableMouse(true)
    excludeBox:RegisterForDrag("LeftButton")

    local excludeList
    local excludeAdd = OneWoW_GUI:CreateValueAddRow(excludeBox, {
        yOffset = -10,
        x = 10,
        rightInset = 10,
        label = L["ITEM_ID"],
        addText = ADD,
        input = { kind = "itemId", width = 100 },
        drop = {
            mode = "chip",
            text = L["DRAG_ITEM_HERE"],
        },
        onAdd = function(itemID)
            local success, msg = ns.DirectDeposit:AddWarboundExclude(itemID)
            if not success then
                print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF0000" .. (msg or "Failed to add item") .. "|r")
                return false
            end
            if excludeList then
                excludeList:Refresh()
            end
            C_Item.RequestLoadItemDataByID(itemID)
            C_Timer.After(0.3, function()
                if excludeList then
                    excludeList:Refresh()
                end
            end)
        end,
    })
    excludeAdd:AttachDropTarget(excludeBox)

    local excludeListTop = -10 - excludeAdd:GetHeight() - 8
    local excludeListHeight = 180 + excludeListTop - 10

    excludeList = OneWoW_GUI:CreateEntryList(excludeBox, {
        yOffset = excludeListTop,
        x = 10,
        rightInset = 10,
        height = excludeListHeight,
        scrollName = "OneWoW_DirectDepositExcludeList",
        emptyText = L["NO_ITEMS"],
        sortKey = "directdeposit:keep",
        getEntries = function()
            local excludeData = ns.DirectDeposit:GetWarboundExcludeList()
            local entries = {}
            for itemID, itemData in pairs(excludeData) do
                local id = tonumber(itemID)
                C_Item.RequestLoadItemDataByID(id)
                local _, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
                tinsert(entries, {
                    id = id,
                    label = itemData.itemName or C_Item.GetItemNameByID(id) or ("Item " .. id),
                    icon = icon,
                    data = itemData,
                })
            end
            return entries
        end,
        onRemove = function(itemID)
            ns.DirectDeposit:RemoveWarboundExclude(itemID)
        end,
    })
    excludeAdd:AttachDropTarget(excludeList:GetFrame())
    if excludeList.scrollFrame then
        excludeAdd:AttachDropTarget(excludeList.scrollFrame)
    end

    panel.excludeBox = excludeBox
    panel.excludeAdd = excludeAdd
    panel.excludeList = excludeList

    GUI:RefreshExcludeList(panel)

    yOffset = yOffset - 190
    yOffset = yOffset - 20

    local itemSection = OneWoW_GUI:CreateSectionHeader(scrollContent, {
        title   = L["ITEM_DEPOSIT"],
        yOffset = yOffset,
    })
    yOffset = itemSection.bottomY - 10

    local itemDepositCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["ITEM_DEPOSIT_ENABLE"] })
    itemDepositCheck:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 20, yOffset)
    itemDepositCheck:SetChecked(GetDB().global.directDeposit.itemDepositEnabled)
    itemDepositCheck:SetScript("OnClick", function(myself)
        GetDB().global.directDeposit.itemDepositEnabled = myself:GetChecked()
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

    local iconSize = OneWoW_GUI.Constants.GUI.ENTRY_LIST_ICON_SIZE
    local itemList
    local itemAdd = OneWoW_GUI:CreateValueAddRow(dropZoneFrame, {
        yOffset = -10,
        x = 10,
        rightInset = 10,
        label = L["ITEM_ID"],
        addText = ADD,
        input = { kind = "itemId", width = 100 },
        drop = {
            mode = "chip",
            text = L["DRAG_ITEM_HERE"],
        },
        onAdd = function(itemID)
            local success, msg = ns.DirectDeposit:AddItemToList(itemID, "personal")
            if not success then
                print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF0000" .. (msg or "Failed to add item") .. "|r")
                return false
            end
            if itemList then
                itemList:Refresh()
            end
            C_Item.RequestLoadItemDataByID(itemID)
            C_Timer.After(0.3, function()
                if itemList then
                    itemList:Refresh()
                end
            end)
        end,
    })
    itemAdd:AttachDropTarget(dropZoneFrame)

    local itemListTop = -10 - itemAdd:GetHeight() - 8
    local itemListHeight = 340 + itemListTop - 10

    itemList = OneWoW_GUI:CreateEntryList(dropZoneFrame, {
        yOffset = itemListTop,
        x = 10,
        rightInset = 10,
        height = itemListHeight,
        rowHeight = 32,
        scrollName = "OneWoW_DirectDepositItemList",
        emptyText = L["NO_ITEMS"],
        sortKey = "directdeposit:deposit",
        getEntries = function()
            local itemData = ns.DirectDeposit:GetItemList()
            local entries = {}
            for itemID, data in pairs(itemData) do
                local id = tonumber(itemID)
                C_Item.RequestLoadItemDataByID(id)
                local _, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
                tinsert(entries, {
                    id = id,
                    label = data.itemName or C_Item.GetItemNameByID(id) or ("Item " .. id),
                    icon = icon,
                    data = data,
                })
            end
            return entries
        end,
        createRow = function(row, entry, api)
            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(iconSize, iconSize)
            removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            removeBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
            local capturedID = entry.id
            removeBtn:SetScript("OnClick", function()
                if not api.IsEnabled() then return end
                ns.DirectDeposit:RemoveItemFromList(capturedID)
                api.RequestRefresh()
            end)

            local bindingInfo = entry.data.bindingInfo
            if not bindingInfo then
                bindingInfo = ns.DirectDeposit:GetItemBindingInfo(entry.id)
            end

            local canWarband = bindingInfo == nil or bindingInfo.canUseWarband ~= false
            local canPersonal = bindingInfo == nil or bindingInfo.canUsePersonal ~= false
            local canGuild = bindingInfo == nil or bindingInfo.canUseGuild ~= false

            -- Radios sit left of the remove control; offsets mirror the prior layout.
            local warbandRadio = CreateFrame("CheckButton", nil, row, "UIRadioButtonTemplate")
            warbandRadio:SetPoint("RIGHT", row, "RIGHT", -250, 0)
            warbandRadio:SetChecked(entry.data.bankType == "warband")
            warbandRadio:SetEnabled(canWarband)

            local warbandLabel = OneWoW_GUI:CreateFS(row, 10)
            warbandLabel:SetPoint("LEFT", warbandRadio, "RIGHT", 3, 0)
            warbandLabel:SetText(L["ITEM_DEPOSIT_WARBAND"])
            if canWarband then
                warbandLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                warbandLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end

            local personalRadio = CreateFrame("CheckButton", nil, row, "UIRadioButtonTemplate")
            personalRadio:SetPoint("RIGHT", row, "RIGHT", -155, 0)
            personalRadio:SetChecked(entry.data.bankType == "personal")
            personalRadio:SetEnabled(canPersonal)

            local personalLabel = OneWoW_GUI:CreateFS(row, 10)
            personalLabel:SetPoint("LEFT", personalRadio, "RIGHT", 3, 0)
            personalLabel:SetText(L["ITEM_DEPOSIT_PERSONAL"])
            if canPersonal then
                personalLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                personalLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end

            local guildRadio = CreateFrame("CheckButton", nil, row, "UIRadioButtonTemplate")
            guildRadio:SetPoint("RIGHT", row, "RIGHT", -75, 0)
            guildRadio:SetChecked(entry.data.bankType == "guild")
            guildRadio:SetEnabled(canGuild)

            local guildLabel = OneWoW_GUI:CreateFS(row, 10)
            guildLabel:SetPoint("LEFT", guildRadio, "RIGHT", 3, 0)
            guildLabel:SetText(GUILD)
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
                    ns.DirectDeposit:UpdateItemBankType(entry.id, "warband")
                else
                    warbandRadio:SetChecked(false)
                end
            end)

            personalRadio:SetScript("OnClick", function()
                if canPersonal then
                    personalRadio:SetChecked(true)
                    warbandRadio:SetChecked(false)
                    guildRadio:SetChecked(false)
                    ns.DirectDeposit:UpdateItemBankType(entry.id, "personal")
                else
                    personalRadio:SetChecked(false)
                end
            end)

            guildRadio:SetScript("OnClick", function()
                if canGuild then
                    guildRadio:SetChecked(true)
                    warbandRadio:SetChecked(false)
                    personalRadio:SetChecked(false)
                    ns.DirectDeposit:UpdateItemBankType(entry.id, "guild")
                else
                    guildRadio:SetChecked(false)
                end
            end)

            local left = 0
            if entry.icon then
                local iconTex = row:CreateTexture(nil, "ARTWORK")
                iconTex:SetSize(iconSize, iconSize)
                iconTex:SetPoint("LEFT", row, "LEFT", 0, 0)
                iconTex:SetTexture(entry.icon)
                iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                left = iconSize + 6
            end

            local nameFrame = CreateFrame("Frame", nil, row)
            nameFrame:SetPoint("LEFT", row, "LEFT", left, 0)
            nameFrame:SetPoint("RIGHT", warbandRadio, "LEFT", -8, 0)
            nameFrame:SetHeight(32)
            nameFrame:EnableMouse(true)
            nameFrame:SetScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(entry.id)
                GameTooltip:Show()
            end)
            nameFrame:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            local nameText = OneWoW_GUI:CreateFS(nameFrame, 12)
            nameText:SetPoint("LEFT", nameFrame, "LEFT", 0, 0)
            nameText:SetPoint("RIGHT", nameFrame, "RIGHT", 0, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetWordWrap(false)
            nameText:SetText(entry.label)
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            return 32
        end,
    })
    itemAdd:AttachDropTarget(itemList:GetFrame())
    if itemList.scrollFrame then
        itemAdd:AttachDropTarget(itemList.scrollFrame)
    end

    panel.itemList = itemList
    panel.itemAdd = itemAdd
    panel.itemScrollFrame = itemList.scrollFrame
    panel.scrollContent = scrollContent
    panel.dropZoneFrame = dropZoneFrame

    GUI:RefreshItemList(panel)

    yOffset = yOffset - 350
    scrollContent:SetHeight(math.abs(yOffset) + 40)

    return panel
end

function GUI:RefreshItemList(panel)
    if not panel or not panel.itemList then return end
    panel.itemList:Refresh()
end

function GUI:RefreshExcludeList(panel)
    if not panel or not panel.excludeList then return end
    panel.excludeList:Refresh()
end

function GUI:CreateKeybindsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()

    local _, scrollContent = OneWoW_GUI:CreateScrollFrame(panel, {
        name = "OneWoW_DirectDepositKeybinds",
    })

    local yOffset = -15

    local tooltipSection = OneWoW_GUI:CreateSectionHeader(scrollContent, {
        title   = L["TOOLTIP_SECTION"],
        yOffset = yOffset,
    })
    yOffset = tooltipSection.bottomY - 10

    local tooltipCheck = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["TOOLTIP_ENABLE"] })
    tooltipCheck:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 20, yOffset)
    tooltipCheck:SetChecked(GetDB().global.directDeposit.tooltipEnabled)
    tooltipCheck:SetScript("OnClick", function(myself)
        GetDB().global.directDeposit.tooltipEnabled = myself:GetChecked()
    end)
    panel.tooltipCheck = tooltipCheck
    yOffset = yOffset - 30

    local tooltipDesc = OneWoW_GUI:CreateFS(scrollContent, 11)
    tooltipDesc:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  40, yOffset)
    tooltipDesc:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -20, yOffset)
    tooltipDesc:SetText(L["TOOLTIP_ENABLE_DESC"])
    tooltipDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    tooltipDesc:SetJustifyH("LEFT")
    tooltipDesc:SetWordWrap(true)
    yOffset = yOffset - 48

    local keybindSection = OneWoW_GUI:CreateSectionHeader(scrollContent, {
        title   = L["KEYBIND_SECTION"],
        yOffset = yOffset,
    })
    yOffset = keybindSection.bottomY - 10

    local keybindDesc = OneWoW_GUI:CreateFS(scrollContent, 11)
    keybindDesc:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  20, yOffset)
    keybindDesc:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -20, yOffset)
    keybindDesc:SetText(L["KEYBIND_DESC"])
    keybindDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    keybindDesc:SetJustifyH("LEFT")
    keybindDesc:SetWordWrap(true)
    yOffset = yOffset - 48

    local bindingDefs = {
        { nameKey = "KEYBIND_ADD_PERSONAL", binding = "ONEWOW_DIRECTDEPOSIT_ADD_PERSONAL" },
        { nameKey = "KEYBIND_ADD_WARBAND",  binding = "ONEWOW_DIRECTDEPOSIT_ADD_WARBAND"  },
        { nameKey = "KEYBIND_ADD_GUILD",    binding = "ONEWOW_DIRECTDEPOSIT_ADD_GUILD"    },
    }

    for _, def in ipairs(bindingDefs) do
        local row = OneWoW_GUI:CreateFrame(scrollContent, {
            backdrop    = BACKDROP_INNER_NO_INSETS,
            bgColor     = "BG_SECONDARY",
            borderColor = "BORDER_SUBTLE",
        })
        row:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  20, yOffset)
        row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -20, yOffset)
        row:SetHeight(32)

        local nameText = OneWoW_GUI:CreateFS(row, 12)
        nameText:SetPoint("LEFT", row, "LEFT", 12, 0)
        nameText:SetText(L[def.nameKey])
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local keyText = OneWoW_GUI:CreateFS(row, 12)
        keyText:SetPoint("RIGHT", row, "RIGHT", -12, 0)
        local key1, key2 = GetBindingKey(def.binding)
        local keyDisplay = key1 or key2 or "|cFF888888Unbound|r"
        if key1 and key2 then keyDisplay = key1 .. " / " .. key2 end
        keyText:SetText(keyDisplay)
        keyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        keyText:SetJustifyH("RIGHT")

        yOffset = yOffset - 38
    end

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
end
