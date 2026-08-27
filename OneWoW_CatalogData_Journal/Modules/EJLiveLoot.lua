-- Merges live Encounter Journal loot into one journal card (names and scaled links).
-- Per-instance only. Login and cache build must not scrape the whole encyclopedia.
local _, ns = ...

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
     return CEJ.GetLootInfoByIndex(index)
end
local function EJ_GetSlotFilterCompat()
    return EJ_Call("GetSlotFilter", "EJ_GetSlotFilter")
end
local function EJ_GetLootFilterCompat()
    if CEJ.GetLootFilter then
        return CEJ.GetLootFilter()
    elseif _G["EJ_GetLootFilter"] then
        return _G["EJ_GetLootFilter"]()
    end
    return nil, nil
end

-- Enum.ItemSlotFilterType.NoFilter (avoid Enum global for LuaLS audit on this data addon).
local EJ_SLOT_FILTER_NO_FILTER = 15

local WORLD_BOSS_INSTANCE_ID = 1312

-- Candidate difficulty ids scanned when MapDifficulties / IsValid is unavailable.
-- Includes legacy 10/25 and dungeon Timewalking (not only primary flex).
local DUNGEON_DIFFS = {
    { id = 1 },
    { id = 2 },
    { id = 23 },
    { id = 8 },
    { id = 24 }, -- Timewalking
}

local RAID_DIFFS = {
    { id = 3 },  -- 10 Player
    { id = 4 },  -- 25 Player
    { id = 5 },  -- 10 Player (Heroic)
    { id = 6 },  -- 25 Player (Heroic)
    { id = 17 }, -- Looking For Raid
    { id = 14 }, -- Normal (flex)
    { id = 15 }, -- Heroic (flex)
    { id = 16 }, -- Mythic
}

local WB_TRY_DIFFS = { 0, 14, 15 }

local function EJ_SelectTierCompat(tier)
    return EJ_Call("SelectTier", "EJ_SelectTier", tier)
end

local function EJ_IsValidInstanceDifficultyCompat(diffID)
    local ok, valid = pcall(function()
        return EJ_Call("IsValidInstanceDifficulty", "EJ_IsValidInstanceDifficulty", diffID)
    end)
    if ok then
        return valid ~= false
    end
    return true
end

local function difficultyLabel(diffID)
    local meta = ns.JournalDifficultyMeta and ns.JournalDifficultyMeta[diffID]
    if GetDifficultyInfo then
        local name = GetDifficultyInfo(diffID)
        if name and name ~= "" then
            return name
        end
    end
    if meta and meta.name then
        return meta.name
    end
    if diffID == 0 then return "World" end
    return "Difficulty " .. tostring(diffID)
end

--- Ordered difficulty ids to scan for an instance card.
---@param inst table
---@return number[]
local function ResolveScanDifficulties(inst)
    local ids = {}
    local seen = {}
    local function add(diffID)
        if not diffID or seen[diffID] then return end
        seen[diffID] = true
        ids[#ids + 1] = diffID
    end

    if inst.validDifficulties then
        for _, diffID in ipairs(inst.validDifficulties) do
            add(diffID)
        end
    else
        local list = (inst.instanceType == "party") and DUNGEON_DIFFS or RAID_DIFFS
        for _, d in ipairs(list) do
            add(d.id)
        end
    end

    local filtered = {}
    for _, diffID in ipairs(ids) do
        if EJ_IsValidInstanceDifficultyCompat(diffID) then
            filtered[#filtered + 1] = diffID
        end
    end
    if #filtered > 0 then
        return filtered
    end
    return ids
end


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

local function applyLootFilterForScan()
    local ok = pcall(function()
        EJ_SetLootFilterCompat(0, 0)
    end)
    if ok then return end
    local classID = select(3, UnitClass("player")) or 0
    local spec = C_SpecializationInfo.GetSpecialization() or 1
    local specID = select(1, C_SpecializationInfo.GetSpecializationInfo(spec)) or 0
    EJ_SetLootFilterCompat(classID, specID)
end

local function NameFromLootInfo(info)
    if not info then
        return nil
    end
    if info.name and info.name ~= "" then
        return info.name
    end
    local link = info.link
    if type(link) == "string" then
        local fromLink = link:match("%[(.-)%]")
        if fromLink and fromLink ~= "" then
            return fromLink
        end
    end
    if info.itemID then
        return C_Item.GetItemNameByID(info.itemID)
    end
    return nil
end

local function scanLootIndices()
    local items = {}
    local n = EJ_GetNumLootCompat()
    for index = 1, n do
        local info = EJ_GetLootInfoByIndexCompat(index)
        if info then
            local itemID = info.itemID
            if itemID and itemID > 0 then
                local row = items[itemID]
                if not row then
                    row = { itemID = itemID, name = NameFromLootInfo(info), icon = info.icon, link = info.link }
                    items[itemID] = row
                else
                    if not row.name or row.name == "" then
                        row.name = NameFromLootInfo(info)
                    end
                    if info.icon then
                        row.icon = info.icon
                    end
                    if info.link then
                        row.link = info.link
                    end
                end
            end
        end
    end
    return items
end

local function dungeonHasNormalLoot(instanceID, firstEncounterID)
    EJ_SelectInstanceCompat(instanceID)
    EJ_SelectEncounterCompat(firstEncounterID)
    EJ_SetDifficultyCompat(1)
    EJ_SetSlotFilterCompat(EJ_SLOT_FILTER_NO_FILTER)
    applyLootFilterForScan()
    local n = EJ_GetNumLootCompat()
    if not n or n < 1 then return false end
    local info = EJ_GetLootInfoByIndexCompat(1)
    if not info or not info.link then return false end
    local itemLevel = select(4, C_Item.GetItemInfo(info.link))
    if not itemLevel then return false end
    return itemLevel >= 200
end

---@param instanceID number
---@param encounterID number
---@param inst table
---@param iidWorldBoss boolean
---@param skipNormalDungeon boolean
function EJLive:ScanEncounterDifficulties(instanceID, encounterID, inst, iidWorldBoss, skipNormalDungeon)
    local results = {}
    local function addDiff(diffID)
        EJ_SelectInstanceCompat(instanceID)
        EJ_SelectEncounterCompat(encounterID)
        EJ_SetDifficultyCompat(diffID)
        EJ_SetSlotFilterCompat(EJ_SLOT_FILTER_NO_FILTER)
        applyLootFilterForScan()
        local byID = scanLootIndices()
        for itemID, data in pairs(byID) do
            local row = results[itemID]
            if not row then
                row = { itemID = itemID, name = data.name, icon = data.icon, difficulties = {}, linkByDiff = {} }
                results[itemID] = row
            end
            -- The EJ loot link is already scaled to the active difficulty, so keep it
            -- per-difficulty; the UI tooltip uses it to mirror the Adventure Guide ilvl.
            if data.link then
                row.linkByDiff = row.linkByDiff or {}
                row.linkByDiff[diffID] = data.link
            end
            local seen = false
            for _, d in ipairs(row.difficulties) do
                if d.id == diffID then seen = true break end
            end
            if not seen then
                tinsert(row.difficulties, { id = diffID, name = difficultyLabel(diffID) })
            end
        end
    end

    if iidWorldBoss then
        for _, diffID in ipairs(WB_TRY_DIFFS) do
            addDiff(diffID)
        end
        return results
    end

    for _, diffID in ipairs(ResolveScanDifficulties(inst)) do
        if not (skipNormalDungeon and diffID == 1) then
            addDiff(diffID)
        end
    end
    return results
end

-- On-demand single-item link resolution. The Adventure Guide derives item level
-- from the difficulty-scaled loot link, so we select the same instance/encounter/
-- difficulty context and read the matching item's link live. Results are cached;
-- the scanningOnDemand flag stops the EJ_LOOT_DATA_RECIEVED handler from treating
-- our own selection churn as a reason to re-merge the open card.
local scaledLinkCache = {}
EJLive.scanningOnDemand = false

---@param instanceID number
---@param encounterID number
---@param diffID number
---@param itemID number
---@return string|nil scaledLink difficulty-scaled item link, or nil if unavailable
function EJLive:GetScaledLootLink(instanceID, encounterID, diffID, itemID)
    if not (instanceID and encounterID and diffID and itemID) then return nil end
    if encounterID == 0 then return nil end

    local key = instanceID .. ":" .. encounterID .. ":" .. diffID .. ":" .. itemID
    if scaledLinkCache[key] then return scaledLinkCache[key] end

    -- The EJ loot system only works once the journal UI is loaded; on a fresh
    -- session the player may never have opened the Adventure Guide.
    OneWoW:EnsureLoaded("Blizzard_EncounterJournal")

    local result
    SuppressEJ()
    EJLive.scanningOnDemand = true
    pcall(function()
        EJ_SelectInstanceCompat(instanceID)
        EJ_SelectEncounterCompat(encounterID)
        EJ_SetDifficultyCompat(diffID)
        EJ_SetSlotFilterCompat(EJ_SLOT_FILTER_NO_FILTER)
        applyLootFilterForScan()
        local n = EJ_GetNumLootCompat()
        for i = 1, n do
            local info = EJ_GetLootInfoByIndexCompat(i)
            if info and info.itemID == itemID and info.link then
                result = info.link
                break
            end
        end
    end)
    EJLive.scanningOnDemand = false
    UnsuppressEJ()

    -- Only cache hits; a miss is usually loot data not received yet, so allow a
    -- retry on the next hover rather than caching the negative permanently.
    if result then
        scaledLinkCache[key] = result
    end
    return result
end

local dungeonNormalCache = {}
local mergeBusy = false
local mergeTarget = nil
-- A merge drives EJ selections that fire EJ_LOOT_DATA_RECIEVED again, so the retry
-- needs a hard ceiling as well as a progress condition.
local MAX_MERGE_RETRIES = 3
local mergeRetries = 0
EJLive.mergeAbort = false

local function findEncounter(inst, encounterID)
    for _, enc in ipairs(inst.encounters) do
        if enc.encounterID == encounterID then
            return enc
        end
    end
end

local function mergeEJRowsIntoEncounter(enc, ejMap)
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
                    tinsert(row.difficulties, d)
                end
            end
            if ejRow.linkByDiff then
                row.linkByDiff = row.linkByDiff or {}
                for diffID, link in pairs(ejRow.linkByDiff) do
                    row.linkByDiff[diffID] = link
                end
            end
            if ejRow.name and not row.nameResolved then
                row.name = ejRow.name
                row.nameResolved = true
                if row.itemData then
                    row.itemData.name = ejRow.name
                end
            end
            row.fromLiveEJ = true
        end
    end
    sort(enc.items, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
end

local function processOneInstance(job)
    if EJLive.mergeAbort then return end
    local inst = job.inst
    local instanceID = job.instanceID
    local expansionID = job.expansionID or inst.expansionID
    local iidWorld = (ns.JournalWorldHubs and ns.JournalWorldHubs[instanceID])
        or (instanceID == WORLD_BOSS_INSTANCE_ID)
    local skipNormal = false
    if inst.instanceType == "party" then
        if dungeonNormalCache[instanceID] == nil then
            SuppressEJ()
            local ok, hasN = pcall(function()
                if expansionID then
                    EJ_SelectTierCompat(expansionID)
                end
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
        if expansionID then
            EJ_SelectTierCompat(expansionID)
        end
        EJ_SelectInstanceCompat(instanceID)
        local bi = 1
        while true do
            local bossName, _, bossID = EJ_GetEncounterInfoByIndexCompat(bi)
            if not bossName or not bossID then break end
            local enc = findEncounter(inst, bossID)
            if not enc then
                enc = {
                    encounterID  = bossID,
                    name         = bossName,
                    nameResolved = bossName ~= nil,
                    bossIndex    = bi,
                    items        = {},
                    source       = "ej",
                }
                tinsert(inst.encounters, enc)
                JournalData:EnsureWorldSectionHeaders(inst)
            else
                enc.source = "ej"
            end
            if bossName then
                enc.name = bossName
                enc.nameResolved = true
            end
            if not enc.bossIndex or enc.bossIndex == 0 then
                enc.bossIndex = bi
            end
            local ejMap = EJLive:ScanEncounterDifficulties(instanceID, bossID, inst, iidWorld, skipNormal)
            mergeEJRowsIntoEncounter(enc, ejMap)
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

--- Card whose live EJ links should refresh when loot data arrives. Nil = ignore the event.
---@param inst table|nil
function EJLive:SetMergeTarget(inst)
    mergeTarget = inst
    mergeRetries = 0
end

--- Scan one card against live EJ. Creates missing boss rows. Names and item
--- links only on loot that is already on the card.
---@param inst table
function EJLive:MergeInstance(inst)
    if mergeBusy then return end
    if not inst or inst.instanceType == "delve" then return end
    if not inst.instanceID or inst.instanceID <= 0 then return end
    if not inst.encounters then return end

    -- Hover tooltips already load this; merge must too or the first open has no
    -- loot names until the player clicks away and back.
    OneWoW:EnsureLoaded("Blizzard_EncounterJournal")

    mergeBusy = true
    EJLive.mergeAbort = false
    processOneInstance({
        instanceID = inst.instanceID,
        expansionID = inst.expansionID,
        inst = inst,
    })
    mergeBusy = false
    if not EJLive.mergeAbort then
        ns:FireScanCallbacks("ej_merge")
    end
end

function EJLive:OnJournalCacheCleared()
    self.mergeAbort = true
    mergeBusy = false
    mergeTarget = nil
    mergeRetries = 0
    if self.debounceTimer and self.debounceTimer.Cancel then
        self.debounceTimer:Cancel()
    end
    self.debounceTimer = nil
    wipe(dungeonNormalCache)
    wipe(scaledLinkCache)
end

--- Boss rows still missing a name. Only boss encounters count: processOneInstance
--- walks EJ_GetEncounterInfoByIndex, so General (0), Achievement (-2), Quest (-3)
--- and extras (-4) rows are not EJ-nameable and must not keep the retry alive.
---@param inst table|nil
---@return boolean
local function HasUnresolvedBossNames(inst)
    if not inst or not inst.encounters then
        return false
    end
    for i = 1, #inst.encounters do
        local enc = inst.encounters[i]
        if enc.encounterID and enc.encounterID > 0 then
            local items = enc.items
            for j = 1, #items do
                if not items[j].nameResolved then
                    return true
                end
            end
        end
    end
    return false
end

---@return boolean
local function ShouldRetryMerge()
    if mergeBusy or EJLive.scanningOnDemand then return false end
    if mergeRetries >= MAX_MERGE_RETRIES then return false end
    return HasUnresolvedBossNames(mergeTarget)
end

-- Blizzard's event name is misspelled. Refresh the open card only; never rebuild
-- the world cache (that restart loop was a multi-second login hitch). On a cold
-- session the first merge can run before the server has sent loot data, so retry
-- while boss rows are still unnamed and give up after MAX_MERGE_RETRIES.
EventRegistry:RegisterFrameEventAndCallback("EJ_LOOT_DATA_RECIEVED", function()
    if not ShouldRetryMerge() then return end
    if EJLive.debounceTimer and EJLive.debounceTimer.Cancel then
        EJLive.debounceTimer:Cancel()
    end
    EJLive.debounceTimer = C_Timer.NewTimer(0.25, function()
        EJLive.debounceTimer = nil
        if not ShouldRetryMerge() then return end
        mergeRetries = mergeRetries + 1
        EJLive:MergeInstance(mergeTarget)
    end)
end)
