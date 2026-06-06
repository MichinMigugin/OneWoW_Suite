local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BagTypes = OneWoW_Bags.BagTypes
local C_Container = C_Container
local C_Item = C_Item

local NORMAL_BAG_SUBCLASS = 0

OneWoW_Bags.BagEquip = {}
local BagEquip = OneWoW_Bags.BagEquip

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
    if OneWoW_GUI:IsAddonRestricted() then
        return false
    end
    return self:IsEquippedBagEmpty(bagIndex)
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
        if not OneWoW_GUI:IsAddonRestricted() and not self:IsEquippedBagEmpty(bagIndex) then
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

---@param bagIndex number
---@return boolean
function BagEquip:EquipCursorBag(bagIndex)
    if OneWoW_GUI:IsAddonRestricted() then
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
