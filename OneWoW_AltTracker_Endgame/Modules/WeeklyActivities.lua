local _, ns = ...

ns.WeeklyActivities = {}
local Module = ns.WeeklyActivities

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local weeklyData = {
        activities = {},
        lastUpdated = time(),
    }

    local list = OneWoW_AltTracker_API.GetProgressList("weeklyActivityQuests")

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
