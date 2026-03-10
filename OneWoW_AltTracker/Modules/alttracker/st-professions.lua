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
