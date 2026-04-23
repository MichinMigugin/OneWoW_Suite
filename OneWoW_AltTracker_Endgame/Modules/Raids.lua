-- OneWoW AltTracker Addon File
-- OneWoW_AltTracker_Endgame/Modules/Raids.lua
-- Created by MichinMigugin (Ricky)
local addonName, ns = ...

ns.Raids = {}
local Module = ns.Raids

local function GetSeasonData()
    if _G.OneWoW_AltTracker and _G.OneWoW_AltTracker.SeasonData then
        return _G.OneWoW_AltTracker.SeasonData
    end
    return nil
end

local function CollectLockouts()
    local lockouts = {}
    local numSavedInstances = GetNumSavedInstances()
    for i = 1, numSavedInstances do
        local name, id, reset, difficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i)

        if isRaid and locked then
            local lockoutData = {
                name = name,
                id = id,
                reset = reset,
                difficulty = difficulty,
                difficultyName = difficultyName,
                extended = extended,
                maxPlayers = maxPlayers,
                numEncounters = numEncounters,
                encounterProgress = encounterProgress,
                isRaid = true,
                encounters = {},
            }

            for j = 1, numEncounters do
                local bossName, fileDataID, isKilled = GetSavedInstanceEncounterInfo(i, j)
                lockoutData.encounters[j] = {
                    name = bossName,
                    isKilled = isKilled,
                    fileDataID = fileDataID,
                }
            end

            table.insert(lockouts, lockoutData)
        end
    end
    return lockouts
end

local function CollectRaidProgress(seasonData)
    local result = {}
    if not seasonData or not seasonData.raids or not seasonData.raidDifficulties then
        return result
    end

    local cache = seasonData:GetRaidCache()
    for _, raidEntry in ipairs(seasonData.raids) do
        local info = cache[raidEntry.label]
        if info and info.journalInstanceID and type(info.mapID) == "number" then
            local encounters = seasonData:GetRaidEncounters({
                label = raidEntry.label,
                journalInstanceID = info.journalInstanceID,
            })

            local raidBlock = {
                key = raidEntry.key,
                label = raidEntry.label,
                journalInstanceID = info.journalInstanceID,
                mapID = info.mapID,
                encounters = {},
                progress = {},
                numEncounters = #encounters,
            }

            for _, diff in ipairs(seasonData.raidDifficulties) do
                raidBlock.progress[diff.id] = 0
            end

            for _, enc in ipairs(encounters) do
                local encKey = enc.dungeonEncounterID or enc.journalEncounterID
                if encKey then
                    local encBlock = {
                        name = enc.name,
                        journalEncounterID = enc.journalEncounterID,
                        dungeonEncounterID = enc.dungeonEncounterID,
                        killed = {},
                    }

                    for _, diff in ipairs(seasonData.raidDifficulties) do
                        local complete = false
                        if type(info.mapID) == "number" and type(enc.dungeonEncounterID) == "number" and type(diff.id) == "number" then
                            complete = C_RaidLocks.IsEncounterComplete(info.mapID, enc.dungeonEncounterID, diff.id) and true or false
                        end
                        encBlock.killed[diff.id] = complete
                        if complete then
                            raidBlock.progress[diff.id] = raidBlock.progress[diff.id] + 1
                        end
                    end

                    raidBlock.encounters[encKey] = encBlock
                end
            end

            result[raidEntry.key] = raidBlock
        end
    end

    return result
end

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local seasonData = GetSeasonData()

    local raidsData = {
        lastUpdated = time(),
        lockouts = CollectLockouts(),
        bosses = CollectRaidProgress(seasonData),
    }

    charData.raids = raidsData
    return true
end
