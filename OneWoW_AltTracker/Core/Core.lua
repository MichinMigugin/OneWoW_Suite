local _, ns = ...

ns.Core = {}
local Core = ns.Core

function Core:Initialize()
    self.initialized = true

    local ms = OneWoW_AltTracker and OneWoW_AltTracker.db and OneWoW_AltTracker.db.global and OneWoW_AltTracker.db.global.migrationStatus

    if ms and not ms.cleanupPerformed then
        self:CleanupOldMigrationData()
    end

    if ns.MigrationFix then
        ns.MigrationFix:RemoveInvalidCharacterKeys()
        ns.MigrationFix:FixImportedData()
        ns.MigrationFix:CleanupWrongPlacedData()
        ns.MigrationFix:ConsolidateCrossReferenceCharKeys()
    end

    if ns.AlttrackerModule and ns.AlttrackerModule.Initialize then
        ns.AlttrackerModule:Initialize()
    end
end

function Core:CleanupOldMigrationData()
    local targetDB = OneWoW_AltTracker.db.global
    if not targetDB then return end

    targetDB.altTracker = nil
    targetDB.warbandBankData = nil
    targetDB.guildBanks = nil
    targetDB.actionBars = nil

    if targetDB.migrationStatus then
        targetDB.migrationStatus.cleanupPerformed = true
    end
end
