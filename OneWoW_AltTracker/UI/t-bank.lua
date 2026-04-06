local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.UI = ns.UI or {}

local selectedCharacterKey = nil
local currentBankType = "personal"
local selectedGuildName = nil

function ns.UI.CreateBankTab(parent)
    local currentChar = UnitName("player")
    selectedCharacterKey = OneWoW_GUI:GetCharacterKey()

    local controlPanel = OneWoW_GUI:CreateFrame(parent, { height = 85, bgColor = "BG_SECONDARY" })
    controlPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -5)

    local controlTitle = OneWoW_GUI:CreateFS(controlPanel, 12)
    controlTitle:SetPoint("TOP", controlPanel, "TOP", 0, -8)
    controlTitle:SetText(currentChar .. " - " .. L["BANK_PERSONAL"])
    controlTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local charDropdown, charDropdownText = OneWoW_GUI:CreateDropdown(controlPanel, {
        width = 170, height = 28, text = ""
    })
    charDropdown:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -28)

    local guildDropdown, guildDropdownText = OneWoW_GUI:CreateDropdown(controlPanel, {
        width = 170, height = 28, text = ""
    })
    guildDropdown:SetPoint("LEFT", charDropdown, "RIGHT", 6, 0)
    guildDropdown:Hide()

    local buttonContainer = CreateFrame("Frame", nil, controlPanel)
    buttonContainer:SetPoint("LEFT", charDropdown, "RIGHT", 8, 0)
    buttonContainer:SetPoint("RIGHT", controlPanel, "RIGHT", -10, 0)
    buttonContainer:SetHeight(30)

    local function CreateBankTypeButton(btnText, bankTypeKey, index)
        local btn = OneWoW_GUI:CreateFitTextButton(buttonContainer, { text = btnText, height = 28 })
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

            for _, button in ipairs(parent.bankTypeButtons) do
                if button.bankType == currentBankType then
                    button:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    button.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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
                buttonContainer:SetPoint("RIGHT", controlPanel, "RIGHT", -10, 0)
            else
                guildDropdown:Hide()
                buttonContainer:ClearAllPoints()
                buttonContainer:SetPoint("LEFT", charDropdown, "RIGHT", 8, 0)
                buttonContainer:SetPoint("RIGHT", controlPanel, "RIGHT", -10, 0)
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
    personalBtn.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local searchBox = OneWoW_GUI:CreateEditBox(controlPanel, {
        placeholderText = L["BANK_SEARCH"] or "Search...",
        onTextChanged = function(text)
            ns.UI.FilterBankItems(parent, text)
        end,
    })
    searchBox:SetPoint("BOTTOMLEFT", controlPanel, "BOTTOMLEFT", 10, 6)
    searchBox:SetPoint("BOTTOMRIGHT", controlPanel, "BOTTOMRIGHT", -10, 6)

    local bankViewPanel = OneWoW_GUI:CreateFrame(parent)
    bankViewPanel:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -8)
    bankViewPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 30)

    local bagScrollFrame, bagScrollContent = OneWoW_GUI:CreateScrollFrame(bankViewPanel)
    bagScrollFrame:ClearAllPoints()
    bagScrollFrame:SetPoint("TOPLEFT", bankViewPanel, "TOPLEFT", 10, -10)
    bagScrollFrame:SetPoint("BOTTOMRIGHT", bankViewPanel, "BOTTOMRIGHT", -10, 10)
    bagScrollFrame:Hide()
    local bagScrollBar = bagScrollFrame.ScrollBar

    local statusBar = OneWoW_GUI:CreateFrame(parent, { height = 25, bgColor = "BG_SECONDARY", borderColor = "BORDER_SUBTLE" })
    statusBar:SetPoint("TOPLEFT", bankViewPanel, "BOTTOMLEFT", 0, -5)
    statusBar:SetPoint("TOPRIGHT", bankViewPanel, "BOTTOMRIGHT", 0, -5)

    local statusText = OneWoW_GUI:CreateFS(statusBar, 10)
    statusText:SetPoint("LEFT", statusBar, "LEFT", 10, 0)
    statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    statusText:SetText(L["BANK_VIEWING"] .. ": " .. currentChar .. " - " .. L["BANK_PERSONAL"])

    parent.controlPanel = controlPanel
    parent.controlTitle = controlTitle
    parent.bankViewPanel = bankViewPanel
    parent.statusBar = statusBar
    parent.statusText = statusText
    parent.charDropdown = charDropdown
    parent.guildDropdown = guildDropdown
    parent.buttonContainer = buttonContainer
    parent.searchBox = searchBox
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

    parent:HookScript("OnHide", function()
        guildBankEventFrame:UnregisterAllEvents()
    end)
    parent:HookScript("OnShow", function()
        guildBankEventFrame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
        guildBankEventFrame:RegisterEvent("GUILDBANK_UPDATE_TABS")
    end)

    parent:SetScript("OnSizeChanged", function(self)
        if not self.bagScrollFrame then return end
        if self._bagResizeTimer then
            self._bagResizeTimer:Cancel()
            self._bagResizeTimer = nil
        end
        self._bagResizeTimer = C_Timer.NewTimer(1, function()
            self._bagResizeTimer = nil
            if ns.UI.RefreshBankDisplay then
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

    if parent.bagScrollFrame then parent.bagScrollFrame:Show() end
    if parent.bagScrollBar then parent.bagScrollBar:Show() end

    if parent.RebuildGuildDropdown and currentBankType == "guild" then
        parent.RebuildGuildDropdown()
    end

    ns.UI.CleanupBankFrames(parent)

    local bankData = ns.UI.GetBankData(selectedCharacterKey, currentBankType, selectedGuildName)
    local sortedItems = {}

    if bankData then
        if currentBankType == "bags" then
            if bankData.bags then
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
        elseif currentBankType == "personal" then
            if bankData.personalBank and bankData.personalBank.tabs then
                for _, tabData in pairs(bankData.personalBank.tabs) do
                    if tabData.items then
                        for _, itemData in pairs(tabData.items) do
                            if itemData and itemData.itemID then
                                table.insert(sortedItems, itemData)
                            end
                        end
                    end
                end
            end
        elseif currentBankType == "warband" then
            if bankData.warbandBank and bankData.warbandBank.tabs then
                for _, tabData in pairs(bankData.warbandBank.tabs) do
                    if tabData.items then
                        for _, itemData in pairs(tabData.items) do
                            if itemData and itemData.itemID then
                                table.insert(sortedItems, itemData)
                            end
                        end
                    end
                end
            end
        elseif currentBankType == "guild" then
            if bankData.guildBank and bankData.guildBank.tabs then
                for _, tabData in pairs(bankData.guildBank.tabs) do
                    if tabData.slots then
                        for _, itemData in pairs(tabData.slots) do
                            if itemData and itemData.itemID then
                                table.insert(sortedItems, itemData)
                            end
                        end
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

    parent._allItems = sortedItems

    if parent.searchBox then
        local searchText = parent.searchBox:GetSearchText()
        if searchText and searchText ~= "" then
            local filtered = {}
            local searchLower = searchText:lower()
            for _, itemData in ipairs(sortedItems) do
                if itemData.itemName and itemData.itemName:lower():find(searchLower, 1, true) then
                    table.insert(filtered, itemData)
                end
            end
            sortedItems = filtered
        end
    end

    ns.UI.DisplayOneBagGrid(parent, sortedItems)

    if parent.controlTitle then
        if currentBankType == "guild" and selectedGuildName then
            parent.controlTitle:SetText(selectedGuildName .. " - " .. L["BANK_GUILD"])
        else
            parent.controlTitle:SetText(charName .. " - " .. bankTypeName)
        end
    end

    if parent.statusText then
        parent.statusText:SetText(L["BANK_VIEWING"] .. ": " .. charName .. " - " .. bankTypeName .. " - " .. #sortedItems .. " " .. L["BANK_ITEMS"])
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

function ns.UI.FilterBankItems(parent, searchText)
    if not parent or not parent._allItems then return end

    local items = parent._allItems
    if searchText and searchText ~= "" then
        local filtered = {}
        local searchLower = searchText:lower()
        for _, itemData in ipairs(items) do
            if itemData.itemName and itemData.itemName:lower():find(searchLower, 1, true) then
                table.insert(filtered, itemData)
            end
        end
        items = filtered
    end

    ns.UI.CleanupBankFrames(parent)
    ns.UI.DisplayOneBagGrid(parent, items)

    local charName = selectedCharacterKey:match("([^-]+)") or selectedCharacterKey
    local bankTypeName = L["BANK_" .. currentBankType:upper()] or currentBankType
    if parent.statusText then
        parent.statusText:SetText(L["BANK_VIEWING"] .. ": " .. charName .. " - " .. bankTypeName .. " - " .. #items .. " " .. L["BANK_ITEMS"])
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

        itemFrame._itemInfo = itemData

        local itemTexture = C_Item.GetItemIconByID(itemData.itemID)
        OneWoW_GUI:UpdateIconTexture(itemFrame, itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
        OneWoW_GUI:UpdateIconQuality(itemFrame, itemData.quality)

        local stack = itemData.stackCount or itemData.count
        if itemFrame._countText then
            itemFrame._countText:SetText((stack and stack > 1) and tostring(stack) or "")
        end
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

local function SetupItemTooltipScripts(frame)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        if self._skinBorder then
            local q = self._skinQuality
            if not (q and q > 1) then
                self._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            end
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local info = self._itemInfo
        if info and info.itemID then
            if info.itemLink then
                GameTooltip:SetHyperlink(info.itemLink)
            else
                GameTooltip:SetItemByID(info.itemID)
            end
        else
            GameTooltip:SetText(L["BANK_EMPTY_SLOT"], 1, 1, 1)
            GameTooltip:AddLine(L["BANK_SLOT"] .. " " .. (self._slotIndex or 0), 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        if self._skinBorder then
            local q = self._skinQuality
            if q and q > 1 then
                self._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetItemQualityColor(q))
            else
                self._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            end
        end
        GameTooltip:Hide()
    end)
end

function ns.UI.GetBagItemFrame(parent)
    for _, pooledFrame in ipairs(parent.bagItemFramePool) do
        if pooledFrame and not pooledFrame:IsShown() then
            return pooledFrame
        end
    end

    local newFrame = OneWoW_GUI:CreateSkinnedIcon(parent.bagScrollContent, {
        size = 40,
        preset = "clean",
        showCount = true,
    })
    SetupItemTooltipScripts(newFrame)
    table.insert(parent.bagItemFramePool, newFrame)

    return newFrame
end

function ns.UI.CleanupBankFrames(parent)
    if not parent then return end

    if parent.bagItemFramePool then
        for _, itemFrame in ipairs(parent.bagItemFramePool) do
            if itemFrame then
                itemFrame:Hide()
                itemFrame:ClearAllPoints()
            end
        end
    end
end
