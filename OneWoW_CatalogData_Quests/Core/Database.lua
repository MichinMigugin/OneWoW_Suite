local ADDON_NAME, ns = ...

ns.DatabaseDefaults = {
    settings = {
        enabled = true,
    },
    version = 1,
    quests     = {},
    completion = {},
}

function ns:GetSettings()
    return OneWoW_CatalogData_Quests_DB and OneWoW_CatalogData_Quests_DB.settings or {}
end
