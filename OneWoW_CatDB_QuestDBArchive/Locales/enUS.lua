local ADDON_NAME, ns = ...

OneWoW.Locale:Register(ADDON_NAME, "enUS", {
    ["ADDON_LOADED"] = "OneWoW CatDB: Quest archive data loaded.",
})

ns.L = OneWoW.Locale:GetTable(ADDON_NAME)
