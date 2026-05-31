local ADDON_NAME, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB
local ipairs, pairs, wipe = ipairs, pairs, wipe

ns.DatabaseDefaults = {
    global = {
        settings = {
            enabled = true,
            autoScan = true,
        },
        itemCache = {},
        scanCache = {},
    },
}

local LEGACY_GLOBAL_KEYS = {
    "settings",
    "version",
    "itemCache",
    "scanCache",
}

local function BridgeLegacyDatabase()
    local sv = OneWoW_CatalogData_Tradeskills_DB
    if not sv then return end

    if not sv.global then
        local global = {}
        for _, key in ipairs(LEGACY_GLOBAL_KEYS) do
            if sv[key] ~= nil then
                global[key] = sv[key]
            end
        end
        wipe(sv)
        sv.global = global
        return
    end

    for _, key in ipairs(LEGACY_GLOBAL_KEYS) do
        if sv.global[key] == nil and sv[key] ~= nil then
            sv.global[key] = sv[key]
        end
    end
end

function ns:MigrateScanCacheKeys(global)
    local scanCache = global.scanCache
    if not scanCache then return end

    local newCache = {}
    for oldKey, data in pairs(scanCache) do
        local realm, name = oldKey:match("^(.+)-(.+)$")
        if realm and name then
            local newKey = name .. "-" .. realm
            newCache[newKey] = data
        else
            newCache[oldKey] = data
        end
    end
    global.scanCache = newCache
end

function ns:InitializeDatabase()
    if not OneWoW_CatalogData_Tradeskills_DB then OneWoW_CatalogData_Tradeskills_DB = {} end
    BridgeLegacyDatabase()

    ns.db = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_CatalogData_Tradeskills_DB",
        defaults = ns.DatabaseDefaults,
    })

    -- Legacy flat SV used db.version >= 2 after scan-cache key fix; bridge so it does not re-run.
    if (ns.db.global.version or 0) >= 2 and (ns.db.global._migrationVersion or 0) < 1 then
        ns.db.global._migrationVersion = 1
    end

    DB:RunMigrations(ns.db, {
        { version = 1, name = "scan_cache_key_canonicalize", run = function(d)
            ns:MigrateScanCacheKeys(d.global)
        end },
        { version = 2, name = "cleanup_legacy_root_keys", run = function(d)
            local keepRootKeys = {
                global = true,
                chars = true,
                realms = true,
                factions = true,
                classes = true,
                specs = true,
                presets = true,
                _activePreset = true,
            }
            local root = d.root
            if not root then return end
            for key in pairs(root) do
                if not keepRootKeys[key] then
                    root[key] = nil
                end
            end
        end },
        { version = 3, name = "consolidate_character_keys", run = function(d)
            local migrated = DB:ConsolidateCharacterKeys(d.global.scanCache)
            if migrated > 0 then
                C_Timer.After(5, function()
                    print("|cFFFFD100OneWoW Catalog (Tradeskills):|r canonicalized "
                        .. migrated .. " legacy character key(s).")
                end)
            end
        end },
    })

    function ns.GetDB()
        return ns.db.global
    end
end

function ns:GetSettings()
    return ns.db.global.settings
end

function ns:GetDB()
    return ns.db.global
end
