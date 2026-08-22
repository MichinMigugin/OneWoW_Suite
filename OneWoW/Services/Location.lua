local _, ns = ...

-- ============================================================================
-- Location
-- ============================================================================
-- The canonical core service for player position, coordinate conversion, user
-- waypoints, and map-space distance. It owns the one thing every consumer used
-- to re-implement: turning a stored coordinate into a super-tracked waypoint
-- with the CanSetUserWaypointOnMap guard actually applied. Trackers and Vendors
-- both omitted that guard and silently failed on maps that refuse waypoints.
--
-- Coordinate formats. The suite stores coordinates two ways: most units
-- (Trackers steps, Notes NPCs, Vendors locations, Merchant scans) store 0-100,
-- while AltTracker stores raw API fractions. Blizzard's map APIs are all 0-1.
-- Callers therefore declare which they hold:
--   ToFraction - tolerant; accepts either and returns 0-1, reading values
--                greater than 1 as percent. For stored data of mixed origin.
--   ToPercent  - strict; multiplies a raw API fraction into 0-100.
-- SetWaypoint takes an explicit opts.format of "percent" or "fraction" so a
-- caller that knows its own storage is never subject to the tolerant guess,
-- which would misread a legitimate sub-1% coordinate. Omitting it falls back to
-- the tolerant reading, which is what mixed-source data (Catalog Navigation)
-- needs.
--
-- Distance works in percent space because that is how radii are authored (a
-- tracker step's waypointRadius and the minimap cutoff are both percent). Map
-- percent is not isotropic, so these distances are an approximation of world
-- range, not a substitute for it.
--
-- Pin rendering is deliberately not here: the Trackers world-map data provider
-- and OneWoW_QoL's map overlays hook Blizzard rendering for unrelated reasons.
-- Instance-entrance and delve-door resolution stays in OneWoW_Catalog's
-- Navigation, which depends on Journal's generated door tables.
-- ============================================================================

local tonumber = tonumber
local sqrt = math.sqrt
local C_Map, C_SuperTrack = C_Map, C_SuperTrack
local UiMapPoint, OpenWorldMap = UiMapPoint, OpenWorldMap

ns.Location = {}
local Location = ns.Location

--- Tolerant conversion to the 0-1 fraction the map APIs expect. Values greater
--- than 1 are read as 0-100 percent.
---@param value number|string|nil
---@return number|nil
function Location.ToFraction(value)
    value = tonumber(value)
    if not value then return nil end
    if value > 1 then
        return value / 100
    end
    return value
end

--- Strict conversion of a raw API fraction into the 0-100 the suite stores.
---@param value number|string|nil
---@return number|nil
function Location.ToPercent(value)
    value = tonumber(value)
    if not value then return nil end
    return value * 100
end

--- Resolves one stored coordinate to a fraction under a declared format.
---@param value number|string|nil
---@param fmt string|nil "percent", "fraction", or nil for the tolerant reading
---@return number|nil
local function Normalize(value, fmt)
    if fmt == "percent" then
        value = tonumber(value)
        return value and (value / 100) or nil
    end
    if fmt == "fraction" then
        return tonumber(value)
    end
    return Location.ToFraction(value)
end

--- The player's current UI map, without the cost of a position lookup.
---@return number|nil
function Location.GetPlayerMapID()
    return C_Map.GetBestMapForUnit("player")
end

--- The player's map and position in 0-100. The mapID is returned on its own
--- when the position is unavailable (loading screens, maps without player
--- coordinates), so a caller that only needs the map still gets it.
---@return number|nil mapID
---@return number|nil x
---@return number|nil y
function Location.GetPlayerLocation()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return mapID end

    local x, y = pos:GetXY()
    if not x or not y then return mapID end

    return mapID, x * 100, y * 100
end

--- Drops a super-tracked user waypoint. x/y accept either coordinate format.
--- Returns false without side effects when the coordinates are incomplete or
--- the map refuses waypoints, so callers must not report success unconditionally.
---@param mapID number|string|nil
---@param x number|string|nil
---@param y number|string|nil
---@param opts table|nil format ("percent"/"fraction"), openMap, superTrack (default true)
---@return boolean set
function Location.SetWaypoint(mapID, x, y, opts)
    mapID = tonumber(mapID)
    if not mapID or mapID == 0 then return false end

    if opts and opts.openMap then
        OpenWorldMap(mapID)
    end

    local fmt = opts and opts.format
    x = Normalize(x, fmt)
    y = Normalize(y, fmt)
    if not (x and y) then return false end
    if not C_Map.CanSetUserWaypointOnMap(mapID) then return false end

    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
    if not opts or opts.superTrack ~= false then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end

    return true
end

--- Straight-line distance between two points in map-percent space.
---@param x1 number|string
---@param y1 number|string
---@param x2 number|string
---@param y2 number|string
---@return number|nil
function Location.DistanceMapPercent(x1, y1, x2, y2)
    x1, y1, x2, y2 = tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2)
    if not (x1 and y1 and x2 and y2) then return nil end

    local dx = x1 - x2
    local dy = y1 - y2
    return sqrt(dx * dx + dy * dy)
end

--- True when two map-percent points are within `radius` percent of each other.
---@param x1 number|string
---@param y1 number|string
---@param x2 number|string
---@param y2 number|string
---@param radius number|string
---@return boolean
function Location.IsWithinRadius(x1, y1, x2, y2, radius)
    local dist = Location.DistanceMapPercent(x1, y1, x2, y2)
    if not dist then return false end
    return dist <= (tonumber(radius) or 0)
end
