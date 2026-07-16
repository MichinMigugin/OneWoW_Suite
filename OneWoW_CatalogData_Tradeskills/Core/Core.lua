local ADDON_NAME, ns = ...

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatalogData_Tradeskills_DB",
    withScanCallbacks = true,
    onLogin = function()
        ns.DataLoader = OneWoW:CreateItemDataLoader(ns:GetDB())
        ns.DataLoader:Initialize()

        if ns.TradeskillData then
            ns.TradeskillData:Initialize()
        end
        if ns.TradeskillScanner then
            ns.TradeskillScanner:Initialize()
        end
    end,
})
