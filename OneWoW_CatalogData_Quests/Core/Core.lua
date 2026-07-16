local ADDON_NAME, ns = ...

local OneWoW = OneWoW

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatalogData_Quests_DB",
    onLogin = function()
        ns.CompletionTracker:Initialize()
        ns.QuestScanner:Initialize()
    end,
})
