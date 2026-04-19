local _, OneWoW_Bags = ...

local C_Timer = C_Timer

OneWoW_Bags.SettingsController = {}
local SettingsController = OneWoW_Bags.SettingsController

local function CancelTimer(timer)
    if timer then
        timer:Cancel()
    end
end

function SettingsController:Create(addon)
    local controller = {}
    controller.addon = addon
    controller.timers = {}
    setmetatable(controller, { __index = self })
    return controller
end

function SettingsController:Debounce(key, delay, callback)
    self.timers[key] = CancelTimer(self.timers[key])
    self.timers[key] = C_Timer.NewTimer(delay, function()
        self.timers[key] = nil
        callback()
    end)
end

function SettingsController:Apply(settingKey, value)
    local db = self.addon:GetDB()
    if not db then return end

    local applier = self.appliers[settingKey]
    if applier then
        applier(self, db, value)
    end
end

SettingsController.appliers = {
    iconSize = function(self, db, value)
        db.global.iconSize = value
        self.addon:RequestLayoutRefresh("all")
    end,
    itemSort = function(self, db, value)
        db.global.itemSort = value
        self.addon:RequestLayoutRefresh("all")
    end,
    enableJunkCategory = function(self, db, value)
        db.global.enableJunkCategory = value
        self.addon:InvalidateCategorization()
        self.addon:RequestLayoutRefresh("all")
        self.addon.CategoryManagerUI:Refresh()
    end,
    enableUpgradeCategory = function(self, db, value)
        db.global.enableUpgradeCategory = value
        self.addon:InvalidateCategorization()
        self.addon:RequestLayoutRefresh("all")
        self.addon.CategoryManagerUI:Refresh()
    end,
    moveRecentToTop = function(self, db, value)
        db.global.moveRecentToTop = value
        self.addon:RequestLayoutRefresh("all")
    end,
    moveOtherToBottom = function(self, db, value)
        db.global.moveOtherToBottom = value
        self.addon:RequestLayoutRefresh("all")
    end,
    pinnedCategoryShowsWhenDisabled = function(self, db, value)
        db.global.pinnedCategoryShowsWhenDisabled = value
        self.addon:InvalidateCategorization()
        self.addon:RequestLayoutRefresh("all")
        if self.addon.CategoryManagerUI and self.addon.CategoryManagerUI.Refresh then
            self.addon.CategoryManagerUI:Refresh()
        end
    end,
    recentItemDuration = function(self, db, value)
        db.global.recentItemDuration = value
        if self.addon.Categories then
            self.addon.Categories:SetRecentItemDuration(value)
        end
    end,
    rarityColor = function(self, db, value)
        db.global.rarityColor = value
        self.addon:RequestVisualRefresh("bags")
    end,
    showNewItems = function(self, db, value)
        db.global.showNewItems = value
        self.addon:RequestVisualRefresh("bags")
    end,
    overlaysEnabled = function(self, db, value)
        if not _G.OneWoW or not _G.OneWoW.SettingsFeatureRegistry then return end
        _G.OneWoW.SettingsFeatureRegistry:SetEnabled("overlays", "general", value)
        _G.OneWoW.OverlayEngine:Refresh()
    end,
    showScrollBar = function(self, db, value)
        db.global.hideScrollBar = not value
        self.addon:RequestWindowReset("bags")
    end,
    showBagsBar = function(self, db, value)
        db.global.showBagsBar = value
        self.addon:RequestLayoutRefresh("bags")
    end,
    showMoneyBar = function(self, db, value)
        db.global.showMoneyBar = value
        self.addon:RequestLayoutRefresh("bags")
    end,
    showCurrencyTrackerCapHighlight = function(self, db, value)
        db.global.showCurrencyTrackerCapHighlight = value
        self.addon:RequestLayoutRefresh("bags")
    end,
    showHeaderBar = function(self, db, value)
        db.global.showHeaderBar = value
        self.addon:RequestLayoutRefresh("bags")
    end,
    showSearchBar = function(self, db, value)
        db.global.showSearchBar = value
        self.addon:RequestLayoutRefresh("bags")
    end,
    enableExpansionFilter = function(self, db, value)
        db.global.enableExpansionFilter = value
        if not value then
            self.addon.activeExpansionFilter = nil
        end
        if self.addon.InfoBar then
            self.addon.InfoBar:UpdateVisibility()
        end
        self.addon:RequestLayoutRefresh("bags")
    end,
    showCategoryHeaders = function(self, db, value)
        db.global.showCategoryHeaders = value
        self.addon:RequestLayoutRefresh("bags")
    end,
    bagColumns = function(self, db, value)
        db.global.bagColumns = value
        self:Debounce("bagColumns", 0.15, function()
            self.addon:RequestLayoutRefresh("bags")
        end)
    end,
    categorySpacing = function(self, db, value)
        db.global.categorySpacing = value
        self:Debounce("categorySpacing", 0.15, function()
            self.addon:RequestLayoutRefresh("bags")
        end)
    end,
    compactGap = function(self, db, value)
        db.global.compactGap = value
        self:Debounce("compactGap", 0.15, function()
            self.addon:RequestLayoutRefresh("bags")
        end)
    end,
    enableInventorySlots = function(self, db, value)
        db.global.enableInventorySlots = value
        self.addon:InvalidateCategorization()
        self.addon:RequestLayoutRefresh("all")
    end,
    compactCategories = function(self, db, value)
        db.global.compactCategories = value
        self.addon:RequestLayoutRefresh("bags")
    end,
    stackItems = function(self, db, value)
        db.global.stackItems = value
        self.addon:RequestLayoutRefresh("all")
    end,
    showUnusableOverlay = function(self, db, value)
        db.global.showUnusableOverlay = value
        self.addon:RequestVisualRefresh("bags")
    end,
    dimJunkItems = function(self, db, value)
        db.global.dimJunkItems = value
        self.addon:RequestVisualRefresh("bags")
    end,
    stripJunkOverlays = function(self, db, value)
        db.global.stripJunkOverlays = value
        self.addon:RequestVisualRefresh("bags")
    end,
    altToShow = function(self, db, value)
        db.global.altToShow = value
    end,
    autoOpen = function(self, db, value)
        db.global.autoOpen = value
    end,
    autoClose = function(self, db, value)
        db.global.autoClose = value
    end,
    autoOpenWithBank = function(self, db, value)
        db.global.autoOpenWithBank = value
    end,
    locked = function(self, db, value)
        db.global.locked = value
    end,
    enableBankUI = function(self, db, value)
        db.global.enableBankUI = value
        if value then return end
        if self.addon.RestoreBankFrame then
            self.addon:RestoreBankFrame()
        end
        if self.addon.RestoreGuildBankFrame then
            self.addon:RestoreGuildBankFrame()
        end
        if self.addon.BankGUI and self.addon.BankGUI:IsShown() then
            self.addon.BankGUI:Hide()
        end
        if self.addon.GuildBankGUI and self.addon.GuildBankGUI:IsShown() then
            self.addon.GuildBankGUI:Hide()
        end
    end,
    bankRarityColor = function(self, db, value)
        db.global.bankRarityColor = value
        self.addon:RequestVisualRefresh("bank_related")
    end,
    enableBankOverlays = function(self, db, value)
        db.global.enableBankOverlays = value
        if value then
            if self.addon.FireCallbacksOnBankButtons then
                self.addon:FireCallbacksOnBankButtons()
            end
        elseif self.addon.ClearBankOverlays then
            self.addon:ClearBankOverlays()
        end
    end,
    showBankScrollBar = function(self, db, value)
        db.global.bankHideScrollBar = not value
        self.addon:RequestWindowReset("bank_related")
    end,
    showBankBagsBar = function(self, db, value)
        db.global.showBankBagsBar = value
        self.addon:RequestLayoutRefresh("bank")
    end,
    showBankHeaderBar = function(self, db, value)
        db.global.showBankHeaderBar = value
        self.addon:RequestLayoutRefresh("bank")
    end,
    showBankSearchBar = function(self, db, value)
        db.global.showBankSearchBar = value
        self.addon:RequestLayoutRefresh("bank")
    end,
    enableBankExpansionFilter = function(self, db, value)
        db.global.enableBankExpansionFilter = value
        if not value then
            self.addon.activeBankExpansionFilter = nil
        end
        if self.addon.BankInfoBar then
            self.addon.BankInfoBar:UpdateViewButtons()
        end
        self.addon:RequestLayoutRefresh("bank")
    end,
    showBankCategoryHeaders = function(self, db, value)
        db.global.showBankCategoryHeaders = value
        self.addon:RequestLayoutRefresh("bank")
    end,
    bankColumns = function(self, db, value)
        db.global.bankColumns = value
        self:Debounce("bankColumns", 0.15, function()
            self.addon:RequestLayoutRefresh("bank_related")
        end)
    end,
    bankCategorySpacing = function(self, db, value)
        db.global.bankCategorySpacing = value
        self:Debounce("bankCategorySpacing", 0.15, function()
            self.addon:RequestLayoutRefresh("bank")
        end)
    end,
    bankCompactCategories = function(self, db, value)
        db.global.bankCompactCategories = value
        self.addon:RequestLayoutRefresh("bank")
    end,
    bankCompactGap = function(self, db, value)
        db.global.bankCompactGap = value
        self:Debounce("bankCompactGap", 0.15, function()
            self.addon:RequestLayoutRefresh("bank")
        end)
    end,
    bankLocked = function(self, db, value)
        db.global.bankLocked = value
    end,
    warbandBankRarityColor = function(self, db, value)
        db.global.warbandBankRarityColor = value
        if self.addon.BankController:IsWarbandMode() then
            self.addon:RequestVisualRefresh("bank_related")
        end
    end,
    enableWarbandBankOverlays = function(self, db, value)
        db.global.enableWarbandBankOverlays = value
        if not self.addon.BankController:IsWarbandMode() then return end
        if value then
            if self.addon.FireCallbacksOnBankButtons then
                self.addon:FireCallbacksOnBankButtons()
            end
        elseif self.addon.ClearBankOverlays then
            self.addon:ClearBankOverlays()
        end
    end,
    showWarbandBankScrollBar = function(self, db, value)
        db.global.warbandBankHideScrollBar = not value
        if self.addon.BankController:IsWarbandMode() then
            self.addon:RequestWindowReset("bank_related")
        end
    end,
    showWarbandBankBagsBar = function(self, db, value)
        db.global.showWarbandBankBagsBar = value
        if self.addon.BankController:IsWarbandMode() then
            self.addon:RequestLayoutRefresh("bank")
        end
    end,
    showWarbandBankHeaderBar = function(self, db, value)
        db.global.showWarbandBankHeaderBar = value
        if self.addon.BankController:IsWarbandMode() then
            self.addon:RequestLayoutRefresh("bank")
        end
    end,
    showWarbandBankSearchBar = function(self, db, value)
        db.global.showWarbandBankSearchBar = value
        if self.addon.BankController:IsWarbandMode() then
            self.addon:RequestLayoutRefresh("bank")
        end
    end,
    enableWarbandBankExpansionFilter = function(self, db, value)
        db.global.enableWarbandBankExpansionFilter = value
        if not value then
            self.addon.activeBankExpansionFilter = nil
        end
        if self.addon.BankInfoBar then
            self.addon.BankInfoBar:UpdateViewButtons()
        end
        if self.addon.BankController:IsWarbandMode() then
            self.addon:RequestLayoutRefresh("bank")
        end
    end,
    showWarbandBankCategoryHeaders = function(self, db, value)
        db.global.showWarbandBankCategoryHeaders = value
        if self.addon.BankController:IsWarbandMode() then
            self.addon:RequestLayoutRefresh("bank")
        end
    end,
    warbandBankColumns = function(self, db, value)
        db.global.warbandBankColumns = value
        self:Debounce("warbandBankColumns", 0.15, function()
            if self.addon.BankController:IsWarbandMode() then
                self.addon:RequestLayoutRefresh("bank_related")
            end
        end)
    end,
    warbandBankCategorySpacing = function(self, db, value)
        db.global.warbandBankCategorySpacing = value
        self:Debounce("warbandBankCategorySpacing", 0.15, function()
            if self.addon.BankController:IsWarbandMode() then
                self.addon:RequestLayoutRefresh("bank")
            end
        end)
    end,
    warbandBankCompactCategories = function(self, db, value)
        db.global.warbandBankCompactCategories = value
        if self.addon.BankController:IsWarbandMode() then
            self.addon:RequestLayoutRefresh("bank")
        end
    end,
    warbandBankCompactGap = function(self, db, value)
        db.global.warbandBankCompactGap = value
        self:Debounce("warbandBankCompactGap", 0.15, function()
            if self.addon.BankController:IsWarbandMode() then
                self.addon:RequestLayoutRefresh("bank")
            end
        end)
    end,
}
