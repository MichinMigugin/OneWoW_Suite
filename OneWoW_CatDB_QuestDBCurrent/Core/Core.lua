local ADDON_NAME, ns = ...

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatDB_QuestDBCurrent_DB",
    onLogin = function()
        ns.CompletionTracker:Initialize()
    end,
})
