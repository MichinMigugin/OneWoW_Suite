local addonName, ns = ...

ns.Raids = {}
local Module = ns.Raids

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local raidsData = {
        lockouts = {},
        lastUpdated = time(),
    }

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
                encounters = {},
            }

            for j = 1, numEncounters do
                local bossName, fileDataID, isKilled, unknown4 = GetSavedInstanceEncounterInfo(i, j)

                lockoutData.encounters[j] = {
                    name = bossName,
                    isKilled = isKilled,
                    fileDataID = fileDataID,
                }
            end

            table.insert(raidsData.lockouts, lockoutData)
        end
    end

    charData.raids = raidsData

    return true
end
