local _, ns = ...

local CM = ns.CategoryManagerBase:Create()
ns.CategoryManager = CM

function CM:GetSourceButtons()
    return ns.BagSet:GetAllButtons()
end
