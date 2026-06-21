local _, ns = ...
local L = ns.L

-- ============================================================================
-- Navigation
-- ============================================================================
-- Shared map navigation for the Catalog: opens the world map to a zone and, when
-- coordinates are known, drops a super-tracked user waypoint.
--
-- Coordinates are stored 0-100 in the quest/vendor data; the waypoint API wants
-- 0-1, so values > 1 are scaled here.
-- ============================================================================

local tonumber = tonumber
local C_Map, C_SuperTrack = C_Map, C_SuperTrack

ns.Navigation = ns.Navigation or {}
local Navigation = ns.Navigation

local function ToFraction(value)
    value = tonumber(value)
    if not value then return nil end
    if value > 1 then
        value = value / 100
    end
    return value
end

--- Opens the world map to `mapID` and sets a super-tracked user waypoint when
--- x/y are provided and the map supports waypoints.
---@param mapID number
---@param x number|nil  0-100 or 0-1
---@param y number|nil  0-100 or 0-1
---@return boolean opened
function Navigation:OpenMapPin(mapID, x, y)
    mapID = tonumber(mapID)
    if not mapID or mapID == 0 then return false end

    OpenWorldMap(mapID)

    x = ToFraction(x)
    y = ToFraction(y)
    if x and y and C_Map.CanSetUserWaypointOnMap(mapID) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end

    return true
end

--- Opens OneWoW_Notes to the given NPC, adding it under "Quest Givers" if it is
--- not already a saved note. No-op (returns false) when Notes is not installed.
--- OneWoW_Notes is an optional dependency, so its API presence is checked here.
---@param npcID number
---@param npcInfo table|nil  { name, zone, mapID, coords = { x, y } }
---@return boolean opened
function Navigation:OpenNPC(npcID, npcInfo)
    npcID = tonumber(npcID)
    if not npcID then return false end

    OneWoW:BringUp("OneWoW_Notes")
    local notesAPI = OneWoW_Notes_API
    if not notesAPI then return false end

    npcInfo = npcInfo or {}
    local existing = notesAPI.GetNPC(npcID)
    if not existing then
        notesAPI.AddOrUpdateNPC(npcID, {
            name     = npcInfo.name,
            zone     = npcInfo.zone,
            mapID    = npcInfo.mapID,
            coords   = npcInfo.coords,
            category = "Quest Givers",
        })
    elseif npcInfo.name and npcInfo.name ~= "" then
        local cur = existing.name
        if not cur or cur == "" or cur:find("^NPC %d") then
            notesAPI.AddOrUpdateNPC(npcID, { name = npcInfo.name })
        end
    end
    return notesAPI.OpenNPC(npcID)
end

--- Opens OneWoW_Notes to the given item's note, creating it under the "Quest"
--- category if it does not exist yet. No-op (returns false) when Notes is not
--- installed.
---@param itemID number
---@param itemInfo table|nil  { category }
---@return boolean opened
function Navigation:OpenItemNote(itemID, itemInfo)
    itemID = tonumber(itemID)
    if not itemID then return false end

    -- Full mid-session bring-up (load + lifecycle catch-up); respects soft
    -- opt-out via EnsureLoaded, in which case the Notes API stays nil.
    OneWoW:BringUp("OneWoW_Notes")

    local notesAPI = OneWoW_Notes_API
    if not notesAPI then
        print("|cFFFFD100OneWoW:|r " .. L["NAV_NOTES_UNAVAILABLE"])
        return false
    end

    if not notesAPI.GetItem(itemID) then
        itemInfo = itemInfo or {}
        notesAPI.AddOrUpdateItem(itemID, {
            name     = itemInfo.name,
            link     = itemInfo.link,
            icon     = itemInfo.icon,
            quality  = itemInfo.quality,
            rarity   = itemInfo.rarity or itemInfo.quality,
            category = itemInfo.category or "Quest",
            storage  = itemInfo.storage or "account",
            content  = itemInfo.content,
        })
    end
    return notesAPI.OpenItem(itemID)
end
