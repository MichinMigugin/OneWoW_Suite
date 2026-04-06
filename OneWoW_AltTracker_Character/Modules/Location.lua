local addonName, ns = ...

ns.Location = {}
local Module = ns.Location

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local locationData = {}

    locationData.zone = GetZoneText() or ""
    locationData.subzone = GetSubZoneText() or ""
    locationData.bindLocation = GetBindLocation() or ""

    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then
        locationData.mapID = mapID

        local position = C_Map.GetPlayerMapPosition(mapID, "player")
        if position then
            locationData.x = position.x
            locationData.y = position.y
        end
    end

    charData.location = locationData

    return true
end
