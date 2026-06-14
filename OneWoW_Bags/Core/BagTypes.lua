local _, OneWoW_Bags = ...

local C_Container = C_Container

OneWoW_Bags.BagTypes = {}
local BagTypes = OneWoW_Bags.BagTypes

local playerBagIDs = {
    Enum.BagIndex.Backpack,
    Enum.BagIndex.Bag_1,
    Enum.BagIndex.Bag_2,
    Enum.BagIndex.Bag_3,
    Enum.BagIndex.Bag_4,
    Enum.BagIndex.ReagentBag
}

-- Values are locale keys (resolved via L by display callers), so they must match
-- the BAG_* keys in the locale files. Backpack/Reagent previously used "BACKPACK"/
-- "REAGENT_BAG", which had no locale entry and rendered as the raw key in Bag View.
local bagNames = {
    [Enum.BagIndex.Backpack] = "BAG_BACKPACK",
    [Enum.BagIndex.Bag_1] = "BAG_1",
    [Enum.BagIndex.Bag_2] = "BAG_2",
    [Enum.BagIndex.Bag_3] = "BAG_3",
    [Enum.BagIndex.Bag_4] = "BAG_4",
    [Enum.BagIndex.ReagentBag] = "BAG_REAGENT",
}

function BagTypes:IsReagentBag(bagID)
    return bagID == Enum.BagIndex.ReagentBag
end

function BagTypes:IsSwappableBag(bagID)
    return bagID ~= Enum.BagIndex.Backpack
end

--- True when the container has an equipped bag item (backpack is always equipped).
---@param bagID number
---@return boolean
function BagTypes:IsBagEquipped(bagID)
    if bagID == Enum.BagIndex.Backpack then
        return true
    end
    return C_Container.GetContainerNumSlots(bagID) > 0
end

function BagTypes:IsPlayerBag(bagID)
    return bagID >= Enum.BagIndex.Backpack and bagID <= Enum.BagIndex.ReagentBag
end

function BagTypes:GetPlayerBagIDs()
    return playerBagIDs
end

function BagTypes:GetBagName(bagID)
    return bagNames[bagID] or "UNKNOWN"
end

function BagTypes:GetContainerType(bagID)
    local BankTypes = OneWoW_Bags.BankTypes
    if self:IsPlayerBag(bagID) then return "backpack" end
    if BankTypes:IsPersonalBankTab(bagID) then return "character_bank" end
    if BankTypes:IsWarbandTab(bagID) then return "warband_bank" end
    return nil
end
