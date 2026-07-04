local _, ns = ...

-- Public, cross-addon read surface for the Tradeskills data store. ns stays private.
OneWoW_CatalogData_Tradeskills_API = {}

--- Returns the tradeskill store settings.
---@return table settings
function OneWoW_CatalogData_Tradeskills_API.GetSettings()
    return ns:GetSettings()
end

--- All professions known to the static recipe database.
---@return table professions
function OneWoW_CatalogData_Tradeskills_API.GetProfessions()
    return ns.TradeskillData:GetProfessions()
end

--- Expansion filter values for tradeskill browsing.
---@return table expansions
function OneWoW_CatalogData_Tradeskills_API.GetExpansions()
    return ns.TradeskillData:GetExpansions()
end

--- Recipes for one profession, optionally filtered by expansion and search text.
---@param profName string
---@param expFilter number|nil
---@param search string|nil
---@return table recipes
function OneWoW_CatalogData_Tradeskills_API.GetRecipesByProfession(profName, expFilter, search)
    return ns.TradeskillData:GetRecipesByProfession(profName, expFilter, search)
end

--- One recipe record by ID.
---@param recipeID number
---@return table|nil recipe
function OneWoW_CatalogData_Tradeskills_API.GetRecipe(recipeID)
    return ns.TradeskillData:GetRecipe(recipeID)
end

--- Reagents required for a recipe.
---@param recipeID number
---@return table reagents
function OneWoW_CatalogData_Tradeskills_API.GetRecipeReagents(recipeID)
    return ns.TradeskillData:GetRecipeReagents(recipeID)
end

--- Profession name that owns a recipe ID in the static catalog, or nil.
--- Used by consumers to attribute learned recipes to a profession.
---@param recipeID number
---@return string|nil professionName
function OneWoW_CatalogData_Tradeskills_API.GetRecipeProfession(recipeID)
    return ns.TradeskillData:GetRecipeProfession(recipeID)
end

--- Search recipes across professions and expansions.
---@param text string
---@param profFilter string|nil
---@param expFilter number|nil
---@return table recipes
function OneWoW_CatalogData_Tradeskills_API.SearchRecipes(text, profFilter, expFilter)
    return ns.TradeskillData:SearchRecipes(text, profFilter, expFilter)
end

--- Recipes that produce an item.
---@param itemID number
---@return table recipes
function OneWoW_CatalogData_Tradeskills_API.GetRecipesByItem(itemID)
    return ns.TradeskillData:GetRecipesByItem(itemID)
end

--- Recipes that consume an item as a reagent.
---@param itemID number
---@return table recipes
function OneWoW_CatalogData_Tradeskills_API.GetRecipesByReagent(itemID)
    return ns.TradeskillData:GetRecipesByReagent(itemID)
end

--- Profession metadata by display name.
---@param name string
---@return table|nil profession
function OneWoW_CatalogData_Tradeskills_API.GetProfessionByName(name)
    return ns.TradeskillData:GetProfessionByName(name)
end

--- Profession metadata by profession ID.
---@param profID number
---@return table|nil profession
function OneWoW_CatalogData_Tradeskills_API.GetProfessionByID(profID)
    return ns.TradeskillData:GetProfessionByID(profID)
end

--- Per-expansion recipe counts for a profession.
---@param profName string
---@return table counts
function OneWoW_CatalogData_Tradeskills_API.GetExpansionRecipeCounts(profName)
    return ns.TradeskillData:GetExpansionRecipeCounts(profName)
end

--- Prerequisite recipe chain for a recipe.
---@param recipeID number
---@return table chain
function OneWoW_CatalogData_Tradeskills_API.GetRecipeChain(recipeID)
    return ns.TradeskillData:GetRecipeChain(recipeID)
end

--- Aggregate tradeskill-store statistics.
---@return table stats
function OneWoW_CatalogData_Tradeskills_API.GetStats()
    return ns.TradeskillData:GetStats()
end

--- Register a listener invoked after tradeskill scan data updates.
---@param fn fun()|nil
function OneWoW_CatalogData_Tradeskills_API.RegisterScanCallback(fn)
    ns:RegisterScanCallback(fn)
end

--- Cached item-data entry from this store's item loader.
---@param itemID number
---@return table|nil cached
function OneWoW_CatalogData_Tradeskills_API.GetCachedItem(itemID)
    return ns.DataLoader:GetCachedItem(itemID)
end

--- Loads item data asynchronously via this store's item loader.
---@param itemID number
---@param callback fun(itemID: number, result: table|nil)|nil
---@return table|nil cached synchronous result when already cached
function OneWoW_CatalogData_Tradeskills_API.LoadItemData(itemID, callback)
    return ns.DataLoader:LoadItemData(itemID, callback)
end

--- Whether any tracked character knows a recipe.
---@param recipeID number
---@return boolean known
function OneWoW_CatalogData_Tradeskills_API.IsRecipeKnown(recipeID)
    return ns.TradeskillScanner:IsRecipeKnown(recipeID)
end

--- Characters that know a recipe.
---@param recipeID number
---@return table characters
function OneWoW_CatalogData_Tradeskills_API.GetRecipeKnownBy(recipeID)
    return ns.TradeskillScanner:GetRecipeKnownBy(recipeID)
end

--- All characters with scanned profession data.
---@return table characters
function OneWoW_CatalogData_Tradeskills_API.GetAllCharacters()
    return ns.TradeskillScanner:GetAllCharacters()
end

--- Known recipes for one character and profession.
---@param charKey string
---@param profName string
---@return table recipes
function OneWoW_CatalogData_Tradeskills_API.GetKnownRecipes(charKey, profName)
    return ns.TradeskillScanner:GetKnownRecipes(charKey, profName)
end

--- Remove one character's scanned profession data.
---@param charKey string
---@return boolean purged
function OneWoW_CatalogData_Tradeskills_API.PurgeCharacter(charKey)
    return ns.TradeskillScanner:PurgeCharacter(charKey)
end

--- Item IDs interchangeable in a crafting reagent slot (e.g. quality tiers).
---@param itemID number
---@return number[] variants
function OneWoW_CatalogData_Tradeskills_API.GetCraftingQualityVariants(itemID)
    return ns.TradeskillData:GetCraftingQualityVariants(itemID)
end
