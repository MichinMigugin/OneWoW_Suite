local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BankTabView = {}
local View = OneWoW_Bags.BankTabView

function View:Layout(contentFrame, width, filteredButtons)
    local Constants = OneWoW_Bags.Constants
    local BagTypes = OneWoW_Bags.BagTypes
    local BankSet = OneWoW_Bags.BankSet
    local db = OneWoW_Bags.db
    local L = OneWoW_Bags.L
    local CM = OneWoW_Bags.BankCategoryManager

    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local padding = 2

    local filterSet
    if filteredButtons then
        filterSet = {}
        for _, btn in ipairs(filteredButtons) do
            filterSet[btn] = true
        end
    end

    CM:ReleaseAllSections()

    local selectedTab = db.global.bankSelectedTab
    local showWarband = db.global.bankShowWarband
    local bagList = showWarband and BagTypes.WARBAND_BAGS or BagTypes.BANK_BAGS
    local yOffset = 0

    local function T(key)
        if Constants and Constants.THEME and Constants.THEME[key] then
            return unpack(Constants.THEME[key])
        end
        return 0.5, 0.5, 0.5, 1.0
    end

    for tabIdx, bagID in ipairs(bagList) do
        local buttons = BankSet:GetButtonsByBag(bagID)
        if selectedTab ~= nil and bagID ~= selectedTab then
            for _, button in ipairs(buttons) do button:Hide() end
        end
        if filterSet then
            local filtered = {}
            for _, btn in ipairs(buttons) do
                if filterSet[btn] then
                    table.insert(filtered, btn)
                end
            end
            buttons = filtered
        end
        if #buttons > 0 and (selectedTab == nil or bagID == selectedTab) then
            local section = CM:AcquireSection(contentFrame)
            section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
            section:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
            section:SetBackdropColor(T("BG_SECONDARY"))
            section:SetBackdropBorderColor(T("BORDER_SUBTLE"))

            local tabName = L["BANK_TAB"]:format(tabIdx)
            if OneWoW_Bags.bankOpen then
                local bankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
                local tabDataList = C_Bank.FetchPurchasedBankTabData(bankType)
                if tabDataList and tabDataList[tabIdx] and tabDataList[tabIdx].name and tabDataList[tabIdx].name ~= "" then
                    tabName = tabDataList[tabIdx].name
                end
            end

            section.title:SetText(tabName)
            section.title:SetTextColor(T("ACCENT_PRIMARY"))
            section.count:SetText(tostring(#buttons))
            section.count:SetTextColor(T("TEXT_MUTED"))

            local collapsed = db.global.collapsedBankSections[bagID]
            section.isCollapsed = collapsed or false

            local sectionHeight = 26

            if not section.isCollapsed then
                local cols = math.floor((width - padding * 2) / (iconSize + spacing))
                cols = math.max(cols, 1)

                local totalGridWidth = cols * (iconSize + spacing) - spacing
                local leftPadding = math.max(padding, math.floor((width - totalGridWidth) / 2))

                local itemRow = 0
                local itemCol = 0

                section.content:SetHeight(1)

                for _, button in ipairs(buttons) do
                    local x = leftPadding + (itemCol * (iconSize + spacing))
                    local y = -(itemRow * (iconSize + spacing))

                    button:ClearAllPoints()
                    button:SetPoint("TOPLEFT", section.content, "TOPLEFT", x, y)
                    button:OWB_SetIconSize(iconSize)
                    button:Show()

                    itemCol = itemCol + 1
                    if itemCol >= cols then
                        itemCol = 0
                        itemRow = itemRow + 1
                    end
                end

                local totalRows = (itemCol > 0) and (itemRow + 1) or itemRow
                local contentHeight = totalRows * (iconSize + spacing)
                section.content:SetHeight(contentHeight)
                section.content:Show()

                sectionHeight = sectionHeight + contentHeight + 4
            else
                section.content:Hide()
                for _, button in ipairs(buttons) do
                    button:Hide()
                end
            end

            section:SetHeight(sectionHeight)
            yOffset = yOffset + sectionHeight + 4

            section.header:SetScript("OnClick", function()
                section.isCollapsed = not section.isCollapsed
                db.global.collapsedBankSections[bagID] = section.isCollapsed or nil
                if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
                    OneWoW_Bags.BankGUI:RefreshLayout()
                end
            end)
        end
    end

    return math.max(yOffset, 100)
end
