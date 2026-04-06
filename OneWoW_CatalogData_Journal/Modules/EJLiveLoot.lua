-- OneWoW Addon File
-- OneWoW_CatalogData_Journal/Modules/EJLiveLoot.lua
-- Merges live Encounter Journal loot into the static journal cache (same pattern as common EJ tools).
local addonName, ns = ...

local JournalData = ns.JournalData
local EJLive = {}
ns.EJLiveLoot = EJLive

local CEJ = C_EncounterJournal or {}

local function EJ_Call(cejName, globalName, ...)
    if CEJ[cejName] then
        return CEJ[cejName](...)
    elseif _G[globalName] then
        return _G[globalName](...)
    end
    return nil
end

local function EJ_SelectInstanceCompat(instanceID)
    return EJ_Call("SelectInstance", "EJ_SelectInstance", instanceID)
end
local function EJ_GetEncounterInfoByIndexCompat(index)
    return EJ_Call("GetEncounterInfoByIndex", "EJ_GetEncounterInfoByIndex", index)
end
local function EJ_SelectEncounterCompat(encounterID)
    return EJ_Call("SelectEncounter", "EJ_SelectEncounter", encounterID)
end
local function EJ_SetDifficultyCompat(diffID)
    return EJ_Call("SetDifficulty", "EJ_SetDifficulty", diffID)
end
local function EJ_SetLootFilterCompat(classID, specID)
    return EJ_Call("SetLootFilter", "EJ_SetLootFilter", classID, specID)
end
local function EJ_SetSlotFilterCompat(slotFilter)
    return EJ_Call("SetSlotFilter", "EJ_SetSlotFilter", slotFilter)
end
local function EJ_GetNumLootCompat()
    return EJ_Call("GetNumLoot", "EJ_GetNumLoot") or 0
end
local function EJ_GetLootInfoByIndexCompat(index)
    if CEJ.GetLootInfoByIndex then
        return CEJ.GetLootInfoByIndex(index)
    end
    if _G.EJ_GetLootInfoByIndex then
        local name, icon, slot, armorType, itemID, itemLink = _G.EJ_GetLootInfoByIndex(index)
        if name then
            return { name = name, icon = icon, itemID = itemID, link = itemLink }
        end
    end
    return nil
end
local function EJ_GetSlotFilterCompat()
    return EJ_Call("GetSlotFilter", "EJ_GetSlotFilter")
end
local function EJ_GetLootFilterCompat()
    if CEJ.GetLootFilter then
        return CEJ.GetLootFilter()
    elseif _G.EJ_GetLootFilter then
        return _G.EJ_GetLootFilter()
    end
    return nil, nil
end

local EISFT = Enum.ItemSlotFilterType

local WORLD_BOSS_INSTANCE_ID = 1312

local DUNGEON_DIFFS = {
    { id = 1,  key = "N" },
    { id = 2,  key = "H" },
    { id = 23, key = "M" },
    { id = 8,  key = "M+" },
}

local RAID_DIFFS = {
    { id = 17, key = "LFR" },
    { id = 14, key = "N" },
    { id = 15, key = "H" },
    { id = 16, key = "M" },
}

local WB_TRY_DIFFS = { 0, 14, 15 }

local ejOriginalOnEvent = nil
local ejSuppressCount = 0
local ejSavedDifficulty = nil
local ejSavedSlotFilter = nil
local ejSavedLootClassID = nil
local ejSavedLootSpecID = nil

local function SuppressEJ()
    ejSuppressCount = ejSuppressCount + 1
    if ejSuppressCount > 1 then return end
    if not EncounterJournal then return end
    ejSavedDifficulty = EJ_Call("GetDifficulty", "EJ_GetDifficulty")
    ejSavedSlotFilter = EJ_GetSlotFilterCompat()
    ejSavedLootClassID, ejSavedLootSpecID = EJ_GetLootFilterCompat()
    ejOriginalOnEvent = EncounterJournal:GetScript("OnEvent")
    EncounterJournal:SetScript("OnEvent", nil)
    EncounterJournal:UnregisterEvent("EJ_LOOT_DATA_RECIEVED")
    EncounterJournal:UnregisterEvent("EJ_DIFFICULTY_UPDATE")
    EncounterJournal:UnregisterEvent("UNIT_LEVEL")
end

local function UnsuppressEJ()
    ejSuppressCount = ejSuppressCount - 1
    if ejSuppressCount > 0 then return end
    ejSuppressCount = 0
    if not EncounterJournal then return end
    if ejSavedDifficulty ~= nil then
        EJ_SetDifficultyCompat(ejSavedDifficulty)
        ejSavedDifficulty = nil
    end
    if ejSavedSlotFilter ~= nil then
        EJ_SetSlotFilterCompat(ejSavedSlotFilter)
        ejSavedSlotFilter = nil
    end
    if ejSavedLootClassID and ejSavedLootSpecID then
        EJ_SetLootFilterCompat(ejSavedLootClassID, ejSavedLootSpecID)
        ejSavedLootClassID = nil
        ejSavedLootSpecID = nil
    end
    if ejOriginalOnEvent then
        EncounterJournal:SetScript("OnEvent", ejOriginalOnEvent)
        ejOriginalOnEvent = nil
    end
    EncounterJournal:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
    EncounterJournal:RegisterEvent("EJ_DIFFICULTY_UPDATE")
    EncounterJournal:RegisterEvent("UNIT_LEVEL")
end

local function difficultyLabel(diffID)
    if GetDifficultyInfo then
        local name = GetDifficultyInfo(diffID)
        if name and name ~= "" then
            return name
        end
    end
    if diffID == 0 then return "World" end
    return "Difficulty " .. tostring(diffID)
end

local function applyLootFilterForScan()
    local ok = pcall(function()
        EJ_SetLootFilterCompat(0, 0)
    end)
    if ok then return end
    local classID = select(3, UnitClass("player")) or 0
    local spec = GetSpecialization() or 1
    local specID = select(1, GetSpecializationInfo(spec)) or 0
    EJ_SetLootFilterCompat(classID, specID)
end

local function scanLootIndices()
    local items = {}
    local index = 1
    while true do
        local info = EJ_GetLootInfoByIndexCompat(index)
        if not info or not info.name then break end
        local itemID = info.itemID
        if itemID and itemID > 0 then
            items[itemID] = items[itemID] or { itemID = itemID, name = info.name, icon = info.icon, link = info.link }
        end
        index = index + 1
    end
    return items
end

local function dungeonHasNormalLoot(instanceID, firstEncounterID)
    EJ_SelectInstanceCompat(instanceID)
    EJ_SelectEncounterCompat(firstEncounterID)
    EJ_SetDifficultyCompat(1)
    EJ_SetSlotFilterCompat(EISFT.NoFilter)
    applyLootFilterForScan()
    local n = EJ_GetNumLootCompat()
    if not n or n < 1 then return false end
    local info = EJ_GetLootInfoByIndexCompat(1)
    if not info or not info.link then return false end
    local itemLevel = select(4, GetItemInfo(info.link))
    if not itemLevel then return false end
    return itemLevel >= 200
end

function EJLive:ScanEncounterDifficulties(instanceID, encounterID, instanceType, iidWorldBoss, skipNormalDungeon)
    local results = {}
    local function addDiff(diffID)
        EJ_SelectInstanceCompat(instanceID)
        EJ_SelectEncounterCompat(encounterID)
        EJ_SetDifficultyCompat(diffID)
        EJ_SetSlotFilterCompat(EISFT.NoFilter)
        applyLootFilterForScan()
        local byID = scanLootIndices()
        for itemID, data in pairs(byID) do
            local row = results[itemID]
            if not row then
                row = { itemID = itemID, name = data.name, icon = data.icon, difficulties = {} }
                results[itemID] = row
            end
            local seen = false
            for _, d in ipairs(row.difficulties) do
                if d.id == diffID then seen = true break end
            end
            if not seen then
                table.insert(row.difficulties, { id = diffID, name = difficultyLabel(diffID) })
            end
        end
    end

    if iidWorldBoss then
        for _, diffID in ipairs(WB_TRY_DIFFS) do
            addDiff(diffID)
        end
        return results
    end

    if instanceType == "party" then
        for _, d in ipairs(DUNGEON_DIFFS) do
            if not (skipNormalDungeon and d.id == 1) then
                addDiff(d.id)
            end
        end
        return results
    end

    for _, d in ipairs(RAID_DIFFS) do
        addDiff(d.id)
    end
    return results
end

local mergeQueue = {}
local mergeRunning = false
local dungeonNormalCache = {}
EJLive.mergeAbort = false

local function enqueueMergeJobs()
    wipe(mergeQueue)
    if not JournalData.journalCache then return end
    for instanceID, inst in pairs(JournalData.journalCache) do
        mergeQueue[#mergeQueue + 1] = { instanceID = instanceID, inst = inst }
    end
    table.sort(mergeQueue, function(a, b)
        return (a.inst.name or "") < (b.inst.name or "")
    end)
end

local function findEncounter(inst, encounterID)
    for _, enc in ipairs(inst.encounters) do
        if enc.encounterID == encounterID then
            return enc
        end
    end
end

local function buildItemRowFromEJ(itemID, ejRow, JournalDataRef)
    local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    if not name then
        name = ejRow.name or (ns.L and ns.L["JOURNAL_UNKNOWN_ITEM"]) or "Unknown Item"
    end
    local idata = {
        itemID       = itemID,
        name         = name,
        icon         = icon or ejRow.icon or 134400,
        quality      = quality or 1,
        itemType     = "",
        itemSubType  = "",
        fromLiveEJ   = true,
    }
    if link then
        idata.link = link
    end
    return {
        itemID       = itemID,
        itemData     = idata,
        name         = name,
        icon         = idata.icon,
        quality      = idata.quality,
        special      = JournalDataRef:DetermineItemSpecial(idata),
        difficulties = CopyTable(ejRow.difficulties or {}),
        source       = "ej",
        fromLiveEJ   = true,
    }
end

local function mergeEJRowsIntoEncounter(enc, ejMap, JournalDataRef)
    local byItemID = {}
    for _, row in ipairs(enc.items) do
        byItemID[row.itemID] = row
    end
    for itemID, ejRow in pairs(ejMap) do
        local row = byItemID[itemID]
        if row then
            for _, d in ipairs(ejRow.difficulties or {}) do
                local seen = false
                for _, ed in ipairs(row.difficulties or {}) do
                    if ed.id == d.id then seen = true break end
                end
                if not seen then
                    row.difficulties = row.difficulties or {}
                    table.insert(row.difficulties, d)
                end
            end
            row.fromLiveEJ = true
        else
            local newRow = buildItemRowFromEJ(itemID, ejRow, JournalDataRef)
            table.insert(enc.items, newRow)
            byItemID[itemID] = newRow
        end
    end
    table.sort(enc.items, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
end

local function processOneInstance(job)
    if EJLive.mergeAbort then return end
    local inst = job.inst
    local instanceID = job.instanceID
    local iidWorld = (instanceID == WORLD_BOSS_INSTANCE_ID)
    local skipNormal = false
    if inst.instanceType == "party" then
        if dungeonNormalCache[instanceID] == nil then
            SuppressEJ()
            local ok, hasN = pcall(function()
                EJ_SelectInstanceCompat(instanceID)
                local bn, _, bid = EJ_GetEncounterInfoByIndexCompat(1)
                if not bn or not bid then return false end
                return dungeonHasNormalLoot(instanceID, bid)
            end)
            UnsuppressEJ()
            dungeonNormalCache[instanceID] = ok and hasN or false
        end
        skipNormal = not dungeonNormalCache[instanceID]
    end

    SuppressEJ()
    local ok, err = pcall(function()
        EJ_SelectInstanceCompat(instanceID)
        local bi = 1
        while true do
            local bossName, _, bossID = EJ_GetEncounterInfoByIndexCompat(bi)
            if not bossName or not bossID then break end
            local enc = findEncounter(inst, bossID)
            if not enc then
                enc = {
                    encounterID = bossID,
                    name        = bossName,
                    bossIndex   = bi,
                    items       = {},
                }
                table.insert(inst.encounters, enc)
            else
                if (not enc.name or enc.name == (ns.L and ns.L["JOURNAL_UNKNOWN_INST"])) and bossName then
                    enc.name = bossName
                end
                if not enc.bossIndex or enc.bossIndex == 0 then
                    enc.bossIndex = bi
                end
            end
            local ejMap = EJLive:ScanEncounterDifficulties(instanceID, bossID, inst.instanceType, iidWorld, skipNormal)
            mergeEJRowsIntoEncounter(enc, ejMap, JournalData)
            bi = bi + 1
        end
        JournalData:SortEncountersInPlace(inst)
        JournalData:RecalculateInstanceTotals(inst)
    end)
    UnsuppressEJ()
    if not ok then
        print("|cffff6060OneWoW Catalog Journal:|r Live EJ merge error: " .. tostring(err))
    end
end

function EJLive.ProcessQueueTick()
    if EJLive.mergeAbort then
        EJLive.mergeAbort = false
        wipe(mergeQueue)
        mergeRunning = false
        return
    end
    if #mergeQueue == 0 then
        mergeRunning = false
        EJLive.ejMergeComplete = true
        ns:FireScanCallbacks("ej_merge")
        return
    end
    local job = table.remove(mergeQueue, 1)
    processOneInstance(job)
    C_Timer.After(0, EJLive.ProcessQueueTick)
end

function EJLive:BeginMerge()
    if mergeRunning then return end
    JournalData:BuildJournalCache()
    if not JournalData.journalCache then return end
    enqueueMergeJobs()
    if #mergeQueue == 0 then return end
    mergeRunning = true
    EJLive.ejMergeComplete = false
    C_Timer.After(0.05, EJLive.ProcessQueueTick)
end

function EJLive:OnJournalCacheCleared()
    self.mergeAbort = true
    wipe(mergeQueue)
    mergeRunning = false
    if self.debounceTimer and self.debounceTimer.Cancel then
        self.debounceTimer:Cancel()
    end
    self.debounceTimer = nil
    wipe(dungeonNormalCache)
end

function EJLive:ScheduleAfterStaticBuild()
    C_Timer.After(0.5, function()
        if JournalData.journalCache then
            EJLive:BeginMerge()
        end
    end)
end

local ejEvent = CreateFrame("Frame")
ejEvent:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
ejEvent:SetScript("OnEvent", function()
    if mergeRunning then return end
    if not JournalData.journalCache then return end
    if EJLive.debounceTimer and EJLive.debounceTimer.Cancel then
        EJLive.debounceTimer:Cancel()
    end
    EJLive.debounceTimer = C_Timer.NewTimer(1.5, function()
        EJLive.debounceTimer = nil
        if mergeRunning then return end
        JournalData:ClearCache()
        JournalData:BuildJournalCache()
    end)
end)
