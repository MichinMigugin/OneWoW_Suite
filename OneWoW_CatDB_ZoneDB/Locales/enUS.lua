local ADDON_NAME, ns = ...

OneWoW.Locale:Register(ADDON_NAME, "enUS", {
    ["ADDON_LOADED"] = "OneWoW CatDB: Zone data loaded.",

    ["JOURNAL_GENERAL_LOOT"]  = "General Loot",
    ["JOURNAL_WORLD_BOSSES"]  = "World Bosses",
    ["JOURNAL_WORLD_RARES"]   = "World Rares",
    ["JOURNAL_NPC_UNNAMED"]   = "NPC #%d",
    ["JOURNAL_UNKNOWN_ITEM"]  = "Unknown Item",
    ["JOURNAL_UNKNOWN_INST"]  = "Unknown Instance",
})

ns.L = OneWoW.Locale:GetTable(ADDON_NAME)
