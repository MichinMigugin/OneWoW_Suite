local _, ns = ...

-- ============================================================================
-- ItemLevel
-- ============================================================================
-- Shared item-level resolver. Prefers ItemLocation-backed
-- C_Item.GetCurrentItemLevel over C_Item.GetDetailedItemLevelInfo(link).
--
-- Why: GetDetailedItemLevelInfo returns pre-squish / wrong levels for a
-- minority of legacy items (WoWUIBugs #828). Tooltips and equipment-slot
-- GetCurrentItemLevel are correct; link-only detailed is the last resort.
--
-- Container slot counts (bag capacity) are resolved separately for the
-- Item Level overlay and Bags ilvl sort — bags have no useful equipment
-- ilvl; the meaningful number is slots (CONTAINER_SLOTS tooltip line).
-- ============================================================================

local ItemLevel = {}
ns.ItemLevel = ItemLevel

local containerSlotByItemID = {}

--- Pattern matching CONTAINER_SLOTS ("%d Slot %s", positional/%s variants, |4 plurals).
---@return string
local function ContainerSlotsLinePattern()
    local s = CONTAINER_SLOTS
    s = s:gsub("|4[^;]*;", "\002")
    s = s:gsub("%%%d+%$d", "\001"):gsub("%%d", "\001")
    s = s:gsub("%%%d+%$s", "\002"):gsub("%%s", "\002")
    s = s:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    s = s:gsub("\001", "(%%d+)"):gsub("\002", ".-")
    return s
end

local containerSlotsPattern

--- Resolve bag/container capacity from the item tooltip (cached per itemID).
---@param itemID number
---@return number|nil
function ItemLevel.GetContainerSlotCount(itemID)
    if not itemID then
        return nil
    end
    local cached = containerSlotByItemID[itemID]
    if cached then
        return cached
    end

    containerSlotsPattern = containerSlotsPattern or ContainerSlotsLinePattern()
    local slots
    local td = C_TooltipInfo.GetItemByID(itemID)
    if td and td.lines then
        for _, line in ipairs(td.lines) do
            local text = line.leftText
            if text then
                slots = tonumber(text:match(containerSlotsPattern))
                if slots then
                    break
                end
            end
        end
    end

    -- Cache hits only; misses may be empty tooltip data that fills in later.
    if slots then
        containerSlotByItemID[itemID] = slots
    end
    return slots
end

--- Resolve the current item level for a link and/or live item location.
---@param itemLink string|nil
---@param itemLocation ItemLocationMixin|nil
---@return number|nil
function ItemLevel.Get(itemLink, itemLocation)
    local ilvl
    if itemLocation and C_Item.DoesItemExist(itemLocation) then
        ilvl = C_Item.GetCurrentItemLevel(itemLocation)
    end
    if (not ilvl or ilvl == 0) and itemLink then
        ilvl = C_Item.GetDetailedItemLevelInfo(itemLink)
    end
    if not ilvl or ilvl == 0 then
        return nil
    end
    return ilvl
end

--- Resolve iLvl for an equipped inventory slot (player).
---@param slotIndex number
---@return number|nil
function ItemLevel.GetFromEquipmentSlot(slotIndex)
    local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotIndex)
    local itemLink
    if itemLocation and C_Item.DoesItemExist(itemLocation) then
        itemLink = C_Item.GetItemLink(itemLocation)
    else
        itemLink = GetInventoryItemLink("player", slotIndex)
    end
    return ItemLevel.Get(itemLink, itemLocation)
end
