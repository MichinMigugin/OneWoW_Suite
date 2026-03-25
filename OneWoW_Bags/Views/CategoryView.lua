local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.CategoryView = {}
local View = OneWoW_Bags.CategoryView

local labelPool = {}
local activeLabels = {}

local function AcquireLabel(parent)
    local label
    if #labelPool > 0 then
        label = table.remove(labelPool)
        label:SetParent(parent)
    else
        label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
    end
    label:ClearAllPoints()
    label:Show()
    activeLabels[label] = true
    return label
end

local function ReleaseAllLabels()
    for label in pairs(activeLabels) do
        label:Hide()
        label:ClearAllPoints()
        table.insert(labelPool, label)
    end
    wipe(activeLabels)
end

function View:Layout(contentFrame, width, filteredButtons)
    local Constants = OneWoW_Bags.Constants
    local db = OneWoW_Bags.db
    local CM = OneWoW_Bags.CategoryManager
    local L = OneWoW_Bags.L

    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local padding = 2
    local compact = db.global.compactCategories

    local filterSet
    if filteredButtons then
        filterSet = {}
        for _, btn in ipairs(filteredButtons) do
            filterSet[btn] = true
        end
    end

    CM:AssignCategories()
    CM:ReleaseAllSections()
    ReleaseAllLabels()

    local itemsByCategory = CM:GetItemsByCategory()
    local layout = CM:GetSectionedLayout(itemsByCategory)

    local cols = db.global.bagColumns or math.floor((width - padding * 2) / (iconSize + spacing))
    cols = math.max(cols, 1)
    local cellSize = iconSize + spacing
    local totalGridWidth = cols * cellSize - spacing
    local leftPadding = math.max(padding, math.floor((width - totalGridWidth) / 2))

    local yOffset = 0

    local function T(key)
        if Constants and Constants.THEME and Constants.THEME[key] then
            return unpack(Constants.THEME[key])
        end
        return 0.5, 0.5, 0.5, 1.0
    end

    local function FilterItems(categoryName)
        local items = itemsByCategory[categoryName]
        if not items then return nil end
        if filterSet then
            local filtered = {}
            for _, btn in ipairs(items) do
                if filterSet[btn] then
                    table.insert(filtered, btn)
                end
            end
            items = filtered
        end
        if #items == 0 then return nil end
        OneWoW_Bags:SortButtons(items)
        return items
    end

    local function RenderCategoryStacked(categoryName)
        local items = FilterItems(categoryName)
        if not items then return end

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
            local itemRow = 0
            local itemCol = 0

            section.content:SetHeight(1)

            for _, button in ipairs(items) do
                local x = leftPadding + (itemCol * cellSize)
                local y = -(itemRow * cellSize)

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
            local contentHeight = totalRows * cellSize
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

    local gapSlots = 1
    local labelHeight = 16

    local function FlushGroupCompact(group)
        if #group == 0 then return end

        local lines = {}
        local currentLine = {}
        local curCol = 0

        for _, catInfo in ipairs(group) do
            local count = #catInfo.items
            local startCol = curCol > 0 and (curCol + gapSlots) or 0
            local avail = cols - startCol

            if avail < 1 then
                table.insert(lines, currentLine)
                currentLine = {}
                curCol = 0
                startCol = 0
                avail = cols
            end

            local blockWidth = math.min(count, avail)
            local blockRows = math.ceil(count / blockWidth)

            if blockRows > 2 and (curCol > 0 or blockWidth < cols) then
                if #currentLine > 0 then
                    table.insert(lines, currentLine)
                    currentLine = {}
                end
                curCol = 0
                startCol = 0
                blockWidth = math.min(count, cols)
                blockRows = math.ceil(count / blockWidth)
            end

            table.insert(currentLine, {
                name = catInfo.name,
                displayName = catInfo.displayName,
                items = catInfo.items,
                startCol = startCol,
                blockWidth = blockWidth,
                blockRows = blockRows,
            })

            if blockRows > 2 then
                table.insert(lines, currentLine)
                currentLine = {}
                curCol = 0
            else
                curCol = startCol + blockWidth
            end
        end
        if #currentLine > 0 then
            table.insert(lines, currentLine)
        end

        for _, line in ipairs(lines) do
            for _, cat in ipairs(line) do
                local label = AcquireLabel(contentFrame)
                label:SetPoint("TOPLEFT", contentFrame, "TOPLEFT",
                    leftPadding + cat.startCol * cellSize, -yOffset)
                label:SetWidth(cat.blockWidth * cellSize)
                label:SetText(cat.displayName)
                label:SetTextColor(T("ACCENT_PRIMARY"))
            end
            yOffset = yOffset + labelHeight

            local maxRows = 0
            for _, cat in ipairs(line) do
                if cat.blockRows > maxRows then maxRows = cat.blockRows end
                local itemCol = 0
                local itemRow = 0
                for _, button in ipairs(cat.items) do
                    local x = leftPadding + (cat.startCol + itemCol) * cellSize
                    local y = -(yOffset + itemRow * cellSize)

                    button:ClearAllPoints()
                    button:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, y)
                    button:OWB_SetIconSize(iconSize)
                    button:Show()

                    itemCol = itemCol + 1
                    if itemCol >= cat.blockWidth then
                        itemCol = 0
                        itemRow = itemRow + 1
                    end
                end
            end
            yOffset = yOffset + maxRows * cellSize
        end
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

    local function BuildCatInfo(categoryName)
        local items = FilterItems(categoryName)
        if not items then return nil end
        local localeKey = "CAT_" .. string.upper(string.gsub(categoryName, "%s+", "_"))
        local displayName = L[localeKey] or categoryName
        return { name = categoryName, displayName = displayName, items = items }
    end

    if type(layout) == "table" and layout[1] and type(layout[1]) == "table" then
        if compact then
            local currentGroup = {}
            for _, entry in ipairs(layout) do
                if entry.type == "category" then
                    local catInfo = BuildCatInfo(entry.name)
                    if catInfo then
                        table.insert(currentGroup, catInfo)
                    end
                elseif entry.type == "separator" then
                    FlushGroupCompact(currentGroup)
                    currentGroup = {}
                    if entry.showHeader then
                        RenderSeparator()
                    end
                elseif entry.type == "section_header" then
                    FlushGroupCompact(currentGroup)
                    currentGroup = {}
                    if entry.showHeader then
                        RenderSectionHeader(entry)
                    end
                end
            end
            FlushGroupCompact(currentGroup)
        else
            for _, entry in ipairs(layout) do
                if entry.type == "category" then
                    RenderCategoryStacked(entry.name)
                elseif entry.type == "separator" then
                    if entry.showHeader then
                        RenderSeparator()
                    end
                elseif entry.type == "section_header" then
                    if entry.showHeader then
                        RenderSectionHeader(entry)
                    end
                end
            end
        end
    else
        if compact then
            local currentGroup = {}
            for _, categoryName in ipairs(layout) do
                local catInfo = BuildCatInfo(categoryName)
                if catInfo then
                    table.insert(currentGroup, catInfo)
                end
            end
            FlushGroupCompact(currentGroup)
        else
            for _, categoryName in ipairs(layout) do
                RenderCategoryStacked(categoryName)
            end
        end
    end

    return math.max(yOffset, 100)
end
