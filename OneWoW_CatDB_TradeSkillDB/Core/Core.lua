local ADDON_NAME, ns = ...

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatDB_TradeSkillDB_DB",
    withScanCallbacks = true,
    onLogin = function()
        ns.DataLoader = OneWoW:CreateItemDataLoader(ns:GetDB())
        ns.DataLoader:Initialize()
        if OneWoW.CatDBSync then
            OneWoW.CatDBSync.Flush("recipe")
            OneWoW.CatDBSync.Register("recipe", OneWoW_CatDB_TradeSkillDB_API.GetSyncQueue)
        end
    end,
})
