local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local L = OneWoW_Bags.L

local tremove, tinsert, wipe, sort = tremove, tinsert, wipe, sort
local pairs, ipairs, type = pairs, ipairs, type
local floor, min, max, ceil, sqrt = math.floor, math.min, math.max, math.ceil, math.sqrt
local tostring = tostring
local SetItemButtonCount = SetItemButtonCount
local C_Item = C_Item

OneWoW_Bags.CategoryViewHelpers = {}
local H = OneWoW_Bags.CategoryViewHelpers

function H.CreateLabelPool()
    local pool = {}
    local active = {}

    local function Acquire(parent)
        local label
        if #pool > 0 then
            label = tremove(pool)
            label:SetParent(parent)
        else
            label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
        end
        label:ClearAllPoints()
        label:Show()
        active[label] = true
        return label
    end

    local function ReleaseAll()
        for label in pairs(active) do
            label:Hide()
            label:ClearAllPoints()
            tinsert(pool, label)
        end
        wipe(active)
    end

    return Acquire, ReleaseAll
end

function H.ResolveCategoryName(categoryName)
    local localeKey = "CAT_" .. string.upper(string.gsub(categoryName, "%s+", "_"))
    return L[localeKey] or categoryName
end

function H.ApplyCategoryColor(fontString, catMods, categoryName)
    local catMod = catMods[categoryName]
    if catMod and catMod.color then
        local cr = tonumber(catMod.color:sub(1,2), 16) / 255
        local cg = tonumber(catMod.color:sub(3,4), 16) / 255
        local cb = tonumber(catMod.color:sub(5,6), 16) / 255
        fontString:SetTextColor(cr, cg, cb, 1.0)
    else
        fontString:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end
end

function H.PinSpecialCategories(list, moveRecentToTop, moveOtherToBottom, getName)
    if not moveRecentToTop and not moveOtherToBottom then return list end
    getName = getName or function(entry) return entry end
    local pinRecent, pinBottom, rest = {}, {}, {}
    for _, entry in ipairs(list) do
        local name = getName(entry)
        if name == "Recent Items" and moveRecentToTop then
            tinsert(pinRecent, entry)
        elseif name == "Other" and moveOtherToBottom then
            tinsert(pinBottom, entry)
        else
            tinsert(rest, entry)
        end
    end
    local result = {}
    for _, e in ipairs(pinRecent) do tinsert(result, e) end
    for _, e in ipairs(rest) do tinsert(result, e) end
    for _, e in ipairs(pinBottom) do tinsert(result, e) end
    return result
end

function H.VerticalGap(cellSize, verticalSpacing)
    return floor(cellSize * verticalSpacing * 0.25 + 0.5)
end

function H.RenderItemGrid(parentFrame, items, startY, leftPadding, cellSize, iconSize, cols)
    local itemRow = 0
    local itemCol = 0
    for _, button in ipairs(items) do
        local x = leftPadding + (itemCol * cellSize)
        local y = -(startY + itemRow * cellSize)
        button:ClearAllPoints()
        OneWoW_Bags.WindowHelpers:SetPointPixelAligned(button, parentFrame, x, y)
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

function H.SetupCategorySection(section, contentFrame, yOffset, categoryName, itemCount, catMods)
    section:ClearAllPoints()
    section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
    section:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
    section:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    section:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    section.title:SetText(H.ResolveCategoryName(categoryName))
    H.ApplyCategoryColor(section.title, catMods, categoryName)
    section.count:SetText(tostring(itemCount))
    section.count:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
end

function H.LayoutCompactGroup(catInfoList, contentFrame, opts)
    if #catInfoList == 0 then return opts.yOffset end

    local yOffset = opts.yOffset
    local cols = opts.cols
    local gapSlots = opts.gapSlots
    local showHeaders = opts.showHeaders
    local labelHeight = showHeaders and 16 or 0
    local leftPadding = opts.leftPadding
    local cellSize = opts.cellSize
    local iconSize = opts.iconSize
    local catMods = opts.catMods
    local AcquireLabel = opts.AcquireLabel
    local verticalSpacing = opts.verticalSpacing

    local lines = {}
    local currentLine = {}
    local curCol = 0

    for _, catInfo in ipairs(catInfoList) do
        local count = #catInfo.items
        local startCol = curCol > 0 and (curCol + gapSlots) or 0
        local avail = floor(cols - startCol)

        if avail < 1 then
            tinsert(lines, currentLine)
            currentLine = {}
            curCol = 0
            startCol = 0
            avail = cols
        end

        local optimalWidth = count <= cols and count or max(2, floor(sqrt(count / 1.618)))
        local blockWidth = min(optimalWidth, avail)
        local blockRows = ceil(count / blockWidth)

        if blockRows > 1 and (curCol > 0 or blockWidth < cols) then
            if #currentLine > 0 then
                tinsert(lines, currentLine)
                currentLine = {}
            end
            curCol = 0
            startCol = 0
            blockWidth = min(count, cols)
            blockRows = ceil(count / blockWidth)
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
                H.ApplyCategoryColor(label, catMods, cat.name)
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
                OneWoW_Bags.WindowHelpers:SetPointPixelAligned(button, contentFrame, x, y)
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
        yOffset = yOffset + H.VerticalGap(cellSize, verticalSpacing)
    end

    return yOffset
end

function H.GetSortedCategoryNames(itemsByCategory)
    local Categories = OneWoW_Bags.Categories
    local names = {}
    for name in pairs(itemsByCategory) do
        tinsert(names, name)
    end

    local db = OneWoW_Bags.db
    local categoryOrder = db.global.categoryOrder
    if categoryOrder and #categoryOrder > 0 then
        local orderMap = {}
        for i, name in ipairs(categoryOrder) do
            orderMap[name] = i
        end
        sort(names, function(a, b)
            local aPos = orderMap[a] or 999
            local bPos = orderMap[b] or 999
            if aPos ~= bPos then return aPos < bPos end
            return a < b
        end)
    else
        local sortMode = db.global.categorySort or "priority"
        Categories:SortCategories(names, sortMode)
    end

    return names
end

local function ResolveSectionShowHeader(sec, containerType)
    if containerType == "backpack" then
        return sec.showHeader or false
    end
    local bankVal = sec.showHeaderBank
    if bankVal == nil then return sec.showHeader or false end
    return bankVal
end

function H.GetSectionedLayout(itemsByCategory, containerType)
    local Categories = OneWoW_Bags.Categories
    local db = OneWoW_Bags.db

    local sections    = db.global.categorySections
    local sectOrder   = db.global.sectionOrder
    local catOrder    = db.global.categoryOrder

    if #sectOrder == 0 then
        return H.GetSortedCategoryNames(itemsByCategory)
    end

    local catMods = db.global.categoryModifications
    local g = db.global
    local disabled = g.disabledCategories
    local function IsCategoryVisible(catName)
        if disabled[catName] then
            local hasItems = itemsByCategory[catName] and #itemsByCategory[catName] > 0
            if not (g.pinnedCategoryShowsWhenDisabled and hasItems) then
                return false
            end
        end
        if not Categories:CategoryAppliesTo(catName, containerType) then
            return false
        end
        return true
    end

    local displayOrder = db.global.displayOrder

    if #displayOrder > 0 then
        local layout = {}

        local inOrder = {}
        for _, entry in ipairs(displayOrder) do
            if entry ~= "----" and entry ~= "section_end" and not entry:find("^section:") then
                inOrder[entry] = true
            end
        end

        local equipSlotNames = {}
        if db.global.enableInventorySlots then
            local slotKeys = {
                "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_BODY",
                "INVTYPE_CHEST", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET",
                "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_FINGER", "INVTYPE_TRINKET",
                "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND",
                "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE",
                "INVTYPE_CLOAK", "INVTYPE_RANGED",
            }
            for _, key in ipairs(slotKeys) do
                local displayName = _G[key]
                if displayName and displayName ~= "" then
                    equipSlotNames[displayName] = true
                end
            end
        end

        local i = 1
        while i <= #displayOrder do
            local entry = displayOrder[i]

            if entry == "----" then
                tinsert(layout, { type = "separator", showHeader = true })
            elseif entry:sub(1, 8) == "section:" then
                local sectionID = entry:sub(9)
                local sec = sections[sectionID]

                local sectionCatNames = {}
                i = i + 1
                while i <= #displayOrder and displayOrder[i] ~= "section_end" do
                    local catEntry = displayOrder[i]
                    if catEntry ~= "----" and not catEntry:find("^section:") then
                        tinsert(sectionCatNames, catEntry)
                    end
                    i = i + 1
                end

                if sec then
                    local visibleCats = {}
                    local hasEquipBase = false
                    for _, catName in ipairs(sectionCatNames) do
                        if itemsByCategory[catName] and #itemsByCategory[catName] > 0 and IsCategoryVisible(catName) then
                            tinsert(visibleCats, catName)
                        end
                        if catName == "Weapons" or catName == "Armor" then
                            hasEquipBase = true
                        end
                    end

                    local sectionSlotCats = {}
                    if hasEquipBase and db.global.enableInventorySlots then
                        for name in pairs(itemsByCategory) do
                            if not inOrder[name] and equipSlotNames[name] and #itemsByCategory[name] > 0 and IsCategoryVisible(name) then
                                tinsert(sectionSlotCats, name)
                            end
                        end
                        sort(sectionSlotCats)
                    end

                    local hasContent = #visibleCats > 0 or #sectionSlotCats > 0

                    if hasContent then
                        local showHeader = ResolveSectionShowHeader(sec, containerType)
                        local effectiveCollapsed = showHeader and sec.collapsed
                        tinsert(layout, { type = "section_header", name = sec.name, sectionID = sectionID, collapsed = effectiveCollapsed, showHeader = showHeader })

                        if not effectiveCollapsed then
                            for _, catName in ipairs(visibleCats) do
                                tinsert(layout, { type = "category", name = catName })
                            end
                            for _, catName in ipairs(sectionSlotCats) do
                                tinsert(layout, { type = "category", name = catName })
                            end
                        end
                    end
                end
            elseif entry ~= "section_end" then
                if itemsByCategory[entry] and #itemsByCategory[entry] > 0 and IsCategoryVisible(entry) then
                    tinsert(layout, { type = "category", name = entry })
                end
            end

            i = i + 1
        end

        local claimedSlots = {}
        if db.global.enableInventorySlots then
            for name in pairs(itemsByCategory) do
                if equipSlotNames[name] then
                    claimedSlots[name] = true
                end
            end
        end

        local leftover = {}
        for name in pairs(itemsByCategory) do
            if not inOrder[name] and not claimedSlots[name] and #itemsByCategory[name] > 0 and IsCategoryVisible(name) then
                tinsert(leftover, name)
            end
        end
        Categories:SortCategories(leftover, db.global.categorySort or "priority")
        for _, name in ipairs(leftover) do
            tinsert(layout, { type = "category", name = name })
        end

        return layout
    end

    local inSection = {}
    for _, sec in pairs(sections) do
        for _, catName in ipairs(sec.categories or {}) do
            inSection[catName] = true
        end
    end

    local layout = {}

    local rootCats = {}
    for name in pairs(itemsByCategory) do
        if not inSection[name] and IsCategoryVisible(name) then
            tinsert(rootCats, name)
        end
    end

    if #catOrder > 0 then
        local orderMap = {}
        for i, name in ipairs(catOrder) do orderMap[name] = i end
        sort(rootCats, function(a, b)
            local aP = orderMap[a] or 999
            local bP = orderMap[b] or 999
            if aP ~= bP then return aP < bP end
            return a < b
        end)
    else
        Categories:SortCategories(rootCats, db.global.categorySort or "priority")
    end

    for _, sectionID in ipairs(sectOrder) do
        local sec = sections[sectionID]
        if sec and sec.categories then
            local hasItems = false
            for _, catName in ipairs(sec.categories) do
                if itemsByCategory[catName] and #itemsByCategory[catName] > 0 and IsCategoryVisible(catName) then
                    hasItems = true
                    break
                end
            end
            if hasItems then
                local showHeader = ResolveSectionShowHeader(sec, containerType)
                local effectiveCollapsed = showHeader and sec.collapsed

                tinsert(layout, { type = "separator", showHeader = showHeader })
                tinsert(layout, { type = "section_header", name = sec.name, sectionID = sectionID, collapsed = effectiveCollapsed, showHeader = showHeader })
                if not effectiveCollapsed then
                    for _, catName in ipairs(sec.categories) do
                        if itemsByCategory[catName] and #itemsByCategory[catName] > 0 and IsCategoryVisible(catName) then
                            tinsert(layout, { type = "category", name = catName })
                        end
                    end
                end
            end
        end
    end

    for _, name in ipairs(rootCats) do
        tinsert(layout, { type = "category", name = name })
    end

    return layout
end

function H.RestoreItemButtonCounts(items)
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

function H.StackItems(items, db, PE)
    H.RestoreItemButtonCounts(items)
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

function H.FilterItems(categoryName, itemsByCategory, filterSet, catMods, sortButtons, db, PE)
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
    local mod = catMods[categoryName]
    local catSort = mod and mod.sortMode or nil
    sortButtons(items, catSort)
    items = H.StackItems(items, db, PE)
    return items
end

function H.GroupItemsBy(items, groupBy, PE, L)
    local groups = {}
    local groupOrder = {}

    if groupBy == "expansion" then
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
    elseif groupBy == "type" then
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
    elseif groupBy == "slot" then
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
    elseif groupBy == "quality" then
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
    else
        return nil, nil
    end

    return groups, groupOrder
end

function H.LayoutCategoryContent(config)
    local contentFrame = config.contentFrame
    local viewContext = config.viewContext
    local itemsByCategory = config.itemsByCategory
    local layout = config.layout
    local compact = config.compact
    local showHeaders = config.showHeaders
    local verticalSpacing = config.verticalSpacing
    local compactGapSlots = config.compactGapSlots
    local cols = config.cols
    local leftPadding = config.leftPadding
    local cellSize = config.cellSize
    local iconSize = config.iconSize
    local filterSet = config.filterSet
    local db = config.db
    local PE = config.PE

    local sortButtons = viewContext.sortButtons
    local acquireSection = viewContext.acquireSection
    local acquireSectionHeader = viewContext.acquireSectionHeader
    local acquireDivider = viewContext.acquireDivider
    local getCollapsed = viewContext.getCollapsed
    local setCollapsed = viewContext.setCollapsed

    local AcquireLabel = config.AcquireLabel
    local ReleaseAllLabels = config.ReleaseAllLabels
    ReleaseAllLabels()

    local moveRecentToTop = config.moveRecentToTop
    local moveOtherToBottom = config.moveOtherToBottom
    if moveRecentToTop or moveOtherToBottom then
        if type(layout[1]) == "table" then
            layout = H.PinSpecialCategories(layout, moveRecentToTop, moveOtherToBottom,
                function(entry) return entry.type == "category" and entry.name or nil end)
        else
            layout = H.PinSpecialCategories(layout, moveRecentToTop, moveOtherToBottom)
        end
    end

    local catMods = db.global.categoryModifications
    local yOffset = 0

    local function GetCategoryGrouping(categoryName)
        local mod = catMods[categoryName]
        if mod and mod.groupBy then return mod.groupBy end
        return nil
    end

    local function DoFilterItems(categoryName)
        return H.FilterItems(categoryName, itemsByCategory, filterSet, catMods, sortButtons, db, PE)
    end

    local function RenderCategoryStacked(categoryName)
        local items = DoFilterItems(categoryName)
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
                    local groups, groupOrder = H.GroupItemsBy(items, groupBy, PE, L)

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
        local items = DoFilterItems(categoryName)
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
