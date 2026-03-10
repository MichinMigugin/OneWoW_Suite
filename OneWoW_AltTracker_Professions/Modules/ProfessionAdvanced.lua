local addonName, ns = ...

ns.ProfessionAdvanced = {}
local Module = ns.ProfessionAdvanced

local EXPANSION_NAMES = {
    [0] = "Classic",
    [1] = "The Burning Crusade",
    [2] = "Wrath of the Lich King",
    [3] = "Cataclysm",
    [4] = "Mists of Pandaria",
    [5] = "Warlords of Draenor",
    [6] = "Legion",
    [7] = "Battle for Azeroth",
    [8] = "Shadowlands",
    [9] = "Dragonflight",
    [10] = "The War Within",
    [11] = "Midnight",
}

function Module:CollectData(charKey, charData, professionName)
    if not charKey or not charData or not professionName then return false end

    if not charData.recipes then
        charData.recipes = {}
    end

    local allRecipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
    if not allRecipeIDs or #allRecipeIDs == 0 then
        return false
    end

    local recipes = {}

    for _, recipeID in ipairs(allRecipeIDs) do
        local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
        if recipeInfo and recipeInfo.learned then
            recipes[recipeID] = true
        end
    end

    charData.recipes[professionName] = recipes
    charData.lastUpdate = time()

    return true
end

function Module:BuildRecipesByExpansion(charData, professionName)
    if not charData or not charData.recipes or not charData.recipes[professionName] then
        return {}
    end

    local recipesByExpansion = {}

    for recipeID in pairs(charData.recipes[professionName]) do
        local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
        if recipeInfo then
            local expansionID = self:GetRecipeExpansion(recipeInfo)
            if not recipesByExpansion[expansionID] then
                recipesByExpansion[expansionID] = {
                    expansionID = expansionID,
                    expansionName = EXPANSION_NAMES[expansionID] or "Unknown",
                    learnedRecipes = 0,
                    totalRecipes = 0,
                    recipes = {},
                }
            end
            recipesByExpansion[expansionID].learnedRecipes = recipesByExpansion[expansionID].learnedRecipes + 1
            recipesByExpansion[expansionID].totalRecipes = recipesByExpansion[expansionID].totalRecipes + 1
            table.insert(recipesByExpansion[expansionID].recipes, recipeID)
        end
    end

    return recipesByExpansion
end

function Module:GetRecipeExpansion(recipeInfo)
    if not recipeInfo then return 0 end

    if recipeInfo.categoryID then
        if recipeInfo.categoryID >= 2000 and recipeInfo.categoryID < 3000 then
            return 11
        elseif recipeInfo.categoryID >= 1900 and recipeInfo.categoryID < 2000 then
            return 10
        elseif recipeInfo.categoryID >= 1800 and recipeInfo.categoryID < 1900 then
            return 9
        elseif recipeInfo.categoryID >= 1700 and recipeInfo.categoryID < 1800 then
            return 8
        elseif recipeInfo.categoryID >= 1600 and recipeInfo.categoryID < 1700 then
            return 7
        elseif recipeInfo.categoryID >= 1500 and recipeInfo.categoryID < 1600 then
            return 6
        elseif recipeInfo.categoryID >= 1400 and recipeInfo.categoryID < 1500 then
            return 5
        elseif recipeInfo.categoryID >= 1300 and recipeInfo.categoryID < 1400 then
            return 4
        elseif recipeInfo.categoryID >= 1200 and recipeInfo.categoryID < 1300 then
            return 3
        elseif recipeInfo.categoryID >= 1100 and recipeInfo.categoryID < 1200 then
            return 2
        elseif recipeInfo.categoryID >= 1000 and recipeInfo.categoryID < 1100 then
            return 1
        end
    end

    return 0
end

function Module:GetRecipeCount(charKey, charData, professionName)
    if not charData or not charData.recipes or not charData.recipes[professionName] then
        return 0
    end

    local count = 0
    for _ in pairs(charData.recipes[professionName]) do
        count = count + 1
    end

    return count
end
