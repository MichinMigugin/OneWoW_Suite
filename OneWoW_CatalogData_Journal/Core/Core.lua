local ADDON_NAME, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_GUI.DB:BootSubModule(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatalogData_Journal_DB",
    withScanCallbacks = true,
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
