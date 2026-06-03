-- DEV TOOL (not shipped): smoke-tests the merged QuestData model against the
-- real cleaned static DB plus a simulated runtime capture. Run with standalone
-- Lua 5.1; stubs the WoW globals QuestData relies on.

local function scriptDir()
    local src = debug.getinfo(1, "S").source:gsub("^@", "")
    return src:match("^(.*[\\/])") or "./"
end
local root = scriptDir() .. "../"
local ADDON = "OneWoW_CatalogData_Quests"

-- ---- WoW global stubs ----
tinsert = table.insert
tremove = table.remove
sort = table.sort
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
time = os.time
C_Timer = { After = function(_, fn) end }
C_Map = { GetMapInfo = function() return nil end }
C_Item = { GetItemInfo = function() return nil end }
OneWoW_Catalog = { UI = {}, ItemSearch = nil }
OneWoW_Catalog_DB = { global = { itemCache = {} } }

-- ---- addon namespace + DB stub ----
local ns = {}
local runtime = { quests = {} }
function ns:GetDB() return runtime end

local function runFile(rel)
    local chunk = assert(loadfile(root .. rel))
    return chunk(ADDON, ns)
end

runFile("Core/QuestDBLoader.lua")
for _, e in ipairs({ "classic", "bc", "wotlk" }) do
    runFile("Data/QuestDB/QuestDB_" .. e .. ".lua")
end

local QuestData = runFile("Modules/QuestData.lua")

-- ---- tests ----
local function check(label, cond, extra)
    print((cond and "  OK   " or "  FAIL ") .. label .. (extra and ("  -> " .. tostring(extra)) or ""))
    return cond
end

local q = QuestData:GetQuest(10068)
check("GetQuest(10068) returns Frost Nova", q and q.name == "Frost Nova", q and q.name)

local total = QuestData:GetQuestCount()
check("GetQuestCount > 5000 (classic+bc+wotlk)", total > 5000, total)

local exps = QuestData:GetAvailableExpansions()
check("GetAvailableExpansions non-empty", #exps > 0, #exps .. " expansions")

-- runtime merge: live capture overrides static fields + adds new quest
QuestData:StoreQuestInfo(10068, { questGiverName = "Test Giver", expansion = 1 })
local merged = QuestData:GetQuest(10068)
check("runtime field merged over static", merged and merged.questGiverName == "Test Giver", merged and merged.questGiverName)
check("static fields preserved after merge", merged and merged.name == "Frost Nova", merged and merged.name)

QuestData:StoreQuestInfo(99999901, { id = 99999901, name = "Live Only Quest", expansion = 11, description = "A live captured quest.", rewardXP = 100 })
local live = QuestData:GetQuest(99999901)
check("live-only quest retrievable", live and live.name == "Live Only Quest", live and live.name)

-- search
local results = QuestData:GetSortedQuests(nil, nil, nil, nil, "frost")
check("search 'frost' returns results", #results > 0, #results .. " hits")

-- self-heal: cleared quest giver
QuestData:StoreQuestInfo(10068, { questGiverCleared = true })
local healed = QuestData:GetQuest(10068)
check("questGiverCleared wipes giver", healed and healed.questGiverName == nil, healed and healed.questGiverName)

-- initial-view cap
local initial, total = QuestData:GetInitialQuests(100)
check("GetInitialQuests caps to 100", #initial == 100, #initial)
check("GetInitialQuests reports total > 100", total > 100, total)
check("initial list is sorted by name", initial[1].name <= initial[2].name, initial[1] and initial[1].name)

-- quest reward index: Frost Nova (10068) rewards item 53365
local rewardingFrost = QuestData:GetQuestsRewardingItem(53365)
local foundFrost = false
if rewardingFrost then
    for _, qid in ipairs(rewardingFrost) do if qid == 10068 then foundFrost = true end end
end
check("GetQuestsRewardingItem(53365) includes quest 10068", foundFrost, rewardingFrost and #rewardingFrost)
check("GetRewardItemIDs non-empty", #QuestData:GetRewardItemIDs() > 0, #QuestData:GetRewardItemIDs())
check("GetQuestsRewardingItem(unknown) is nil", QuestData:GetQuestsRewardingItem(999999999) == nil)

local fv = QuestData:GetFilterValues()
check("GetFilterValues classes non-empty", #fv.classes > 0, #fv.classes)
check("GetFilterValues races non-empty", #fv.races > 0, #fv.races)
check("GetFilterValues categories non-empty", #fv.categories > 0, #fv.categories)

-- NPC index: store a quest giver and look it up
QuestData:StoreQuestInfo(10072, { questGiverID = 17999, questGiverName = "Test Giver NPC" })
local npcQuests = QuestData:GetQuestsForNPC(17999)
local foundNPC = false
if npcQuests then for _, qid in ipairs(npcQuests) do if qid == 10072 then foundNPC = true end end end
check("GetQuestsForNPC(17999) includes quest 10072", foundNPC, npcQuests and #npcQuests)
check("GetQuestsForNPC(unknown) is nil", QuestData:GetQuestsForNPC(424242) == nil)

print("done.")
