local _, OneWoW_Bags = ...

local C_Bank = C_Bank
local C_Container = C_Container
local C_Timer = C_Timer

OneWoW_Bags.BankController = {}
local BankController = OneWoW_Bags.BankController

function BankController:Create(addon)
    local controller = {}
    controller.addon = addon
    setmetatable(controller, { __index = self })
    return controller
end

function BankController:GetViewMode()
    local db = self.addon:GetDB()
    return db and db.global.bankViewMode or "list"
end

function BankController:SetViewMode(mode)
    local db = self.addon:GetDB()
    if not db or db.global.bankViewMode == mode then return end
    db.global.bankViewMode = mode
    self.addon:RequestLayoutRefresh("bank")
end

function BankController:GetShowEmptySlots()
    local db = self.addon:GetDB()
    if not db then return true end
    local showEmptySlots = db.global.showEmptySlots
    if showEmptySlots == nil then
        return true
    end
    return showEmptySlots
end

function BankController:ToggleEmptySlots()
    local db = self.addon:GetDB()
    if not db then return end
    db.global.showEmptySlots = not db.global.showEmptySlots
    self.addon:RequestLayoutRefresh("bank")
end

function BankController:GetExpansionFilter()
    return self.addon.activeBankExpansionFilter
end

function BankController:SetExpansionFilter(value)
    if value == "ALL" then
        self.addon.activeBankExpansionFilter = nil
    else
        self.addon.activeBankExpansionFilter = value
    end
    self.addon:RequestLayoutRefresh("bank")
end

function BankController:OnSearchChanged(text)
    if self.addon.BankGUI then
        self.addon.BankGUI:OnSearchChanged(text)
    end
end

function BankController:GetSelectedTab()
    local db = self.addon:GetDB()
    return db and db.global.bankSelectedTab or nil
end

function BankController:ToggleSelectedTab(tabID)
    local db = self.addon:GetDB()
    if not db then return end

    if db.global.bankSelectedTab == tabID then
        db.global.bankSelectedTab = nil
    else
        db.global.bankSelectedTab = tabID
    end

    if self.addon.BankBar then
        self.addon.BankBar:UpdateTabHighlights()
    end
    self.addon:RequestLayoutRefresh("bank")
end

function BankController:IsWarbandMode()
    local db = self.addon:GetDB()
    return db and db.global.bankShowWarband == true or false
end

function BankController:SetBankMode(showWarband)
    local db = self.addon:GetDB()
    if not db or db.global.bankShowWarband == showWarband then return end
    db.global.bankShowWarband = showWarband
    if self.addon.BankBar then
        self.addon.BankBar:UpdateBankTypeButtons()
    end
    if self.addon.BankGUI then
        self.addon.BankGUI:OnBankTypeChanged()
    end
end

function BankController:SortBank()
    if not self.addon.bankOpen then return end

    if self:IsWarbandMode() then
        C_Container.SortBank(Enum.BankType.Account)
    else
        C_Container.SortBank(Enum.BankType.Character)
    end
end

function BankController:DepositReagents()
    local bankType = self:IsWarbandMode() and Enum.BankType.Account or Enum.BankType.Character
    C_Bank.AutoDepositItemsIntoBank(bankType)
end

function BankController:ShowWithdrawMoney(anchorFrame)
    if not self.addon.bankOpen or not self:IsWarbandMode() then return end

    self.addon:ShowMoneyDialog({
        title = self.addon.L["BANK_WARBAND_TITLE"],
        anchorFrame = anchorFrame,
        onWithdraw = function(copper)
            if C_Bank.CanWithdrawMoney(Enum.BankType.Account) then
                C_Bank.WithdrawMoney(Enum.BankType.Account, copper)
                C_Timer.After(0.3, function()
                    if self.addon.BankBar then
                        self.addon.BankBar:UpdateGold()
                    end
                end)
            end
        end,
    })
end

function BankController:ShowDepositMoney(anchorFrame)
    if not self.addon.bankOpen or not self:IsWarbandMode() then return end

    self.addon:ShowMoneyDialog({
        title = self.addon.L["BANK_WARBAND_TITLE"],
        anchorFrame = anchorFrame,
        onDeposit = function(copper)
            if C_Bank.CanDepositMoney(Enum.BankType.Account) then
                C_Bank.DepositMoney(Enum.BankType.Account, copper)
                C_Timer.After(0.3, function()
                    if self.addon.BankBar then
                        self.addon.BankBar:UpdateGold()
                    end
                end)
            end
        end,
    })
end
