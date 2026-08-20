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
    local name, link, quality, _, _, itemType, itemSubType, _, itemEquipLoc, icon = C_Item.GetItemInfo(itemID)
    if not icon then
        local _, instantType, instantSub, instantLoc, instantIcon = C_Item.GetItemInfoInstant(itemID)
        itemType = itemType or instantType
        itemSubType = itemSubType or instantSub
        itemEquipLoc = itemEquipLoc or instantLoc
        icon = instantIcon
    end
    if not name then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return {
        itemID      = itemID,
        name        = name,
        icon        = icon or 134400,
        quality     = quality or 1,
        itemType    = itemType or "",
        itemSubType = itemSubType or "",
        isTransmog  = itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" or false,
        link        = link,
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
        tinsert(items, {
            itemID       = entry.itemID,
            itemData     = idata,
            name         = (idata and idata.name) or L["JOURNAL_UNKNOWN_ITEM"],
            icon         = (idata and idata.icon) or 134400,
            quality      = (idata and idata.quality) or 1,
            special      = self:DetermineItemSpecial(idata or {}),
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
    ApplyTotals(entry, encounters)
    return entry
end

function JournalData:BuildJournalCache()
    if self.journalCache then return end
    self.journalCache = {}

    local membership = ns.JournalTierMembership
    local overrides = ns.JournalListingOverrides or { forceHide = {}, forceShow = {} }

    local ejItemOnInst = {}
    if ns.JournalLoot then
        for instanceID, rows in pairs(ns.JournalLoot) do
            local set = {}
            for _, row in ipairs(rows) do
                set[row.itemID] = true
            end
            ejItemOnInst[instanceID] = set
        end
    end

    -- Extras keyed by CacheKey. Legacy ATT tables stay expansion-scoped (no union).
    local extrasByKey = {}

    local function IsEJItem(instanceID, itemID)
        local set = instanceID and ejItemOnInst[instanceID]
        return set and set[itemID] == true
    end

    for _, expansion in ipairs(expansionList) do
        local extrasGlobal = _G["OneWoWExtras_" .. expansion.name]
        if extrasGlobal then
            for _, row in ipairs(extrasGlobal) do
                local itemID = row.itemID
                if itemID then
                    local instID = row.instanceID
                    local isWorld = row.world == true or (not instID or instID == 0)
                    if not isWorld and IsEJItem(instID, itemID) then
                        -- already on the Adventure Guide page
                    else
                        local key = isWorld
                            and self.CacheKey(expansion.expansionID, 0, "world")
                            or self.CacheKey(expansion.expansionID, instID)
                        AddExtraEntry(extrasByKey, key, itemID, row, row)
                    end
                end
            end
        end

        local itemsGlobal = _G["OneWoWItems_" .. expansion.name]
        if itemsGlobal then
            for itemID, itemData in pairs(itemsGlobal) do
                if itemData.locations then
                    for _, loc in ipairs(itemData.locations) do
                        local instID = loc.instanceID
                        local isWorld = loc.world == true or (not instID or instID == 0)
                        if not isWorld and IsEJItem(instID, itemID) then
                            -- skip Adventure Guide duplicates
                        elseif isWorld then
                            AddExtraEntry(
                                extrasByKey,
                                self.CacheKey(expansion.expansionID, 0, "world"),
                                itemID, itemData, loc
                            )
                        elseif instID then
                            AddExtraEntry(
                                extrasByKey,
                                self.CacheKey(expansion.expansionID, instID),
                                itemID, itemData, loc
                            )
                        end
                    end
                end
            end
        end
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

    local function FinishEncounters(expansionID, instanceID, instanceType)
        local key = self.CacheKey(expansionID, instanceID, instanceType)
        local encounters = {}
        if instanceType ~= "world" or (instanceID and instanceID > 0) then
            encounters = self:BuildEJEncounters(instanceID)
        end
        local extras = extrasByKey[key]
        -- Outdoor extras are keyed exp:world. MoP+ hub cards also need that pile.
        if ns.JournalWorldHubs and ns.JournalWorldHubs[instanceID] then
            extras = MergeExtrasLists(extras, extrasByKey[self.CacheKey(expansionID, 0, "world")])
        end
        local extrasEnc = self:BuildExtrasEncounter(extras)
        if extrasEnc then
            tinsert(encounters, extrasEnc)
        end
        sort(encounters, SortEncounters)
        return encounters
    end

    local function AddCard(expansionID, instanceID, orderIndex)
        local key = self.CacheKey(expansionID, instanceID)
        if overrides.forceHide and overrides.forceHide[key] then
            return
        end
        local encounters = FinishEncounters(expansionID, instanceID)
        self.journalCache[key] = MakeCacheEntry(
            expansionID, instanceID, orderIndex, nil, encounters
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
        local encounters = FinishEncounters(expansionID, 0, "world")
        self.journalCache[key] = MakeCacheEntry(
            expansionID,
            0,
            0,
            { name = name, instanceType = "world" },
            encounters
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
    return all[#all]
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
function JournalData:RefreshBountiful()
    wipe(self.bountifulMapIDs)
    self:BuildJournalCache()

    local nameToMap = {}
    local poiToMap = {}
    for _, inst in pairs(self.journalCache) do
        if inst.instanceType == "delve" and inst.mapID then
            nameToMap[inst.name] = inst.mapID
            for _, row in ipairs(inst.entrances or {}) do
                if row.bountifulPoiID then
                    poiToMap[row.bountifulPoiID] = inst.mapID
                end
            end
        end
    end

    local seenMaps = {}
    for _, inst in pairs(self.journalCache) do
        if inst.instanceType == "delve" then
            for _, row in ipairs(inst.entrances or {}) do
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
    wipe(self.bountifulMapIDs)
    if ns.EJLiveLoot and ns.EJLiveLoot.OnJournalCacheCleared then
        ns.EJLiveLoot:OnJournalCacheCleared()
    end
end

function JournalData:Initialize()
    self.initialized = true
end
