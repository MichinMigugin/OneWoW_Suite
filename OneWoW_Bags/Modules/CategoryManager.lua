local _, OneWoW_Bags = ...

local CM = OneWoW_Bags.CategoryManagerBase:Create()
OneWoW_Bags.CategoryManager = CM

function CM:GetSourceButtons()
    return OneWoW_Bags.BagSet:GetAllButtons()
end
