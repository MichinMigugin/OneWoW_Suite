local _, ns = ...

ns.GuildBank = {}
local Module = ns.GuildBank

-- Guild bank, tabbed (up to 8 viewable tabs). Guild-scope, so it writes
-- DB.guildBanks[guildName]. Slot scanning, the canonical record shape, and the
-- link-hex quality recovery live in ns.ContainerScan; this keeps the tab
-- metadata, money, and write path.
function Module:CollectData(charKey, _)
    if not charKey then return false end

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
        local name, icon, isViewable, canDeposit = GetGuildBankTabInfo(tabID)

        if name and isViewable then
            guildBank.tabs[tabID] = {
                slots = ns.ContainerScan:GuildTabSlots(tabID, 98),
                name = name,
                icon = icon,
                canDeposit = canDeposit,
            }
        end
    end

    OneWoW_AltTracker_Storage_DB.guildBanks[guildName] = guildBank

    return true
end
