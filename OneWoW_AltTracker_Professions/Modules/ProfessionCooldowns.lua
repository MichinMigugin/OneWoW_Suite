local addonName, ns = ...

ns.ProfessionCooldowns = {}
local Module = ns.ProfessionCooldowns

function Module:CollectData(charKey, charData, professionName)
    return false
end

function Module:GetActiveCooldowns(charKey, charData, professionName)
    return {}
end

function Module:CleanExpiredCooldowns(charKey, charData, professionName)
    return false
end
