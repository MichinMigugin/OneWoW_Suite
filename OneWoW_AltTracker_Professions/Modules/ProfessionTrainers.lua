local addonName, ns = ...

ns.ProfessionTrainers = {}
local Module = ns.ProfessionTrainers

function Module:CollectData(charKey, charData)
    return false
end

function Module:GetRecentTrainers(charKey, charData, count)
    return {}
end

function Module:GetTrainersByZone(charKey, charData, zoneName)
    return {}
end
