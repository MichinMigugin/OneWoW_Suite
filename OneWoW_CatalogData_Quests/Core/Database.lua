-- OneWoW Addon File
-- OneWoW_CatalogData_Quests/Core/Database.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.DatabaseDefaults = {
    settings = {
        enabled = true,
    },
    version = 1,
    quests     = {},
    completion = {},
}

function ns:GetSettings()
    return _G.OneWoW_CatalogData_Quests_DB and _G.OneWoW_CatalogData_Quests_DB.settings or {}
end
