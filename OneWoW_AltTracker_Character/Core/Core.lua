local ADDON_NAME, ns = ...

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_AltTracker_Character_DB",
    defaults = ns.DatabaseDefaults,
    sortField = "lastLogin",
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
