local _, OneWoW_Bags = ...

OneWoW_Bags.ImportExport = OneWoW_Bags.ImportExport or {}
OneWoW_Bags.ImportExport.Backup = OneWoW_Bags.ImportExport.Backup or {}
local Backup = OneWoW_Bags.ImportExport.Backup

local pairs, type, time = pairs, type, time

local BACKUP_FIELDS = {
    "customCategoriesV2",
    "categorySections",
    "sectionOrder",
    "categoryModifications",
    "disabledCategories",
    "categoryOrder",
    "displayOrder",
}

local function deepCopy(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local out = {}
    seen[v] = out
    for k, vv in pairs(v) do
        out[k] = deepCopy(vv, seen)
    end
    return out
end

function Backup:Snapshot(tag, db)
    if not db or not db.global then return false end
    local g = db.global
    local snapshot = {
        tag     = tag or "pre_import",
        savedAt = time and time() or 0,
        tables  = {},
    }
    for _, key in pairs(BACKUP_FIELDS) do
        snapshot.tables[key] = deepCopy(g[key])
    end
    g.importBackup = snapshot
    return true
end

function Backup:HasBackup(db)
    if not db or not db.global then return false end
    local b = db.global.importBackup
    return b ~= nil and b.tables ~= nil
end

function Backup:GetBackupInfo(db)
    if not self:HasBackup(db) then return nil end
    return db.global.importBackup
end

function Backup:Restore(db, controller)
    if not self:HasBackup(db) then return false end
    local g = db.global
    local snap = g.importBackup
    for _, key in pairs(BACKUP_FIELDS) do
        g[key] = deepCopy(snap.tables[key]) or {}
    end

    local SD = OneWoW_Bags.SectionDefaults
    if SD and SD.SyncOnewowSectionCategories then
        SD:SyncOnewowSectionCategories(g)
    end

    if controller and controller.RefreshUI then
        controller:RefreshUI()
    end
    return true
end

function Backup:Clear(db)
    if not db or not db.global then return end
    db.global.importBackup = nil
end
