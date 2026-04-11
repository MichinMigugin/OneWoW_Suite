local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local CategoryManager = OneWoW_Bags.CategoryManager
local H = OneWoW_Bags.CategoryViewHelpers

local PE = OneWoW_Bags.PredicateEngine

local floor, max = math.floor, math.max
local pairs, ipairs = pairs, ipairs
local tinsert, sort = tinsert, sort
local tostring = tostring
local SetItemButtonCount = SetItemButtonCount

OneWoW_Bags.CategoryView = {}
local View = OneWoW_Bags.CategoryView

local function GetDB()
    return OneWoW_Bags:GetDB()
end

local AcquireLabel, ReleaseAllLabels = H.CreateLabelPool()

function View:Layout(contentFrame, width, filteredButtons, containerType, viewContext)
    local db = GetDB()
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

    local sortButtons = viewContext.sortButtons
    local acquireSection = viewContext.acquireSection
    local acquireSectionHeader = viewContext.acquireSectionHeader
    local acquireDivider = viewContext.acquireDivider
    local getCollapsed = viewContext.getCollapsed
    local setCollapsed = viewContext.setCollapsed

    CategoryManager:AssignCategories()
    ReleaseAllLabels()

    local itemsByCategory = CategoryManager:GetItemsByCategory()
    local layout = CategoryManager:GetSectionedLayout(itemsByCategory, containerType)

    local moveRecentToTop = db.global.moveUpgradesToTop
    local moveOtherToBottom = db.global.moveOtherToBottom
    if moveRecentToTop or moveOtherToBottom then
        if type(layout[1]) == "table" then
            layout = H.PinSpecialCategories(layout, moveRecentToTop, moveOtherToBottom,
                function(entry) return entry.type == "category" and entry.name or nil end)
        else
            layout = H.PinSpecialCategories(layout, moveRecentToTop, moveOtherToBottom)
        end
    end

    local cols = db.global.bagColumns or floor((width - padding * 2) / (iconSize + spacing))
    cols = max(cols, 1)
    local cellSize = iconSize + spacing
    local totalGridWidth = cols * cellSize - spacing
    local leftPadding = max(padding, floor((width - totalGridWidth) / 2))

    local yOffset = 0

    local catMods = db.global.categoryModifications

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

    local function RestoreItemButtonCounts(items)
        for _, btn in ipairs(items) do
            btn._owb_stackCount = nil
            local info = btn.owb_itemInfo
            if info and info.hyperlink then
                SetItemButtonCount(btn, info.stackCount or 0)
            else
                SetItemButtonCount(btn, 0)
            end
        end
    end

    local function StackItems(items)
        RestoreItemButtonCounts(items)
        if not db.global.stackItems then return items end
        local stacks = {}
        local stackOrder = {}
        for _, btn in ipairs(items) do
            local info = btn.owb_itemInfo
            local itemID = info and info.itemID
            if not itemID then
                tinsert(stackOrder, { buttons = {btn}, count = 1 })
            else
                local key = PE:GetItemIdentityKey(itemID, info and info.hyperlink) or tostring(itemID)
                if not stacks[key] then
                    stacks[key] = { buttons = {}, count = 0, representative = btn }
                    tinsert(stackOrder, stacks[key])
                end
                tinsert(stacks[key].buttons, btn)
                stacks[key].count = stacks[key].count + (info.stackCount or 1)
            end
        end
        local result = {}
        for _, stack in ipairs(stackOrder) do
            local rep = stack.representative or stack.buttons[1]
            if stack.count > 1 and rep then
                rep._owb_stackCount = stack.count
                SetItemButtonCount(rep, stack.count)
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
        sortButtons(items, catSort)
        items = StackItems(items)
        return items
    end

    local function GroupItemsByExpansion(items)
        local groups = {}
        local groupOrder = {}
        for _, btn in ipairs(items) do
            local expID = -1
            if btn.owb_itemInfo and btn.owb_itemInfo.hyperlink then
                expID = PE:GetExpansionID(btn.owb_itemInfo.itemID, btn.owb_itemInfo.hyperlink) or -1
            end
            local expName = PE:GetExpansionName(expID) or L["UNKNOWN_EXPANSION"]
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
            local qName = _G["ITEM_QUALITY" .. q .. "_DESC"] or (L["QUALITY_PREFIX"] .. q)
            if not groups[qName] then
                groups[qName] = {}
                tinsert(groupOrder, { name = qName, sortKey = q })
            end
            tinsert(groups[qName], btn)
        end
        sort(groupOrder, function(a, b) return a.sortKey > b.sortKey end)
        return groups, groupOrder
    end

    local function RenderCategoryStacked(categoryName)
        local items = FilterItems(categoryName)
        if not items then return end

        local groupBy = GetCategoryGrouping(categoryName)

        if showHeaders then
            local section = acquireSection(contentFrame)
            H.SetupCategorySection(section, contentFrame, yOffset, categoryName, #items, catMods)

            local collapsed = getCollapsed("category", categoryName)
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

                                local gridH = H.RenderItemGrid(section.content, groupItems, subY, leftPadding, cellSize, iconSize, cols)
                                subY = subY + gridH + 4
                            end
                        end
                        section.content:SetHeight(subY)
                        section.content:Show()
                        sectionHeight = sectionHeight + subY + 4
                    end
                else
                    local contentHeight = H.RenderItemGrid(section.content, items, 0, leftPadding, cellSize, iconSize, cols)
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
            yOffset = yOffset + sectionHeight + H.VerticalGap(cellSize, verticalSpacing)

            local capturedName = categoryName
            section.header:SetScript("OnClick", function()
                section.isCollapsed = not section.isCollapsed
                setCollapsed("category", capturedName, section.isCollapsed)
            end)
        else
            local gridHeight = H.RenderItemGrid(contentFrame, items, yOffset, leftPadding, cellSize, iconSize, cols)
            yOffset = yOffset + gridHeight + H.VerticalGap(cellSize, verticalSpacing)
        end
    end

    local compactOpts = {
        yOffset = 0,
        cols = cols,
        gapSlots = compactGapSlots,
        showHeaders = showHeaders,
        leftPadding = leftPadding,
        cellSize = cellSize,
        iconSize = iconSize,
        catMods = catMods,
        AcquireLabel = AcquireLabel,
        verticalSpacing = verticalSpacing,
    }

    local function RenderSeparator()
        local divider = acquireDivider(contentFrame)
        divider:ClearAllPoints()
        divider:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 8, -(yOffset + 4))
        divider:SetPoint("RIGHT", contentFrame, "RIGHT", -8, 0)
        divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        divider:Show()
        yOffset = yOffset + 10
    end

    local function RenderSectionHeader(entry)
        local sectionID = entry.sectionID
        local sectionName = entry.name

        local section = acquireSectionHeader(contentFrame)
        section:ClearAllPoints()
        section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
        section:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
        section:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        section:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

        section.title:SetText(sectionName)
        section.title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
        section.count:SetText(entry.collapsed and ">" or "")
        section.count:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        section.content:Hide()
        section:SetHeight(24)
        yOffset = yOffset + 26

        local capturedSectionID = sectionID
        section.header:SetScript("OnClick", function()
            section.isCollapsed = not section.isCollapsed
            setCollapsed("section", capturedSectionID, section.isCollapsed)
        end)
    end

    local function BuildCatInfo(categoryName)
        local items = FilterItems(categoryName)
        if not items then return nil end
        return { name = categoryName, displayName = H.ResolveCategoryName(categoryName), items = items }
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
                    compactOpts.yOffset = yOffset
                    yOffset = H.LayoutCompactGroup(currentGroup, contentFrame, compactOpts)
                    currentGroup = {}
                    if entry.showHeader then
                        RenderSeparator()
                    end
                elseif entry.type == "section_header" then
                    compactOpts.yOffset = yOffset
                    yOffset = H.LayoutCompactGroup(currentGroup, contentFrame, compactOpts)
                    currentGroup = {}
                    if entry.showHeader then
                        RenderSectionHeader(entry)
                    end
                end
            end
            compactOpts.yOffset = yOffset
            yOffset = H.LayoutCompactGroup(currentGroup, contentFrame, compactOpts)
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
            compactOpts.yOffset = yOffset
            yOffset = H.LayoutCompactGroup(currentGroup, contentFrame, compactOpts)
        else
            for _, categoryName in ipairs(layout) do
                RenderCategoryStacked(categoryName)
            end
        end
    end

    return max(yOffset, 100)
end
