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

-- v2: Bug fix for the historical Trackers→Notes split. Move tracker-owned global keys
-- from `OneWoW_Notes_DB.global` into our DB and DELETE them from Notes' SV so they
-- stop hanging around as orphans. (The previous implementation only copied.)
--
-- Ordered after v1 so that legacy users with `guidesRoutinesCleanedUp = true` (whose
-- _migrationVersion gets bridged to 1) still receive this orphan cleanup.
--
-- Idempotent in both directions:
--   * Fresh user with data still in Notes_DB → adopt + delete (full migration).
--   * Already-migrated user with orphans still in Notes_DB → delete only (cleanup).
--   * No data anywhere → no-op.
function ns:MigrateFromNotes(d)
    local notesSV = OneWoW_Notes_DB
    if type(notesSV) ~= "table" then return end

    local ng = notesSV.global
    if type(ng) ~= "table" then return end

    local adopted, cleaned = 0, 0
    local function takeOrCleanup(key)
        local notesData = ng[key]
        if type(notesData) == "table" and next(notesData) ~= nil then
            local ourData = d.global[key]
            if type(ourData) ~= "table" or next(ourData) == nil then
                d.global[key] = CopyTable(notesData)
                adopted = adopted + 1
            else
                cleaned = cleaned + 1
            end
        end
        ng[key] = nil
    end

    takeOrCleanup("trackerLists")
    takeOrCleanup("trackerGlobalProgress")
    takeOrCleanup("trackerBundledVersions")
    takeOrCleanup("trackerBundledDeleted")

    ng.guidesRoutinesCleanedUp = nil

    if adopted > 0 then
        print(CHAT_PREFIX .. " Migrated " .. adopted .. " global tracker data set(s) from Notes_DB.")
    elseif cleaned > 0 then
        print(CHAT_PREFIX .. " Cleaned up " .. cleaned .. " orphaned tracker key(s) from Notes_DB.")
    end
end

-- v1: Wraps the existing TrackerMigration:MigrateAll body, which restructures the
-- pre-Trackers guides/routines schema into the modern trackerLists schema. The
-- inner function is idempotent (gated by `db.global.guidesRoutinesCleanedUp`), but
-- as a versioned step we only invoke it once.
function ns:MigrateGuidesRoutines()
    if ns.TrackerMigration and ns.TrackerMigration.MigrateAll then
        ns.TrackerMigration:MigrateAll()
    end
end

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
    if not OneWoW or not OneWoW.IsFeatureWanted or not OneWoW:IsFeatureWanted("OneWoW_Notes") then
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
    -- releases stored everything at the SV root (no .global subtable); the switch
    -- to DB:Init single mode created root.global next to those legacy keys without
    -- moving them, leaving duplicate trackerLists / trackerBundledVersions / etc.
    -- that the rest of the addon never reads.
    --
    -- For data tables we gap-fill at the entry level so a custom legacy list isn't
    -- dropped just because global has *some* trackerLists. For obsolete scalars
    -- (sortCompletedTasks belongs to Notes; _migratedFromNotes / guidesRoutinesCleanedUp
    -- are flags _migrationVersion already supersedes) we just delete the root copy.
    -- Idempotent: once root is clean, subsequent loads skip every branch.
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
    self.db = db

    -- Inline bridge: drain legacy _G.OneWoW_Trackers_CharDB into db.char (single mode
    -- stores per-character data at db.chars[charKey]). Idempotent per character.
    -- Each known key is copied only if our slot is still at its default state, so
    -- already-migrated characters don't get clobbered on subsequent logins.
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

    -- Eager account-wide drain from Notes SV (see TryNotesAcctDrain).
    TryNotesAcctDrain(db)

    -- Bridge legacy boolean migration flags to integer _migrationVersion high-water mark.
    -- Only `guidesRoutinesCleanedUp` is honored as a "skip" signal: v2 (Notes orphan
    -- cleanup) is idempotent and safe to re-run even on already-migrated saves, but
    -- v1 (the legacy guide/routine→trackerList restructure) was a one-shot transform
    -- we must not invoke twice.
    if db.global._migrationVersion == nil and db.global.guidesRoutinesCleanedUp then
        db.global._migrationVersion = 1
    end

    DB:RunMigrations(db, {
        { version = 1, name = "migrate_guides_routines", run = function(d)
            self:MigrateGuidesRoutines(d)
        end },
        { version = 2, name = "migrate_from_notes", run = function(d)
            self:MigrateFromNotes(d)
        end },
        { version = 3, name = "cleanup_old_flags", run = function(d)
            d.global._migratedFromNotes      = nil
            d.global.guidesRoutinesCleanedUp = nil
        end },
        -- v4: Self-heal pass for lists that slipped through the pre-tightened
        -- ImportList validator. Foreign-schema strings (other addons, hand-rolled
        -- formats) used to be accepted on any value with a `title` field, which
        -- left lists in the DB with missing `listType` and `sections[*].steps`.
        -- A nil `listType` crashed `GetSortedLists`' sort comparator, which in
        -- turn wiped the entire list panel and broke detail rendering.
        --
        -- TD:NormalizeAllLists fixes those entries in place: missing/invalid
        -- `listType` becomes "todo", missing `sections`/`steps` become empty
        -- tables, and the lists become safe to sort and render — empty
        -- placeholders the user can delete from the UI.
        { version = 4, name = "normalize_imported_lists", run = function()
            if ns.TrackerData and ns.TrackerData.NormalizeAllLists then
                local normalized, broken, titles = ns.TrackerData:NormalizeAllLists()
                if normalized > 0 then
                    print(CHAT_PREFIX .. " Repaired " .. normalized
                        .. " malformed tracker list(s) from older imports.")
                end
                if broken > 0 and titles then
                    print(CHAT_PREFIX .. " The following list(s) came in with no usable steps and are now empty placeholders you can delete from the UI:")
                    for _, t in ipairs(titles) do
                        print("  - " .. t)
                    end
                end
            end
        end },
        -- v5: NormalizeAllLists now backfills the per-list pinned-window UI
        -- state introduced for the Notes-parity pinned tracker (opacity,
        -- collapsed, lockMove, lockResize, hideCompleted) and splits the old
        -- combined `pinnedLocked` into independent move/resize locks. v4 ran
        -- before those defaults existed in the normalizer, so re-run it once
        -- for already-migrated saves. Idempotent — subsequent loads no-op.
        { version = 5, name = "backfill_pinned_ui_state", run = function()
            if ns.TrackerData and ns.TrackerData.NormalizeAllLists then
                ns.TrackerData:NormalizeAllLists()
            end
        end },
    })
end
