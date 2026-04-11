local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local L = OneWoW_Bags.L
local WH = OneWoW_Bags.WindowHelpers
local BH = OneWoW_Bags.BarHelpers

local pairs = pairs

OneWoW_Bags.GuildBankBar = {}
local GuildBankBar = OneWoW_Bags.GuildBankBar

---@class GuildBankBarFrame : Frame
---@field withdrawBtn table
---@field depositBtn table
---@field logBtn table
---@field goldText FontString
---@field freeSlots FontString
local bagsBarFrame = nil ---@type GuildBankBarFrame?
local tabButtons = {}

local ROW1_Y = 0
local BAR_HEIGHT = 38

local function GetDB()
    return OneWoW_Bags:GetDB()
end

local function GetController()
    return OneWoW_Bags.GuildBankController
end

function GuildBankBar:Create(parent)
    if bagsBarFrame then return bagsBarFrame end

    bagsBarFrame = BH:CreateBarFrame(parent, "OneWoW_GuildBankBagsBar", BAR_HEIGHT)

    local _, rightInsetCreate = WH:GetItemGridChromeInsets(GetDB().global.bankHideScrollBar)

    GuildBankBar:BuildTabButtons()

    local withdrawBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["GUILD_BANK_WITHDRAW"] or "Withdraw", height = 22 })
    withdrawBtn:SetPoint("RIGHT", bagsBarFrame, "RIGHT", -rightInsetCreate, ROW1_Y)
    withdrawBtn:SetScript("OnClick", function(self)
        local controller = GetController()
        if controller and controller.ShowWithdrawMoney then
            controller:ShowWithdrawMoney(self)
        end
    end)
    bagsBarFrame.withdrawBtn = withdrawBtn

    local depositBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["GUILD_BANK_DEPOSIT"] or "Deposit", height = 22 })
    depositBtn:SetPoint("RIGHT", withdrawBtn, "LEFT", -4, 0)
    depositBtn:SetScript("OnClick", function(self)
        local controller = GetController()
        if controller and controller.ShowDepositMoney then
            controller:ShowDepositMoney(self)
        end
    end)
    bagsBarFrame.depositBtn = depositBtn

    local logBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["GUILD_BANK_LOG"] or "Log", height = 22, minWidth = 30 })
    logBtn:SetPoint("RIGHT", depositBtn, "LEFT", -4, 0)
    logBtn:SetScript("OnClick", function()
        local controller = GetController()
        if controller and controller.ToggleLog then
            controller:ToggleLog()
        end
    end)
    bagsBarFrame.logBtn = logBtn

    BH:CreateGoldDisplay(bagsBarFrame, logBtn)

    GuildBankBar:UpdateGold()

    return bagsBarFrame
end

function GuildBankBar:RefreshChromeAnchors()
    if not bagsBarFrame then return end
    local db = GetDB()
    local leftInset, rightInset = WH:GetItemGridChromeInsets(db.global.bankHideScrollBar)
    if bagsBarFrame.withdrawBtn then
        bagsBarFrame.withdrawBtn:ClearAllPoints()
        bagsBarFrame.withdrawBtn:SetPoint("RIGHT", bagsBarFrame, "RIGHT", -rightInset, ROW1_Y)
    end
    if bagsBarFrame.depositBtn and bagsBarFrame.withdrawBtn then
        bagsBarFrame.depositBtn:ClearAllPoints()
        bagsBarFrame.depositBtn:SetPoint("RIGHT", bagsBarFrame.withdrawBtn, "LEFT", -4, 0)
    end
    if bagsBarFrame.logBtn and bagsBarFrame.depositBtn then
        bagsBarFrame.logBtn:ClearAllPoints()
        bagsBarFrame.logBtn:SetPoint("RIGHT", bagsBarFrame.depositBtn, "LEFT", -4, 0)
    end
    if bagsBarFrame.goldText and bagsBarFrame.logBtn then
        bagsBarFrame.goldText:ClearAllPoints()
        bagsBarFrame.goldText:SetPoint("RIGHT", bagsBarFrame.logBtn, "LEFT", -OneWoW_GUI:GetSpacing("SM"), 0)
    end
    if bagsBarFrame.freeSlots and bagsBarFrame.goldText then
        bagsBarFrame.freeSlots:ClearAllPoints()
        bagsBarFrame.freeSlots:SetPoint("RIGHT", bagsBarFrame.goldText, "LEFT", -OneWoW_GUI:GetSpacing("SM"), 0)
    end
    local numTabs = GetNumGuildBankTabs() or 0
    local xOffset = leftInset
    for tabID = 1, numTabs do
        local btn = tabButtons[tabID]
        if btn then
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", bagsBarFrame, "LEFT", xOffset, ROW1_Y)
        end
        xOffset = xOffset + 30
    end
end

function GuildBankBar:BuildTabButtons()
    if not bagsBarFrame then return end

    BH:RecycleTabButtons(tabButtons)
    tabButtons = {}

    local numTabs = GetNumGuildBankTabs() or 0
    local xOffset = select(1, WH:GetItemGridChromeInsets(GetDB().global.bankHideScrollBar))

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
        if originalTab then
            local _, _, origViewable = GetGuildBankTabInfo(originalTab)
            if origViewable then
                QueryGuildBankTab(originalTab)
            end
        end
    end
end

function GuildBankBar:CreateTabButton(parent, tabID, tabName, tabIcon, isViewable)
    local db = GetDB()
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
        local tName = self.tabName or format(L["GUILD_BANK_TAB"], self.tabID)
        GameTooltip:SetText(tName, 1, 1, 1)
        if self.isViewable then
            local _, _, _, _, _, remainingWithdrawals = GetGuildBankTabInfo(self.tabID)
            if remainingWithdrawals == -1 then
                GameTooltip:AddLine(L["GUILD_BANK_WITHDRAWALS_UNLIMITED"], 0.4, 1, 0.4)
            elseif remainingWithdrawals and remainingWithdrawals > 0 then
                GameTooltip:AddLine(format(L["GUILD_BANK_WITHDRAWALS_FORMAT"], remainingWithdrawals), 0.4, 1, 0.4)
            elseif remainingWithdrawals == 0 then
                GameTooltip:AddLine(L["GUILD_BANK_WITHDRAWALS_NONE"], 1, 0.4, 0.4)
            end
            local GBSet = OneWoW_Bags.GuildBankSet
            if GBSet and GBSet.slots[self.tabID] then
                local usedSlots = 0
                local totalSlots = #GBSet.slots[self.tabID]
                for _, button in pairs(GBSet.slots[self.tabID]) do
                    if button.owb_hasItem then usedSlots = usedSlots + 1 end
                end
                GameTooltip:AddLine(format(L["GUILD_BANK_SLOTS_FORMAT"], usedSlots, totalSlots), 0.7, 0.7, 0.7)
            end
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function(self, mouseButton)
        if not self.isViewable then return end

        if mouseButton == "RightButton" and OneWoW_Bags.guildBankOpen then
            local controller = GetController()
            if controller and controller.OpenTabEditor then
                controller:OpenTabEditor(self.tabID)
            end
            return
        end

        local controller = GetController()
        if controller and controller.ToggleSelectedTab then
            controller:ToggleSelectedTab(self.tabID)
        end
    end)

    return btn
end

function GuildBankBar:OpenTabEditor(tabID)
    if not GuildBankPopupFrame then return end
    if not CanEditGuildBankTabInfo() then return end
    GuildBankPopupFrame:Hide()
    GuildBankPopupFrame.mode = IconSelectorPopupFrameModes.Edit
    GuildBankPopupFrame:Show()
    GuildBankPopupFrame:SetParent(UIParent)
    GuildBankPopupFrame:ClearAllPoints()
    GuildBankPopupFrame:SetClampedToScreen(true)
    GuildBankPopupFrame:SetClampRectInsets(0, 0, 0, 0)
    GuildBankPopupFrame:SetFrameLevel(999)
    local gbWindow = OneWoW_Bags.GuildBankGUI:GetMainWindow()
    if gbWindow then
        GuildBankPopupFrame:SetPoint("TOPLEFT", gbWindow, "TOPRIGHT", 2, 0)
    else
        GuildBankPopupFrame:SetPoint("CENTER")
    end
end

function GuildBankBar:UpdateTabHighlights()
    BH:UpdateTabHighlights(tabButtons, GetDB().global.guildBankSelectedTab)
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
    BH:UpdateFreeSlots(bagsBarFrame, free, total)
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
    BH:ResetBar(bagsBarFrame)
    bagsBarFrame = nil
    tabButtons = {}
end
