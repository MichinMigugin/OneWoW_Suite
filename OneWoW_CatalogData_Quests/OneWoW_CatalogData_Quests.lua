local _, ns = ...

OneWoW_CatalogData_Quests_API = {
    GetSettings = function()
        return ns:GetSettings()
    end,
    GetQuest = function(questID)
        return ns.QuestData and ns.QuestData:GetQuest(questID)
    end,
    GetQuestCount = function()
        return ns.QuestData and ns.QuestData:GetQuestCount() or 0
    end,
    GetCompletedCharacters = function(questID)
        return ns.CompletionTracker and ns.CompletionTracker:GetCompletedCharacters(questID) or {}
    end,
    GetQuestsForNPC = function(npcID)
        return ns.QuestData and ns.QuestData:GetQuestsForNPC(npcID)
    end,
    GetTrackedCharacterKeys = function()
        return ns.CompletionTracker and ns.CompletionTracker:GetTrackedCharacterKeys() or {}
    end,
    PurgeCharacter = function(charKey)
        return ns.CompletionTracker and ns.CompletionTracker:PurgeCharacter(charKey) or false
    end,
}
