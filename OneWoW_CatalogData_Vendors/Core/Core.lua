local ADDON_NAME, ns = ...

local OneWoW = OneWoW
if not OneWoW or not OneWoW.BootStore then return end

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatalogData_Vendors_DB",
    withScanCallbacks = true,
    onLogin = function()
        ns.DataLoader = OneWoW_Catalog_API.CreateItemDataLoader(ns:GetDB())
        ns.DataLoader:Initialize()
        if ns.ExtendDataLoaderWithNPC then
            ns:ExtendDataLoaderWithNPC(ns.DataLoader)
        end

        if ns.VendorScanner then
            ns.VendorScanner:Initialize()
        end

        if OneWoW_Catalog_API then
            OneWoW_Catalog_API.RegisterDataAddon("vendors", ns)
        end
    end,
})
