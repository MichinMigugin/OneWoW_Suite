local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BankBar = {}
local BankBar = OneWoW_Bags.BankBar

local bagsBarFrame = nil
local tabButtons = {}
local OneWoW_GUI = OneWoW_Bags.GUILib
local T = OneWoW_Bags.T
local S = OneWoW_Bags.S

local ROW1_Y = 12
local ROW2_Y = -14
local BAR_HEIGHT = 58

function BankBar:Create(parent)
    if bagsBarFrame then return bagsBarFrame end

    local L = OneWoW_Bags.L

    bagsBarFrame = CreateFrame("Frame", "OneWoW_BankBagsBar", parent, "BackdropTemplate")
    bagsBarFrame:SetHeight(BAR_HEIGHT)
    bagsBarFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bagsBarFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bagsBarFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    bagsBarFrame:SetBackdropColor(T("BG_TERTIARY"))
    bagsBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    BankBar:BuildTabButtons()

    local withdrawBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["BANK_WITHDRAW_GOLD"] or "Withdraw", height = 22 })
    withdrawBtn:SetPoint("RIGHT", bagsBarFrame, "RIGHT", -S("SM"), ROW1_Y)
    withdrawBtn:SetScript("OnClick", function(self)
        if not OneWoW_Bags.bankOpen then return end
        local db = OneWoW_Bags.db
        if not (db and db.global and db.global.bankShowWarband) then return end
        OneWoW_Bags:ShowMoneyDialog({
            title = L["BANK_WARBAND_TITLE"] or "Warband Bank",
            anchorFrame = self,
            onWithdraw = function(copper)
                if C_Bank.CanWithdrawMoney(Enum.BankType.Account) then
                    C_Bank.WithdrawMoney(Enum.BankType.Account, copper)
                    C_Timer.After(0.3, function() BankBar:UpdateGold() end)
                end
            end,
        })
    end)
    bagsBarFrame.withdrawBtn = withdrawBtn

    local depositGoldBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["BANK_DEPOSIT_GOLD"] or "Deposit", height = 22 })
    depositGoldBtn:SetPoint("RIGHT", withdrawBtn, "LEFT", -4, 0)
    depositGoldBtn:SetScript("OnClick", function(self)
        if not OneWoW_Bags.bankOpen then return end
        local db = OneWoW_Bags.db
        if not (db and db.global and db.global.bankShowWarband) then return end
        OneWoW_Bags:ShowMoneyDialog({
            title = L["BANK_WARBAND_TITLE"] or "Warband Bank",
            anchorFrame = self,
            onDeposit = function(copper)
                if C_Bank.CanDepositMoney(Enum.BankType.Account) then
                    C_Bank.DepositMoney(Enum.BankType.Account, copper)
                    C_Timer.After(0.3, function() BankBar:UpdateGold() end)
                end
            end,
        })
    end)
    bagsBarFrame.depositGoldBtn = depositGoldBtn

    local goldText = bagsBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldText:SetPoint("RIGHT", depositGoldBtn, "LEFT", -S("SM"), 0)
    bagsBarFrame.goldText = goldText

    local freeSlots = bagsBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    freeSlots:SetPoint("RIGHT", goldText, "LEFT", -S("SM"), 0)
    freeSlots:SetTextColor(T("TEXT_SECONDARY"))
    bagsBarFrame.freeSlots = freeSlots

    local depositReagentsBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["BANK_DEPOSIT_REAGENTS"] or "Deposit Reagents", height = 22 })
    depositReagentsBtn:SetPoint("LEFT", bagsBarFrame, "LEFT", S("SM"), ROW2_Y)
    depositReagentsBtn:SetScript("OnClick", function()
        local db = OneWoW_Bags.db
        local bankType = db.global.bankShowWarband and Enum.BankType.Account or Enum.BankType.Character
        C_Bank.AutoDepositItemsIntoBank(bankType)
    end)
    bagsBarFrame.depositReagentsBtn = depositReagentsBtn

    local warbandBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["BANK_WARBAND"] or "Warband", height = 22 })
    warbandBtn:SetPoint("RIGHT", bagsBarFrame, "RIGHT", -S("SM"), ROW2_Y)
    warbandBtn._defaultEnter = warbandBtn:GetScript("OnEnter")
    warbandBtn._defaultLeave = warbandBtn:GetScript("OnLeave")
    warbandBtn:SetScript("OnEnter", function(self)
        if not self._isActive and self._defaultEnter then self._defaultEnter(self) end
    end)
    warbandBtn:SetScript("OnLeave", function(self)
        if not self._isActive and self._defaultLeave then self._defaultLeave(self) end
    end)
    warbandBtn:SetScript("OnClick", function()
        local db = OneWoW_Bags.db
        if db.global.bankShowWarband then return end
        db.global.bankShowWarband = true
        BankBar:UpdateBankTypeButtons()
        if OneWoW_Bags.BankGUI then OneWoW_Bags.BankGUI:OnBankTypeChanged() end
    end)
    bagsBarFrame.warbandBtn = warbandBtn

    local personalBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["BANK_PERSONAL"] or "Personal", height = 22 })
    personalBtn:SetPoint("RIGHT", warbandBtn, "LEFT", -4, 0)
    personalBtn._defaultEnter = personalBtn:GetScript("OnEnter")
    personalBtn._defaultLeave = personalBtn:GetScript("OnLeave")
    personalBtn:SetScript("OnEnter", function(self)
        if not self._isActive and self._defaultEnter then self._defaultEnter(self) end
    end)
    personalBtn:SetScript("OnLeave", function(self)
        if not self._isActive and self._defaultLeave then self._defaultLeave(self) end
    end)
    personalBtn:SetScript("OnClick", function()
        local db = OneWoW_Bags.db
        if not db.global.bankShowWarband then return end
        db.global.bankShowWarband = false
        BankBar:UpdateBankTypeButtons()
        if OneWoW_Bags.BankGUI then OneWoW_Bags.BankGUI:OnBankTypeChanged() end
    end)
    bagsBarFrame.personalBtn = personalBtn

    BankBar:UpdateBankTypeButtons()
    BankBar:UpdateGold()

    return bagsBarFrame
end

function BankBar:BuildTabButtons()
    if not bagsBarFrame then return end
    local db = OneWoW_Bags.db
    local BankTypes = OneWoW_Bags.BankTypes
    local showWarband = db and db.global and db.global.bankShowWarband

    for _, btn in pairs(tabButtons) do
        btn:Hide()
        btn:ClearAllPoints()
        btn:SetParent(UIParent)
    end
    tabButtons = {}

    local bagList = showWarband and BankTypes.ALL_WARBAND_TABS or BankTypes.ALL_BANK_TABS
    local xOffset = S("SM")

    local numPurchased = 0
    if OneWoW_Bags.bankOpen then
        local bankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
        numPurchased = C_Bank.FetchNumPurchasedBankTabs(bankType) or 0
    end

    for i, bagID in ipairs(bagList) do
        local isPurchased = (i <= numPurchased)
        local btn = BankBar:CreateTabButton(bagsBarFrame, bagID, i, isPurchased)
        btn:SetPoint("LEFT", bagsBarFrame, "LEFT", xOffset, ROW1_Y)
        tabButtons[bagID] = btn
        xOffset = xOffset + 30
    end
end

function BankBar:CreateTabButton(parent, bagID, tabIndex, isPurchased)
    local L = OneWoW_Bags.L

    local btn = CreateFrame("Button", "OneWoW_BankTab" .. bagID, parent)
    btn:SetSize(26, 26)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    btn.icon = icon
    btn.bagID = bagID
    btn.tabIndex = tabIndex
    btn.isPurchased = isPurchased

    if isPurchased then
        local tabData = BankBar:GetTabData(bagID, tabIndex)
        if tabData and tabData.icon and tabData.icon > 0 then
            icon:SetTexture(tabData.icon)
        else
            icon:SetAtlas("Banker")
        end
    else
        icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
        icon:SetDesaturated(true)
    end

    btn._skinnedIcon = icon
    OneWoW_GUI:SkinIconFrame(btn, { preset = "clean" })

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if self.isPurchased then
            local tabData = BankBar:GetTabData(self.bagID, self.tabIndex)
            local tabName = (tabData and tabData.name and tabData.name ~= "") and tabData.name or (L["BANK_TAB"] and L["BANK_TAB"]:format(self.tabIndex) or ("Tab " .. self.tabIndex))
            GameTooltip:SetText(tabName, 1, 1, 1)
            local BankSet = OneWoW_Bags.BankSet
            if BankSet and BankSet.slots[self.bagID] then
                local usedSlots, totalSlots = 0, 0
                for _, button in pairs(BankSet.slots[self.bagID]) do
                    totalSlots = totalSlots + 1
                    if button.owb_hasItem then usedSlots = usedSlots + 1 end
                end
                if totalSlots > 0 then
                    GameTooltip:AddLine(string.format("%d/%d", usedSlots, totalSlots), 0.7, 0.7, 0.7)
                end
            end
        else
            GameTooltip:SetText(L["BANK_TAB_LOCKED"] or "Locked", 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function(self, mouseButton)
        if not self.isPurchased then return end

        if mouseButton == "RightButton" and OneWoW_Bags.bankOpen then
            local db = OneWoW_Bags.db
            local showWarband = db and db.global and db.global.bankShowWarband
            local bType = showWarband and Enum.BankType.Account or Enum.BankType.Character
            local tabData = BankBar:GetTabData(self.bagID, self.tabIndex)
            if BankFrame and BankFrame.BankPanel then BankFrame.BankPanel:SetBankType(bType) end
            local menu = BankBar:GetTabSettingsMenu()
            if menu then
                local capturedBagID = self.bagID
                local capturedTabData = tabData
                local dataFunc = function()
                    return {
                        GetTabData = function()
                            return {
                                ID = capturedBagID,
                                icon = capturedTabData and capturedTabData.icon or 0,
                                name = capturedTabData and capturedTabData.name or "",
                                depositFlags = capturedTabData and capturedTabData.depositFlags or 0,
                                bankType = bType,
                            }
                        end
                    }
                end
                menu.GetBankPanel = dataFunc
                menu.GetBankFrame = dataFunc
                menu:OnOpenTabSettingsRequested(self.bagID)
            end
            return
        end

        local db = OneWoW_Bags.db
        if db.global.bankSelectedTab == self.bagID then
            db.global.bankSelectedTab = nil
        else
            db.global.bankSelectedTab = self.bagID
        end
        BankBar:UpdateTabHighlights()
        if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
            OneWoW_Bags.BankGUI:RefreshLayout()
        end
    end)

    return btn
end

function BankBar:GetTabSettingsMenu()
    if not bagsBarFrame then return nil end
    if not bagsBarFrame._tabSettingsMenu then
        local bankWindow = OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI:GetMainWindow()
        local parent = bankWindow or UIParent
        bagsBarFrame._tabSettingsMenu = CreateFrame("Frame", "OneWoW_BankTabSettingsMenu", parent, "BankPanelTabSettingsMenuTemplate")
        bagsBarFrame._tabSettingsMenu:SetClampedToScreen(true)
        bagsBarFrame._tabSettingsMenu:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, 0)
        bagsBarFrame._tabSettingsMenu:Hide()
    end
    return bagsBarFrame._tabSettingsMenu
end

function BankBar:GetTabData(bagID, tabIndex)
    local db = OneWoW_Bags.db
    local showWarband = db and db.global and db.global.bankShowWarband
    local bankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
    local tabDataList = C_Bank.FetchPurchasedBankTabData(bankType)
    if tabDataList and tabDataList[tabIndex] then return tabDataList[tabIndex] end
    return nil
end

function BankBar:UpdateTabHighlights()
    local db = OneWoW_Bags.db
    local selected = db and db.global.bankSelectedTab
    for bagID, btn in pairs(tabButtons) do
        if btn._skinBorder then
            if selected ~= nil and selected == bagID then
                btn._skinBorder:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
            else
                btn._skinBorder:SetBackdropBorderColor(T("BORDER_DEFAULT"))
            end
        end
    end
end

function BankBar:UpdateBankTypeButtons()
    if not bagsBarFrame then return end
    local db = OneWoW_Bags.db
    local showWarband = db and db.global and db.global.bankShowWarband

    local function setActive(btn)
        if not btn then return end
        btn._isActive = true
        btn:SetBackdropColor(T("BG_ACTIVE"))
        btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
        if btn.text then btn.text:SetTextColor(T("TEXT_ACCENT")) end
    end

    local function setInactive(btn)
        if not btn then return end
        btn._isActive = false
        btn:SetBackdropColor(T("BTN_NORMAL"))
        btn:SetBackdropBorderColor(T("BTN_BORDER"))
        if btn.text then btn.text:SetTextColor(T("TEXT_PRIMARY")) end
    end

    if showWarband then
        setActive(bagsBarFrame.warbandBtn)
        setInactive(bagsBarFrame.personalBtn)
    else
        setActive(bagsBarFrame.personalBtn)
        setInactive(bagsBarFrame.warbandBtn)
    end

    BankBar:UpdateDepositWithdrawVisibility()
end

function BankBar:UpdateModeButtons()
    BankBar:UpdateBankTypeButtons()
end

function BankBar:UpdateDepositWithdrawVisibility()
    if not bagsBarFrame then return end
    local db = OneWoW_Bags.db
    local showWarband = db and db.global and db.global.bankShowWarband
    if bagsBarFrame.depositGoldBtn then bagsBarFrame.depositGoldBtn:SetShown(showWarband == true) end
    if bagsBarFrame.withdrawBtn then bagsBarFrame.withdrawBtn:SetShown(showWarband == true) end
end

function BankBar:UpdateGold()
    if not bagsBarFrame or not bagsBarFrame.goldText then return end
    local db = OneWoW_Bags.db
    local showWarband = db and db.global and db.global.bankShowWarband
    if showWarband then
        local money = C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
        bagsBarFrame.goldText:SetText(OneWoW_GUI:FormatGold(money))
        bagsBarFrame.goldText:Show()
    else
        bagsBarFrame.goldText:SetText("")
        bagsBarFrame.goldText:Hide()
    end
end

function BankBar:UpdateFreeSlots(free, total)
    if not bagsBarFrame or not bagsBarFrame.freeSlots then return end
    bagsBarFrame.freeSlots:SetText(string.format("%d/%d", free, total))
end

function BankBar:GetFrame()
    return bagsBarFrame
end

function BankBar:SetShown(show)
    if bagsBarFrame then
        bagsBarFrame:SetShown(show)
    end
end

function BankBar:Reset()
    if bagsBarFrame then
        bagsBarFrame:Hide()
        bagsBarFrame:SetParent(UIParent)
    end
    bagsBarFrame = nil
    tabButtons = {}
end
