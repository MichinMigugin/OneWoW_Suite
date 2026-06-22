local _, ns = ...

-- Public, cross-addon read surface for the Collections unit. ns stays private.
OneWoW_AltTracker_Collections_API = {}

--- Stored collections data for a character.
---@param charKey string
---@return table|nil charData
function OneWoW_AltTracker_Collections_API.GetCharacterData(charKey)
    return ns.DataManager:GetCharacterData(charKey)
end

--- All stored characters keyed by character key.
---@return table characters charKey -> charData
function OneWoW_AltTracker_Collections_API.GetAllCharacters()
    return ns.DataManager:GetAllCharacters()
end

--- Character key for the logged-in player.
---@return string|nil charKey
function OneWoW_AltTracker_Collections_API.GetCurrentCharacterKey()
    return ns:GetCharacterKey()
end

--- Delete a character's stored collections data.
---@param charKey string
---@return boolean deleted
function OneWoW_AltTracker_Collections_API.DeleteCharacter(charKey)
    return ns.DataManager:DeleteCharacter(charKey)
end

--- Trigger a full data collection pass for the current character.
function OneWoW_AltTracker_Collections_API.ForceDataCollection()
    return ns.DataManager:CollectAllData()
end

--- Whether a quest is flagged completed for the current character.
---@param questID number
---@return boolean completed
function OneWoW_AltTracker_Collections_API.IsQuestCompleted(questID)
    return ns.Quests:IsQuestCompleted(questID)
end

--- Title/completion info for a quest.
---@param questID number
---@return table|nil info
function OneWoW_AltTracker_Collections_API.GetQuestInfo(questID)
    return ns.Quests:GetQuestInfo(questID)
end

--- Current standing for a faction.
---@param factionID number
---@return table|nil standing
function OneWoW_AltTracker_Collections_API.GetFactionStanding(factionID)
    return ns.Reputations:GetFactionStanding(factionID)
end

--- Info for an achievement.
---@param achievementID number
---@return table|nil info
function OneWoW_AltTracker_Collections_API.GetAchievementInfo(achievementID)
    return ns.Achievements:GetAchievementInfo(achievementID)
end
