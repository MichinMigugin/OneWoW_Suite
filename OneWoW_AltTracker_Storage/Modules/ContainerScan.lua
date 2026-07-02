local _, ns = ...

-- Shared write-side scanner. The Bags / PersonalBank / WarbandBank / GuildBank
-- modules all read the same kind of slot -- read a slot, fetch its link, decorate
-- via C_Item.GetItemInfo, assemble a record -- so slot iteration and the one
-- canonical record builder live here, emitting a single uniform slot shape. Each
-- container module keeps only its own outer structure (flat bags vs. tabs, per-tab
-- accounting, money, write path), which genuinely differ. Mail has its own write
-- path (expiry math, accounting hooks) and does not use this scanner.
-- See OneWoW_AltTracker_Storage/Docs/ARCHITECTURE.md.

ns.ContainerScan = {}
local ContainerScan = ns.ContainerScan

-- Guild bank links don't expose a quality field through the guild API, so we
-- recover it from the link's color code. Container slots get quality from
-- C_Container.GetContainerItemInfo instead.
local LINK_COLOR_TO_QUALITY = {
    ["ff9d9d9d"] = 0, -- Poor
    ["ffffffff"] = 1, -- Common
    ["ff1eff00"] = 2, -- Uncommon
    ["ff0070dd"] = 3, -- Rare
    ["ffa335ee"] = 4, -- Epic
    ["ffff8000"] = 5, -- Legendary
    ["ffe6cc80"] = 6, -- Artifact
    ["ff00ccff"] = 7, -- Heirloom
}

local function QualityFromLink(itemLink)
    if not itemLink then return nil end
    local hex = itemLink:match("|c(%x%x%x%x%x%x%x%x)")
    return hex and LINK_COLOR_TO_QUALITY[hex:lower()] or nil
end

-- Fill the link-derived fields (name / item level / sell price) on a partly
-- built record and backfill quality/texture only where the source couldn't
-- supply them. The source-preferred quality/texture are passed in already set,
-- so `or` here just provides the C_Item fallback -- preserving each scanner's
-- original precedence (itemInfo.quality / guild link-hex first, GetItemInfo last).
local function Enrich(rec, lookupKey)
    local itemName, _, itemQuality, itemLevel, _, _, _, _, _, itemTexture, sellPrice = C_Item.GetItemInfo(lookupKey)
    rec.itemName = itemName
    rec.itemLevel = itemLevel
    rec.sellPrice = sellPrice or 0
    rec.quality = rec.quality or itemQuality
    rec.texture = rec.texture or itemTexture
    return rec
end

-- The container API's isBound is soulbound-only: a Warbound (account-bound) item
-- reports isBound=false, so a "Hide Bound"-style filter misses it. Detect warbound
-- from the live slot the same way the overlay engine does -- Warbound-until-equipped
-- off the link, otherwise a bound item the Account bank will accept. Must run at
-- scan time: the ItemLocation is only valid for the logged-in character, so stored
-- alt data only carries this once that alt has been re-scanned.
---@param bagID number
---@param slotID number
---@param itemLink string|nil
---@return boolean
local function DetectWarbound(bagID, slotID, itemLink)
    if itemLink and C_Item.IsItemBindToAccountUntilEquip(itemLink) then
        return true
    end
    local loc = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if C_Item.DoesItemExist(loc) and C_Item.IsBound(loc) then
        return C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, loc) or false
    end
    return false
end

-- Canonical slot record from a live container slot (bags / personal / warband,
-- all C_Container). itemInfo is the GetContainerItemInfo result for the slot.
local function BuildContainerRecord(bagID, slotID, itemInfo)
    local itemLink = C_Container.GetContainerItemLink(bagID, slotID)
    local rec = {
        itemID     = itemInfo.itemID,
        itemLink   = itemLink,
        quality    = itemInfo.quality,   -- texture/itemName/itemLevel come from Enrich
        stackCount = itemInfo.stackCount or 1,
        isLocked   = itemInfo.isLocked,
        isBound    = itemInfo.isBound,
        isWarbound = DetectWarbound(bagID, slotID, itemLink),
    }
    return Enrich(rec, itemLink or itemInfo.itemID)
end

-- Canonical slot record from a live guild bank slot (guild API). Returns nil for
-- an empty slot. isBound is unavailable from the guild API, so it stays nil.
local function BuildGuildRecord(tabID, slotID)
    local itemLink = GetGuildBankItemLink(tabID, slotID)
    if not itemLink then return nil end
    local texture, itemCount, locked = GetGuildBankItemInfo(tabID, slotID)
    local rec = {
        itemID     = tonumber(itemLink:match("item:(%d+)")),
        itemLink   = itemLink,
        quality    = QualityFromLink(itemLink),
        texture    = texture,
        stackCount = itemCount,
        isLocked   = locked,
    }
    return Enrich(rec, itemLink)
end

-- Scan one C_Container bag (a backpack bag, a personal-bank tab bag, or a
-- warband-bank tab bag -- they all share the container API). Returns the slot
-- map (keyed by slotID), the used-slot count, and the bag's total slot count.
---@param bagID number
---@return table slots, number usedCount, number numSlots
function ContainerScan:BagSlots(bagID)
    local slots, used = {}, 0
    local numSlots = C_Container.GetContainerNumSlots(bagID) or 0
    for slotID = 1, numSlots do
        local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
        if itemInfo and itemInfo.itemID then
            slots[slotID] = BuildContainerRecord(bagID, slotID, itemInfo)
            used = used + 1
        end
    end
    return slots, used, numSlots
end

-- Scan one guild bank tab. Returns the slot map (keyed by slotID); empty slots
-- are skipped. Guild tabs are a fixed 98 slots.
---@param tabID number
---@param numSlots number|nil defaults to 98
---@return table slots
function ContainerScan:GuildTabSlots(tabID, numSlots)
    local slots = {}
    for slotID = 1, (numSlots or 98) do
        local rec = BuildGuildRecord(tabID, slotID)
        if rec then slots[slotID] = rec end
    end
    return slots
end
