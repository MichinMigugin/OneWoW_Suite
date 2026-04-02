local addonName, ns = ...
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0")
local DB = OneWoW_GUI.DB

DB:InitSubModule("OneWoW_AltTracker_Auctions_DB")

ns.DatabaseDefaults = {
    characters = {},
    settings = {
        enableDataCollection = true,
        trackAuctions = true,
        trackBids = true,
    },
    version = 1,
}

local AH_PRICE_MAX_AGE_DAYS = 14

function ns:InitializeDatabase()
    if not OneWoW_AltTracker_Auctions_DB.characters then
        OneWoW_AltTracker_Auctions_DB.characters = {}
    end

    if not OneWoW_AltTracker_Auctions_DB.settings then
        OneWoW_AltTracker_Auctions_DB.settings = ns.DatabaseDefaults.settings
    end

    if not OneWoW_AltTracker_Auctions_DB.version then
        OneWoW_AltTracker_Auctions_DB.version = ns.DatabaseDefaults.version
    end

    if not _G.OneWoW_AHPrices then
        _G.OneWoW_AHPrices = {}
    end

    local cutoff = GetServerTime() - (AH_PRICE_MAX_AGE_DAYS * 86400)
    local purged = 0
    for itemID, data in pairs(_G.OneWoW_AHPrices) do
        if not data.timestamp or data.timestamp < cutoff then
            _G.OneWoW_AHPrices[itemID] = nil
            purged = purged + 1
        end
    end
    if purged > 0 then
        C_Timer.After(5, function()
            print("|cFFFFD100OneWoW:|r Cleaned " .. purged .. " expired AH price entries (>" .. AH_PRICE_MAX_AGE_DAYS .. " days old).")
        end)
    end
end
