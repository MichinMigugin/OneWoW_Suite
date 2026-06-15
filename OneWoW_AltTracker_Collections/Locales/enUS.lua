local ADDON_NAME, ns = ...

OneWoW.Locale:Register(ADDON_NAME, "enUS", {
    ["ADDON_LOADED"] = "OneWoW AltTracker: Collections data tracking enabled",
    ["DATA_COLLECTED"] = "Collections data collected",
    ["DATA_COLLECTION_FAILED"] = "Failed to collect collections data",
})

ns.L = OneWoW.Locale:GetTable(ADDON_NAME)
