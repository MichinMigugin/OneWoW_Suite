local ADDON_NAME, ns = ...

OneWoW.Locale:Register(ADDON_NAME, "enUS", {
    ["ADDON_LOADED"] = "OneWoW CatalogData: Journal data loaded.",

    ["JOURNAL_STATUS_KNOWN"]         = "Known",
    ["JOURNAL_STATUS_UNKNOWN"]       = "Not Known",
    ["JOURNAL_STATUS_COMPLETED"]     = "Completed",
    ["JOURNAL_STATUS_NOT_COMPLETED"] = "Not Completed",
    ["JOURNAL_STATUS_NA"]            = "N/A",

    ["JOURNAL_GENERAL_LOOT"]  = "General Loot",
    ["JOURNAL_ALSO_FROM_ATT"] = "Also from ATT",
    ["JOURNAL_ACHIEVEMENT_LOOT"] = "Achievement",
    ["JOURNAL_QUEST_LOOT"]    = "Quest Related / Quest Drop",
    ["JOURNAL_UNKNOWN_ITEM"]  = "Unknown Item",
    ["JOURNAL_UNKNOWN_INST"]  = "Unknown Instance",
    ["JOURNAL_LOADING"]       = "Loading...",
})

ns.L = OneWoW.Locale:GetTable(ADDON_NAME)
