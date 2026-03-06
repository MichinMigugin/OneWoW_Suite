-- OneWoW Addon File
-- OneWoW_CatalogData_Tradeskills/OneWoW_CatalogData_Tradeskills.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

_G.OneWoW_CatalogData_Tradeskills = ns

OneWoW_CatalogData_Tradeskills_API = {
    GetSettings = function()
        return ns:GetSettings()
    end,

    GetProfessions = function()
        return ns.TradeskillData:GetProfessions()
    end,

    GetExpansions = function()
        return ns.TradeskillData:GetExpansions()
    end,

    GetRecipesByProfession = function(profName, expFilter, search)
        return ns.TradeskillData:GetRecipesByProfession(profName, expFilter, search)
    end,

    GetRecipe = function(recipeID)
        return ns.TradeskillData:GetRecipe(recipeID)
    end,

    GetRecipeReagents = function(recipeID)
        return ns.TradeskillData:GetRecipeReagents(recipeID)
    end,

    SearchRecipes = function(text, profFilter, expFilter)
        return ns.TradeskillData:SearchRecipes(text, profFilter, expFilter)
    end,

    GetRecipesByItem = function(itemID)
        return ns.TradeskillData:GetRecipesByItem(itemID)
    end,

    GetRecipesByReagent = function(itemID)
        return ns.TradeskillData:GetRecipesByReagent(itemID)
    end,

    GetProfessionByName = function(name)
        return ns.TradeskillData:GetProfessionByName(name)
    end,

    GetProfessionByID = function(profID)
        return ns.TradeskillData:GetProfessionByID(profID)
    end,

    GetExpansionRecipeCounts = function(profName)
        return ns.TradeskillData:GetExpansionRecipeCounts(profName)
    end,

    GetRecipeChain = function(recipeID)
        return ns.TradeskillData:GetRecipeChain(recipeID)
    end,

    GetStats = function()
        return ns.TradeskillData:GetStats()
    end,

    RegisterScanCallback = function(fn)
        ns:RegisterScanCallback(fn)
    end,

    GetCachedItem = function(itemID)
        return ns.DataLoader:GetCachedItem(itemID)
    end,

    LoadItemData = function(itemID, callback)
        return ns.DataLoader:LoadItemData(itemID, callback)
    end,

    IsRecipeKnown = function(recipeID)
        return ns.TradeskillScanner:IsRecipeKnown(recipeID)
    end,

    GetRecipeKnownBy = function(recipeID)
        return ns.TradeskillScanner:GetRecipeKnownBy(recipeID)
    end,

    GetAllCharacters = function()
        return ns.TradeskillScanner:GetAllCharacters()
    end,

    GetKnownRecipes = function(charKey, profName)
        return ns.TradeskillScanner:GetKnownRecipes(charKey, profName)
    end,
}
