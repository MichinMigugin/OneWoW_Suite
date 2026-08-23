local _, ns = ...

-- ============================================================================
-- QuestData
-- ============================================================================
-- Serves a merged view of the quest database to the Catalog quest tab:
--   * static  - shipped, pre-cleaned Wowhead DBs (ns.ExternalQuestDB)
--   * runtime - live in-game captures in SavedVariables (ns:GetDB().quests)
-- Runtime fields are merged over static per-quest; explicit "cleared" markers
-- let bad live captures self-heal. Display hygiene (chrome/junk filtering) runs
-- here as a backstop even though shipped data is already cleaned offline by
-- db2_exports/quest_tools/clean_questdb.lua.
-- ============================================================================

local pairs, ipairs, next, type = pairs, ipairs, next, type
local tonumber, tostring = tonumber, tostring
local tinsert, tremove, sort, wipe = tinsert, tremove, sort, wipe
local time, C_Timer = time, C_Timer

local QuestData = {}
ns.QuestData = QuestData

------------------------------------------------------------
-- DATABASE ACCESS
------------------------------------------------------------

local function GetRuntimeDB()
    return ns:GetDB()
end

local function GetExternalDB()
    return ns.ExternalQuestDB
end

local function GetExternalExpansionDB(expansionID)
    return ns.ExternalQuestDBByExpansion[expansionID]
end

------------------------------------------------------------
-- EXPANSIONS
------------------------------------------------------------

local EXPANSIONS = {
    [0]  = "Classic",
    [1]  = "Burning Crusade",
    [2]  = "Wrath of the Lich King",
    [3]  = "Cataclysm",
    [4]  = "Mists of Pandaria",
    [5]  = "Warlords of Draenor",
    [6]  = "Legion",
    [7]  = "Battle for Azeroth",
    [8]  = "Shadowlands",
    [9]  = "Dragonflight",
    [10] = "The War Within",
    [11] = "Midnight",
}

local EXPANSION_SHORT = {
    [0]  = "Classic",
    [1]  = "BC",
    [2]  = "Wrath",
    [3]  = "Cata",
    [4]  = "MoP",
    [5]  = "WoD",
    [6]  = "Legion",
    [7]  = "BFA",
    [8]  = "SL",
    [9]  = "DF",
    [10] = "TWW",
    [11] = "Midnight",
}

local allQuestsCache = nil
local expansionQuestsCache = {}
local sortedQuestSourceCache = {}
local sortedQuestCache = {}
local sortedQuestCacheOrder = {}
local filterValuesCache = nil
local questNPCIndex = nil
local questSearchBlobCache = {}
local mapNameCache = {}
local refreshQueued = false
local SORTED_QUEST_CACHE_LIMIT = 40

------------------------------------------------------------
-- FILTER HELPERS
------------------------------------------------------------

local HIDDEN_CATEGORIES = {
    test = true,
    hidden = true,
}

local HIDDEN_FLAGS = {
    deprecated = true,
    internal = true,
    unobtainable = true,
    removed = true,
}

local LEGACY_QUEST_TYPE_CATEGORIES = {
    normal = "standard",
    world = "world",
    worldquest = "world",
    dungeon = "dungeon",
    raid = "raid",
    group = "group",
    pvp = "pvp",
    professions = "profession",
    profession = "profession",
}

local FREQUENCY_CATEGORIES = {
    daily = true,
    weekly = true,
    repeatable = true,
}

local function HasDNTMarker(text)
    return text
        and tostring(text):upper():find("DNT", 1, true) ~= nil
end

local function HasNthMarker(text)
    if not text then
        return false
    end

    return tostring(text):upper():find("%f[%w]NTH%f[%W]") ~= nil
end

local function HasPHMarker(text)
    return text
        and (
            tostring(text):upper():find("[PH]", 1, true) ~= nil
            or tostring(text):upper():find("(PH)", 1, true) ~= nil
        )
end

local function HasNYIMarker(text)
    return text
        and tostring(text):upper():find("[NYI]", 1, true) ~= nil
end

local function HasRemovedMarker(text)
    if not text then
        return false
    end

    text = tostring(text):upper()
    text = text:gsub("^%s+", ""):gsub("%s+$", "")

    return text:find("[REMOVED]", 1, true) ~= nil
        or text == "REMOVED"
end

local function HasBracketedDevMarker(text)
    if not text then
        return false
    end

    text = tostring(text):gsub("^%s+", ""):gsub("%s+$", "")

    return text:find("%b[]") ~= nil
end

local function StripWoWTextFormatting(text)
    if not text then
        return nil
    end

    text = tostring(text)
    text = text:gsub("|[cC]%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|[rR]", "")
    text = text:gsub("||", "|")

    return text
end

local function CleanWowheadText(text)
    if not text then
        return nil
    end

    text = StripWoWTextFormatting(text)
    if not text then
        return nil
    end

    text = text:gsub(
        "See if you've already completed this by typing:%s*/run%s+print%(%s*C_QuestLog%.IsQuestFlaggedCompleted%(%s*%d+%s*%)%s*%)",
        ""
    )

    text = text:gsub(
        "Gather info with the Wowhead Client%s*Download Now%s*Help keep the database up to date!?",
        ""
    )

    text = text:gsub(
        "Accept this quest to record its description and rewards%.?",
        ""
    )

    text = text:gsub(
        "^Community Feasts are one of the main features.-Getting a soup all the way to Legendary%s*",
        ""
    )

    if text:find("Progress:", 1, true)
        and text:find("[\128-\255]")
    then
        text = text:gsub("%s*Progress:.*$", "")
    end

    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    text = text:gsub("%s%s+", " ")

    if text == "" then
        return nil
    end

    return text
end

local function HasWowheadChrome(text)
    if not text then
        return false
    end

    text = tostring(text)

    return text:find("See if you've already completed this by typing:", 1, true) ~= nil
        or text:find("C_QuestLog.IsQuestFlaggedCompleted", 1, true) ~= nil
        or text:find("Wowhead Client", 1, true) ~= nil
        or text:find("Download Now", 1, true) ~= nil
        or text:find("Help keep the database up to date", 1, true) ~= nil
        or text:find("Accept this quest to record its description and rewards", 1, true) ~= nil
end

local function HasPlaceholderMarker(text)
    return text
        and tostring(text):lower():find("placeholder", 1, true) ~= nil
end

local
    function IsInternalName(name, questID)
        if not name then
            return true
        end

        name = tostring(name):gsub("^%s+", ""):gsub("%s+$", "")
        local lowerName = name:lower()

        if name == "" then
            return true
        end

        -- Fake scanner junk
        if name:match("^Level%s+%d+$") then
            return true
        end

        if lowerName:find("reward test", 1, true) then
            return true
        end

        if lowerName:find("rated pvp incentive", 1, true) then
            return true
        end

        if lowerName:find("tracking quest", 1, true) then
            return true
        end

        if lowerName:find("reward quest", 1, true) then
            return true
        end

        if lowerName:find("quest start", 1, true) then
            return true
        end

        if lowerName:find("navigation playtest", 1, true) then
            return true
        end

        if lowerName:find(":]p", 1, true) then
            return true
        end

        if lowerName:find("test case", 1, true)
            or lowerName:find("test quest", 1, true)
            or lowerName:find("nav test", 1, true)
            or lowerName:find("test currency", 1, true)
            or lowerName:find("testing", 1, true)
            or lowerName:find("do not use", 1, true)
            or lowerName:find("event tracking", 1, true)
            or lowerName:find("unused", 1, true)
            or lowerName:find("vignette", 1, true)
            or lowerName:find("capstone", 1, true)
        then
            return true
        end

        if lowerName:find("%f[%w]poi%f[%W]") then
            return true
        end

        if lowerName:find("bonus objective", 1, true)
            and tonumber(questID) ~= 71153
        then
            return true
        end

        if HasPlaceholderMarker(name) then
            return true
        end

        if HasDNTMarker(name) then
            return true
        end

        if HasNthMarker(name) then
            return true
        end

        if HasPHMarker(name) then
            return true
        end

        if HasNYIMarker(name) then
            return true
        end

        if HasRemovedMarker(name) then
            return true
        end

        if HasBracketedDevMarker(name) then
            return true
        end

        -- Generic placeholder junk
        if name == "?" or name == "??" or lowerName == "zz" or lowerName == "test" then
            return true
        end

        return false
    end

local function HasDisplayQuestText(text)
    if not text then
        return false
    end

    text = tostring(text):gsub("^%s+", ""):gsub("%s+$", "")

    if text == "" then
        return false
    end

    if text == "Accept this quest to record its description and rewards." then
        return false
    end

    if HasWowheadChrome(text) then
        return false
    end

    return true
end

local function HasDisplayObjectives(quest)
    if not quest then
        return false
    end

    if HasDisplayQuestText(quest.objectivesText) then
        return true
    end

    if quest.objectives then
        for _, objective in ipairs(quest.objectives) do
            if HasDisplayQuestText(objective) then
                return true
            end
        end
    end

    return false
end

local function HasUsefulSparseChainData(quest, values)
    if not quest or not values then
        return false
    end

    local questID = tonumber(quest.id)

    for _, value in ipairs(values) do
        local linkedID = tonumber(value)
        if not linkedID or linkedID ~= questID then
            return true
        end
    end

    return false
end

local function HasUsefulSparseQuestData(quest)
    if not quest then
        return false
    end

    if (quest.rewardGold and quest.rewardGold > 0)
        or (quest.rewardXP and quest.rewardXP > 0)
        or (quest.rewardItems and #quest.rewardItems > 0)
        or (quest.rewardChoices and #quest.rewardChoices > 0)
        or (quest.rewardCurrencies and #quest.rewardCurrencies > 0)
    then
        return true
    end

    if quest.coords
        and quest.coords.mapID
        and quest.coords.mapID ~= 0
    then
        return true
    end

    if quest.mapID and quest.mapID ~= 0 then
        return true
    end

    if HasUsefulSparseChainData(quest, quest.storyline)
        or HasUsefulSparseChainData(quest, quest.series)
    then
        return true
    end

    return false
end

local function HasValue(tbl, value)
    if not tbl then
        return false
    end

    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end

    return false
end

local function HasCategory(quest, category)
    return HasValue(quest.categories, category)
end

local function HasFlag(quest, flag)
    return HasValue(quest.flags, flag)
end

local function HasAnyValue(tbl)
    return tbl and #tbl > 0
end

local function HasNormalizedValue(tbl, value)
    if not tbl or not value then
        return false
    end

    value = tostring(value):lower()

    for _, v in ipairs(tbl) do
        if tostring(v):lower() == value then
            return true
        end
    end

    return false
end

local function NormalizeFactionValue(value)
    if value == nil or tostring(value) == "" then
        return nil
    end

    value = tostring(value):lower()
    if value == "none" or value == "both" or value == "neutral" then
        return "neutral"
    end

    return value
end

local function AddValue(tbl, value)
    if value and not HasValue(tbl, value) then
        tinsert(tbl, value)
    end
end

local function RemoveValue(tbl, value)
    for index = #tbl, 1, -1 do
        if tbl[index] == value then
            tremove(tbl, index)
        end
    end
end

local function GetMapName(mapID)
    if not mapID then
        return nil
    end

    if mapNameCache[mapID] ~= nil then
        return mapNameCache[mapID] or nil
    end

    local mapInfo = C_Map.GetMapInfo(mapID)

    local mapName =
        mapInfo
        and mapInfo.name
        or false

    mapNameCache[mapID] = mapName

    return mapName or nil
end

local function QueueQuestUIRefresh()
    if refreshQueued then
        return
    end

    refreshQueued = true

    C_Timer.After(0.1, function()
        refreshQueued = false

        -- RefreshQuestsList is created lazily when the Catalog quest tab is
        -- first opened, so it may legitimately not exist yet.
        if OneWoW_Catalog_API then
            OneWoW_Catalog_API.RefreshQuestsList()
        end
    end)
end

local function GetRewardItemID(rewardItem)
    if type(rewardItem) == "number" then
        return rewardItem
    end

    if type(rewardItem) == "table" then
        return rewardItem.itemID or rewardItem.id
    end

    return nil
end

-- Catalog owns the cross-unit item-name cache; delegate to its public API so we
-- never touch OneWoW_Catalog_DB directly. Both no-op gracefully when Catalog is
-- not loaded.
local function GetCatalogCachedItemName(itemID)
    if OneWoW_Catalog_API then
        return OneWoW_Catalog_API.GetCachedItemName(itemID)
    end
    return nil
end

local function RememberCatalogItemName(itemID, itemName)
    if OneWoW_Catalog_API then
        return OneWoW_Catalog_API.RememberItemName(itemID, itemName)
    end
    return false
end

local function GetCachedItemNameLower(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end

    local itemName = GetCatalogCachedItemName(itemID)

    return itemName and tostring(itemName):lower() or nil
end

local function QuestRewardItemsMatchSearch(quest, search)
    if not quest or not search or search == "" then
        return false
    end

    local itemSearch = search:gsub("^item:%s*", "")
    if itemSearch == "" then
        return false
    end

    local numericSearch = tonumber(itemSearch)

    local function checkList(items)
        if not items then
            return false
        end

        for _, rewardItem in ipairs(items) do
            local itemID = GetRewardItemID(rewardItem)
            if itemID then
                if numericSearch and tonumber(itemID) == numericSearch then
                    return true
                end

                local itemName = GetCachedItemNameLower(itemID)
                if itemName and itemName:find(itemSearch, 1, true) then
                    return true
                end
            end
        end

        return false
    end

    return checkList(quest.rewardItems)
        or checkList(quest.rewardChoices)
end

local GetQuestSearchBlob

local function ParseQuestSearchTerms(searchText)
    local terms = {}
    local text = tostring(searchText or "")
    local length = #text
    local index = 1
    local stopWords = {
        a = true,
        an = true,
        ["and"] = true,
        ["at"] = true,
        ["by"] = true,
        ["for"] = true,
        ["from"] = true,
        ["in"] = true,
        ["of"] = true,
        ["on"] = true,
        ["or"] = true,
        ["the"] = true,
        ["to"] = true,
        ["with"] = true,
    }

    while index <= length do
        while index <= length and text:sub(index, index):match("%s") do
            index = index + 1
        end

        if index > length then
            break
        end

        local quoted = false
        local value

        if text:sub(index, index) == "\"" then
            quoted = true
            local closeIndex = text:find("\"", index + 1, true)
            if closeIndex then
                value = text:sub(index + 1, closeIndex - 1)
                index = closeIndex + 1
            else
                value = text:sub(index + 1)
                index = length + 1
            end
        else
            local nextSpace = text:find("%s", index)
            if nextSpace then
                value = text:sub(index, nextSpace - 1)
                index = nextSpace + 1
            else
                value = text:sub(index)
                index = length + 1
            end
        end

        value = value and value:gsub("^%s+", ""):gsub("%s+$", ""):lower()
        if value and value ~= "" and not stopWords[value] then
            tinsert(terms, {
                text = value,
                quoted = quoted,
                wordExact = quoted and value:find("%s") == nil and value:match("^%w+$") ~= nil,
            })
        end
    end

    return terms
end

local function TextMatchesSearchTerm(text, term)
    if not text or not term or not term.text or term.text == "" then
        return false
    end

    if term.wordExact then
        return text:find("%f[%w]" .. term.text .. "%f[%W]") ~= nil
    end

    return text:find(term.text, 1, true) ~= nil
end

local function QuestMatchesSearchTerms(quest, terms)
    if not terms or #terms == 0 then
        return true
    end

    local blob = GetQuestSearchBlob(quest)

    for _, term in ipairs(terms) do
        if not TextMatchesSearchTerm(blob, term)
            and not QuestRewardItemsMatchSearch(quest, term.text)
        then
            return false
        end
    end

    return true
end

local function CopyQuestArray(source)
    local copy = {}

    for i = 1, #source do
        copy[i] = source[i]
    end

    return copy
end

local function ClearSortedQuestCache()
    wipe(sortedQuestCache)
    wipe(sortedQuestCacheOrder)
end

local function ClearQuestDerivedCaches()
    ClearSortedQuestCache()
    wipe(sortedQuestSourceCache)
    wipe(questSearchBlobCache)
    filterValuesCache = nil
    questNPCIndex = nil
end

local function CachePart(value)
    if value == nil then
        return ""
    end

    return tostring(value)
end

local function BuildSortedQuestCacheKey(
    expansionFilter,
    zoneFilter,
    typeFilter,
    questTypeFilter,
    searchText,
    advancedFilters
)
    advancedFilters = advancedFilters or {}

    return table.concat({
        CachePart(expansionFilter),
        CachePart(zoneFilter),
        CachePart(typeFilter),
        CachePart(questTypeFilter),
        CachePart(searchText and tostring(searchText):lower() or ""),
        CachePart(advancedFilters.category),
        CachePart(advancedFilters.flag),
        CachePart(advancedFilters.profession),
        CachePart(advancedFilters.class),
        CachePart(advancedFilters.race),
        CachePart(advancedFilters.faction),
        CachePart(advancedFilters.story),
        CachePart(advancedFilters.runtime),
        CachePart(advancedFilters.npcID),
    }, "\031")
end

--- True if npcID is this quest's giver or turn-in (legacy fields or starts/ends lists).
local function QuestAssociatedWithNPC(quest, npcID)
    npcID = tonumber(npcID)
    if not quest or not npcID then
        return false
    end

    if tonumber(quest.questGiverID) == npcID or tonumber(quest.questTurnInID) == npcID then
        return true
    end

    local function listHasNPC(list)
        if not list then
            return false
        end
        for _, entry in ipairs(list) do
            if type(entry) == "table" and tonumber(entry.npcID) == npcID then
                return true
            end
        end
        return false
    end

    return listHasNPC(quest.starts) or listHasNPC(quest.ends)
end

local function RememberSortedQuestCache(key, results)
    if sortedQuestCache[key] then
        sortedQuestCache[key] = CopyQuestArray(results)
        return
    end

    sortedQuestCache[key] = CopyQuestArray(results)
    tinsert(sortedQuestCacheOrder, key)

    while #sortedQuestCacheOrder > SORTED_QUEST_CACHE_LIMIT do
        local expiredKey = tremove(sortedQuestCacheOrder, 1)
        sortedQuestCache[expiredKey] = nil
    end
end

GetQuestSearchBlob = function(quest)
    if not quest then
        return ""
    end

    local questID = quest.id or quest.questID or quest
    if questID and questSearchBlobCache[questID] then
        return questSearchBlobCache[questID]
    end

    local parts = {}
    local function addPart(value)
        if value ~= nil and value ~= "" then
            tinsert(parts, tostring(value))
        end
    end

    addPart(quest.name)
    addPart(quest.description)
    addPart(quest.objectivesText)
    addPart(quest.questGiverName)
    addPart(quest.questTurnInName)
    addPart(quest.id)
    addPart(quest.db2QuestInfoName)
    addPart(quest.db2QuestSortName)
    addPart(quest.db2VignetteName)
    addPart(quest.questType)

    if quest.db2Objectives then
        for _, objective in ipairs(quest.db2Objectives) do
            if type(objective) == "table" then
                addPart(objective.text)
            end
        end
    end

    for _, questLine in ipairs(quest.questLines or {}) do
        addPart(questLine.name)
    end

    for _, campaign in ipairs(quest.campaigns or {}) do
        addPart(campaign.title)
    end

    for _, scenario in ipairs(quest.activities and quest.activities.scenarios or {}) do
        addPart(scenario.name)
    end

    for _, activity in ipairs(quest.activities and quest.activities.groupFinder or {}) do
        addPart(activity.name)
    end

    for _, worldBoss in ipairs(quest.worldSystems and quest.worldSystems.worldBosses or {}) do
        addPart(worldBoss.name)
    end

    for _, invasion in ipairs(quest.worldSystems and quest.worldSystems.invasions or {}) do
        addPart(invasion.name)
    end

    for _, reward in ipairs(quest.worldSystems and quest.worldSystems.renownRewards or {}) do
        addPart(reward.name)
    end

    if (not quest.questGiverName or quest.questGiverName == "")
        and quest.starts
        and quest.starts[1]
    then
        addPart(quest.starts[1].npcName or quest.starts[1].name)
    end

    if (not quest.questTurnInName or quest.questTurnInName == "")
        and quest.ends
        and quest.ends[1]
    then
        addPart(quest.ends[1].npcName or quest.ends[1].name)
    end

    if quest.objectives then
        for _, objective in ipairs(quest.objectives) do
            addPart(objective)
        end
    end

    local blob = table.concat(parts, " "):lower()

    if questID then
        questSearchBlobCache[questID] = blob
    end

    return blob
end

local function GetSortedQuestSourceArray(self, expansionFilter)
    local sourceKey = CachePart(expansionFilter or -1)
    local cachedSource = sortedQuestSourceCache[sourceKey]
    if cachedSource then
        return cachedSource
    end

    local sourceMap = self:GetQuestsForExpansion(expansionFilter)
    local sourceArray = {}

    for _, quest in pairs(sourceMap) do
        tinsert(sourceArray, quest)
    end

    sort(sourceArray, function(a, b)
        local aName = a.name or ""
        local bName = b.name or ""

        if aName ~= bName then
            return aName < bName
        end

        return (a.id or 0) < (b.id or 0)
    end)

    sortedQuestSourceCache[sourceKey] = sourceArray

    return sourceArray
end

local function CompareQuestsByName(a, b)
    local aName = a.name or ""
    local bName = b.name or ""

    if aName ~= bName then
        return aName < bName
    end

    return (a.id or 0) < (b.id or 0)
end

local function CompareQuestsByExpansionThenName(a, b)
    local aExpansionName = EXPANSIONS[a.expansion or -1] or "Unknown"
    local bExpansionName = EXPANSIONS[b.expansion or -1] or "Unknown"

    if aExpansionName ~= bExpansionName then
        return aExpansionName < bExpansionName
    end

    return CompareQuestsByName(a, b)
end

local function ShouldGroupResultsByExpansion(
    expansionFilter,
    zoneFilter,
    typeFilter,
    questTypeFilter,
    searchTerms,
    advancedFilters
)
    if expansionFilter and expansionFilter ~= -1 then
        return false
    end

    if searchTerms and #searchTerms > 0 then
        return true
    end

    if zoneFilter and zoneFilter ~= "" then
        return true
    end

    if typeFilter and typeFilter ~= "all" then
        return true
    end

    if questTypeFilter and questTypeFilter ~= "all" then
        return true
    end

    for key, value in pairs(advancedFilters or {}) do
        if key ~= "groupType"
            and key ~= "questType"
            and value
            and value ~= "all"
            and value ~= ""
        then
            return true
        end
    end

    return false
end

local function NormalizeQuest(quest)
    if not quest then
        return nil
    end

    quest.categories = quest.categories or {}
    quest.flags = quest.flags or {}
    quest.requiredClasses = quest.requiredClasses or {}
    quest.requiredRaces = quest.requiredRaces or {}
    quest.requiredProfessions = quest.requiredProfessions or {}
    quest.rewardItems = quest.rewardItems or {}
    quest.rewardChoices = quest.rewardChoices or {}
    quest.rewardCurrencies = quest.rewardCurrencies or {}
    quest.storyline = quest.storyline or {}
    quest.series = quest.series or {}
    quest.questLines = quest.questLines or {}
    quest.campaigns = quest.campaigns or {}

    quest.name = StripWoWTextFormatting(quest.name)

    if (not quest.zoneName or quest.zoneName == "")
        and quest.mapID
        and quest.mapID ~= 0
    then
        quest.zoneName = GetMapName(quest.mapID) or quest.zoneName
    end

    quest.description = CleanWowheadText(quest.description)
    quest.objectivesText = CleanWowheadText(quest.objectivesText)

    if quest.objectives then
        local cleanedObjectives = {}
        for _, objective in ipairs(quest.objectives) do
            local cleaned = CleanWowheadText(objective)
            if cleaned then
                tinsert(cleanedObjectives, cleaned)
            end
        end
        quest.objectives = cleanedObjectives
    end

    if quest.objectiveDetails then
        local cleanedDetails = {}
        for _, objective in ipairs(quest.objectiveDetails) do
            if type(objective) == "table" then
                objective.text = CleanWowheadText(objective.text)
                if objective.text then
                    tinsert(cleanedDetails, objective)
                end
            end
        end
        quest.objectiveDetails = cleanedDetails
    end

    if not quest.questType or quest.questType == "" then
        for category, resolvedType in pairs(LEGACY_QUEST_TYPE_CATEGORIES) do
            if HasCategory(quest, category) then
                quest.questType = resolvedType
                break
            end
        end
    end

    quest.questType = quest.questType or "standard"

    for category, resolvedType in pairs(LEGACY_QUEST_TYPE_CATEGORIES) do
        if HasCategory(quest, category) then
            if quest.questType == "standard" and resolvedType ~= "standard" then
                quest.questType = resolvedType
            end
            RemoveValue(quest.categories, category)
        end
    end

    for category in pairs(FREQUENCY_CATEGORIES) do
        if HasCategory(quest, category) then
            AddValue(quest.flags, category)
            RemoveValue(quest.categories, category)
        end
    end

    if HasFlag(quest, "daily") then
        quest.isDaily = true
    end

    if HasFlag(quest, "weekly") then
        quest.isWeekly = true
    end

    if HasCategory(quest, "campaign") or #quest.campaigns > 0 then
        quest.isCampaign = true
        AddValue(quest.categories, "campaign")
    end

    if quest.questType == "world" then
        quest.isWorldQuest = true
    end

    if HasCategory(quest, "legendary") then
        quest.classification = quest.classification or 1
    end

    return quest
end

local function IsValidQuest(quest)
    if not quest then
        return false
    end

    if not quest.id or not quest.name then
        return false
    end

    -- Honor the scanner's explicit internal/tracking-quest marking.
    if quest.isInternal then
        return false
    end

    if IsInternalName(quest.name, quest.id) then
        return false
    end

    if HasDNTMarker(quest.description)
        or HasDNTMarker(quest.objectivesText)
        or HasNthMarker(quest.description)
        or HasNthMarker(quest.objectivesText)
        or HasPHMarker(quest.description)
        or HasPHMarker(quest.objectivesText)
        or HasNYIMarker(quest.description)
        or HasNYIMarker(quest.objectivesText)
        or HasBracketedDevMarker(quest.description)
        or HasBracketedDevMarker(quest.objectivesText)
        or HasPlaceholderMarker(quest.description)
        or HasPlaceholderMarker(quest.objectivesText)
        or HasRemovedMarker(quest.description)
        or HasRemovedMarker(quest.objectivesText)
        or HasWowheadChrome(quest.description)
        or HasWowheadChrome(quest.objectivesText)
    then
        return false
    end

    if quest.objectives then
        for _, objective in ipairs(quest.objectives) do
            if HasDNTMarker(objective)
                or HasNthMarker(objective)
                or HasPHMarker(objective)
                or HasNYIMarker(objective)
                or HasBracketedDevMarker(objective)
                or HasPlaceholderMarker(objective)
                or HasRemovedMarker(objective)
                or HasWowheadChrome(objective)
            then
                return false
            end
        end
    end

    for category in pairs(HIDDEN_CATEGORIES) do
        if HasCategory(quest, category) then
            return false
        end
    end

    for flag in pairs(HIDDEN_FLAGS) do
        if HasFlag(quest, flag) then
            return false
        end
    end

    if not HasDisplayQuestText(quest.description)
        and not HasDisplayObjectives(quest)
        and not HasUsefulSparseQuestData(quest)
    then
        return false
    end

    return true
end

------------------------------------------------------------
-- MERGING
------------------------------------------------------------

local function MergeQuestData(external, runtime)
    if not external and not runtime then
        return nil
    end

    local merged = {}

    if external then
        for k, v in pairs(external) do
            merged[k] = v
        end
    end

    if runtime then
        for k, v in pairs(runtime) do
            merged[k] = v
        end
    end

    if runtime and runtime.questGiverCleared then
        merged.starts = {}
        merged.questGiverID = nil
        merged.questGiverName = nil
    end

    if runtime and runtime.questTurnInCleared then
        merged.ends = {}
        merged.questTurnInID = nil
        merged.questTurnInName = nil
    end

    if runtime
        and runtime.capturedFrom == "QUEST_LOG"
        and runtime.coords
        and not (runtime.starts and runtime.starts[1])
        and not (runtime.ends and runtime.ends[1])
    then
        merged.coords = external and external.coords or nil
    end

    return NormalizeQuest(merged)
end

------------------------------------------------------------
-- QUEST ACCESS
------------------------------------------------------------

function QuestData:GetQuest(questID)
    if not questID then
        return nil
    end

    local external = GetExternalDB()[questID]

    local runtimeDB = GetRuntimeDB()

    local runtime =
        runtimeDB
        and runtimeDB.quests
        and runtimeDB.quests[questID]

    return MergeQuestData(external, runtime)
end

function QuestData:GetAllQuests()
    if allQuestsCache then
        return allQuestsCache
    end

    local results = {}

    local externalDB = GetExternalDB()
    local runtimeDB = GetRuntimeDB()

    for questID in pairs(externalDB) do
        local q = self:GetQuest(questID)

        if IsValidQuest(q) then
            results[questID] = q
        end
    end

    if runtimeDB and runtimeDB.quests then
        for questID, runtimeQuest in pairs(runtimeDB.quests) do
            if not results[questID] then
                local q = MergeQuestData(nil, runtimeQuest)

                if IsValidQuest(q) then
                    results[questID] = q
                end
            end
        end
    end

    allQuestsCache = results

    return allQuestsCache
end

function QuestData:GetQuestsForExpansion(expansionID)
    if not expansionID or expansionID == -1 then
        return self:GetAllQuests()
    end

    if expansionQuestsCache[expansionID] then
        return expansionQuestsCache[expansionID]
    end

    local results = {}
    local externalDB = GetExternalExpansionDB(expansionID)

    if not externalDB then
        externalDB = GetExternalDB()
    end

    for questID in pairs(externalDB) do
        local q = self:GetQuest(questID)

        if q
            and q.expansion == expansionID
            and IsValidQuest(q)
        then
            results[questID] = q
        end
    end

    local runtimeDB = GetRuntimeDB()
    if runtimeDB and runtimeDB.quests then
        for questID, runtimeQuest in pairs(runtimeDB.quests) do
            if not results[questID] then
                local q = MergeQuestData(nil, runtimeQuest)

                if q
                    and q.expansion == expansionID
                    and IsValidQuest(q)
                then
                    results[questID] = q
                end
            end
        end
    end

    expansionQuestsCache[expansionID] = results

    return results
end

------------------------------------------------------------
-- SORTED QUERYING
------------------------------------------------------------

--- Fill `results` from the quest source. Optional `shouldYield` (ChunkedJob)
--- keeps large filter walks off the hitch path.
local function BuildSortedQuestResults(
    self,
    expansionFilter,
    zoneFilter,
    typeFilter,
    questTypeFilter,
    searchText,
    advancedFilters,
    results,
    shouldYield
)
    wipe(results)
    advancedFilters = advancedFilters or {}

    typeFilter = advancedFilters.groupType or typeFilter
    questTypeFilter = advancedFilters.questType or questTypeFilter

    local search =
        searchText
        and searchText:lower()
        or nil
    local searchTerms = ParseQuestSearchTerms(search)

    local cacheKey = BuildSortedQuestCacheKey(
        expansionFilter,
        zoneFilter,
        typeFilter,
        questTypeFilter,
        search,
        advancedFilters
    )

    local cachedResults = sortedQuestCache[cacheKey]
    if cachedResults then
        for i = 1, #cachedResults do
            results[i] = cachedResults[i]
        end
        return
    end

    local YieldIfNeeded = OneWoW.ChunkedJob.YieldIfNeeded
    local yieldCheck = shouldYield or function() return false end
    local questSource = GetSortedQuestSourceArray(self, expansionFilter)

    for _, quest in ipairs(questSource) do
        local include = true

        ----------------------------------------------------
        -- SEARCH
        ----------------------------------------------------

        if searchTerms and #searchTerms > 0 then
            if not QuestMatchesSearchTerms(quest, searchTerms) then
                include = false
            end
        end

        ----------------------------------------------------
        -- EXPANSION
        ----------------------------------------------------

        if include
            and expansionFilter
            and expansionFilter ~= -1
        then
            if quest.expansion ~= expansionFilter then
                include = false
            end
        end

        ----------------------------------------------------
        -- ZONE
        ----------------------------------------------------

        if include
            and zoneFilter
            and zoneFilter ~= ""
        then
            local zoneName =
                quest.zoneName
                or GetMapName(quest.mapID)

            if zoneName ~= zoneFilter then
                include = false
            end
        end

        ----------------------------------------------------
        -- GROUP TYPE
        ----------------------------------------------------

        if include and typeFilter and typeFilter ~= "all" then
            local sg = quest.suggestedGroup or 0

            if typeFilter == "solo" and sg >= 2 then
                include = false
            elseif typeFilter == "group"
                and (sg < 2 or sg >= 10)
            then
                include = false
            elseif typeFilter == "raid" and sg < 10 then
                include = false
            end
        end

        ----------------------------------------------------
        -- QUEST TYPE
        ----------------------------------------------------

        if include
            and questTypeFilter
            and questTypeFilter ~= "all"
        then
            if quest.questType ~= questTypeFilter then
                include = false
            end
        end

        ----------------------------------------------------
        -- ADVANCED METADATA
        ----------------------------------------------------

        if include and advancedFilters.category and advancedFilters.category ~= "all" then
            if not HasCategory(quest, advancedFilters.category) then
                include = false
            end
        end

        if include and advancedFilters.flag and advancedFilters.flag ~= "all" then
            if not HasFlag(quest, advancedFilters.flag) then
                include = false
            end
        end

        if include and advancedFilters.profession and advancedFilters.profession ~= "all" then
            if not HasNormalizedValue(quest.requiredProfessions, advancedFilters.profession) then
                include = false
            end
        end

        if include and advancedFilters.class and advancedFilters.class ~= "all" then
            if not HasNormalizedValue(quest.requiredClasses, advancedFilters.class) then
                include = false
            end
        end

        if include and advancedFilters.race and advancedFilters.race ~= "all" then
            if not HasNormalizedValue(quest.requiredRaces, advancedFilters.race) then
                include = false
            end
        end

        if include and advancedFilters.faction and advancedFilters.faction ~= "all" then
            if NormalizeFactionValue(quest.faction) ~= NormalizeFactionValue(advancedFilters.faction) then
                include = false
            end
        end

        if include and advancedFilters.story and advancedFilters.story ~= "all" then
            local hasQuestLine = HasAnyValue(quest.questLines)
            local hasStoryline = HasAnyValue(quest.storyline) or hasQuestLine
            local hasSeries = HasAnyValue(quest.series)
            local hasCampaign = HasAnyValue(quest.campaigns)

            if advancedFilters.story == "campaign" and not hasCampaign then
                include = false
            elseif advancedFilters.story == "storyline" and not hasStoryline then
                include = false
            elseif advancedFilters.story == "chain" and not hasSeries then
                include = false
            elseif advancedFilters.story == "standalone" and (hasCampaign or hasStoryline or hasSeries) then
                include = false
            end
        end

        if include and advancedFilters.runtime and advancedFilters.runtime ~= "all" then
            local hasStarter = quest.starts and quest.starts[1] and quest.starts[1].npcID
            local hasEnder = quest.ends and quest.ends[1] and quest.ends[1].npcID
            local hasLocation =
                (quest.coords and quest.coords.mapID and quest.coords.x and quest.coords.y)
                or (quest.starts and quest.starts[1] and quest.starts[1].mapID and quest.starts[1].x and quest.starts[1].y)
                or (quest.ends and quest.ends[1] and quest.ends[1].mapID and quest.ends[1].x and quest.ends[1].y)

            if advancedFilters.runtime == "has_location" then
                if not hasLocation then
                    include = false
                end
            elseif advancedFilters.runtime == "missing_location" then
                if hasLocation then
                    include = false
                end
            elseif advancedFilters.runtime == "has_quest_giver" then
                if not hasStarter then
                    include = false
                end
            elseif advancedFilters.runtime == "has_turnin" then
                if not hasEnder then
                    include = false
                end
            elseif advancedFilters.runtime == "has_reward_choices" then
                if not (quest.rewardChoices and #quest.rewardChoices > 0) then
                    include = false
                end
            elseif advancedFilters.runtime == "has_rewards" then
                if not (
                    (quest.rewardGold and quest.rewardGold > 0)
                    or (quest.rewardXP and quest.rewardXP > 0)
                    or (quest.rewardItems and #quest.rewardItems > 0)
                    or (quest.rewardChoices and #quest.rewardChoices > 0)
                    or (quest.rewardCurrencies and #quest.rewardCurrencies > 0)
                ) then
                    include = false
                end
            end
        end

        ----------------------------------------------------
        -- NPC (giver or turn-in)
        ----------------------------------------------------

        if include and advancedFilters.npcID then
            if not QuestAssociatedWithNPC(quest, advancedFilters.npcID) then
                include = false
            end
        end

        ----------------------------------------------------
        -- FINAL
        ----------------------------------------------------

        if include then
            tinsert(results, quest)
        end

        YieldIfNeeded(yieldCheck)
    end

    if ShouldGroupResultsByExpansion(
        expansionFilter,
        zoneFilter,
        typeFilter,
        questTypeFilter,
        searchTerms,
        advancedFilters
    ) then
        OneWoW.ChunkedJob.Sort(results, CompareQuestsByExpansionThenName, shouldYield)
    end

    RememberSortedQuestCache(cacheKey, results)
end

function QuestData:GetSortedQuests(
    expansionFilter,
    zoneFilter,
    typeFilter,
    questTypeFilter,
    searchText,
    advancedFilters
)
    local results = {}
    BuildSortedQuestResults(
        self,
        expansionFilter,
        zoneFilter,
        typeFilter,
        questTypeFilter,
        searchText,
        advancedFilters,
        results,
        nil
    )
    return CopyQuestArray(results)
end

function QuestData:CancelSortedQuery()
    if self._sortedQueryJob then
        self._sortedQueryJob:Cancel()
        self._sortedQueryJob = nil
    end
end

--- Time-sliced sorted query into `outResults` (mutated in place). Cancels any prior job.
---@param outResults table
---@param opts table|nil { onProgress, onComplete, onCancel, budgetMs }
---@return table jobHandle
function QuestData:StartSortedQuests(
    expansionFilter,
    zoneFilter,
    typeFilter,
    questTypeFilter,
    searchText,
    advancedFilters,
    outResults,
    opts
)
    opts = opts or {}
    if type(outResults) ~= "table" then
        error("QuestData:StartSortedQuests requires an outResults table", 2)
    end

    self:CancelSortedQuery()
    wipe(outResults)

    local job
    job = OneWoW.ChunkedJob.Start({
        budgetMs = opts.budgetMs,
        run = function(shouldYield)
            BuildSortedQuestResults(
                self,
                expansionFilter,
                zoneFilter,
                typeFilter,
                questTypeFilter,
                searchText,
                advancedFilters,
                outResults,
                shouldYield
            )
        end,
        onProgress = opts.onProgress,
        onComplete = function()
            if self._sortedQueryJob == job then
                self._sortedQueryJob = nil
            end
            if opts.onComplete then
                opts.onComplete(outResults)
            end
        end,
        onCancel = function()
            if self._sortedQueryJob == job then
                self._sortedQueryJob = nil
            end
            if opts.onCancel then
                opts.onCancel()
            end
        end,
    })
    self._sortedQueryJob = job
    return job
end

------------------------------------------------------------
-- EXPANSIONS
------------------------------------------------------------

function QuestData:GetExpansionName(expansionID)
    return EXPANSIONS[expansionID] or "Unknown"
end

function QuestData:GetExpansionShortName(expansionID)
    return EXPANSION_SHORT[expansionID] or "Unknown"
end

function QuestData:GetAvailableExpansions()
    local found = {}

    if ns.ExternalQuestDBByExpansion then
        for expID in pairs(ns.ExternalQuestDBByExpansion) do
            found[expID] = true
        end
    end

    local runtimeDB = GetRuntimeDB()
    if runtimeDB and runtimeDB.quests then
        for _, quest in pairs(runtimeDB.quests) do
            if quest.expansion ~= nil then
                found[quest.expansion] = true
            end
        end
    end

    if not next(found) then
        for _, quest in pairs(self:GetAllQuests()) do
            if quest.expansion ~= nil then
                found[quest.expansion] = true
            end
        end
    end

    local result = {}

    for expID in pairs(found) do
        tinsert(result, {
            id = expID,
            name = self:GetExpansionName(expID),
        })
    end

    sort(result, function(a, b)
        return a.id < b.id
    end)

    return result
end

function QuestData:GetAvailableZones(expansionID)
    local found = {}
    local source =
        expansionID
        and self:GetQuestsForExpansion(expansionID)
        or self:GetAllQuests()

    for _, quest in pairs(source) do
        if quest.expansion ~= nil then
            local zoneName =
                quest.zoneName
                or GetMapName(quest.mapID)

            if zoneName and zoneName ~= "" then
                found[zoneName] = true
            end
        end
    end

    local result = {}

    for zoneName in pairs(found) do
        tinsert(result, zoneName)
    end

    sort(result)

    return result
end

------------------------------------------------------------
-- ZONES
------------------------------------------------------------

------------------------------------------------------------
-- RUNTIME STORAGE
------------------------------------------------------------

function QuestData:StoreQuestInfo(questID, data)
    if not questID or not data then
        return
    end

    local db = GetRuntimeDB()

    db.quests[questID] =
        db.quests[questID] or {}

    for k, v in pairs(data) do
        db.quests[questID][k] = v
    end

    db.quests[questID].id = questID
    db.quests[questID].lastUpdated = time()

    allQuestsCache = nil
    wipe(expansionQuestsCache)
    ClearQuestDerivedCaches()
    self:InvalidateQuestRewardIndex()
    QueueQuestUIRefresh()
end

--- Persist enrichment for an already-known quest WITHOUT invalidating the
--- derived caches or triggering a list refresh. Used by the detail view to fill
--- in display-only fields (mapID, classification, tagName) on click; rebuilding
--- the full sorted/source caches there would cost a 33k-quest pass per click.
---@param questID number
---@param data table
function QuestData:StoreQuestInfoQuiet(questID, data)
    if not questID or not data then
        return
    end

    local db = GetRuntimeDB()

    db.quests[questID] = db.quests[questID] or {}

    for k, v in pairs(data) do
        db.quests[questID][k] = v
    end

    db.quests[questID].id = questID
    db.quests[questID].lastUpdated = time()
end

function QuestData:RememberItemName(itemID, itemName)
    itemID = tonumber(itemID)
    if not itemID or not itemName or itemName == "" then
        return
    end

    if RememberCatalogItemName(itemID, tostring(itemName)) then
        ClearSortedQuestCache()
    end
end

function QuestData:GetCachedItemName(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end

    return GetCatalogCachedItemName(itemID)
end

------------------------------------------------------------
-- STATS
------------------------------------------------------------

function QuestData:GetCapturedQuestCount()
    local count = 0

    for _ in pairs(self:GetAllQuests()) do
        count = count + 1
    end

    return count
end

function QuestData:GetQuestCount()
    return self:GetCapturedQuestCount()
end

--- Returns up to `limit` quests for the unfiltered initial view (sorted by name)
--- plus the total available count. Reuses the cached sorted source array and
--- copies only the first `limit`, avoiding a full-result-set copy on load.
---@param limit number|nil
---@return table[] quests
---@return number total
function QuestData:GetInitialQuests(limit)
    local source = GetSortedQuestSourceArray(self, -1)
    local total = #source
    local n = math.min(limit or 100, total)

    local out = {}
    for i = 1, n do
        out[i] = source[i]
    end

    return out, total
end

------------------------------------------------------------
-- QUEST REWARD INDEX (itemID -> questIDs)
------------------------------------------------------------

local questRewardIndex = nil

local function BuildQuestRewardIndex()
    if questRewardIndex then
        return questRewardIndex
    end

    questRewardIndex = {}

    local function indexList(questID, list)
        if not list then return end
        for _, rewardItem in ipairs(list) do
            local itemID = GetRewardItemID(rewardItem)
            if itemID then
                local bucket = questRewardIndex[itemID]
                if not bucket then
                    bucket = {}
                    questRewardIndex[itemID] = bucket
                end
                bucket[questID] = true
            end
        end
    end

    for questID, quest in pairs(QuestData:GetAllQuests()) do
        indexList(questID, quest.rewardItems)
        indexList(questID, quest.rewardChoices)
    end

    return questRewardIndex
end

--- Returns a sorted array of quest IDs that reward the given item, or nil.
--- The index is built lazily from the merged quest set and cached until quest
--- data changes (see InvalidateQuestRewardIndex).
---@param itemID number
---@return number[]|nil
function QuestData:GetQuestsRewardingItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end

    local bucket = BuildQuestRewardIndex()[itemID]
    if not bucket then return nil end

    local ids = {}
    for questID in pairs(bucket) do
        ids[#ids + 1] = questID
    end
    sort(ids)
    return ids
end

--- Returns an array of every item ID that appears as a quest reward, for
--- name-based Item Search cross-referencing.
---@return number[]
function QuestData:GetRewardItemIDs()
    local idx = BuildQuestRewardIndex()
    local ids = {}
    for itemID in pairs(idx) do
        ids[#ids + 1] = itemID
    end
    return ids
end

function QuestData:InvalidateQuestRewardIndex()
    questRewardIndex = nil
end

------------------------------------------------------------
-- QUEST NPC INDEX (npcID -> questIDs)
------------------------------------------------------------

local function BuildQuestNPCIndex()
    if questNPCIndex then
        return questNPCIndex
    end

    questNPCIndex = {}

    local function add(npcID, questID)
        npcID = tonumber(npcID)
        if not npcID then return end
        local bucket = questNPCIndex[npcID]
        if not bucket then
            bucket = {}
            questNPCIndex[npcID] = bucket
        end
        bucket[questID] = true
    end

    local function addList(questID, list)
        if not list then return end
        for _, npc in ipairs(list) do
            if type(npc) == "table" and npc.npcID then
                add(npc.npcID, questID)
            end
        end
    end

    for questID, quest in pairs(QuestData:GetAllQuests()) do
        add(quest.questGiverID, questID)
        add(quest.questTurnInID, questID)
        addList(questID, quest.starts)
        addList(questID, quest.ends)
    end

    return questNPCIndex
end

--- Returns a sorted array of quest IDs associated with an NPC (as quest giver or
--- turn-in), or nil. NPC associations come from live captures, so this reflects
--- quests the player has interacted with. Cached until quest data changes.
---@param npcID number
---@return number[]|nil
function QuestData:GetQuestsForNPC(npcID)
    npcID = tonumber(npcID)
    if not npcID then return nil end

    local bucket = BuildQuestNPCIndex()[npcID]
    if not bucket then return nil end

    local ids = {}
    for questID in pairs(bucket) do
        ids[#ids + 1] = questID
    end
    sort(ids)
    return ids
end

--- Returns the distinct filter values actually present in the merged quest set,
--- for building the advanced-filter dropdowns. Class/race are numeric IDs;
--- professions/categories/flags are lowercase string tokens. Cached until quest
--- data changes.
---@return table values  { classes, races, professions, categories, flags }
function QuestData:GetFilterValues()
    if filterValuesCache then
        return filterValuesCache
    end

    local classes, races, professions, categories, flags = {}, {}, {}, {}, {}

    for _, quest in pairs(self:GetAllQuests()) do
        if quest.requiredClasses then
            for _, c in ipairs(quest.requiredClasses) do classes[c] = true end
        end
        if quest.requiredRaces then
            for _, r in ipairs(quest.requiredRaces) do races[r] = true end
        end
        if quest.requiredProfessions then
            for _, p in ipairs(quest.requiredProfessions) do professions[tostring(p):lower()] = true end
        end
        if quest.categories then
            for _, cat in ipairs(quest.categories) do categories[tostring(cat):lower()] = true end
        end
        if quest.flags then
            for _, f in ipairs(quest.flags) do flags[tostring(f):lower()] = true end
        end
    end

    local function toSortedArray(set)
        local out = {}
        for k in pairs(set) do out[#out + 1] = k end
        sort(out)
        return out
    end

    filterValuesCache = {
        classes     = toSortedArray(classes),
        races       = toSortedArray(races),
        professions = toSortedArray(professions),
        categories  = toSortedArray(categories),
        flags       = toSortedArray(flags),
    }

    return filterValuesCache
end

return QuestData
