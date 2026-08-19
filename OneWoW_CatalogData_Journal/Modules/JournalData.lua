local _, ns = ...

ns.JournalData = {}
local JournalData = ns.JournalData

local expansionList = {
    { name = "Classic",            expansionID = 1,  displayName = "Classic" },
    { name = "BurningCrusade",     expansionID = 2,  displayName = "The Burning Crusade" },
    { name = "WrathoftheLichKing", expansionID = 3,  displayName = "Wrath of the Lich King" },
    { name = "Cataclysm",         expansionID = 4,  displayName = "Cataclysm" },
    { name = "MistsofPandaria",    expansionID = 5,  displayName = "Mists of Pandaria" },
    { name = "WarlordsofDraenor",  expansionID = 6,  displayName = "Warlords of Draenor" },
    { name = "Legion",             expansionID = 7,  displayName = "Legion" },
    { name = "BattleforAzeroth",   expansionID = 8,  displayName = "Battle for Azeroth" },
    { name = "Shadowlands",        expansionID = 9,  displayName = "Shadowlands" },
    { name = "Dragonflight",       expansionID = 10, displayName = "Dragonflight" },
    { name = "TheWarWithin",       expansionID = 11, displayName = "The War Within" },
    { name = "Midnight",           expansionID = 12, displayName = "Midnight" },
}

local expansionByID = {}
for _, exp in ipairs(expansionList) do
    expansionByID[exp.expansionID] = exp
end

JournalData.journalCache = nil
JournalData.initialized = false

-- Synthetic encounters that pull achievement-tied and quest-obtained loot out of
-- the General bucket, so "General" only holds items not tied to a boss,
-- achievement, or quest.
local ACHIEVEMENT_ENC_ID = -2
local QUEST_ENC_ID = -3
JournalData.ACHIEVEMENT_ENC_ID = ACHIEVEMENT_ENC_ID
JournalData.QUEST_ENC_ID = QUEST_ENC_ID

--- Composite cache / favorites key for a journal card.
---@param expansionID number
---@param instanceID number
---@return string
function JournalData.CacheKey(expansionID, instanceID)
    return tostring(expansionID) .. ":" .. tostring(instanceID)
end

-- Encounter display order: bosses (by bossIndex) -> Achievement -> Quest -> General.
local function EncounterSortRank(enc)
    if enc.encounterID == 0 then return 4 end
    if enc.encounterID == QUEST_ENC_ID then return 3 end
    if enc.encounterID == ACHIEVEMENT_ENC_ID then return 2 end
    return 1
end

local function SortEncounters(a, b)
    local ra, rb = EncounterSortRank(a), EncounterSortRank(b)
    if ra ~= rb then return ra < rb end
    local ai = a.bossIndex or 999
    local bi = b.bossIndex or 999
    if ai ~= bi then return ai < bi end
    return (a.name or "") < (b.name or "")
end

function JournalData:DetermineItemSpecial(idata)
    -- Achievement-gated items are tagged first so they can be excluded from
    -- regular loot counts and shown with achievement info in the UI.
    if idata.achievementID then
        return "Achievement"
    end

    if idata.mountID then
        return "Mount"
    end

    if idata.speciesID then
        return "Pet"
    end

    if idata.isToy then
        return "Toy"
    end

    if idata.isTransmog then
        return "TMog"
    end

    local itemType    = idata.itemType    or ""
    local itemSubType = idata.itemSubType or ""

    if itemType == "Recipe" then
        return "Recipe"
    end

    if itemType == "Quest" then
        return "Quest"
    end

    if itemType == "Housing" then
        return "Housing"
    end

    if itemSubType == "Mount" or itemSubType == "Mounts" then
        return "Mount"
    end

    if itemSubType == "Companion Pets" or itemSubType == "Battle Pets" then
        return "Pet"
    end

    if itemType == "Miscellaneous" or itemType == "Consumable" then
        local itemID = idata.itemID
        if itemID then
            local _, _, _, isToy = C_ToyBox.GetToyInfo(itemID)
            if isToy then return "Toy" end

            local mountID = C_MountJournal.GetMountFromItem(itemID)
            if mountID then return "Mount" end

            local _, _, _, _, _, _, _, _, _, _, _, _, speciesID = C_PetJournal.GetPetInfoByItemID(itemID)
            if speciesID and speciesID > 0 then return "Pet" end
        end
    end

    return nil
end

-- Prefer the player's faction source quest, else the first listed source.
---@param itemData table|nil
---@return number|nil questID
local function ResolveQuestIDFromItemData(itemData)
    local sources = itemData and itemData.questSources
    if not sources or #sources == 0 then
        return nil
    end
    local faction = UnitFactionGroup("player")
    local fallback
    for _, qs in ipairs(sources) do
        if not fallback then fallback = qs.id end
        if qs.faction == faction then return qs.id end
    end
    return fallback
end

-- Specials answered by OneWoW.Collectibles (item-facing facade).
local COLLECTIBLES_SPECIAL_TYPES = {
    TMog = true, Mount = true, Pet = true, Toy = true, Recipe = true, Housing = true,
}

-- Collection state for a journal item.
-- Collectibles specials → OneWoW.Collectibles.GetItemCollectionStatus.
-- Quest → Catalog Quests CompletionTracker (soft dep) or C_QuestLog fallback.
-- Returns nil when status is indeterminate (hide badge; ignore for "Has uncollected").
function JournalData:IsItemCollected(itemID, itemData, specialType)
    if not specialType then
        return nil
    end

    if specialType == "Quest" then
        local questID = ResolveQuestIDFromItemData(itemData)
        if not questID then
            return nil
        end
        local questAddon = OneWoW_CatalogData_Quests_API
        if questAddon then
            return questAddon.IsCompletedByCurrentChar(questID) == true
        end
        return C_QuestLog.IsQuestFlaggedCompleted(questID) == true
    end

    if not itemID or not COLLECTIBLES_SPECIAL_TYPES[specialType] then
        return nil
    end

    local status = OneWoW.Collectibles.GetItemCollectionStatus(itemID)
    if status then
        return status.collected == true
    end

    -- No resolvable collectible key: hide the badge for recipes (indeterminate),
    -- report not-owned for the deterministic collection types.
    if specialType == "Recipe" then
        return nil
    end
    return false
end

function JournalData:DetermineItemStatus(itemID, itemData, specialType)
    if not specialType then
        return nil
    end

    local L = ns.L
    local collected = self:IsItemCollected(itemID, itemData, specialType)

    if collected == nil then
        return nil
    end

    if specialType == "TMog" then
        return collected and COLLECTED or NOT_COLLECTED
    end

    if specialType == "Quest" then
        return collected and L["JOURNAL_QUEST_COMPLETED"] or L["JOURNAL_QUEST_NOT_COMPLETED"]
    end

    if specialType == "Mount" or specialType == "Pet" or specialType == "Toy"
        or specialType == "Recipe" or specialType == "Housing" then
        return collected and L["JOURNAL_STATUS_KNOWN"] or L["JOURNAL_STATUS_UNKNOWN"]
    end

    return nil
end

--- Deduped item-location rows for one instanceID across every expansion tables file.
---@param itemsByEncByInst table
---@param itemID number
---@param itemData table
---@param loc table
local function AddLocationEntry(itemsByEncByInst, itemID, itemData, loc)
    local instID = loc.instanceID
    local encID = loc.encounterID or 0
    if not instID then
        return
    end
    itemsByEncByInst[instID] = itemsByEncByInst[instID] or {}
    itemsByEncByInst[instID][encID] = itemsByEncByInst[instID][encID] or {}
    local bucket = itemsByEncByInst[instID][encID]
    for _, existing in ipairs(bucket) do
        if existing.itemID == itemID then
            -- Same item already placed on this encounter from another tables file.
            return
        end
    end
    tinsert(bucket, {
        itemID       = itemID,
        itemData     = itemData,
        difficulties = loc.difficulties,
        source       = loc.source,
        encounterID  = encID,
        instanceID   = instID,
    })
end

---@param encByID table
---@param encountersGlobal table|nil
---@param fallbackEncounters table
---@return table encounters
function JournalData:BuildEncountersForInstance(encByID, encountersGlobal, fallbackEncounters)
    local L = ns.L
    local encounters = {}

    local function MakeItemRow(entry)
        local idata = entry.itemData
        return {
            itemID       = entry.itemID,
            itemData     = idata,
            name         = idata.name or L["JOURNAL_UNKNOWN_ITEM"],
            icon         = idata.icon or 134400,
            quality      = idata.quality or 1,
            special      = self:DetermineItemSpecial(idata),
            difficulties = entry.difficulties or {},
            source       = entry.source,
            questSources = idata.questSources,
        }
    end

    local function ByName(a, b)
        return a.name < b.name
    end

    for encID, entries in pairs(encByID) do
        if encID == 0 then
            local generalItems, achievementItems, questItems = {}, {}, {}
            for _, entry in ipairs(entries) do
                local itemRow = MakeItemRow(entry)
                if itemRow.questSources and #itemRow.questSources > 0 then
                    tinsert(questItems, itemRow)
                elseif itemRow.special == "Achievement" then
                    tinsert(achievementItems, itemRow)
                else
                    tinsert(generalItems, itemRow)
                end
            end

            if #generalItems > 0 then
                sort(generalItems, ByName)
                tinsert(encounters, {
                    encounterID = 0,
                    name        = L["JOURNAL_GENERAL_LOOT"],
                    bossIndex   = 0,
                    items       = generalItems,
                })
            end
            if #achievementItems > 0 then
                sort(achievementItems, ByName)
                tinsert(encounters, {
                    encounterID = ACHIEVEMENT_ENC_ID,
                    name        = L["JOURNAL_ACHIEVEMENT_LOOT"],
                    bossIndex   = 0,
                    items       = achievementItems,
                })
            end
            if #questItems > 0 then
                sort(questItems, ByName)
                tinsert(encounters, {
                    encounterID   = QUEST_ENC_ID,
                    name          = L["JOURNAL_QUEST_LOOT"],
                    bossIndex     = 0,
                    items         = questItems,
                    questCategory = true,
                })
            end
        else
            local encInfo = (encountersGlobal and encountersGlobal[encID])
                or (fallbackEncounters and fallbackEncounters[encID])
            local encName = L["JOURNAL_UNKNOWN_INST"]
            local bossIndex = 0
            if encInfo then
                encName = encInfo.name or L["JOURNAL_UNKNOWN_INST"]
                bossIndex = encInfo.bossIndex or 0
            end

            local items = {}
            for _, entry in ipairs(entries) do
                tinsert(items, MakeItemRow(entry))
            end
            sort(items, ByName)

            tinsert(encounters, {
                encounterID = encID,
                name        = encName,
                bossIndex   = bossIndex,
                items       = items,
            })
        end
    end

    sort(encounters, SortEncounters)
    return encounters
end

local function ApplyTotals(inst, encounters)
    local hasTMog, hasMounts, hasPets, hasToys, hasRecipes, hasQuest, hasHousing =
        false, false, false, false, false, false, false
    local totalItems = 0
    local seenItemIDs = {}
    for _, enc in ipairs(encounters) do
        for _, item in ipairs(enc.items) do
            if item.special ~= "Achievement" and not seenItemIDs[item.itemID] then
                seenItemIDs[item.itemID] = true
                totalItems = totalItems + 1
                if item.special == "TMog"    then hasTMog    = true end
                if item.special == "Mount"   then hasMounts  = true end
                if item.special == "Pet"     then hasPets    = true end
                if item.special == "Toy"     then hasToys    = true end
                if item.special == "Recipe"  then hasRecipes = true end
                if item.special == "Quest"   then hasQuest   = true end
                if item.special == "Housing" then hasHousing = true end
            end
        end
    end
    inst.hasTMog       = hasTMog
    inst.hasMounts     = hasMounts
    inst.hasPets       = hasPets
    inst.hasToys       = hasToys
    inst.hasRecipes    = hasRecipes
    inst.hasQuest      = hasQuest
    inst.hasHousing    = hasHousing
    inst.totalItems    = totalItems
end

--- DB2 doors win. Wowhead /way fallbacks fill holes until Blizzard ships a row.
---@param instanceID number
---@return table|nil
---@return string|nil
local function ResolveEntrances(instanceID)
    local db2 = ns.JournalInstanceEntrances and ns.JournalInstanceEntrances[instanceID]
    if db2 and db2[1] then
        return db2, "db2"
    end
    local hand = ns.JournalInstanceEntranceFallbacks and ns.JournalInstanceEntranceFallbacks[instanceID]
    if hand and hand[1] then
        return hand, "wowhead"
    end
    return nil, nil
end

---@param expansionID number
---@param instanceID number
---@param orderIndex number|nil
---@param instInfo table|nil
---@param encounters table
---@return table
local function MakeCacheEntry(expansionID, instanceID, orderIndex, instInfo, encounters)
    local L = ns.L
    local exp = expansionByID[expansionID]
    local ejMeta = ns.JournalInstanceMeta and ns.JournalInstanceMeta[instanceID]
    local flags = (ejMeta and ejMeta.flags) or 0
    local mapID = (instInfo and instInfo.mapID)
        or (ejMeta and ejMeta.mapID)
        or nil
    local name = (instInfo and instInfo.name)
        or (ejMeta and ejMeta.name)
        or L["JOURNAL_UNKNOWN_INST"]
    local instanceType = (instInfo and instInfo.instanceType) or "party"
    local validDifficulties = nil
    if mapID and ns.JournalMapDifficulties then
        validDifficulties = ns.JournalMapDifficulties[mapID]
    end

    local entrances, entranceSource = ResolveEntrances(instanceID)

    local entry = {
        cacheKey           = JournalData.CacheKey(expansionID, instanceID),
        instanceID         = instanceID,
        name               = name,
        mapID              = mapID,
        instanceType       = instanceType,
        expansionID        = expansionID,
        expansionName      = exp and exp.displayName or tostring(expansionID),
        orderIndex         = orderIndex or 0,
        encounters         = encounters,
        flags              = flags,
        isTimewalker       = (flags % 2) ~= 0,
        validDifficulties  = validDifficulties,
        entrances          = entrances,
        entranceSource     = entranceSource,
    }
    ApplyTotals(entry, encounters)
    return entry
end

function JournalData:BuildJournalCache()
    if self.journalCache then return end
    self.journalCache = {}

    local membership = ns.JournalTierMembership
    local overrides = ns.JournalListingOverrides or { forceHide = {}, forceShow = {} }

    -- Index ATT instances / encounters per expansion, and union loot by instanceID.
    local instancesByExp = {}
    local encountersByExp = {}
    local itemsByEncByInst = {}
    local anyEncounterByID = {}

    for _, expansion in ipairs(expansionList) do
        local instancesGlobal  = _G["OneWoWInstances_"  .. expansion.name]
        local encountersGlobal = _G["OneWoWEncounters_" .. expansion.name]
        local itemsGlobal      = _G["OneWoWItems_"      .. expansion.name]

        if instancesGlobal then
            instancesByExp[expansion.expansionID] = instancesGlobal
        end
        if encountersGlobal then
            encountersByExp[expansion.expansionID] = encountersGlobal
            for encID, encInfo in pairs(encountersGlobal) do
                if not anyEncounterByID[encID] then
                    anyEncounterByID[encID] = encInfo
                end
            end
        end
        if itemsGlobal then
            for itemID, itemData in pairs(itemsGlobal) do
                if itemData.locations then
                    for _, loc in ipairs(itemData.locations) do
                        AddLocationEntry(itemsByEncByInst, itemID, itemData, loc)
                    end
                end
            end
        end
    end

    local function ResolveInstInfo(expansionID, instanceID)
        local primary = instancesByExp[expansionID] and instancesByExp[expansionID][instanceID]
        if primary then
            return primary
        end
        for _, expansion in ipairs(expansionList) do
            local bag = instancesByExp[expansion.expansionID]
            if bag and bag[instanceID] then
                return bag[instanceID]
            end
        end
        return nil
    end

    local function AddCard(expansionID, instanceID, orderIndex)
        local key = self.CacheKey(expansionID, instanceID)
        if overrides.forceHide and overrides.forceHide[key] then
            return
        end
        local encByID = itemsByEncByInst[instanceID] or {}
        local encounters = self:BuildEncountersForInstance(
            encByID,
            encountersByExp[expansionID],
            anyEncounterByID
        )
        local instInfo = ResolveInstInfo(expansionID, instanceID)
        self.journalCache[key] = MakeCacheEntry(
            expansionID, instanceID, orderIndex, instInfo, encounters
        )
    end

    if membership then
        for expansionID, cards in pairs(membership) do
            for instanceID, orderIndex in pairs(cards) do
                AddCard(expansionID, instanceID, orderIndex)
            end
        end
    else
        -- Membership missing: fall back to ATT instances (legacy single-key behavior avoided).
        for _, expansion in ipairs(expansionList) do
            local instancesGlobal = instancesByExp[expansion.expansionID]
            if instancesGlobal then
                for instanceID in pairs(instancesGlobal) do
                    AddCard(expansion.expansionID, instanceID, 0)
                end
            end
        end
    end

    if overrides.forceShow then
        for key in pairs(overrides.forceShow) do
            if not self.journalCache[key] then
                local expansionID, instanceID = strsplit(":", key)
                expansionID = tonumber(expansionID)
                instanceID = tonumber(instanceID)
                if expansionID and instanceID then
                    AddCard(expansionID, instanceID, 0)
                end
            end
        end
    end

    collectgarbage("collect")

    if ns.EJLiveLoot and ns.EJLiveLoot.ScheduleAfterStaticBuild then
        ns.EJLiveLoot:ScheduleAfterStaticBuild()
    end
end

function JournalData:SortEncountersInPlace(inst)
    if not inst or not inst.encounters then return end
    sort(inst.encounters, SortEncounters)
end

function JournalData:RecalculateInstanceTotals(inst)
    if not inst or not inst.encounters then return end
    ApplyTotals(inst, inst.encounters)
end

function JournalData:GetAllInstances()
    self:BuildJournalCache()
    local result = {}
    for _, inst in pairs(self.journalCache) do
        tinsert(result, inst)
    end
    return result
end

function JournalData:GetSortedInstances(expansionFilter, searchText, instanceTypeFilter)
    self:BuildJournalCache()
    local result = {}
    local search = searchText and searchText:lower() or ""

    for _, inst in pairs(self.journalCache) do
        local passesExpansion = (not expansionFilter or expansionFilter == 0 or inst.expansionID == expansionFilter)
        local passesSearch = (search == "" or inst.name:lower():find(search, 1, true)
                              or inst.expansionName:lower():find(search, 1, true))
        local passesType = (not instanceTypeFilter or instanceTypeFilter == "all"
                            or inst.instanceType == instanceTypeFilter)

        -- Membership cards with empty encounters stay visible (live merge pending).
        if passesExpansion and passesSearch and passesType then
            tinsert(result, inst)
        end
    end

    sort(result, function(a, b)
        if a.expansionID ~= b.expansionID then
            return a.expansionID > b.expansionID
        end
        if (a.orderIndex or 0) ~= (b.orderIndex or 0) then
            return (a.orderIndex or 0) < (b.orderIndex or 0)
        end
        return a.name < b.name
    end)

    return result
end

function JournalData:GetAvailableExpansions()
    self:BuildJournalCache()
    local present = {}
    for _, inst in pairs(self.journalCache) do
        present[inst.expansionID] = inst.expansionName
    end
    local result = {}
    for _, exp in ipairs(expansionList) do
        if present[exp.expansionID] then
            tinsert(result, { expansionID = exp.expansionID, displayName = exp.displayName })
        end
    end
    return result
end

--- All journal cards for a world map ID (dual-listed remakes may return two).
---@param mapID number
---@return table instances sorted by expansionID ascending
function JournalData:GetInstancesByMapID(mapID)
    self:BuildJournalCache()
    local result = {}
    if not mapID or not self.journalCache then
        return result
    end
    for _, data in pairs(self.journalCache) do
        if data.mapID == mapID then
            tinsert(result, data)
        end
    end
    sort(result, function(a, b)
        return a.expansionID < b.expansionID
    end)
    return result
end

--- Preferred card for a map ID (highest expansionID — remake face when dual-listed).
---@param mapID number
---@return table|nil instanceData
function JournalData:GetInstanceByMapID(mapID)
    local all = self:GetInstancesByMapID(mapID)
    if #all == 0 then
        return nil
    end
    return all[#all]
end

function JournalData:ClearCache()
    self.journalCache = nil
    if ns.EJLiveLoot and ns.EJLiveLoot.OnJournalCacheCleared then
        ns.EJLiveLoot:OnJournalCacheCleared()
    end
end

function JournalData:Initialize()
    self.initialized = true
end
