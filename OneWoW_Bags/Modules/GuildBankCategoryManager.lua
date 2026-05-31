local _, OneWoW_Bags = ...

local GBCM = OneWoW_Bags.CategoryManagerBase:Create()
OneWoW_Bags.GuildBankCategoryManager = GBCM

function GBCM:GetSourceButtons()
    return OneWoW_Bags.GuildBankSet:GetAllButtons()
end
