local _, ns = ...

ns.SeasonData = ns.SeasonData or {}

ns.SeasonData.raids = {
    {key = "venomous",   label = "The Venomous Abyss",   short = "Abyss"},
    {key = "tidebound",  label = "The Tidebound Grotto", short = "Tide"},
}

ns.SeasonData.raidDifficulties = {
    {id = 17, key = "LFR", label = "L"},
    {id = 14, key = "NOR", label = "N"},
    {id = 15, key = "HER", label = "H"},
    {id = 16, key = "MYT", label = "M"},
}

ns.SeasonData.dungeons = {
    {key = "sd1", name = "Altar of Fangs",          short = "FANG",  mapID = 0},
    {key = "sd2", name = "Murder Row",              short = "MURD",  mapID = 0},
    {key = "sd3", name = "Den of Nalorakk",         short = "NALO",  mapID = 0},
    {key = "sd4", name = "The Blinding Vale",       short = "VALE",  mapID = 0},
    {key = "sd5", name = "Voidscar Arena",          short = "VOID",  mapID = 0},
    {key = "sd6", name = "Ruby Life Pools",         short = "RLP",   mapID = 399},
    {key = "sd7", name = "Kings' Rest",             short = "KR",    mapID = 249},
    {key = "sd8", name = "Temple of Sethraliss",    short = "TOS",   mapID = 250},
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

local function ChallengeNamesMatch(a, b)
    if a == b then return true end
    if not a or not b then return false end
    return (a:gsub("^The ", "")) == (b:gsub("^The ", ""))
end

--- Fill `dung.mapID` from `C_ChallengeMode.GetMapTable()` when the hardcoded
--- ID is missing or stale. Matches `dung.name` to `GetMapUIInfo`.
---@param dung table
---@return number|nil mapID
function ns.SeasonData:ResolveDungeonMapID(dung)
    if dung.mapID and dung.mapID > 0 then
        local name = C_ChallengeMode.GetMapUIInfo(dung.mapID)
        if name then
            return dung.mapID
        end
    end
    local mapTable = C_ChallengeMode.GetMapTable()
    for _, id in ipairs(mapTable) do
        local name = C_ChallengeMode.GetMapUIInfo(id)
        if ChallengeNamesMatch(name, dung.name) then
            dung.mapID = id
            return id
        end
    end
    return dung.mapID
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
        local name, _, journalEncounterID, _, _, _, dungeonEncounterID = EJ_GetEncounterInfoByIndex(index, journalInstanceID)
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

-- EXPANSION_SEASON_NAME uses a per-expansion ordinal (1, 2, 3…), not the
-- content season UID from C_SeasonInfo.GetCurrentDisplaySeasonID.
local MAX_EXPANSION_SEASON_ORDINAL = 12

---@return number|nil
local function SeasonOrdinalFromAPI()
    local displayNum = C_MythicPlus.GetCurrentSeasonValues()
    if displayNum and displayNum > 0 and displayNum <= MAX_EXPANSION_SEASON_ORDINAL then
        return displayNum
    end
    local uiSeason = C_MythicPlus.GetCurrentUIDisplaySeason()
    if uiSeason and uiSeason > 0 and uiSeason <= MAX_EXPANSION_SEASON_ORDINAL then
        return uiSeason
    end
    return nil
end

--- Per-expansion season ordinal from live Mythic+ APIs.
---@return number|nil
function ns.SeasonData:GetCurrentSeasonNumber()
    local ordinal = SeasonOrdinalFromAPI()
    if ordinal then
        return ordinal
    end
    if C_MythicPlus.GetCurrentSeason() == -1 then
        C_MythicPlus.RequestMapInfo()
        return SeasonOrdinalFromAPI()
    end
    return nil
end

--- Localized tooltip-style label (`EXPANSION_SEASON_NAME`), e.g. "Midnight Season 2".
---@return string|nil
function ns.SeasonData:GetCurrentSeasonLabel()
    local seasonNum = self:GetCurrentSeasonNumber()
    if not seasonNum then
        return nil
    end
    local expName = OneWoW:GetExpansionName(LE_EXPANSION_LEVEL_CURRENT)
    if not expName then
        local displayExpID = C_SeasonInfo.GetCurrentDisplaySeasonExpansion()
        expName = displayExpID and OneWoW:GetExpansionName(displayExpID)
    end
    if not expName then
        return nil
    end
    return EXPANSION_SEASON_NAME:format(expName, seasonNum)
end
