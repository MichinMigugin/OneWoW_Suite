local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_Bags.CategoryView = {}
local View = OneWoW_Bags.CategoryView

local labelPool = {}
local activeLabels = {}

local function AcquireLabel(parent)
    local label
    if #labelPool > 0 then
        label = tremove(labelPool)
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
        tinsert(labelPool, label)
    end
    wipe(activeLabels)
end

function View:Layout(contentFrame, width, filteredButtons, containerType)
    local Constants = OneWoW_Bags.Constants
    local db = OneWoW_Bags.db
    local CM = OneWoW_Bags.CategoryManager
    local L = OneWoW_Bags.L

    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local padding = 2
    local compact = db.global.compactCategories
    local showHeaders = db.global.showCategoryHeaders ~= false
    local verticalSpacing = (db.global.categorySpacing or 1.0)
    local compactGapSlots = db.global.compactGap or 1

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
    local layout = CM:GetSectionedLayout(itemsByCategory, containerType)

    local moveUpgradesToTop = db.global.moveUpgradesToTop
    local moveOtherToBottom = db.global.moveOtherToBottom
    if moveUpgradesToTop or moveOtherToBottom then
        local pinRecent, pinUpgrades, pinBottom, rest = {}, {}, {}, {}
        if type(layout[1]) == "table" then
            for _, entry in ipairs(layout) do
                if entry.type == "category" and entry.name == "Recent Items" and moveUpgradesToTop then
                    tinsert(pinRecent, entry)
                elseif entry.type == "category" and entry.name == "1W Upgrades" and moveUpgradesToTop then
                    tinsert(pinUpgrades, entry)
                elseif entry.type == "category" and entry.name == "Other" and moveOtherToBottom then
                    tinsert(pinBottom, entry)
                else
                    tinsert(rest, entry)
                end
            end
        else
            for _, name in ipairs(layout) do
                if name == "Recent Items" and moveUpgradesToTop then
                    tinsert(pinRecent, name)
                elseif name == "1W Upgrades" and moveUpgradesToTop then
                    tinsert(pinUpgrades, name)
                elseif name == "Other" and moveOtherToBottom then
                    tinsert(pinBottom, name)
                else
                    tinsert(rest, name)
                end
            end
        end
        layout = {}
        for _, e in ipairs(pinRecent)   do tinsert(layout, e) end
        for _, e in ipairs(pinUpgrades) do tinsert(layout, e) end
        for _, e in ipairs(rest)        do tinsert(layout, e) end
        for _, e in ipairs(pinBottom)   do tinsert(layout, e) end
    end

    local cols = db.global.bagColumns or math.floor((width - padding * 2) / (iconSize + spacing))
    cols = math.max(cols, 1)
    local cellSize = iconSize + spacing
    local totalGridWidth = cols * cellSize - spacing
    local leftPadding = math.max(padding, math.floor((width - totalGridWidth) / 2))

    local yOffset = 0

    local catMods = db.global.categoryModifications or {}
    local SE = OneWoW_Bags.SearchEngine

    local function GetCategorySortMode(categoryName)
        local mod = catMods[categoryName]
        if mod and mod.sortMode then return mod.sortMode end
        return nil
    end

    local function GetCategoryGrouping(categoryName)
        local mod = catMods[categoryName]
        if mod and mod.groupBy then return mod.groupBy end
        return nil
    end

    local function StackItems(items)
        if not db.global.stackItems then return items end
        local stacks = {}
        local stackOrder = {}
        for _, btn in ipairs(items) do
            local itemID = btn.owb_itemInfo and btn.owb_itemInfo.itemID
            if not itemID then
                tinsert(stackOrder, { buttons = {btn}, count = 1 })
            else
                local key = tostring(itemID)
                if not stacks[key] then
                    stacks[key] = { buttons = {}, count = 0, representative = btn }
                    tinsert(stackOrder, stacks[key])
                end
                tinsert(stacks[key].buttons, btn)
                stacks[key].count = stacks[key].count + (btn.owb_itemInfo.stackCount or 1)
            end
        end
        local result = {}
        for _, stack in ipairs(stackOrder) do
            local rep = stack.representative or stack.buttons[1]
            if stack.count > 1 and rep then
                rep._owb_stackCount = stack.count
            end
            tinsert(result, rep)
            for _, btn in ipairs(stack.buttons) do
                if btn ~= rep then
                    btn:Hide()
                end
            end
        end
        return result
    end

    local function FilterItems(categoryName)
        local items = itemsByCategory[categoryName]
        if not items then return nil end
        if filterSet then
            local filtered = {}
            for _, btn in ipairs(items) do
                if filterSet[btn] then
                    tinsert(filtered, btn)
                end
            end
            items = filtered
        end
        if #items == 0 then return nil end
        local catSort = GetCategorySortMode(categoryName)
        OneWoW_Bags:SortButtons(items, catSort)
        items = StackItems(items)
        return items
    end

    local function GroupItemsByExpansion(items)
        local groups = {}
        local groupOrder = {}
        for _, btn in ipairs(items) do
            local expID = -1
            if SE and btn.owb_itemInfo and btn.owb_itemInfo.hyperlink then
                expID = SE:GetExpansionID(btn.owb_itemInfo.itemID, btn.owb_itemInfo.hyperlink) or -1
            end
            local expName = (SE and SE:GetExpansionName(expID)) or "Unknown"
            if not groups[expName] then
                groups[expName] = {}
                tinsert(groupOrder, { name = expName, sortKey = expID })
            end
            tinsert(groups[expName], btn)
        end
        sort(groupOrder, function(a, b) return a.sortKey > b.sortKey end)
        return groups, groupOrder
    end

    local function GroupItemsByType(items)
        local groups = {}
        local groupOrder = {}
        for _, btn in ipairs(items) do
            local typeName = "Other"
            if btn.owb_itemInfo and btn.owb_itemInfo.hyperlink then
                local _, _, _, _, _, itemType = C_Item.GetItemInfo(btn.owb_itemInfo.hyperlink)
                typeName = itemType or "Other"
            end
            if not groups[typeName] then
                groups[typeName] = {}
                tinsert(groupOrder, { name = typeName, sortKey = typeName })
            end
            tinsert(groups[typeName], btn)
        end
        sort(groupOrder, function(a, b) return a.sortKey < b.sortKey end)
        return groups, groupOrder
    end

    local function GroupItemsBySlot(items)
        local groups = {}
        local groupOrder = {}
        for _, btn in ipairs(items) do
            local slotName = "Other"
            if btn.owb_itemInfo and btn.owb_itemInfo.hyperlink then
                local _, _, _, _, _, _, _, _, equipLoc = C_Item.GetItemInfo(btn.owb_itemInfo.hyperlink)
                if equipLoc and equipLoc ~= "" then
                    slotName = _G[equipLoc] or equipLoc
                end
            end
            if not groups[slotName] then
                groups[slotName] = {}
                tinsert(groupOrder, { name = slotName, sortKey = slotName })
            end
            tinsert(groups[slotName], btn)
        end
        sort(groupOrder, function(a, b) return a.sortKey < b.sortKey end)
        return groups, groupOrder
    end

    local function GroupItemsByQuality(items)
        local groups = {}
        local groupOrder = {}
        for _, btn in ipairs(items) do
            local q = (btn.owb_itemInfo and btn.owb_itemInfo.quality) or 0
            local qName = _G["ITEM_QUALITY" .. q .. "_DESC"] or ("Quality " .. q)
            if not groups[qName] then
                groups[qName] = {}
                tinsert(groupOrder, { name = qName, sortKey = q })
            end
            tinsert(groups[qName], btn)
        end
        sort(groupOrder, function(a, b) return a.sortKey > b.sortKey end)
        return groups, groupOrder
    end

    local function RenderItemGrid(parentFrame, items, startY)
        local itemRow = 0
        local itemCol = 0
        for _, button in ipairs(items) do
            local x = leftPadding + (itemCol * cellSize)
            local y = -(startY + itemRow * cellSize)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", x, y)
            button:OWB_SetIconSize(iconSize)
            button:Show()
            itemCol = itemCol + 1
            if itemCol >= cols then
                itemCol = 0
                itemRow = itemRow + 1
            end
        end
        local totalRows = (itemCol > 0) and (itemRow + 1) or itemRow
        return totalRows * cellSize
    end

    local function RenderCategoryStacked(categoryName)
        local items = FilterItems(categoryName)
        if not items then return end

        local groupBy = GetCategoryGrouping(categoryName)

        if showHeaders then
            local section = CM:AcquireSection(contentFrame)
            section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
            section:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
            section:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            section:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

            local localeKey = "CAT_" .. string.upper(string.gsub(categoryName, "%s+", "_"))
            local displayName = L[localeKey] or categoryName
            section.title:SetText(displayName)
            local catMods = db.global.categoryModifications or {}
            local catMod = catMods[categoryName]
            if catMod and catMod.color then
                local cr = tonumber(catMod.color:sub(1,2), 16) / 255
                local cg = tonumber(catMod.color:sub(3,4), 16) / 255
                local cb = tonumber(catMod.color:sub(5,6), 16) / 255
                section.title:SetTextColor(cr, cg, cb, 1.0)
            else
                section.title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            end
            section.count:SetText(tostring(#items))
            section.count:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

            local collapsed = db.global.collapsedSections[categoryName]
            section.isCollapsed = collapsed or false

            local sectionHeight = 26

            if not section.isCollapsed then
                section.content:SetHeight(1)

                if groupBy and groupBy ~= "none" then
                    local groups, groupOrder
                    if groupBy == "expansion" then
                        groups, groupOrder = GroupItemsByExpansion(items)
                    elseif groupBy == "type" then
                        groups, groupOrder = GroupItemsByType(items)
                    elseif groupBy == "slot" then
                        groups, groupOrder = GroupItemsBySlot(items)
                    elseif groupBy == "quality" then
                        groups, groupOrder = GroupItemsByQuality(items)
                    end

                    if groups and groupOrder then
                        local subY = 0
                        for _, groupInfo in ipairs(groupOrder) do
                            local groupItems = groups[groupInfo.name]
                            if groupItems and #groupItems > 0 then
                                local subLabel = AcquireLabel(section.content)
                                subLabel:SetPoint("TOPLEFT", section.content, "TOPLEFT", leftPadding, -subY)
                                subLabel:SetWidth(cols * cellSize)
                                subLabel:SetText(groupInfo.name)
                                subLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                                subY = subY + 14

                                local gridH = RenderItemGrid(section.content, groupItems, subY)
                                subY = subY + gridH + 4
                            end
                        end
                        section.content:SetHeight(subY)
                        section.content:Show()
                        sectionHeight = sectionHeight + subY + 4
                    end
                else
                    local itemRow = 0
                    local itemCol = 0

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
                end
            else
                section.content:Hide()
                for _, button in ipairs(items) do
                    button:Hide()
                end
            end

            section:SetHeight(sectionHeight)
            yOffset = yOffset + sectionHeight + math.floor(cellSize * verticalSpacing * 0.25 + 0.5)

            local capturedName = categoryName
            section.header:SetScript("OnClick", function()
                section.isCollapsed = not section.isCollapsed
                db.global.collapsedSections[capturedName] = section.isCollapsed or nil
                if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then
                    OneWoW_Bags.GUI:RefreshLayout()
                end
            end)
        else
            local itemRow = 0
            local itemCol = 0
            for _, button in ipairs(items) do
                local x = leftPadding + (itemCol * cellSize)
                local y = -(yOffset + itemRow * cellSize)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, y)
                button:OWB_SetIconSize(iconSize)
                button:Show()
                itemCol = itemCol + 1
                if itemCol >= cols then
                    itemCol = 0
                    itemRow = itemRow + 1
                end
            end
            local totalRows = (itemCol > 0) and (itemRow + 1) or itemRow
            yOffset = yOffset + totalRows * cellSize + math.floor(cellSize * verticalSpacing * 0.25 + 0.5)
        end
    end

    local gapSlots = compactGapSlots
    local labelHeight = showHeaders and 16 or 0

    local function FlushGroupCompact(group)
        if #group == 0 then return end

        local lines = {}
        local currentLine = {}
        local curCol = 0

        for _, catInfo in ipairs(group) do
            local count = #catInfo.items
            local startCol = curCol > 0 and (curCol + gapSlots) or 0
            local avail = math.floor(cols - startCol)

            if avail < 1 then
                tinsert(lines, currentLine)
                currentLine = {}
                curCol = 0
                startCol = 0
                avail = cols
            end

            local optimalWidth = count <= cols and count or math.max(2, math.floor(math.sqrt(count / 1.618)))
            local blockWidth = math.min(optimalWidth, avail)
            local blockRows = math.ceil(count / blockWidth)

            if blockRows > 1 and (curCol > 0 or blockWidth < cols) then
                if #currentLine > 0 then
                    tinsert(lines, currentLine)
                    currentLine = {}
                end
                curCol = 0
                startCol = 0
                blockWidth = math.min(count, cols)
                blockRows = math.ceil(count / blockWidth)
            end

            tinsert(currentLine, {
                name = catInfo.name,
                displayName = catInfo.displayName,
                items = catInfo.items,
                startCol = startCol,
                blockWidth = blockWidth,
                blockRows = blockRows,
            })

            if blockRows > 1 then
                tinsert(lines, currentLine)
                currentLine = {}
                curCol = 0
            else
                curCol = startCol + blockWidth
            end
        end
        if #currentLine > 0 then
            tinsert(lines, currentLine)
        end

        for _, line in ipairs(lines) do
            if showHeaders then
                for _, cat in ipairs(line) do
                    local label = AcquireLabel(contentFrame)
                    label:SetPoint("TOPLEFT", contentFrame, "TOPLEFT",
                        leftPadding + cat.startCol * cellSize, -yOffset)
                    label:SetWidth(cat.blockWidth * cellSize)
                    label:SetText(cat.displayName)
                    local catMods2 = db.global.categoryModifications or {}
                    local catMod2 = catMods2[cat.name]
                    if catMod2 and catMod2.color then
                        local cr = tonumber(catMod2.color:sub(1,2), 16) / 255
                        local cg = tonumber(catMod2.color:sub(3,4), 16) / 255
                        local cb = tonumber(catMod2.color:sub(5,6), 16) / 255
                        label:SetTextColor(cr, cg, cb, 1.0)
                    else
                        label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    end
                end
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
        if #lines > 0 then
            yOffset = yOffset + math.floor(cellSize * verticalSpacing * 0.25 + 0.5)
        end
    end

    local function RenderSeparator()
        local divider = CM:AcquireDivider(contentFrame)
        divider:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 8, -(yOffset + 4))
        divider:SetPoint("RIGHT", contentFrame, "RIGHT", -8, 0)
        divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
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
        section:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        section:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

        section.title:SetText(sectionName)
        section.title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
        section.count:SetText(isCollapsed and ">" or "")
        section.count:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

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
                        tinsert(currentGroup, catInfo)
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
                    tinsert(currentGroup, catInfo)
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
