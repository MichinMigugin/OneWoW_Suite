local _, OneWoW_Bags = ...

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

local bagNames = {
    [Enum.BagIndex.Backpack] = "BACKPACK",
    [Enum.BagIndex.Bag_1] = "BAG_1",
    [Enum.BagIndex.Bag_2] = "BAG_2",
    [Enum.BagIndex.Bag_3] = "BAG_3",
    [Enum.BagIndex.Bag_4] = "BAG_4",
    [Enum.BagIndex.ReagentBag] = "REAGENT_BAG",
}

function BagTypes:IsReagentBag(bagID)
    return bagID == Enum.BagIndex.ReagentBag
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
