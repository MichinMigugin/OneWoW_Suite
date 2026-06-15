local ADDON_NAME, ns = ...

OneWoW.Locale:Register(ADDON_NAME, "enUS", {
    ["ADDON_LOADED"] = "OneWoW AltTracker: Character data tracking enabled",
    ["DATA_COLLECTED"] = "Character data collected",
    ["DATA_COLLECTION_FAILED"] = "Failed to collect character data",
})

ns.L = OneWoW.Locale:GetTable(ADDON_NAME)
