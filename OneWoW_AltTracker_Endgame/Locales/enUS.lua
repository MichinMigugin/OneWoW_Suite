local ADDON_NAME, ns = ...

OneWoW.Locale:Register(ADDON_NAME, "enUS", {
    ["ADDON_LOADED"] = "OneWoW AltTracker: Endgame data tracking enabled",
    ["DATA_COLLECTED"] = "Endgame data collected",
    ["DATA_COLLECTION_FAILED"] = "Failed to collect endgame data",
})

ns.L = OneWoW.Locale:GetTable(ADDON_NAME)
