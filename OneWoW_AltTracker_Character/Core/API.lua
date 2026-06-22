local _, ns = ...

-- Public, cross-addon read surface for the Character unit. ns stays private.
OneWoW_AltTracker_Character_API = {}

--- Stored character data (info, stats, equipment, progression).
---@param charKey string
---@return table|nil charData
function OneWoW_AltTracker_Character_API.GetCharacterData(charKey)
    return ns.DataManager:GetCharacterData(charKey)
end

--- All stored characters keyed by character key.
---@return table characters charKey -> charData
function OneWoW_AltTracker_Character_API.GetAllCharacters()
    return ns.DataManager:GetAllCharacters()
end

--- Character key for the logged-in player.
---@return string|nil charKey
function OneWoW_AltTracker_Character_API.GetCurrentCharacterKey()
    return ns:GetCharacterKey()
end

--- Delete a character's stored data.
---@param charKey string
---@return boolean deleted
function OneWoW_AltTracker_Character_API.DeleteCharacter(charKey)
    return ns.DataManager:DeleteCharacter(charKey)
end

--- Collect action bar data for the current character.
function OneWoW_AltTracker_Character_API.CollectActionBars()
    return ns.DataManager:CollectActionBars()
end

--- The action-bar set module (save/restore action-bar layouts, macros, and
--- keybinds). The hub's action-bars tab drives it via colon-methods.
---@return table actionBars the ns.ActionBars module
function OneWoW_AltTracker_Character_API.GetActionBarsModule()
    return ns.ActionBars
end

--- Trigger a full data collection pass for the current character.
function OneWoW_AltTracker_Character_API.ForceDataCollection()
    return ns.DataManager:CollectAllData()
end
