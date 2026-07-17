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
-- ============================================================================

local ItemLevel = {}
ns.ItemLevel = ItemLevel

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
