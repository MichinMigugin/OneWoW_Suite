local ADDON_NAME, ns = ...

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_AltTracker_Professions_DB",
    defaults = ns.DatabaseDefaults,
    sortField = "lastUpdate",
    onLogin = function()
        if ns.ProfessionRecipeCommit then
            ns.ProfessionRecipeCommit:Initialize()
        end

        if ns.DataManager then
            ns.DataManager:Initialize()
            ns.DataManager:RegisterEvents()

            C_Timer.After(2, function()
                ns.DataManager:CollectAllBasicData()
            end)
        end
    end,
})
