local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

ns.DatabaseDefaults = {
    characters = {},
    settings = {
        enableDataCollection = true,
        trackAuctions = true,
        trackBids = true,
    },
}

local AH_PRICE_MAX_AGE_DAYS = 14

-- Defaults applied by BootStore (MergeMissing) before this runs. Char-key
-- normalizer plus the ongoing AH price TTL purge remain here.
function ns:InitializeDatabase()
    local migrated = DB:ConsolidateCharacterKeys(OneWoW_AltTracker_Auctions_DB.characters)
    if migrated > 0 then
        C_Timer.After(5, function()
            print("|cFFFFD100OneWoW AltTracker:|r consolidated " .. migrated .. " duplicate character key(s) in auctions data.")
        end)
    end

    if not OneWoW_AHPrices then
        OneWoW_AHPrices = {}
    end

    local cutoff = GetServerTime() - (AH_PRICE_MAX_AGE_DAYS * 86400)
    local purged = 0
    for itemID, data in pairs(OneWoW_AHPrices) do
        if not data.timestamp or data.timestamp < cutoff then
            OneWoW_AHPrices[itemID] = nil
            purged = purged + 1
        end
    end
    if purged > 0 then
        C_Timer.After(5, function()
            print("|cFFFFD100OneWoW:|r Cleaned " .. purged .. " expired AH price entries (>" .. AH_PRICE_MAX_AGE_DAYS .. " days old).")
        end)
    end
end
