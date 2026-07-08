local ADDON_NAME, ns = ...

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_AltTracker_Collections_DB",
    defaults = ns.DatabaseDefaults,
    sortField = "lastUpdate",
    onLogin = function()
        if ns.DataManager then
            ns.DataManager:Initialize()
            ns.DataManager:RegisterEvents()
        end
    end,
    onEnteringWorld = function()
        if ns.DataManager then
            ns.DataManager:OnEnteringWorld()
        end
    end,
})
