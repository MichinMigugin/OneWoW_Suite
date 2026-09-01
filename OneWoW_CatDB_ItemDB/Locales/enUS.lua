local ADDON_NAME, ns = ...

OneWoW.Locale:Register(ADDON_NAME, "enUS", {
    ["ADDON_LOADED"] = "OneWoW CatDB: Item data loaded.",
})

ns.L = OneWoW.Locale:GetTable(ADDON_NAME)
