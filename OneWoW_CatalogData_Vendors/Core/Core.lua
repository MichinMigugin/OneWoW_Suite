-- OneWoW_CatalogData_Vendors/Core/Core.lua
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_GUI.DB:BootSubModule(ns, {
    addonName = addonName,
    savedVar = "OneWoW_CatalogData_Vendors_DB",
    defaults = ns.DatabaseDefaults,
    withScanCallbacks = true,
    onLogin = function()
        ns.DataLoader = OneWoW_GUI:CreateItemDataLoader(ns:GetDB())
        ns.DataLoader:Initialize()
        if ns.ExtendDataLoaderWithNPC then
            ns:ExtendDataLoaderWithNPC(ns.DataLoader)
        end

        if ns.VendorScanner then
            ns.VendorScanner:Initialize()
        end

        local catalog = _G.OneWoW_Catalog
        if catalog and catalog.Catalog then
            catalog.Catalog:RegisterDataAddon("vendors", ns)
        end
    end,
})
