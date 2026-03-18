local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BankTypes = {}
local BankTypes = OneWoW_Bags.BankTypes

BankTypes.BANK_TAB_1 = 6
BankTypes.BANK_TAB_2 = 7
BankTypes.BANK_TAB_3 = 8
BankTypes.BANK_TAB_4 = 9
BankTypes.BANK_TAB_5 = 10
BankTypes.BANK_TAB_6 = 11
BankTypes.ALL_BANK_TABS = {6, 7, 8, 9, 10, 11}

BankTypes.WARBAND_TAB_1 = 12
BankTypes.WARBAND_TAB_2 = 13
BankTypes.WARBAND_TAB_3 = 14
BankTypes.WARBAND_TAB_4 = 15
BankTypes.WARBAND_TAB_5 = 16
BankTypes.ALL_WARBAND_TABS = {12, 13, 14, 15, 16}

BankTypes.GUILD_BANK_SLOTS_PER_TAB = 98

local personalSet = {[6]=true,[7]=true,[8]=true,[9]=true,[10]=true,[11]=true}
local warbandSet  = {[12]=true,[13]=true,[14]=true,[15]=true,[16]=true}

function BankTypes:IsPersonalBankTab(bagID)
    return personalSet[bagID] or false
end

function BankTypes:IsWarbandTab(bagID)
    return warbandSet[bagID] or false
end

local tabNames = {
    [6]="BANK_TAB_1", [7]="BANK_TAB_2",  [8]="BANK_TAB_3",
    [9]="BANK_TAB_4", [10]="BANK_TAB_5", [11]="BANK_TAB_6",
    [12]="WARBAND_TAB_1", [13]="WARBAND_TAB_2", [14]="WARBAND_TAB_3",
    [15]="WARBAND_TAB_4", [16]="WARBAND_TAB_5",
}

function BankTypes:GetTabName(bagID)
    return tabNames[bagID] or "UNKNOWN"
end
