-- OneWoW Addon File
-- OneWoW_CatalogData_Journal/Core/Database.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.DatabaseDefaults = {
    settings = {
        enabled = true,
    },
    version = 1,
    itemCache = {},
}

function ns:GetSettings()
    return _G.OneWoW_CatalogData_Journal_DB and _G.OneWoW_CatalogData_Journal_DB.settings or {}
end

function ns:GetDB()
    return _G.OneWoW_CatalogData_Journal_DB
end
