local ADDON_NAME, ns = ...

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
        seasonChecklist = {},

        -- Last-used Items-tab duplicate-finder spec (seeded from the Storage
        -- default on first use; canonical default values live in that unit).
        dupeSpec = {},

        overrides = {
            progress = {},
        },
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

-- Effective override list: user's SavedVariables customization when non-empty,
-- otherwise the static baseline (ns.OverrideDefaults). Callers run after hub init.
function ns:GetProgressList(key)
    local userList = ns.db.global.overrides.progress[key]
    if type(userList) == "table" and #userList > 0 then
        return userList
    end
    return ns.OverrideDefaults.progress[key]
end

-- Copy-on-write: ensure SavedVariables holds an editable copy of the list
-- (seeded from the static baseline on first edit), then return it for mutation.
function ns:EnsureProgressList(key)
    local progress = ns.db.global.overrides.progress
    if type(progress[key]) ~= "table" then
        progress[key] = CopyOverrideList(ns.OverrideDefaults.progress[key])
    end
    return progress[key]
end

function ns:InitializeDatabase()
    ns.db = DB:Init({
        savedVar = "OneWoW_AltTracker_DB",
        addonName = ADDON_NAME,
        defaults = ns.DatabaseDefaults,
    })

    -- AceDB/NewCompat-era cleanup: the hub never stored per-character or profile
    -- data. DB:Init single mode keeps char data under root.chars, so drop the
    -- legacy root tables to stop them syncing as dead weight.
    ns.db.root.char = nil
    ns.db.root.profileKeys = nil

    -- One-time reset of seeded progress overrides. SavedVariables now holds only
    -- user customizations; absence falls back to the static baseline, so wipe the
    -- old fully-seeded table once and let everyone adopt ns.OverrideDefaults.
    local global = ns.db.global
    if not global.overridesReset then
        global.overrides = { progress = {} }
        global.overridesReset = true
    end

    -- Drop stale weekly-activity overrides that still pointed at season metas
    -- 95842/95843 (sticky completion flag). Baseline now uses zone weeklies.
    if not global.weeklyActivityQuestsV2 then
        if global.overrides and global.overrides.progress then
            global.overrides.progress.weeklyActivityQuests = nil
        end
        global.weeklyActivityQuestsV2 = true
    end
end
