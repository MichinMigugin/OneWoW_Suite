-- OneWoW Addon File
-- OneWoW_CatalogData_Quests/Modules/QuestData.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.QuestData = {}
local QuestData = ns.QuestData

local EXPANSION_NAMES = {
    [0]  = "Classic",
    [1]  = "The Burning Crusade",
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

local INTERNAL_NAME_PATTERNS = {
    "tracking quest",
    "^decor ",
    "^deprecated",
    "^test ",
    "^qa ",
}

local function IsInternalName(name)
    if not name or name == "" then return true end
    local lower = name:lower()
    for _, pattern in ipairs(INTERNAL_NAME_PATTERNS) do
        if lower:find(pattern) then return true end
    end
    return false
end

local EXPANSION_SHORT = {
    [0]  = "Classic",
    [1]  = "BC",
    [2]  = "Wrath",
    [3]  = "Cataclysm",
    [4]  = "Pandaria",
    [5]  = "Warlords",
    [6]  = "Legion",
    [7]  = "BfA",
    [8]  = "Shadowlands",
    [9]  = "Dragonflight",
    [10] = "War Within",
    [11] = "Midnight",
}

local CLASSIFICATION_TYPE = {
    [0]  = "important",
    [1]  = "legendary",
    [2]  = "campaign",
    [3]  = "calling",
    [4]  = "meta",
    [5]  = "recurring",
    [6]  = "questline",
    [7]  = "normal",
    [8]  = "bonus",
    [9]  = "threat",
    [10] = "worldquest",
}

local function GetDB()
    return OneWoW_CatalogData_Quests_DB
end

function QuestData:GetExpansionName(expansionID)
    if expansionID == nil then return nil end
    return EXPANSION_NAMES[expansionID]
end

function QuestData:GetExpansionShortName(expansionID)
    if expansionID == nil then return nil end
    return EXPANSION_SHORT[expansionID]
end

function QuestData:GetAllExpansionNames()
    return EXPANSION_NAMES
end

function QuestData:GetClassificationType(classificationID)
    if classificationID == nil then return "normal" end
    return CLASSIFICATION_TYPE[classificationID] or "normal"
end

function QuestData:StoreQuestInfo(questID, data)
    local db = GetDB()
    if not db or not questID then return end

    local existing = db.quests[questID] or {}
    for k, v in pairs(data) do
        if v ~= nil then
            existing[k] = v
        end
    end
    existing.lastUpdated = time()
    if not existing.firstSeen then
        existing.firstSeen = time()
    end
    db.quests[questID] = existing
end

function QuestData:GetQuest(questID)
    local db = GetDB()
    if not db then return nil end
    return db.quests[questID]
end

function QuestData:GetAllQuests()
    local db = GetDB()
    if not db then return {} end
    return db.quests
end

function QuestData:GetQuestCount()
    local db = GetDB()
    if not db then return 0 end
    local count = 0
    for _ in pairs(db.quests) do count = count + 1 end
    return count
end

function QuestData:GetCapturedQuestCount()
    local db = GetDB()
    if not db then return 0 end
    local count = 0
    for _, quest in pairs(db.quests) do
        if quest.name and quest.description and not quest.isInternal and not IsInternalName(quest.name) then
            count = count + 1
        end
    end
    return count
end

function QuestData:GetSortedQuests(expansionFilter, zoneFilter, typeFilter, questTypeFilter, searchText)
    local db = GetDB()
    if not db then return {} end

    local result = {}
    local search = searchText and searchText:lower() or ""

    for questID, quest in pairs(db.quests) do
        if quest.name and quest.description and not quest.isInternal and not IsInternalName(quest.name) then
            local pass = true

            if expansionFilter and expansionFilter ~= -1 then
                if quest.expansion ~= expansionFilter then
                    pass = false
                end
            end

            if pass and zoneFilter and zoneFilter ~= "" then
                if not quest.zoneName or quest.zoneName ~= zoneFilter then
                    pass = false
                end
            end

            if pass and typeFilter and typeFilter ~= "all" then
                if typeFilter == "solo" then
                    if quest.suggestedGroup and quest.suggestedGroup > 1 then pass = false end
                elseif typeFilter == "group" then
                    if not quest.suggestedGroup or quest.suggestedGroup < 2 or quest.suggestedGroup >= 10 then pass = false end
                elseif typeFilter == "raid" then
                    if not quest.suggestedGroup or quest.suggestedGroup < 10 then pass = false end
                end
            end

            if pass and questTypeFilter and questTypeFilter ~= "all" then
                local qtype = CLASSIFICATION_TYPE[quest.classification] or "normal"
                if questTypeFilter == "daily" then
                    if not quest.isDaily then pass = false end
                elseif questTypeFilter == "weekly" then
                    if not quest.isWeekly then pass = false end
                elseif questTypeFilter == "campaign" then
                    if qtype ~= "campaign" then pass = false end
                elseif questTypeFilter == "worldquest" then
                    if qtype ~= "worldquest" then pass = false end
                elseif questTypeFilter == "normal" then
                    if quest.isDaily or quest.isWeekly or qtype == "campaign" or qtype == "worldquest" then pass = false end
                end
            end

            if pass and search ~= "" then
                local name = (quest.name or ""):lower()
                if not name:find(search, 1, true) then
                    pass = false
                end
            end

            if pass then
                table.insert(result, quest)
            end
        end
    end

    table.sort(result, function(a, b)
        return (a.name or "") < (b.name or "")
    end)

    return result
end

function QuestData:GetAvailableExpansions()
    local db = GetDB()
    if not db then return {} end

    local seen = {}
    for _, quest in pairs(db.quests) do
        if quest.expansion ~= nil and quest.name then
            seen[quest.expansion] = true
        end
    end

    local result = {}
    for expID in pairs(seen) do
        table.insert(result, {
            id   = expID,
            name = EXPANSION_NAMES[expID] or "Unknown",
        })
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

function QuestData:GetAvailableZones(expansionFilter)
    local db = GetDB()
    if not db then return {} end

    local seen = {}
    for _, quest in pairs(db.quests) do
        if quest.zoneName and quest.zoneName ~= "" and quest.name then
            local include = true
            if expansionFilter and expansionFilter ~= -1 then
                include = (quest.expansion == expansionFilter)
            end
            if include then
                seen[quest.zoneName] = true
            end
        end
    end

    local result = {}
    for zoneName in pairs(seen) do
        table.insert(result, zoneName)
    end
    table.sort(result)
    return result
end

function QuestData:FormatGold(copper)
    if not copper or copper == 0 then return nil end
    local gold   = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local c      = copper % 100
    local parts  = {}
    if gold   > 0 then table.insert(parts, gold .. "g")   end
    if silver > 0 then table.insert(parts, silver .. "s") end
    if c      > 0 then table.insert(parts, c .. "c")       end
    return table.concat(parts, " ")
end

function QuestData:FormatNumber(num)
    if not num or num == 0 then return nil end
    local str = tostring(math.floor(num))
    return str:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end
