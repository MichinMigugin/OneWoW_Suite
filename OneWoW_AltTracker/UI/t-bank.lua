local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_EDGE = OneWoW_GUI.Constants.BACKDROP_EDGE

ns.UI = ns.UI or {}

local selectedCharacterKey = nil
local currentBankType = "personal"
local currentTab = 1
local selectedGuildName = nil

function ns.UI.CreateBankTab(parent)
    local currentChar = UnitName("player")
    local currentRealm = GetRealmName()
    selectedCharacterKey = currentChar .. "-" .. currentRealm

    local controlPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    controlPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -5)
    controlPanel:SetHeight(85)
    controlPanel:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    controlPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    controlPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local controlTitle = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    controlTitle:SetPoint("TOP", controlPanel, "TOP", 0, -8)
    controlTitle:SetText(currentChar .. " - " .. L["BANK_PERSONAL"])
    controlTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local charDropdown, charDropdownText = OneWoW_GUI:CreateDropdown(controlPanel, {
        width = 170, height = 28, text = ""
    })
    charDropdown:SetPoint("BOTTOMLEFT", controlPanel, "BOTTOMLEFT", 10, 6)

    local guildDropdown, guildDropdownText = OneWoW_GUI:CreateDropdown(controlPanel, {
        width = 170, height = 28, text = ""
    })
    guildDropdown:SetPoint("LEFT", charDropdown, "RIGHT", 6, 0)
    guildDropdown:Hide()

    local buttonContainer = CreateFrame("Frame", nil, controlPanel)
    buttonContainer:SetPoint("LEFT", charDropdown, "RIGHT", 8, 0)
    buttonContainer:SetPoint("RIGHT", controlPanel, "RIGHT", -140, 0)
    buttonContainer:SetHeight(30)

    local function CreateBankTypeButton(btnText, bankTypeKey, index)
        local btn = OneWoW_GUI:CreateButton(buttonContainer, { text = btnText, width = 80, height = 28 })
        btn.label = btn.text
        btn.bankType = bankTypeKey
        btn.index = index

        btn:SetScript("OnEnter", function(self)
            if currentBankType ~= self.bankType then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                self.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        end)

        btn:SetScript("OnLeave", function(self)
            if currentBankType ~= self.bankType then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                self.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            end
        end)

        btn:SetScript("OnClick", function(self)
            currentBankType = self.bankType
            currentTab = 1

            for _, button in ipairs(parent.bankTypeButtons) do
                if button.bankType == currentBankType then
                    button:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    button.label:SetTextColor(1, 1, 1)
                else
                    button:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                    button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
                    button.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                end
            end

            if currentBankType == "guild" then
                guildDropdown:Show()
                buttonContainer:ClearAllPoints()
                buttonContainer:SetPoint("LEFT", guildDropdown, "RIGHT", 8, 0)
                buttonContainer:SetPoint("RIGHT", controlPanel, "RIGHT", -140, 0)
            else
                guildDropdown:Hide()
                buttonContainer:ClearAllPoints()
                buttonContainer:SetPoint("LEFT", charDropdown, "RIGHT", 8, 0)
                buttonContainer:SetPoint("RIGHT", controlPanel, "RIGHT", -140, 0)
            end

            if ns.UI.RefreshBankDisplay then
                ns.UI.RefreshBankDisplay(parent)
            end
        end)

        return btn
    end

    local personalBtn = CreateBankTypeButton(L["BANK_PERSONAL"], "personal", 1)
    local warbandBtn = CreateBankTypeButton(L["BANK_WARBAND"], "warband", 2)
    local guildBtn = CreateBankTypeButton(L["BANK_GUILD"], "guild", 3)
    local bagsBtn = CreateBankTypeButton(L["BANK_BAGS"], "bags", 4)

    parent.bankTypeButtons = { personalBtn, warbandBtn, guildBtn, bagsBtn }

    local function LayoutBankButtons()
        local containerWidth = buttonContainer:GetWidth()
        local numButtons = #parent.bankTypeButtons
        local totalGap = 8 * (numButtons - 1)
        local buttonWidth = (containerWidth - totalGap) / numButtons

        for i, btn in ipairs(parent.bankTypeButtons) do
            btn:SetWidth(buttonWidth)
            btn:ClearAllPoints()
            if i == 1 then
                btn:SetPoint("LEFT", buttonContainer, "LEFT", 0, 0)
            else
                btn:SetPoint("LEFT", parent.bankTypeButtons[i-1], "RIGHT", 8, 0)
            end
        end
    end

    buttonContainer:SetScript("OnSizeChanged", LayoutBankButtons)
    C_Timer.After(0.1, LayoutBankButtons)

    personalBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    personalBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    personalBtn.label:SetTextColor(1, 1, 1)

    local updateButton = OneWoW_GUI:CreateButton(controlPanel, { text = L["BANK_UPDATE_BANKS"], width = 120, height = 28 })
    updateButton:SetPoint("BOTTOMRIGHT", controlPanel, "BOTTOMRIGHT", -10, 6)
    updateButton:SetScript("OnClick", function()
        if parent.RebuildGuildDropdown then
            parent.RebuildGuildDropdown()
        end
        if ns.UI.RefreshBankDisplay then
            ns.UI.RefreshBankDisplay(parent)
        end
    end)

    local bankViewPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bankViewPanel:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -8)
    bankViewPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 30)
    bankViewPanel:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    bankViewPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    bankViewPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local gridContainer = CreateFrame("Frame", nil, bankViewPanel)
    gridContainer:SetPoint("TOPLEFT", bankViewPanel, "TOPLEFT", 10, -10)
    gridContainer:SetPoint("BOTTOMRIGHT", bankViewPanel, "BOTTOMRIGHT", -75, 10)

    local tabContainer = CreateFrame("Frame", nil, bankViewPanel)
    tabContainer:SetPoint("TOPRIGHT", bankViewPanel, "TOPRIGHT", -5, -10)
    tabContainer:SetPoint("BOTTOMRIGHT", bankViewPanel, "BOTTOMRIGHT", -5, 10)
    tabContainer:SetWidth(65)

    local bagScrollFrame = CreateFrame("ScrollFrame", nil, bankViewPanel)
    bagScrollFrame:SetPoint("TOPLEFT", bankViewPanel, "TOPLEFT", 10, -10)
    bagScrollFrame:SetPoint("BOTTOMRIGHT", bankViewPanel, "BOTTOMRIGHT", -17, 10)
    bagScrollFrame:Hide()

    local bagScrollContent = CreateFrame("Frame", nil, bagScrollFrame)
    bagScrollContent:SetWidth(1)
    bagScrollContent:SetHeight(1)
    bagScrollFrame:SetScrollChild(bagScrollContent)

    local bagScrollBar = CreateFrame("Slider", nil, bankViewPanel, "BackdropTemplate")
    bagScrollBar:SetPoint("TOPLEFT", bagScrollFrame, "TOPRIGHT", 2, 0)
    bagScrollBar:SetPoint("BOTTOMLEFT", bagScrollFrame, "BOTTOMRIGHT", 2, 0)
    bagScrollBar:SetWidth(10)
    bagScrollBar:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SIMPLE)
    bagScrollBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    bagScrollBar:SetMinMaxValues(0, 0)
    bagScrollBar:SetValue(0)
    bagScrollBar:Hide()
    bagScrollBar:SetScript("OnValueChanged", function(s, value)
        bagScrollFrame:SetVerticalScroll(value)
    end)

    local bagScrollThumb = bagScrollBar:CreateTexture(nil, "OVERLAY")
    bagScrollThumb:SetSize(8, 30)
    bagScrollThumb:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    bagScrollBar:SetThumbTexture(bagScrollThumb)

    bagScrollFrame:EnableMouseWheel(true)
    bagScrollFrame:SetScript("OnMouseWheel", function(sf, direction)
        local current = bagScrollFrame:GetVerticalScroll()
        local maxScroll = math.max(0, bagScrollContent:GetHeight() - bagScrollFrame:GetHeight())
        local new = math.max(0, math.min(maxScroll, current - (direction * 42)))
        bagScrollFrame:SetVerticalScroll(new)
        bagScrollBar:SetValue(new)
    end)

    local statusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    statusBar:SetPoint("TOPLEFT", bankViewPanel, "BOTTOMLEFT", 0, -5)
    statusBar:SetPoint("TOPRIGHT", bankViewPanel, "BOTTOMRIGHT", 0, -5)
    statusBar:SetHeight(25)
    statusBar:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    statusBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    statusBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", statusBar, "LEFT", 10, 0)
    statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    statusText:SetText(L["BANK_VIEWING"] .. ": " .. currentChar .. " - " .. L["BANK_PERSONAL"])

    parent.controlPanel = controlPanel
    parent.controlTitle = controlTitle
    parent.bankViewPanel = bankViewPanel
    parent.gridContainer = gridContainer
    parent.tabContainer = tabContainer
    parent.statusBar = statusBar
    parent.statusText = statusText
    parent.charDropdown = charDropdown
    parent.guildDropdown = guildDropdown
    parent.buttonContainer = buttonContainer
    parent.updateButton = updateButton
    parent.itemFramePool = {}
    parent.tabButtons = {}
    parent.bagScrollFrame = bagScrollFrame
    parent.bagScrollContent = bagScrollContent
    parent.bagScrollBar = bagScrollBar
    parent.bagItemFramePool = {}

    local function InitializeCharacterDropdown()
        if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then
            charDropdownText:SetText(L["BANK_NO_CHARACTERS"] or "No Characters")
            return
        end

        local characterList = {}
        for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
            table.insert(characterList, {
                text = charData.name or charKey,
                key = charKey,
                name = charData.name or charKey
            })
        end

        table.sort(characterList, function(a, b)
            return a.name < b.name
        end)

        for _, charInfo in ipairs(characterList) do
            if charInfo.key == selectedCharacterKey then
                charDropdownText:SetText(charInfo.text)
                break
            end
        end

        OneWoW_GUI:AttachFilterMenu(charDropdown, {
            searchable = true,
            menuHeight = 314,
            buildItems = function()
                local items = {}
                for _, charInfo in ipairs(characterList) do
                    table.insert(items, {
                        text = charInfo.text,
                        value = charInfo.key,
                    })
                end
                return items
            end,
            getActiveValue = function()
                return selectedCharacterKey
            end,
            onSelect = function(value, text)
                selectedCharacterKey = value
                charDropdown._text:SetText(text)
                currentTab = 1
                if ns.UI.RefreshBankDisplay then
                    ns.UI.RefreshBankDisplay(parent)
                end
            end,
        })
    end

    local function InitializeGuildDropdown()
        if not _G.OneWoW_AltTracker_Storage_DB or not _G.OneWoW_AltTracker_Storage_DB.guildBanks then
            guildDropdownText:SetText(L["BANK_NO_GUILDS"])
            return
        end

        local guildList = {}
        for guildName, guildData in pairs(_G.OneWoW_AltTracker_Storage_DB.guildBanks) do
            if guildData and guildData.tabs and next(guildData.tabs) then
                table.insert(guildList, {
                    name = guildName,
                    lastUpdate = guildData.lastScan or 0
                })
            end
        end

        table.sort(guildList, function(a, b)
            return a.name < b.name
        end)

        if #guildList > 0 then
            if not selectedGuildName or selectedGuildName == "" then
                local currentPlayerGuild = IsInGuild() and GetGuildInfo("player")
                selectedGuildName = currentPlayerGuild or guildList[1].name
            end

            local foundGuild = false
            for _, guildInfo in ipairs(guildList) do
                if guildInfo.name == selectedGuildName then
                    guildDropdownText:SetText(guildInfo.name)
                    foundGuild = true
                    break
                end
            end

            if not foundGuild then
                selectedGuildName = guildList[1].name
                guildDropdownText:SetText(guildList[1].name)
            end

            OneWoW_GUI:AttachFilterMenu(guildDropdown, {
                searchable = true,
                menuHeight = 314,
                buildItems = function()
                    local items = {}
                    for _, guildInfo in ipairs(guildList) do
                        table.insert(items, {
                            text = guildInfo.name,
                            value = guildInfo.name,
                        })
                    end
                    return items
                end,
                getActiveValue = function()
                    return selectedGuildName
                end,
                onSelect = function(value, text)
                    selectedGuildName = value
                    guildDropdown._text:SetText(text)
                    currentTab = 1
                    if ns.UI.RefreshBankDisplay then
                        ns.UI.RefreshBankDisplay(parent)
                    end
                end,
            })
        else
            selectedGuildName = nil
            guildDropdownText:SetText(L["BANK_NO_GUILDS"])
        end
    end

    InitializeCharacterDropdown()
    InitializeGuildDropdown()

    parent.RebuildGuildDropdown = InitializeGuildDropdown

    parent.lastGuildBankUpdate = 0

    local guildBankEventFrame = CreateFrame("Frame")
    guildBankEventFrame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
    guildBankEventFrame:RegisterEvent("GUILDBANK_UPDATE_TABS")
    guildBankEventFrame:SetScript("OnEvent", function(self, event)
        local now = GetTime()
        if (now - parent.lastGuildBankUpdate) > 2 then
            parent.lastGuildBankUpdate = now
            C_Timer.After(1.5, function()
                if ns.UI.RefreshBankDisplay and parent:IsVisible() then
                    ns.UI.RefreshBankDisplay(parent)
                end
            end)
        end
    end)
    parent.guildBankEventFrame = guildBankEventFrame

    parent:SetScript("OnSizeChanged", function(self)
        if not (self.bagScrollFrame and self.bagScrollFrame:IsShown()) then return end
        if self._bagResizeTimer then
            self._bagResizeTimer:Cancel()
            self._bagResizeTimer = nil
        end
        self._bagResizeTimer = C_Timer.NewTimer(1, function()
            self._bagResizeTimer = nil
            if ns.UI.RefreshBankDisplay and self.bagScrollFrame and self.bagScrollFrame:IsShown() then
                ns.UI.RefreshBankDisplay(self)
            end
        end)
    end)

    parent.RefreshData = function()
        if ns.UI.RefreshBankDisplay then
            ns.UI.RefreshBankDisplay(parent)
        end
    end

    parent.Activate = function()
        if ns.UI.RefreshBankDisplay then
            ns.UI.RefreshBankDisplay(parent)
        end
    end

    parent:SetScript("OnShow", function(self)
        if ns.UI.RefreshBankDisplay then
            ns.UI.RefreshBankDisplay(self)
        end
    end)

    if not ns.UI.BankTabReference then
        ns.UI.BankTabReference = {}
    end
    ns.UI.BankTabReference.parent = parent

    _G.OneWoW_AltTracker = _G.OneWoW_AltTracker or {}
    _G.OneWoW_AltTracker.UI = _G.OneWoW_AltTracker.UI or {}
    _G.OneWoW_AltTracker.UI.RefreshBankDisplay = ns.UI.RefreshBankDisplay
    _G.OneWoW_AltTracker.UI.BankTab = parent

    C_Timer.After(0.3, function()
        if ns.UI.RefreshBankDisplay then
            ns.UI.RefreshBankDisplay(parent)
        end
    end)
end

function ns.UI.RefreshBankDisplay(parent)
    if not parent or not parent.bankViewPanel then return end

    local charName = selectedCharacterKey:match("([^-]+)") or selectedCharacterKey
    local bankTypeName = L["BANK_" .. currentBankType:upper()] or currentBankType

    if currentBankType == "bags" then
        parent.gridContainer:Hide()
        parent.tabContainer:Hide()
        if parent.bagScrollFrame then parent.bagScrollFrame:Show() end
        if parent.bagScrollBar then parent.bagScrollBar:Show() end

        ns.UI.CleanupBankFrames(parent, true)

        local bankData = ns.UI.GetBankData(selectedCharacterKey, currentBankType, selectedGuildName)
        local sortedItems = {}

        if bankData and bankData.bags then
            for bagID = 0, 5 do
                local bagData = bankData.bags[bagID]
                if bagData and bagData.slots then
                    for _, itemData in pairs(bagData.slots) do
                        if itemData then
                            table.insert(sortedItems, itemData)
                        end
                    end
                end
            end
        end

        table.sort(sortedItems, function(a, b)
            local nameA = a.itemName
            local nameB = b.itemName
            if nameA and nameB then
                return nameA < nameB
            elseif nameA then
                return true
            elseif nameB then
                return false
            else
                return (a.itemID or 0) < (b.itemID or 0)
            end
        end)

        ns.UI.DisplayOneBagGrid(parent, sortedItems)

        if parent.controlTitle then
            parent.controlTitle:SetText(charName .. " - " .. bankTypeName)
        end

        if parent.statusText then
            parent.statusText:SetText(L["BANK_VIEWING"] .. ": " .. charName .. " - " .. bankTypeName .. " - " .. #sortedItems .. " " .. L["BANK_ITEMS"])
        end
    else
        if parent.bagScrollFrame then parent.bagScrollFrame:Hide() end
        if parent.bagScrollBar then parent.bagScrollBar:Hide() end
        parent.gridContainer:Show()
        parent.tabContainer:Show()

        if parent.RebuildGuildDropdown then
            parent.RebuildGuildDropdown()
        end

        ns.UI.CleanupBankFrames(parent, true)

        local bankData = ns.UI.GetBankData(selectedCharacterKey, currentBankType, selectedGuildName)
        ns.UI.CreateBankTabs(parent, bankData)
        local items = {}

        if bankData then
            if currentBankType == "personal" then
                if bankData.personalBank and bankData.personalBank.tabs then
                    if bankData.personalBank.tabs[currentTab] and bankData.personalBank.tabs[currentTab].items then
                        for slotID, itemData in pairs(bankData.personalBank.tabs[currentTab].items) do
                            items[slotID] = itemData
                        end
                    end
                end
            elseif currentBankType == "warband" then
                if bankData.warbandBank and bankData.warbandBank.tabs and bankData.warbandBank.tabs[currentTab] then
                    if bankData.warbandBank.tabs[currentTab].items then
                        for slotID, itemData in pairs(bankData.warbandBank.tabs[currentTab].items) do
                            items[slotID] = itemData
                        end
                    end
                end
            elseif currentBankType == "guild" then
                if bankData.guildBank and bankData.guildBank.tabs and bankData.guildBank.tabs[currentTab] and bankData.guildBank.tabs[currentTab].slots then
                    for slotID, itemData in pairs(bankData.guildBank.tabs[currentTab].slots) do
                        items[slotID] = itemData
                    end
                end
            end
        end

        ns.UI.DisplayBankGrid(parent, items)

        local statusMessage = L["BANK_VIEWING"] .. ": " .. charName .. " - " .. bankTypeName .. " - " .. string.format(L["AB_LABEL_BAR"], currentTab)

        if parent.controlTitle then
            if currentBankType == "guild" and selectedGuildName then
                parent.controlTitle:SetText(selectedGuildName .. " - " .. L["BANK_GUILD"])
            else
                parent.controlTitle:SetText(charName .. " - " .. bankTypeName)
            end
        end

        if parent.statusText then
            parent.statusText:SetText(statusMessage)
        end
    end
end

function ns.UI.GetBankData(characterKey, bankType, guildName)
    if not _G.OneWoW_AltTracker_Storage_DB then return nil end
    if not characterKey then return nil end

    local charData = _G.OneWoW_AltTracker_Storage_DB.characters and _G.OneWoW_AltTracker_Storage_DB.characters[characterKey]
    if not charData then return nil end

    return {
        bags = charData.bags,
        personalBank = charData.personalBank,
        warbandBank = _G.OneWoW_AltTracker_Storage_DB.warbandBank,
        guildBank = guildName and _G.OneWoW_AltTracker_Storage_DB.guildBanks and _G.OneWoW_AltTracker_Storage_DB.guildBanks[guildName] or nil,
    }
end

function ns.UI.CreateBankTabs(parent, bankData)
    ns.UI.CleanupBankTabs(parent)
    if currentBankType == "bags" then return end

    if not parent.tabButtons then
        parent.tabButtons = {}
    end

    local maxTabs = 6
    if currentBankType == "bags" then
        maxTabs = 6
    elseif currentBankType == "personal" then
        if bankData and bankData.personalBank and bankData.personalBank.tabs then
            maxTabs = 0
            for tabID, _ in pairs(bankData.personalBank.tabs) do
                if tabID > maxTabs then
                    maxTabs = tabID
                end
            end
        else
            maxTabs = 6
        end
    elseif currentBankType == "warband" then
        maxTabs = 5
    elseif currentBankType == "guild" then
        maxTabs = 8
    end

    local bagNames = {
        L["BANK_BACKPACK"], L["BANK_BAG_1"], L["BANK_BAG_2"],
        L["BANK_BAG_3"], L["BANK_BAG_4"], L["BANK_REAGENTS"]
    }

    for i = 1, maxTabs do
        local tabLabel
        if currentBankType == "bags" then
            tabLabel = bagNames[i]:gsub("Bag ", ""):gsub("Backpack", "BP"):gsub("Reagents", "R")
        else
            tabLabel = tostring(i)
        end

        local tabBtn = OneWoW_GUI:CreateButton(parent.tabContainer, { text = tabLabel, width = 58, height = 50 })
        tabBtn:SetPoint("TOP", parent.tabContainer, "TOP", 0, -((i - 1) * 55))

        tabBtn.text:ClearAllPoints()
        tabBtn.text:SetPoint("BOTTOM", tabBtn, "BOTTOM", 0, 4)
        tabBtn.text:SetFontObject("GameFontNormalSmall")
        tabBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local icon = tabBtn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32)
        icon:SetPoint("CENTER", tabBtn, "CENTER", 0, 4)

        if currentBankType == "bags" and bankData and bankData.bags then
            local bagSlot = i - 1
            local bagItemID = nil

            if bagSlot == 0 then
                icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
            elseif bagSlot == 5 then
                icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_CenarionHerbBag")
            else
                local containerInfo = C_Container.GetContainerNumSlots(bagSlot)
                if containerInfo and containerInfo > 0 then
                    local invSlot = ContainerIDToInventoryID(bagSlot)
                    if invSlot then
                        bagItemID = GetInventoryItemID("player", invSlot)
                        if bagItemID then
                            local bagIcon = C_Item.GetItemIconByID(bagItemID)
                            if bagIcon then
                                icon:SetTexture(bagIcon)
                            else
                                icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
                            end
                        else
                            icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
                        end
                    else
                        icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
                    end
                else
                    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
                end
            end
        else
            icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
        end

        tabBtn.icon = icon

        tabBtn:SetScript("OnEnter", function(self)
            if currentTab ~= i then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        end)

        tabBtn:SetScript("OnLeave", function(self)
            if currentTab ~= i then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            end
        end)

        tabBtn:SetScript("OnClick", function()
            currentTab = i

            for tabIndex, btn in ipairs(parent.tabButtons) do
                if tabIndex == i then
                    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    btn.text:SetTextColor(1, 1, 1)
                else
                    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                    btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                end
            end

            if ns.UI.RefreshBankDisplay then
                ns.UI.RefreshBankDisplay(parent)
            end
        end)

        if i == currentTab then
            tabBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            tabBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            tabBtn.text:SetTextColor(1, 1, 1)
        end

        table.insert(parent.tabButtons, tabBtn)
    end
end

function ns.UI.DisplayBankGrid(parent, items)
    local itemSize = 40
    local itemSpacing = 2
    local slotsPerRow = 14
    local maxRows = 7

    for col = 0, slotsPerRow - 1 do
        for row = 0, maxRows - 1 do
            local slotIndex = col * maxRows + row + 1
            local itemInfo = items[slotIndex]

            local x = col * (itemSize + itemSpacing)
            local y = -row * (itemSize + itemSpacing)

            local itemFrame = ns.UI.GetItemFrame(parent)
            itemFrame:SetSize(itemSize, itemSize)
            itemFrame:SetPoint("TOPLEFT", parent.gridContainer, "TOPLEFT", x, y)
            itemFrame:Show()

            if not itemFrame.bg then
                itemFrame.bg = itemFrame:CreateTexture(nil, "BACKGROUND")
                itemFrame.bg:SetAllPoints()
                itemFrame.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            end

            if not itemFrame.border then
                itemFrame.border = CreateFrame("Frame", nil, itemFrame, "BackdropTemplate")
                itemFrame.border:SetAllPoints()
                itemFrame.border:SetBackdrop(BACKDROP_EDGE)
                itemFrame.border:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end

            if not itemFrame.texture then
                itemFrame.texture = itemFrame:CreateTexture(nil, "ARTWORK")
                itemFrame.texture:SetSize(itemSize - 6, itemSize - 6)
                itemFrame.texture:SetPoint("CENTER")
            end

            if not itemFrame.qualityBorder then
                itemFrame.qualityBorder = itemFrame:CreateTexture(nil, "BORDER")
                itemFrame.qualityBorder:SetTexture(BACKDROP_SIMPLE.bgFile)
                itemFrame.qualityBorder:SetSize(itemSize - 4, itemSize - 4)
                itemFrame.qualityBorder:SetPoint("CENTER")
                itemFrame.qualityBorder:Hide()
            end

            if not itemFrame.count then
                itemFrame.count = itemFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                itemFrame.count:SetPoint("BOTTOMRIGHT", itemFrame, "BOTTOMRIGHT", -2, 2)
                itemFrame.count:SetJustifyH("RIGHT")
            end

            if itemInfo and itemInfo.itemID then
                local itemTexture = C_Item.GetItemIconByID(itemInfo.itemID)
                if itemTexture then
                    itemFrame.texture:SetTexture(itemTexture)
                else
                    itemFrame.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end

                local quality = itemInfo.quality
                if quality and quality > 1 then
                    local r, g, b = C_Item.GetItemQualityColor(quality)
                    itemFrame.qualityBorder:SetColorTexture(r, g, b, 1.0)
                    itemFrame.qualityBorder:Show()
                else
                    itemFrame.qualityBorder:Hide()
                end

                local stack = itemInfo.stackCount or itemInfo.count
                if stack and stack > 1 then
                    itemFrame.count:SetText(stack)
                    itemFrame.count:Show()
                else
                    itemFrame.count:Hide()
                end

                itemFrame:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if itemInfo.itemLink then
                        GameTooltip:SetHyperlink(itemInfo.itemLink)
                    else
                        GameTooltip:SetItemByID(itemInfo.itemID)
                    end
                    GameTooltip:Show()
                end)

                itemFrame:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)
            else
                itemFrame.texture:SetTexture(nil)
                itemFrame.qualityBorder:Hide()
                itemFrame.count:Hide()

                itemFrame:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(L["BANK_EMPTY_SLOT"], 1, 1, 1)
                    GameTooltip:AddLine(L["BANK_SLOT"] .. " " .. slotIndex, 0.7, 0.7, 0.7, true)
                    GameTooltip:Show()
                end)

                itemFrame:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)
            end
        end
    end
end

function ns.UI.DisplayOneBagGrid(parent, sortedItems)
    if not parent.bagScrollFrame or not parent.bagScrollContent then return end

    if parent.bagItemFramePool then
        for _, f in ipairs(parent.bagItemFramePool) do
            if f then
                f:Hide()
                f:ClearAllPoints()
            end
        end
    else
        parent.bagItemFramePool = {}
    end

    local itemSize = 40
    local itemSpacing = 2
    local step = itemSize + itemSpacing
    local panelWidth = parent.bagScrollFrame:GetWidth()
    if panelWidth <= 0 then panelWidth = 840 end
    local xPad = step
    local columns = math.max(1, math.floor((panelWidth - xPad * 2) / step))

    parent.bagScrollContent:SetWidth(panelWidth)

    for i, itemData in ipairs(sortedItems) do
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        local x = xPad + col * step
        local y = -row * step

        local itemFrame = ns.UI.GetBagItemFrame(parent)
        itemFrame:SetSize(itemSize, itemSize)
        itemFrame:SetPoint("TOPLEFT", parent.bagScrollContent, "TOPLEFT", x, y)
        itemFrame:Show()

        if not itemFrame.bg then
            itemFrame.bg = itemFrame:CreateTexture(nil, "BACKGROUND")
            itemFrame.bg:SetAllPoints()
            itemFrame.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        end

        if not itemFrame.border then
            itemFrame.border = CreateFrame("Frame", nil, itemFrame, "BackdropTemplate")
            itemFrame.border:SetAllPoints()
            itemFrame.border:SetBackdrop(BACKDROP_EDGE)
            itemFrame.border:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end

        if not itemFrame.texture then
            itemFrame.texture = itemFrame:CreateTexture(nil, "ARTWORK")
            itemFrame.texture:SetSize(itemSize - 6, itemSize - 6)
            itemFrame.texture:SetPoint("CENTER")
        end

        if not itemFrame.qualityBorder then
            itemFrame.qualityBorder = itemFrame:CreateTexture(nil, "BORDER")
            itemFrame.qualityBorder:SetTexture(BACKDROP_SIMPLE.bgFile)
            itemFrame.qualityBorder:SetSize(itemSize - 4, itemSize - 4)
            itemFrame.qualityBorder:SetPoint("CENTER")
            itemFrame.qualityBorder:Hide()
        end

        if not itemFrame.count then
            itemFrame.count = itemFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            itemFrame.count:SetPoint("BOTTOMRIGHT", itemFrame, "BOTTOMRIGHT", -2, 2)
            itemFrame.count:SetJustifyH("RIGHT")
        end

        local itemTexture = C_Item.GetItemIconByID(itemData.itemID)
        if itemTexture then
            itemFrame.texture:SetTexture(itemTexture)
        else
            itemFrame.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        local quality = itemData.quality
        if quality and quality > 1 then
            local r, g, b = C_Item.GetItemQualityColor(quality)
            itemFrame.qualityBorder:SetColorTexture(r, g, b, 1.0)
            itemFrame.qualityBorder:Show()
        else
            itemFrame.qualityBorder:Hide()
        end

        local stack = itemData.stackCount or itemData.count
        if stack and stack > 1 then
            itemFrame.count:SetText(stack)
            itemFrame.count:Show()
        else
            itemFrame.count:Hide()
        end

        itemFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if itemData.itemLink then
                GameTooltip:SetHyperlink(itemData.itemLink)
            else
                GameTooltip:SetItemByID(itemData.itemID)
            end
            GameTooltip:Show()
        end)

        itemFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end

    local numRows = math.ceil(math.max(1, #sortedItems) / columns)
    local contentHeight = numRows * step + itemSpacing
    parent.bagScrollContent:SetHeight(contentHeight)

    if parent.bagScrollBar then
        local frameHeight = parent.bagScrollFrame:GetHeight()
        local maxScroll = math.max(0, contentHeight - frameHeight)
        parent.bagScrollBar:SetMinMaxValues(0, maxScroll)
        parent.bagScrollBar:SetValue(0)
        parent.bagScrollFrame:SetVerticalScroll(0)
    end
end

function ns.UI.GetBagItemFrame(parent)
    for _, pooledFrame in ipairs(parent.bagItemFramePool) do
        if pooledFrame and not pooledFrame:IsShown() then
            return pooledFrame
        end
    end

    local newFrame = CreateFrame("Button", nil, parent.bagScrollContent)
    newFrame:EnableMouse(true)
    table.insert(parent.bagItemFramePool, newFrame)

    return newFrame
end

function ns.UI.GetItemFrame(parent)
    for _, pooledFrame in ipairs(parent.itemFramePool) do
        if pooledFrame and not pooledFrame:IsShown() then
            return pooledFrame
        end
    end

    local newFrame = CreateFrame("Button", nil, parent.gridContainer)
    newFrame:EnableMouse(true)
    table.insert(parent.itemFramePool, newFrame)

    return newFrame
end

function ns.UI.CleanupBankFrames(parent, gridOnly)
    if not parent then return end

    if parent.itemFramePool then
        for _, itemFrame in ipairs(parent.itemFramePool) do
            if itemFrame then
                itemFrame:Hide()
                itemFrame:ClearAllPoints()
            end
        end
    end

    if parent.bagItemFramePool then
        for _, itemFrame in ipairs(parent.bagItemFramePool) do
            if itemFrame then
                itemFrame:Hide()
                itemFrame:ClearAllPoints()
            end
        end
    end

    if not gridOnly then
        ns.UI.CleanupBankTabs(parent)
    end
end

function ns.UI.CleanupBankTabs(parent)
    if not parent or not parent.tabButtons then return end

    for _, tabBtn in ipairs(parent.tabButtons) do
        if tabBtn then
            tabBtn:Hide()
            tabBtn:SetParent(nil)
            tabBtn:ClearAllPoints()
        end
    end

    wipe(parent.tabButtons)
end
