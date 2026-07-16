local ADDON_NAME, ns = ...

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatalogData_Vendors_DB",
    withScanCallbacks = true,
    onLogin = function()
        ns.DataLoader = OneWoW:CreateItemDataLoader(ns:GetDB())
        ns.DataLoader:Initialize()
        if ns.ExtendDataLoaderWithNPC then
            ns:ExtendDataLoaderWithNPC(ns.DataLoader)
        end

        if ns.VendorScanner then
            ns.VendorScanner:Initialize()
        end
    end,
})
