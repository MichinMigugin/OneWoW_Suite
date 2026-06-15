local _, ns = ...
local AutoRepairModule = ns.ModuleRegistry:Current()
if not AutoRepairModule then return end

function AutoRepairModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_AutoRepair")
        self._frame:SetScript("OnEvent", function(_, event)
            if event == "MERCHANT_SHOW" then
                self:MERCHANT_SHOW()
            end
        end)
    end
    self._frame:RegisterEvent("MERCHANT_SHOW")
end

function AutoRepairModule:OnDisable()
    if self._frame then
        self._frame:UnregisterAllEvents()
    end
end

function AutoRepairModule:MERCHANT_SHOW()
    if not CanMerchantRepair() then return end

    local repairAllCost, canRepair = GetRepairAllCost()
    if not canRepair or repairAllCost <= 0 then return end

    local useGuildBank = ns.ModuleRegistry:GetToggleValue("autorepair", "use_guild_bank") and CanGuildBankRepair()

    if useGuildBank then
        RepairAllItems(true)
        print(string.format("|cFFFFD100OneWoW QoL:|r Auto-repaired using guild bank for %s", C_CurrencyInfo.GetCoinTextureString(repairAllCost)))
    elseif repairAllCost <= GetMoney() then
        RepairAllItems(false)
        print(string.format("|cFFFFD100OneWoW QoL:|r Auto-repaired for %s", C_CurrencyInfo.GetCoinTextureString(repairAllCost)))
    else
        print("|cFFFFD100OneWoW QoL:|r Insufficient funds for auto-repair")
    end
end
