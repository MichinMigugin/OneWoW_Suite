local _, ns = ...

StorageAPI = {
    GetBags = function(charKey)
        if not charKey then return nil end
        local charData = ns.db.characters[charKey]
        return charData and charData.bags or nil
    end,

    GetPersonalBank = function(charKey)
        if not charKey then return nil end
        local charData = ns.db.characters[charKey]
        return charData and charData.personalBank or nil
    end,

    GetWarbandBank = function(charKey)
        return ns.db.warbandBank
    end,

    GetWarbandBankGold = function(charKey)
        return ns.db.warbandBank.money or 0
    end,

    GetGuildBank = function(charKey)
        if not charKey then return nil end
        local charData = ns.db.characters[charKey]
        if not charData then return nil end

        local guildName = GetGuildInfo("player")
        if not guildName then return nil end

        return ns.db.guildBanks[guildName]
    end,

    GetGuildBankGold = function(charKey)
        local guildName = GetGuildInfo("player")
        if not guildName then return 0 end

        local guildBank = ns.db.guildBanks[guildName]
        return guildBank and guildBank.money or 0
    end,

    GetMail = function(charKey)
        if not charKey then return nil end
        local charData = ns.db.characters[charKey]
        return charData and charData.mail or nil
    end,

    -- Returns a live summary of a character's stored mailbox:
    --   { count, hasAnyMail, oldestExpirySeconds, lastScan,
    --     hasUnread, hasCOD, hasReturned, hasAttachment }
    -- Drops already-expired entries on the fly (without persisting). Returns
    -- nil when the character has no mail data at all.
    GetMailSummary = function(charKey)
        if not charKey then return nil end
        local charData = ns.db.characters[charKey]
        if not charData or not charData.mail then return nil end

        local summary = ns.Mail:GetSummary(charData.mail)
        summary.lastScan = charData.mailLastUpdate
        -- HasNewMail() captured at login (persisted as mail.hasNewMail) lights
        -- the icon even before the inbox has been scanned into mail.mails, so a
        -- character with freshly arrived mail shows up without visiting the box.
        summary.hasNewMail = charData.mail.hasNewMail == true
        summary.hasAnyMail = summary.count > 0 or summary.hasNewMail
        return summary
    end,
}
