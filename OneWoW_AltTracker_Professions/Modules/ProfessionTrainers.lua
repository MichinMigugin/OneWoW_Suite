local addonName, ns = ...

ns.ProfessionTrainers = {}
local Module = ns.ProfessionTrainers

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    if not charData.trainerLocations then
        charData.trainerLocations = {}
    end

    local zoneName = GetZoneText()
    local subZoneName = GetSubZoneText()
    local mapID = C_Map.GetBestMapForUnit("player")

    local position = nil
    if mapID then
        local playerPos = C_Map.GetPlayerMapPosition(mapID, "player")
        if playerPos then
            position = {
                x = playerPos.x,
                y = playerPos.y,
            }
        end
    end

    local location = {
        zoneName = zoneName,
        subZoneName = subZoneName,
        mapID = mapID,
        position = position,
        timestamp = time(),
    }

    table.insert(charData.trainerLocations, location)

    if #charData.trainerLocations > 50 then
        table.remove(charData.trainerLocations, 1)
    end

    charData.lastUpdate = time()

    return true
end

function Module:GetRecentTrainers(charKey, charData, count)
    if not charData or not charData.trainerLocations then
        return {}
    end

    count = count or 10

    local recent = {}
    local startIndex = math.max(1, #charData.trainerLocations - count + 1)

    for i = #charData.trainerLocations, startIndex, -1 do
        table.insert(recent, charData.trainerLocations[i])
    end

    return recent
end

function Module:GetTrainersByZone(charKey, charData, zoneName)
    if not charData or not charData.trainerLocations then
        return {}
    end

    local trainers = {}

    for _, location in ipairs(charData.trainerLocations) do
        if location.zoneName == zoneName then
            table.insert(trainers, location)
        end
    end

    return trainers
end
