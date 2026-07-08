local ADDON_NAME, ns = ...

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_AltTracker_Storage_DB",
    defaults = ns.DatabaseDefaults,
    sortField = "lastUpdate",
    onLogin = function()
        if ns.Mail then
            ns.Mail:Initialize()
        end

        if ns.DataManager then
            ns.DataManager:Initialize()
            ns.DataManager:RegisterEvents()
            ns.DataManager:CollectBags()
        end

        if ns.ItemIndex then
            ns.ItemIndex:Initialize()
        end
    end,
    onEnteringWorld = function()
        if ns.DataManager then
            ns.DataManager:OnEnteringWorld()
        end
    end,
})
