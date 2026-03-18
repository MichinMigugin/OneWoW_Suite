local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BagTypes = {}

local BagTypes = OneWoW_Bags.BagTypes

BagTypes.BACKPACK = 0
BagTypes.BAG_1 = 1
BagTypes.BAG_2 = 2
BagTypes.BAG_3 = 3
BagTypes.BAG_4 = 4
BagTypes.REAGENT_BAG = 5

BagTypes.BACKPACK_BAGS = {0, 1, 2, 3, 4}
BagTypes.REAGENT_BAGS = {5}
BagTypes.ALL_PLAYER_BAGS = {0, 1, 2, 3, 4, 5}

local backpackSet = {[0] = true, [1] = true, [2] = true, [3] = true, [4] = true}
local reagentSet = {[5] = true}
local playerSet = {[0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true}

function BagTypes:IsBackpackBag(bagID)
    return backpackSet[bagID] or false
end

function BagTypes:IsReagentBag(bagID)
    return reagentSet[bagID] or false
end

function BagTypes:IsPlayerBag(bagID)
    return playerSet[bagID] or false
end

local bagNames = {
    [0] = "BACKPACK",
    [1] = "BAG_1",
    [2] = "BAG_2",
    [3] = "BAG_3",
    [4] = "BAG_4",
    [5] = "REAGENT_BAG",
}

function BagTypes:GetBagName(bagID)
    return bagNames[bagID] or "UNKNOWN"
end
