local _, OneWoW_Bags = ...

OneWoW_Bags.BankTypes = {}
local BankTypes = OneWoW_Bags.BankTypes

local bankTabIDs = {
    Enum.BagIndex.CharacterBankTab_1,
    Enum.BagIndex.CharacterBankTab_2,
    Enum.BagIndex.CharacterBankTab_3,
    Enum.BagIndex.CharacterBankTab_4,
    Enum.BagIndex.CharacterBankTab_5,
    Enum.BagIndex.CharacterBankTab_6
}

local warbandTabIDs = {
    Enum.BagIndex.AccountBankTab_1,
    Enum.BagIndex.AccountBankTab_2,
    Enum.BagIndex.AccountBankTab_3,
    Enum.BagIndex.AccountBankTab_4,
    Enum.BagIndex.AccountBankTab_5
}

local tabNames = {
    [Enum.BagIndex.CharacterBankTab_1] = "BANK_TAB_1",
    [Enum.BagIndex.CharacterBankTab_2] = "BANK_TAB_2",
    [Enum.BagIndex.CharacterBankTab_3] = "BANK_TAB_3",
    [Enum.BagIndex.CharacterBankTab_4] = "BANK_TAB_4",
    [Enum.BagIndex.CharacterBankTab_5] = "BANK_TAB_5",
    [Enum.BagIndex.CharacterBankTab_6] = "BANK_TAB_6",
    [Enum.BagIndex.AccountBankTab_1] = "WARBAND_TAB_1",
    [Enum.BagIndex.AccountBankTab_2] = "WARBAND_TAB_2",
    [Enum.BagIndex.AccountBankTab_3] = "WARBAND_TAB_3",
    [Enum.BagIndex.AccountBankTab_4] = "WARBAND_TAB_4",
    [Enum.BagIndex.AccountBankTab_5] = "WARBAND_TAB_5",
}

function BankTypes:IsPersonalBankTab(bagID)
    return bagID >= Enum.BagIndex.CharacterBankTab_1 and bagID <= Enum.BagIndex.CharacterBankTab_6
end

function BankTypes:IsWarbandTab(bagID)
    return bagID >= Enum.BagIndex.AccountBankTab_1 and bagID <= Enum.BagIndex.AccountBankTab_5
end

function BankTypes:GetBankTabIDs()
    return bankTabIDs
end

function BankTypes:GetWarbandTabIDs()
    return warbandTabIDs
end

function BankTypes:GetTabName(bagID)
    return tabNames[bagID] or "UNKNOWN"
end
