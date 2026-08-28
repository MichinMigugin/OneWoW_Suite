local _, ns = ...

ns.Raids = {}
local Module = ns.Raids

local tinsert = tinsert
local C_RaidLocks = C_RaidLocks
local C_QuestLog = C_QuestLog
local GetNumSavedInstances = GetNumSavedInstances
local GetSavedInstanceInfo = GetSavedInstanceInfo
local GetSavedInstanceEncounterInfo = GetSavedInstanceEncounterInfo
local GetNumSavedWorldBosses = GetNumSavedWorldBosses
local GetSavedWorldBossInfo = GetSavedWorldBossInfo

-- Tidebound Grotto weekly outdoor lock. Do not treat EJ IsEncounterComplete as
-- a per-difficulty signal; it follows the last selected Adventure Guide difficulty.
local WORLD_DIFFICULTY_ID = 250

local function NamesMatch(a, b)
    if a == b then return true end
    if not a or not b then return false end
    return (a:gsub("^The ", "")) == (b:gsub("^The ", ""))
end

local function CollectLockouts()
    local lockouts = {}
    local numSavedInstances = GetNumSavedInstances()
    for i = 1, numSavedInstances do
        local name, id, reset, difficulty, locked, extended, _, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i)

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

            tinsert(lockouts, lockoutData)
        end
    end
    return lockouts
end

local function RaidLockComplete(mapID, dungeonEncounterID, difficultyID)
    if type(mapID) ~= "number" or type(dungeonEncounterID) ~= "number" or type(difficultyID) ~= "number" then
        return false
    end
    local checkDiff = C_RaidLocks.GetRedirectedDifficultyID(mapID, difficultyID)
    return C_RaidLocks.IsEncounterComplete(mapID, dungeonEncounterID, checkDiff) and true or false
end

local function LockoutEncounterKilled(lockouts, raidNames, difficultyID, encounterName)
    for i = 1, #lockouts do
        local lockout = lockouts[i]
        if lockout.difficulty == difficultyID then
            local nameHit = false
            for j = 1, #raidNames do
                if NamesMatch(lockout.name, raidNames[j]) then
                    nameHit = true
                    break
                end
            end
            if nameHit then
                local encs = lockout.encounters
                for k = 1, #encs do
                    if encs[k].isKilled and NamesMatch(encs[k].name, encounterName) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function WorldBossSaved(encounterName)
    local n = GetNumSavedWorldBosses()
    for i = 1, n do
        local name = GetSavedWorldBossInfo(i)
        if NamesMatch(name, encounterName) then
            return true
        end
    end
    return false
end

local function CollectRaidProgress(seasonData, lockouts)
    local result = {}
    if not seasonData or not seasonData.raids then
        return result
    end

    for _, raidEntry in ipairs(seasonData.raids) do
        local journalInstanceID, mapID = seasonData:ResolveRaid(raidEntry)
        if journalInstanceID and type(mapID) == "number" then
            local encounters = seasonData:GetRaidEncounters({
                label = raidEntry.label,
                journalInstanceID = journalInstanceID,
            })
            local difficulties = seasonData:GetRaidDifficulties(raidEntry)
            local localizedName = EJ_GetInstanceInfo(journalInstanceID)
            local raidNames = { localizedName, raidEntry.label }

            local raidBlock = {
                key = raidEntry.key,
                label = localizedName or raidEntry.label,
                journalInstanceID = journalInstanceID,
                mapID = mapID,
                encounters = {},
                progress = {},
                numEncounters = #encounters,
            }

            for _, diff in ipairs(difficulties) do
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

                    for _, diff in ipairs(difficulties) do
                        local complete = RaidLockComplete(mapID, enc.dungeonEncounterID, diff.id)
                        if not complete then
                            complete = LockoutEncounterKilled(lockouts, raidNames, diff.id, enc.name)
                        end
                        if not complete and diff.id == WORLD_DIFFICULTY_ID then
                            if raidEntry.worldBossQuestID and C_QuestLog.IsQuestFlaggedCompleted(raidEntry.worldBossQuestID) then
                                complete = true
                            elseif WorldBossSaved(enc.name) then
                                complete = true
                            end
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

    local seasonData = OneWoW_AltTracker_API.GetSeasonData()
    local lockouts = CollectLockouts()

    local raidsData = {
        lastUpdated = time(),
        lockouts = lockouts,
        bosses = CollectRaidProgress(seasonData, lockouts),
    }

    charData.raids = raidsData
    return true
end
