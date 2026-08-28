local _, ns = ...

-- Public, cross-addon read surface for the AltTracker hub. Endgame (RequiredDeps:
-- OneWoW_AltTracker) and hub UI call these dot-functions; ns stays private.
-- Most other AltTracker stores no longer TOC-depend on this hub.
OneWoW_AltTracker_API = {}

--- Effective progress override list. trackedCurrencyIDs is season defaults
--- minus player offs, plus extras (empty is allowed). Other keys: user copy
--- when non-empty, else the static baseline.
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

--- Every character known to any OneWoW database, with the stores each was found
--- in. Drives the core Roles & Alts tab's character list + purge. Sorted by last
--- login (most recent first), then name.
---@return table[] characters
function OneWoW_AltTracker_API.CollectAllCharacters()
    return ns.CharacterCleanup:CollectAll()
end

--- Permanently remove a character from every OneWoW database. A UI reload should
--- follow so stale in-memory views are dropped.
---@param charKey string
---@return string[] purgedFrom labels of stores the character was removed from
function OneWoW_AltTracker_API.PurgeCharacter(charKey)
    return ns.CharacterCleanup:Purge(charKey)
end

--- Toggle the AltTracker module in the suite hub (keybinding entry).
function OneWoW_AltTracker_API.Toggle()
    local mw = OneWoW.UI:GetMainWindow()
    local global = OneWoW:GetCoreGlobal()
    if mw and mw:IsShown() and global.lastModuleTab == "alttracker" then
        OneWoW.UI:Hide()
    else
        OneWoW.UI:Show("alttracker")
    end
end

--- Open Roles & Alts setup in suite settings (keybinding entry; former standalone setup).
function OneWoW_AltTracker_API.OpenSetup()
    OneWoW.UI:Show("settings")
    OneWoW.UI:SelectSubTab("settings", "rolesandalts")
end
