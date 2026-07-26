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
---
--- Bags' own tables only. Named expressions live in the core catalog and are not
--- Bags' to snapshot: copying that namespace here would capture entries no Bags
--- category references — and entries other addons own — which restore would then
--- treat as authoritative. The catalog half of an undo is a recorded delta
--- instead; see `Restore`.
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

    -- The catalog half of the undo, and the whole of it. The applier records the
    -- entries the import minted, so removing exactly those restores the previous
    -- state: an import only ever creates (identical bodies merge to a no-op,
    -- genuine conflicts are skipped), so the created list is a complete delta.
    --
    -- Deliberately *not* a wholesale restore of the saved namespace. That
    -- namespace is core-owned and suite-wide: replacing it from a Bags snapshot
    -- would re-mint every id and drop every former-name redirect — the redirects
    -- being the one thing that keeps expression text working across a rename —
    -- and would delete entries created after the import, including other addons'.
    OneWoW.SearchCatalog:RollbackImportedEntries(snap.createdCatalogEntries)

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
