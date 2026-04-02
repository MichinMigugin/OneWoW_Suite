local addonName, ns = ...
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0")
local DB = OneWoW_GUI.DB

DB:BootSubModule(ns, {
    addonName = addonName,
    savedVar = "OneWoW_AltTracker_Character_DB",
    sortField = "lastLogin",
    onLogin = function()
        if ns.DataManager then
            ns.DataManager:Initialize()
            ns.DataManager:RegisterEvents()
        end
    end,
})
