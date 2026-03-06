local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BagTypes = {}

local BagTypes = OneWoW_Bags.BagTypes

BagTypes.BACKPACK = 0
BagTypes.BAG_1 = 1
BagTypes.BAG_2 = 2
BagTypes.BAG_3 = 3
BagTypes.BAG_4 = 4
BagTypes.REAGENT_BAG = 5
BagTypes.BANK_TAB_1 = 6
BagTypes.BANK_TAB_2 = 7
BagTypes.BANK_TAB_3 = 8
BagTypes.BANK_TAB_4 = 9
BagTypes.BANK_TAB_5 = 10
BagTypes.BANK_TAB_6 = 11
BagTypes.WARBAND_TAB_1 = 12
BagTypes.WARBAND_TAB_2 = 13
BagTypes.WARBAND_TAB_3 = 14
BagTypes.WARBAND_TAB_4 = 15
BagTypes.WARBAND_TAB_5 = 16

BagTypes.BACKPACK_BAGS = {0, 1, 2, 3, 4}
BagTypes.REAGENT_BAGS = {5}
BagTypes.ALL_PLAYER_BAGS = {0, 1, 2, 3, 4, 5}
BagTypes.BANK_BAGS = {6, 7, 8, 9, 10, 11}
BagTypes.WARBAND_BAGS = {12, 13, 14, 15, 16}

local backpackSet = {[0] = true, [1] = true, [2] = true, [3] = true, [4] = true}
local reagentSet = {[5] = true}
local playerSet = {[0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true}
local bankSet = {[6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true}
local warbandSet = {[12] = true, [13] = true, [14] = true, [15] = true, [16] = true}

function BagTypes:IsBackpackBag(bagID)
    return backpackSet[bagID] or false
end

function BagTypes:IsReagentBag(bagID)
    return reagentSet[bagID] or false
end

function BagTypes:IsBankBag(bagID)
    return bankSet[bagID] or false
end

function BagTypes:IsWarbandBag(bagID)
    return warbandSet[bagID] or false
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
    [6] = "BANK_TAB_1",
    [7] = "BANK_TAB_2",
    [8] = "BANK_TAB_3",
    [9] = "BANK_TAB_4",
    [10] = "BANK_TAB_5",
    [11] = "BANK_TAB_6",
    [12] = "WARBAND_TAB_1",
    [13] = "WARBAND_TAB_2",
    [14] = "WARBAND_TAB_3",
    [15] = "WARBAND_TAB_4",
    [16] = "WARBAND_TAB_5",
}

function BagTypes:GetBagName(bagID)
    return bagNames[bagID] or "UNKNOWN"
end
