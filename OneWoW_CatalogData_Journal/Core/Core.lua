local ADDON_NAME, ns = ...

local OneWoW = OneWoW
if not OneWoW or not OneWoW.BootStore then return end

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatalogData_Journal_DB",
    withScanCallbacks = true,
    onEnteringWorld = function(_, _, isZoning)
        if isZoning then
            ns:FireScanCallbacks(nil)
        end
    end,
    onLogin = function()
        ns.DataLoader = OneWoW_Catalog:CreateItemDataLoader(ns:GetDB())
        ns.DataLoader:Initialize()

        if ns.JournalData then
            ns.JournalData:Initialize()
        end
        if ns.JournalScanner then
            ns.JournalScanner:Initialize()
        end

        local catalog = OneWoW_Catalog
        if catalog and catalog.Catalog then
            catalog.Catalog:RegisterDataAddon("journal", ns)
        end
    end,
})
