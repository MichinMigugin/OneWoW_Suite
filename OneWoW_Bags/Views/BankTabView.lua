local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local BankSet = OneWoW_Bags.BankSet
local BankTypes = OneWoW_Bags.BankTypes

local tinsert, ipairs = tinsert, ipairs
local floor, max = math.floor, math.max

OneWoW_Bags.BankTabView = {}
local View = OneWoW_Bags.BankTabView

local function GetDB()
    return OneWoW_Bags:GetDB()
end

function View:Layout(contentFrame, width, filteredButtons, viewContext)
    local db = GetDB()
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

    local sortButtons = viewContext.sortButtons
    local acquireSection = viewContext.acquireSection
    local getCollapsed = viewContext.getCollapsed
    local setCollapsed = viewContext.setCollapsed

    local BC = OneWoW_Bags.BankController
    local selectedTab = BC:Get("selectedTab")
    local showWarband = BankSet:IsWarband()
    local bagList = showWarband and BankTypes:GetWarbandTabIDs() or BankTypes:GetBankTabIDs()
    local bankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
    local tabDataList = C_Bank.FetchPurchasedBankTabData(bankType)

    local yOffset = 0

    for tabIdx, bagID in ipairs(bagList) do
        local buttons = BankSet:GetButtonsByBag(bagID)
        local skip = (#buttons == 0)

        if not skip and selectedTab ~= nil and bagID ~= selectedTab then
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
                sortButtons(buttons)
                local section = acquireSection(contentFrame)
                section:ClearAllPoints()
                section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
                section:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
                section:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                section:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

                local tabName = L["BANK_TAB"]:format(tabIdx)
                if tabDataList and tabDataList[tabIdx] and tabDataList[tabIdx].name and tabDataList[tabIdx].name ~= "" then
                    tabName = tabDataList[tabIdx].name
                end

                section.title:SetText(tabName)
                section.title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                section.count:SetText(tostring(#buttons))
                section.count:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

                local collapsed = getCollapsed("tab", bagID)
                section.isCollapsed = collapsed or false

                section.collapseBtn.icon:SetAtlas(section.isCollapsed and "uitools-icon-chevron-right" or "uitools-icon-chevron-down")
                section.collapseBtn.icon:SetVertexColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))

                local sectionHeight = 26

                if not section.isCollapsed then
                    local cols = BC:Get("columns") or floor((width - padding * 2) / (iconSize + spacing))
                    cols = max(cols, 1)

                    local totalGridWidth = cols * (iconSize + spacing) - spacing
                    local leftPadding = max(padding, floor((width - totalGridWidth) / 2))

                    local itemRow = 0
                    local itemCol = 0

                    section.content:SetHeight(1)

                    for _, button in ipairs(buttons) do
                        local x = leftPadding + (itemCol * (iconSize + spacing))
                        local y = -(itemRow * (iconSize + spacing))

                        button:ClearAllPoints()
                        OneWoW_Bags.WindowHelpers:SetPointPixelAligned(button, section.content, x, y)
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

                local capturedBagID = bagID
                section.header:SetScript("OnClick", nil)
                section.collapseBtn:SetScript("OnClick", function()
                    section.isCollapsed = not section.isCollapsed
                    setCollapsed("tab", capturedBagID, section.isCollapsed)
                end)
            end
        end
    end

    return max(yOffset, 100)
end
