local _, ns = ...

-- Public, cross-addon read surface for the Endgame unit (Mythic+, raids, Great
-- Vault, PVP, currencies, weekly activities). ns stays private.
OneWoW_AltTracker_Endgame_API = {}

--- Stored endgame progression data for a character (raids/lockouts, mythic+,
--- great vault, pvp, currencies, weekly activities).
---@param charKey string
---@return table|nil charData
function OneWoW_AltTracker_Endgame_API.GetCharacterData(charKey)
    return ns.DataManager:GetCharacterData(charKey)
end

--- All stored characters keyed by character key.
---@return table characters charKey -> charData
function OneWoW_AltTracker_Endgame_API.GetAllCharacters()
    return ns.DataManager:GetAllCharacters()
end

--- Character key for the logged-in player.
---@return string|nil charKey
function OneWoW_AltTracker_Endgame_API.GetCurrentCharacterKey()
    return ns:GetCharacterKey()
end

--- Delete a character's stored endgame data.
---@param charKey string
---@return boolean deleted
function OneWoW_AltTracker_Endgame_API.DeleteCharacter(charKey)
    return ns.DataManager:DeleteCharacter(charKey)
end
