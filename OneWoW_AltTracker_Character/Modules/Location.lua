local _, ns = ...

ns.Location = {}
local Module = ns.Location

--- Propagates a freshly captured hearth map to every other character bound to
--- the same location. An identical bind string means the same inn, which means
--- the same map. Only fills characters that have no map of their own yet, so a
--- character's own (potentially more accurate) fix is never overwritten.
---@param sourceKey string the character whose map we just captured
---@param bind string the bind-location string to match against
---@param mapID number
---@param x number|nil
---@param y number|nil
local function PropagateHearthMap(sourceKey, bind, mapID, x, y)
    for key, data in pairs(OneWoW_AltTracker_Character_DB.characters) do
        if key ~= sourceKey and data.location
            and data.location.bindLocation == bind
            and not data.location.hearthMapID then
            data.location.hearthMapID = mapID
            data.location.hearthX = x
            data.location.hearthY = y
        end
    end
end

--- Collects the character's current location plus an opportunistic hearthstone
--- map fix.
---
--- The hearthstone exposes no map: GetBindLocation() returns only a localized
--- string. So when the character is physically standing at their bind location
--- (the bind string matches the current sub/zone), the current map *is* the
--- hearth's map — capture it, and share it with same-bind alts. Otherwise carry
--- the previous fix forward, but only while the bind string is unchanged: a
--- re-bind drops the stale map so it never points at the old location.
---@param charKey string|nil
---@param charData table|nil
---@return boolean collected
function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local prev = charData.location
    local locationData = {}

    locationData.zone = GetZoneText() or ""
    locationData.subzone = GetSubZoneText() or ""
    locationData.bindLocation = GetBindLocation() or ""

    local mapID = C_Map.GetBestMapForUnit("player")
    local position
    if mapID then
        locationData.mapID = mapID

        position = C_Map.GetPlayerMapPosition(mapID, "player")
        if position then
            locationData.x = position.x
            locationData.y = position.y
        end
    end

    local bind = locationData.bindLocation
    if mapID and bind ~= "" and
        (bind == locationData.subzone or bind == locationData.zone or bind == GetMinimapZoneText()) then
        locationData.hearthMapID = mapID
        if position then
            locationData.hearthX = position.x
            locationData.hearthY = position.y
        end
        PropagateHearthMap(charKey, bind, mapID, locationData.hearthX, locationData.hearthY)
    elseif prev and prev.hearthMapID and prev.bindLocation == bind then
        locationData.hearthMapID = prev.hearthMapID
        locationData.hearthX = prev.hearthX
        locationData.hearthY = prev.hearthY
    end

    charData.location = locationData

    return true
end
