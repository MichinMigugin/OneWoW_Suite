local ADDON_NAME, ns = ...

local OneWoW = OneWoW
if not OneWoW or not OneWoW.BootStore then return end

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatalogData_Tradeskills_DB",
    withScanCallbacks = true,
    onLogin = function()
        ns.DataLoader = OneWoW_Catalog_API.CreateItemDataLoader(ns:GetDB())
        ns.DataLoader:Initialize()

        if ns.TradeskillData then
            ns.TradeskillData:Initialize()
        end
        if ns.TradeskillScanner then
            ns.TradeskillScanner:Initialize()
        end

        if OneWoW_Catalog_API then
            OneWoW_Catalog_API.RegisterDataAddon("tradeskills", ns)
        end
    end,
})
