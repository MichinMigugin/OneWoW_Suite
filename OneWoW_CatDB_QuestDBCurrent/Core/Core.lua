local ADDON_NAME, ns = ...

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatDB_QuestDBCurrent_DB",
    onLogin = function()
        ns:SnapshotShippedQuestIDs()
        ns:ApplyLearnedQuests()
        if OneWoW.CatDBSync then
            OneWoW.CatDBSync.Flush("quest")
            OneWoW.CatDBSync.Register("quest", OneWoW_CatDB_QuestDBCurrent_API.GetSyncQueue)
        end
        ns.CompletionTracker:Initialize()
        ns.QuestScanner:Initialize()
    end,
})
