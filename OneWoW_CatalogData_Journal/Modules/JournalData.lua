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

JournalData.journalCache = nil
JournalData.initialized = false

-- Synthetic encounters that pull achievement-tied and quest-obtained loot out of
-- the General bucket, so "General" only holds items not tied to a boss,
-- achievement, or quest.
local ACHIEVEMENT_ENC_ID = -2
local QUEST_ENC_ID = -3
JournalData.ACHIEVEMENT_ENC_ID = ACHIEVEMENT_ENC_ID
JournalData.QUEST_ENC_ID = QUEST_ENC_ID

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

-- Journal special types that carry a "collected" badge. Others (Achievement,
-- Quest, Housing, …) intentionally show no badge, so IsItemCollected returns nil
-- for them regardless of whether Collectibles could resolve a key.
local BADGE_SPECIAL_TYPES = {
    TMog = true, Mount = true, Pet = true, Toy = true, Recipe = true,
}

-- Collection state for a journal item, delegated to the shared Collectibles
-- facade so journal badges stay in lockstep with tooltips and overlays.
-- Returns nil to hide the badge: no itemID/specialType, a non-badge special
-- type, or a Recipe whose taught spell can't be resolved to a collectible key
-- (showing no badge rather than a misleading "Unknown"). Mount/Pet/Toy/TMog
-- fall back to false (not owned) when no collectible key resolves, matching the
-- prior direct-API behavior. `itemData` is retained for signature compatibility.
---@diagnostic disable-next-line: unused-local
function JournalData:IsItemCollected(itemID, itemData, specialType)
    if not itemID or not specialType or not BADGE_SPECIAL_TYPES[specialType] then
        return nil
    end

    local Collectibles = OneWoW.Collectibles
    if Collectibles then
        local status = Collectibles.GetItemCollectionStatus(itemID)
        if status then
            return status.collected
        end
    end

    -- No resolvable collectible key: hide the badge for recipes (indeterminate),
    -- report not-owned for the deterministic collection types.
    if specialType == "Recipe" then
        return nil
    end
    return false
end

function JournalData:DetermineItemStatus(itemID, itemData, specialType)
    if not itemID or not specialType then
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

    if specialType == "Mount" or specialType == "Pet" or specialType == "Toy" or specialType == "Recipe" then
        return collected and L["JOURNAL_STATUS_KNOWN"] or L["JOURNAL_STATUS_UNKNOWN"]
    end

    return nil
end

function JournalData:BuildJournalCache()
    if self.journalCache then return end
    self.journalCache = {}

    local L = ns.L

    for _, expansion in ipairs(expansionList) do
        local instancesGlobal  = _G["OneWoWInstances_"  .. expansion.name]
        local encountersGlobal = _G["OneWoWEncounters_" .. expansion.name]
        local itemsGlobal      = _G["OneWoWItems_"      .. expansion.name]

        if instancesGlobal and encountersGlobal and itemsGlobal then
            local itemsByEncByInst = {}
            for itemID, itemData in pairs(itemsGlobal) do
                if itemData.locations then
                    for _, loc in ipairs(itemData.locations) do
                        local instID = loc.instanceID
                        local encID  = loc.encounterID or 0
                        if instID then
                            itemsByEncByInst[instID] = itemsByEncByInst[instID] or {}
                            itemsByEncByInst[instID][encID] = itemsByEncByInst[instID][encID] or {}
                            local entry = {
                                itemID       = itemID,
                                itemData     = itemData,
                                difficulties = loc.difficulties,
                                source       = loc.source,
                                encounterID  = encID,
                                instanceID   = instID,
                            }
                            table.insert(itemsByEncByInst[instID][encID], entry)
                        end
                    end
                end
            end

            for instanceID, instInfo in pairs(instancesGlobal) do
                local encByID = itemsByEncByInst[instanceID] or {}
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
                        -- General loot: pull quest-obtained and achievement-tied items
                        -- into their own encounters so true general loot stays clean.
                        -- Priority: a quest source (how you obtain it) wins over an
                        -- achievement tag.
                        local generalItems, achievementItems, questItems = {}, {}, {}
                        for _, entry in ipairs(entries) do
                            local itemRow = MakeItemRow(entry)
                            if itemRow.questSources and #itemRow.questSources > 0 then
                                table.insert(questItems, itemRow)
                            elseif itemRow.special == "Achievement" then
                                table.insert(achievementItems, itemRow)
                            else
                                table.insert(generalItems, itemRow)
                            end
                        end

                        if #generalItems > 0 then
                            table.sort(generalItems, ByName)
                            table.insert(encounters, {
                                encounterID = 0,
                                name        = L["JOURNAL_GENERAL_LOOT"],
                                bossIndex   = 0,
                                items       = generalItems,
                            })
                        end
                        if #achievementItems > 0 then
                            table.sort(achievementItems, ByName)
                            table.insert(encounters, {
                                encounterID = ACHIEVEMENT_ENC_ID,
                                name        = L["JOURNAL_ACHIEVEMENT_LOOT"],
                                bossIndex   = 0,
                                items       = achievementItems,
                            })
                        end
                        if #questItems > 0 then
                            table.sort(questItems, ByName)
                            table.insert(encounters, {
                                encounterID  = QUEST_ENC_ID,
                                name         = L["JOURNAL_QUEST_LOOT"],
                                bossIndex    = 0,
                                items        = questItems,
                                questCategory = true,
                            })
                        end
                    else
                        local encInfo = encountersGlobal[encID]
                        local encName = L["JOURNAL_UNKNOWN_INST"]
                        local bossIndex = 0
                        if encInfo then
                            encName = encInfo.name or L["JOURNAL_UNKNOWN_INST"]
                            bossIndex = encInfo.bossIndex or 0
                        end

                        local items = {}
                        for _, entry in ipairs(entries) do
                            table.insert(items, MakeItemRow(entry))
                        end
                        table.sort(items, ByName)

                        table.insert(encounters, {
                            encounterID = encID,
                            name        = encName,
                            bossIndex   = bossIndex,
                            items       = items,
                        })
                    end
                end

                table.sort(encounters, SortEncounters)

                local hasMounts, hasPets, hasToys, hasRecipes, hasQuest, hasHousing = false, false, false, false, false, false
                local totalItems = 0
                -- Count each unique itemID once regardless of how many encounter
                -- locations it appears in (e.g. both general loot and a boss drop).
                -- Achievement-gated items are excluded from the loot count entirely.
                local seenItemIDs = {}
                for _, enc in ipairs(encounters) do
                    for _, item in ipairs(enc.items) do
                        if item.special ~= "Achievement" and not seenItemIDs[item.itemID] then
                            seenItemIDs[item.itemID] = true
                            totalItems = totalItems + 1
                            if item.special == "Mount"   then hasMounts  = true end
                            if item.special == "Pet"     then hasPets    = true end
                            if item.special == "Toy"     then hasToys    = true end
                            if item.special == "Recipe"  then hasRecipes = true end
                            if item.special == "Quest"   then hasQuest   = true end
                            if item.special == "Housing" then hasHousing = true end
                        end
                    end
                end

                self.journalCache[instanceID] = {
                    instanceID    = instanceID,
                    name          = instInfo.name or L["JOURNAL_UNKNOWN_INST"],
                    mapID         = instInfo.mapID,
                    instanceType  = instInfo.instanceType or "party",
                    expansionID   = instInfo.expansionID or expansion.expansionID,
                    expansionName = expansion.displayName,
                    encounters    = encounters,
                    hasMounts     = hasMounts,
                    hasPets       = hasPets,
                    hasToys       = hasToys,
                    hasRecipes    = hasRecipes,
                    hasQuest      = hasQuest,
                    hasHousing    = hasHousing,
                    totalItems    = totalItems,
                }
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
    table.sort(inst.encounters, SortEncounters)
end

function JournalData:RecalculateInstanceTotals(inst)
    if not inst or not inst.encounters then return end
    local hasMounts, hasPets, hasToys, hasRecipes, hasQuest, hasHousing = false, false, false, false, false, false
    local totalItems = 0
    local seenItemIDs = {}
    for _, enc in ipairs(inst.encounters) do
        for _, item in ipairs(enc.items) do
            if item.special ~= "Achievement" and not seenItemIDs[item.itemID] then
                seenItemIDs[item.itemID] = true
                totalItems = totalItems + 1
                if item.special == "Mount"   then hasMounts  = true end
                if item.special == "Pet"     then hasPets    = true end
                if item.special == "Toy"     then hasToys    = true end
                if item.special == "Recipe"  then hasRecipes = true end
                if item.special == "Quest"   then hasQuest   = true end
                if item.special == "Housing" then hasHousing = true end
            end
        end
    end
    inst.hasMounts     = hasMounts
    inst.hasPets       = hasPets
    inst.hasToys       = hasToys
    inst.hasRecipes    = hasRecipes
    inst.hasQuest      = hasQuest
    inst.hasHousing    = hasHousing
    inst.totalItems    = totalItems
end

function JournalData:GetAllInstances()
    self:BuildJournalCache()
    local result = {}
    for _, inst in pairs(self.journalCache) do
        table.insert(result, inst)
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

        if passesExpansion and passesSearch and passesType and #inst.encounters > 0 then
            table.insert(result, inst)
        end
    end

    table.sort(result, function(a, b)
        if a.expansionID ~= b.expansionID then
            return a.expansionID > b.expansionID
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
            table.insert(result, { expansionID = exp.expansionID, displayName = exp.displayName })
        end
    end
    return result
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
