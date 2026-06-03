-- DEV TOOL (not shipped): stubs the WoW quest API and simulates a quest-accept
-- capture to verify QuestScanner produces correct enriched data with no errors.

local function scriptDir()
    local src = debug.getinfo(1, "S").source:gsub("^@", "")
    return src:match("^(.*[\\/])") or "./"
end
local root = scriptDir() .. "../"
local ADDON = "OneWoW_CatalogData_Quests"

-- ---- generic WoW global stubs ----
tinsert = table.insert
function strsplit(sep, s)
    local out, pat = {}, "([^" .. sep .. "]*)" .. sep .. "?"
    for piece in s:gmatch(pat) do out[#out + 1] = piece end
    out[#out] = nil
    return unpack(out)
end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local capturedHandler
local function makeFrame()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, fn) capturedHandler = fn end,
    }
end
CreateFrame = function() return makeFrame() end

local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }

Enum = {
    QuestClassification = { Important = 0, Legendary = 1, Campaign = 2, Calling = 3,
        Meta = 4, Recurring = 5, Questline = 6, Normal = 7, BonusObjective = 8,
        Threat = 9, WorldQuest = 10 },
    QuestFrequency = { Default = 0, Daily = 1, Weekly = 2 },
}

-- a fake quest 12345 from NPC "Captain Bob" (npcID 540) in map 84
UnitExists = function(u) return u == "npc" end
UnitGUID = function(u) return u == "npc" and "Creature-0-1-2-3-540-000012ABCD" or nil end
UnitName = function(u) return u == "npc" and "Captain Bob" or nil end

C_Map = {
    GetMapInfo = function(id) return { name = "Elwynn Forest", mapID = id } end,
    GetBestMapForUnit = function() return 84 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.42, 0.55 end } end,
}
C_CurrencyInfo = { GetCurrencyInfo = function() return { name = "Valorstones", iconFileID = 123 } end }
C_TaskQuest = { GetQuestTimeLeftSeconds = function() return nil end }

C_QuestLog = {
    GetLogIndexForQuestID = function() return 1 end,
    GetInfo = function() return { questID = 12345, title = "Defend the Keep", level = 10,
        suggestedGroup = 0, frequency = 0, isHeader = false, isHidden = false,
        isStory = true } end,
    GetTitleForQuestID = function() return "Defend the Keep" end,
    GetQuestObjectives = function() return { { text = "Slay 10 wolves", type = "monster",
        finished = false, numFulfilled = 3, numRequired = 10 } } end,
    GetRequiredMoney = function() return 0 end,
    IsPushableQuest = function() return true end,
    GetQuestTagInfo = function() return { tagName = "Group", tagID = 1, isElite = false } end,
    GetNumQuestLogEntries = function() return 0 end,
    GetAllCompletedQuestIDs = function() return {} end,
}
C_QuestInfoSystem = {
    GetQuestClassification = function() return Enum.QuestClassification.Campaign end,
    GetQuestRewardSpells = function() return {} end,
    GetQuestRewardCurrencies = function() return { { currencyID = 3008, quantity = 5 } } end,
}

GetQuestID = function() return 12345 end
GetTitleText = function() return "Defend the Keep" end
GetQuestText = function() return "The keep is under attack!" end
GetObjectiveText = function() return "Slay 10 wolves." end
GetQuestLogQuestText = function() return "The keep is under attack!", "Slay 10 wolves." end
GetQuestUiMapID = function() return 84 end
GetRewardMoney = function() return 0 end
GetRewardXP = function() return 0 end
GetNumQuestRewards = function() return 0 end
GetNumQuestChoices = function() return 0 end
GetQuestItemInfo = function() return nil end
GetQuestLogRewardMoney = function() return 1500 end
GetQuestLogRewardXP = function() return 800 end
GetNumQuestLogRewards = function() return 1 end
GetQuestLogRewardInfo = function() return "Sword", 134400, 1, 3, true, 12783 end
GetNumQuestLogChoices = function() return 0 end
GetQuestLogChoiceInfo = function() return nil end
GetQuestLogSpecialItemInfo = function() return nil end

-- ---- addon ns + QuestData stub that records stores ----
local ns = {}
local lastStore
function ns:GetDB() return { quests = {} } end
ns.QuestData = { StoreQuestInfo = function(_, questID, data) lastStore = { id = questID, data = data } end }
ns.CompletionTracker = { MarkCompleted = function() end }

local chunk = assert(loadfile(root .. "Modules/QuestScanner.lua"))
chunk(ADDON, ns)

-- ---- simulate QUEST_DETAIL then QUEST_ACCEPTED ----
capturedHandler(nil, "QUEST_DETAIL")
capturedHandler(nil, "QUEST_ACCEPTED", 12345)
for _, fn in ipairs(timers) do fn() end  -- run the C_Timer.After(0, ...) capture

local function check(label, cond, extra)
    print((cond and "  OK   " or "  FAIL ") .. label .. (extra ~= nil and ("  -> " .. tostring(extra)) or ""))
end

local d = lastStore and lastStore.data
check("stored quest 12345", lastStore and lastStore.id == 12345, lastStore and lastStore.id)
check("name captured", d and d.name == "Defend the Keep", d and d.name)
check("description captured", d and d.description == "The keep is under attack!", d and d.description)
check("questGiver NPC id from GUID", d and d.questGiverID == 540, d and d.questGiverID)
check("questGiver name", d and d.questGiverName == "Captain Bob", d and d.questGiverName)
check("mapID captured", d and d.mapID == 84, d and d.mapID)
check("zoneName resolved", d and d.zoneName == "Elwynn Forest", d and d.zoneName)
check("rewardGold", d and d.rewardGold == 1500, d and d.rewardGold)
check("rewardXP", d and d.rewardXP == 800, d and d.rewardXP)
check("rewardItems has 12783", d and d.rewardItems and d.rewardItems[1] == 12783, d and d.rewardItems and d.rewardItems[1])
check("campaign category", d and d.isCampaign == true, d and d.isCampaign)
check("story category from log", d and d.isStory == true, d and d.isStory)
check("starts[1] npc", d and d.starts and d.starts[1] and d.starts[1].npcID == 540, d and d.starts and d.starts[1] and d.starts[1].npcID)
check("coords captured", d and d.coords and d.coords.x == 42, d and d.coords and d.coords.x)
check("currency captured", d and d.rewardCurrencies and d.rewardCurrencies[1].name == "Valorstones",
    d and d.rewardCurrencies and d.rewardCurrencies[1] and d.rewardCurrencies[1].name)

print("done.")
