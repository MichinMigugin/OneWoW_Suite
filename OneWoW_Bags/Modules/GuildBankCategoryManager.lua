local _, ns = ...

local GBCM = ns.CategoryManagerBase:Create()
ns.GuildBankCategoryManager = GBCM

function GBCM:GetSourceButtons()
    return ns.GuildBankSet:GetAllButtons()
end
