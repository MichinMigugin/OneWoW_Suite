local _, ns = ...

ns.ProfessionCooldowns = {}
local Module = ns.ProfessionCooldowns

function Module:CollectData(_, _, _)
    return false
end

function Module:GetActiveCooldowns(_, _, _)
    return {}
end

function Module:CleanExpiredCooldowns(_, _, _)
    return false
end
