local addonName, ns = ...

ns.PlayTime = {}
local Module = ns.PlayTime

local lastRequest = 0
local THROTTLE_SECONDS = 300

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local currentTime = time()
    if currentTime - lastRequest < THROTTLE_SECONDS then
        return false
    end

    if not OneWoW_AltTracker_Character_DB.settings.enablePlaytimeTracking then
        return false
    end

    RequestTimePlayed()
    lastRequest = currentTime

    return true
end

function Module:OnTimePlayedMsg(totalTime, levelTime)
    local charKey = ns:GetCharacterKey()
    if not charKey then return end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return end

    if not charData.playTime then
        charData.playTime = {}
    end

    charData.playTime.total = totalTime
    charData.playTime.thisLevel = levelTime
    charData.playTime.lastUpdate = time()
end
