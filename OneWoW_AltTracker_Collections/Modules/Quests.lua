local addonName, ns = ...

ns.Quests = {}
local Module = ns.Quests

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    if not charData.quests then
        charData.quests = {}
    end

    local questsData = charData.quests

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    questsData.activeCount = numEntries or 0

    local activeQuests = {}
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader then
            table.insert(activeQuests, {
                questID  = info.questID,
                title    = info.title,
                isDaily  = info.frequency == Enum.QuestFrequency.Daily,
                isWeekly = info.frequency == Enum.QuestFrequency.Weekly,
                isComplete = info.isComplete,
            })
        end
    end
    questsData.active = activeQuests

    local completedQuests = {}
    local questIDs = C_QuestLog.GetAllCompletedQuestIDs()
    if questIDs then
        for _, questID in ipairs(questIDs) do
            table.insert(completedQuests, questID)
        end
    end
    questsData.completed = completedQuests
    questsData.completedCount = #completedQuests

    charData.lastUpdate = time()

    return true
end

function Module:IsQuestCompleted(questID)
    if not questID then return false end
    return C_QuestLog.IsQuestFlaggedCompleted(questID)
end

function Module:GetQuestInfo(questID)
    if not questID then return nil end

    local title = C_QuestLog.GetTitleForQuestID(questID)
    local isCompleted = C_QuestLog.IsQuestFlaggedCompleted(questID)

    return {
        questID = questID,
        title = title,
        isCompleted = isCompleted,
    }
end
