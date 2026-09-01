-- ============================================================================
-- JournalCard
-- ============================================================================
-- Mutates an already-hydrated Catalog journal card (encounters / totals).
-- Shared by live EJ merge and live ATT extras. Does not write ns.Places or
-- ns.Encounters and does not invent pins.
-- ============================================================================
local _, ns = ...

local L = ns.L
local tinsert, sort = tinsert, sort
local tonumber, format = tonumber, string.format
local C_Item = C_Item

local Card = {}
ns.JournalCard = Card

local WORLD_BOSSES_SECTION_ID = -10
local WORLD_RARES_SECTION_ID = -11
local RARE_BASE = 10000000

Card.WORLD_BOSSES_SECTION_ID = WORLD_BOSSES_SECTION_ID
Card.WORLD_RARES_SECTION_ID = WORLD_RARES_SECTION_ID
Card.RARE_BASE = RARE_BASE

---@param inst table
---@return boolean
function Card.UsesWorldLayout(inst)
    return inst.instanceType == "world" or inst.instanceType == "zone"
end

---@param enc table
---@return number
local function EncounterSortRank(enc)
    if enc.sectionHeader then
        if enc.encounterID == WORLD_BOSSES_SECTION_ID then
            return 0
        end
        if enc.encounterID == WORLD_RARES_SECTION_ID then
            return 2
        end
    end
    if enc.worldRare then
        return 3
    end
    if enc.extrasCategory or enc.encounterID == 0 then
        return 7
    end
    return 1
end

---@param a table
---@param b table
---@return boolean
local function SortEncounters(a, b)
    local ra, rb = EncounterSortRank(a), EncounterSortRank(b)
    if ra ~= rb then
        return ra < rb
    end
    local ai = a.bossIndex or 999
    local bi = b.bossIndex or 999
    if ai ~= bi then
        return ai < bi
    end
    return (a.name or "") < (b.name or "")
end

---@param inst table
function Card.SortEncountersInPlace(inst)
    if not inst or not inst.encounters then
        return
    end
    sort(inst.encounters, SortEncounters)
end

---@param inst table
function Card.RecalculateInstanceTotals(inst)
    if not inst or not inst.encounters then
        return
    end
    local total = 0
    local rares = 0
    local bosses = 0
    local seen = {}
    for i = 1, #inst.encounters do
        local enc = inst.encounters[i]
        if enc.worldRare then
            rares = rares + 1
        elseif enc.encounterID and enc.encounterID > 0 and enc.encounterID < RARE_BASE and not enc.sectionHeader then
            bosses = bosses + 1
        end
        local items = enc.items
        if items then
            for j = 1, #items do
                local itemID = items[j].itemID
                if itemID and not seen[itemID] then
                    seen[itemID] = true
                    total = total + 1
                end
            end
        end
    end
    inst.totalItems = total
    inst.rareCount = rares
    inst.bossCount = bosses
end

---@param inst table
function Card.EnsureWorldSectionHeaders(inst)
    if not inst or not Card.UsesWorldLayout(inst) or not inst.encounters then
        return
    end
    local hasBosses, hasRares, haveBossesHdr, haveRaresHdr = false, false, false, false
    for i = 1, #inst.encounters do
        local enc = inst.encounters[i]
        if enc.encounterID == WORLD_BOSSES_SECTION_ID then
            haveBossesHdr = true
        elseif enc.encounterID == WORLD_RARES_SECTION_ID then
            haveRaresHdr = true
        elseif enc.worldRare then
            hasRares = true
        elseif enc.encounterID and enc.encounterID > 0 and enc.encounterID < RARE_BASE then
            hasBosses = true
        end
    end
    if hasBosses and not haveBossesHdr then
        tinsert(inst.encounters, {
            encounterID = WORLD_BOSSES_SECTION_ID,
            name = L["JOURNAL_WORLD_BOSSES"],
            nameResolved = true,
            bossIndex = 0,
            items = {},
            sectionHeader = true,
        })
    end
    if hasRares and not haveRaresHdr then
        tinsert(inst.encounters, {
            encounterID = WORLD_RARES_SECTION_ID,
            name = L["JOURNAL_WORLD_RARES"],
            nameResolved = true,
            bossIndex = 0,
            items = {},
            sectionHeader = true,
        })
    end
end

---@param itemID number
---@param itemData table|nil
---@return string|nil special
---@return table|nil rec
local function ItemSpecial(itemID, itemData)
    local rec = itemData
    if not rec or not rec.classID then
        local itemAPI = OneWoW_CatDB_ItemDB_API
        rec = itemAPI and itemAPI.GetItem(itemID) or rec
    end
    if not rec then
        return nil, nil
    end
    if rec.isTransmog then
        return "TMog", rec
    end
    if rec.speciesID then
        return "Pet", rec
    end
    if rec.mountID then
        return "Mount", rec
    end
    if rec.isToy or rec.toyID then
        return "Toy", rec
    end
    if rec.classID == Enum.ItemClass.Recipe then
        return "Recipe", rec
    end
    if rec.classID == Enum.ItemClass.Questitem then
        return "Quest", rec
    end
    if rec.classID == Enum.ItemClass.Housing then
        return "Housing", rec
    end
    if rec.classID == Enum.ItemClass.Battlepet then
        return "Pet", rec
    end
    return nil, rec
end

---@param entry table
---@return table item
function Card.MakeExtraItem(entry)
    local itemID = entry.itemID
    local idata = entry.itemData
    local snap = OneWoW_CatDB_ZoneDB_API.GetCachedItem(itemID)
    local special, rec = ItemSpecial(itemID, idata)
    local name = (idata and idata.name) or (snap and snap.name) or L["JOURNAL_UNKNOWN_ITEM"]
    return {
        itemID = itemID,
        itemData = rec or idata or snap,
        name = name,
        nameResolved = name ~= L["JOURNAL_UNKNOWN_ITEM"],
        icon = (idata and idata.icon) or (snap and snap.icon) or C_Item.GetItemIconByID(itemID) or 134400,
        quality = (idata and idata.quality) or (snap and snap.quality) or 1,
        special = special,
        difficulties = entry.difficulties or {},
        source = entry.source,
        npcID = entry.npcID,
    }
end

---@param items table
---@param itemID number
---@return boolean
local function EncounterHasItem(items, itemID)
    for i = 1, #items do
        if items[i].itemID == itemID then
            return true
        end
    end
    return false
end

---@param npcID number
---@param source string|nil
---@return table
local function NewRareEncounter(npcID, source)
    local resolved = OneWoW_CatDB_ZoneDB_API.ResolveNPCName(npcID)
    return {
        encounterID = RARE_BASE + npcID,
        name = resolved or format(L["JOURNAL_NPC_UNNAMED"], npcID),
        nameResolved = resolved ~= nil,
        bossIndex = 0,
        items = {},
        worldRare = true,
        npcID = npcID,
        source = source,
    }
end

---@param encID number
---@param npcID number|nil
---@param source string|nil
---@return table
local function NewWorldBossEncounter(encID, npcID, source)
    local resolved
    if npcID then
        resolved = OneWoW_CatDB_ZoneDB_API.ResolveNPCName(npcID)
    end
    local shipped = ns.Encounters[encID]
    if shipped and shipped.name and shipped.name ~= "" then
        resolved = shipped.name
    end
    local _, _, _, displayInfo = EJ_GetCreatureInfo(1, encID)
    return {
        encounterID = encID,
        name = resolved or L["JOURNAL_UNKNOWN_INST"],
        nameResolved = resolved ~= nil,
        bossIndex = (shipped and shipped.order) or 999,
        items = {},
        npcID = npcID,
        displayID = (displayInfo and displayInfo > 0) and displayInfo or nil,
        source = source,
    }
end

--- Place one extra onto an already-hydrated card. Creates a boss / rare /
--- general row only on this card view. Does not add places or pins.
---@param inst table
---@param entry table
---@return boolean added
function Card.PlaceExtraOnCard(inst, entry)
    local itemID = entry.itemID
    if not inst or not itemID then
        return false
    end
    local encID = entry.encounterID
    local npcID = tonumber(entry.npcID)
    local entrySource = entry.source
    local isWorld = Card.UsesWorldLayout(inst)
    local dest
    for i = 1, #inst.encounters do
        local enc = inst.encounters[i]
        if encID and encID > 0 and enc.encounterID == encID then
            dest = enc
            break
        end
        if isWorld and npcID and enc.worldRare and enc.npcID == npcID then
            dest = enc
            break
        end
        if (not encID or encID == 0) and not (isWorld and npcID)
            and (enc.encounterID == 0 or enc.extrasCategory)
        then
            dest = enc
            break
        end
    end
    if not dest then
        if encID and encID > 0 then
            dest = NewWorldBossEncounter(encID, npcID, entrySource)
        elseif isWorld and npcID then
            dest = NewRareEncounter(npcID, entrySource)
        else
            dest = {
                encounterID = 0,
                name = L["JOURNAL_GENERAL_LOOT"],
                nameResolved = true,
                bossIndex = 999,
                items = {},
                extrasCategory = true,
                source = entrySource,
            }
        end
        dest.zoneMapID = dest.zoneMapID or entry.mapID
        tinsert(inst.encounters, dest)
        Card.EnsureWorldSectionHeaders(inst)
    end
    dest.zoneMapID = dest.zoneMapID or entry.mapID
    if EncounterHasItem(dest.items, itemID) then
        return false
    end
    tinsert(dest.items, Card.MakeExtraItem(entry))
    sort(dest.items, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    if dest.extrasCategory then
        dest.name = L["JOURNAL_GENERAL_LOOT"]
        dest.source = entrySource
    end
    return true
end
