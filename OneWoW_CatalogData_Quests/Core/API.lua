local _, ns = ...

-- Public, cross-addon read surface for the Quests data store. ns stays private.
OneWoW_CatalogData_Quests_API = {}

--- Returns the quest store settings.
---@return table settings
function OneWoW_CatalogData_Quests_API.GetSettings()
    return ns:GetSettings()
end

--- Returns one merged quest record.
---@param questID number
---@return table|nil quest
function OneWoW_CatalogData_Quests_API.GetQuest(questID)
    return ns.QuestData:GetQuest(questID)
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

--- Stores runtime quest fields and notifies consumers.
---@param questID number
---@param data table
function OneWoW_CatalogData_Quests_API.StoreQuestInfo(questID, data)
    ns.QuestData:StoreQuestInfo(questID, data)
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
---@return number[] itemIDs
function OneWoW_CatalogData_Quests_API.GetRewardItemIDs()
    return ns.QuestData:GetRewardItemIDs()
end

--- Returns quest IDs that reward an item.
---@param itemID number
---@return number[]|nil questIDs
function OneWoW_CatalogData_Quests_API.GetQuestsRewardingItem(itemID)
    return ns.QuestData:GetQuestsRewardingItem(itemID)
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
