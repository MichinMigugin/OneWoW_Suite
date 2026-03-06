local addonName, ns = ...

_G.StorageAPI = {
    GetBags = function(charKey)
        if not charKey or not _G.OneWoW_AltTracker_Storage_DB or not _G.OneWoW_AltTracker_Storage_DB.characters then
            return nil
        end
        local charData = _G.OneWoW_AltTracker_Storage_DB.characters[charKey]
        if charData then
            return charData.bags
        end
        return nil
    end,

    GetPersonalBank = function(charKey)
        if not charKey or not _G.OneWoW_AltTracker_Storage_DB or not _G.OneWoW_AltTracker_Storage_DB.characters then
            return nil
        end
        local charData = _G.OneWoW_AltTracker_Storage_DB.characters[charKey]
        if charData then
            return charData.personalBank
        end
        return nil
    end,

    GetWarbandBank = function(charKey)
        if not _G.OneWoW_AltTracker_Storage_DB then
            return nil
        end
        return _G.OneWoW_AltTracker_Storage_DB.warbandBank
    end,

    GetWarbandBankGold = function(charKey)
        if not _G.OneWoW_AltTracker_Storage_DB or not _G.OneWoW_AltTracker_Storage_DB.warbandBank then
            return 0
        end
        return _G.OneWoW_AltTracker_Storage_DB.warbandBank.money or 0
    end,

    GetGuildBank = function(charKey)
        if not _G.OneWoW_AltTracker_Storage_DB or not _G.OneWoW_AltTracker_Storage_DB.characters then
            return nil
        end
        local charData = _G.OneWoW_AltTracker_Storage_DB.characters[charKey]
        if not charData then return nil end

        local guildName = GetGuildInfo("player")
        if not guildName then return nil end

        if _G.OneWoW_AltTracker_Storage_DB.guildBanks then
            return _G.OneWoW_AltTracker_Storage_DB.guildBanks[guildName]
        end
        return nil
    end,

    GetGuildBankGold = function(charKey)
        if not _G.OneWoW_AltTracker_Storage_DB then
            return 0
        end

        local guildName = GetGuildInfo("player")
        if not guildName then return 0 end

        if _G.OneWoW_AltTracker_Storage_DB.guildBanks and _G.OneWoW_AltTracker_Storage_DB.guildBanks[guildName] then
            return _G.OneWoW_AltTracker_Storage_DB.guildBanks[guildName].money or 0
        end
        return 0
    end,

    GetMail = function(charKey)
        if not charKey or not _G.OneWoW_AltTracker_Storage_DB or not _G.OneWoW_AltTracker_Storage_DB.characters then
            return nil
        end
        local charData = _G.OneWoW_AltTracker_Storage_DB.characters[charKey]
        if charData then
            return charData.mail
        end
        return nil
    end,
}
