local ADDON_NAME, ns = ...

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatDB_NPCDB_DB",
    withScanCallbacks = true,
    onLogin = function()
        ns.DataLoader = OneWoW:CreateItemDataLoader(ns:GetDB())
        ns.DataLoader:Initialize()
        ns:ApplyLearnedNPCs()
        if OneWoW.CatDBSync then
            OneWoW.CatDBSync.Flush("npc")
            OneWoW.CatDBSync.Register("npc", OneWoW_CatDB_NPCDB_API.GetSyncQueue)
        end
        OneWoW.Merchant.RegisterScanCallback("CatDB_NPCDB", function(scan)
            OneWoW_CatDB_NPCDB_API.MergeMerchantScan(scan)
        end)
    end,
})
