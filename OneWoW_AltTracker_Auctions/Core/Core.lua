local ADDON_NAME, ns = ...

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_AltTracker_Auctions_DB",
    defaults = ns.DatabaseDefaults,
    sortField = "lastUpdate",
    onLogin = function()
        if ns.AHReplicateScanner then
            ns.AHReplicateScanner:Initialize()
        end

        if ns.AHPricesPanel then
            ns.AHPricesPanel:Initialize()
        end

        if ns.DataManager then
            ns.DataManager:Initialize()
            ns.DataManager:RegisterEvents()
        end
    end,
})
