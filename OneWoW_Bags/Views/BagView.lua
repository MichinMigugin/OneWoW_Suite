local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local BagTypes = OneWoW_Bags.BagTypes
local BagSet = OneWoW_Bags.BagSet

local ipairs, tinsert = ipairs, tinsert
local floor, max = math.floor, math.max

OneWoW_Bags.BagView = {}
local View = OneWoW_Bags.BagView

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

    local selectedBag = db.global.selectedBag
    local yOffset = 0

    for _, bagID in ipairs(BagTypes:GetPlayerBagIDs()) do
        local buttons = BagSet:GetButtonsByBag(bagID)
        if selectedBag ~= nil and bagID ~= selectedBag then
            for _, button in ipairs(buttons) do button:Hide() end
        end
        if filterSet then
            local filtered = {}
            for _, btn in ipairs(buttons) do
                if filterSet[btn] then
                    tinsert(filtered, btn)
                end
            end
            buttons = filtered
        end
        if #buttons > 0 and (selectedBag == nil or bagID == selectedBag) then
            sortButtons(buttons)
            local section = acquireSection(contentFrame)
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
            section:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
            section:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            section:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

            local bagName = BagTypes:GetBagName(bagID)
            local displayName = L[bagName] or bagName
            section.title:SetText(displayName)
            section.title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            section.count:SetText(tostring(#buttons))
            section.count:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

            local collapsed = getCollapsed("bag", bagID)
            section.isCollapsed = collapsed or false

            local sectionHeight = 26

            if not section.isCollapsed then
                local cols = db.global.bagColumns or floor((width - padding * 2) / (iconSize + spacing))
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

            section.header:SetScript("OnClick", function()
                section.isCollapsed = not section.isCollapsed
                setCollapsed("bag", bagID, section.isCollapsed)
            end)
        end
    end

    return max(yOffset, 100)
end
