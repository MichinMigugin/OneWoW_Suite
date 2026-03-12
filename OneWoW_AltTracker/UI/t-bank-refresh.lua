local addonName, ns = ...
local L = ns.L
local T = ns.T
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

-- APIs removed, using direct DB access


ns.UI = ns.UI or {}

local characterRows = {}

function ns.UI.RefreshBankTab(bankTab)
    if not bankTab then
        return
    end

    if not _G.OneWoW_AltTracker_Character_DB then
        return
    end

    if not _G.OneWoW_AltTracker_Storage_DB then
        return
    end

    local allChars = do local t={}; for k,d in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do table.insert(t,{key=k,data=d}) end; return t end)()

    if not allChars or #allChars == 0 then
        return
    end

    local scrollContent = bankTab.scrollContent
    if not scrollContent then return end

    for _, row in ipairs(characterRows) do
        if row.expandedFrame then
            row.expandedFrame:Hide()
            row.expandedFrame = nil
        end
        row:Hide()
        row:SetParent(nil)
    end
    wipe(characterRows)

    local yOffset = -5
    local rowHeight = 32
    local rowGap = 2

    for charIndex, charInfo in ipairs(allChars) do
        local charKey = charInfo.key
        local charData = charInfo.data

        local charRow = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        charRow:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, yOffset)
        charRow:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -10, yOffset)
        charRow:SetHeight(rowHeight)
        charRow:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SIMPLE)
        charRow:SetBackdropColor(T("BG_TERTIARY"))
        charRow.charKey = charKey
        charRow.cells = {}

        local expandBtn = CreateFrame("Button", nil, charRow)
        expandBtn:SetSize(25, rowHeight)
        local expandIcon = expandBtn:CreateTexture(nil, "ARTWORK")
        expandIcon:SetSize(14, 14)
        expandIcon:SetPoint("CENTER")
        expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
        expandBtn.icon = expandIcon
        table.insert(charRow.cells, expandBtn)

        local function ToggleExpanded()
            local isExpanded = charRow.isExpanded or false
            charRow.isExpanded = not isExpanded

            if charRow.isExpanded then
                expandIcon:SetAtlas("Gamepad_Rev_Minus_64")
                if not charRow.expandedFrame then
                    charRow.expandedFrame = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
                    charRow.expandedFrame:SetPoint("TOPLEFT", charRow, "BOTTOMLEFT", 0, -2)
                    charRow.expandedFrame:SetPoint("TOPRIGHT", charRow, "BOTTOMRIGHT", 0, -2)
                    charRow.expandedFrame:SetHeight(80)
                    charRow.expandedFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SIMPLE)
                    charRow.expandedFrame:SetBackdropColor(T("BG_SECONDARY"))

                    local leftCol = charRow.expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    leftCol:SetPoint("LEFT", charRow.expandedFrame, "LEFT", 15, 0)
                    leftCol:SetJustifyH("LEFT")
                    leftCol:SetTextColor(T("TEXT_PRIMARY"))

                    local rightCol = charRow.expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    rightCol:SetPoint("LEFT", charRow.expandedFrame, "CENTER", 15, 0)
                    rightCol:SetJustifyH("LEFT")
                    rightCol:SetTextColor(T("TEXT_PRIMARY"))

                    local bagsData = StorageAPI.GetBags(charKey)
                    local bankData = StorageAPI.GetPersonalBank(charKey)
                    local warbandData = StorageAPI.GetWarbandBank(charKey)
                    local guildBankData = StorageAPI.GetGuildBank(charKey)

                    local bagItemCount = 0
                    if bagsData then
                        for bagID, bagInfo in pairs(bagsData) do
                            if bagInfo.slots then
                                for slotID, itemData in pairs(bagInfo.slots) do
                                    if itemData then
                                        bagItemCount = bagItemCount + 1
                                    end
                                end
                            end
                        end
                    end

                    local bankItemCount = 0
                    if bankData then
                        for bagID, bagInfo in pairs(bankData) do
                            if bagInfo.slots then
                                for slotID, itemData in pairs(bagInfo.slots) do
                                    if itemData then
                                        bankItemCount = bankItemCount + 1
                                    end
                                end
                            end
                        end
                    end

                    local warbandItemCount = 0
                    if warbandData and warbandData.tabs then
                        for tabID, tabInfo in pairs(warbandData.tabs) do
                            if tabInfo.slots then
                                for slotID, itemData in pairs(tabInfo.slots) do
                                    if itemData then
                                        warbandItemCount = warbandItemCount + 1
                                    end
                                end
                            end
                        end
                    end

                    local guildBankItemCount = 0
                    if guildBankData and guildBankData.tabs then
                        for tabID, tabInfo in pairs(guildBankData.tabs) do
                            if tabInfo.slots then
                                for slotID, itemData in pairs(tabInfo.slots) do
                                    if itemData then
                                        guildBankItemCount = guildBankItemCount + 1
                                    end
                                end
                            end
                        end
                    end

                    leftCol:SetText(string.format("%s %d\n%s %d",
                        L["EXPANDED_BAG_ITEMS"], bagItemCount,
                        L["EXPANDED_BANK_ITEMS"], bankItemCount))

                    rightCol:SetText(string.format("%s %d\n%s %d",
                        L["EXPANDED_WARBAND_ITEMS"], warbandItemCount,
                        L["EXPANDED_GUILD_BANK_ITEMS"], guildBankItemCount))

                    charRow.expandedFrame.leftCol = leftCol
                    charRow.expandedFrame.rightCol = rightCol
                end
                charRow.expandedFrame:Show()
            else
                expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
                if charRow.expandedFrame then
                    charRow.expandedFrame:Hide()
                end
            end
        end

        expandBtn:SetScript("OnClick", ToggleExpanded)

        local factionIcon = charRow:CreateTexture(nil, "ARTWORK")
        factionIcon:SetSize(18, 18)
        if charData.faction == "Alliance" then
            factionIcon:SetTexture("Interface\\FriendsFrame\\PlusManz-Alliance")
        elseif charData.faction == "Horde" then
            factionIcon:SetTexture("Interface\\FriendsFrame\\PlusManz-Horde")
        else
            factionIcon:SetTexture("Interface\\FriendsFrame\\PlusManz-Alliance")
            factionIcon:SetDesaturated(true)
        end
        table.insert(charRow.cells, factionIcon)

        local nameText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetText(charData.name or charKey)
        local classColor = RAID_CLASS_COLORS[charData.class]
        if classColor then
            nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            nameText:SetTextColor(1, 1, 1)
        end
        nameText:SetJustifyH("LEFT")
        table.insert(charRow.cells, nameText)

        local levelText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        levelText:SetText(tostring(charData.level or 0))
        levelText:SetTextColor(T("TEXT_PRIMARY"))
        table.insert(charRow.cells, levelText)

        local bagsText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local bagsFree, bagsTotal = 0, 0
        if StorageAPI then
            local bagsData = StorageAPI.GetBags(charKey)
            if bagsData then
                for bagID = 0, 4 do
                    if bagsData[bagID] then
                        local numSlots = bagsData[bagID].numSlots or 0
                        bagsTotal = bagsTotal + numSlots

                        local usedSlots = 0
                        if bagsData[bagID].slots then
                            for slotID, itemData in pairs(bagsData[bagID].slots) do
                                if itemData then
                                    usedSlots = usedSlots + 1
                                end
                            end
                        end
                        bagsFree = bagsFree + (numSlots - usedSlots)
                    end
                end
            end
        end
        bagsText:SetText(bagsFree .. "/" .. bagsTotal)
        bagsText:SetTextColor(0.3, 1, 0.3)
        table.insert(charRow.cells, bagsText)

        local bankText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local bankFree, bankTotal = 0, 0
        if StorageAPI then
            local bankData = StorageAPI.GetPersonalBank(charKey)
            if bankData then
                for bagID = -1, 11 do
                    if bankData[bagID] then
                        local numSlots = bankData[bagID].numSlots or 0
                        bankTotal = bankTotal + numSlots

                        local usedSlots = 0
                        if bankData[bagID].slots then
                            for slotID, itemData in pairs(bankData[bagID].slots) do
                                if itemData then
                                    usedSlots = usedSlots + 1
                                end
                            end
                        end
                        bankFree = bankFree + (numSlots - usedSlots)
                    end
                end
            end
        end
        bankText:SetText(bankFree .. "/" .. bankTotal)
        bankText:SetTextColor(0.67, 0.83, 0.94)
        table.insert(charRow.cells, bankText)

        local warbandText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local warbandFree, warbandTotal = 0, 0
        if StorageAPI then
            local warbandData = StorageAPI.GetWarbandBank(charKey)
            if warbandData and warbandData.tabs then
                for tabID, tabInfo in pairs(warbandData.tabs) do
                    local numSlots = tabInfo.numSlots or 0
                    warbandTotal = warbandTotal + numSlots

                    local usedSlots = 0
                    if tabInfo.slots then
                        for slotID, itemData in pairs(tabInfo.slots) do
                            if itemData then
                                usedSlots = usedSlots + 1
                            end
                        end
                    end
                    warbandFree = warbandFree + (numSlots - usedSlots)
                end
            end
        end
        warbandText:SetText(warbandFree .. "/" .. warbandTotal)
        warbandText:SetTextColor(1, 0.84, 0)
        table.insert(charRow.cells, warbandText)

        local guildBankText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local guildBankFree, guildBankTotal = 0, 0
        if StorageAPI then
            local guildBankData = StorageAPI.GetGuildBank(charKey)
            if guildBankData and guildBankData.tabs then
                for tabID, tabInfo in pairs(guildBankData.tabs) do
                    local numSlots = tabInfo.numSlots or 0
                    guildBankTotal = guildBankTotal + numSlots

                    local usedSlots = 0
                    if tabInfo.slots then
                        for slotID, itemData in pairs(tabInfo.slots) do
                            if itemData then
                                usedSlots = usedSlots + 1
                            end
                        end
                    end
                    guildBankFree = guildBankFree + (numSlots - usedSlots)
                end
            end
        end
        guildBankText:SetText(guildBankFree .. "/" .. guildBankTotal)
        guildBankText:SetTextColor(0.5, 1, 0.5)
        table.insert(charRow.cells, guildBankText)

        local charGoldText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local money = charData.money or 0
        local goldFormatted = CharacterAPI.FormatMoney(money)
        charGoldText:SetText(goldFormatted)
        charGoldText:SetTextColor(1, 0.82, 0)
        charGoldText:SetJustifyH("RIGHT")
        table.insert(charRow.cells, charGoldText)

        local warbandGoldText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local warbandGold = StorageAPI.GetWarbandBankGold(charKey)
        local warbandGoldFormatted = CharacterAPI.FormatMoney(warbandGold)
        warbandGoldText:SetText(warbandGoldFormatted)
        warbandGoldText:SetTextColor(1, 0.84, 0)
        warbandGoldText:SetJustifyH("RIGHT")
        table.insert(charRow.cells, warbandGoldText)

        local guildGoldText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local guildGold = StorageAPI.GetGuildBankGold(charKey)
        local guildGoldFormatted = CharacterAPI.FormatMoney(guildGold)
        guildGoldText:SetText(guildGoldFormatted)
        guildGoldText:SetTextColor(0.5, 1, 0.5)
        guildGoldText:SetJustifyH("RIGHT")
        table.insert(charRow.cells, guildGoldText)

        charRow:EnableMouse(true)
        charRow:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
        end)

        charRow:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_TERTIARY"))
        end)

        charRow:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                ToggleExpanded()
            end
        end)

        local headerRow = bankTab.headerRow
        if headerRow and headerRow.columnButtons then
            for i, cell in ipairs(charRow.cells) do
                local btn = headerRow.columnButtons[i]
                if btn and btn.columnWidth and btn.columnX then
                    local width = btn.columnWidth
                    local x = btn.columnX

                    cell:ClearAllPoints()

                    if i == 1 then
                        cell:SetSize(width, rowHeight)
                        cell:SetPoint("LEFT", charRow, "LEFT", x, 0)
                    elseif i == 2 then
                        cell:SetPoint("CENTER", charRow, "LEFT", x + width/2, 0)
                    else
                        cell:SetWidth(width - 6)
                        if i == 3 then
                            cell:SetPoint("LEFT", charRow, "LEFT", x + 3, 0)
                        elseif i == 8 or i == 9 or i == 10 then
                            cell:SetPoint("RIGHT", charRow, "LEFT", x + width - 3, 0)
                        else
                            cell:SetPoint("CENTER", charRow, "LEFT", x + width/2, 0)
                        end
                    end
                end
            end
        end

        charRow:Show()
        table.insert(characterRows, charRow)
        yOffset = yOffset - (rowHeight + rowGap)
    end

    local newHeight = math.max(400, #characterRows * (rowHeight + rowGap) + 10)
    scrollContent:SetHeight(newHeight)

    if bankTab.statusText then
        bankTab.statusText:SetText(string.format(L["CHARACTERS_TRACKED"], #allChars, ""))
    end

    ns.UI.ApplyFontToFrame(bankTab)

    C_Timer.After(0.1, function()
        if bankTab.headerRow then
            bankTab.headerRow:GetScript("OnSizeChanged")(bankTab.headerRow)
        end
    end)
end
