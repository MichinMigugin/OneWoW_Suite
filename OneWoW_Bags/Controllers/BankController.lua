local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BagTypes = OneWoW_Bags.BagTypes
local BankTypes = OneWoW_Bags.BankTypes

local C_Bank = C_Bank
local C_Container = C_Container
local C_Timer = C_Timer
local ItemLocation = ItemLocation
local strtrim = strtrim
local tinsert, ipairs = tinsert, ipairs

local DEPOSIT_INTERVAL_SEC = 0.12

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
    showEmptySlots   = "bankShowEmptySlots",
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
    showEmptySlots   = "warbandBankShowEmptySlots",
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
    if self.addon:GetDB().global.bankShowWarband then
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
    return self:Get("showEmptySlots")
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

function BankController:GetActiveBankType()
    if self:IsWarbandMode() then
        return Enum.BankType.Account
    end
    return Enum.BankType.Character
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
    local bankType = self:GetActiveBankType()
    C_Bank.AutoDepositItemsIntoBank(bankType)
end

function BankController:NormalizeSearchText(searchText)
    searchText = strtrim(searchText or "")
    if searchText == "" then return nil end
    local L = OneWoW_Bags.L
    if L and searchText == L["SEARCH_PLACEHOLDER"] then return nil end
    return searchText
end

function BankController:CanTransferSearch(searchText, direction)
    if not self:NormalizeSearchText(searchText) then return false end
    if direction == "toBank" or direction == "fromBank" then
        return self.addon.bankOpen == true
    end
    return false
end

function BankController:CancelTransferTickers()
    if self._bagDepositTicker then
        self._bagDepositTicker:Cancel()
        self._bagDepositTicker = nil
    end
    if self._bankWithdrawTicker then
        self._bankWithdrawTicker:Cancel()
        self._bankWithdrawTicker = nil
    end
end

local function QueueDepositEntry(queuedSlots, seenSlots, bagID, slotID, bankType)
    if not bagID or not slotID or not BagTypes:IsPlayerBag(bagID) then return end

    local slotKey = bagID .. ":" .. slotID
    if seenSlots[slotKey] then return end
    seenSlots[slotKey] = true

    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    if not info or info.isLocked or not info.itemID or not info.hyperlink then return end

    local location = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if not location or not location:IsValid() or not C_Bank.IsItemAllowedInBankType(bankType, location) then return end

    tinsert(queuedSlots, {
        bagID = bagID,
        slotID = slotID,
        itemID = info.itemID,
        hyperlink = info.hyperlink,
    })
end

local function QueueWithdrawEntry(queuedSlots, seenSlots, bagID, slotID, isWarband)
    if not bagID or not slotID then return end

    local inActiveBank = (isWarband and BankTypes:IsWarbandTab(bagID))
        or (not isWarband and BankTypes:IsPersonalBankTab(bagID))
    if not inActiveBank then return end

    local slotKey = bagID .. ":" .. slotID
    if seenSlots[slotKey] then return end
    seenSlots[slotKey] = true

    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    if not info or info.isLocked or not info.itemID or not info.hyperlink then return end

    tinsert(queuedSlots, {
        bagID = bagID,
        slotID = slotID,
        itemID = info.itemID,
        hyperlink = info.hyperlink,
    })
end

local function AppendButtonStackToQueue(queuedSlots, seenSlots, button, queueEntryFn, ...)
    local sourceButtons = button._owb_virtualStackButtons or { button }
    for _, sourceButton in ipairs(sourceButtons) do
        queueEntryFn(queuedSlots, seenSlots, sourceButton.owb_bagID, sourceButton.owb_slotID, ...)
    end
end

function BankController:CollectMatchingBagSlots(searchText)
    local normalized = self:NormalizeSearchText(searchText)
    if not normalized or not self.addon.BagSet then return {} end

    local bankType = self:GetActiveBankType()
    local buttons = self.addon.BagSet:GetAllButtons()
    local WH = OneWoW_Bags.WindowHelpers
    local bagsController = self.addon.BagsController
    -- Bag view only: selectedBag scopes layout (BagView). List/category show all bags.
    if bagsController and bagsController:GetViewMode() == "bag" then
        buttons = WH:FilterByTab(buttons, bagsController:GetSelectedBag(), WH:GetScratchTable("transferBagScope"))
    end
    local matched = WH:FilterBySearch(buttons, normalized, WH:GetScratchTable("transferBagSearch"))
    local expFilter = bagsController and bagsController:GetExpansionFilter() or self.addon.activeExpansionFilter
    matched = WH:FilterByExpansion(matched, expFilter, WH:GetScratchTable("transferBagExpansion"))

    local queuedSlots = {}
    local seenSlots = {}
    for _, button in ipairs(matched) do
        AppendButtonStackToQueue(queuedSlots, seenSlots, button, QueueDepositEntry, bankType)
    end
    return queuedSlots
end

function BankController:CollectMatchingBankSlots(searchText)
    local normalized = self:NormalizeSearchText(searchText)
    if not normalized or not self.addon.BankSet then return {} end

    local isWarband = self:IsWarbandMode()
    local buttons = self.addon.BankSet:GetAllButtons()
    local WH = OneWoW_Bags.WindowHelpers
    buttons = WH:FilterByTab(buttons, self:Get("selectedTab"), WH:GetScratchTable("transferBankScope"))
    local matched = WH:FilterBySearch(buttons, normalized, WH:GetScratchTable("transferBankSearch"))

    local queuedSlots = {}
    local seenSlots = {}
    for _, button in ipairs(matched) do
        AppendButtonStackToQueue(queuedSlots, seenSlots, button, QueueWithdrawEntry, isWarband)
    end
    return queuedSlots
end

function BankController:TransferSearchToBank(searchText)
    if OneWoW_GUI:IsAddonRestricted() or not self.addon.bankOpen then return false end

    local bankType = self:GetActiveBankType()
    if not C_Bank.CanUseBank(bankType) then return false end

    local queue = self:CollectMatchingBagSlots(searchText)
    if #queue == 0 then return false end

    self:QueueBagDeposits(queue, bankType)
    return true
end

function BankController:TransferSearchFromBank(searchText)
    if OneWoW_GUI:IsAddonRestricted() or not self.addon.bankOpen then return false end

    local bankType = self:GetActiveBankType()
    if not C_Bank.CanUseBank(bankType) then return false end

    local queue = self:CollectMatchingBankSlots(searchText)
    if #queue == 0 then return false end

    self:QueueBankWithdrawals(queue, bankType)
    return true
end

function BankController:QueueBagDeposits(queue, bankType)
    self:CancelTransferTickers()

    local index = 1
    local function Finish()
        if self._bagDepositTicker then
            self._bagDepositTicker:Cancel()
            self._bagDepositTicker = nil
        end
        self.addon:RequestLayoutRefresh("all")
    end

    self._bagDepositTicker = C_Timer.NewTicker(DEPOSIT_INTERVAL_SEC, function()
        local entry = queue[index]
        index = index + 1

        if not entry then
            Finish()
            return
        end

        if self.addon.bankOpen and C_Bank.CanUseBank(bankType) then
            local info = C_Container.GetContainerItemInfo(entry.bagID, entry.slotID)
            if info and not info.isLocked and info.itemID == entry.itemID and info.hyperlink == entry.hyperlink then
                local location = ItemLocation:CreateFromBagAndSlot(entry.bagID, entry.slotID)
                if location and location:IsValid() and C_Bank.IsItemAllowedInBankType(bankType, location) then
                    C_Container.UseContainerItem(entry.bagID, entry.slotID, nil, bankType)
                end
            end
        end

        if index > #queue then
            Finish()
        end
    end)
end

function BankController:QueueBankWithdrawals(queue, bankType)
    self:CancelTransferTickers()

    local index = 1
    local function Finish()
        if self._bankWithdrawTicker then
            self._bankWithdrawTicker:Cancel()
            self._bankWithdrawTicker = nil
        end
        self.addon:RequestLayoutRefresh("all")
    end

    self._bankWithdrawTicker = C_Timer.NewTicker(DEPOSIT_INTERVAL_SEC, function()
        local entry = queue[index]
        index = index + 1

        if not entry then
            Finish()
            return
        end

        if self.addon.bankOpen and C_Bank.CanUseBank(bankType) then
            local info = C_Container.GetContainerItemInfo(entry.bagID, entry.slotID)
            if info and not info.isLocked and info.itemID == entry.itemID and info.hyperlink == entry.hyperlink then
                C_Container.UseContainerItem(entry.bagID, entry.slotID)
            end
        end

        if index > #queue then
            Finish()
        end
    end)
end

function BankController:DepositBagButtonStack(button)
    if not self.addon.bankOpen or not button or not button.owb_hasItem then return false end

    local bankType = self:GetActiveBankType()
    if not C_Bank.CanUseBank(bankType) then return false end

    local queuedSlots = {}
    local seenSlots = {}
    AppendButtonStackToQueue(queuedSlots, seenSlots, button, QueueDepositEntry, bankType)

    if #queuedSlots == 0 then return false end

    self:QueueBagDeposits(queuedSlots, bankType)
    return true
end

function BankController:ShowWithdrawMoney(anchorFrame)
    if not self.addon.bankOpen or not self:IsWarbandMode() then return end

    self.addon:ShowMoneyDialog({
        title = ACCOUNT_BANK_PANEL_TITLE,
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
        title = ACCOUNT_BANK_PANEL_TITLE,
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
