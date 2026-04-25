local ADDON_NAME, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB
local ipairs, pairs, wipe = ipairs, pairs, wipe

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
    local sv = _G["OneWoW_Catalog_DB"]
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
    if not _G["OneWoW_Catalog_DB"] then _G["OneWoW_Catalog_DB"] = {} end
    BridgeLegacyDatabase()

    local db = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_Catalog_DB",
        defaults = ns.DatabaseDefaults,
    })

    DB:RunMigrations(db, {
        { version = 1, name = "cleanup_legacy_root_keys", run = function(d)
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
    })

    ns.addon.db = db
end
