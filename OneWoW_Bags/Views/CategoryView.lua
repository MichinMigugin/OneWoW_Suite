local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.CategoryView = {}
local View = OneWoW_Bags.CategoryView

function View:Layout(contentFrame, width, filteredButtons)
    local Constants = OneWoW_Bags.Constants
    local db = OneWoW_Bags.db
    local CM = OneWoW_Bags.CategoryManager
    local L = OneWoW_Bags.L

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

    CM:AssignCategories()
    CM:ReleaseAllSections()

    local itemsByCategory = CM:GetItemsByCategory()
    local layout = CM:GetSectionedLayout(itemsByCategory)

    local yOffset = 0

    local function T(key)
        if Constants and Constants.THEME and Constants.THEME[key] then
            return unpack(Constants.THEME[key])
        end
        return 0.5, 0.5, 0.5, 1.0
    end

    local function RenderCategory(categoryName)
        local items = itemsByCategory[categoryName]
        if items and filterSet then
            local filtered = {}
            for _, btn in ipairs(items) do
                if filterSet[btn] then
                    table.insert(filtered, btn)
                end
            end
            items = filtered
        end
        if not items or #items == 0 then return end

        OneWoW_Bags:SortButtons(items)
        local section = CM:AcquireSection(contentFrame)
        section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
        section:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
        section:SetBackdropColor(T("BG_SECONDARY"))
        section:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local localeKey = "CAT_" .. string.upper(string.gsub(categoryName, "%s+", "_"))
        local displayName = L[localeKey] or categoryName
        section.title:SetText(displayName)
        section.title:SetTextColor(T("ACCENT_PRIMARY"))
        section.count:SetText(tostring(#items))
        section.count:SetTextColor(T("TEXT_MUTED"))

        local collapsed = db.global.collapsedSections[categoryName]
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

            for _, button in ipairs(items) do
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
            for _, button in ipairs(items) do
                button:Hide()
            end
        end

        section:SetHeight(sectionHeight)
        yOffset = yOffset + sectionHeight + 4

        local capturedName = categoryName
        section.header:SetScript("OnClick", function()
            section.isCollapsed = not section.isCollapsed
            db.global.collapsedSections[capturedName] = section.isCollapsed or nil
            if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then
                OneWoW_Bags.GUI:RefreshLayout()
            end
        end)
    end

    local function RenderSeparator()
        local divider = CM:AcquireDivider(contentFrame)
        divider:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 8, -(yOffset + 4))
        divider:SetPoint("RIGHT", contentFrame, "RIGHT", -8, 0)
        divider:SetColorTexture(T("BORDER_SUBTLE"))
        divider:Show()
        yOffset = yOffset + 10
    end

    local function RenderSectionHeader(entry)
        local sectionID = entry.sectionID
        local sectionName = entry.name
        local isCollapsed = entry.collapsed

        local section = CM:AcquireSectionHeader(contentFrame)
        section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
        section:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
        section:SetBackdropColor(T("BG_PRIMARY"))
        section:SetBackdropBorderColor(T("BORDER_DEFAULT"))

        section.title:SetText(sectionName)
        section.title:SetTextColor(T("ACCENT_SECONDARY"))
        section.count:SetText(isCollapsed and ">" or "")
        section.count:SetTextColor(T("TEXT_MUTED"))

        section.content:Hide()
        section:SetHeight(24)
        yOffset = yOffset + 26

        local capturedSectionID = sectionID
        section.header:SetScript("OnClick", function()
            local sec = db.global.categorySections and db.global.categorySections[capturedSectionID]
            if sec then
                sec.collapsed = not sec.collapsed
                if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then
                    OneWoW_Bags.GUI:RefreshLayout()
                end
            end
        end)
    end

    if type(layout) == "table" and layout[1] and type(layout[1]) == "table" then
        for _, entry in ipairs(layout) do
            if entry.type == "category" then
                RenderCategory(entry.name)
            elseif entry.type == "separator" then
                RenderSeparator()
            elseif entry.type == "section_header" then
                RenderSectionHeader(entry)
            end
        end
    else
        for _, categoryName in ipairs(layout) do
            RenderCategory(categoryName)
        end
    end

    return math.max(yOffset, 100)
end
