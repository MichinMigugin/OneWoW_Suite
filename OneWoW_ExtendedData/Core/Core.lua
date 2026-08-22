local ADDON_NAME, ns = ...

local OneWoW = OneWoW

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    initDB = function()
        OneWoW:RegisterDataReadyWatcher("OneWoW_CatalogData_Quests", function()
            ns.FlushQuestData()
        end)
        OneWoW:RegisterDataReadyWatcher("OneWoW_CatalogData_Journal", function()
            ns.FlushZoneMembership()
        end)
    end,
})
