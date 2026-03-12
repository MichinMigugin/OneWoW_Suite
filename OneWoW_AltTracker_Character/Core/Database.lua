local addonName, ns = ...

if not OneWoW_AltTracker_Character_DB then
    OneWoW_AltTracker_Character_DB = {}
end

ns.DatabaseDefaults = {
    characters = {},
    settings = {
        enablePlaytimeTracking = true,
        playtimeThrottle = 300,
        enableDataCollection = true,
    },
    version = 1,
}

local function IsProfile(tbl)
    return type(tbl) == "table" and type(tbl.name) == "string" and type(tbl.timestamp) == "number"
end

local function MigrateProfilesFlat()
    local profiles = OneWoW_AltTracker_Character_DB.settingsProfiles
    if not profiles or profiles._migrated then return end

    local charBuckets = {}
    local existingProfiles = {}

    for key, value in pairs(profiles) do
        if type(value) == "table" then
            if IsProfile(value) then
                existingProfiles[key] = value
            else
                charBuckets[key] = value
            end
        end
    end

    if next(charBuckets) == nil then
        profiles._migrated = true
        return
    end

    for charKey, bucket in pairs(charBuckets) do
        for profileName, profileData in pairs(bucket) do
            if IsProfile(profileData) then
                profileData.savedBy = profileData.savedBy or charKey
                local targetName = profileName
                if profiles[targetName] and profiles[targetName] ~= profileData then
                    local charName = charKey:match("^([^%-]+)")
                    targetName = profileName .. " (" .. (charName or charKey) .. ")"
                    profileData.name = targetName
                end
                profiles[targetName] = profileData
            end
        end
        profiles[charKey] = nil
    end

    profiles._migrated = true
end

function ns:InitializeDatabase()
    if not OneWoW_AltTracker_Character_DB.characters then
        OneWoW_AltTracker_Character_DB.characters = {}
    end

    if not OneWoW_AltTracker_Character_DB.settings then
        OneWoW_AltTracker_Character_DB.settings = ns.DatabaseDefaults.settings
    end

    if not OneWoW_AltTracker_Character_DB.version then
        OneWoW_AltTracker_Character_DB.version = ns.DatabaseDefaults.version
    end

    if not OneWoW_AltTracker_Character_DB.settingsProfiles then
        OneWoW_AltTracker_Character_DB.settingsProfiles = {}
    end

    if not OneWoW_AltTracker_Character_DB.actionBarSets then
        OneWoW_AltTracker_Character_DB.actionBarSets = {}
    end

    MigrateProfilesFlat()

    if ns.ActionBars and ns.ActionBars.MigrateToNamedSets then
        ns.ActionBars:MigrateToNamedSets()
    end
end

function ns:GetSettingsProfiles()
    if not OneWoW_AltTracker_Character_DB.settingsProfiles then
        OneWoW_AltTracker_Character_DB.settingsProfiles = {}
    end
    return OneWoW_AltTracker_Character_DB.settingsProfiles
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

    if not OneWoW_AltTracker_Character_DB.characters[charKey] then
        OneWoW_AltTracker_Character_DB.characters[charKey] = {}
    end

    return OneWoW_AltTracker_Character_DB.characters[charKey]
end

function ns:GetAllCharacters()
    local chars = {}
    for charKey, data in pairs(OneWoW_AltTracker_Character_DB.characters) do
        table.insert(chars, {
            key = charKey,
            data = data
        })
    end

    table.sort(chars, function(a, b)
        return (a.data.lastLogin or 0) > (b.data.lastLogin or 0)
    end)

    return chars
end

function ns:DeleteCharacter(charKey)
    if not charKey then return false end
    OneWoW_AltTracker_Character_DB.characters[charKey] = nil
    return true
end
