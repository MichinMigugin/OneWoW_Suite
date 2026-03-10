local addonName, ns = ...

if not OneWoW_AltTracker_Professions_DB then
    OneWoW_AltTracker_Professions_DB = {}
end

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

function ns:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if not name or not realm then return nil end
    return name .. "-" .. realm
end

function ns:GetCharacterData(charKey)
    if not charKey then
        charKey = self:GetCharacterKey()
    end

    if not charKey then return nil end

    if not OneWoW_AltTracker_Professions_DB.characters[charKey] then
        OneWoW_AltTracker_Professions_DB.characters[charKey] = {}
    end

    return OneWoW_AltTracker_Professions_DB.characters[charKey]
end

function ns:GetAllCharacters()
    local chars = {}
    for charKey, data in pairs(OneWoW_AltTracker_Professions_DB.characters) do
        table.insert(chars, {
            key = charKey,
            data = data
        })
    end

    table.sort(chars, function(a, b)
        return (a.data.lastUpdate or 0) > (b.data.lastUpdate or 0)
    end)

    return chars
end

function ns:DeleteCharacter(charKey)
    if not charKey then return false end
    OneWoW_AltTracker_Professions_DB.characters[charKey] = nil
    return true
end
