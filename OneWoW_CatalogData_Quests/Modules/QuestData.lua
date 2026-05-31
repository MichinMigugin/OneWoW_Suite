local addonName, ns = ...

local QuestData = {}
ns.QuestData = QuestData

------------------------------------------------------------
-- DATABASE ACCESS
------------------------------------------------------------

local function GetRuntimeDB()
    OneWoW_CatalogData_Quests_DB =
        OneWoW_CatalogData_Quests_DB or {}

    local db = OneWoW_CatalogData_Quests_DB.global
        or OneWoW_CatalogData_Quests_DB

    db.quests = db.quests or {}

    return db
end

local function GetExternalDB()
    return ns.ExternalQuestDB or {}
end

local function GetExternalExpansionDB(expansionID)
    return
        ns.ExternalQuestDBByExpansion
        and ns.ExternalQuestDBByExpansion[expansionID]
        or nil
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
        table.insert(tbl, value)
    end
end

local function GetMapName(mapID)
    if not mapID then
        return nil
    end

    if mapNameCache[mapID] ~= nil then
        return mapNameCache[mapID] or nil
    end

    local mapInfo =
        C_Map
        and C_Map.GetMapInfo
        and C_Map.GetMapInfo(mapID)

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

        if ns.UI and ns.UI.RefreshQuestsList then
            ns.UI.RefreshQuestsList()
        elseif _G.OneWoW_Catalog
            and OneWoW_Catalog.UI
            and OneWoW_Catalog.UI.RefreshQuestsList
        then
            OneWoW_Catalog.UI.RefreshQuestsList()
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

local function GetCatalogCachedItemName(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end

    local catalogCache =
        OneWoW_Catalog_DB
        and OneWoW_Catalog_DB.global
        and OneWoW_Catalog_DB.global.itemCache

    local cached = catalogCache and catalogCache[itemID]

    if type(cached) == "table" then
        return cached.name
    elseif type(cached) == "string" then
        return cached
    end

    return nil
end

local function RememberCatalogItemName(itemID, itemName)
    itemID = tonumber(itemID)
    if not itemID or not itemName or itemName == "" then
        return false
    end

    if not OneWoW_Catalog_DB then
        OneWoW_Catalog_DB = {}
    end

    OneWoW_Catalog_DB.global = OneWoW_Catalog_DB.global or {}
    OneWoW_Catalog_DB.global.itemCache = OneWoW_Catalog_DB.global.itemCache or {}

    local itemCache = OneWoW_Catalog_DB.global.itemCache
    local previous = itemCache[itemID]
    local previousName =
        type(previous) == "table"
        and previous.name
        or previous

    if type(previous) ~= "table" then
        previous = {}
        itemCache[itemID] = previous
    end

    previous.name = itemName

    if not previous.link and C_Item and C_Item.GetItemInfo then
        local _, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
        previous.link = link
        previous.quality = previous.quality or quality or 1
        previous.icon = previous.icon or icon or 134400
    else
        previous.quality = previous.quality or 1
        previous.icon = previous.icon or 134400
    end

    return previousName ~= itemName
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
            table.insert(terms, {
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
    }, "\031")
end

local function RememberSortedQuestCache(key, results)
    if sortedQuestCache[key] then
        sortedQuestCache[key] = CopyQuestArray(results)
        return
    end

    sortedQuestCache[key] = CopyQuestArray(results)
    table.insert(sortedQuestCacheOrder, key)

    while #sortedQuestCacheOrder > SORTED_QUEST_CACHE_LIMIT do
        local expiredKey = table.remove(sortedQuestCacheOrder, 1)
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
            table.insert(parts, tostring(value))
        end
    end

    addPart(quest.name)
    addPart(quest.description)
    addPart(quest.objectivesText)
    addPart(quest.questGiverName)
    addPart(quest.questTurnInName)
    addPart(quest.id)

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
        table.insert(sourceArray, quest)
    end

    table.sort(sourceArray, function(a, b)
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
                table.insert(cleanedObjectives, cleaned)
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
                    table.insert(cleanedDetails, objective)
                end
            end
        end
        quest.objectiveDetails = cleanedDetails
    end

    if HasFlag(quest, "daily") then
        quest.isDaily = true
        AddValue(quest.categories, "daily")
    end

    if HasFlag(quest, "weekly") then
        quest.isWeekly = true
        AddValue(quest.categories, "weekly")
    end

    if HasFlag(quest, "repeatable") then
        AddValue(quest.categories, "repeatable")
    end

    if HasCategory(quest, "campaign") then
        quest.isCampaign = true
    end

    if HasCategory(quest, "world") then
        quest.isWorldQuest = true
        AddValue(quest.categories, "worldquest")
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

function QuestData:GetSortedQuests(
    expansionFilter,
    zoneFilter,
    typeFilter,
    questTypeFilter,
    searchText,
    advancedFilters
)
    local results = {}
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
        return CopyQuestArray(cachedResults)
    end

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
        -- QUEST CATEGORY
        ----------------------------------------------------

        if include
            and questTypeFilter
            and questTypeFilter ~= "all"
        then
            if questTypeFilter == "normal" then
                if quest.isDaily
                    or quest.isWeekly
                    or quest.isCampaign
                    or quest.isWorldQuest
                then
                    include = false
                end
            elseif not HasCategory(quest, questTypeFilter) then
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
            local hasStoryline = HasAnyValue(quest.storyline)
            local hasSeries = HasAnyValue(quest.series)

            if advancedFilters.story == "storyline" and not hasStoryline then
                include = false
            elseif advancedFilters.story == "chain" and not (hasStoryline or hasSeries) then
                include = false
            elseif advancedFilters.story == "standalone" and (hasStoryline or hasSeries) then
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
        -- FINAL
        ----------------------------------------------------

        if include then
            table.insert(results, quest)
        end
    end

    if ShouldGroupResultsByExpansion(
        expansionFilter,
        zoneFilter,
        typeFilter,
        questTypeFilter,
        searchTerms,
        advancedFilters
    ) then
        table.sort(results, CompareQuestsByExpansionThenName)
    end

    RememberSortedQuestCache(cacheKey, results)

    return CopyQuestArray(results)
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
        table.insert(result, {
            id = expID,
            name = self:GetExpansionName(expID),
        })
    end

    table.sort(result, function(a, b)
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
        table.insert(result, zoneName)
    end

    table.sort(result)

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
    QueueQuestUIRefresh()

    if _G.OneWoW_Catalog
        and OneWoW_Catalog.ItemSearch
        and OneWoW_Catalog.ItemSearch.InvalidateQuestRewardIndex
    then
        OneWoW_Catalog.ItemSearch:InvalidateQuestRewardIndex()
    end
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

return QuestData
