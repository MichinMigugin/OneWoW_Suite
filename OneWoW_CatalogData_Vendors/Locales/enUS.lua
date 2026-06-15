local ADDON_NAME, ns = ...

OneWoW.Locale:Register(ADDON_NAME, "enUS", {
    ["ADDON_LOADED"] = "OneWoW CatalogData: Vendor data loaded.",
    ["SCAN_COMPLETE"] = "Vendor scanned: %s (%d items)",
})

ns.L = OneWoW.Locale:GetTable(ADDON_NAME)
