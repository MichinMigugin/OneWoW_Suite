local _, OneWoW_Bags = ...

local BCM = OneWoW_Bags.CategoryManagerBase:Create()
OneWoW_Bags.BankCategoryManager = BCM

function BCM:GetSourceButtons()
    return OneWoW_Bags.BankSet:GetAllButtons()
end
