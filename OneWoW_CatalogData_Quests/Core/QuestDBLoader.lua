local _, ns = ...

ns.ExternalQuestDB = ns.ExternalQuestDB or {}
ns.ExternalQuestDBByExpansion = ns.ExternalQuestDBByExpansion or {}

local db = ns.ExternalQuestDB
local byExpansion = ns.ExternalQuestDBByExpansion

------------------------------------------------------------
-- EXPANSION NORMALIZATION
------------------------------------------------------------

local BURNING_CRUSADE_MAPS = {
    [94] = true,  -- Eversong Woods
    [95] = true,  -- Ghostlands
    [97] = true,  -- Azuremyst Isle
    [100] = true, -- Hellfire Peninsula
    [102] = true, -- Zangarmarsh
    [103] = true, -- The Exodar
    [104] = true, -- Shadowmoon Valley
    [105] = true, -- Blade's Edge Mountains
    [106] = true, -- Bloodmyst Isle
    [107] = true, -- Nagrand
    [108] = true, -- Terokkar Forest
    [109] = true, -- Netherstorm
    [110] = true, -- Silvermoon City
    [111] = true, -- Shattrath City
    [122] = true, -- Isle of Quel'Danas
}

local BURNING_CRUSADE_ZONES = {
    [3430] = true,
    [3431] = true,
    [3433] = true,
    [3483] = true,
    [3518] = true,
    [3519] = true,
    [3520] = true,
    [3521] = true,
    [3522] = true,
    [3523] = true,
    [3524] = true,
    [3525] = true,
    [3703] = true,
    [4080] = true,
    [6455] = true,
    [6456] = true,
}

local function GetQuestMapID(questData)
    if type(questData.mapID) == "number"
        and questData.mapID ~= 0
    then
        return questData.mapID
    end

    if type(questData.coords) == "table"
        and type(questData.coords.mapID) == "number"
        and questData.coords.mapID ~= 0
    then
        return questData.coords.mapID
    end

    if type(questData.starts) == "table"
        and type(questData.starts[1]) == "table"
        and type(questData.starts[1].mapID) == "number"
        and questData.starts[1].mapID ~= 0
    then
        return questData.starts[1].mapID
    end

    if type(questData.ends) == "table"
        and type(questData.ends[1]) == "table"
        and type(questData.ends[1].mapID) == "number"
        and questData.ends[1].mapID ~= 0
    then
        return questData.ends[1].mapID
    end

    return nil
end

local function IsBurningCrusadeQuest(questData)
    local mapID = GetQuestMapID(questData)

    if mapID then
        return BURNING_CRUSADE_MAPS[mapID] == true
    end

    return
        type(questData.zoneID) == "number"
        and BURNING_CRUSADE_ZONES[questData.zoneID] == true
end

local function ResolveExpansionID(questData)
    local expansionID = questData.expansion

    if type(expansionID) == "number"
        and expansionID <= 2
        and IsBurningCrusadeQuest(questData)
    then
        return 1
    end

    return expansionID
end

------------------------------------------------------------
-- MERGE HELPER
------------------------------------------------------------

local loadedDBCount = 0

local function MergeDB(sourceName, source)
    if type(source) ~= "table" then
        return 0
    end

    local added = 0

    for questID, questData in pairs(source) do
        if type(questID) == "number"
            and type(questData) == "table"
        then
            local expansionID = ResolveExpansionID(questData)

            if type(expansionID) == "number" then
                questData.expansion = expansionID
            end

            db[questID] = questData

            if type(expansionID) == "number" then
                byExpansion[expansionID] =
                    byExpansion[expansionID] or {}
                byExpansion[expansionID][questID] = questData
            end

            added = added + 1
        end
    end

    return added
end

------------------------------------------------------------
-- AUTO-DETECT QUEST DBS
------------------------------------------------------------

for globalName, globalValue in pairs(_G) do
    if type(globalName) == "string"
        and type(globalValue) == "table"
    then
        ----------------------------------------------------
        -- Match scraper DB globals
        ----------------------------------------------------

        if globalName:match("^QuestDB_")
            or globalName:match("^OneWoW_QuestDB_")
        then
            if MergeDB(globalName, globalValue) > 0 then
                loadedDBCount = loadedDBCount + 1
            end
        end
    end
end

------------------------------------------------------------
-- FINAL COUNT
------------------------------------------------------------

local total = 0

for _ in pairs(db) do
    total = total + 1
end

print(
    string.format(
        "|cff00ff98OneWoW|r Loaded %d QuestDBs (%d quests)",
        loadedDBCount,
        total
    )
)
