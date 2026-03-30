local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.GuildBankBar = {}
local GuildBankBar = OneWoW_Bags.GuildBankBar

local bagsBarFrame = nil
local tabButtons = {}
local OneWoW_GUI = OneWoW_Bags.GUILib
local T = OneWoW_Bags.T
local S = OneWoW_Bags.S

local ROW1_Y = 0
local BAR_HEIGHT = 38

function GuildBankBar:Create(parent)
    if bagsBarFrame then return bagsBarFrame end

    local L = OneWoW_Bags.L

    bagsBarFrame = CreateFrame("Frame", "OneWoW_GuildBankBagsBar", parent, "BackdropTemplate")
    bagsBarFrame:SetHeight(BAR_HEIGHT)
    bagsBarFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bagsBarFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bagsBarFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    bagsBarFrame:SetBackdropColor(T("BG_TERTIARY"))
    bagsBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    GuildBankBar:BuildTabButtons()

    local withdrawBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["GUILD_BANK_WITHDRAW"] or "Withdraw", height = 22 })
    withdrawBtn:SetPoint("RIGHT", bagsBarFrame, "RIGHT", -S("SM"), ROW1_Y)
    withdrawBtn:SetScript("OnClick", function(self)
        if not OneWoW_Bags.guildBankOpen then return end
        if not CanWithdrawGuildBankMoney() then return end
        local limit = GetGuildBankWithdrawMoney()
        OneWoW_Bags:ShowMoneyDialog({
            title = L["GUILD_BANK_TITLE"] or "Guild Bank",
            anchorFrame = self,
            onWithdraw = function(copper)
                local max = (limit == -1) and copper or math.min(copper, limit)
                WithdrawGuildBankMoney(max)
                C_Timer.After(0.3, function() GuildBankBar:UpdateGold() end)
            end,
        })
    end)
    bagsBarFrame.withdrawBtn = withdrawBtn

    local depositBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["GUILD_BANK_DEPOSIT"] or "Deposit", height = 22 })
    depositBtn:SetPoint("RIGHT", withdrawBtn, "LEFT", -4, 0)
    depositBtn:SetScript("OnClick", function(self)
        if not OneWoW_Bags.guildBankOpen then return end
        OneWoW_Bags:ShowMoneyDialog({
            title = L["GUILD_BANK_TITLE"] or "Guild Bank",
            anchorFrame = self,
            onDeposit = function(copper)
                DepositGuildBankMoney(copper)
                C_Timer.After(0.3, function() GuildBankBar:UpdateGold() end)
            end,
        })
    end)
    bagsBarFrame.depositBtn = depositBtn

    local logBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["GUILD_BANK_LOG"] or "Log", height = 22, minWidth = 30 })
    logBtn:SetPoint("RIGHT", depositBtn, "LEFT", -4, 0)
    logBtn:SetScript("OnClick", function()
        if OneWoW_Bags.GuildBankLog then
            OneWoW_Bags.GuildBankLog:Toggle()
        end
    end)
    bagsBarFrame.logBtn = logBtn

    local goldText = bagsBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldText:SetPoint("RIGHT", logBtn, "LEFT", -S("SM"), 0)
    bagsBarFrame.goldText = goldText

    local freeSlots = bagsBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    freeSlots:SetPoint("RIGHT", goldText, "LEFT", -S("SM"), 0)
    freeSlots:SetTextColor(T("TEXT_SECONDARY"))
    bagsBarFrame.freeSlots = freeSlots

    GuildBankBar:UpdateGold()

    return bagsBarFrame
end

function GuildBankBar:BuildTabButtons()
    if not bagsBarFrame then return end

    for _, btn in pairs(tabButtons) do
        btn:Hide()
        btn:ClearAllPoints()
        btn:SetParent(UIParent)
    end
    tabButtons = {}

    local numTabs = GetNumGuildBankTabs() or 0
    local xOffset = S("SM")

    for tabID = 1, numTabs do
        local name, icon, isViewable = GetGuildBankTabInfo(tabID)
        local btn = GuildBankBar:CreateTabButton(bagsBarFrame, tabID, name, icon, isViewable)
        btn:SetPoint("LEFT", bagsBarFrame, "LEFT", xOffset, ROW1_Y)
        tabButtons[tabID] = btn
        xOffset = xOffset + 30
    end

    if OneWoW_Bags.guildBankOpen and numTabs > 0 then
        local originalTab = GetCurrentGuildBankTab()
        for tabID = 1, numTabs do
            local _, _, isViewable = GetGuildBankTabInfo(tabID)
            if isViewable and tabID ~= originalTab then
                QueryGuildBankTab(tabID)
            end
        end
        local _, _, origViewable = GetGuildBankTabInfo(originalTab)
        if origViewable then
            QueryGuildBankTab(originalTab)
        end
    end
end

function GuildBankBar:CreateTabButton(parent, tabID, tabName, tabIcon, isViewable)
    local L = OneWoW_Bags.L

    local btn = CreateFrame("Button", "OneWoW_GuildBankTab" .. tabID, parent)
    btn:SetSize(26, 26)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    btn.icon = icon
    btn.tabID = tabID
    btn.tabName = tabName
    btn.isViewable = isViewable

    if tabIcon then
        icon:SetTexture(tabIcon)
    else
        icon:SetAtlas("Banker")
    end
    if not isViewable then
        icon:SetDesaturated(true)
    end

    btn._skinnedIcon = icon
    OneWoW_GUI:SkinIconFrame(btn, { preset = "clean" })

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local tName = self.tabName or (L["GUILD_BANK_TAB"] and L["GUILD_BANK_TAB"]:format(self.tabID) or ("Tab " .. self.tabID))
        GameTooltip:SetText(tName, 1, 1, 1)
        if self.isViewable then
            local _, _, _, _, _, remainingWithdrawals = GetGuildBankTabInfo(self.tabID)
            if remainingWithdrawals == -1 then
                GameTooltip:AddLine("Withdrawals: Unlimited", 0.4, 1, 0.4)
            elseif remainingWithdrawals and remainingWithdrawals > 0 then
                GameTooltip:AddLine(string.format("Withdrawals: %d", remainingWithdrawals), 0.4, 1, 0.4)
            elseif remainingWithdrawals == 0 then
                GameTooltip:AddLine("Withdrawals: None", 1, 0.4, 0.4)
            end
            local GBSet = OneWoW_Bags.GuildBankSet
            if GBSet and GBSet.slots[self.tabID] then
                local usedSlots = 0
                for _, button in pairs(GBSet.slots[self.tabID]) do
                    if button.owb_hasItem then usedSlots = usedSlots + 1 end
                end
                GameTooltip:AddLine(string.format("%d/98", usedSlots), 0.7, 0.7, 0.7)
            end
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function(self, mouseButton)
        if not self.isViewable then return end

        if mouseButton == "RightButton" and OneWoW_Bags.guildBankOpen then
            SetCurrentGuildBankTab(self.tabID)
            GuildBankBar:OpenTabEditor(self.tabID)
            return
        end

        local db = OneWoW_Bags.db
        if db.global.guildBankSelectedTab == self.tabID then
            db.global.guildBankSelectedTab = nil
        else
            db.global.guildBankSelectedTab = self.tabID
        end

        SetCurrentGuildBankTab(self.tabID)
        QueryGuildBankTab(self.tabID)
        GuildBankBar:UpdateTabHighlights()
        if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.RefreshLayout then
            OneWoW_Bags.GuildBankGUI:RefreshLayout()
        end
        if OneWoW_Bags.GuildBankLog then
            OneWoW_Bags.GuildBankLog:OnTabChanged()
        end
    end)

    return btn
end

function GuildBankBar:OpenTabEditor(tabID)
    if not GuildBankPopupFrame then return end
    if not CanEditGuildBankTabInfo(tabID) then return end
    GuildBankPopupFrame:Hide()
    GuildBankPopupFrame.mode = IconSelectorPopupFrameModes.Edit
    GuildBankPopupFrame:Show()
    GuildBankPopupFrame:SetParent(UIParent)
    GuildBankPopupFrame:ClearAllPoints()
    GuildBankPopupFrame:SetClampedToScreen(true)
    GuildBankPopupFrame:SetClampRectInsets(0, 0, 0, 0)
    GuildBankPopupFrame:SetFrameLevel(999)
    local gbWindow = OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI:GetMainWindow()
    if gbWindow then
        GuildBankPopupFrame:SetPoint("TOPLEFT", gbWindow, "TOPRIGHT", 2, 0)
    else
        GuildBankPopupFrame:SetPoint("CENTER")
    end
end

function GuildBankBar:UpdateTabHighlights()
    local db = OneWoW_Bags.db
    local selected = db and db.global.guildBankSelectedTab
    for tabID, btn in pairs(tabButtons) do
        if btn._skinBorder then
            if selected ~= nil and selected == tabID then
                btn._skinBorder:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
            else
                btn._skinBorder:SetBackdropBorderColor(T("BORDER_DEFAULT"))
            end
        end
    end
end

function GuildBankBar:UpdateWithdrawButton()
    if not bagsBarFrame or not bagsBarFrame.withdrawBtn then return end
    if not OneWoW_Bags.guildBankOpen then
        bagsBarFrame.withdrawBtn:Disable()
        return
    end
    local canWithdraw = CanWithdrawGuildBankMoney()
    local limit = GetGuildBankWithdrawMoney()
    local guildMoney = GetGuildBankMoney()
    if canWithdraw and limit ~= 0 and guildMoney > 0 then
        bagsBarFrame.withdrawBtn:Enable()
    else
        bagsBarFrame.withdrawBtn:Disable()
    end
end

function GuildBankBar:UpdateGold()
    if not bagsBarFrame or not bagsBarFrame.goldText then return end
    local money = GetGuildBankMoney and GetGuildBankMoney() or 0
    bagsBarFrame.goldText:SetText(OneWoW_GUI:FormatGold(money))
    GuildBankBar:UpdateWithdrawButton()
end

function GuildBankBar:UpdateFreeSlots(free, total)
    if not bagsBarFrame or not bagsBarFrame.freeSlots then return end
    bagsBarFrame.freeSlots:SetText(string.format("%d/%d", free, total))
end

function GuildBankBar:GetFrame()
    return bagsBarFrame
end

function GuildBankBar:SetShown(show)
    if bagsBarFrame then
        bagsBarFrame:SetShown(show)
    end
end

function GuildBankBar:Reset()
    if bagsBarFrame then
        bagsBarFrame:Hide()
        bagsBarFrame:SetParent(UIParent)
    end
    bagsBarFrame = nil
    tabButtons = {}
end
