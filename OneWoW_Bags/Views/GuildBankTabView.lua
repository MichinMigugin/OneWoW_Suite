local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_Bags.GuildBankTabView = {}
local View = OneWoW_Bags.GuildBankTabView

function View:Layout(contentFrame, width, filteredButtons)
    local Constants = OneWoW_Bags.Constants
    local GBSet = OneWoW_Bags.GuildBankSet
    local db = OneWoW_Bags.db
    local L = OneWoW_Bags.L
    local CM = OneWoW_Bags.GuildBankCategoryManager

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

    local selectedTab = db.global.guildBankSelectedTab
    local yOffset = 0

    for tabID = 1, GBSet.numTabs do
        local buttons = GBSet:GetButtonsByTab(tabID)
        local skip = (#buttons == 0)

        if not skip and selectedTab ~= nil and tabID ~= selectedTab then
            for _, button in ipairs(buttons) do
                button:Hide()
            end
            skip = true
        end

        if not skip then
            if filterSet then
                local filtered = {}
                for _, btn in ipairs(buttons) do
                    if filterSet[btn] then
                        tinsert(filtered, btn)
                    end
                end
                buttons = filtered
            end

            if #buttons > 0 then
                OneWoW_Bags:SortButtons(buttons)
                local section = CM:AcquireSection(contentFrame)
                section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
                section:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
                section:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                section:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

                local tabName = GetGuildBankTabInfo(tabID)
                if not tabName or tabName == "" then
                    tabName = L["GUILD_BANK_TAB"] and L["GUILD_BANK_TAB"]:format(tabID) or ("Tab " .. tabID)
                end

                section.title:SetText(tabName)
                section.title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                section.count:SetText(tostring(#buttons))
                section.count:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

                local collapsed = db.global.collapsedGuildBankSections and db.global.collapsedGuildBankSections[tabID]
                section.isCollapsed = collapsed or false

                local sectionHeight = 26

                if not section.isCollapsed then
                    local cols = db.global.bankColumns or math.floor((width - padding * 2) / (iconSize + spacing))
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

                local capturedTabID = tabID
                section.header:SetScript("OnClick", function()
                    section.isCollapsed = not section.isCollapsed
                    if not db.global.collapsedGuildBankSections then
                        db.global.collapsedGuildBankSections = {}
                    end
                    db.global.collapsedGuildBankSections[capturedTabID] = section.isCollapsed or nil
                    if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.RefreshLayout then
                        OneWoW_Bags.GuildBankGUI:RefreshLayout()
                    end
                end)
            end
        end
    end

    return math.max(yOffset, 100)
end
