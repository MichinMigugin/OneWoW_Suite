local _, ns = ...

ns.WeeklyActivities = {}
local Module = ns.WeeklyActivities

-- Prefer live objective progress when Blizzard exposes it. Season meta quests
-- (e.g. 95842/95843) often stay IsQuestFlaggedCompleted after the intro, so the
-- flag alone is not a weekly signal. Zone weeklies still fall back to the flag.
local function QuestObjectivesComplete(questID)
    local objectives = C_QuestLog.GetQuestObjectives(questID)
    if type(objectives) ~= "table" or #objectives == 0 then
        return nil
    end
    for i = 1, #objectives do
        if not objectives[i].finished then
            return false
        end
    end
    return true
end

local function IsQuestDoneThisWeek(questID)
    local objDone = QuestObjectivesComplete(questID)
    if objDone ~= nil then
        return objDone
    end
    if C_QuestLog.IsOnQuest(questID) then
        return C_QuestLog.IsComplete(questID) and true or false
    end
    -- Season metas (95842/95843) often keep a sticky completion flag after the
    -- intro chain. Without objectives or an active log entry, do not treat the
    -- bare flag as "done this week." Normal weeklies still use the flag.
    local classification = C_QuestInfoSystem.GetQuestClassification(questID)
    if classification == Enum.QuestClassification.Meta then
        return false
    end
    return C_QuestLog.IsQuestFlaggedCompleted(questID) and true or false
end

local function GetEntryQuestIDs(entry)
    if type(entry.questIDs) == "table" and #entry.questIDs > 0 then
        return entry.questIDs
    end
    if entry.questID and entry.questID > 0 then
        return { entry.questID }
    end
    return nil
end

local function IsEntryCompleted(entry)
    local ids = GetEntryQuestIDs(entry)
    if not ids then
        return false
    end

    local mode = entry.mode or "any"
    if mode == "all" then
        for _, questID in ipairs(ids) do
            if not IsQuestDoneThisWeek(questID) then
                return false
            end
        end
        return true
    end

    for _, questID in ipairs(ids) do
        if IsQuestDoneThisWeek(questID) then
            return true
        end
    end
    return false
end

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local weeklyData = {
        activities = {},
        lastUpdated = time(),
    }

    local list = OneWoW_AltTracker_API.GetProgressList("weeklyActivityQuests")

    for _, entry in ipairs(list) do
        local key = entry.key
        if key then
            local ids = GetEntryQuestIDs(entry)
            local title
            if ids then
                for _, questID in ipairs(ids) do
                    title = C_QuestLog.GetTitleForQuestID(questID)
                    if title then break end
                end
            end
            weeklyData.activities[key] = {
                key       = key,
                questIDs  = ids,
                name      = entry.name or title or key,
                title     = title,
                completed = IsEntryCompleted(entry),
            }
        end
    end

    charData.weeklyActivities = weeklyData
    return true
end
