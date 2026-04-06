local _, OneWoW_Bags = ...

local C_Timer = C_Timer

OneWoW_Bags.GuildBankController = {}
local GuildBankController = OneWoW_Bags.GuildBankController

function GuildBankController:Create(addon)
    local controller = {}
    controller.addon = addon
    setmetatable(controller, { __index = self })
    return controller
end

function GuildBankController:GetViewMode()
    local db = self.addon:GetDB()
    return db and db.global.guildBankViewMode or "list"
end

function GuildBankController:SetViewMode(mode)
    local db = self.addon:GetDB()
    if not db or db.global.guildBankViewMode == mode then return end
    db.global.guildBankViewMode = mode
    self.addon:RequestLayoutRefresh("guild")
end

function GuildBankController:GetShowEmptySlots()
    local db = self.addon:GetDB()
    if not db then return true end
    local showEmptySlots = db.global.showEmptySlots
    if showEmptySlots == nil then
        return true
    end
    return showEmptySlots
end

function GuildBankController:ToggleEmptySlots()
    local db = self.addon:GetDB()
    if not db then return end
    db.global.showEmptySlots = not db.global.showEmptySlots
    self.addon:RequestLayoutRefresh("guild")
end

function GuildBankController:OnSearchChanged(text)
    if self.addon.GuildBankGUI then
        self.addon.GuildBankGUI:OnSearchChanged(text)
    end
end

function GuildBankController:GetSelectedTab()
    local db = self.addon:GetDB()
    return db and db.global.guildBankSelectedTab or nil
end

function GuildBankController:ToggleSelectedTab(tabID)
    local db = self.addon:GetDB()
    if not db then return end

    if db.global.guildBankSelectedTab == tabID then
        db.global.guildBankSelectedTab = nil
    else
        db.global.guildBankSelectedTab = tabID
    end

    SetCurrentGuildBankTab(tabID)
    QueryGuildBankTab(tabID)

    if self.addon.GuildBankBar then
        self.addon.GuildBankBar:UpdateTabHighlights()
    end

    if self.addon.GuildBankGUI then
        self.addon.GuildBankGUI:RefreshLayout()
    end

    if self.addon.GuildBankLog then
        self.addon.GuildBankLog:OnTabChanged()
    end
end

function GuildBankController:ToggleLog()
    if self.addon.GuildBankLog then
        self.addon.GuildBankLog:Toggle()
    end
end

function GuildBankController:OpenTabEditor(tabID)
    SetCurrentGuildBankTab(tabID)
    if self.addon.GuildBankBar then
        self.addon.GuildBankBar:OpenTabEditor(tabID)
    end
end

function GuildBankController:ShowWithdrawMoney(anchorFrame)
    if not self.addon.guildBankOpen or not CanWithdrawGuildBankMoney() then return end

    local limit = GetGuildBankWithdrawMoney()
    self.addon:ShowMoneyDialog({
        title = self.addon.L["GUILD_BANK_TITLE"] or "Guild Bank",
        anchorFrame = anchorFrame,
        onWithdraw = function(copper)
            local amount = (limit == -1) and copper or math.min(copper, limit)
            WithdrawGuildBankMoney(amount)
            C_Timer.After(0.3, function()
                if self.addon.GuildBankBar then
                    self.addon.GuildBankBar:UpdateGold()
                end
            end)
        end,
    })
end

function GuildBankController:ShowDepositMoney(anchorFrame)
    if not self.addon.guildBankOpen then return end

    self.addon:ShowMoneyDialog({
        title = self.addon.L["GUILD_BANK_TITLE"] or "Guild Bank",
        anchorFrame = anchorFrame,
        onDeposit = function(copper)
            DepositGuildBankMoney(copper)
            C_Timer.After(0.3, function()
                if self.addon.GuildBankBar then
                    self.addon.GuildBankBar:UpdateGold()
                end
            end)
        end,
    })
end
