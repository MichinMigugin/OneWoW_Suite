local addonName, ns = ...
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0")
local DB = OneWoW_GUI.DB

DB:BootSubModule(ns, {
    addonName = addonName,
    savedVar = "OneWoW_AltTracker_Storage_DB",
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
})
