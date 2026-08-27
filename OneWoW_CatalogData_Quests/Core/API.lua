local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

-- Public, cross-addon read surface for the Quests data store. ns stays private.
OneWoW_CatalogData_Quests_API = {}

--- Returns the quest store settings.
---@return table settings
function OneWoW_CatalogData_Quests_API.GetSettings()
    return ns:GetSettings()
end

--- Returns one merged quest record from shards already in memory.
--- Looking up an ID never parses Quest Archive. Load older expansions with
--- EnsureArchiveThen or by picking that expansion in Catalog.
---@param questID number
---@return table|nil quest
function OneWoW_CatalogData_Quests_API.GetQuest(questID)
    return ns.QuestData:GetQuest(questID)
end

--- Load Quest Archive, then run `callback`.
---@param callback function
function OneWoW_CatalogData_Quests_API.EnsureArchiveThen(callback)
    ns.QuestData:EnsureArchiveThen(callback)
end

--- Merge Archive (or any extra) shards into the hot quest DB and re-apply overlays.
---@param source table<number, table>
function OneWoW_CatalogData_Quests_API.ImportQuestData(source)
    ns:RegisterQuestData(source)
    ns.ApplyGeneratedOverlays(source)
    ns.QuestData:OnExternalDBChanged()
end

--- Ordered quest IDs for a later Guide button. Nil when the chain has fewer than 2 quests.
---@param quest table|number
---@return number[]|nil
function OneWoW_CatalogData_Quests_API.GetQuestGuideChain(quest)
    return ns.QuestData:GetQuestGuideChain(quest)
end

--- Returns all merged quest records keyed by quest ID.
---@return table quests
function OneWoW_CatalogData_Quests_API.GetAllQuests()
    return ns.QuestData:GetAllQuests()
end

--- Returns the total merged quest count.
---@return number count
function OneWoW_CatalogData_Quests_API.GetQuestCount()
    return ns.QuestData:GetQuestCount()
end

--- Returns the number of runtime-captured quests.
---@return number count
function OneWoW_CatalogData_Quests_API.GetCapturedQuestCount()
    return ns.QuestData:GetCapturedQuestCount()
end

--- Returns quests associated with an NPC.
---@param npcID number
---@return table|nil quests
function OneWoW_CatalogData_Quests_API.GetQuestsForNPC(npcID)
    return ns.QuestData:GetQuestsForNPC(npcID)
end

--- Returns quests for one expansion.
---@param expansionID number
---@return table quests
function OneWoW_CatalogData_Quests_API.GetQuestsForExpansion(expansionID)
    return ns.QuestData:GetQuestsForExpansion(expansionID)
end

--- Returns quests sorted and filtered for Catalog.
---@return table quests
function OneWoW_CatalogData_Quests_API.GetSortedQuests(...)
    return ns.QuestData:GetSortedQuests(...)
end

--- Cancel an in-flight StartSortedQuests job.
function OneWoW_CatalogData_Quests_API.CancelSortedQuery()
    ns.QuestData:CancelSortedQuery()
end

--- Time-sliced sorted query into outResults. Prefer for Catalog UI walks.
--- Args match QuestData:StartSortedQuests (filters…, outResults, opts).
---@return table jobHandle
function OneWoW_CatalogData_Quests_API.StartSortedQuests(...)
    return ns.QuestData:StartSortedQuests(...)
end

--- Returns an expansion display name.
---@param expansionID number
---@return string|nil name
function OneWoW_CatalogData_Quests_API.GetExpansionName(expansionID)
    return ns.QuestData:GetExpansionName(expansionID)
end

--- Returns available expansion filter values.
---@return table expansions
function OneWoW_CatalogData_Quests_API.GetAvailableExpansions()
    return ns.QuestData:GetAvailableExpansions()
end

--- Returns available zone filter values.
---@param expansionID number|nil
---@return table zones
function OneWoW_CatalogData_Quests_API.GetAvailableZones(expansionID)
    return ns.QuestData:GetAvailableZones(expansionID)
end

--- Stores runtime quest fields. Live captures patch merged caches and the
--- item/NPC indexes in place so loot and quest-reward tooltips stay cheap.
---@param questID number
---@param data table
function OneWoW_CatalogData_Quests_API.StoreQuestInfo(questID, data)
    ns.QuestData:StoreQuestInfo(questID, data)
end

--- Persist display-only fields without touching derived caches or the list.
---@param questID number
---@param data table
function OneWoW_CatalogData_Quests_API.StoreQuestInfoQuiet(questID, data)
    ns.QuestData:StoreQuestInfoQuiet(questID, data)
end

--- Stores a resolved reward-item name.
---@param itemID number
---@param itemName string
function OneWoW_CatalogData_Quests_API.RememberItemName(itemID, itemName)
    ns.QuestData:RememberItemName(itemID, itemName)
end

--- Returns a cached reward-item name.
---@param itemID number
---@return string|nil itemName
function OneWoW_CatalogData_Quests_API.GetCachedItemName(itemID)
    return ns.QuestData:GetCachedItemName(itemID)
end

--- Returns all indexed quest-reward item IDs.
---@param shouldYield fun(): boolean|nil
---@return number[] itemIDs
function OneWoW_CatalogData_Quests_API.GetRewardItemIDs(shouldYield)
    return ns.QuestData:GetRewardItemIDs(shouldYield)
end

--- Returns quest IDs that reward an item.
---@param itemID number
---@param loadArchive boolean|nil
---@return number[]|nil questIDs
function OneWoW_CatalogData_Quests_API.GetQuestsRewardingItem(itemID, loadArchive)
    return ns.QuestData:GetQuestsRewardingItem(itemID, loadArchive)
end

--- Returns characters that completed a quest.
---@param questID number
---@return table characters
function OneWoW_CatalogData_Quests_API.GetCompletedCharacters(questID)
    return ns.CompletionTracker:GetCompletedCharacters(questID)
end

--- Returns characters that currently have a quest active.
---@param questID number
---@return table characters
function OneWoW_CatalogData_Quests_API.GetActiveCharacters(questID)
    return ns.CompletionTracker:GetActiveCharacters(questID)
end

--- Reports whether the current character completed a quest.
---@param questID number
---@return boolean completed
function OneWoW_CatalogData_Quests_API.IsCompletedByCurrentChar(questID)
    return ns.CompletionTracker:IsCompletedByCurrentChar(questID)
end

--- Returns character keys tracked by the quest store.
---@return string[] charKeys
function OneWoW_CatalogData_Quests_API.GetTrackedCharacterKeys()
    return ns.CompletionTracker:GetTrackedCharacterKeys()
end

--- Removes one character's quest-completion data.
---@param charKey string
---@return boolean removed
function OneWoW_CatalogData_Quests_API.PurgeCharacter(charKey)
    return ns.CompletionTracker:PurgeCharacter(charKey)
end

local tinsert = tinsert
local pendingQuestNames = {}

local questNameFrame = CreateFrame("Frame")
questNameFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
questNameFrame:SetScript("OnEvent", function(_, _, questID, success)
    local cbs = pendingQuestNames[questID]
    if not cbs then return end
    pendingQuestNames[questID] = nil
    local name = success and OneWoW_CatalogData_Quests_API.GetQuestName(questID) or nil
    for i = 1, #cbs do
        xpcall(cbs[i], CallErrorHandler, questID, name)
    end
end)

--- Live or static quest title. Nil until the client has a name.
---@param questID number
---@return string|nil name
function OneWoW_CatalogData_Quests_API.GetQuestName(questID)
    questID = tonumber(questID)
    if not questID then return nil end

    local quest = ns.QuestData:GetQuest(questID)
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

--- Request a quest title. Invokes callback with (questID, name|nil).
---@param questID number
---@param callback fun(questID: number, name: string|nil)|nil
---@return string|nil name
function OneWoW_CatalogData_Quests_API.RequestQuestName(questID, callback)
    questID = tonumber(questID)
    if not questID then
        if callback then callback(questID, nil) end
        return nil
    end

    local name = OneWoW_CatalogData_Quests_API.GetQuestName(questID)
    if name then
        if callback then callback(questID, name) end
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
        return OneWoW_CatalogData_Quests_API.GetQuestName(id)
    end,
    RequestAsync = function(id, cb)
        OneWoW_CatalogData_Quests_API.RequestQuestName(id, function(questID, name)
            cb(questID, name and { name = name } or nil)
        end)
    end,
})
