local _, ns = ...

ns.ProfessionTrainers = {}
local Module = ns.ProfessionTrainers

function Module:CollectData(_, _)
    return false
end

function Module:GetRecentTrainers(_, _, _)
    return {}
end

function Module:GetTrainersByZone(_, _, _)
    return {}
end
