local addonName, ns = ...

ns.GuildBank = {}
local Module = ns.GuildBank

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
                        quality = itemQuality,
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
