-- OneWoW AltTracker Addon File
-- OneWoW_AltTracker_Endgame/Modules/WorldBoss.lua
-- Created by MichinMigugin (Ricky)
local addonName, ns = ...

ns.WorldBoss = {}
local Module = ns.WorldBoss

local DEFAULT_BOSS_QUEST_IDS = {}

local KNOWN_BOSS_NAMES = {}

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

    local questIDs = DEFAULT_BOSS_QUEST_IDS
    if _G.OneWoW_AltTracker_DB and
       _G.OneWoW_AltTracker_DB.global and
       _G.OneWoW_AltTracker_DB.global.overrides and
       _G.OneWoW_AltTracker_DB.global.overrides.progress and
       _G.OneWoW_AltTracker_DB.global.overrides.progress.worldBossQuestIDs and
       #_G.OneWoW_AltTracker_DB.global.overrides.progress.worldBossQuestIDs > 0 then
        questIDs = _G.OneWoW_AltTracker_DB.global.overrides.progress.worldBossQuestIDs
    end

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

function Module:GetDefaultQuestIDs()
    return DEFAULT_BOSS_QUEST_IDS
end
