local _, ns = ...

ns.ProfessionsModule = ns.ProfessionsModule or {}
local ProfessionsModule = ns.ProfessionsModule

function ProfessionsModule:Initialize()
    self.initialized = true
end

function ProfessionsModule:GetCharacterProfessions(characterKey)
    if not characterKey then
        return {professions = {}, professionEquipment = {}, recipeCount = 0, recipesByExpansion = {}}
    end

    if not OneWoW_AltTracker_Professions_API then
        return {professions = {}, professionEquipment = {}, recipeCount = 0, recipesByExpansion = {}}
    end

    local charData = OneWoW_AltTracker_Professions_API.GetCharacterData(characterKey)
    if not charData then
        return {professions = {}, professionEquipment = {}, recipeCount = 0, recipesByExpansion = {}}
    end

    local professionData = {
        professions = charData.professions or {},
        professionEquipment = charData.professionEquipment or {},
        concentration = charData.concentration or {},
        recipeCount = 0,
        recipesByExpansion = {},
        recipeProgress = {},
        catalogLoaded = false,
        weeklyQuestStatus = {}
    }

    if charData.recipes then
        local count = 0
        for _, recipes in pairs(charData.recipes) do
            for _ in pairs(recipes) do
                count = count + 1
            end
        end
        professionData.recipeCount = count
    end

    -- Recipe comparison is sourced from the Professions unit's API, which folds
    -- in the LoD catalog data when it is loaded and degrades to stored-only
    -- counts when it is not (no fake "Total 0 / Known 0"). recipesByExpansion is
    -- kept for the profession tooltip's per-expansion breakdown (catalog-only).
    local recipesByExpansion = {}
    local recipeProgress = {}
    local catalogLoaded = false
    local professions = charData.professions or {}

    for _, profInfo in pairs(professions) do
        if profInfo and profInfo.name then
            local progress = OneWoW_AltTracker_Professions_API.GetRecipeProgress(characterKey, profInfo.name)
            recipeProgress[profInfo.name] = progress
            if progress.catalogLoaded then
                catalogLoaded = true
                recipesByExpansion[profInfo.name] = progress.byExpansion
            end
        end
    end

    professionData.recipesByExpansion = recipesByExpansion
    professionData.recipeProgress = recipeProgress
    professionData.catalogLoaded = catalogLoaded

    return professionData
end

function ProfessionsModule:GetProfessionAbbreviation(professionName)
    if ns.ProfessionData then
        return ns.ProfessionData:GetAbbreviation(professionName)
    end
    return professionName
end

function ProfessionsModule:GetProfessionIcon(profDataOrName, iconFileID, skillLine)
    if ns.ProfessionData then
        if type(profDataOrName) == "table" then
            return ns.ProfessionData:GetIconFromProf(profDataOrName)
        end
        return ns.ProfessionData:GetIcon(profDataOrName, iconFileID, skillLine)
    end
    return 134400
end
