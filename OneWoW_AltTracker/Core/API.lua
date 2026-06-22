local _, ns = ...

-- Public, cross-addon read surface for the AltTracker hub. Companion stores
-- (RequiredDeps: OneWoW_AltTracker) call these dot-functions; ns stays private.
OneWoW_AltTracker_API = {}

--- Effective progress override list (user customization when non-empty, else baseline).
---@param key string "trackedCurrencyIDs" | "worldBossQuestIDs" | "weeklyActivityQuests"
---@return table|nil list
function OneWoW_AltTracker_API.GetProgressList(key)
    return ns:GetProgressList(key)
end

--- Shared season definition (raids, dungeons, difficulties) from Data/d-season.lua.
---@return table seasonData
function OneWoW_AltTracker_API.GetSeasonData()
    return ns.SeasonData
end
