local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

local ipairs, wipe = ipairs, wipe

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

function ns:InitializeDatabase()
    if not OneWoW_CatalogData_Tradeskills_DB then OneWoW_CatalogData_Tradeskills_DB = {} end
    BridgeLegacyDatabase()

    ns.db = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_CatalogData_Tradeskills_DB",
        defaults = ns.DatabaseDefaults,
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
