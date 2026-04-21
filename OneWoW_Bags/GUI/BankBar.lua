local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local L = OneWoW_Bags.L
local BankTypes = OneWoW_Bags.BankTypes
local BankSet = OneWoW_Bags.BankSet
local WH = OneWoW_Bags.WindowHelpers
local BH = OneWoW_Bags.BarHelpers

local pairs, ipairs = pairs, ipairs

local C_Bank = C_Bank

OneWoW_Bags.BankBar = {}
local BankBar = OneWoW_Bags.BankBar

---@class BankBarFrame : Frame
---@field withdrawBtn table
---@field depositGoldBtn table
---@field depositReagentsBtn table
---@field warbandBtn table
---@field personalBtn table
---@field goldText FontString
---@field freeSlots FontString
---@field _tabSettingsMenu table
local bagsBarFrame = nil ---@type BankBarFrame?
local tabButtons = {}

local ROW1_Y = 12
local ROW2_Y = -14
local BAR_HEIGHT = 58

local function GetDB()
    return OneWoW_Bags:GetDB()
end

local function GetController()
    return OneWoW_Bags.BankController
end

function BankBar:Create(parent)
    if bagsBarFrame then return bagsBarFrame end

    bagsBarFrame = BH:CreateBarFrame(parent, "OneWoW_BankBagsBar", BAR_HEIGHT)

    local leftInsetCreate, rightInsetCreate = WH:GetItemGridChromeInsets(GetDB().global.bankHideScrollBar)

    BankBar:BuildTabButtons()

    local withdrawBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["BANK_WITHDRAW_GOLD"], height = 22 })
    withdrawBtn:SetPoint("RIGHT", bagsBarFrame, "RIGHT", -rightInsetCreate, ROW1_Y)
    withdrawBtn:SetScript("OnClick", function(self)
        local controller = GetController()
        if controller and controller.ShowWithdrawMoney then
            controller:ShowWithdrawMoney(self)
        end
    end)
    bagsBarFrame.withdrawBtn = withdrawBtn

    local depositGoldBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["BANK_DEPOSIT_GOLD"], height = 22 })
    depositGoldBtn:SetPoint("RIGHT", withdrawBtn, "LEFT", -4, 0)
    depositGoldBtn:SetScript("OnClick", function(self)
        local controller = GetController()
        if controller and controller.ShowDepositMoney then
            controller:ShowDepositMoney(self)
        end
    end)
    bagsBarFrame.depositGoldBtn = depositGoldBtn

    BH:CreateGoldDisplay(bagsBarFrame, depositGoldBtn)

    local depositReagentsBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["BANK_DEPOSIT_REAGENTS"], height = 22 })
    depositReagentsBtn:SetPoint("LEFT", bagsBarFrame, "LEFT", leftInsetCreate, ROW2_Y)
    depositReagentsBtn:SetScript("OnClick", function()
        local controller = GetController()
        if controller and controller.DepositReagents then
            controller:DepositReagents()
        end
    end)
    bagsBarFrame.depositReagentsBtn = depositReagentsBtn

    local warbandBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["BANK_WARBAND"], height = 22 })
    warbandBtn:SetPoint("RIGHT", bagsBarFrame, "RIGHT", -rightInsetCreate, ROW2_Y)
    warbandBtn._defaultEnter = warbandBtn:GetScript("OnEnter")
    warbandBtn._defaultLeave = warbandBtn:GetScript("OnLeave")
    warbandBtn:SetScript("OnEnter", function(self)
        if not self._isActive and self._defaultEnter then self._defaultEnter(self) end
    end)
    warbandBtn:SetScript("OnLeave", function(self)
        if not self._isActive and self._defaultLeave then self._defaultLeave(self) end
    end)
    warbandBtn:SetScript("OnClick", function()
        local controller = GetController()
        if controller and controller.SetBankMode then
            controller:SetBankMode(true)
        end
    end)
    bagsBarFrame.warbandBtn = warbandBtn

    local personalBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["BANK_PERSONAL"], height = 22 })
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
        local controller = GetController()
        if controller and controller.SetBankMode then
            controller:SetBankMode(false)
        end
    end)
    bagsBarFrame.personalBtn = personalBtn

    BankBar:UpdateBankTypeButtons()
    BankBar:UpdateGold()

    return bagsBarFrame
end

function BankBar:RefreshChromeAnchors()
    if not bagsBarFrame then return end
    local db = GetDB()
    local leftInset, rightInset = WH:GetItemGridChromeInsets(OneWoW_Bags.BankController:Get("hideScrollBar"))
    if bagsBarFrame.withdrawBtn then
        bagsBarFrame.withdrawBtn:ClearAllPoints()
        bagsBarFrame.withdrawBtn:SetPoint("RIGHT", bagsBarFrame, "RIGHT", -rightInset, ROW1_Y)
    end
    if bagsBarFrame.warbandBtn then
        bagsBarFrame.warbandBtn:ClearAllPoints()
        bagsBarFrame.warbandBtn:SetPoint("RIGHT", bagsBarFrame, "RIGHT", -rightInset, ROW2_Y)
    end
    if bagsBarFrame.personalBtn and bagsBarFrame.warbandBtn then
        bagsBarFrame.personalBtn:ClearAllPoints()
        bagsBarFrame.personalBtn:SetPoint("RIGHT", bagsBarFrame.warbandBtn, "LEFT", -4, 0)
    end
    if bagsBarFrame.depositReagentsBtn then
        bagsBarFrame.depositReagentsBtn:ClearAllPoints()
        bagsBarFrame.depositReagentsBtn:SetPoint("LEFT", bagsBarFrame, "LEFT", leftInset, ROW2_Y)
    end
    local showWarband = db.global.bankShowWarband
    local bagList = showWarband and BankTypes:GetWarbandTabIDs() or BankTypes:GetBankTabIDs()
    local xOffset = leftInset
    for _, bagID in ipairs(bagList) do
        local btn = tabButtons[bagID]
        if btn then
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", bagsBarFrame, "LEFT", xOffset, ROW1_Y)
        end
        xOffset = xOffset + 30
    end
end

function BankBar:BuildTabButtons()
    if not bagsBarFrame then return end
    local db = GetDB()
    local showWarband = db.global.bankShowWarband

    BH:RecycleTabButtons(tabButtons)
    tabButtons = {}

    local bagList = showWarband and BankTypes:GetWarbandTabIDs() or BankTypes:GetBankTabIDs()
    local xOffset = select(1, WH:GetItemGridChromeInsets(OneWoW_Bags.BankController:Get("hideScrollBar")))

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
    local db = GetDB()
    local btn = CreateFrame("Button", "OneWoW_BankTab" .. bagID, parent)
    btn:SetSize(26, 26)

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
            if BankSet.slots[self.bagID] then
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
            local showWarband = db.global.bankShowWarband
            local bType = showWarband and Enum.BankType.Account or Enum.BankType.Character
            if OneWoW_Bags.bankOpen and C_Bank.CanPurchaseBankTab(bType) and not C_Bank.HasMaxBankTabs(bType) then
                local tabData = C_Bank.FetchNextPurchasableBankTabData(bType)
                if tabData and tabData.tabCost then
                    GameTooltip:SetText(L["BANK_TAB_PURCHASE"], 1, 0.82, 0)
                    GameTooltip:AddLine(OneWoW_GUI:FormatGold(tabData.tabCost), 1, 1, 1)
                else
                    GameTooltip:SetText(L["BANK_TAB_LOCKED"], 0.5, 0.5, 0.5)
                end
            else
                GameTooltip:SetText(L["BANK_TAB_LOCKED"], 0.5, 0.5, 0.5)
            end
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if not isPurchased then
        local showWarband = db.global.bankShowWarband
        local bType = showWarband and Enum.BankType.Account or Enum.BankType.Character
        btn:RegisterForClicks("LeftButtonUp")
        btn:SetAttribute("overrideBankType", nil)
        btn.GetBankTypeForTabPurchase = nil
        btn:SetScript("OnClick", function()
            if not OneWoW_Bags.bankOpen then return end
            if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.ShowPurchasePrompt then
                OneWoW_Bags.BankGUI:ShowPurchasePrompt(bType)
            end
        end)
        return btn
    end

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetAttribute("overrideBankType", nil)
    btn.GetBankTypeForTabPurchase = nil
    btn:SetScript("OnClick", function(self, mouseButton)
        if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.ClearForcedPurchasePrompt then
            OneWoW_Bags.BankGUI:ClearForcedPurchasePrompt()
        end

        if mouseButton == "RightButton" and OneWoW_Bags.bankOpen then
            local showWarband = db.global.bankShowWarband
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

        local controller = GetController()
        if controller and controller.ToggleSelectedTab then
            controller:ToggleSelectedTab(self.bagID)
        end
    end)

    return btn
end

function BankBar:GetTabSettingsMenu()
    if not bagsBarFrame then return nil end
    if not bagsBarFrame._tabSettingsMenu then
        local bankWindow = OneWoW_Bags.BankGUI:GetMainWindow()
        local parent = bankWindow or UIParent
        bagsBarFrame._tabSettingsMenu = CreateFrame("Frame", "OneWoW_BankTabSettingsMenu", parent, "BankPanelTabSettingsMenuTemplate")
        bagsBarFrame._tabSettingsMenu:SetClampedToScreen(true)
        bagsBarFrame._tabSettingsMenu:SetClampRectInsets(0, 0, 0, 0)
        bagsBarFrame._tabSettingsMenu:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, 0)
        bagsBarFrame._tabSettingsMenu:Hide()
    end
    return bagsBarFrame._tabSettingsMenu
end

function BankBar:GetTabData(bagID, tabIndex)
    local db = GetDB()
    local showWarband = db.global.bankShowWarband
    local bankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
    local tabDataList = C_Bank.FetchPurchasedBankTabData(bankType)
    if tabDataList and tabDataList[tabIndex] then return tabDataList[tabIndex] end
    return nil
end

function BankBar:UpdateTabHighlights()
    BH:UpdateTabHighlights(tabButtons, GetDB().global.bankSelectedTab)
end

function BankBar:UpdateBankTypeButtons()
    if not bagsBarFrame then return end
    local db = GetDB()
    local showWarband = db.global.bankShowWarband
    local warbandOnly = OneWoW_Bags.isWarbandOnlyBankAccess == true

    local function setActive(btn)
        if not btn then return end
        btn._isActive = true
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        if btn.text then btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT")) end
    end

    local function setInactive(btn)
        if not btn then return end
        btn._isActive = false
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        if btn.text then btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
    end

    if bagsBarFrame.personalBtn then
        bagsBarFrame.personalBtn:SetShown(not warbandOnly)
    end
    if bagsBarFrame.warbandBtn then
        bagsBarFrame.warbandBtn:Show()
    end

    if showWarband or warbandOnly then
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
    local db = GetDB()
    local showWarband = db.global.bankShowWarband
    if bagsBarFrame.depositGoldBtn then bagsBarFrame.depositGoldBtn:SetShown(showWarband == true) end
    if bagsBarFrame.withdrawBtn then bagsBarFrame.withdrawBtn:SetShown(showWarband == true) end
end

function BankBar:UpdateGold()
    if not bagsBarFrame or not bagsBarFrame.goldText then return end
    local db = GetDB()
    local showWarband = db.global.bankShowWarband
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
    BH:UpdateFreeSlots(bagsBarFrame, free, total)
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
    BH:ResetBar(bagsBarFrame)
    bagsBarFrame = nil
    tabButtons = {}
end
