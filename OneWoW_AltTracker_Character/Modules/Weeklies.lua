local _, ns = ...

-- ============================================================================
-- Weeklies (character profession quests + account Trading Post)
-- ============================================================================
-- Profession weeklies stay on the character. Trading Post is account-wide.
-- ============================================================================

ns.Weeklies = {}
local Module = ns.Weeklies

local function IsProfessionWeekly(questID)
    if C_QuestLog.GetQuestType(questID) == Enum.QuestTagType.Profession then
        return true
    end
    local tag = C_QuestLog.GetQuestTagInfo(questID)
    if not tag then
        return false
    end
    if tag.worldQuestType == Enum.QuestTagType.Profession then
        return true
    end
    return (tag.tradeskillLineID or 0) > 0
end

function Module:CollectData(charKey, charData)
    local quests = {}
    local num = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, num do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.frequency == Enum.QuestFrequency.Weekly
            and IsProfessionWeekly(info.questID) then
            quests[#quests + 1] = {
                id = info.questID,
                name = info.title,
                complete = C_QuestLog.IsComplete(info.questID),
            }
        end
    end
    charData.weeklies = {
        collectedAt = time(),
        professionQuests = quests,
    }
    return true
end

function Module:CollectAccount()
    local account = ns:GetAccountBucket()
    local info = C_PerksActivities.GetPerksActivitiesInfo()
    local completed = 0
    local total = 0
    local points = 0
    local thresholdMax = 0
    local activities = info.activities
    if activities then
        for _, activity in pairs(activities) do
            total = total + 1
            if activity.completed then
                completed = completed + 1
                points = points + (activity.thresholdContributionAmount or 0)
            end
        end
    end
    local thresholds = info.thresholds
    if thresholds then
        for _, threshold in pairs(thresholds) do
            local need = threshold.requiredContributionAmount or 0
            if need > thresholdMax then
                thresholdMax = need
            end
        end
    end
    if points > thresholdMax and thresholdMax > 0 then
        points = thresholdMax
    end
    local pending = C_PerksProgram.GetPendingChestRewards()
    local pendingN = 0
    if pending then
        for _ in pairs(pending) do
            pendingN = pendingN + 1
        end
    end
    account.weeklies = account.weeklies or {}
    account.weeklies.tradingPost = {
        collectedAt = time(),
        month = info.activePerksMonth,
        monthName = info.displayMonthName,
        secondsRemaining = info.secondsRemaining,
        points = points,
        thresholdMax = thresholdMax,
        completed = completed,
        total = total,
        pendingReward = pendingN > 0,
    }
    return true
end
