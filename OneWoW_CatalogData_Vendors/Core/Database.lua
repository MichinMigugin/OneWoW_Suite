-- OneWoW_CatalogData_Vendors/Core/Database.lua
local addonName, ns = ...

ns.DatabaseDefaults = {
    settings = {
        enabled = true,
        autoScan = true,
    },
    version = 2,
    vendors = {},
    nameCache = {},
    itemCache = {},
}

function ns:GetSettings()
    return _G.OneWoW_CatalogData_Vendors_DB and _G.OneWoW_CatalogData_Vendors_DB.settings or {}
end

function ns:GetDB()
    return _G.OneWoW_CatalogData_Vendors_DB
end
