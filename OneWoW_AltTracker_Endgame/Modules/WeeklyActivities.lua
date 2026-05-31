-- OneWoW AltTracker Addon File
-- OneWoW_AltTracker_Endgame/Modules/WeeklyActivities.lua
-- Created by MichinMigugin (Ricky)
local addonName, ns = ...

ns.WeeklyActivities = {}
local Module = ns.WeeklyActivities

local DEFAULT_ACTIVITY_QUESTS = {
    {questID = 95842, key = "voidAssaults", name = "Void Assaults"},
    {questID = 95843, key = "ritualSites",  name = "Ritual Sites"},
}

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local weeklyData = {
        activities = {},
        lastUpdated = time(),
    }

    local list = DEFAULT_ACTIVITY_QUESTS
    if _G.OneWoW_AltTracker_DB and
       _G.OneWoW_AltTracker_DB.global and
       _G.OneWoW_AltTracker_DB.global.overrides and
       _G.OneWoW_AltTracker_DB.global.overrides.progress and
       _G.OneWoW_AltTracker_DB.global.overrides.progress.weeklyActivityQuests and
       #_G.OneWoW_AltTracker_DB.global.overrides.progress.weeklyActivityQuests > 0 then
        list = _G.OneWoW_AltTracker_DB.global.overrides.progress.weeklyActivityQuests
    end

    for _, entry in ipairs(list) do
        local questID = entry.questID
        if questID and questID > 0 then
            local title = C_QuestLog.GetTitleForQuestID(questID)
            weeklyData.activities[questID] = {
                questID   = questID,
                key       = entry.key,
                name      = entry.name or title or ("Quest " .. questID),
                title     = title,
                completed = C_QuestLog.IsQuestFlaggedCompleted(questID),
            }
        end
    end

    charData.weeklyActivities = weeklyData
    return true
end

function Module:GetDefaultActivities()
    return DEFAULT_ACTIVITY_QUESTS
end
