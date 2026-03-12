local addonName, ns = ...
local OneWoWAltTracker = _G.OneWoW_AltTracker
local L = ns.L

ns.ProfessionsModule = ns.ProfessionsModule or {}
local ProfessionsModule = ns.ProfessionsModule

function ProfessionsModule:Initialize()
    self.initialized = true
end

function ProfessionsModule:GetCharacterProfessions(characterKey)
    if not characterKey then
        return {professions = {}, professionEquipment = {}, recipeCount = 0, recipesByExpansion = {}}
    end

    if not _G.OneWoW_AltTracker_Professions_DB or not _G.OneWoW_AltTracker_Professions_DB.characters then
        return {professions = {}, professionEquipment = {}, recipeCount = 0, recipesByExpansion = {}}
    end

    local charData = _G.OneWoW_AltTracker_Professions_DB.characters[characterKey]
    if not charData then
        return {professions = {}, professionEquipment = {}, recipeCount = 0, recipesByExpansion = {}}
    end

    local professionData = {
        professions = charData.professions or {},
        professionEquipment = charData.professionEquipment or {},
        concentration = charData.concentration or {},
        recipeCount = 0,
        recipesByExpansion = {},
        weeklyQuestStatus = {}
    }

    if charData.recipes then
        local count = 0
        for profName, recipes in pairs(charData.recipes) do
            for _ in pairs(recipes) do
                count = count + 1
            end
        end
        professionData.recipeCount = count
    end

    local catalogGlobals = {
        ["Alchemy"] = "OneWoWTradeskills_Alchemy",
        ["Blacksmithing"] = "OneWoWTradeskills_Blacksmithing",
        ["Cooking"] = "OneWoWTradeskills_Cooking",
        ["Enchanting"] = "OneWoWTradeskills_Enchanting",
        ["Engineering"] = "OneWoWTradeskills_Engineering",
        ["Fishing"] = "OneWoWTradeskills_Fishing",
        ["Herbalism"] = "OneWoWTradeskills_Herbalism",
        ["Inscription"] = "OneWoWTradeskills_Inscription",
        ["Jewelcrafting"] = "OneWoWTradeskills_Jewelcrafting",
        ["Leatherworking"] = "OneWoWTradeskills_Leatherworking",
        ["Mining"] = "OneWoWTradeskills_Mining",
        ["Skinning"] = "OneWoWTradeskills_Skinning",
        ["Tailoring"] = "OneWoWTradeskills_Tailoring",
    }

    local recipesByExpansion = {}
    local professions = charData.professions or {}
    local knownRecipes = charData.recipes or {}

    for slotName, profInfo in pairs(professions) do
        if profInfo and profInfo.name then
            local globalName = catalogGlobals[profInfo.name]
            local catalogData = globalName and _G[globalName]
            if catalogData and catalogData.r then
                local knownSet = {}
                if knownRecipes[profInfo.name] then
                    for k in pairs(knownRecipes[profInfo.name]) do
                        knownSet[tonumber(k) or k] = true
                    end
                end

                local profExpData = {}
                for recipeID, recipe in pairs(catalogData.r) do
                    local expKey = recipe.exp or "Unknown"
                    if not profExpData[expKey] then
                        profExpData[expKey] = {
                            learnedRecipes = 0,
                            totalRecipes = 0,
                        }
                    end
                    profExpData[expKey].totalRecipes = profExpData[expKey].totalRecipes + 1
                    if knownSet[recipeID] then
                        profExpData[expKey].learnedRecipes = profExpData[expKey].learnedRecipes + 1
                    end
                end
                recipesByExpansion[profInfo.name] = profExpData
            end
        end
    end
    professionData.recipesByExpansion = recipesByExpansion

    return professionData
end

function ProfessionsModule:GetProfessionAbbreviation(professionName)
    if ns.ProfessionData then
        return ns.ProfessionData:GetAbbreviation(professionName)
    end
    return professionName
end

function ProfessionsModule:GetProfessionIcon(professionName)
    if ns.ProfessionData then
        return ns.ProfessionData:GetIcon(professionName)
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end
