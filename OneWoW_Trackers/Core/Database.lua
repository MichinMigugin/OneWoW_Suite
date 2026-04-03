local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.Database = {}
local Database = ns.Database

local GLOBAL_DEFAULTS = {
    trackerLists              = {},
    trackerBundledVersions    = {},
    trackerBundledDeleted     = {},
    trackerGlobalProgress     = {},
    sortCompletedTasks        = false,
    guidesRoutinesCleanedUp   = false,
    mainFrameSize             = nil,
    mainFramePosition         = nil,
    minimap                   = { hide = false, minimapPos = 220, theme = "neutral" },
    _migratedFromNotes        = false,
}

local CHAR_DEFAULTS = {
    trackerProgress           = {},
    trackerDashboard          = {},
    trackerActiveList         = nil,
    trackerLastWeeklyReset    = 0,
    trackerLastDailyReset     = 0,
    _migratedFromNotes        = false,
}

function Database:Initialize()
    if not _G.OneWoW_Trackers_DB then
        _G.OneWoW_Trackers_DB = {}
    end
    if not _G.OneWoW_Trackers_CharDB then
        _G.OneWoW_Trackers_CharDB = {}
    end

    local gdb = _G.OneWoW_Trackers_DB
    local cdb = _G.OneWoW_Trackers_CharDB

    for k, v in pairs(GLOBAL_DEFAULTS) do
        if gdb[k] == nil then
            if type(v) == "table" then
                gdb[k] = CopyTable(v)
            else
                gdb[k] = v
            end
        end
    end

    for k, v in pairs(CHAR_DEFAULTS) do
        if cdb[k] == nil then
            if type(v) == "table" then
                cdb[k] = CopyTable(v)
            else
                cdb[k] = v
            end
        end
    end

    return { global = gdb, char = cdb }
end

function Database:MigrateFromNotes(db)
    local notesGlobalDB = _G.OneWoW_Notes_DB
    if not notesGlobalDB then return end

    local migratedCount = 0

    if not db.global._migratedFromNotes then
        local ng = notesGlobalDB.global or notesGlobalDB
        if ng then
            if ng.trackerLists and next(ng.trackerLists) then
                db.global.trackerLists = CopyTable(ng.trackerLists)
                migratedCount = migratedCount + 1
            end
            if ng.trackerGlobalProgress and next(ng.trackerGlobalProgress) then
                db.global.trackerGlobalProgress = CopyTable(ng.trackerGlobalProgress)
                migratedCount = migratedCount + 1
            end
            if ng.trackerBundledVersions and next(ng.trackerBundledVersions) then
                db.global.trackerBundledVersions = CopyTable(ng.trackerBundledVersions)
                migratedCount = migratedCount + 1
            end
            if ng.trackerBundledDeleted and next(ng.trackerBundledDeleted) then
                db.global.trackerBundledDeleted = CopyTable(ng.trackerBundledDeleted)
                migratedCount = migratedCount + 1
            end
            if ng.sortCompletedTasks ~= nil then
                db.global.sortCompletedTasks = ng.sortCompletedTasks
            end
            if ng.guidesRoutinesCleanedUp ~= nil then
                db.global.guidesRoutinesCleanedUp = ng.guidesRoutinesCleanedUp
            end
        end
        db.global._migratedFromNotes = true
    end

    if not db.char._migratedFromNotes then
        local nc = notesGlobalDB.char
        if not nc and _G.OneWoW_Notes_CharDB then
            nc = _G.OneWoW_Notes_CharDB
        end
        if nc then
            if nc.trackerProgress and next(nc.trackerProgress) then
                db.char.trackerProgress = CopyTable(nc.trackerProgress)
                migratedCount = migratedCount + 1
            end
            if nc.trackerDashboard and next(nc.trackerDashboard) then
                db.char.trackerDashboard = CopyTable(nc.trackerDashboard)
            end
            if nc.trackerActiveList ~= nil then
                db.char.trackerActiveList = nc.trackerActiveList
            end
            if nc.trackerLastWeeklyReset and nc.trackerLastWeeklyReset > 0 then
                db.char.trackerLastWeeklyReset = nc.trackerLastWeeklyReset
            end
            if nc.trackerLastDailyReset and nc.trackerLastDailyReset > 0 then
                db.char.trackerLastDailyReset = nc.trackerLastDailyReset
            end
        end
        db.char._migratedFromNotes = true
    end

    if migratedCount > 0 then
        print("|cFFFFD100OneWoW Trackers:|r Migrated tracker data from Notes (" .. migratedCount .. " data sets).")
    end
end
