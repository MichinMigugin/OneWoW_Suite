local addonName, ns = ...

StorageAPI = {
    GetBags = function(charKey)
        if not charKey or not OneWoW_AltTracker_Storage_DB or not OneWoW_AltTracker_Storage_DB.characters then
            return nil
        end
        local charData = OneWoW_AltTracker_Storage_DB.characters[charKey]
        if charData then
            return charData.bags
        end
        return nil
    end,

    GetPersonalBank = function(charKey)
        if not charKey or not OneWoW_AltTracker_Storage_DB or not OneWoW_AltTracker_Storage_DB.characters then
            return nil
        end
        local charData = OneWoW_AltTracker_Storage_DB.characters[charKey]
        if charData then
            return charData.personalBank
        end
        return nil
    end,

    GetWarbandBank = function(charKey)
        if not OneWoW_AltTracker_Storage_DB then
            return nil
        end
        return OneWoW_AltTracker_Storage_DB.warbandBank
    end,

    GetWarbandBankGold = function(charKey)
        if not OneWoW_AltTracker_Storage_DB or not OneWoW_AltTracker_Storage_DB.warbandBank then
            return 0
        end
        return OneWoW_AltTracker_Storage_DB.warbandBank.money or 0
    end,

    GetGuildBank = function(charKey)
        if not OneWoW_AltTracker_Storage_DB or not OneWoW_AltTracker_Storage_DB.characters then
            return nil
        end
        local charData = OneWoW_AltTracker_Storage_DB.characters[charKey]
        if not charData then return nil end

        local guildName = GetGuildInfo("player")
        if not guildName then return nil end

        if OneWoW_AltTracker_Storage_DB.guildBanks then
            return OneWoW_AltTracker_Storage_DB.guildBanks[guildName]
        end
        return nil
    end,

    GetGuildBankGold = function(charKey)
        if not OneWoW_AltTracker_Storage_DB then
            return 0
        end

        local guildName = GetGuildInfo("player")
        if not guildName then return 0 end

        if OneWoW_AltTracker_Storage_DB.guildBanks and OneWoW_AltTracker_Storage_DB.guildBanks[guildName] then
            return OneWoW_AltTracker_Storage_DB.guildBanks[guildName].money or 0
        end
        return 0
    end,

    GetMail = function(charKey)
        if not charKey or not OneWoW_AltTracker_Storage_DB or not OneWoW_AltTracker_Storage_DB.characters then
            return nil
        end
        local charData = OneWoW_AltTracker_Storage_DB.characters[charKey]
        if charData then
            return charData.mail
        end
        return nil
    end,

    -- Returns a live summary of a character's stored mailbox:
    --   { count, hasAnyMail, oldestExpirySeconds, lastScan,
    --     hasUnread, hasCOD, hasReturned, hasAttachment }
    -- Drops already-expired entries on the fly (without persisting). Returns
    -- nil when the character has no mail data at all.
    GetMailSummary = function(charKey)
        if not charKey or not OneWoW_AltTracker_Storage_DB or not OneWoW_AltTracker_Storage_DB.characters then
            return nil
        end
        local charData = OneWoW_AltTracker_Storage_DB.characters[charKey]
        if not charData or not charData.mail then return nil end

        local summary = ns.Mail:GetSummary(charData.mail)
        summary.lastScan = charData.mailLastUpdate
        summary.hasAnyMail = summary.count > 0
        return summary
    end,
}
