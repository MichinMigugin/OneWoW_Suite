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
local EXTRAS_ENC_ID = -4
JournalData.ACHIEVEMENT_ENC_ID = ACHIEVEMENT_ENC_ID
JournalData.QUEST_ENC_ID = QUEST_ENC_ID
JournalData.EXTRAS_ENC_ID = EXTRAS_ENC_ID

--- Composite cache / favorites key for a journal card.
---@param expansionID number
---@param instanceID number
---@param instanceType string|nil
---@return string
function JournalData.CacheKey(expansionID, instanceID, instanceType)
    if instanceType == "delve" then
        return tostring(expansionID) .. ":delve:" .. tostring(instanceID)
    end
    if instanceType == "world" and (not instanceID or instanceID == 0) then
        return tostring(expansionID) .. ":world"
    end
    return tostring(expansionID) .. ":" .. tostring(instanceID)
end

-- Encounter display order: bosses -> Achievement -> Quest -> General -> ATT extras.
local function EncounterSortRank(enc)
    if enc.encounterID == EXTRAS_ENC_ID then return 5 end
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

    if idata.isToy or idata.toyID then
        return "Toy"
    end

    if idata.isTransmog then
        return "TMog"
    end

    local classID = idata.classID
    local subclassID = idata.subclassID
    if classID == Enum.ItemClass.Recipe then
        return "Recipe"
    end
    if classID == Enum.ItemClass.Questitem then
        return "Quest"
    end
    if classID == Enum.ItemClass.Housing then
        return "Housing"
    end
    if classID == Enum.ItemClass.Battlepet then
        return "Pet"
    end
    if classID == Enum.ItemClass.Miscellaneous then
        if subclassID == Enum.ItemMiscellaneousSubclass.Mount then
            return "Mount"
        end
        if subclassID == Enum.ItemMiscellaneousSubclass.CompanionPet then
            return "Pet"
        end
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

    return nil
end

--- Toy / mount / pet journal probes for leftover Misc or Consumable rows.
--- Not called for every loot item: Enum class/subclass already covers most.
---
--- Runs per card rather than per visible row because its result feeds ApplyTotals,
--- which turns item.special into the card's hasToys / hasMounts / hasPets tags and
--- the collectible filters. Deferring to row paint would leave those wrong until
--- the player scrolled every row.
---@param idata table
---@return string|nil special
local function ProbeCollectibleSpecial(idata)
    local itemID = idata and idata.itemID
    if not itemID then
        return nil
    end
    local classID = idata.classID
    local itemType = idata.itemType or ""
    local isMisc = classID == Enum.ItemClass.Miscellaneous or itemType == "Miscellaneous"
    local isConsumable = classID == Enum.ItemClass.Consumable or itemType == "Consumable"
    if not isMisc and not isConsumable then
        return nil
    end

    local _, _, _, isToy = C_ToyBox.GetToyInfo(itemID)
    if isToy then
        idata.isToy = true
        return "Toy"
    end

    local mountID = C_MountJournal.GetMountFromItem(itemID)
    if mountID then
        idata.mountID = mountID
        return "Mount"
    end

    local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(itemID))
    if speciesID and speciesID > 0 then
        idata.speciesID = speciesID
        return "Pet"
    end
    return nil
end

---@param encounters table
local function ProbeLeftoverSpecials(encounters)
    for i = 1, #encounters do
        local items = encounters[i].items
        for j = 1, #items do
            local item = items[j]
            if not item.special then
                item.special = ProbeCollectibleSpecial(item.itemData or {})
            end
        end
    end
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

---@param diffIDs table|nil
---@return table
local function DiffRowsFromIDs(diffIDs)
    local rows = {}
    if not diffIDs then
        return rows
    end
    for _, did in ipairs(diffIDs) do
        local name = GetDifficultyInfo(did)
        if (not name or name == "") and ns.JournalDifficultyMeta and ns.JournalDifficultyMeta[did] then
            name = ns.JournalDifficultyMeta[did].name
        end
        tinsert(rows, { id = did, name = name or ("Difficulty " .. did) })
    end
    return rows
end

---@param itemID number
---@return table
local function ItemDataFromClient(itemID)
    -- Instant + name/quality by ID. Never GetItemInfo / RequestLoadItemDataByID
    -- here: that storm was the hitch when opening a raid card.
    local _, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID =
        C_Item.GetItemInfoInstant(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    local quality = C_Item.GetItemQualityByID(itemID)
    return {
        itemID      = itemID,
        name        = name,
        icon        = icon or 134400,
        quality     = quality == nil and 1 or quality,
        itemType    = itemType or "",
        itemSubType = itemSubType or "",
        classID     = classID,
        subclassID  = subclassID,
        isTransmog  = itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" or false,
        source      = "ej",
    }
end

--- ATT extras for one expansion+instance (or synthetic world). No cross-expansion union.
---@param extrasByKey table
---@param key string
---@param itemID number
---@param itemData table
---@param loc table
local function AddExtraEntry(extrasByKey, key, itemID, itemData, loc)
    extrasByKey[key] = extrasByKey[key] or {}
    local bucket = extrasByKey[key]
    for _, existing in ipairs(bucket) do
        if existing.itemID == itemID then
            return
        end
    end
    tinsert(bucket, {
        itemID       = itemID,
        itemData     = itemData,
        difficulties = loc.difficulties,
        source       = loc.source or "att",
        encounterID  = loc.encounterID or 0,
        instanceID   = loc.instanceID,
        npcID        = loc.npcID,
    })
end

local function MergeExtrasLists(a, b)
    if not a or #a == 0 then
        return b
    end
    if not b or #b == 0 then
        return a
    end
    local seen = {}
    local out = {}
    for i = 1, #a do
        local entry = a[i]
        local itemID = entry.itemID
        if itemID and not seen[itemID] then
            seen[itemID] = true
            tinsert(out, entry)
        end
    end
    for i = 1, #b do
        local entry = b[i]
        local itemID = entry.itemID
        if itemID and not seen[itemID] then
            seen[itemID] = true
            tinsert(out, entry)
        end
    end
    return out
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
            nameResolved = idata.name ~= nil,
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

--- Adventure Guide bosses + loot for one instance. IDs from Generated; names from DB2 / C_Item.
---@param instanceID number
---@return table encounters
function JournalData:BuildEJEncounters(instanceID)
    local L = ns.L
    local encList = ns.JournalEncounters and ns.JournalEncounters[instanceID]
    local lootList = ns.JournalLoot and ns.JournalLoot[instanceID]
    local itemsByEnc = {}
    if lootList then
        for _, row in ipairs(lootList) do
            local encID = row.encounterID
            itemsByEnc[encID] = itemsByEnc[encID] or {}
            local idata = ItemDataFromClient(row.itemID)
            tinsert(itemsByEnc[encID], {
                itemID       = row.itemID,
                itemData     = idata,
                name         = idata.name or L["JOURNAL_UNKNOWN_ITEM"],
                nameResolved = idata.name ~= nil,
                icon         = idata.icon,
                quality      = idata.quality,
                special      = self:DetermineItemSpecial(idata),
                difficulties = DiffRowsFromIDs(row.diffs),
                source       = "ej",
            })
        end
    end

    local function ByName(a, b)
        return (a.name or "") < (b.name or "")
    end

    local encounters = {}
    if encList then
        for _, enc in ipairs(encList) do
            local items = itemsByEnc[enc.id] or {}
            itemsByEnc[enc.id] = nil
            sort(items, ByName)
            tinsert(encounters, {
                encounterID = enc.id,
                name        = enc.name,
                bossIndex   = enc.order,
                items       = items,
            })
        end
    end
    for encID, items in pairs(itemsByEnc) do
        sort(items, ByName)
        tinsert(encounters, {
            encounterID = encID,
            name        = L["JOURNAL_UNKNOWN_INST"],
            bossIndex   = 999,
            items       = items,
        })
    end
    sort(encounters, SortEncounters)
    return encounters
end

--- One labeled extras pile. Does not mix into Adventure Guide boss rows.
---@param extras table|nil
---@return table|nil encounter
function JournalData:BuildExtrasEncounter(extras)
    if not extras or #extras == 0 then
        return nil
    end
    local L = ns.L
    local items = {}
    for _, entry in ipairs(extras) do
        local idata = entry.itemData
        local special = self:DetermineItemSpecial(idata or {})
        if not special then
            special = ProbeCollectibleSpecial(idata or {})
        end
        tinsert(items, {
            itemID       = entry.itemID,
            itemData     = idata,
            name         = (idata and idata.name) or L["JOURNAL_UNKNOWN_ITEM"],
            nameResolved = (idata and idata.name) ~= nil,
            icon         = (idata and idata.icon) or 134400,
            quality      = (idata and idata.quality) or 1,
            special      = special,
            difficulties = entry.difficulties or {},
            source       = entry.source or "att",
            questSources = idata and idata.questSources,
            npcID        = entry.npcID,
        })
    end
    sort(items, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return {
        encounterID     = EXTRAS_ENC_ID,
        name            = L["JOURNAL_ALSO_FROM_ATT"],
        bossIndex       = 999,
        items           = items,
        extrasCategory  = true,
    }
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

---@param mapID number
---@return table|nil
---@return string|nil
local function ResolveDelveEntrances(mapID)
    local db2 = ns.DelveEntrances and ns.DelveEntrances[mapID]
    if db2 and db2[1] then
        return db2, "db2"
    end
    return nil, nil
end

---@param mapID number|nil
---@param instanceType string
---@return table
local function AchievementsFor(mapID, instanceType)
    if not mapID then
        return {}
    end
    local src = instanceType == "delve" and ns.DelveAchievements or ns.JournalAchievements
    return (src and src[mapID]) or {}
end

---@param instanceID number
---@return number
local function CountGeneratedLoot(instanceID)
    local loot = ns.JournalLoot and ns.JournalLoot[instanceID]
    if not loot then
        return 0
    end
    local seen = {}
    local n = 0
    for i = 1, #loot do
        local itemID = loot[i].itemID
        if itemID and not seen[itemID] then
            seen[itemID] = true
            n = n + 1
        end
    end
    return n
end

---@param instanceID number
---@return number
local function CountGeneratedBosses(instanceID)
    local encs = ns.JournalEncounters and ns.JournalEncounters[instanceID]
    return encs and #encs or 0
end

local extrasCountByKey = nil

--- Unique non-achievement extras itemIDs per card key.
---
--- OneWoWExtras_* is pre-diffed against JournalLoot, so no extras itemID is also
--- an Adventure Guide drop on the same instance. Adding these counts to
--- CountGeneratedLoot therefore reproduces exactly what ApplyTotals will compute
--- once the card hydrates, from static data only - no C_Item, one pass over
--- ~8.5k rows per session.
local function BuildExtrasCounts()
    extrasCountByKey = {}
    local itemsByKey = {}

    for _, exp in ipairs(expansionList) do
        local rows = _G["OneWoWExtras_" .. exp.name]
        if rows then
            local worldKey = JournalData.CacheKey(exp.expansionID, 0, "world")
            for i = 1, #rows do
                local row = rows[i]
                local itemID = row.itemID
                -- ApplyTotals excludes achievement-gated loot from the total.
                if itemID and not row.achievementID then
                    local instID = row.instanceID
                    local key = (row.world == true or not instID or instID == 0)
                        and worldKey
                        or JournalData.CacheKey(exp.expansionID, instID)
                    local set = itemsByKey[key]
                    if not set then
                        set = {}
                        itemsByKey[key] = set
                    end
                    set[itemID] = true
                end
            end
        end
    end

    local function SetSize(set)
        local n = 0
        for _ in pairs(set) do
            n = n + 1
        end
        return n
    end

    for key, set in pairs(itemsByKey) do
        extrasCountByKey[key] = SetSize(set)
    end

    -- A world hub card also shows its expansion's world pile, and
    -- MergeExtrasLists dedupes by itemID, so those keys need a union not a sum.
    if ns.JournalWorldHubs then
        for _, exp in ipairs(expansionList) do
            local worldSet = itemsByKey[JournalData.CacheKey(exp.expansionID, 0, "world")]
            if worldSet then
                for instanceID in pairs(ns.JournalWorldHubs) do
                    local key = JournalData.CacheKey(exp.expansionID, instanceID)
                    local merged = {}
                    for itemID in pairs(itemsByKey[key] or {}) do
                        merged[itemID] = true
                    end
                    for itemID in pairs(worldSet) do
                        merged[itemID] = true
                    end
                    extrasCountByKey[key] = SetSize(merged)
                end
            end
        end
    end
end

---@param expansionID number
---@param instanceID number
---@param instanceType string|nil
---@return number
local function CountExtrasLoot(expansionID, instanceID, instanceType)
    if not extrasCountByKey then
        BuildExtrasCounts()
    end
    return extrasCountByKey[JournalData.CacheKey(expansionID, instanceID, instanceType)] or 0
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
    local name = (ejMeta and ejMeta.name)
        or (instInfo and instInfo.name)
        or L["JOURNAL_UNKNOWN_INST"]
    local instanceType
    if instInfo and instInfo.instanceType then
        instanceType = instInfo.instanceType
    elseif ns.JournalWorldHubs and ns.JournalWorldHubs[instanceID] then
        instanceType = "world"
    elseif ejMeta and ejMeta.instanceType then
        instanceType = ejMeta.instanceType
    else
        instanceType = "party"
    end
    local validDifficulties = nil
    if mapID and ns.JournalMapDifficulties then
        validDifficulties = ns.JournalMapDifficulties[mapID]
    end

    local entrances, entranceSource
    if instanceType == "delve" then
        entrances, entranceSource = ResolveDelveEntrances(mapID)
    else
        entrances, entranceSource = ResolveEntrances(instanceID)
    end

    local entry = {
        cacheKey           = JournalData.CacheKey(expansionID, instanceID, instanceType),
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
        achievements       = AchievementsFor(mapID, instanceType),
    }
    -- Skeleton cards skip ApplyTotals / C_Item. Hydrate via EnsureEncounters.
    -- totalItems must already match what ApplyTotals will compute, or the count
    -- visibly changes when the player opens the card.
    if instanceType == "delve" then
        entry.encountersHydrated = true
        entry.totalItems = 0
        entry.bossCount = 0
    elseif instanceType == "world" and (not instanceID or instanceID == 0) then
        -- Synthetic world cards carry extras only; live ATT may add more on open.
        entry.encountersHydrated = false
        entry.totalItems = CountExtrasLoot(expansionID, instanceID, instanceType)
        entry.bossCount = 0
    else
        entry.encountersHydrated = false
        entry.totalItems = CountGeneratedLoot(instanceID)
            + CountExtrasLoot(expansionID, instanceID, instanceType)
        entry.bossCount = CountGeneratedBosses(instanceID)
    end
    return entry
end

function JournalData:BuildJournalCache()
    if self.journalCache then return end
    self.journalCache = {}

    local membership = ns.JournalTierMembership
    local overrides = ns.JournalListingOverrides or { forceHide = {}, forceShow = {} }

    -- Skeleton cards only: names, map, achievements, Generated loot/boss counts.
    -- Loot rows and ATT extras hydrate in EnsureEncounters (one card at a time).
    local function AddCard(expansionID, instanceID, orderIndex)
        local key = self.CacheKey(expansionID, instanceID)
        if overrides.forceHide and overrides.forceHide[key] then
            return
        end
        self.journalCache[key] = MakeCacheEntry(
            expansionID, instanceID, orderIndex, nil, {}
        )
    end

    local function AddSyntheticWorldCard(expansionID)
        local key = self.CacheKey(expansionID, 0, "world")
        if overrides.forceHide and overrides.forceHide[key] then
            return
        end
        if self.journalCache[key] then
            return
        end
        local exp = expansionByID[expansionID]
        local name = (exp and exp.displayName or tostring(expansionID)) .. " - " .. WORLD
        self.journalCache[key] = MakeCacheEntry(
            expansionID,
            0,
            0,
            { name = name, instanceType = "world" },
            {}
        )
    end

    local function AddDelveCard(expansionID, mapID, orderIndex, name)
        local key = self.CacheKey(expansionID, mapID, "delve")
        if overrides.forceHide and overrides.forceHide[key] then
            return
        end
        self.journalCache[key] = MakeCacheEntry(
            expansionID,
            mapID,
            orderIndex,
            { name = name, mapID = mapID, instanceType = "delve" },
            {}
        )
    end

    if membership then
        for expansionID, cards in pairs(membership) do
            for instanceID, orderIndex in pairs(cards) do
                AddCard(expansionID, instanceID, orderIndex)
            end
        end
    end

    local synth = ns.JournalSyntheticWorldExpansions
    if synth then
        for i = 1, #synth do
            AddSyntheticWorldCard(synth[i])
        end
    end

    if ns.DelveMembership then
        for expansionID, cards in pairs(ns.DelveMembership) do
            for mapID, info in pairs(cards) do
                AddDelveCard(expansionID, mapID, info.order, info.name)
            end
        end
    end

    if overrides.forceShow then
        for key in pairs(overrides.forceShow) do
            if not self.journalCache[key] then
                local expansionID, mid, mapID = strsplit(":", key)
                expansionID = tonumber(expansionID)
                if mid == "delve" then
                    mapID = tonumber(mapID)
                    if expansionID and mapID then
                        local delveInfo = ns.DelveMembership
                            and ns.DelveMembership[expansionID]
                            and ns.DelveMembership[expansionID][mapID]
                        AddDelveCard(expansionID, mapID, 0, delveInfo and delveInfo.name)
                    end
                elseif mid == "world" then
                    if expansionID then
                        AddSyntheticWorldCard(expansionID)
                    end
                else
                    local instanceID = tonumber(mid)
                    if expansionID and instanceID then
                        AddCard(expansionID, instanceID, 0)
                    end
                end
            end
        end
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

function JournalData:EnsureEJItemSets()
    if self.ejItemOnInst then
        return
    end
    self.ejItemOnInst = {}
    if not ns.JournalLoot then
        return
    end
    for instanceID, rows in pairs(ns.JournalLoot) do
        local set = {}
        for i = 1, #rows do
            local itemID = rows[i].itemID
            if itemID then
                set[itemID] = true
            end
        end
        self.ejItemOnInst[instanceID] = set
    end
end

--- Bucket ATT extras for one expansion. No C_Item. Idempotent per expansionID.
---@param expansionID number
function JournalData:EnsureExtrasForExpansion(expansionID)
    self.extrasByKey = self.extrasByKey or {}
    self.extrasReady = self.extrasReady or {}
    if self.extrasReady[expansionID] then
        return
    end
    local exp = expansionByID[expansionID]
    if not exp then
        self.extrasReady[expansionID] = true
        return
    end
    self:EnsureEJItemSets()
    local extrasByKey = self.extrasByKey
    local function IsEJItem(instanceID, itemID)
        local set = instanceID and self.ejItemOnInst[instanceID]
        return set and set[itemID] == true
    end

    -- OneWoWExtras_* is pre-diffed against JournalLoot by bin/journal_extras.py,
    -- so this walks ~700 rows per expansion instead of every legacy item and its
    -- locations. IsEJItem still runs: the Adventure Guide moves loot between
    -- patches, and a row that became an EJ drop must not double-list.
    local extrasGlobal = _G["OneWoWExtras_" .. exp.name]
    if extrasGlobal then
        for _, row in ipairs(extrasGlobal) do
            local itemID = row.itemID
            if itemID then
                local instID = row.instanceID
                local isWorld = row.world == true or (not instID or instID == 0)
                if isWorld or not IsEJItem(instID, itemID) then
                    local key = isWorld
                        and self.CacheKey(expansionID, 0, "world")
                        or self.CacheKey(expansionID, instID)
                    AddExtraEntry(extrasByKey, key, itemID, row, row)
                end
            end
        end
    end

    self.extrasReady[expansionID] = true
end

local function AttachHydratedEncounters(inst, encounters)
    inst.encounters = encounters
    ApplyTotals(inst, encounters)
    inst.encountersHydrated = true
    inst.bossCount = nil
end

--- Hydrate loot for one card. Idempotent.
---
--- Dual-listed remakes hydrate separately on purpose. Extras are expansion-scoped,
--- so only the Adventure Guide half could ever be shared, and sharing it would mean
--- two cards holding the same mutable encounter and item rows. Only 5 of 212
--- instances are dual-listed (353 JournalLoot rows total), and the duplicate cost
--- lands only if the player opens both cards, so the coupling is not worth it.
---@param inst table
---@return table inst
function JournalData:EnsureEncounters(inst)
    if not inst or inst.encountersHydrated then
        return inst
    end
    self:BuildJournalCache()
    if inst.instanceType == "delve" then
        inst.encountersHydrated = true
        return inst
    end

    local expansionID = inst.expansionID
    local instanceID = inst.instanceID
    local instanceType = inst.instanceType
    self:EnsureExtrasForExpansion(expansionID)

    local key = inst.cacheKey or self.CacheKey(expansionID, instanceID, instanceType)
    local extrasByKey = self.extrasByKey or {}
    local encounters = {}
    if instanceType ~= "world" or (instanceID and instanceID > 0) then
        encounters = self:BuildEJEncounters(instanceID)
    end
    local extras = extrasByKey[key]
    if ns.JournalWorldHubs and ns.JournalWorldHubs[instanceID] then
        extras = MergeExtrasLists(extras, extrasByKey[self.CacheKey(expansionID, 0, "world")])
    end
    local extrasEnc = self:BuildExtrasEncounter(extras)
    if extrasEnc then
        tinsert(encounters, extrasEnc)
    end
    sort(encounters, SortEncounters)

    ProbeLeftoverSpecials(encounters)
    AttachHydratedEncounters(inst, encounters)
    return inst
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

        -- Skeleton cards have empty encounters until EnsureEncounters.
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

function JournalData:GetAvailableExpansions(typeFilter)
    self:BuildJournalCache()
    local present = {}
    for _, inst in pairs(self.journalCache) do
        if not typeFilter or typeFilter == "all" or inst.instanceType == typeFilter then
            present[inst.expansionID] = inst.expansionName
        end
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
    local inst = all[#all]
    self:EnsureEncounters(inst)
    return inst
end

--- Flat itemID -> localized name for every journal drop.
---
--- Generated `JournalItemNames` covers Adventure Guide loot; extras rows carry
--- their own name and are folded in on first use. Consumers text-match against
--- this instead of `C_Item.GetItemNameByID`, which returns nil for any item the
--- client has not cached and would silently drop most loot from a name search.
---@return table<number, string>
function JournalData:GetItemNameIndex()
    local names = ns.JournalItemNames
    if self.itemNamesMerged then
        return names
    end
    for _, exp in ipairs(expansionList) do
        local rows = _G["OneWoWExtras_" .. exp.name]
        if rows then
            for i = 1, #rows do
                local row = rows[i]
                if row.itemID and row.name and not names[row.itemID] then
                    names[row.itemID] = row.name
                end
            end
        end
    end
    self.itemNamesMerged = true
    return names
end

--- itemID -> every place it drops. Built once, on first query only: nothing in
--- the Journal's own UI needs it, so a player who never opens Item Search or
--- hovers an item with the tracker tooltip never pays for it.
function JournalData:EnsureDropIndex()
    if self.dropIndex then
        return
    end
    local index = {}
    local encounterNames = {}

    local function Add(itemID, instanceID, encounterID, difficulties)
        local rows = index[itemID]
        if not rows then
            rows = {}
            index[itemID] = rows
        end
        tinsert(rows, {
            instanceID   = instanceID,
            encounterID  = encounterID or 0,
            difficulties = difficulties,
        })
    end

    for _, encs in pairs(ns.JournalEncounters) do
        for i = 1, #encs do
            local enc = encs[i]
            encounterNames[enc.id] = enc.name
        end
    end

    for instanceID, rows in pairs(ns.JournalLoot) do
        for i = 1, #rows do
            local row = rows[i]
            if row.itemID then
                Add(row.itemID, instanceID, row.encounterID, DiffRowsFromIDs(row.diffs))
            end
        end
    end

    for _, exp in ipairs(expansionList) do
        local rows = _G["OneWoWExtras_" .. exp.name]
        if rows then
            for i = 1, #rows do
                local row = rows[i]
                -- World extras have no instance card to name, so they are not a
                -- "drops from" location for tooltip or detail purposes.
                if row.itemID and row.instanceID and row.instanceID ~= 0 then
                    Add(row.itemID, row.instanceID, row.encounterID, row.difficulties)
                end
            end
        end
    end

    self.dropIndex = index
    self.encounterNames = encounterNames
end

--- Instance / encounter names for every place an item drops. Deduped per
--- instance+encounter pair, in index order.
---@param itemID number
---@return table drops array of { instanceName, encounterName, difficulties }
function JournalData:GetItemDropLocations(itemID)
    local out = {}
    if not itemID then
        return out
    end
    self:EnsureDropIndex()
    local rows = self.dropIndex[itemID]
    if not rows then
        return out
    end
    local seen = {}
    for i = 1, #rows do
        local row = rows[i]
        local key = row.instanceID .. ":" .. row.encounterID
        if not seen[key] then
            seen[key] = true
            local meta = ns.JournalInstanceMeta[row.instanceID]
            tinsert(out, {
                instanceID    = row.instanceID,
                instanceName  = meta and meta.name,
                encounterName = row.encounterID ~= 0 and self.encounterNames[row.encounterID] or nil,
                difficulties  = row.difficulties,
            })
        end
    end
    return out
end

JournalData.bountifulMapIDs = {}

local function MarkBountifulFromPOI(self, uiMapID, poiID, poiToMap, nameToMap)
    local mapped = poiToMap[poiID]
    if mapped then
        self.bountifulMapIDs[mapped] = true
        return
    end
    local info = C_AreaPoiInfo.GetAreaPOIInfo(uiMapID, poiID)
    local atlas = info and info.atlasName
    if atlas and atlas:lower():find("bountiful", 1, true) then
        local mid = info.name and nameToMap[info.name]
        if mid then
            self.bountifulMapIDs[mid] = true
        end
    end
end

local function WalkDelveMaps(self, startID, seenMaps, poiToMap, nameToMap)
    local uiMapID = startID
    while uiMapID and uiMapID ~= 0 and not seenMaps[uiMapID] do
        seenMaps[uiMapID] = true
        local pois = C_AreaPoiInfo.GetDelvesForMap(uiMapID)
        if pois then
            for i = 1, #pois do
                MarkBountifulFromPOI(self, uiMapID, pois[i], poiToMap, nameToMap)
            end
        end
        local mapInfo = C_Map.GetMapInfo(uiMapID)
        uiMapID = mapInfo and mapInfo.parentMapID
    end
end

--- Live bountiful doors this week. atlasName or generated bountifulPoiID.
-- Reads DelveMembership / DelveEntrances only. Must not call BuildJournalCache:
-- PEW runs this for every login, and hydrating every journal card there stalls movement.
function JournalData:RefreshBountiful()
    wipe(self.bountifulMapIDs)

    local nameToMap = {}
    local poiToMap = {}
    local membership = ns.DelveMembership
    if membership then
        for _, cards in pairs(membership) do
            for mapID, info in pairs(cards) do
                if info and info.name then
                    nameToMap[info.name] = mapID
                end
            end
        end
    end

    local seenMaps = {}
    local entrances = ns.DelveEntrances
    if entrances then
        for mapID, rows in pairs(entrances) do
            for i = 1, #rows do
                local row = rows[i]
                if row.bountifulPoiID then
                    poiToMap[row.bountifulPoiID] = mapID
                end
            end
        end
        for _, rows in pairs(entrances) do
            for i = 1, #rows do
                local row = rows[i]
                if row.mapID and row.mapID ~= 0 then
                    local uiMapID = C_Map.GetMapPosFromWorldPos(row.mapID, CreateVector2D(row.x, row.y))
                    WalkDelveMaps(self, uiMapID, seenMaps, poiToMap, nameToMap)
                end
            end
        end
    end

    -- Midnight doors often ship ContinentID 0; the player map still lists live POIs.
    local playerMap = C_Map.GetBestMapForUnit("player")
    if playerMap then
        WalkDelveMaps(self, playerMap, seenMaps, poiToMap, nameToMap)
    end
end

---@param mapID number|nil
---@return boolean
function JournalData:IsDelveBountiful(mapID)
    return mapID ~= nil and self.bountifulMapIDs[mapID] == true
end

function JournalData:ClearCache()
    self.journalCache = nil
    self.extrasByKey = nil
    self.extrasReady = nil
    self.ejItemOnInst = nil
    wipe(self.bountifulMapIDs)
    if ns.EJLiveLoot and ns.EJLiveLoot.OnJournalCacheCleared then
        ns.EJLiveLoot:OnJournalCacheCleared()
    end
end

function JournalData:Initialize()
    self.initialized = true
end
