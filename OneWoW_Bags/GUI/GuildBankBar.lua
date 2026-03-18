local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.GuildBankBar = {}
local GBBar = OneWoW_Bags.GuildBankBar

local bagsBarFrame = nil
local tabButtons = {}
local OneWoW_GUI = OneWoW_Bags.GUILib
local T = OneWoW_Bags.T
local S = OneWoW_Bags.S

local ROW1_Y = 12
local ROW2_Y = -14
local BAR_HEIGHT = 58

function GBBar:Create(parent)
    if bagsBarFrame then return bagsBarFrame end

    local L = OneWoW_Bags.L

    bagsBarFrame = CreateFrame("Frame", "OneWoW_GuildBankBagsBar", parent, "BackdropTemplate")
    bagsBarFrame:SetHeight(BAR_HEIGHT)
    bagsBarFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bagsBarFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bagsBarFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    bagsBarFrame:SetBackdropColor(T("BG_TERTIARY"))
    bagsBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    GBBar:BuildTabButtons()

    local withdrawBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["GUILD_BANK_WITHDRAW"] or "Withdraw", height = 22 })
    withdrawBtn:SetPoint("RIGHT", bagsBarFrame, "RIGHT", -S("SM"), ROW1_Y)
    withdrawBtn:SetScript("OnClick", function(self)
        if not OneWoW_Bags.guildBankOpen then return end
        if not CanWithdrawGuildBankMoney() then return end
        OneWoW_Bags:ShowMoneyDialog({
            title = L["GUILD_BANK_TITLE"] or "Guild Bank",
            anchorFrame = self,
            onWithdraw = function(copper)
                WithdrawGuildBankMoney(copper)
                C_Timer.After(0.3, function() GBBar:UpdateGold() end)
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
                C_Timer.After(0.3, function() GBBar:UpdateGold() end)
            end,
        })
    end)
    bagsBarFrame.depositBtn = depositBtn

    local goldText = bagsBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldText:SetPoint("RIGHT", depositBtn, "LEFT", -S("SM"), 0)
    bagsBarFrame.goldText = goldText

    local freeSlots = bagsBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    freeSlots:SetPoint("RIGHT", goldText, "LEFT", -S("SM"), 0)
    freeSlots:SetTextColor(T("TEXT_SECONDARY"))
    bagsBarFrame.freeSlots = freeSlots

    GBBar:UpdateGold()

    return bagsBarFrame
end

function GBBar:BuildTabButtons()
    if not bagsBarFrame then return end

    for _, btn in pairs(tabButtons) do
        btn:Hide()
        btn:ClearAllPoints()
        btn:SetParent(UIParent)
    end
    tabButtons = {}

    local xOffset = S("SM")
    local numTabs = GetNumGuildBankTabs() or 0

    for tabID = 1, numTabs do
        local name, icon, isViewable = GetGuildBankTabInfo(tabID)
        local btn = GBBar:CreateTabButton(bagsBarFrame, tabID, name, icon, isViewable)
        btn:SetPoint("LEFT", bagsBarFrame, "LEFT", xOffset, ROW1_Y)
        tabButtons[tabID] = btn
        xOffset = xOffset + 30
    end
end

function GBBar:CreateTabButton(parent, tabID, tabName, tabIcon, isViewable)
    local L = OneWoW_Bags.L

    local btn = CreateFrame("Button", "OneWoW_GuildBankTab" .. tabID, parent)
    btn:SetSize(26, 26)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    btn.icon = icon
    btn.tabID = tabID
    btn.isViewable = isViewable

    if tabIcon then icon:SetTexture(tabIcon) else icon:SetAtlas("Banker") end
    if not isViewable then icon:SetDesaturated(true) end

    btn._skinnedIcon = icon
    OneWoW_GUI:SkinIconFrame(btn, { preset = "clean" })

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local tName = tabName or (L["GUILD_BANK_TAB"] and L["GUILD_BANK_TAB"]:format(self.tabID) or ("Tab " .. self.tabID))
        GameTooltip:SetText(tName, 1, 1, 1)
        if self.isViewable then
            local GBSet = OneWoW_Bags.GuildBankSet
            if GBSet and GBSet.slots[self.tabID] then
                local itemCount = 0
                for _, button in pairs(GBSet.slots[self.tabID]) do
                    if button.owb_hasItem then itemCount = itemCount + 1 end
                end
                GameTooltip:AddLine(string.format("%d/98", itemCount), 0.7, 0.7, 0.7)
            end
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function(self, mouseButton)
        if not self.isViewable then return end

        if mouseButton == "RightButton" and OneWoW_Bags.guildBankOpen then
            SetCurrentGuildBankTab(self.tabID)
            GBBar:OpenTabEditor(self.tabID)
            return
        end

        local db = OneWoW_Bags.db
        db.global.guildBankSelectedTab = (db.global.guildBankSelectedTab == self.tabID) and nil or self.tabID

        SetCurrentGuildBankTab(self.tabID)
        QueryGuildBankTab(self.tabID)

        GBBar:UpdateTabHighlights()
        if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.RefreshLayout then
            C_Timer.After(0.1, function()
                if OneWoW_Bags.GuildBankSet then
                    OneWoW_Bags.GuildBankSet:UpdateTab(self.tabID)
                end
                OneWoW_Bags.GuildBankGUI:RefreshLayout()
            end)
        end
    end)

    return btn
end

function GBBar:OpenTabEditor(tabID)
    if not GuildBankPopupFrame then return end
    if not CanEditGuildBankTabInfo(tabID) then return end
    GuildBankPopupFrame:Hide()
    GuildBankPopupFrame.mode = IconSelectorPopupFrameModes.Edit
    GuildBankPopupFrame:Show()
    GuildBankPopupFrame:SetParent(UIParent)
    GuildBankPopupFrame:ClearAllPoints()
    GuildBankPopupFrame:SetClampedToScreen(true)
    GuildBankPopupFrame:SetFrameLevel(999)
    local gbWindow = OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI:GetMainWindow()
    if gbWindow then
        GuildBankPopupFrame:SetPoint("TOPLEFT", gbWindow, "TOPRIGHT", 2, 0)
    else
        GuildBankPopupFrame:SetPoint("CENTER")
    end
end

function GBBar:UpdateTabHighlights()
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

function GBBar:UpdateGold()
    if not bagsBarFrame or not bagsBarFrame.goldText then return end
    local money = GetGuildBankMoney and GetGuildBankMoney() or 0
    bagsBarFrame.goldText:SetText(OneWoW_GUI:FormatGold(money))
end

function GBBar:UpdateFreeSlots(free, total)
    if not bagsBarFrame or not bagsBarFrame.freeSlots then return end
    bagsBarFrame.freeSlots:SetText(string.format("%d/%d", free, total))
end

function GBBar:GetFrame()
    return bagsBarFrame
end

function GBBar:SetShown(show)
    if bagsBarFrame then
        bagsBarFrame:SetShown(show)
    end
end

function GBBar:Reset()
    if bagsBarFrame then
        bagsBarFrame:Hide()
        bagsBarFrame:SetParent(UIParent)
    end
    bagsBarFrame = nil
    tabButtons = {}
end
