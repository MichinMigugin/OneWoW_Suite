-- OneWoW Addon File
-- OneWoW_CatalogData_Tradeskills/Core/Database.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.DatabaseDefaults = {
    settings = {
        enabled = true,
        autoScan = true,
    },
    version = 1,
    itemCache = {},
    scanCache = {},
}

function ns:MigrateScanCacheKeys()
    local db = _G.OneWoW_CatalogData_Tradeskills_DB
    if not db or not db.scanCache then return end

    local newCache = {}
    for oldKey, data in pairs(db.scanCache) do
        local realm, name = oldKey:match("^(.+)-(.+)$")
        if realm and name then
            local newKey = name .. "-" .. realm
            newCache[newKey] = data
        else
            newCache[oldKey] = data
        end
    end
    db.scanCache = newCache
end

function ns:GetSettings()
    return _G.OneWoW_CatalogData_Tradeskills_DB and _G.OneWoW_CatalogData_Tradeskills_DB.settings or {}
end

function ns:GetDB()
    return _G.OneWoW_CatalogData_Tradeskills_DB
end
