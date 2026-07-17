local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

local ipairs, wipe = ipairs, wipe

ns.DatabaseDefaults = {
    global = {
        language          = nil,
        theme             = "green",
        lastTab           = "journal",
        mainFrameSize     = nil,
        mainFramePosition = nil,
        minimap           = { hide = false, minimapPos = 220, theme = "horde" },
        favorites         = {
            journal    = {},
            quests     = {},
            vendors    = {},
            itemSearch = {},
        },
        itemCache         = {},
    },
}

local LEGACY_GLOBAL_KEYS = {
    "favorites",
    "lastTab",
    "mainFrameSize",
    "mainFramePosition",
    "language",
    "theme",
    "minimap",
}

local function BridgeLegacyDatabase()
    local sv = OneWoW_Catalog_DB
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
    if not OneWoW_Catalog_DB then OneWoW_Catalog_DB = {} end
    BridgeLegacyDatabase()

    local db = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_Catalog_DB",
        defaults = ns.DatabaseDefaults,
    })

    ns.db = db
end
