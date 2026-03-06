-- OneWoW Addon File
-- OneWoW_CatalogData_Tradeskills/Core/Database.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

if not OneWoW_CatalogData_Tradeskills_DB then
    OneWoW_CatalogData_Tradeskills_DB = {}
end

ns.DatabaseDefaults = {
    settings = {
        enabled = true,
        autoScan = true,
    },
    version = 1,
    itemCache = {},
    scanCache = {},
}

function ns:InitializeDatabase()
    local db = OneWoW_CatalogData_Tradeskills_DB
    if not db.settings then db.settings = { enabled = true, autoScan = true } end
    if not db.version then db.version = 1 end
    if not db.itemCache then db.itemCache = {} end
    if not db.scanCache then db.scanCache = {} end
end

function ns:GetSettings()
    return OneWoW_CatalogData_Tradeskills_DB.settings or {}
end

function ns:GetDB()
    return OneWoW_CatalogData_Tradeskills_DB
end
