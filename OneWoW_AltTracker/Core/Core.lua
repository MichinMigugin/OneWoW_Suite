local addonName, ns = ...
local OneWoWAltTracker = OneWoW_AltTracker

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.Core = {}
local Core = ns.Core

function Core:Initialize()
    self.initialized = true

    local ms = _G.OneWoW_AltTracker and _G.OneWoW_AltTracker.db and _G.OneWoW_AltTracker.db.global and _G.OneWoW_AltTracker.db.global.migrationStatus
    if ms and not ms.cleanupPerformed then
        self:CleanupOldMigrationData()
    end

    if ns.MigrationFix then
        ns.MigrationFix:RemoveInvalidCharacterKeys()
        ns.MigrationFix:FixImportedData()
        ns.MigrationFix:CleanupWrongPlacedData()
    end

    if ns.AlttrackerModule and ns.AlttrackerModule.Initialize then
        ns.AlttrackerModule:Initialize()
    end
end

function Core:CleanupOldMigrationData()
    local targetDB = _G.OneWoW_AltTracker.db.global
    if not targetDB then return end

    targetDB.altTracker = nil
    targetDB.warbandBankData = nil
    targetDB.guildBanks = nil
    targetDB.actionBars = nil

    if targetDB.migrationStatus then
        targetDB.migrationStatus.cleanupPerformed = true
    end
end
