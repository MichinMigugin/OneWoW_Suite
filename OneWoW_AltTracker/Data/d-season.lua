local addonName, ns = ...

ns.SeasonData = ns.SeasonData or {}

ns.SeasonData.raids = {
    {key = "dreamrift",  label = "The Dreamrift",        short = "Dream"},
    {key = "voidspire",  label = "The Voidspire",         short = "Void"},
    {key = "marchquel",  label = "March on Quel'Danas",  short = "March"},
}

ns.SeasonData.raidDifficulties = {
    {id = 17, key = "LFR", label = "L"},
    {id = 14, key = "NOR", label = "N"},
    {id = 15, key = "HER", label = "H"},
    {id = 16, key = "MYT", label = "M"},
}

ns.SeasonData.dungeons = {
    {key = "sd1", name = "Magisters' Terrace",     short = "MAGT",  mapID = 558},
    {key = "sd2", name = "Maisara Caverns",         short = "MAIS",  mapID = 560},
    {key = "sd3", name = "Nexus-Point Xenas",       short = "XENA",  mapID = 559},
    {key = "sd4", name = "Windrunner Spire",        short = "WSPIR", mapID = 557},
    {key = "sd5", name = "Algeth'ar Academy",       short = "ACAD",  mapID = 402},
    {key = "sd6", name = "Seat of the Triumvirate", short = "SEAT",  mapID = 239},
    {key = "sd7", name = "Skyreach",                short = "SKY",   mapID = 161},
    {key = "sd8", name = "Pit of Saron",            short = "POS",   mapID = 556},
}

local raidCache = nil

local function BuildRaidCache()
    local cache = {}
    local currentTier = EJ_GetCurrentTier()
    EJ_SelectTier(currentTier)

    local index = 1
    while true do
        local instanceID, name, _, _, buttonImage = EJ_GetInstanceByIndex(index, true)
        if not instanceID then break end

        local mapID = nil
        if EJ_GetInstanceInfo then
            local _, _, _, _, _, _, _, _, _, instanceMapID = EJ_GetInstanceInfo(instanceID)
            if type(instanceMapID) == "number" then
                mapID = instanceMapID
            end
        end

        cache[name] = {
            journalInstanceID = instanceID,
            mapID = mapID,
            name = name,
            buttonImage = buttonImage,
        }
        index = index + 1
    end

    return cache
end

function ns.SeasonData:GetRaidCache()
    if not raidCache then
        raidCache = BuildRaidCache()
    end
    return raidCache
end

function ns.SeasonData:RefreshRaidCache()
    raidCache = BuildRaidCache()
    return raidCache
end

function ns.SeasonData:ResolveRaid(raidEntry)
    local cache = self:GetRaidCache()
    local info = cache[raidEntry.label]
    if info then
        return info.journalInstanceID, info.mapID, info.buttonImage
    end
    return nil, nil, nil
end

function ns.SeasonData:GetRaidEncounters(raidEntry)
    local journalInstanceID = raidEntry.journalInstanceID
    if not journalInstanceID then
        journalInstanceID = self:ResolveRaid(raidEntry)
    end
    if not journalInstanceID then return {} end

    EJ_SelectInstance(journalInstanceID)
    local encounters = {}
    local index = 1
    while true do
        local name, description, journalEncounterID, rootSectionID, link, instanceID, dungeonEncounterID = EJ_GetEncounterInfoByIndex(index, journalInstanceID)
        if not name then break end
        table.insert(encounters, {
            name = name,
            journalEncounterID = journalEncounterID,
            dungeonEncounterID = dungeonEncounterID,
            index = index,
        })
        index = index + 1
    end
    return encounters
end

_G.OneWoW_AltTracker = _G.OneWoW_AltTracker or {}
_G.OneWoW_AltTracker.SeasonData = ns.SeasonData
