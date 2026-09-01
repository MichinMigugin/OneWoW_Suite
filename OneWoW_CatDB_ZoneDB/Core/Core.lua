local ADDON_NAME, ns = ...

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatDB_ZoneDB_DB",
    withScanCallbacks = true,
    onLogin = function()
        ns.DataLoader = OneWoW:CreateItemDataLoader(ns:GetDB())
        ns.DataLoader:Initialize()
    end,
})
