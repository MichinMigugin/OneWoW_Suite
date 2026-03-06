local addonName, ns = ...

if not OneWoW_AltTracker_Storage_DB then
    OneWoW_AltTracker_Storage_DB = {}
end

ns.DatabaseDefaults = {
    characters = {},
    warbandBank = {
        tabs = {},
        lastUpdatedBy = nil,
        lastUpdateTime = 0,
    },
    guildBanks = {},
    settings = {
        enableDataCollection = true,
        trackBags = true,
        trackPersonalBank = true,
        trackWarbandBank = true,
        trackGuildBank = true,
        trackMail = true,
    },
    version = 2,
}

function ns:InitializeDatabase()
    if not OneWoW_AltTracker_Storage_DB.characters then
        OneWoW_AltTracker_Storage_DB.characters = {}
    end

    if not OneWoW_AltTracker_Storage_DB.warbandBank then
        OneWoW_AltTracker_Storage_DB.warbandBank = ns.DatabaseDefaults.warbandBank
    end

    if not OneWoW_AltTracker_Storage_DB.guildBanks then
        OneWoW_AltTracker_Storage_DB.guildBanks = {}
    end

    if not OneWoW_AltTracker_Storage_DB.settings then
        OneWoW_AltTracker_Storage_DB.settings = ns.DatabaseDefaults.settings
    end

    if not OneWoW_AltTracker_Storage_DB.version then
        OneWoW_AltTracker_Storage_DB.version = ns.DatabaseDefaults.version
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

    if not OneWoW_AltTracker_Storage_DB.characters[charKey] then
        OneWoW_AltTracker_Storage_DB.characters[charKey] = {}
    end

    return OneWoW_AltTracker_Storage_DB.characters[charKey]
end

function ns:GetAllCharacters()
    local chars = {}
    for charKey, data in pairs(OneWoW_AltTracker_Storage_DB.characters) do
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
    OneWoW_AltTracker_Storage_DB.characters[charKey] = nil
    return true
end
