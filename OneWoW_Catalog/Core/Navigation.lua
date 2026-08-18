local _, ns = ...
local L = ns.L

-- ============================================================================
-- Navigation
-- ============================================================================
-- Shared map navigation for the Catalog: opens the world map to a zone and, when
-- coordinates are known, drops a super-tracked user waypoint.
--
-- Quest/vendor coords are stored 0-100; the waypoint API wants 0-1, so values
-- > 1 are scaled in OpenMapPin. Journal doors arrive as continent Map.db2 +
-- world XY from generated JournalInstanceEntrances and are converted here.
-- ============================================================================

local tonumber = tonumber
local ipairs = ipairs
local C_Map, C_SuperTrack, C_EncounterJournal = C_Map, C_SuperTrack, C_EncounterJournal
local CreateVector2D, OpenWorldMap, UnitFactionGroup = CreateVector2D, OpenWorldMap, UnitFactionGroup

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

local function PlayerFactionID()
    local group = UnitFactionGroup("player")
    if group == "Alliance" then
        return 1
    end
    if group == "Horde" then
        return 0
    end
    return -1
end

--- Pick faction-matching door rows. Alliance=1, Horde=0, -1 = any.
---@param entrances table
---@return table
local function FactionCandidates(entrances)
    local faction = PlayerFactionID()
    if faction >= 0 then
        local matched = {}
        for _, row in ipairs(entrances) do
            if row.faction == faction then
                matched[#matched + 1] = row
            end
        end
        if matched[1] then
            return matched
        end
    end
    local any = {}
    for _, row in ipairs(entrances) do
        if row.faction == -1 then
            any[#any + 1] = row
        end
    end
    if any[1] then
        return any
    end
    return entrances
end

--- Convert continent Map.db2 + world XY into a UiMap + 0-1 position.
--- Drills Continent -> Zone when the child at that point is a zone (not the dungeon interior).
---@param continentID number
---@param worldX number
---@param worldY number
---@return number|nil uiMapID
---@return number|nil x
---@return number|nil y
local function ResolveWorldPos(continentID, worldX, worldY)
    local worldPos = CreateVector2D(worldX, worldY)
    local uiMapID, mapPos = C_Map.GetMapPosFromWorldPos(continentID, worldPos)
    if not uiMapID or not mapPos then
        return nil
    end

    local info = C_Map.GetMapInfo(uiMapID)
    if info and info.mapType and info.mapType < Enum.UIMapType.Zone then
        local child = C_Map.GetMapInfoAtPosition(uiMapID, mapPos.x, mapPos.y)
        local childID = child and child.mapID
        local childType = child and child.mapType
        if childID and childID ~= uiMapID
                and (childType == Enum.UIMapType.Zone or childType == Enum.UIMapType.Micro) then
            local zoneID, zonePos = C_Map.GetMapPosFromWorldPos(continentID, worldPos, childID)
            if zoneID and zonePos then
                uiMapID, mapPos = zoneID, zonePos
            end
        end
    end
    return uiMapID, mapPos.x, mapPos.y
end

---@param uiMapID number
---@return number
local function MapPinScore(uiMapID)
    local info = C_Map.GetMapInfo(uiMapID)
    local mapType = info and info.mapType or 0
    local score = 0
    if mapType == Enum.UIMapType.Zone then
        score = score + 20
    elseif mapType == Enum.UIMapType.Continent then
        score = score + 5
    end
    if C_Map.CanSetUserWaypointOnMap(uiMapID) then
        score = score + 10
    end
    return score
end

---@param uiMapID number
---@param instanceID number
---@return boolean
local function SuperTrackDungeonEntrance(uiMapID, instanceID)
    local list = C_EncounterJournal.GetDungeonEntrancesForMap(uiMapID)
    if not list then
        return false
    end
    for i = 1, #list do
        local info = list[i]
        if info.journalInstanceID == instanceID then
            C_SuperTrack.SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.AreaPOI, info.areaPoiID)
            return true
        end
    end
    return false
end

--- Opens the world map on an instance entrance from generated JournalInstanceEntrance rows.
--- Converts world XYZ / continent MapID to a UiMap waypoint, and super-tracks the official
--- dungeon/raid pin when the client exposes it on that map.
---@param instanceID number
---@param entrances table|nil
---@return boolean opened
function Navigation:OpenInstanceEntrance(instanceID, entrances)
    instanceID = tonumber(instanceID)
    if not instanceID or not entrances or not entrances[1] then
        return false
    end

    local bestScore, bestMapID, bestX, bestY, bestContinent = -1, nil, nil, nil, -1
    for _, row in ipairs(FactionCandidates(entrances)) do
        local uiMapID, x, y = ResolveWorldPos(row.mapID, row.x, row.y)
        if uiMapID then
            local score = MapPinScore(uiMapID)
            if score > bestScore or (score == bestScore and row.mapID > bestContinent) then
                bestScore, bestMapID, bestX, bestY, bestContinent = score, uiMapID, x, y, row.mapID
            end
        end
    end
    if not bestMapID then
        return false
    end

    -- User waypoint is the visible marker (quests use the same path). Official
    -- dungeon/raid AreaPOI super-track is a nicer arrow when the client has one.
    self:OpenMapPin(bestMapID, bestX, bestY)
    if SuperTrackDungeonEntrance(bestMapID, instanceID) then
        return true
    end
    local parent = C_Map.GetMapInfo(bestMapID)
    local parentID = parent and parent.parentMapID
    if parentID and parentID ~= 0 then
        SuperTrackDungeonEntrance(parentID, instanceID)
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
