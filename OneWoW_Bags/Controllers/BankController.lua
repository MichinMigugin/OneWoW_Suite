local _, OneWoW_Bags = ...

local C_Bank = C_Bank
local C_Container = C_Container
local C_Timer = C_Timer

OneWoW_Bags.BankController = {}
local BankController = OneWoW_Bags.BankController

local PERSONAL_KEYS = {
    viewMode         = "bankViewMode",
    columns          = "bankColumns",
    rarityColor      = "bankRarityColor",
    overlays         = "enableBankOverlays",
    hideScrollBar    = "bankHideScrollBar",
    showBagsBar      = "showBankBagsBar",
    showHeaderBar    = "showBankHeaderBar",
    showSearchBar    = "showBankSearchBar",
    showCategoryHeaders = "showBankCategoryHeaders",
    categorySpacing  = "bankCategorySpacing",
    compactCategories = "bankCompactCategories",
    compactGap       = "bankCompactGap",
    expansionFilter  = "enableBankExpansionFilter",
    selectedTab      = "bankSelectedTab",
    collapsedTabs    = "collapsedBankTabSections",
}

local WARBAND_KEYS = {
    viewMode         = "warbandBankViewMode",
    columns          = "warbandBankColumns",
    rarityColor      = "warbandBankRarityColor",
    overlays         = "enableWarbandBankOverlays",
    hideScrollBar    = "warbandBankHideScrollBar",
    showBagsBar      = "showWarbandBankBagsBar",
    showHeaderBar    = "showWarbandBankHeaderBar",
    showSearchBar    = "showWarbandBankSearchBar",
    showCategoryHeaders = "showWarbandBankCategoryHeaders",
    categorySpacing  = "warbandBankCategorySpacing",
    compactCategories = "warbandBankCompactCategories",
    compactGap       = "warbandBankCompactGap",
    expansionFilter  = "enableWarbandBankExpansionFilter",
    selectedTab      = "warbandBankSelectedTab",
    collapsedTabs    = "collapsedWarbandBankTabSections",
}

BankController.PERSONAL_KEYS = PERSONAL_KEYS
BankController.WARBAND_KEYS = WARBAND_KEYS

function BankController:Create(addon)
    local controller = {}
    controller.addon = addon
    setmetatable(controller, { __index = self })
    return controller
end

function BankController:ActiveKeys()
    local db = self.addon:GetDB()
    if db and db.global.bankShowWarband then
        return WARBAND_KEYS
    end
    return PERSONAL_KEYS
end

function BankController:KeysFor(mode)
    if mode == "warband" then return WARBAND_KEYS end
    return PERSONAL_KEYS
end

function BankController:Get(field)
    local db = self.addon:GetDB()
    local keys = self:ActiveKeys()
    return db.global[keys[field]]
end

function BankController:Set(field, value)
    local db = self.addon:GetDB()
    local keys = self:ActiveKeys()
    db.global[keys[field]] = value
end

function BankController:GetFor(mode, field)
    local db = self.addon:GetDB()
    local keys = self:KeysFor(mode)
    return db.global[keys[field]]
end

function BankController:SetFor(mode, field, value)
    local db = self.addon:GetDB()
    local keys = self:KeysFor(mode)
    db.global[keys[field]] = value
end

function BankController:GetViewMode()
    return self:Get("viewMode")
end

function BankController:SetViewMode(mode)
    if self:Get("viewMode") == mode then return end
    self:Set("viewMode", mode)
    self.addon:RequestLayoutRefresh("bank")
end

function BankController:GetShowEmptySlots()
    local db = self.addon:GetDB()
    return db.global.showEmptySlots
end

function BankController:ToggleEmptySlots()
    local db = self.addon:GetDB()
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

function BankController:ToggleCategoryManager()
    self.addon.CategoryManagerUI:Toggle()
end

function BankController:OnSearchChanged(text)
    if self.addon.BankGUI then
        self.addon.BankGUI:OnSearchChanged(text)
    end
end

function BankController:GetSelectedTab()
    return self:Get("selectedTab")
end

function BankController:ToggleSelectedTab(tabID)
    if self:Get("selectedTab") == tabID then
        self:Set("selectedTab", nil)
    else
        self:Set("selectedTab", tabID)
    end

    if self.addon.BankBar then
        self.addon.BankBar:UpdateTabHighlights()
    end
    self.addon:RequestLayoutRefresh("bank")
end

function BankController:IsWarbandMode()
    local db = self.addon:GetDB()
    return db.global.bankShowWarband == true
end

function BankController:SetBankMode(showWarband)
    local db = self.addon:GetDB()
    if db.global.bankShowWarband == showWarband then return end
    if showWarband == false and self.addon.isWarbandOnlyBankAccess then return end
    db.global.bankShowWarband = showWarband
    if self.addon.BankBar then
        self.addon.BankBar:UpdateBankTypeButtons()
    end
    if self.addon.BankInfoBar and self.addon.BankInfoBar.UpdateVisibility then
        self.addon.BankInfoBar:UpdateVisibility()
    end
    if self.addon.BankGUI then
        if self.addon.BankGUI.UpdateWindowWidth then
            self.addon.BankGUI:UpdateWindowWidth()
        end
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
