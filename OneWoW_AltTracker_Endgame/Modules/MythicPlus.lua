local addonName, ns = ...

ns.MythicPlus = {}
local Module = ns.MythicPlus

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    -- Per-map best run data is delivered async by the server. GetSeasonBestForMap
    -- returns nil for every mapID until RequestMapInfo has resolved; the server
    -- then fires CHALLENGE_MODE_MAPS_UPDATE and DataManager re-runs CollectData,
    -- which picks up the populated data on that follow-up pass. previousSeasonBest
    -- preserves prior captures so the first pass after login does not wipe known
    -- runs while the request is in flight.
    local previousSeasonBest = (charData.mythicPlus or {}).seasonBest or {}

    local mplusData = {
        currentKeystone = {
            mapID = nil,
            level = nil,
            mapName = nil,
        },
        overallScore = 0,
        seasonBest = {},
        lastUpdated = time(),
    }

    local keystoneMapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local keystoneLevel = C_MythicPlus.GetOwnedKeystoneLevel()

    if keystoneMapID then
        mplusData.currentKeystone.mapID = keystoneMapID
        mplusData.currentKeystone.level = keystoneLevel

        local mapName = C_ChallengeMode.GetMapUIInfo(keystoneMapID)
        if mapName then
            mplusData.currentKeystone.mapName = mapName
        end
    end

    local overallScore = C_ChallengeMode.GetOverallDungeonScore()
    if overallScore then
        mplusData.overallScore = overallScore
    end

    local mapTable = C_ChallengeMode.GetMapTable()
    if mapTable then
        C_MythicPlus.RequestMapInfo()

        for _, mapID in ipairs(mapTable) do
            local intimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(mapID)

            if intimeInfo or overtimeInfo then
                local mapInfo = {}

                if intimeInfo then
                    mapInfo.intime = {
                        level = intimeInfo.level,
                        durationSec = intimeInfo.durationSec,
                        members = {},
                    }

                    if intimeInfo.members then
                        for i, member in ipairs(intimeInfo.members) do
                            mapInfo.intime.members[i] = {
                                name = member.name,
                                classID = member.classID,
                            }
                        end
                    end
                end

                if overtimeInfo then
                    mapInfo.overtime = {
                        level = overtimeInfo.level,
                        durationSec = overtimeInfo.durationSec,
                        members = {},
                    }

                    if overtimeInfo.members then
                        for i, member in ipairs(overtimeInfo.members) do
                            mapInfo.overtime.members[i] = {
                                name = member.name,
                                classID = member.classID,
                            }
                        end
                    end
                end

                mplusData.seasonBest[mapID] = mapInfo
            elseif previousSeasonBest[mapID] then
                mplusData.seasonBest[mapID] = previousSeasonBest[mapID]
            end
        end
    end

    charData.mythicPlus = mplusData

    return true
end
