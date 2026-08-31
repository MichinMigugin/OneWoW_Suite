local _, ns = ...
local AutoRepairModule = ns.ModuleRegistry:Current()
if not AutoRepairModule then return end

local OneWoW = OneWoW

-- MERCHANT_SHOW was this module's only event, so it subscribes to the core
-- OneWoW.Merchant show channel (single MERCHANT_* owner) instead of owning a
-- frame; module enable/disable maps 1:1 onto subscribe / UnregisterCallback.
local OWNER_ID = "QoL_autorepair"

function AutoRepairModule:OnEnable()
    OneWoW.Merchant.RegisterShowCallback(OWNER_ID, function()
        AutoRepairModule:OnMerchantShow()
    end)
end

function AutoRepairModule:OnDisable()
    OneWoW.Merchant.UnregisterCallback(OWNER_ID)
end

function AutoRepairModule:OnMerchantShow()
    if not CanMerchantRepair() then return end

    local repairAllCost, canRepair = GetRepairAllCost()
    if not canRepair or repairAllCost <= 0 then return end

    local useGuildBank = ns.ModuleRegistry:GetToggleValue("autorepair", "use_guild_bank") and CanGuildBankRepair()

    if useGuildBank then
        RepairAllItems(true)
        print(string.format("|cFFFFD100OneWoW QoL:|r Auto-repaired using guild bank for %s", OneWoW.Format.FormatGold(repairAllCost)))
    elseif repairAllCost <= GetMoney() then
        RepairAllItems(false)
        print(string.format("|cFFFFD100OneWoW QoL:|r Auto-repaired for %s", OneWoW.Format.FormatGold(repairAllCost)))
    else
        print("|cFFFFD100OneWoW QoL:|r Insufficient funds for auto-repair")
    end
end
