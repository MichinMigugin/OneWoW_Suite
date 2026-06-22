local _, ns = ...

local BCM = ns.CategoryManagerBase:Create()
ns.BankCategoryManager = BCM

function BCM:GetSourceButtons()
    return ns.BankSet:GetAllButtons()
end
