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

    if not OneWoW_AltTracker_Storage_DB.mailDataCleaned then
        local cleaned = 0
        for charKey, charData in pairs(OneWoW_AltTracker_Storage_DB.characters) do
            if charData.mail and charData.mail.mails then
                local toRemove = {}
                for mailID, mailData in pairs(charData.mail.mails) do
                    if mailData.isAwaitingCollection then
                        table.insert(toRemove, mailID)
                        cleaned = cleaned + 1
                    elseif mailData.items then
                        for attachIdx, itemData in pairs(mailData.items) do
                            if itemData.count and itemData.count > 10000 then
                                itemData.count = 1
                                cleaned = cleaned + 1
                            end
                        end
                    end
                end
                for _, mailID in ipairs(toRemove) do
                    charData.mail.mails[mailID] = nil
                end
            end
        end
        OneWoW_AltTracker_Storage_DB.mailDataCleaned = true
        if cleaned > 0 then
            C_Timer.After(5, function()
                print("|cFFFFD100OneWoW AltTracker:|r Cleaned " .. cleaned .. " corrupted or stale mail entries.")
            end)
        end
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
