-- OneWoW Addon File
-- OneWoW_CatalogData_Journal/Modules/JournalData.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

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

function JournalData:DetermineItemSpecial(idata)
    if idata.isTransmog then
        return "TMog"
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
            if C_ToyBox and C_ToyBox.GetToyInfo then
                local _, _, _, isToy = C_ToyBox.GetToyInfo(itemID)
                if isToy then return "Toy" end
            end
            if C_MountJournal and C_MountJournal.GetMountFromItem then
                local mountID = C_MountJournal.GetMountFromItem(itemID)
                if mountID then return "Mount" end
            end
            if C_PetJournal and C_PetJournal.GetPetInfoByItemID then
                local _, _, _, _, _, _, _, _, _, _, _, _, speciesID = C_PetJournal.GetPetInfoByItemID(itemID)
                if speciesID and speciesID > 0 then return "Pet" end
            end
        end
    end

    return nil
end

function JournalData:IsItemCollected(itemID, itemData, specialType)
    if not itemID or not specialType then
        return nil
    end

    if specialType == "TMog" then
        if C_TransmogCollection then
            return C_TransmogCollection.PlayerHasTransmog(itemID)
        end
        return false
    end

    if specialType == "Mount" then
        local mountID = itemData.mountID
        if not mountID and C_MountJournal and C_MountJournal.GetMountFromItem then
            mountID = C_MountJournal.GetMountFromItem(itemID)
        end
        if mountID and C_MountJournal then
            local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
            return isCollected
        end
        return false
    end

    if specialType == "Pet" then
        local speciesID = itemData.speciesID
        if not speciesID and C_PetJournal and C_PetJournal.GetPetInfoByItemID then
            local _, _, _, _, _, _, _, _, _, _, _, _, sid = C_PetJournal.GetPetInfoByItemID(itemID)
            speciesID = sid
        end
        if speciesID and speciesID > 0 and C_PetJournal then
            local numCollected = C_PetJournal.GetNumCollectedInfo(speciesID)
            return (numCollected and numCollected > 0)
        end
        return false
    end

    if specialType == "Toy" then
        if PlayerHasToy then
            return PlayerHasToy(itemID)
        end
        return false
    end

    if specialType == "Recipe" then
        local spellID = itemData.spellID
        if spellID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
            local recipeInfo = C_TradeSkillUI.GetRecipeInfo(spellID)
            if recipeInfo and recipeInfo.learned ~= nil then
                return recipeInfo.learned
            end
        end
        local Util = _G.OneWoW_RecipeKnownUtil
        if Util then
            local result = Util:IsRecipeKnown(itemID, itemData.link)
            if result ~= nil then return result end
        end
        return nil
    end

    return nil
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
        return collected and L["JOURNAL_STATUS_COLLECTED"] or L["JOURNAL_STATUS_NOT_COLLECTED"]
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

                for encID, entries in pairs(encByID) do
                    local encInfo = encountersGlobal[encID]
                    local encName
                    local bossIndex = 0

                    if encID == 0 then
                        encName = L["JOURNAL_GENERAL_LOOT"]
                    elseif encInfo then
                        encName = encInfo.name or L["JOURNAL_UNKNOWN_INST"]
                        bossIndex = encInfo.bossIndex or 0
                    else
                        encName = L["JOURNAL_UNKNOWN_INST"]
                    end

                    local items = {}
                    for _, entry in ipairs(entries) do
                        local idata = entry.itemData
                        local itemRow = {
                            itemID       = entry.itemID,
                            itemData     = idata,
                            name         = idata.name or L["JOURNAL_UNKNOWN_ITEM"],
                            icon         = idata.icon or 134400,
                            quality      = idata.quality or 1,
                            special      = self:DetermineItemSpecial(idata),
                            difficulties = entry.difficulties or {},
                            source       = entry.source,
                        }
                        table.insert(items, itemRow)
                    end

                    table.sort(items, function(a, b)
                        return a.name < b.name
                    end)

                    table.insert(encounters, {
                        encounterID = encID,
                        name        = encName,
                        bossIndex   = bossIndex,
                        items       = items,
                    })
                end

                table.sort(encounters, function(a, b)
                    if a.encounterID == 0 then return false end
                    if b.encounterID == 0 then return true end
                    local ai = a.bossIndex or 999
                    local bi = b.bossIndex or 999
                    if ai ~= bi then return ai < bi end
                    return a.name < b.name
                end)

                local hasMounts, hasPets, hasToys, hasRecipes, hasQuest, hasHousing = false, false, false, false, false, false
                local totalItems = 0
                for _, enc in ipairs(encounters) do
                    for _, item in ipairs(enc.items) do
                        totalItems = totalItems + 1
                        if item.special == "Mount"   then hasMounts  = true end
                        if item.special == "Pet"     then hasPets    = true end
                        if item.special == "Toy"     then hasToys    = true end
                        if item.special == "Recipe"  then hasRecipes = true end
                        if item.special == "Quest"   then hasQuest   = true end
                        if item.special == "Housing" then hasHousing = true end
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
    table.sort(inst.encounters, function(a, b)
        if a.encounterID == 0 then return false end
        if b.encounterID == 0 then return true end
        local ai = a.bossIndex or 999
        local bi = b.bossIndex or 999
        if ai ~= bi then return ai < bi end
        return (a.name or "") < (b.name or "")
    end)
end

function JournalData:RecalculateInstanceTotals(inst)
    if not inst or not inst.encounters then return end
    local L = ns.L
    local hasMounts, hasPets, hasToys, hasRecipes, hasQuest, hasHousing = false, false, false, false, false, false
    local totalItems = 0
    for _, enc in ipairs(inst.encounters) do
        for _, item in ipairs(enc.items) do
            totalItems = totalItems + 1
            if item.special == "Mount"   then hasMounts  = true end
            if item.special == "Pet"     then hasPets    = true end
            if item.special == "Toy"     then hasToys    = true end
            if item.special == "Recipe"  then hasRecipes = true end
            if item.special == "Quest"   then hasQuest   = true end
            if item.special == "Housing" then hasHousing = true end
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
