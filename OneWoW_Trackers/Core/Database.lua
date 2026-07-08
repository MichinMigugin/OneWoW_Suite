local addonName, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

local CHAT_PREFIX = "|cFFFFD100OneWoW Trackers:|r"

local C_AddOns = C_AddOns
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
    },
    char = {
        trackerProgress        = {},
        trackerActiveList      = nil,
        trackerLastWeeklyReset = 0,
        trackerLastDailyReset  = 0,
    },
}

-- One-time drain of per-character tracker fields from Notes SV into Trackers SV.
-- Requires Notes to be loaded first (SavedVariables are not readable until then).
local function RunNotesAcctDrain(db)
    local notesSV = OneWoW_Notes_DB
    if type(notesSV) ~= "table" or type(notesSV.chars) ~= "table" then return end

    local trackerSlots = db.root.chars
    local drainedChars = 0
    for rawCharKey, nc in pairs(notesSV.chars) do
        if type(nc) == "table" then
            local charKey = OneWoW_GUI:CanonicalizeCharacterKey(rawCharKey) or rawCharKey
            local hasTrackerData =
                nc.trackerProgress     or nc.trackerActiveList
                or nc.trackerLastWeeklyReset or nc.trackerLastDailyReset
                or nc.trackerDashboard or nc.guideProgress
                or nc.routineProgress  or nc.routineLastWeek
                or nc._migratedFromNotes
            if hasTrackerData then
                if type(trackerSlots[charKey]) ~= "table" then
                    trackerSlots[charKey] = {}
                end
                local target = trackerSlots[charKey]

                if type(nc.trackerProgress) == "table" and next(nc.trackerProgress) ~= nil
                    and (type(target.trackerProgress) ~= "table" or next(target.trackerProgress) == nil) then
                    target.trackerProgress = CopyTable(nc.trackerProgress)
                end
                if nc.trackerActiveList ~= nil and target.trackerActiveList == nil then
                    target.trackerActiveList = nc.trackerActiveList
                end
                if type(nc.trackerLastWeeklyReset) == "number" and nc.trackerLastWeeklyReset > 0
                    and (target.trackerLastWeeklyReset == nil or target.trackerLastWeeklyReset == 0) then
                    target.trackerLastWeeklyReset = nc.trackerLastWeeklyReset
                end
                if type(nc.trackerLastDailyReset) == "number" and nc.trackerLastDailyReset > 0
                    and (target.trackerLastDailyReset == nil or target.trackerLastDailyReset == 0) then
                    target.trackerLastDailyReset = nc.trackerLastDailyReset
                end
                if type(nc.guideProgress) == "table" and next(nc.guideProgress) ~= nil
                    and (type(target.guideProgress) ~= "table" or next(target.guideProgress) == nil) then
                    target.guideProgress = CopyTable(nc.guideProgress)
                end
                if type(nc.routineProgress) == "table" and next(nc.routineProgress) ~= nil
                    and (type(target.routineProgress) ~= "table" or next(target.routineProgress) == nil) then
                    target.routineProgress = CopyTable(nc.routineProgress)
                end
                if type(nc.routineLastWeek) == "number" and nc.routineLastWeek > 0
                    and target.routineLastWeek == nil then
                    target.routineLastWeek = nc.routineLastWeek
                end

                nc.trackerProgress        = nil
                nc.trackerActiveList      = nil
                nc.trackerLastWeeklyReset = nil
                nc.trackerLastDailyReset  = nil
                nc.trackerDashboard       = nil
                nc.guideProgress          = nil
                nc.routineProgress        = nil
                nc.routineLastWeek        = nil
                nc._migratedFromNotes     = nil

                drainedChars = drainedChars + 1
            end

            if next(nc) == nil then
                notesSV.chars[rawCharKey] = nil
            end
        end
    end
    for _, slot in pairs(trackerSlots) do
        if type(slot) == "table" then
            slot._notesCharDrained = nil
        end
    end
    if drainedChars > 0 then
        print(CHAT_PREFIX .. " Migrated tracker data for " .. drainedChars .. " character(s) out of Notes_DB.")
    end
end

-- Gated on db.global._notesAcctDrained. When Notes is soft-opted-out, defer until
-- the user wants Notes again (SV requires the addon to be loaded before drain).
local function TryNotesAcctDrain(db)
    if db.global._notesAcctDrained then return end
    if not OneWoW:IsFeatureWanted("OneWoW_Notes") then
        return
    end
    local function finishDrain()
        RunNotesAcctDrain(db)
        db.global._notesAcctDrained = true
    end
    if C_AddOns.IsAddOnLoaded("OneWoW_Notes") then
        finishDrain()
        return
    end
    OneWoW:WithAddon("OneWoW_Notes", finishDrain)
end

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

    TryNotesAcctDrain(db)
end
