-- OneWoW Addon File
-- OneWoW_CatalogData_Quests/Core/Core.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_GUI.DB:BootSubModule(ns, {
    addonName = addonName,
    savedVar = "OneWoW_CatalogData_Quests_DB",
    defaults = ns.DatabaseDefaults,
    onLogin = function()
        if ns.CompletionTracker then
            ns.CompletionTracker:Initialize()
        end
        if ns.QuestScanner then
            ns.QuestScanner:Initialize()
        end

        local catalog = _G.OneWoW_Catalog
        if catalog and catalog.Catalog then
            catalog.Catalog:RegisterDataAddon("quests", ns)
        end
    end,
})
