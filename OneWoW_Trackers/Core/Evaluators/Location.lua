local _, ns = ...

local E = ns.TrackerEvaluators
local Location = OneWoW.Location
local tonumber = tonumber
local ipairs = ipairs

E.Register("location", function(op)
    local mapID = tonumber(op.mapID)
    if mapID then
        local currentMap = Location.GetPlayerMapID()
        return (currentMap == mapID) and 1 or 0, 1
    end
end)

E.Register("coordinates", function(op)
    local mapID = tonumber(op.mapID)
    local tx = tonumber(op.x)
    local ty = tonumber(op.y)
    local radius = tonumber(op.radius) or 15
    if not (mapID and tx and ty) then return end

    local currentMap, px, py = Location.GetPlayerLocation()
    if currentMap == mapID and px then
        return Location.IsWithinRadius(px, py, tx, ty, radius) and 1 or 0, 1
    end
    return 0, 1
end)

E.Register("exploration", function(op)
    local areaID = tonumber(op.areaID)
    if not areaID then return end
    local mapID = Location.GetPlayerMapID()
    if mapID then
        local explored = C_MapExplorationInfo.GetExploredMapTextures(mapID)
        if explored then
            for _, info in ipairs(explored) do
                if info.textureWidth and info.textureHeight then
                    return 1, 1
                end
            end
        end
    end
    return 0, 1
end)
