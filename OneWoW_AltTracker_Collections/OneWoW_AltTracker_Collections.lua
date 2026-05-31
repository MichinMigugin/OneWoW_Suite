local addonName, ns = ...

_G.OneWoW_AltTracker_Collections = ns

if OneWoW_AltTracker_Collections_API then
    OneWoW_AltTracker_Collections_API = nil
end

OneWoW_AltTracker_Collections_API = {
    GetCharacterData = function(charKey)
        return ns.DataManager:GetCharacterData(charKey)
    end,

    GetAllCharacters = function()
        return ns.DataManager:GetAllCharacters()
    end,

    GetCurrentCharacterKey = function()
        return ns:GetCharacterKey()
    end,

    DeleteCharacter = function(charKey)
        return ns.DataManager:DeleteCharacter(charKey)
    end,

    ForceDataCollection = function()
        return ns.DataManager:CollectAllData()
    end,

    IsQuestCompleted = function(questID)
        return ns.Quests:IsQuestCompleted(questID)
    end,

    GetQuestInfo = function(questID)
        return ns.Quests:GetQuestInfo(questID)
    end,

    GetFactionStanding = function(factionID)
        return ns.Reputations:GetFactionStanding(factionID)
    end,

    GetAchievementInfo = function(achievementID)
        return ns.Achievements:GetAchievementInfo(achievementID)
    end,

}
