local ADDON_NAME, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_GUI.DB:BootSubModule(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatalogData_Quests_DB",
    defaults = ns.DatabaseDefaults,
    onLogin = function()
        ns.CompletionTracker:Initialize()
        ns.QuestScanner:Initialize()
        OneWoW_Catalog.Catalog:RegisterDataAddon("quests", ns)
    end,
})
