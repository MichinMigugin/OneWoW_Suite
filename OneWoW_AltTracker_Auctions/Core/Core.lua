local addonName, ns = ...
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0")
local DB = OneWoW_GUI.DB

DB:BootSubModule(ns, {
    addonName = addonName,
    savedVar = "OneWoW_AltTracker_Auctions_DB",
    sortField = "lastUpdate",
    onLogin = function()
        if ns.AHScanner then
            ns.AHScanner:Initialize()
        end

        if ns.FullAHScanner then
            ns.FullAHScanner:Initialize()
        end

        if ns.DataManager then
            ns.DataManager:Initialize()
            ns.DataManager:RegisterEvents()
        end
    end,
})
