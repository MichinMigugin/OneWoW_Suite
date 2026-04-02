local addonName, ns = ...
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0")
local DB = OneWoW_GUI.DB

DB:InitSubModule("OneWoW_AltTracker_Professions_DB")

ns.DatabaseDefaults = {
    characters = {},
    settings = {
        enableDataCollection = true,
        trackRecipes = true,
        trackEquipment = true,
    },
    version = 2,
}

function ns:InitializeDatabase()
    if not OneWoW_AltTracker_Professions_DB.characters then
        OneWoW_AltTracker_Professions_DB.characters = {}
    end

    if not OneWoW_AltTracker_Professions_DB.settings then
        OneWoW_AltTracker_Professions_DB.settings = ns.DatabaseDefaults.settings
    end

    if not OneWoW_AltTracker_Professions_DB.version then
        OneWoW_AltTracker_Professions_DB.version = 1
    end

    if OneWoW_AltTracker_Professions_DB.version < 2 then
        self:MigrateToV2()
        OneWoW_AltTracker_Professions_DB.version = 2
    end
end

function ns:MigrateToV2()
    local db = OneWoW_AltTracker_Professions_DB
    if not db.characters then return end

    local totalCleaned = 0

    for charKey, charData in pairs(db.characters) do
        if charData.recipes then
            for profName, recipes in pairs(charData.recipes) do
                local slimmed = {}
                for recipeID, recipeData in pairs(recipes) do
                    if type(recipeData) == "table" then
                        slimmed[recipeID] = true
                        totalCleaned = totalCleaned + 1
                    else
                        slimmed[recipeID] = recipeData
                    end
                end
                charData.recipes[profName] = slimmed
            end
        end

        charData.recipesByExpansion = nil
        charData.recipeCooldowns = nil
        charData.trainerLocations = nil
    end

    if db.settings then
        db.settings.trackCooldowns = nil
        db.settings.trackTrainers = nil
    end
end
