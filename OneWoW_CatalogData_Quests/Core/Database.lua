-- OneWoW Addon File
-- OneWoW_CatalogData_Quests/Core/Database.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

if not OneWoW_CatalogData_Quests_DB then
    OneWoW_CatalogData_Quests_DB = {}
end

ns.DatabaseDefaults = {
    settings = {
        enabled = true,
    },
    version = 1,
    quests     = {},
    completion = {},
}

function ns:InitializeDatabase()
    if not OneWoW_CatalogData_Quests_DB.settings then
        OneWoW_CatalogData_Quests_DB.settings = CopyTable(ns.DatabaseDefaults.settings)
    end
    if not OneWoW_CatalogData_Quests_DB.version then
        OneWoW_CatalogData_Quests_DB.version = ns.DatabaseDefaults.version
    end
    if not OneWoW_CatalogData_Quests_DB.quests then
        OneWoW_CatalogData_Quests_DB.quests = {}
    end
    if not OneWoW_CatalogData_Quests_DB.completion then
        OneWoW_CatalogData_Quests_DB.completion = {}
    end
end

function ns:GetSettings()
    return OneWoW_CatalogData_Quests_DB.settings or {}
end
