local ADDON_NAME, ns = ...

local OneWoW = OneWoW
if not OneWoW or not OneWoW.BootStore then return end

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatalogData_Quests_DB",
    onLogin = function()
        ns.CompletionTracker:Initialize()
        ns.QuestScanner:Initialize()
        OneWoW_Catalog.Catalog:RegisterDataAddon("quests", ns)
    end,
})
