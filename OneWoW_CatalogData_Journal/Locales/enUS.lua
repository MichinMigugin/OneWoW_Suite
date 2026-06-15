local ADDON_NAME, ns = ...

OneWoW.Locale:Register(ADDON_NAME, "enUS", {
    ["ADDON_LOADED"] = "OneWoW CatalogData: Journal data loaded.",

    ["JOURNAL_STATUS_COLLECTED"]     = "Collected",
    ["JOURNAL_STATUS_NOT_COLLECTED"] = "Not Collected",
    ["JOURNAL_STATUS_KNOWN"]         = "Known",
    ["JOURNAL_STATUS_UNKNOWN"]       = "Not Known",
    ["JOURNAL_STATUS_COMPLETED"]     = "Completed",
    ["JOURNAL_STATUS_NOT_COMPLETED"] = "Not Completed",
    ["JOURNAL_STATUS_NA"]            = "N/A",

    ["JOURNAL_GENERAL_LOOT"]  = "General Loot",
    ["JOURNAL_UNKNOWN_ITEM"]  = "Unknown Item",
    ["JOURNAL_UNKNOWN_INST"]  = "Unknown Instance",
    ["JOURNAL_LOADING"]       = "Loading...",
    ["JOURNAL_LIVE_EJ_TAG"]   = "Guide",
})

ns.L = OneWoW.Locale:GetTable(ADDON_NAME)
