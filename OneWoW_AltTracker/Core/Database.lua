local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

ns.DatabaseDefaults = {
    global = {
        language = GetLocale(),
        theme = "green",

        mainFrameSize = {
            width = 1400,
            height = 900
        },

        mainFramePosition = nil,

        altTrackerSettings = {
            enablePlaytimeTracking = true,
            enableDataCollection = true,
        },

        minimap = {
            hide = false,
            minimapPos = 220,
            theme = "horde",
        },

        favorites = {},
        favoriteBarSets = {},
        favoriteItems   = {},
        seasonChecklist = {}
    },
}

-- Shallow-copy a baseline list (handles arrays of scalars and arrays of flat
-- tables) so edits to the SavedVariables copy never mutate ns.OverrideDefaults.
local function CopyOverrideList(src)
    if type(src) ~= "table" then return {} end
    local out = {}
    for i = 1, #src do
        local v = src[i]
        if type(v) == "table" then
            local t = {}
            for k, vv in pairs(v) do t[k] = vv end
            out[i] = t
        else
            out[i] = v
        end
    end
    return out
end

-- Effective override list: the user's SavedVariables customization when present
-- and non-empty, otherwise the static baseline (ns.OverrideDefaults). For
-- read-only consumers (including cross-addon AltTracker data units), so this
-- tolerates the hub db not being initialized yet by falling back to the baseline.
function ns:GetProgressList(key)
    local addon = ns.OneWoWAltTracker
    local global = addon and addon.db and addon.db.global
    local progress = global and global.overrides and global.overrides.progress
    local userList = progress and progress[key]
    if type(userList) == "table" and #userList > 0 then
        return userList
    end
    return ns.OverrideDefaults.progress[key]
end

-- Copy-on-write: ensure SavedVariables holds an editable copy of the list
-- (seeded from the static baseline on first edit), then return it for mutation.
function ns:EnsureProgressList(key)
    local global = ns.OneWoWAltTracker.db.global
    if not global.overrides then global.overrides = {} end
    if not global.overrides.progress then global.overrides.progress = {} end
    local progress = global.overrides.progress
    if type(progress[key]) ~= "table" then
        progress[key] = CopyOverrideList(ns.OverrideDefaults.progress[key])
    end
    return progress[key]
end

function ns:InitializeDatabase()
    local addon = ns.OneWoWAltTracker

    addon.db = DB:Init({
        savedVar = "OneWoW_AltTracker_DB",
        addonName = "OneWoW_AltTracker",
        defaults = ns.DatabaseDefaults,
    })

    -- AceDB/NewCompat-era cleanup: the hub never stored per-character or profile
    -- data. DB:Init single mode keeps char data under root.chars, so drop the
    -- legacy root tables to stop them syncing as dead weight.
    addon.db.root.char = nil
    addon.db.root.profileKeys = nil

    -- One-time reset of seeded progress overrides. SavedVariables now holds only
    -- user customizations; absence falls back to the static baseline, so wipe the
    -- old fully-seeded table once and let everyone adopt ns.OverrideDefaults.
    local global = addon.db.global
    if not global.overridesReset then
        global.overrides = { progress = {} }
        global.overridesReset = true
    end
end
