local _, OneWoW_Bags = ...

local sort, tinsert = table.sort, tinsert
local pairs, ipairs = pairs, ipairs
local strtrim = strtrim
local string_lower = string.lower

OneWoW_Bags.SectionDefaults = OneWoW_Bags.SectionDefaults or {}
local SD = OneWoW_Bags.SectionDefaults

SD.SEC_ONEWOW_BAGS = "sec_onewow_bags"
SD.SEC_EQUIPMENT = "sec_equipment"
SD.SEC_CRAFTING = "sec_crafting"
SD.SEC_HOUSING = "sec_housing"

SD.EQUIPMENT_CATEGORIES = { "Equipment Sets", "Weapons", "Armor" }
SD.CRAFTING_CATEGORIES = { "Reagents", "Trade Goods", "Tradeskill", "Recipes" }
SD.HOUSING_CATEGORIES = { "Housing" }

SD.BASE_BUILTIN_NAMES = {
    "Recent Items", "Hearthstone", "Keystone", "Potions", "Food",
    "Consumables", "Quest Items", "Equipment Sets", "Weapons", "Armor",
    "Reagents", "Trade Goods", "Tradeskill", "Recipes", "Housing",
    "Gems", "Item Enhancement", "Containers", "Keys", "Miscellaneous",
    "Battle Pets", "Toys", "Other", "Junk",
}

SD.BUILTIN_SORT_PRIORITY = {
    ["1W Junk"] = 1,
    ["1W Upgrades"] = 1,
    ["Recent Items"] = 1,
    ["Hearthstone"] = 2,
    ["Keystone"] = 3,
    ["Potions"] = 4,
    ["Food"] = 5,
    ["Consumables"] = 6,
    ["Quest Items"] = 7,
    ["Equipment Sets"] = 8,
    ["Weapons"] = 9,
    ["Armor"] = 10,
    ["Reagents"] = 11,
    ["Trade Goods"] = 12,
    ["Tradeskill"] = 13,
    ["Recipes"] = 14,
    ["Housing"] = 15,
    ["Gems"] = 16,
    ["Item Enhancement"] = 17,
    ["Containers"] = 18,
    ["Keys"] = 19,
    ["Miscellaneous"] = 20,
    ["Battle Pets"] = 21,
    ["Toys"] = 22,
    ["Junk"] = 90,
    ["Other"] = 98,
}

function SD:GetOptionalOneWoWCategories(g)
    local list = {}
    if g.enableJunkCategory then
        tinsert(list, "1W Junk")
    end
    if g.enableUpgradeCategory then
        tinsert(list, "1W Upgrades")
    end
    return list
end

function SD:GetEffectiveBuiltinNames(g)
    local names = {}
    for _, n in ipairs(SD.BASE_BUILTIN_NAMES) do
        tinsert(names, n)
    end
    for _, n in ipairs(SD:GetOptionalOneWoWCategories(g)) do
        tinsert(names, n)
    end
    return names
end

function SD:CollectAssignedExcept(categorySections, excludeSectionId)
    local assigned = {}
    for sid, sec in pairs(categorySections) do
        if sid ~= excludeSectionId and sec and sec.categories then
            for _, nm in ipairs(sec.categories) do
                assigned[nm] = true
            end
        end
    end
    return assigned
end

function SD:SortMemberNames(names, g)
    local saved = g.categoryOrder
    if saved and #saved > 0 then
        local orderMap = {}
        for i, name in ipairs(saved) do
            orderMap[name] = i
        end
        sort(names, function(a, b)
            local aP = orderMap[a] or 999
            local bP = orderMap[b] or 999
            if aP ~= bP then
                return aP < bP
            end
            return a < b
        end)
    else
        sort(names, function(a, b)
            local aP = SD.BUILTIN_SORT_PRIORITY[a] or 50
            local bP = SD.BUILTIN_SORT_PRIORITY[b] or 50
            if aP ~= bP then
                return aP < bP
            end
            return a < b
        end)
    end
end

local function IsNameInBuiltinList(name, eff)
    for _, n in ipairs(eff) do
        if n == name then
            return true
        end
    end
    return false
end

function SD:BuildOnewowMembers(g)
    local eff = SD:GetEffectiveBuiltinNames(g)
    local assigned = SD:CollectAssignedExcept(g.categorySections, SD.SEC_ONEWOW_BAGS)
    local builtinMembers = {}
    for _, n in ipairs(eff) do
        if not assigned[n] then
            tinsert(builtinMembers, n)
        end
    end
    SD:SortMemberNames(builtinMembers, g)

    local customRows = {}
    for id, catData in pairs(g.customCategoriesV2 or {}) do
        if catData then
            local nm = catData.name
            if type(nm) == "string" then
                nm = strtrim(nm)
            else
                nm = ""
            end
            if nm ~= "" and not assigned[nm] and not IsNameInBuiltinList(nm, eff) then
                tinsert(customRows, {
                    id = id,
                    name = nm,
                    sortOrder = catData.sortOrder or 0,
                })
            end
        end
    end
    sort(customRows, function(a, b)
        if a.sortOrder ~= b.sortOrder then
            return a.sortOrder < b.sortOrder
        end
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.id < b.id
    end)
    local customSeenNorm = {}
    local customMembers = {}
    for _, row in ipairs(customRows) do
        local kn = string_lower(row.name)
        if not customSeenNorm[kn] then
            customSeenNorm[kn] = true
            tinsert(customMembers, row.name)
        end
    end

    local members = {}
    for _, n in ipairs(builtinMembers) do
        tinsert(members, n)
    end
    for _, n in ipairs(customMembers) do
        tinsert(members, n)
    end
    return members
end

function SD:SyncOnewowSectionCategories(g)
    local ow = g.categorySections[SD.SEC_ONEWOW_BAGS]
    if not ow then
        return
    end
    ow.categories = SD:BuildOnewowMembers(g)
end

function SD:ScrubCategoryOrderForSections(g)
    local inAny = {}
    for _, sec in pairs(g.categorySections) do
        for _, nm in ipairs(sec.categories or {}) do
            inAny[nm] = true
        end
    end
    local co = g.categoryOrder
    if not co or #co == 0 then
        return
    end
    local newOrder = {}
    for _, nm in ipairs(co) do
        if not inAny[nm] then
            tinsert(newOrder, nm)
        end
    end
    g.categoryOrder = newOrder
end
