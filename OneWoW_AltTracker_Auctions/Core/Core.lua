local ADDON_NAME, ns = ...

local OneWoW = OneWoW
if not OneWoW or not OneWoW.BootStore then return end

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
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
