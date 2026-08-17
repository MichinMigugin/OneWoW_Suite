local _, ns = ...

local E = ns.TrackerEvaluators
local tonumber = tonumber
local ipairs = ipairs
local math_sqrt = math.sqrt

E.Register("location", function(op)
    local mapID = tonumber(op.mapID)
    if mapID then
        local currentMap = C_Map.GetBestMapForUnit("player")
        return (currentMap == mapID) and 1 or 0, 1
    end
end)

E.Register("coordinates", function(op)
    local mapID = tonumber(op.mapID)
    local tx = tonumber(op.x)
    local ty = tonumber(op.y)
    local radius = tonumber(op.radius) or 15
    if not (mapID and tx and ty) then return end
    local currentMap = C_Map.GetBestMapForUnit("player")
    if currentMap == mapID then
        local pos = C_Map.GetPlayerMapPosition(currentMap, "player")
        if pos then
            local px, py = pos:GetXY()
            px = px * 100
            py = py * 100
            local dx = px - tx
            local dy = py - ty
            local dist = math_sqrt(dx * dx + dy * dy)
            return (dist <= radius) and 1 or 0, 1
        end
    end
    return 0, 1
end)

E.Register("exploration", function(op)
    local areaID = tonumber(op.areaID)
    if not areaID then return end
    local mapID = C_Map.GetBestMapForUnit("player")
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
