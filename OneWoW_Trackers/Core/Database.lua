local addonName, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

local pairs, ipairs, type, next = pairs, ipairs, type, next

local defaults = {
    global = {
        trackerLists           = {},
        trackerBundledVersions = {},
        trackerBundledDeleted  = {},
        trackerGlobalProgress  = {},
        -- Per-character roster completion for steps flagged `rosterMode`. Keyed
        -- by listID then stepKey; the completers map is account-wide (every
        -- character that satisfies the step's trigger is recorded here), so it
        -- lives in `global` regardless of the host list's own scope.
        trackerRosters         = {},
        mainFrameSize          = nil,
        mainFramePosition      = nil,
        -- Account-wide lists share progress across characters, so their reset
        -- boundary is tracked per account here. Char-scoped lists use the
        -- per-character markers below.
        trackerLastWeeklyReset = 0,
        trackerLastDailyReset  = 0,
        -- "auto" follows the realm's region via C_DateAndTime; a region key
        -- ("us"/"eu"/"asia") forces the weekly reset weekday instead.
        weeklyResetRegion      = "auto",
        -- Percent scale for all pinned overlay windows (50-200).
        pinnedScale            = 100,
    },
    char = {
        trackerProgress        = {},
        trackerActiveList      = nil,
        trackerLastWeeklyReset = 0,
        trackerLastDailyReset  = 0,
    },
}

function ns:InitializeDatabase()
    -- Pre-Init bridge: lift legacy root-level keys into root.global. Older Trackers
    -- releases stored everything at the SV root (no .global subtable).
    local sv = OneWoW_Trackers_DB
    if type(sv) == "table" then
        if type(sv.global) ~= "table" then sv.global = {} end
        local g = sv.global

        for _, key in ipairs({ "trackerLists", "trackerGlobalProgress",
                               "trackerBundledVersions", "trackerBundledDeleted" }) do
            if type(sv[key]) == "table" then
                if type(g[key]) ~= "table" then g[key] = {} end
                for id, value in pairs(sv[key]) do
                    if g[key][id] == nil then
                        g[key][id] = value
                    end
                end
                sv[key] = nil
            end
        end

        if sv.minimap ~= nil then
            if g.minimap == nil then g.minimap = sv.minimap end
            sv.minimap = nil
        end

        sv.sortCompletedTasks      = nil
        sv._migratedFromNotes      = nil
        sv.guidesRoutinesCleanedUp = nil
    end

    local db = DB:Init({
        addonName = addonName,
        savedVar  = "OneWoW_Trackers_DB",
        defaults  = defaults,
    })
    ns.db = db

    local legacyChar = OneWoW_Trackers_CharDB
    if type(legacyChar) == "table" and not db.char._charDBDrained then
        if type(legacyChar.trackerProgress) == "table" and next(legacyChar.trackerProgress) ~= nil
            and next(db.char.trackerProgress) == nil then
            db.char.trackerProgress = CopyTable(legacyChar.trackerProgress)
        end
        if legacyChar.trackerActiveList ~= nil and db.char.trackerActiveList == nil then
            db.char.trackerActiveList = legacyChar.trackerActiveList
        end
        if type(legacyChar.trackerLastWeeklyReset) == "number" and legacyChar.trackerLastWeeklyReset > 0
            and db.char.trackerLastWeeklyReset == 0 then
            db.char.trackerLastWeeklyReset = legacyChar.trackerLastWeeklyReset
        end
        if type(legacyChar.trackerLastDailyReset) == "number" and legacyChar.trackerLastDailyReset > 0
            and db.char.trackerLastDailyReset == 0 then
            db.char.trackerLastDailyReset = legacyChar.trackerLastDailyReset
        end
        db.char._charDBDrained = true
        wipe(legacyChar)
    end

    ns.TrackerData:RemapStoredCategories()
end
