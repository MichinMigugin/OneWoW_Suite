local _, ns = ...

ns.Core = {}
local Core = ns.Core

function Core:Initialize()
    self.initialized = true

    if ns.MigrationFix then
        ns.MigrationFix:ConsolidateCrossReferenceCharKeys()
    end

    if ns.AlttrackerModule and ns.AlttrackerModule.Initialize then
        ns.AlttrackerModule:Initialize()
    end
end
