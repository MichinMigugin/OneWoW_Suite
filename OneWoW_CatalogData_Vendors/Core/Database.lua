local addonName, ns = ...

if not OneWoW_CatalogData_Vendors_DB then
    OneWoW_CatalogData_Vendors_DB = {}
end

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

function ns:InitializeDatabase()
    local db = OneWoW_CatalogData_Vendors_DB
    if not db.settings then db.settings = { enabled = true, autoScan = true } end
    if not db.version then db.version = 2 end
    if not db.vendors then db.vendors = {} end
    if not db.nameCache then db.nameCache = {} end
    if not db.itemCache then db.itemCache = {} end
end

function ns:GetSettings()
    return OneWoW_CatalogData_Vendors_DB.settings or {}
end

function ns:GetDB()
    return OneWoW_CatalogData_Vendors_DB
end
