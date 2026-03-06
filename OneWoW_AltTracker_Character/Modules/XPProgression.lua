local addonName, ns = ...

ns.XPProgression = {}
local Module = ns.XPProgression

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local xpData = {}

    xpData.currentXP = UnitXP("player")
    xpData.maxXP = UnitXPMax("player")
    xpData.restedXP = GetXPExhaustion() or 0
    xpData.restState = GetRestState()
    xpData.isResting = IsResting()
    xpData.isXPDisabled = IsXPUserDisabled()

    charData.xp = xpData

    return true
end
