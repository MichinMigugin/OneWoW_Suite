local addonName, ns = ...

if not OneWoW_AltTracker_Collections_DB then
    OneWoW_AltTracker_Collections_DB = {}
end

ns.DatabaseDefaults = {
    characters = {},
    settings = {
        enableDataCollection = true,
    },
    version = 4,
}

function ns:InitializeDatabase()
    if not OneWoW_AltTracker_Collections_DB.characters then
        OneWoW_AltTracker_Collections_DB.characters = {}
    end

    if not OneWoW_AltTracker_Collections_DB.settings then
        OneWoW_AltTracker_Collections_DB.settings = ns.DatabaseDefaults.settings
    end

    local currentVersion = OneWoW_AltTracker_Collections_DB.version or 1

    if currentVersion < 4 then
        OneWoW_AltTracker_Collections_DB.account = nil
        for _, charData in pairs(OneWoW_AltTracker_Collections_DB.characters) do
            charData.petsMounts = nil
            if charData.reputations and charData.reputations.factions then
                for _, faction in ipairs(charData.reputations.factions) do
                    faction.description = nil
                end
            end
        end
    end

    OneWoW_AltTracker_Collections_DB.version = 4
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

    if not OneWoW_AltTracker_Collections_DB.characters[charKey] then
        OneWoW_AltTracker_Collections_DB.characters[charKey] = {}
    end

    return OneWoW_AltTracker_Collections_DB.characters[charKey]
end

function ns:GetAllCharacters()
    local chars = {}
    for charKey, data in pairs(OneWoW_AltTracker_Collections_DB.characters) do
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
    OneWoW_AltTracker_Collections_DB.characters[charKey] = nil
    return true
end
