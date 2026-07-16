local ADDON_NAME, ns = ...

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
        ns.DataLoader = OneWoW:CreateItemDataLoader(ns:GetDB())
        ns.DataLoader:Initialize()

        if ns.JournalData then
            ns.JournalData:Initialize()
        end
        if ns.JournalScanner then
            ns.JournalScanner:Initialize()
        end
    end,
})
