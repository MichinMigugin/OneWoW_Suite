local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.CategoryManager = {}
local CM = OneWoW_Bags.CategoryManager

local sectionPool = {}
local activeSections = {}

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
