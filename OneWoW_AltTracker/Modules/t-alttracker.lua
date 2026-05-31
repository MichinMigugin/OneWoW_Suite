local addonName, ns = ...
local OneWoWAltTracker = OneWoW_AltTracker
local L = ns.L

ns.AlttrackerModule = ns.AlttrackerModule or {}
local AlttrackerModule = ns.AlttrackerModule

function AlttrackerModule:Initialize()
    self.initialized = true

    if ns.AltTrackerCache then
        ns.AltTrackerCache:Initialize()
    end



    if ns.ProfessionsModule then
        ns.ProfessionsModule:Initialize()
    end
end
