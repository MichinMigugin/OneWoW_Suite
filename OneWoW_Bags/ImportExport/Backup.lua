local _, ns = ...

ns.ImportExport = ns.ImportExport or {}
ns.ImportExport.Backup = ns.ImportExport.Backup or {}
local Backup = ns.ImportExport.Backup

local pairs, time, type = pairs, time, type
local deepCopy = ns.ImportExport.Util.DeepCopy

local BACKUP_FIELDS = {
    "customCategoriesV2",
    "categorySections",
    "sectionOrder",
    "categoryModifications",
    "disabledCategories",
    "categoryOrder",
    "displayOrder",
    "enableJunkCategory",
    "enableUpgradeCategory",
}

--- Save a deep-copy snapshot of import-managed category tables.
---@param tag string|nil
---@param db table
---@return boolean ok
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
    local SE = OneWoW.SearchExpand
    snapshot.tables.savedSearches = deepCopy(SE:GetAllSaved())
    g.importBackup = snapshot
    return true
end

--- Check whether an import backup exists.
---@param db table
---@return boolean hasBackup
function Backup:HasBackup(db)
    if not db or not db.global then return false end
    local b = db.global.importBackup
    return b ~= nil and b.tables ~= nil
end

--- Return the current import backup payload.
---@param db table
---@return table|nil backup
function Backup:GetBackupInfo(db)
    if not self:HasBackup(db) then return nil end
    return db.global.importBackup
end

--- Restore the last import backup and refresh category UI when possible.
---@param db table
---@param controller table|nil
---@return boolean ok
function Backup:Restore(db, controller)
    if not self:HasBackup(db) then return false end
    local g = db.global
    local snap = g.importBackup
    for _, key in pairs(BACKUP_FIELDS) do
        local val = snap.tables[key]
        if type(val) == "table" then
            g[key] = deepCopy(val)
        elseif val ~= nil then
            g[key] = val
        else
            g[key] = {}
        end
    end

    -- Entries the import minted in the core catalog. Restoring Bags' own tables
    -- cannot reach them, so the applier records them here and they are removed
    -- explicitly; otherwise an undo leaves them behind as orphans.
    OneWoW.SearchCatalog:RollbackImportedEntries(snap.createdCatalogEntries)

    local SE = OneWoW.SearchExpand
    local restored = snap.tables.savedSearches
    local current = SE:GetAllSaved()
    for name in pairs(current) do
        SE:DeleteSaved(name)
    end
    if type(restored) == "table" then
        for name, query in pairs(restored) do
            if type(name) == "string" and type(query) == "string" then
                SE:SetSaved(name, query)
            end
        end
    end

    local SD = ns.SectionDefaults
    if SD and SD.SyncOnewowSectionCategories then
        SD:SyncOnewowSectionCategories(g)
    end

    if controller and controller.RefreshUI then
        controller:RefreshUI()
    end
    return true
end

--- Remove the stored import backup.
---@param db table
function Backup:Clear(db)
    if not db or not db.global then return end
    db.global.importBackup = nil
end
