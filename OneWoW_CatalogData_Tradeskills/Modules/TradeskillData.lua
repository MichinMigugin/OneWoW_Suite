-- OneWoW Addon File
-- OneWoW_CatalogData_Tradeskills/Modules/TradeskillData.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.TradeskillData = {}
local TD = ns.TradeskillData

local PROFESSIONS = {
    {id = 171, name = "Alchemy",        icon = 136240, global = "OneWoWTradeskills_Alchemy",        type = "crafting"},
    {id = 164, name = "Blacksmithing",  icon = 136241, global = "OneWoWTradeskills_Blacksmithing",  type = "crafting"},
    {id = 185, name = "Cooking",        icon = 133971, global = "OneWoWTradeskills_Cooking",        type = "secondary"},
    {id = 333, name = "Enchanting",     icon = 136244, global = "OneWoWTradeskills_Enchanting",     type = "crafting"},
    {id = 202, name = "Engineering",    icon = 136243, global = "OneWoWTradeskills_Engineering",    type = "crafting"},
    {id = 356, name = "Fishing",        icon = 136245, global = "OneWoWTradeskills_Fishing",        type = "secondary"},
    {id = 182, name = "Herbalism",      icon = 136246, global = "OneWoWTradeskills_Herbalism",      type = "gathering"},
    {id = 2984,name = "HousingDyes",   icon = 7449434,global = "OneWoWTradeskills_HousingDyes",   type = "crafting"},
    {id = 773, name = "Inscription",    icon = 237171, global = "OneWoWTradeskills_Inscription",    type = "crafting"},
    {id = 755, name = "Jewelcrafting",  icon = 134071, global = "OneWoWTradeskills_Jewelcrafting",  type = "crafting"},
    {id = 165, name = "Leatherworking", icon = 133611, global = "OneWoWTradeskills_Leatherworking", type = "crafting"},
    {id = 186, name = "Mining",         icon = 134708, global = "OneWoWTradeskills_Mining",         type = "gathering"},
    {id = 393, name = "Skinning",       icon = 134366, global = "OneWoWTradeskills_Skinning",       type = "gathering"},
    {id = 197, name = "Tailoring",      icon = 136249, global = "OneWoWTradeskills_Tailoring",      type = "crafting"},
}

local EXPANSIONS = {
    {key = "Classic",           id = 1,  order = 1},
    {key = "BurningCrusade",    id = 2,  order = 2},
    {key = "WrathOfTheLichKing",id = 3,  order = 3},
    {key = "Cataclysm",         id = 4,  order = 4},
    {key = "MistsOfPandaria",   id = 5,  order = 5},
    {key = "WarlordsOfDraenor", id = 6,  order = 6},
    {key = "Legion",            id = 7,  order = 7},
    {key = "BattleForAzeroth",  id = 8,  order = 8},
    {key = "Shadowlands",       id = 9,  order = 9},
    {key = "Dragonflight",      id = 10, order = 10},
    {key = "TheWarWithin",      id = 11, order = 11},
    {key = "Midnight",          id = 12, order = 12},
}

local expansionOrder = {}
for _, exp in ipairs(EXPANSIONS) do
    expansionOrder[exp.key] = exp.order
end

local profByName = {}
for _, prof in ipairs(PROFESSIONS) do
    profByName[prof.name] = prof
end

local recipeIndex = nil
local reagentIndex = nil
local itemIndex = nil

local function GetProfessionData(profName)
    local prof = profByName[profName]
    if not prof then return nil end
    return _G[prof.global]
end

local function BuildRecipeIndex()
    if recipeIndex then return end
    recipeIndex = {}
    for _, prof in ipairs(PROFESSIONS) do
        local data = _G[prof.global]
        if data and data.r then
            for recipeID, recipe in pairs(data.r) do
                recipeIndex[recipeID] = prof.name
            end
        end
    end
end

local function BuildReagentIndex()
    if reagentIndex then return end
    reagentIndex = {}
    for _, prof in ipairs(PROFESSIONS) do
        local data = _G[prof.global]
        if data and data.r then
            for recipeID, recipe in pairs(data.r) do
                if recipe.rg then
                    for _, rg in ipairs(recipe.rg) do
                        local itemID = rg[1]
                        if itemID then
                            if not reagentIndex[itemID] then
                                reagentIndex[itemID] = {}
                            end
                            table.insert(reagentIndex[itemID], recipeID)
                        end
                    end
                end
            end
        end
    end
end

local function BuildItemIndex()
    if itemIndex then return end
    itemIndex = {}
    for _, prof in ipairs(PROFESSIONS) do
        local data = _G[prof.global]
        if data and data.r then
            for recipeID, recipe in pairs(data.r) do
                if recipe.item then
                    if not itemIndex[recipe.item] then
                        itemIndex[recipe.item] = {}
                    end
                    table.insert(itemIndex[recipe.item], recipeID)
                end
            end
        end
    end
end

function TD:Initialize()
    self.initialized = true
end

function TD:GetProfessions()
    local result = {}
    for _, prof in ipairs(PROFESSIONS) do
        local data = _G[prof.global]
        local count = 0
        if data and data.r then
            for _ in pairs(data.r) do count = count + 1 end
        end
        table.insert(result, {
            id = prof.id,
            name = prof.name,
            icon = data and data.icon or prof.icon,
            type = prof.type,
            recipeCount = count,
            hasData = (data ~= nil),
        })
    end
    return result
end

function TD:GetExpansions()
    return EXPANSIONS
end

function TD:GetRecipesByProfession(professionName, expFilter, searchText)
    local data = GetProfessionData(professionName)
    if not data or not data.r then return {} end

    local results = {}
    local searchLower = searchText and searchText:lower() or nil

    for recipeID, recipe in pairs(data.r) do
        local include = true

        if expFilter and expFilter ~= "" and recipe.exp ~= expFilter then
            include = false
        end

        if include and searchLower and searchLower ~= "" then
            local recipeName = nil
            if recipe.item then
                local itemName = C_Item.GetItemNameByID(recipe.item)
                if itemName then
                    recipeName = itemName:lower()
                end
            end
            if not recipeName or not recipeName:find(searchLower, 1, true) then
                local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(recipe.id)
                if spellName then
                    if not spellName:lower():find(searchLower, 1, true) then
                        include = false
                    end
                else
                    include = false
                end
            end
        end

        if include then
            table.insert(results, recipe)
        end
    end

    table.sort(results, function(a, b)
        local orderA = expansionOrder[a.exp] or 99
        local orderB = expansionOrder[b.exp] or 99
        if orderA ~= orderB then return orderA < orderB end
        return a.id < b.id
    end)

    return results
end

function TD:GetRecipe(recipeID)
    BuildRecipeIndex()
    local profName = recipeIndex[recipeID]
    if not profName then return nil end
    local data = GetProfessionData(profName)
    if not data or not data.r then return nil end
    return data.r[recipeID]
end

function TD:GetRecipeReagents(recipeID)
    local recipe = self:GetRecipe(recipeID)
    if not recipe then return nil, nil end
    return recipe.rg, recipe.sl
end

function TD:SearchRecipes(searchText, professionFilter, expansionFilter)
    if not searchText or searchText == "" then return {} end

    local results = {}
    local searchLower = searchText:lower()

    local profsToSearch = {}
    if professionFilter and professionFilter ~= "" then
        table.insert(profsToSearch, professionFilter)
    else
        for _, prof in ipairs(PROFESSIONS) do
            table.insert(profsToSearch, prof.name)
        end
    end

    for _, profName in ipairs(profsToSearch) do
        local matches = self:GetRecipesByProfession(profName, expansionFilter, searchText)
        for _, recipe in ipairs(matches) do
            table.insert(results, recipe)
        end
    end

    return results
end

function TD:GetRecipesByItem(itemID)
    BuildItemIndex()
    local recipeIDs = itemIndex[itemID]
    if not recipeIDs then return {} end
    local results = {}
    for _, recipeID in ipairs(recipeIDs) do
        local recipe = self:GetRecipe(recipeID)
        if recipe then
            table.insert(results, recipe)
        end
    end
    return results
end

function TD:GetRecipesByReagent(itemID)
    BuildReagentIndex()
    local recipeIDs = reagentIndex[itemID]
    if not recipeIDs then return {} end
    local results = {}
    for _, recipeID in ipairs(recipeIDs) do
        local recipe = self:GetRecipe(recipeID)
        if recipe then
            table.insert(results, recipe)
        end
    end
    return results
end

function TD:GetProfessionByName(name)
    return profByName[name]
end

function TD:GetProfessionByID(profID)
    for _, prof in ipairs(PROFESSIONS) do
        if prof.id == profID then return prof end
    end
    return nil
end

function TD:GetExpansionRecipeCounts(professionName)
    local data = GetProfessionData(professionName)
    if not data or not data.r then return {} end

    local counts = {}
    for _, recipe in pairs(data.r) do
        local exp = recipe.exp or "Unknown"
        counts[exp] = (counts[exp] or 0) + 1
    end
    return counts
end

function TD:GetRecipeChain(recipeID)
    BuildRecipeIndex()
    local recipe = self:GetRecipe(recipeID)
    if not recipe then return nil end

    local chain = {}
    local current = recipe
    while current and current.prev do
        current = self:GetRecipe(current.prev)
    end

    local seen = {}
    while current and not seen[current.id] do
        seen[current.id] = true
        table.insert(chain, current)
        if current.next then
            current = self:GetRecipe(current.next)
        else
            current = nil
        end
    end

    if #chain <= 1 then return nil end
    return chain
end

function TD:GetStats()
    local totalRecipes = 0
    local profCount = 0
    for _, prof in ipairs(PROFESSIONS) do
        local data = _G[prof.global]
        if data and data.r then
            profCount = profCount + 1
            for _ in pairs(data.r) do totalRecipes = totalRecipes + 1 end
        end
    end
    return { professions = profCount, recipes = totalRecipes }
end
