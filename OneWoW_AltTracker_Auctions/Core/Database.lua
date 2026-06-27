local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

ns.DatabaseDefaults = {
    characters = {},
    settings = {
        enableDataCollection = true,
        trackAuctions = true,
        trackBids = true,
        autoScanOnOpen = false,
    },
}

-- Defaults applied by BootStore (MergeMissing) before this runs. Char-key
-- normalizer; AH price cache init/TTL handled by AHPriceCache.
function ns:InitializeDatabase()
    local migrated = DB:ConsolidateCharacterKeys(OneWoW_AltTracker_Auctions_DB.characters)
    if migrated > 0 then
        C_Timer.After(5, function()
            print("|cFFFFD100OneWoW AltTracker:|r consolidated " .. migrated .. " duplicate character key(s) in auctions data.")
        end)
    end

    if ns.AHPriceCache then
        ns.AHPriceCache:Initialize()
    end
end
