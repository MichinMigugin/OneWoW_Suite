local _, ns = ...

local E = ns.TrackerEvaluators
local ipairs, tonumber = ipairs, tonumber

local function CountFlagged(ids, checkFn)
    local done = 0
    for _, id in ipairs(ids) do
        if checkFn(tonumber(id)) then
            done = done + 1
        end
    end
    return done
end

local function EvalQuestFlag(op, checkFn)
    local qid = tonumber(op.questID)
    if qid then
        return checkFn(qid) and 1 or 0, 1
    end
    if op.questIDs then
        return CountFlagged(op.questIDs, checkFn), #op.questIDs
    end
end

E.Register("quest", function(op)
    return EvalQuestFlag(op, C_QuestLog.IsQuestFlaggedCompleted)
end)

E.Register("rare_quest", function(op)
    return EvalQuestFlag(op, C_QuestLog.IsQuestFlaggedCompleted)
end)

E.Register("quest_account", function(op)
    return EvalQuestFlag(op, C_QuestLog.IsQuestFlaggedCompletedOnAccount)
end)

local function EvalPool(op, checkFn)
    if not op.questIDs then return end
    local done = CountFlagged(op.questIDs, checkFn)
    local pick = tonumber(op.pick) or #op.questIDs
    return done, pick
end

E.Register("quest_pool", function(op)
    return EvalPool(op, C_QuestLog.IsQuestFlaggedCompleted)
end)

E.Register("quest_pool_account", function(op)
    return EvalPool(op, C_QuestLog.IsQuestFlaggedCompletedOnAccount)
end)

E.Register("quest_progress", function(op)
    local qid = tonumber(op.questID)
    local objIdx = tonumber(op.objectiveIndex) or 1
    if not qid then return end
    if C_QuestLog.IsQuestFlaggedCompleted(qid) then
        local objectives = C_QuestLog.GetQuestObjectives(qid)
        if objectives and objectives[objIdx] then
            return objectives[objIdx].numRequired or 1, objectives[objIdx].numRequired or 1
        end
        return 1, 1
    end
    local objectives = C_QuestLog.GetQuestObjectives(qid)
    if objectives and objectives[objIdx] then
        return objectives[objIdx].numFulfilled or 0, objectives[objIdx].numRequired or 1
    end
    return 0, 1
end)

E.Register("quest_active", function(op)
    local qid = tonumber(op.questID)
    if qid then
        return C_QuestLog.IsOnQuest(qid) and 1 or 0, 1
    end
end)

E.Register("quest_world", function(op)
    local qid = tonumber(op.questID)
    if not qid then return end
    if C_QuestLog.IsQuestFlaggedCompleted(qid) then return 1, 1 end
    return 0, 1
end)

E.Register("campaign", function(op)
    local campaignID = tonumber(op.campaignID)
    if not campaignID then return end
    local info = C_CampaignInfo.GetCampaignInfo(campaignID)
    if not info then return end
    if info.complete then return 1, 1 end
    local chapters = C_CampaignInfo.GetChapterIDs(campaignID)
    if not chapters then return end
    local done = 0
    for _, chapterID in ipairs(chapters) do
        local chapterInfo = C_CampaignInfo.GetCampaignChapterInfo(chapterID)
        if chapterInfo and chapterInfo.completed then
            done = done + 1
        end
    end
    return done, #chapters
end)
