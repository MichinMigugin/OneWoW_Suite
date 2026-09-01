local _, ns = ...

local pairs, ipairs, type = pairs, ipairs, type
local tonumber = tonumber
local tinsert, sort = tinsert, sort
local C_Item = C_Item
local C_Spell = C_Spell

-- Public, cross-addon read surface for TradeSkillDB. ns stays private.
-- Recipe helpers for the Catalog Tradeskills tab.
OneWoW_CatDB_TradeSkillDB_API = {}

local EXPANSIONS = {
    {key = "Classic",            id = 1,  order = 1},
    {key = "BurningCrusade",     id = 2,  order = 2},
    {key = "WrathOfTheLichKing", id = 3,  order = 3},
    {key = "Cataclysm",          id = 4,  order = 4},
    {key = "MistsOfPandaria",    id = 5,  order = 5},
    {key = "WarlordsOfDraenor",  id = 6,  order = 6},
    {key = "Legion",             id = 7,  order = 7},
    {key = "BattleForAzeroth",   id = 8,  order = 8},
    {key = "Shadowlands",        id = 9,  order = 9},
    {key = "Dragonflight",       id = 10, order = 10},
    {key = "TheWarWithin",       id = 11, order = 11},
    {key = "Midnight",           id = 12, order = 12},
}

local expansionOrder = {}
for _, exp in ipairs(EXPANSIONS) do
    expansionOrder[exp.key] = exp.order
end

local PROFESSION_ORDER = {
    "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering",
    "Fishing", "Herbalism", "HousingDyes", "Inscription", "Jewelcrafting",
    "Leatherworking", "Mining", "Skinning", "Tailoring",
}

local reagentIndex

--- Catalog GetCachedItem shape. Quality is a number (GetItemQualityByID / ItemDB),
--- never GetItemInfoInstant's itemSubType (e.g. "Elixirs").
---@param itemID number
---@return table|nil
local function ItemSnapshot(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end
    if ns.DataLoader then
        local cached = ns.DataLoader:GetCachedItem(itemID)
        if cached then
            return cached
        end
    end
    local itemAPI = OneWoW_CatDB_ItemDB_API
    if itemAPI then
        local rec = itemAPI.GetItem(itemID)
        if rec then
            local name = rec.name or itemAPI.GetItemName(itemID)
            if name then
                local quality = rec.quality
                if type(quality) ~= "number" then
                    quality = C_Item.GetItemQualityByID(itemID)
                end
                return {
                    name = name,
                    quality = quality,
                    icon = rec.icon or C_Item.GetItemIconByID(itemID),
                }
            end
        end
        local shipped = itemAPI.GetItemName(itemID)
        if shipped then
            return {
                name = shipped,
                quality = C_Item.GetItemQualityByID(itemID),
                icon = C_Item.GetItemIconByID(itemID),
            }
        end
    end
    local name = C_Item.GetItemNameByID(itemID)
    if not name then
        return nil
    end
    return {
        name = name,
        quality = C_Item.GetItemQualityByID(itemID),
        icon = C_Item.GetItemIconByID(itemID) or select(5, C_Item.GetItemInfoInstant(itemID)),
    }
end

local function IndexReagent(itemID, recipe)
    if type(itemID) ~= "number" or itemID <= 0 then
        return
    end
    local list = reagentIndex[itemID]
    if not list then
        list = {}
        reagentIndex[itemID] = list
    end
    tinsert(list, recipe)
end

local function EnsureReagentIndex()
    if reagentIndex then
        return
    end
    reagentIndex = {}
    for _, recipe in pairs(ns.Recipes) do
        if recipe.rg then
            for i = 1, #recipe.rg do
                IndexReagent(recipe.rg[i][1], recipe)
            end
        end
        if recipe.sl then
            for i = 1, #recipe.sl do
                local options = recipe.sl[i][5]
                if options then
                    for j = 1, #options do
                        IndexReagent(options[j], recipe)
                    end
                end
            end
        end
    end
end

--- Returns the store settings.
---@return table settings
function OneWoW_CatDB_TradeSkillDB_API.GetSettings()
    return ns:GetSettings()
end

--- Profession headers for the Tradeskills tab.
---@return table professions
function OneWoW_CatDB_TradeSkillDB_API.GetProfessions()
    local out = {}
    local seen = {}
    for _, name in ipairs(PROFESSION_ORDER) do
        local prof = ns.Professions[name]
        if prof then
            seen[name] = true
            local count = 0
            if prof.r then
                for _ in pairs(prof.r) do
                    count = count + 1
                end
            end
            tinsert(out, {
                id = prof.pid,
                name = prof.name,
                icon = prof.icon,
                recipeCount = count,
                hasData = true,
            })
        end
    end
    for name, prof in pairs(ns.Professions) do
        if not seen[name] then
            local count = 0
            if prof.r then
                for _ in pairs(prof.r) do
                    count = count + 1
                end
            end
            tinsert(out, {
                id = prof.pid,
                name = prof.name,
                icon = prof.icon,
                recipeCount = count,
                hasData = true,
            })
        end
    end
    return out
end

--- Expansion labels used by the Tradeskills filter.
---@return table expansions
function OneWoW_CatDB_TradeSkillDB_API.GetExpansions()
    return EXPANSIONS
end

--- Recipes for one profession.
---@param profName string
---@param expFilter any
---@param search string|nil
---@return table recipes
function OneWoW_CatDB_TradeSkillDB_API.GetRecipesByProfession(profName, expFilter, search)
    local prof = ns.Professions[profName]
    if not prof or not prof.r then
        return {}
    end

    local results = {}
    local searchLower = search and search:lower() or nil
    for _, recipe in pairs(prof.r) do
        local include = true
        if expFilter and expFilter ~= "" and recipe.exp ~= expFilter then
            include = false
        end
        if include and searchLower and searchLower ~= "" then
            local recipeName
            if recipe.item then
                local itemName = C_Item.GetItemNameByID(recipe.item)
                if itemName then
                    recipeName = itemName:lower()
                end
            end
            if not recipeName or not recipeName:find(searchLower, 1, true) then
                local spellName = C_Spell.GetSpellName(recipe.id)
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
            tinsert(results, recipe)
        end
    end
    sort(results, function(a, b)
        local orderA = expansionOrder[a.exp] or 99
        local orderB = expansionOrder[b.exp] or 99
        if orderA ~= orderB then
            return orderA < orderB
        end
        return a.id < b.id
    end)
    return results
end

--- One recipe by spell / recipe ID.
---@param recipeID number
---@return table|nil recipe
function OneWoW_CatDB_TradeSkillDB_API.GetRecipe(recipeID)
    return ns.Recipes[recipeID]
end

---@param recipeID number
---@return table, table|nil
function OneWoW_CatDB_TradeSkillDB_API.GetRecipeReagents(recipeID)
    local recipe = ns.Recipes[recipeID]
    if not recipe then
        return {}, nil
    end
    return recipe.rg or {}, recipe.sl
end

---@param recipeID number
---@return string|nil
function OneWoW_CatDB_TradeSkillDB_API.GetRecipeProfession(recipeID)
    local recipe = ns.Recipes[recipeID]
    return recipe and recipe.prof or nil
end

---@param text string
---@param profFilter any
---@param expFilter any
---@return table
function OneWoW_CatDB_TradeSkillDB_API.SearchRecipes(text, profFilter, expFilter)
    if not text or text == "" then
        return {}
    end
    local results = {}
    if profFilter and profFilter ~= "" then
        return OneWoW_CatDB_TradeSkillDB_API.GetRecipesByProfession(profFilter, expFilter, text)
    end
    for _, prof in ipairs(OneWoW_CatDB_TradeSkillDB_API.GetProfessions()) do
        local matches = OneWoW_CatDB_TradeSkillDB_API.GetRecipesByProfession(prof.name, expFilter, text)
        for i = 1, #matches do
            tinsert(results, matches[i])
        end
    end
    return results
end

--- Recipes that craft a given item.
---@param itemID number
---@return table recipes
function OneWoW_CatDB_TradeSkillDB_API.GetRecipesByItem(itemID)
    return ns.RecipesByItem[itemID] or {}
end

---@param itemID number
---@return table
function OneWoW_CatDB_TradeSkillDB_API.GetRecipesByReagent(itemID)
    EnsureReagentIndex()
    return reagentIndex[itemID] or {}
end

---@param name string
---@return table|nil
function OneWoW_CatDB_TradeSkillDB_API.GetProfessionByName(name)
    return ns.Professions[name]
end

---@param profID number
---@return table|nil
function OneWoW_CatDB_TradeSkillDB_API.GetProfessionByID(profID)
    for _, prof in pairs(ns.Professions) do
        if prof.pid == profID then
            return prof
        end
    end
    return nil
end

---@param profName string
---@return table
function OneWoW_CatDB_TradeSkillDB_API.GetExpansionRecipeCounts(profName)
    local prof = ns.Professions[profName]
    if not prof or not prof.r then
        return {}
    end
    local counts = {}
    for _, recipe in pairs(prof.r) do
        local exp = recipe.exp or "Unknown"
        counts[exp] = (counts[exp] or 0) + 1
    end
    return counts
end

---@param recipeID number
---@return table|nil
function OneWoW_CatDB_TradeSkillDB_API.GetRecipeChain(recipeID)
    local recipe = ns.Recipes[recipeID]
    if not recipe then
        return nil
    end
    local chain = {}
    local current = recipe
    while current and current.prev do
        current = ns.Recipes[current.prev]
    end
    if not current then
        current = recipe
    end
    local seen = {}
    while current and current.id and not seen[current.id] do
        seen[current.id] = true
        tinsert(chain, current)
        if current.next then
            current = ns.Recipes[current.next]
        else
            current = nil
        end
    end
    if #chain <= 1 then
        return nil
    end
    return chain
end

---@return table
function OneWoW_CatDB_TradeSkillDB_API.GetStats()
    local recipes = 0
    local professions = 0
    for _ in pairs(ns.Recipes) do
        recipes = recipes + 1
    end
    for _ in pairs(ns.Professions) do
        professions = professions + 1
    end
    return { professions = professions, recipes = recipes }
end

---@param fn fun()|nil
function OneWoW_CatDB_TradeSkillDB_API.RegisterScanCallback(fn)
    ns:RegisterScanCallback(fn)
end

---@param itemID number
---@return table|nil
function OneWoW_CatDB_TradeSkillDB_API.GetCachedItem(itemID)
    return ItemSnapshot(itemID)
end

---@param itemID number
---@param callback fun(itemID: number, result: table|nil)|nil
---@return table|nil
function OneWoW_CatDB_TradeSkillDB_API.LoadItemData(itemID, callback)
    if ns.DataLoader then
        return ns.DataLoader:LoadItemData(itemID, callback)
    end
    local cached = ItemSnapshot(itemID)
    if callback then
        callback(itemID, cached)
    end
    return cached
end

---@param recipeID number
---@return boolean
function OneWoW_CatDB_TradeSkillDB_API.IsRecipeKnown(recipeID)
    local knownBy = OneWoW_CatDB_TradeSkillDB_API.GetRecipeKnownBy(recipeID)
    return #knownBy > 0
end

---@param recipeID number
---@return table
function OneWoW_CatDB_TradeSkillDB_API.GetRecipeKnownBy(recipeID)
    local knownBy = {}
    local seen = {}
    local api = OneWoW_AltTracker_Professions_API
    if api and api.GetAllCharacters then
        for charKey, charData in pairs(api.GetAllCharacters()) do
            if not seen[charKey] and charData and charData.recipes then
                for _, recipeSet in pairs(charData.recipes) do
                    if recipeSet[recipeID] then
                        seen[charKey] = true
                        tinsert(knownBy, charKey)
                        break
                    end
                end
            end
        end
    end
    sort(knownBy)
    return knownBy
end

---@return string[]
function OneWoW_CatDB_TradeSkillDB_API.GetAllCharacters()
    local keys = {}
    local api = OneWoW_AltTracker_Professions_API
    if api then
        for charKey in pairs(api.GetAllCharacters()) do
            tinsert(keys, charKey)
        end
    end
    sort(keys)
    return keys
end

---@param slotName string
---@param profName string
---@return boolean
local function ProfessionNameMatches(slotName, profName)
    if not slotName or not profName or slotName == "" or profName == "" then
        return false
    end
    if slotName == profName then
        return true
    end
    if profName:find(slotName, 1, true) then
        return true
    end
    if slotName:find(profName, 1, true) then
        return true
    end
    return false
end

---@param bands table|nil
---@return table expansions
---@return string|nil bestExpansion
---@return number bestSkill
local function NormalizeExpansionBands(bands)
    local expansions = {}
    local bestOrder, bestName, bestSkill = -1, nil, 0
    if type(bands) ~= "table" then
        return expansions, nil, 0
    end
    for i = 1, #bands do
        local band = bands[i]
        local order = band.sortOrder or band.order or 0
        local label = band.label or band.name
        local skill = band.skillLevel or band.currentSkill or 0
        local maxSkill = band.maxSkill or band.maxSkillLevel or 0
        tinsert(expansions, {
            label = label,
            order = order,
            skillLevel = skill,
            maxSkill = maxSkill,
        })
        if order > bestOrder then
            bestOrder = order
            bestName = label
            bestSkill = skill
        end
    end
    return expansions, bestName, bestSkill
end

--- Known-recipe bucket for one character and profession.
--- Reads AltTracker Professions (the suite known-recipe store). Nil when
--- that character has no matching profession / recipe set.
---@param charKey string
---@param profName string
---@return table|nil recipes { known, skillLevel, maxSkillLevel, lastScan, expansions, bestExpansion, bestSkill }
function OneWoW_CatDB_TradeSkillDB_API.GetKnownRecipes(charKey, profName)
    if not charKey or not profName or profName == "" then
        return nil
    end
    local api = OneWoW_AltTracker_Professions_API
    if not api then
        return nil
    end
    local charData = api.GetCharacterData(charKey)
    if not charData then
        return nil
    end

    local profData
    if charData.professions then
        for _, slot in pairs(charData.professions) do
            if slot and ProfessionNameMatches(slot.name, profName) then
                profData = slot
                break
            end
        end
    end

    local known
    if charData.recipes then
        known = charData.recipes[profName]
        if not known and profData and profData.name then
            known = charData.recipes[profData.name]
        end
        if not known then
            for key, set in pairs(charData.recipes) do
                if ProfessionNameMatches(key, profName) then
                    known = set
                    break
                end
            end
        end
    end

    if not profData and not known then
        return nil
    end

    local expansions, bestExpansion, bestSkill = NormalizeExpansionBands(profData and profData.expansions)
    return {
        known = known or {},
        skillLevel = (profData and (profData.currentSkill or profData.skillLevel)) or 0,
        maxSkillLevel = (profData and (profData.maxSkill or profData.maxSkillLevel)) or 0,
        lastScan = charData.lastUpdate,
        expansions = expansions,
        bestExpansion = bestExpansion,
        bestSkill = bestSkill,
    }
end

---@param charKey string
---@return boolean
function OneWoW_CatDB_TradeSkillDB_API.PurgeCharacter(charKey)
    return ns:DeleteCharacter(charKey)
end

---@param itemID number
---@return number[]
function OneWoW_CatDB_TradeSkillDB_API.GetCraftingQualityVariants(itemID)
    local variants = { itemID }
    local recipes = OneWoW_CatDB_TradeSkillDB_API.GetRecipesByReagent(itemID)
    for i = 1, #recipes do
        local recipe = recipes[i]
        if recipe.sl then
            for j = 1, #recipe.sl do
                local options = recipe.sl[j][5]
                if options and #options > 1 then
                    local found = false
                    for k = 1, #options do
                        if options[k] == itemID then
                            found = true
                            break
                        end
                    end
                    if found then
                        for k = 1, #options do
                            local optID = options[k]
                            local already = false
                            for n = 1, #variants do
                                if variants[n] == optID then
                                    already = true
                                    break
                                end
                            end
                            if not already then
                                tinsert(variants, optID)
                            end
                        end
                    end
                end
            end
        end
    end
    return variants
end
