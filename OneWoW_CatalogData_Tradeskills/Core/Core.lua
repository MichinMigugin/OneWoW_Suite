local ADDON_NAME, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_GUI.DB:BootSubModule(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatalogData_Tradeskills_DB",
    withScanCallbacks = true,
    onLogin = function()
        local locale = GetLocale()
        if ns.Locales and ns.Locales[locale] then
            ns.L = ns.Locales[locale]
        end

        ns.DataLoader = OneWoW_Catalog:CreateItemDataLoader(ns:GetDB())
        ns.DataLoader:Initialize()

        if ns.TradeskillData then
            ns.TradeskillData:Initialize()
        end
        if ns.TradeskillScanner then
            ns.TradeskillScanner:Initialize()
        end

        local catalog = OneWoW_Catalog
        if catalog and catalog.Catalog then
            catalog.Catalog:RegisterDataAddon("tradeskills", ns)
        end
    end,
})
