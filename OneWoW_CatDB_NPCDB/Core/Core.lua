local ADDON_NAME, ns = ...

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatDB_NPCDB_DB",
    withScanCallbacks = true,
    onLogin = function()
        ns.DataLoader = OneWoW:CreateItemDataLoader(ns:GetDB())
        ns.DataLoader:Initialize()
        OneWoW.Merchant.RegisterScanCallback("CatDB_NPCDB", function(scan)
            OneWoW_CatDB_NPCDB_API.MergeMerchantScan(scan)
        end)
    end,
})
