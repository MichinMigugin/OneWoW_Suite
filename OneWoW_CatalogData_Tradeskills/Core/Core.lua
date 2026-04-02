-- OneWoW Addon File
-- OneWoW_CatalogData_Tradeskills/Core/Core.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_GUI.DB:BootSubModule(ns, {
    addonName = addonName,
    savedVar = "OneWoW_CatalogData_Tradeskills_DB",
    defaults = ns.DatabaseDefaults,
    withScanCallbacks = true,
    initDB = function()
        local DB = OneWoW_GUI.DB
        if not _G.OneWoW_CatalogData_Tradeskills_DB then _G.OneWoW_CatalogData_Tradeskills_DB = {} end
        DB:MergeMissing(_G.OneWoW_CatalogData_Tradeskills_DB, ns.DatabaseDefaults)
        local db = _G.OneWoW_CatalogData_Tradeskills_DB
        if db.version < 2 then
            ns:MigrateScanCacheKeys()
            db.version = 2
        end
    end,
    onLogin = function()
        local locale = GetLocale()
        if ns.Locales and ns.Locales[locale] then
            ns.L = ns.Locales[locale]
        end

        ns.DataLoader = OneWoW_GUI:CreateItemDataLoader(ns:GetDB())
        ns.DataLoader:Initialize()

        if ns.TradeskillData then
            ns.TradeskillData:Initialize()
        end
        if ns.TradeskillScanner then
            ns.TradeskillScanner:Initialize()
        end

        local catalog = _G.OneWoW_Catalog
        if catalog and catalog.Catalog then
            catalog.Catalog:RegisterDataAddon("tradeskills", ns)
        end
    end,
})
