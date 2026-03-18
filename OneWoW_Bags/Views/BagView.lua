local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BagView = {}
local View = OneWoW_Bags.BagView

function View:Layout(contentFrame, width, filteredButtons)
    local Constants = OneWoW_Bags.Constants
    local BagTypes = OneWoW_Bags.BagTypes
    local BagSet = OneWoW_Bags.BagSet
    local db = OneWoW_Bags.db
    local L = OneWoW_Bags.L
    local CM = OneWoW_Bags.CategoryManager

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

    local selectedBag = db.global.selectedBag
    local yOffset = 0

    local function T(key)
        if Constants and Constants.THEME and Constants.THEME[key] then
            return unpack(Constants.THEME[key])
        end
        return 0.5, 0.5, 0.5, 1.0
    end

    for _, bagID in ipairs(BagTypes.ALL_PLAYER_BAGS) do
        local buttons = BagSet:GetButtonsByBag(bagID)
        if selectedBag ~= nil and bagID ~= selectedBag then
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
        if #buttons > 0 and (selectedBag == nil or bagID == selectedBag) then
            OneWoW_Bags:SortButtons(buttons)
            local section = CM:AcquireSection(contentFrame)
            section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
            section:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
            section:SetBackdropColor(T("BG_SECONDARY"))
            section:SetBackdropBorderColor(T("BORDER_SUBTLE"))

            local bagName = BagTypes:GetBagName(bagID)
            local displayName = L[bagName] or bagName
            section.title:SetText(displayName)
            section.title:SetTextColor(T("ACCENT_PRIMARY"))
            section.count:SetText(tostring(#buttons))
            section.count:SetTextColor(T("TEXT_MUTED"))

            local collapsed = db.global.collapsedBagSections[bagID]
            section.isCollapsed = collapsed or false

            local sectionHeight = 26

            if not section.isCollapsed then
                local cols = db.global.bagColumns or math.floor((width - padding * 2) / (iconSize + spacing))
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
                db.global.collapsedBagSections[bagID] = section.isCollapsed or nil
                if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then
                    OneWoW_Bags.GUI:RefreshLayout()
                end
            end)
        end
    end

    return math.max(yOffset, 100)
end
