local _, ns = ...

ns.WorldBoss = {}
local Module = ns.WorldBoss

local KNOWN_BOSS_NAMES = {
    [92123] = "Cragpine",
    [92560] = "Lu'ashal",
    [92636] = "Predaxas",
    [92034] = "Thorm'belan",
    [96472] = "Nexus-Captain Leth'ir",
    [96473] = "Imperator Pertinax",
    [97128] = "Nymrissa Wavecaller",
}

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local worldBossData = {
        killedBosses = {},
        questCompleted = false,
        questBossName = nil,
        questBossID = nil,
        lastUpdated = time(),
    }

    local numBosses = GetNumSavedWorldBosses()
    for i = 1, numBosses do
        local name, worldBossID, reset = GetSavedWorldBossInfo(i)
        if name then
            table.insert(worldBossData.killedBosses, {
                name = name,
                id = worldBossID,
                reset = reset,
            })
        end
    end

    local questIDs = OneWoW_AltTracker_API.GetProgressList("worldBossQuestIDs")

    for _, questID in ipairs(questIDs) do
        if C_QuestLog.IsQuestFlaggedCompleted(questID) then
            worldBossData.questCompleted = true
            worldBossData.questBossID = questID
            local title = C_QuestLog.GetTitleForQuestID(questID)
            worldBossData.questBossName = title or KNOWN_BOSS_NAMES[questID]
            break
        end
    end

    charData.worldBoss = worldBossData
    return true
end

function Module:GetKnownBossNames()
    return KNOWN_BOSS_NAMES
end
