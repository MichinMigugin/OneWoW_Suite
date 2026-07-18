local _, ns = ...

-- Public, cross-addon read surface for the Storage unit. Other suite units
-- (RequiredDeps on this addon) call these directly; ns stays private.
OneWoW_AltTracker_Storage_API = {}

--- Stored bag contents for a character, keyed by bag ID.
---@param charKey string
---@return table|nil bags nil if no key or the character has no stored bags
function OneWoW_AltTracker_Storage_API.GetBags(charKey)
    if not charKey then return nil end
    local charData = OneWoW_AltTracker_Storage_DB.characters[charKey]
    return charData and charData.bags or nil
end

--- Stored personal (character) bank contents for a character.
---@param charKey string
---@return table|nil personalBank nil if no key or no stored bank data
function OneWoW_AltTracker_Storage_API.GetPersonalBank(charKey)
    if not charKey then return nil end
    local charData = OneWoW_AltTracker_Storage_DB.characters[charKey]
    return charData and charData.personalBank or nil
end

--- All stored characters, keyed by charKey. Read-only iteration surface for
--- consumers that aggregate across every tracked character (item search, alt
--- inventory rollups).
---@return table characters map of charKey -> stored character data
function OneWoW_AltTracker_Storage_API.GetCharacters()
    return OneWoW_AltTracker_Storage_DB.characters
end

--- Account-wide warband bank contents (shared across all characters).
---@return table warbandBank
function OneWoW_AltTracker_Storage_API.GetWarbandBank()
    return OneWoW_AltTracker_Storage_DB.warbandBank
end

--- All stored guild banks, keyed by guild name. For cross-guild aggregation;
--- use GetGuildBank(charKey) for just the current player's guild.
---@return table guildBanks map of guildName -> stored guild bank
function OneWoW_AltTracker_Storage_API.GetGuildBanks()
    return OneWoW_AltTracker_Storage_DB.guildBanks
end

--- Gold (copper) stored in the account-wide warband bank.
---@return number copper
function OneWoW_AltTracker_Storage_API.GetWarbandBankGold()
    return OneWoW_AltTracker_Storage_DB.warbandBank.money or 0
end

--- Stored guild bank contents for the current player's guild. The character
--- must be known; the guild is resolved from the logged-in player, not charKey.
---@param charKey string
---@return table|nil guildBank nil if no key, unknown character, or no guild
function OneWoW_AltTracker_Storage_API.GetGuildBank(charKey)
    if not charKey then return nil end
    local charData = OneWoW_AltTracker_Storage_DB.characters[charKey]
    if not charData then return nil end

    local guildName = GetGuildInfo("player")
    if not guildName then return nil end

    return OneWoW_AltTracker_Storage_DB.guildBanks[guildName]
end

--- Gold (copper) stored in the current player's guild bank.
---@return number copper
function OneWoW_AltTracker_Storage_API.GetGuildBankGold()
    local guildName = GetGuildInfo("player")
    if not guildName then return 0 end

    local guildBank = OneWoW_AltTracker_Storage_DB.guildBanks[guildName]
    return guildBank and guildBank.money or 0
end

--- Stored mailbox for a character.
---@param charKey string
---@return table|nil mail nil if no key or no stored mail data
function OneWoW_AltTracker_Storage_API.GetMail(charKey)
    if not charKey then return nil end
    local charData = OneWoW_AltTracker_Storage_DB.characters[charKey]
    return charData and charData.mail or nil
end

---@class OneWoWStorageMailSummary
---@field count number non-expired stored entries
---@field oldestExpirySeconds number|nil soonest expiry across entries
---@field hasUnread boolean
---@field hasCOD boolean
---@field hasReturned boolean
---@field hasAttachment boolean
---@field hasNewMail boolean login-captured new-mail flag
---@field hasAnyMail boolean count > 0 or hasNewMail
---@field lastScan number|nil epoch seconds of the last inbox scan

--- Live summary of a character's stored mailbox. Drops already-expired entries
--- on the fly (without persisting).
---@param charKey string
---@return OneWoWStorageMailSummary|nil summary nil if the character has no mail data
function OneWoW_AltTracker_Storage_API.GetMailSummary(charKey)
    if not charKey then return nil end
    local charData = OneWoW_AltTracker_Storage_DB.characters[charKey]
    if not charData or not charData.mail then return nil end

    local summary = ns.Mail:GetSummary(charData.mail)
    summary.lastScan = charData.mailLastUpdate
    -- HasNewMail() captured at login (persisted as mail.hasNewMail) lights the
    -- icon even before the inbox has been scanned into mail.mails, so a
    -- character with freshly arrived mail shows up without visiting the box.
    summary.hasNewMail = charData.mail.hasNewMail == true
    summary.hasAnyMail = summary.count > 0 or summary.hasNewMail
    return summary
end

--- The shared item index module (inverted item -> location lookups across all
--- stored characters/banks). Consumers call methods on it, e.g.
--- `GetItemIndex():GetFamilyLocations(itemID)`.
---@return table itemIndex the ns.ItemIndex module
function OneWoW_AltTracker_Storage_API.GetItemIndex()
    return ns.ItemIndex
end

--- Subscribe to post-write storage-change signals. The callback fires after a
--- scanner writes to SavedVariables, receiving a { scope, charKey } table
--- (scope = "bags"|"personal"|"warband"|"guild"|"mail"). Use it to refresh
--- views/caches once the changed data has landed.
---@param callback fun(info: table)
function OneWoW_AltTracker_Storage_API.RegisterStorageChanged(callback)
    ns.DataManager:RegisterStorageChanged(callback)
end

--- In-transit shipments awaiting collection on a character (sibling of inbox mail).
---@param charKey string
---@return table list
function OneWoW_AltTracker_Storage_API.GetInTransitShipments(charKey)
    if not charKey then return {} end
    local charData = OneWoW_AltTracker_Storage_DB.characters[charKey]
    if not charData then return {} end
    charData.inTransitShipments = charData.inTransitShipments or {}
    return charData.inTransitShipments
end

--- Append an in-transit shipment record for a suite alt recipient.
---@param charKey string
---@param entry table
function OneWoW_AltTracker_Storage_API.AddInTransitShipment(charKey, entry)
    if not charKey or not entry then return end
    local chars = OneWoW_AltTracker_Storage_DB.characters
    chars[charKey] = chars[charKey] or {}
    local list = chars[charKey].inTransitShipments
    if not list then
        list = {}
        chars[charKey].inTransitShipments = list
    end
    tinsert(list, entry)
    if ns.DataManager and ns.DataManager.NotifyStorageChanged then
        ns.DataManager:NotifyStorageChanged("mail", charKey)
    end
end

--- Remove in-transit entries whose subject matches a collected mail.
---@param charKey string
---@param subject string
function OneWoW_AltTracker_Storage_API.ClearInTransitBySubject(charKey, subject)
    if not charKey or not subject then return end
    local charData = OneWoW_AltTracker_Storage_DB.characters[charKey]
    if not charData or not charData.inTransitShipments then return end
    local list = charData.inTransitShipments
    for i = #list, 1, -1 do
        if list[i].subject == subject then
            tremove(list, i)
        end
    end
    if ns.DataManager and ns.DataManager.NotifyStorageChanged then
        ns.DataManager:NotifyStorageChanged("mail", charKey)
    end
end

--- Drop every in-transit row for a character (inbox fully empty after collect).
---@param charKey string
function OneWoW_AltTracker_Storage_API.ClearAllInTransit(charKey)
    if not charKey then return end
    local charData = OneWoW_AltTracker_Storage_DB.characters[charKey]
    if not charData or not charData.inTransitShipments then return end
    if #charData.inTransitShipments == 0 then return end
    wipe(charData.inTransitShipments)
    if ns.DataManager and ns.DataManager.NotifyStorageChanged then
        ns.DataManager:NotifyStorageChanged("mail", charKey)
    end
end
