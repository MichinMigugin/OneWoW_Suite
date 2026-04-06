-- OneWoW Addon File
-- OneWoW_CatalogData_Quests/Modules/QuestScanner.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.QuestScanner = {}
local QuestScanner = ns.QuestScanner

local SCAN_BATCH_SIZE  = 50
local SCAN_BATCH_DELAY = 0.1

local INTERNAL_PATTERNS = {
    "tracking quest",
    "^decor ",
    "^deprecated",
    "^test ",
    "^qa ",
}

local function IsInternalQuest(name, info)
    if not name then return true end
    if info and info.isHidden then return true end
    local lower = name:lower()
    for _, pattern in ipairs(INTERNAL_PATTERNS) do
        if lower:find(pattern) then return true end
    end
    return false
end

local function GetQuestLogIndex(questID)
    local count = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, count do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID == questID then
            return i
        end
    end
    return nil
end

local function CaptureQuestFromLog(questID)
    if not questID then return end

    local data = { id = questID }

    data.name = C_QuestLog.GetTitleForQuestID(questID)

    local logIndex = GetQuestLogIndex(questID)
    local logInfo  = logIndex and C_QuestLog.GetInfo(logIndex)
    if IsInternalQuest(data.name, logInfo) then
        ns.QuestData:StoreQuestInfo(questID, { id = questID, name = data.name, isInternal = true })
        return
    end

    local mapID = GetQuestUiMapID(questID)
    if mapID and mapID ~= 0 then
        data.mapID = mapID
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.name then
            data.zoneName = mapInfo.name
        end
    end

    if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification then
        local classification = C_QuestInfoSystem.GetQuestClassification(questID)
        data.classification = classification
        if classification == 2 then
            data.isCampaign = true
        elseif classification == 10 then
            data.isWorldQuest = true
        end
    end

    local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
    if tagInfo then
        data.tagName = tagInfo.tagName
        data.isElite = tagInfo.isElite or false
    end

    if logIndex then
        if logInfo then
            data.level          = logInfo.level
            data.suggestedGroup = logInfo.suggestedGroup or 0
            if logInfo.frequency == 1 then
                data.isDaily = true
            elseif logInfo.frequency == 2 then
                data.isWeekly = true
            end
        end

        local desc, obj = GetQuestLogQuestText(logIndex)
        if desc and desc ~= "" then
            data.description = desc
        end
        if obj and obj ~= "" then
            data.objectivesText = obj
        end
    end

    local objectives = C_QuestLog.GetQuestObjectives(questID)
    if objectives and #objectives > 0 then
        local objList = {}
        for _, obj in ipairs(objectives) do
            if obj.text and obj.text ~= "" then
                table.insert(objList, obj.text)
            end
        end
        if #objList > 0 then
            data.objectives = objList
        end
    end

    local rewardMoney = GetQuestLogRewardMoney(questID)
    if rewardMoney and rewardMoney > 0 then
        data.rewardGold = rewardMoney
    end

    local rewardXP = GetQuestLogRewardXP(questID)
    if rewardXP and rewardXP > 0 then
        data.rewardXP = rewardXP
    end

    local numRewards = GetNumQuestLogRewards(questID)
    if numRewards and numRewards > 0 then
        local items = {}
        for i = 1, numRewards do
            local itemName, itemTexture, numItems, quality, _, itemID = GetQuestLogRewardInfo(i, questID)
            if itemID then
                table.insert(items, {
                    itemID  = itemID,
                    name    = itemName,
                    count   = numItems or 1,
                    quality = quality,
                    texture = itemTexture,
                })
            end
        end
        if #items > 0 then
            data.rewardItems = items
        end
    end

    ns.QuestData:StoreQuestInfo(questID, data)
end

local function ScanActiveQuestLog()
    local count = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, count do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden and info.questID then
            CaptureQuestFromLog(info.questID)
        end
    end
end

local function ScanCompletedBatch(completedIDs, startIndex)
    local db = OneWoW_CatalogData_Quests_DB
    if not db then return end

    local endIndex = math.min(startIndex + SCAN_BATCH_SIZE - 1, #completedIDs)
    for i = startIndex, endIndex do
        local questID = completedIDs[i]
        if questID and not db.quests[questID] then
            local name     = C_QuestLog.GetTitleForQuestID(questID)
            local internal = IsInternalQuest(name, nil)
            ns.QuestData:StoreQuestInfo(questID, { id = questID, name = name, isInternal = internal })
        end
    end

    if endIndex < #completedIDs then
        C_Timer.After(SCAN_BATCH_DELAY, function()
            ScanCompletedBatch(completedIDs, endIndex + 1)
        end)
    end
end

local scanFrame = CreateFrame("Frame")
scanFrame:RegisterEvent("QUEST_ACCEPTED")
scanFrame:RegisterEvent("QUEST_TURNED_IN")
scanFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "QUEST_ACCEPTED" then
        local questLogIndex, questID = ...
        local qID = questID or questLogIndex
        if qID and type(qID) == "number" then
            C_Timer.After(0, function() CaptureQuestFromLog(qID) end)
        end
    elseif event == "QUEST_TURNED_IN" then
        local questID = ...
        if questID and ns.CompletionTracker then
            ns.CompletionTracker:MarkCompleted(questID)
        end
    end
end)

function QuestScanner:Initialize()
    C_Timer.After(1.5, function()
        ScanActiveQuestLog()
        local completedIDs = C_QuestLog.GetAllCompletedQuestIDs()
        if completedIDs and #completedIDs > 0 then
            C_Timer.After(0.5, function()
                ScanCompletedBatch(completedIDs, 1)
            end)
        end
    end)
end
