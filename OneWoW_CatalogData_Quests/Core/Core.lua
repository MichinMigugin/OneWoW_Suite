local ADDON_NAME, ns = ...

local OneWoW = OneWoW

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatalogData_Quests_DB",
    onLogin = function()
        ns.CompletionTracker:Initialize()
        ns.QuestScanner:Initialize()
        OneWoW_Catalog_API.RegisterDataAddon(
            "quests",
            OneWoW_CatalogData_Quests_API
        )
    end,
})
