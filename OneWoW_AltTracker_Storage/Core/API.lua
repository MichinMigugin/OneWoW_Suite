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
