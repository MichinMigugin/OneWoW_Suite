local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.CategoryManager = {}
local CM = OneWoW_Bags.CategoryManager

local sectionPool = {}
local activeSections = {}
local dividerPool = {}
local activeDividers = {}

function CM:AssignCategories()
    local BagSet = OneWoW_Bags.BagSet
    local Categories = OneWoW_Bags.Categories
    local buttons = BagSet:GetAllButtons()

    for _, button in ipairs(buttons) do
        if button.owb_hasItem and button.owb_itemInfo then
            button.owb_categoryName = Categories:GetItemCategory(button.owb_bagID, button.owb_slotID, button.owb_itemInfo)
        else
            button.owb_categoryName = nil
        end
    end
end

function CM:GetItemsByCategory()
    local BagSet = OneWoW_Bags.BagSet
    local result = {}
    local buttons = BagSet:GetAllButtons()

    for _, button in ipairs(buttons) do
        if button.owb_hasItem and button.owb_categoryName then
            if not result[button.owb_categoryName] then
                result[button.owb_categoryName] = {}
            end
            table.insert(result[button.owb_categoryName], button)
        end
    end

    return result
end

function CM:GetSortedCategoryNames(itemsByCategory)
    local Categories = OneWoW_Bags.Categories
    local names = {}
    for name in pairs(itemsByCategory) do
        table.insert(names, name)
    end

    local db = OneWoW_Bags.db
    local categoryOrder = db and db.global.categoryOrder
    if categoryOrder and #categoryOrder > 0 then
        local orderMap = {}
        for i, name in ipairs(categoryOrder) do
            orderMap[name] = i
        end
        table.sort(names, function(a, b)
            local aPos = orderMap[a] or 999
            local bPos = orderMap[b] or 999
            if aPos ~= bPos then return aPos < bPos end
            return a < b
        end)
    else
        local sortMode = db and db.global.categorySort or "priority"
        Categories:SortCategories(names, sortMode)
    end

    return names
end

function CM:GetSectionedLayout(itemsByCategory, containerType)
    local db = OneWoW_Bags.db
    if not db then return self:GetSortedCategoryNames(itemsByCategory) end

    local sections    = db.global.categorySections or {}
    local sectOrder   = db.global.sectionOrder or {}
    local catOrder    = db.global.categoryOrder or {}

    if #sectOrder == 0 then
        return self:GetSortedCategoryNames(itemsByCategory)
    end

    local catMods = db.global.categoryModifications or {}
    local function IsCategoryVisible(catName)
        local mod = catMods[catName]
        if mod and mod.hideIn and containerType then
            if mod.hideIn[containerType] then
                return false
            end
        end
        return true
    end

    local displayOrder = db.global.displayOrder or {}

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
                table.insert(layout, { type = "separator", showHeader = true })
            elseif entry:sub(1, 8) == "section:" then
                local sectionID = entry:sub(9)
                local sec = sections[sectionID]

                local sectionCatNames = {}
                i = i + 1
                while i <= #displayOrder and displayOrder[i] ~= "section_end" do
                    local catEntry = displayOrder[i]
                    if catEntry ~= "----" and not catEntry:find("^section:") then
                        table.insert(sectionCatNames, catEntry)
                    end
                    i = i + 1
                end

                if sec then
                    local visibleCats = {}
                    local hasEquipBase = false
                    for _, catName in ipairs(sectionCatNames) do
                        if itemsByCategory[catName] and #itemsByCategory[catName] > 0 and IsCategoryVisible(catName) then
                            table.insert(visibleCats, catName)
                        end
                        if catName == "Weapons" or catName == "Armor" then
                            hasEquipBase = true
                        end
                    end

                    local sectionSlotCats = {}
                    if hasEquipBase and db.global.enableInventorySlots then
                        for name in pairs(itemsByCategory) do
                            if not inOrder[name] and equipSlotNames[name] and #itemsByCategory[name] > 0 and IsCategoryVisible(name) then
                                table.insert(sectionSlotCats, name)
                            end
                        end
                        table.sort(sectionSlotCats)
                    end

                    local hasContent = #visibleCats > 0 or #sectionSlotCats > 0

                    if hasContent then
                        local showHeader = sec.showHeader or false
                        local effectiveCollapsed = showHeader and sec.collapsed
                        table.insert(layout, { type = "section_header", name = sec.name, sectionID = sectionID, collapsed = effectiveCollapsed, showHeader = showHeader })

                        if not effectiveCollapsed then
                            for _, catName in ipairs(visibleCats) do
                                table.insert(layout, { type = "category", name = catName })
                            end
                            for _, catName in ipairs(sectionSlotCats) do
                                table.insert(layout, { type = "category", name = catName })
                            end
                        end
                    end
                end
            elseif entry ~= "section_end" then
                if itemsByCategory[entry] and #itemsByCategory[entry] > 0 and IsCategoryVisible(entry) then
                    table.insert(layout, { type = "category", name = entry })
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
                table.insert(leftover, name)
            end
        end
        local Categories = OneWoW_Bags.Categories
        Categories:SortCategories(leftover, db.global.categorySort or "priority")
        for _, name in ipairs(leftover) do
            table.insert(layout, { type = "category", name = name })
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
            table.insert(rootCats, name)
        end
    end

    if #catOrder > 0 then
        local orderMap = {}
        for i, name in ipairs(catOrder) do orderMap[name] = i end
        table.sort(rootCats, function(a, b)
            local aP = orderMap[a] or 999
            local bP = orderMap[b] or 999
            if aP ~= bP then return aP < bP end
            return a < b
        end)
    else
        local Categories = OneWoW_Bags.Categories
        Categories:SortCategories(rootCats, db.global.categorySort or "priority")
    end

    for _, name in ipairs(rootCats) do
        table.insert(layout, { type = "category", name = name })
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
                local showHeader = sec.showHeader or false
                local effectiveCollapsed = showHeader and sec.collapsed

                table.insert(layout, { type = "separator", showHeader = showHeader })
                table.insert(layout, { type = "section_header", name = sec.name, sectionID = sectionID, collapsed = effectiveCollapsed, showHeader = showHeader })
                if not effectiveCollapsed then
                    for _, catName in ipairs(sec.categories) do
                        if itemsByCategory[catName] and #itemsByCategory[catName] > 0 and IsCategoryVisible(catName) then
                            table.insert(layout, { type = "category", name = catName })
                        end
                    end
                end
            end
        end
    end

    return layout
end

function CM:AcquireSection(parent)
    local section
    if #sectionPool > 0 then
        section = table.remove(sectionPool)
        section:SetParent(parent)
        section:Show()
    else
        section = CM:CreateSection(parent)
    end
    activeSections[section] = true
    return section
end

function CM:ReleaseSection(section)
    if not section then return end
    section:Hide()
    section:ClearAllPoints()
    activeSections[section] = nil
    table.insert(sectionPool, section)
end

function CM:ReleaseAllSections()
    for section in pairs(activeSections) do
        section:Hide()
        section:ClearAllPoints()
        table.insert(sectionPool, section)
    end
    activeSections = {}
    for divider in pairs(activeDividers) do
        divider:Hide()
        divider:ClearAllPoints()
        table.insert(dividerPool, divider)
    end
    activeDividers = {}
end

function CM:CreateSection(parent)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    section.header = CreateFrame("Button", nil, section)
    section.header:SetHeight(24)
    section.header:SetPoint("TOPLEFT", 0, 0)
    section.header:SetPoint("TOPRIGHT", 0, 0)

    section.title = section.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    section.title:SetPoint("LEFT", 8, 0)
    section.title:SetJustifyH("LEFT")

    section.count = section.header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    section.count:SetPoint("RIGHT", -8, 0)
    section.count:SetJustifyH("RIGHT")

    section.content = CreateFrame("Frame", nil, section)
    section.content:SetPoint("TOPLEFT", section.header, "BOTTOMLEFT", 0, -2)
    section.content:SetPoint("TOPRIGHT", section.header, "BOTTOMRIGHT", 0, -2)

    section.isCollapsed = false

    section.header:SetScript("OnClick", function()
        section.isCollapsed = not section.isCollapsed
        if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then
            OneWoW_Bags.GUI:RefreshLayout()
        end
    end)

    return section
end

function CM:AcquireDivider(parent)
    local divider
    if #dividerPool > 0 then
        divider = table.remove(dividerPool)
        divider:SetParent(parent)
        divider:Show()
    else
        divider = parent:CreateTexture(nil, "ARTWORK")
        divider:SetHeight(1)
    end
    activeDividers[divider] = true
    return divider
end

function CM:AcquireSectionHeader(parent)
    local section
    if #sectionPool > 0 then
        section = table.remove(sectionPool)
        section:SetParent(parent)
        section:Show()
    else
        section = CM:CreateSection(parent)
    end
    activeSections[section] = true
    return section
end
