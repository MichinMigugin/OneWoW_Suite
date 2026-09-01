local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local pairs, ipairs, type = pairs, ipairs, type
local tonumber, tostring = tonumber, tostring
local tinsert, sort, wipe = tinsert, sort, wipe
local C_Map = C_Map
local C_QuestLog = C_QuestLog

-- Public, cross-addon read surface for QuestDB Archive. ns stays private.
-- Public, cross-addon read surface for Quest Archive. ns stays private.
OneWoW_CatDB_QuestDBArchive_API = {}

local API = OneWoW_CatDB_QuestDBArchive_API

local EXPANSION_NAMES = {
    [0]  = "Classic",
    [1]  = "Burning Crusade",
    [2]  = "Wrath of the Lich King",
    [3]  = "Cataclysm",
    [4]  = "Mists of Pandaria",
    [5]  = "Warlords of Draenor",
    [6]  = "Legion",
    [7]  = "Battle for Azeroth",
    [8]  = "Shadowlands",
    [9]  = "Dragonflight",
    [10] = "The War Within",
    [11] = "Midnight",
    [12] = "Midnight",
}

ns.itemNameCache = ns.itemNameCache or {}

local sortedQueryJob

local function CopyQuestIDList(src)
    local out = {}
    if type(src) ~= "table" then
        return out
    end
    for i = 1, #src do
        local id = tonumber(src[i])
        if id then
            tinsert(out, id)
        end
    end
    return out
end

local function HasValue(tbl, value)
    if type(tbl) ~= "table" then
        return false
    end
    for i = 1, #tbl do
        if tbl[i] == value then
            return true
        end
    end
    return false
end

local function HasAnyValue(tbl)
    return type(tbl) == "table" and #tbl > 0
end

local function QuestAssociatedWithNPC(quest, npcID)
    npcID = tonumber(npcID)
    if not quest or not npcID then
        return false
    end
    if tonumber(quest.questGiverID) == npcID or tonumber(quest.questTurnInID) == npcID then
        return true
    end
    local function listHasNPC(list)
        if not list then
            return false
        end
        for i = 1, #list do
            local entry = list[i]
            if type(entry) == "table" and tonumber(entry.npcID) == npcID then
                return true
            end
            if tonumber(entry) == npcID then
                return true
            end
        end
        return false
    end
    return listHasNPC(quest.starts) or listHasNPC(quest.ends)
end

local function QuestZoneName(quest)
    if quest.zoneName and quest.zoneName ~= "" then
        return quest.zoneName
    end
    if quest.mapID then
        local info = C_Map.GetMapInfo(quest.mapID)
        if info and info.name then
            return info.name
        end
    end
    return nil
end

local function QuestMatches(quest, expansionFilter, zoneFilter, typeFilter, questTypeFilter, searchText, advancedFilters)
    advancedFilters = advancedFilters or {}
    typeFilter = advancedFilters.groupType or typeFilter
    questTypeFilter = advancedFilters.questType or questTypeFilter
    if expansionFilter and expansionFilter ~= -1 and quest.expansion ~= expansionFilter then
        return false
    end
    if zoneFilter and zoneFilter ~= "" and zoneFilter ~= "all" then
        if QuestZoneName(quest) ~= zoneFilter then
            return false
        end
    end
    if typeFilter and typeFilter ~= "all" then
        local sg = quest.suggestedGroup or 0
        if typeFilter == "solo" and sg >= 2 then
            return false
        elseif typeFilter == "group" and (sg < 2 or sg >= 10) then
            return false
        elseif typeFilter == "raid" and sg < 10 then
            return false
        end
    end
    if questTypeFilter and questTypeFilter ~= "all" and quest.questType ~= questTypeFilter then
        return false
    end
    if searchText and searchText ~= "" then
        local needle = searchText:lower()
        local name = quest.name and quest.name:lower() or ""
        local idStr = tostring(quest.id or "")
        if not name:find(needle, 1, true) and not idStr:find(needle, 1, true) then
            local desc = quest.description and quest.description:lower() or ""
            if not desc:find(needle, 1, true) then
                return false
            end
        end
    end
    advancedFilters = advancedFilters or {}
    if advancedFilters.category and advancedFilters.category ~= "all" then
        if not HasValue(quest.categories, advancedFilters.category) then
            return false
        end
    end
    if advancedFilters.flag and advancedFilters.flag ~= "all" then
        if not HasValue(quest.flags, advancedFilters.flag) then
            return false
        end
    end
    if advancedFilters.faction and advancedFilters.faction ~= "all" then
        if quest.faction and quest.faction ~= "both" and quest.faction ~= advancedFilters.faction then
            return false
        end
    end
    if advancedFilters.story and advancedFilters.story ~= "all" then
        local hasQuestLine = HasAnyValue(quest.questLines)
        local hasStoryline = HasAnyValue(quest.storyline) or hasQuestLine
        local hasSeries = HasAnyValue(quest.series)
        local hasCampaign = HasAnyValue(quest.campaigns)
        if advancedFilters.story == "campaign" and not hasCampaign then
            return false
        elseif advancedFilters.story == "storyline" and not hasStoryline then
            return false
        elseif advancedFilters.story == "chain" and not hasSeries then
            return false
        elseif advancedFilters.story == "standalone" and (hasCampaign or hasStoryline or hasSeries) then
            return false
        end
    end
    if advancedFilters.npcID and not QuestAssociatedWithNPC(quest, advancedFilters.npcID) then
        return false
    end
    return true
end

local function CompareQuests(a, b)
    local expA, expB = a.expansion or 0, b.expansion or 0
    if expA ~= expB then
        return expA < expB
    end
    local nameA, nameB = a.name or "", b.name or ""
    if nameA ~= nameB then
        return nameA < nameB
    end
    return (a.id or 0) < (b.id or 0)
end

local function FillSortedQuests(expansionFilter, zoneFilter, typeFilter, questTypeFilter, searchText, advancedFilters, results, shouldYield)
    wipe(results)
    local source
    if expansionFilter and expansionFilter ~= -1 then
        source = ns.ExternalQuestDBByExpansion[expansionFilter]
    else
        source = ns.ExternalQuestDB
    end
    if not source then
        return
    end
    local YieldIfNeeded = OneWoW.ChunkedJob.YieldIfNeeded
    for _, quest in pairs(source) do
        if QuestMatches(quest, expansionFilter, zoneFilter, typeFilter, questTypeFilter, searchText, advancedFilters) then
            tinsert(results, quest)
        end
        YieldIfNeeded(shouldYield)
    end
    OneWoW.ChunkedJob.Sort(results, CompareQuests, shouldYield)
end

--- Returns the store settings.
---@return table settings
function API.GetSettings()
    return ns:GetSettings()
end

--- One quest record from shards already in memory.
---@param questID number
---@return table|nil quest
function API.GetQuest(questID)
    return ns.ExternalQuestDB[questID]
end

--- Merge extra quest shards into the hot quest DB.
---@param source table<number, table>
function API.ImportQuestData(source)
    ns:RegisterQuestData(source)
end

--- Archive is already loaded; run callback now.
---@param callback function
function API.EnsureArchiveThen(callback)
    if callback then
        callback()
    end
end

--- All quest records keyed by quest ID.
---@return table quests
function API.GetAllQuests()
    return ns.ExternalQuestDB
end

--- Total shipped quest count.
---@return number count
function API.GetQuestCount()
    local n = 0
    for _ in pairs(ns.ExternalQuestDB) do
        n = n + 1
    end
    return n
end

--- Same as GetQuestCount (old Quests pack aliased the two).
---@return number count
function API.GetCapturedQuestCount()
    return API.GetQuestCount()
end

--- Quests associated with an NPC.
---@param npcID number
---@return table|nil quests
function API.GetQuestsForNPC(npcID)
    return ns.QuestsByNPC[npcID]
end

--- Quests for one expansion. `-1` / nil returns the full DB.
---@param expansionID number|nil
---@return table quests
function API.GetQuestsForExpansion(expansionID)
    if expansionID == nil or expansionID == -1 then
        return ns.ExternalQuestDB
    end
    return ns.ExternalQuestDBByExpansion[expansionID] or {}
end

--- Sorted list for Catalog.
---@return table quests
function API.GetSortedQuests(expansionFilter, zoneFilter, typeFilter, questTypeFilter, searchText, advancedFilters)
    local results = {}
    FillSortedQuests(expansionFilter, zoneFilter, typeFilter, questTypeFilter, searchText, advancedFilters, results, nil)
    return results
end

function API.CancelSortedQuery()
    if sortedQueryJob then
        sortedQueryJob:Cancel()
        sortedQueryJob = nil
    end
end

--- Time-sliced sorted query into outResults.
---@return table jobHandle
function API.StartSortedQuests(...)
    local expansionFilter, zoneFilter, typeFilter, questTypeFilter, searchText, advancedFilters, outResults, opts = ...
    opts = opts or {}
    if type(outResults) ~= "table" then
        error("StartSortedQuests requires an outResults table", 2)
    end
    API.CancelSortedQuery()
    wipe(outResults)
    local job
    job = OneWoW.ChunkedJob.Start({
        budgetMs = opts.budgetMs,
        run = function(shouldYield)
            FillSortedQuests(
                expansionFilter,
                zoneFilter,
                typeFilter,
                questTypeFilter,
                searchText,
                advancedFilters,
                outResults,
                shouldYield
            )
        end,
        onProgress = opts.onProgress,
        onComplete = function()
            if sortedQueryJob == job then
                sortedQueryJob = nil
            end
            if opts.onComplete then
                opts.onComplete(outResults)
            end
        end,
        onCancel = function()
            if sortedQueryJob == job then
                sortedQueryJob = nil
            end
            if opts.onCancel then
                opts.onCancel()
            end
        end,
    })
    sortedQueryJob = job
    return job
end

---@param expansionID number
---@return string|nil name
function API.GetExpansionName(expansionID)
    return EXPANSION_NAMES[expansionID] or OneWoW:GetExpansionName(expansionID)
end

---@return table expansions
function API.GetAvailableExpansions()
    local found = {}
    for expID in pairs(ns.ExternalQuestDBByExpansion) do
        found[expID] = true
    end
    local result = {}
    for expID in pairs(found) do
        tinsert(result, {
            id = expID,
            name = API.GetExpansionName(expID) or tostring(expID),
        })
    end
    sort(result, function(a, b)
        return a.id < b.id
    end)
    return result
end

---@param expansionID number|nil
---@return table zones
function API.GetAvailableZones(expansionID)
    local source = API.GetQuestsForExpansion(expansionID)
    local found = {}
    for _, quest in pairs(source) do
        local zoneName = QuestZoneName(quest)
        if zoneName and zoneName ~= "" then
            found[zoneName] = true
        end
    end
    local result = {}
    for zoneName in pairs(found) do
        tinsert(result, zoneName)
    end
    sort(result)
    return result
end

---@param questID number
---@param data table
function API.StoreQuestInfo(questID, data)
    if not questID or type(data) ~= "table" then
        return
    end
    local quest = ns.ExternalQuestDB[questID]
    if not quest then
        data.id = data.id or questID
        ns:RegisterQuestData({ [questID] = data })
        return
    end
    for key, value in pairs(data) do
        quest[key] = value
    end
end

---@param questID number
---@param data table
function API.StoreQuestInfoQuiet(questID, data)
    API.StoreQuestInfo(questID, data)
end

---@param itemID number
---@param itemName string
function API.RememberItemName(itemID, itemName)
    if itemID and itemName and itemName ~= "" then
        ns.itemNameCache[itemID] = itemName
    end
end

---@param itemID number
---@return string|nil itemName
function API.GetCachedItemName(itemID)
    return ns.itemNameCache[itemID]
end

---@param shouldYield fun(): boolean|nil
---@return number[] itemIDs
function API.GetRewardItemIDs(shouldYield)
    local out = {}
    local YieldIfNeeded = OneWoW.ChunkedJob.YieldIfNeeded
    for itemID in pairs(ns.QuestsByRewardItem) do
        tinsert(out, itemID)
        YieldIfNeeded(shouldYield)
    end
    return out
end

--- Quest IDs that reward an item.
---@param itemID number
---@param loadArchive boolean|nil
---@return number[]|nil questIDs
function API.GetQuestsRewardingItem(itemID, loadArchive)
    local ids = ns.QuestsByRewardItem[itemID]
    if loadArchive and not ids then
        return nil
    end
    return ids
end

---@param quest table|number
---@return number[]|nil
function API.GetQuestGuideChain(quest)
    if type(quest) ~= "table" then
        quest = API.GetQuest(quest)
    end
    if not quest then
        return nil
    end
    for _, line in ipairs(quest.questLines or {}) do
        local members = line.id and OneWoW_CatDB_QuestDBCurrent_API.GetQuestLineMembers(line.id)
        if members and #members >= 2 then
            return CopyQuestIDList(members)
        end
    end
    local storyline = CopyQuestIDList(quest.storyline)
    if #storyline >= 2 then
        return storyline
    end
    local series = CopyQuestIDList(quest.series)
    if #series >= 2 then
        return series
    end
    local chain = CopyQuestIDList(quest.sourceQuests)
    local questID = tonumber(quest.id)
    if questID then
        local seen = {}
        for i = 1, #chain do
            seen[chain[i]] = true
        end
        if not seen[questID] then
            tinsert(chain, questID)
            seen[questID] = true
        end
        for _, id in ipairs(CopyQuestIDList(quest.nextQuests)) do
            if not seen[id] then
                seen[id] = true
                tinsert(chain, id)
            end
        end
    end
    if #chain >= 2 then
        return chain
    end
    return nil
end

local function CurrentQuestAPI()
    return OneWoW_CatDB_QuestDBCurrent_API
end

---@param questID number
---@return table
function API.GetCompletedCharacters(questID)
    local current = CurrentQuestAPI()
    if current then
        return current.GetCompletedCharacters(questID)
    end
    return {}
end

---@param questID number
---@return table
function API.GetActiveCharacters(questID)
    local current = CurrentQuestAPI()
    if current then
        return current.GetActiveCharacters(questID)
    end
    return {}
end

---@param questID number
---@return boolean
function API.IsCompletedByCurrentChar(questID)
    local current = CurrentQuestAPI()
    if current then
        return current.IsCompletedByCurrentChar(questID)
    end
    questID = tonumber(questID)
    if not questID then
        return false
    end
    return C_QuestLog.IsQuestFlaggedCompleted(questID) == true
end

---@return string[]
function API.GetTrackedCharacterKeys()
    local current = CurrentQuestAPI()
    if current then
        return current.GetTrackedCharacterKeys()
    end
    return {}
end

---@param charKey string
---@return boolean
function API.PurgeCharacter(charKey)
    local current = CurrentQuestAPI()
    if current then
        return current.PurgeCharacter(charKey)
    end
    return false
end

local pendingQuestNames = {}

local questNameFrame = CreateFrame("Frame")
questNameFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
questNameFrame:SetScript("OnEvent", function(_, _, questID, success)
    local cbs = pendingQuestNames[questID]
    if not cbs then
        return
    end
    pendingQuestNames[questID] = nil
    local name = success and API.GetQuestName(questID) or nil
    for i = 1, #cbs do
        xpcall(cbs[i], CallErrorHandler, questID, name)
    end
end)

---@param questID number
---@return string|nil name
function API.GetQuestName(questID)
    questID = tonumber(questID)
    if not questID then
        return nil
    end
    local quest = ns.ExternalQuestDB[questID]
    if quest and quest.name and quest.name ~= "" then
        return quest.name
    end
    local name = C_QuestLog.GetTitleForQuestID(questID)
    if name and name ~= "" then
        return name
    end
    name = QuestUtils_GetQuestName(questID)
    if name and name ~= "" then
        return name
    end
    return nil
end

---@param questID number
---@param callback fun(questID: number, name: string|nil)|nil
---@return string|nil name
function API.RequestQuestName(questID, callback)
    questID = tonumber(questID)
    if not questID then
        if callback then
            callback(questID, nil)
        end
        return nil
    end
    local name = API.GetQuestName(questID)
    if name then
        if callback then
            callback(questID, name)
        end
        return name
    end
    if callback then
        local list = pendingQuestNames[questID]
        if not list then
            list = {}
            pendingQuestNames[questID] = list
        end
        tinsert(list, callback)
    end
    C_QuestLog.RequestLoadQuestByID(questID)
    return nil
end

OneWoW_GUI:RegisterEntityResolver("quest", {
    Resolve = function(id)
        return API.GetQuestName(id)
    end,
    RequestAsync = function(id, cb)
        API.RequestQuestName(id, function(questID, name)
            cb(questID, name and { name = name } or nil)
        end)
    end,
})
