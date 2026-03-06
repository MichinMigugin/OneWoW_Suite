-- OneWoW Addon File
-- OneWoW_CatalogData_Journal/Core/Database.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

if not OneWoW_CatalogData_Journal_DB then
    OneWoW_CatalogData_Journal_DB = {}
end

ns.DatabaseDefaults = {
    settings = {
        enabled = true,
    },
    version = 1,
    itemCache = {},
}

function ns:InitializeDatabase()
    local db = OneWoW_CatalogData_Journal_DB
    if not db.settings then db.settings = { enabled = true } end
    if not db.version then db.version = 1 end
    if not db.itemCache then db.itemCache = {} end
end

function ns:GetSettings()
    return OneWoW_CatalogData_Journal_DB.settings or {}
end

function ns:GetDB()
    return OneWoW_CatalogData_Journal_DB
end
