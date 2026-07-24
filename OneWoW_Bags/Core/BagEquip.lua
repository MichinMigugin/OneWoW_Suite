local _, ns = ...

local BagTypes = OneWoW.Inventory.BagTypes
local L = ns.L
local C_Container = C_Container
local C_Item = C_Item
local C_Timer = C_Timer
local ipairs = ipairs
local tinsert = tinsert
local wipe = wipe
local bit = bit

local NORMAL_BAG_SUBCLASS = 0

ns.BagEquip = {}
local BagEquip = ns.BagEquip

local EMPTY_BAG_MOVE_LIMIT = 500
local EMPTY_BAG_FALLBACK_DELAY = 0.2
-- How many consecutive update cycles with no progress before we give up. A move
-- only settles on the next BAG_UPDATE_DELAYED, so a single "nothing happened"
-- cycle is normal right after a move; we only stop once we are genuinely stuck.
local EMPTY_BAG_STALL_LIMIT = 3

local function DestSlotKey(bagIndex, slot)
    return bagIndex * 1000 + slot
end

local emptyBagFrame = nil -- empty-bag continue armed via Inventory delayed channel

local function EnsureEmptyBagListener()
    if emptyBagFrame then return end
    emptyBagFrame = true
    OneWoW.Inventory.RegisterDelayedCallback("Bags_BagEquip", function()
        if not BagEquip._emptySourceBag or not BagEquip._emptyContinuePending then
            return
        end
        BagEquip._emptyContinuePending = false
        if BagEquip._emptyBagFallbackTimer then
            BagEquip._emptyBagFallbackTimer:Cancel()
            BagEquip._emptyBagFallbackTimer = nil
        end
        BagEquip:ContinueEmptyBag()
    end)
end

EnsureEmptyBagListener()

---@param bagIndex number
---@return number|nil
function BagEquip:GetInventorySlotID(bagIndex)
    return C_Container.ContainerIDToInventoryID(bagIndex)
end

---@param itemID number
---@return number|nil
function BagEquip:GetContainerSubclass(itemID)
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    if classID ~= Enum.ItemClass.Container then
        return nil
    end
    return subclassID
end

---@return number|nil
function BagEquip:GetEquippedReagentBagItemID()
    local invSlot = self:GetInventorySlotID(Enum.BagIndex.ReagentBag)
    if not invSlot then
        return nil
    end
    return select(1, GetInventoryItemID("player", invSlot))
end

---@param itemID number
---@return boolean
function BagEquip:IsReagentBagItem(itemID)
    local subclass = self:GetContainerSubclass(itemID)
    if subclass == nil then
        return false
    end
    local refID = self:GetEquippedReagentBagItemID()
    if refID then
        return self:GetContainerSubclass(refID) == subclass
    end
    return subclass ~= NORMAL_BAG_SUBCLASS
end

---@param itemID number
---@return boolean
function BagEquip:IsNormalBagItem(itemID)
    local subclass = self:GetContainerSubclass(itemID)
    if subclass == nil then
        return false
    end
    return subclass == NORMAL_BAG_SUBCLASS
end

---@param itemID number
---@param targetBagIndex number
---@return boolean
function BagEquip:IsCompatibleBagItem(itemID, targetBagIndex)
    if not self:GetContainerSubclass(itemID) then
        return false
    end
    if BagTypes:IsReagentBag(targetBagIndex) then
        return self:IsReagentBagItem(itemID)
    end
    return self:IsNormalBagItem(itemID)
end

---@param bagIndex number
---@return boolean
function BagEquip:IsEquippedBagEmpty(bagIndex)
    if not BagTypes:IsBagEquipped(bagIndex) then
        return false
    end
    local numSlots = C_Container.GetContainerNumSlots(bagIndex)
    for slot = 1, numSlots do
        if C_Container.GetContainerItemID(bagIndex, slot) then
            return false
        end
    end
    return true
end

---@param bagIndex number
---@return boolean
function BagEquip:CanPickup(bagIndex)
    if not BagTypes:IsSwappableBag(bagIndex) then
        return false
    end
    if OneWoW.Restriction.IsProtectedActionBlocked() then
        return false
    end
    return self:IsEquippedBagEmpty(bagIndex)
end

--- Swap/equip from inventory requires an empty equipped bag or an empty slot.
---@param bagIndex number
---@return boolean
function BagEquip:CanSwap(bagIndex)
    if not BagTypes:IsSwappableBag(bagIndex) then
        return false
    end
    if OneWoW.Restriction.IsProtectedActionBlocked() then
        return false
    end
    if BagTypes:IsBagEquipped(bagIndex) and not self:IsEquippedBagEmpty(bagIndex) then
        return false
    end
    return true
end

---@return number|nil
function BagEquip:GetCursorBagItemID()
    local cursorType, itemID, itemLink = GetCursorInfo()
    if cursorType ~= "item" then
        return nil
    end
    if (not itemID or itemID == 0) and itemLink then
        itemID = C_Item.GetItemInfoInstant(itemLink)
    end
    if (not itemID or itemID == 0) and itemLink then
        itemID = tonumber(itemLink:match("item:(%d+)"))
    end
    if not itemID or itemID == 0 then
        return nil
    end
    return itemID
end

---@return boolean
function BagEquip:CursorHasItem()
    return GetCursorInfo() == "item"
end

---@param bagIndex number
---@return boolean
function BagEquip:PickupEquipped(bagIndex)
    if not BagTypes:IsBagEquipped(bagIndex) then
        return false
    end
    if not self:CanPickup(bagIndex) then
        if not OneWoW.Restriction.IsProtectedActionBlocked() and not self:IsEquippedBagEmpty(bagIndex) then
            UIErrorsFrame:AddMessage(ONLY_EMPTY_BAGS, 1.0, 0.1, 0.1, 1.0)
        end
        return false
    end
    local invSlotID = self:GetInventorySlotID(bagIndex)
    if not invSlotID then
        return false
    end
    PickupBagFromSlot(invSlotID)
    return true
end

---@param targetBagIndex number
---@param visit fun(sourceBagID: number, slot: number, itemID: number)
function BagEquip:EnumerateCompatibleBags(targetBagIndex, visit)
    for _, bagID in ipairs(BagTypes:GetPlayerBagIDs()) do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        for slot = 1, numSlots do
            local itemID = C_Container.GetContainerItemID(bagID, slot)
            if itemID and self:IsCompatibleBagItem(itemID, targetBagIndex) then
                visit(bagID, slot, itemID)
            end
        end
    end
end

---@param sourceBagID number
---@param sourceSlot number
---@param targetBagIndex number
---@return boolean
function BagEquip:EquipFromContainer(sourceBagID, sourceSlot, targetBagIndex)
    if OneWoW.Restriction.IsProtectedActionBlocked() then
        return false
    end
    local itemID = C_Container.GetContainerItemID(sourceBagID, sourceSlot)
    if not itemID then
        return false
    end
    if not self:IsCompatibleBagItem(itemID, targetBagIndex) then
        if BagTypes:IsReagentBag(targetBagIndex) then
            UIErrorsFrame:AddMessage(ERR_SLOT_ONLY_REAGENTBAG, 1.0, 0.1, 0.1, 1.0)
        else
            UIErrorsFrame:AddMessage(ERR_REAGENTBAG_WRONG_SLOT, 1.0, 0.1, 0.1, 1.0)
        end
        return false
    end
    if BagTypes:IsBagEquipped(targetBagIndex) and not self:IsEquippedBagEmpty(targetBagIndex) then
        UIErrorsFrame:AddMessage(ONLY_EMPTY_BAGS, 1.0, 0.1, 0.1, 1.0)
        return false
    end
    C_Container.PickupContainerItem(sourceBagID, sourceSlot)
    return self:EquipCursorBag(targetBagIndex)
end

---@param bagIndex number
---@return boolean
function BagEquip:EquipCursorBag(bagIndex)
    if OneWoW.Restriction.IsProtectedActionBlocked() then
        return false
    end
    local itemID = self:GetCursorBagItemID()
    if not itemID then
        return false
    end
    local subclass = self:GetContainerSubclass(itemID)
    if subclass ~= nil and not self:IsCompatibleBagItem(itemID, bagIndex) then
        if BagTypes:IsReagentBag(bagIndex) then
            UIErrorsFrame:AddMessage(ERR_SLOT_ONLY_REAGENTBAG, 1.0, 0.1, 0.1, 1.0)
        else
            UIErrorsFrame:AddMessage(ERR_REAGENTBAG_WRONG_SLOT, 1.0, 0.1, 0.1, 1.0)
        end
        return false
    end
    local invSlotID = self:GetInventorySlotID(bagIndex)
    if not invSlotID then
        return false
    end
    return PutItemInBag(invSlotID)
end

---@param bagIndex number
---@return string
function BagEquip:GetBagDisplayLabel(bagIndex)
    return L[BagTypes:GetBagName(bagIndex)]
end

---@param itemID number
---@return boolean
function BagEquip:IsCraftingReagentItem(itemID)
    local isCraftingReagent = select(17, C_Item.GetItemInfo(itemID))
    return isCraftingReagent == true
end

---@param itemID number
---@param destBagIndex number
---@return boolean
function BagEquip:ItemCanGoInBag(itemID, destBagIndex)
    if not BagTypes:IsBagEquipped(destBagIndex) then
        return false
    end
    if BagTypes:IsReagentBag(destBagIndex) then
        return self:IsCraftingReagentItem(itemID)
    end
    local itemFamily = C_Item.GetItemFamily(itemID) or 0
    local _, bagFamily = C_Container.GetContainerNumFreeSlots(destBagIndex)
    bagFamily = bagFamily or 0
    if bagFamily == 0 then
        return true
    end
    if itemFamily == 0 then
        return false
    end
    return bit.band(itemFamily, bagFamily) ~= 0
end

---@param itemID number
---@param destBagIndex number
---@param usedDestSlots table|nil slots already claimed this pass (keyed by DestSlotKey)
---@return number|nil
function BagEquip:FindSlotForItem(itemID, destBagIndex, usedDestSlots)
    if not self:ItemCanGoInBag(itemID, destBagIndex) then
        return nil
    end

    local maxStack = C_Item.GetItemMaxStackSizeByID(itemID) or 1
    if maxStack > 1 then
        local numSlots = C_Container.GetContainerNumSlots(destBagIndex)
        for slot = 1, numSlots do
            if not (usedDestSlots and usedDestSlots[DestSlotKey(destBagIndex, slot)])
                and C_Container.GetContainerItemID(destBagIndex, slot) == itemID then
                local slotInfo = C_Container.GetContainerItemInfo(destBagIndex, slot)
                if slotInfo and not slotInfo.isLocked and slotInfo.stackCount < maxStack then
                    return slot
                end
            end
        end
    end

    local freeSlots = C_Container.GetContainerFreeSlots(destBagIndex)
    if freeSlots then
        for _, slot in ipairs(freeSlots) do
            if not (usedDestSlots and usedDestSlots[DestSlotKey(destBagIndex, slot)]) then
                return slot
            end
        end
    end
    return nil
end

---@param itemID number
---@param sourceBagIndex number
---@param destBagIndex number|nil
---@param usedDestSlots table|nil slots already claimed this pass (keyed by DestSlotKey)
---@return number|nil, number|nil
function BagEquip:FindMoveTarget(itemID, sourceBagIndex, destBagIndex, usedDestSlots)
    if destBagIndex then
        local slot = self:FindSlotForItem(itemID, destBagIndex, usedDestSlots)
        if slot then
            return destBagIndex, slot
        end
        return nil, nil
    end

    for _, bagID in ipairs(BagTypes:GetPlayerBagIDs()) do
        if bagID ~= sourceBagIndex and BagTypes:IsBagEquipped(bagID) then
            local slot = self:FindSlotForItem(itemID, bagID, usedDestSlots)
            if slot then
                return bagID, slot
            end
        end
    end
    return nil, nil
end

---@param sourceBagIndex number
---@param destBagIndex number|nil
---@return boolean
function BagEquip:CanEmptyTo(sourceBagIndex, destBagIndex)
    if not BagTypes:IsBagEquipped(sourceBagIndex) or self:IsEquippedBagEmpty(sourceBagIndex) then
        return false
    end

    local numSlots = C_Container.GetContainerNumSlots(sourceBagIndex)
    for slot = 1, numSlots do
        local info = C_Container.GetContainerItemInfo(sourceBagIndex, slot)
        if info and not info.isLocked then
            local destBag, destSlot = self:FindMoveTarget(info.itemID, sourceBagIndex, destBagIndex)
            if destBag and destSlot then
                return true
            end
        end
    end
    return false
end

---@param bagIndex number
---@return boolean
function BagEquip:CanEmpty(bagIndex)
    if not BagTypes:IsBagEquipped(bagIndex) or self:IsEquippedBagEmpty(bagIndex) then
        return false
    end
    if OneWoW.Restriction.IsProtectedActionBlocked() then
        return false
    end
    return self:CanEmptyTo(bagIndex, nil)
end

---@param sourceBagIndex number
---@return table
function BagEquip:GetEmptyDestinations(sourceBagIndex)
    local destinations = {}
    for _, bagID in ipairs(BagTypes:GetPlayerBagIDs()) do
        if bagID ~= sourceBagIndex and BagTypes:IsBagEquipped(bagID) then
            tinsert(destinations, {
                bagIndex = bagID,
                label = self:GetBagDisplayLabel(bagID),
            })
        end
    end
    return destinations
end

function BagEquip:CancelEmptyBag()
    if self._emptyBagFallbackTimer then
        self._emptyBagFallbackTimer:Cancel()
        self._emptyBagFallbackTimer = nil
    end
    self._emptyContinuePending = false
    self._emptySourceBag = nil
    self._emptyDestBag = nil
    self._emptyMovesLeft = nil
    self._emptyCursorWaits = nil
    self._emptyStall = nil
    self._emptyLastCount = nil
end

function BagEquip:ScheduleContinueEmptyBag()
    if not self._emptySourceBag then
        return
    end
    self._emptyContinuePending = true
    if self._emptyBagFallbackTimer then
        self._emptyBagFallbackTimer:Cancel()
    end
    self._emptyBagFallbackTimer = C_Timer.After(EMPTY_BAG_FALLBACK_DELAY, function()
        self._emptyBagFallbackTimer = nil
        if not self._emptyContinuePending or not self._emptySourceBag then
            return
        end
        self._emptyContinuePending = false
        self:ContinueEmptyBag()
    end)
end

---@param bagIndex number
---@return number count of occupied slots
function BagEquip:CountOccupiedSlots(bagIndex)
    local count = 0
    local numSlots = C_Container.GetContainerNumSlots(bagIndex)
    for slot = 1, numSlots do
        if C_Container.GetContainerItemID(bagIndex, slot) then
            count = count + 1
        end
    end
    return count
end

-- One cycle of the empty-bag operation. Reads the *settled* state from the
-- previous cycle, decides whether we are done or stuck, then issues a fresh
-- batch of moves. A single no-progress cycle is tolerated because a move only
-- settles on the following BAG_UPDATE_DELAYED; we only stop after the source is
-- emptied or several consecutive cycles make no progress.
function BagEquip:ContinueEmptyBag()
    local sourceBag = self._emptySourceBag
    if not sourceBag then
        return
    end
    if OneWoW.Restriction.IsProtectedActionBlocked() then
        self:FinishEmptyBag()
        return
    end

    self._emptyMovesLeft = (self._emptyMovesLeft or EMPTY_BAG_MOVE_LIMIT) - 1
    if self._emptyMovesLeft <= 0 then
        self:FinishEmptyBag()
        return
    end

    -- Wait for the cursor to clear (e.g. the player is mid-drag) before acting.
    if GetCursorInfo() then
        self._emptyCursorWaits = (self._emptyCursorWaits or 0) + 1
        if self._emptyCursorWaits > 20 then
            self:FinishEmptyBag()
        else
            self:ScheduleContinueEmptyBag()
        end
        return
    end
    self._emptyCursorWaits = 0

    local remaining = self:CountOccupiedSlots(sourceBag)
    if remaining == 0 then
        self:FinishEmptyBag()
        return
    end

    -- Detect progress against the previous settled cycle.
    if self._emptyLastCount and remaining < self._emptyLastCount then
        self._emptyStall = 0
    end
    self._emptyLastCount = remaining

    local moved = self:EmptyBagPass()
    if moved > 0 then
        self._emptyStall = 0
    else
        self._emptyStall = (self._emptyStall or 0) + 1
        if self._emptyStall >= EMPTY_BAG_STALL_LIMIT then
            self:FinishEmptyBag()
            return
        end
    end

    self:ScheduleContinueEmptyBag()
end

---@param sourceBag number
---@param sourceSlot number
---@param destBag number
---@param destSlot number
---@return boolean moved true if the item left the source slot
function BagEquip:TryMoveContainerItem(sourceBag, sourceSlot, destBag, destSlot)
    if GetCursorInfo() then
        return false
    end

    local sourceItemID = C_Container.GetContainerItemID(sourceBag, sourceSlot)
    if not sourceItemID then
        return false
    end

    C_Container.PickupContainerItem(sourceBag, sourceSlot)
    if not GetCursorInfo() then
        return false
    end
    C_Container.PickupContainerItem(destBag, destSlot)
    if GetCursorInfo() then
        -- Placement failed or only a partial stack merged; return the remainder
        -- to the (now empty) source slot so nothing is left stranded on the cursor.
        C_Container.PickupContainerItem(sourceBag, sourceSlot)
        if GetCursorInfo() then
            ClearCursor()
        end
        return false
    end
    return true
end

-- Moves as many items as possible out of the source bag in a single frame.
-- pickup/place are synchronous on the cursor, so several items can move per
-- cycle; claimed destination slots are tracked because container queries do not
-- refresh mid-frame.
---@return number moved count of items moved this pass
function BagEquip:EmptyBagPass()
    local sourceBag = self._emptySourceBag
    if not sourceBag then
        return 0
    end

    local destBagFilter = self._emptyDestBag
    local used = wipe(self._emptyUsedDestSlots or {})
    self._emptyUsedDestSlots = used

    local moved = 0
    local numSlots = C_Container.GetContainerNumSlots(sourceBag)
    for slot = 1, numSlots do
        if GetCursorInfo() then
            break
        end
        local info = C_Container.GetContainerItemInfo(sourceBag, slot)
        if info and not info.isLocked then
            -- Eligibility (incl. bag items) is handled by FindMoveTarget/ItemCanGoInBag.
            local destBag, destSlot = self:FindMoveTarget(info.itemID, sourceBag, destBagFilter, used)
            if destBag and destSlot and self:TryMoveContainerItem(sourceBag, slot, destBag, destSlot) then
                used[DestSlotKey(destBag, destSlot)] = true
                moved = moved + 1
            end
        end
    end
    return moved
end

function BagEquip:FinishEmptyBag()
    local sourceBag = self._emptySourceBag
    self:CancelEmptyBag()
    if sourceBag and BagTypes:IsBagEquipped(sourceBag) and not self:IsEquippedBagEmpty(sourceBag) then
        UIErrorsFrame:AddMessage(ERR_INV_FULL, 1.0, 0.1, 0.1, 1.0)
    end
end

---@param sourceBagIndex number
---@param destBagIndex number|nil
---@return boolean
function BagEquip:EmptyBag(sourceBagIndex, destBagIndex)
    if destBagIndex and not self:CanEmptyTo(sourceBagIndex, destBagIndex) then
        return false
    end
    if not destBagIndex and not self:CanEmpty(sourceBagIndex) then
        return false
    end

    self:CancelEmptyBag()
    self._emptySourceBag = sourceBagIndex
    self._emptyDestBag = destBagIndex
    self._emptyMovesLeft = EMPTY_BAG_MOVE_LIMIT
    self._emptyCursorWaits = 0
    self._emptyStall = 0
    self._emptyLastCount = nil

    self:ContinueEmptyBag()
    return true
end
