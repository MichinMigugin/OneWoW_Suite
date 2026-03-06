-- OneWoW Addon File
-- OneWoW_CatalogData_Quests/OneWoW_CatalogData_Quests.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

_G.OneWoW_CatalogData_Quests = ns

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
}
