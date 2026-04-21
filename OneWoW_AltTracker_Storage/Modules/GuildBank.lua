local addonName, ns = ...

ns.GuildBank = {}
local Module = ns.GuildBank

local LINK_COLOR_TO_QUALITY = {
    ["ff9d9d9d"] = 0, -- Poor
    ["ffffffff"] = 1, -- Common
    ["ff1eff00"] = 2, -- Uncommon
    ["ff0070dd"] = 3, -- Rare
    ["ffa335ee"] = 4, -- Epic
    ["ffff8000"] = 5, -- Legendary
    ["ffe6cc80"] = 6, -- Artifact
    ["ff00ccff"] = 7, -- Heirloom
}

local function QualityFromLink(itemLink)
    if not itemLink then return nil end
    local hex = itemLink:match("|c(%x%x%x%x%x%x%x%x)")
    return hex and LINK_COLOR_TO_QUALITY[hex:lower()] or nil
end

function Module:CollectData(charKey, charData)
    if not charKey then return false end
    if not _G.OneWoW_AltTracker_Storage_DB then return false end

    if not IsInGuild() then
        return true
    end

    local guildName = GetGuildInfo("player")
    if not guildName then return false end

    local guildBank = {
        tabs = {},
        money = 0,
        guildName = guildName,
        lastUpdatedBy = charKey,
        lastUpdateTime = time(),
    }

    guildBank.money = GetGuildBankMoney()

    for tabID = 1, 8 do
        local name, icon, isViewable, canDeposit, numWithdrawals, remainingWithdrawals = GetGuildBankTabInfo(tabID)

        if name and isViewable then
            guildBank.tabs[tabID] = {
                slots = {},
                name = name,
                icon = icon,
                canDeposit = canDeposit,
            }

            for slotID = 1, 98 do
                local itemLink = GetGuildBankItemLink(tabID, slotID)

                if itemLink then
                    local texture, itemCount, locked = GetGuildBankItemInfo(tabID, slotID)
                    local itemID = tonumber(itemLink:match("item:(%d+)"))
                    local itemName, _, itemQuality, itemLevel, _, _, _, _, _, itemTexture, sellPrice = GetItemInfo(itemLink)

                    guildBank.tabs[tabID].slots[slotID] = {
                        itemID = itemID,
                        itemLink = itemLink,
                        itemName = itemName,
                        quality = QualityFromLink(itemLink) or itemQuality,
                        itemLevel = itemLevel,
                        texture = texture,
                        sellPrice = sellPrice or 0,
                        stackCount = itemCount,
                        isLocked = locked,
                    }
                end
            end
        end
    end

    if not _G.OneWoW_AltTracker_Storage_DB.guildBanks then
        _G.OneWoW_AltTracker_Storage_DB.guildBanks = {}
    end

    _G.OneWoW_AltTracker_Storage_DB.guildBanks[guildName] = guildBank

    return true
end
