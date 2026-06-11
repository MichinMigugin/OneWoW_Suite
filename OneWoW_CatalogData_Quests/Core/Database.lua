local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB
local ipairs, pairs, wipe = ipairs, pairs, wipe

ns.DatabaseDefaults = {
    global = {
        settings = {
            enabled = true,
        },
        quests     = {},
        completion = {},
    },
}

local LEGACY_GLOBAL_KEYS = {
    "settings",
    "version",
    "quests",
    "completion",
}

local function BridgeLegacyDatabase()
    local sv = OneWoW_CatalogData_Quests_DB
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
    if not OneWoW_CatalogData_Quests_DB then OneWoW_CatalogData_Quests_DB = {} end
    BridgeLegacyDatabase()

    ns.db = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_CatalogData_Quests_DB",
        defaults = ns.DatabaseDefaults,
    })

    DB:RunMigrations(ns.db, {
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
        { version = 2, name = "consolidate_character_keys", run = function(d)
            local migrated = DB:ConsolidateCharacterKeys(d.global.completion)
            if migrated > 0 then
                C_Timer.After(5, function()
                    print("|cFFFFD100OneWoW Catalog (Quests):|r canonicalized "
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
