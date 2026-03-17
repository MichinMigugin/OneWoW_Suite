local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BankBagsBar = {}
local BankBagsBar = OneWoW_Bags.BankBagsBar

local bagsBarFrame = nil
local tabButtons = {}
local tabSettingsMenu = nil
local OneWoW_GUI = OneWoW_Bags.GUILib

local function T(key)
    return OneWoW_GUI:GetThemeColor(key)
end

local function S(key)
    return OneWoW_GUI:GetSpacing(key)
end

local function FormatNumber(n)
    local s = tostring(n)
    local pos = #s % 3
    if pos == 0 then pos = 3 end
    local parts = { s:sub(1, pos) }
    for i = pos + 1, #s, 3 do
        parts[#parts + 1] = s:sub(i, i + 2)
    end
    return table.concat(parts, ",")
end

local function FormatGold(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    if gold > 0 then
        return string.format("|cFFFFD100%sg|r |cFFC0C0C0%ds|r |cFFAD6A24%dc|r", FormatNumber(gold), silver, cop)
    elseif silver > 0 then
        return string.format("|cFFC0C0C0%ds|r |cFFAD6A24%dc|r", silver, cop)
    else
        return string.format("|cFFAD6A24%dc|r", cop)
    end
end

local ROW1_Y = 12
local ROW2_Y = -14
local BAR_HEIGHT = 58

local function CreateBarButton(parent, label, height)
    local btn = OneWoW_GUI:CreateFitTextButton(parent, { text = label, height = height or 22 })
    btn.isActive = false
    btn._defaultEnter = btn:GetScript("OnEnter")
    btn._defaultLeave = btn:GetScript("OnLeave")
    btn:SetScript("OnEnter", function(self)
        if not self.isActive and self._defaultEnter then self._defaultEnter(self) end
    end)
    btn:SetScript("OnLeave", function(self)
        if not self.isActive and self._defaultLeave then self._defaultLeave(self) end
    end)
    return btn
end

function BankBagsBar:Create(parent)
    if bagsBarFrame then return bagsBarFrame end

    local Constants = OneWoW_Bags.Constants
    local L = OneWoW_Bags.L
    local C = Constants.GUI

    bagsBarFrame = CreateFrame("Frame", "OneWoW_BankBagsBar", parent, "BackdropTemplate")
    bagsBarFrame:SetHeight(BAR_HEIGHT)
    bagsBarFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bagsBarFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bagsBarFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    bagsBarFrame:SetBackdropColor(T("BG_TERTIARY"))
    bagsBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    BankBagsBar:BuildTabButtons()

    local withdrawBtn = CreateBarButton(bagsBarFrame, L["BANK_WITHDRAW_GOLD"])
    withdrawBtn:SetPoint("RIGHT", bagsBarFrame, "RIGHT", -S("SM"), ROW1_Y)
    withdrawBtn:SetScript("OnClick", function(self)
        local db = OneWoW_Bags.db
        local showWarband = db and db.global and db.global.bankShowWarband
        if not OneWoW_Bags.bankOpen then return end
        if showWarband then
            OneWoW_Bags:ShowMoneyDialog({
                title = L["BANK_WARBAND_TITLE"],
                anchorFrame = self,
                onWithdraw = function(copper)
                    if C_Bank.CanWithdrawMoney(Enum.BankType.Account) then
                        C_Bank.WithdrawMoney(Enum.BankType.Account, copper)
                        C_Timer.After(0.3, function() BankBagsBar:UpdateGold() end)
                    end
                end,
            })
        end
    end)
    bagsBarFrame.withdrawBtn = withdrawBtn

    local depositBtn = CreateBarButton(bagsBarFrame, L["BANK_DEPOSIT_GOLD"])
    depositBtn:SetPoint("RIGHT", withdrawBtn, "LEFT", -4, 0)
    depositBtn:SetScript("OnClick", function(self)
        local db = OneWoW_Bags.db
        local showWarband = db and db.global and db.global.bankShowWarband
        if not OneWoW_Bags.bankOpen then return end
        if showWarband then
            OneWoW_Bags:ShowMoneyDialog({
                title = L["BANK_WARBAND_TITLE"],
                anchorFrame = self,
                onDeposit = function(copper)
                    if C_Bank.CanDepositMoney(Enum.BankType.Account) then
                        C_Bank.DepositMoney(Enum.BankType.Account, copper)
                        C_Timer.After(0.3, function() BankBagsBar:UpdateGold() end)
                    end
                end,
            })
        end
    end)
    bagsBarFrame.depositBtn = depositBtn

    local goldText = bagsBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldText:SetPoint("RIGHT", depositBtn, "LEFT", -S("SM"), 0)
    bagsBarFrame.goldText = goldText

    local freeSlots = bagsBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    freeSlots:SetPoint("RIGHT", goldText, "LEFT", -S("SM"), 0)
    freeSlots:SetTextColor(T("TEXT_SECONDARY"))
    bagsBarFrame.freeSlots = freeSlots

    local row2 = CreateFrame("Frame", nil, bagsBarFrame)
    row2:SetPoint("BOTTOMLEFT", bagsBarFrame, "BOTTOMLEFT", S("SM"), 3)
    row2:SetPoint("BOTTOMRIGHT", bagsBarFrame, "BOTTOMRIGHT", -(S("SM") + 18), 3)
    row2:SetHeight(22)
    bagsBarFrame.row2 = row2

    local gap = 4

    local depositReagentsBtn = CreateBarButton(row2, L["BANK_DEPOSIT_REAGENTS"])
    depositReagentsBtn:SetPoint("LEFT", row2, "LEFT", 0, 0)
    depositReagentsBtn:SetHeight(22)
    depositReagentsBtn:SetScript("OnClick", function()
        local db = OneWoW_Bags.db
        local bankType = db.global.bankShowWarband and Enum.BankType.Account or Enum.BankType.Character
        C_Bank.AutoDepositItemsIntoBank(bankType)
    end)
    bagsBarFrame.depositReagentsBtn = depositReagentsBtn

    local warbandBtn = CreateBarButton(row2, L["BANK_WARBAND"])
    warbandBtn:SetPoint("LEFT", depositReagentsBtn, "RIGHT", gap, 0)
    warbandBtn:SetHeight(22)
    warbandBtn:SetScript("OnClick", function()
        local db = OneWoW_Bags.db
        db.global.bankShowWarband = not db.global.bankShowWarband
        BankBagsBar:UpdateWarbandButton()
        if OneWoW_Bags.BankGUI then
            OneWoW_Bags.BankGUI:OnBankTypeChanged()
        end
    end)
    bagsBarFrame.warbandBtn = warbandBtn

    local function UpdateRow2Widths()
        local w = row2:GetWidth()
        if w < 10 then return end
        local btnW = math.floor((w - gap) / 2)
        depositReagentsBtn:SetWidth(btnW)
        warbandBtn:SetWidth(w - btnW - gap)
    end
    row2:SetScript("OnSizeChanged", UpdateRow2Widths)
    C_Timer.After(0, UpdateRow2Widths)

    BankBagsBar:UpdateWarbandButton()
    BankBagsBar:UpdateGold()
    BankBagsBar:UpdateDepositWithdrawVisibility()

    return bagsBarFrame
end

function BankBagsBar:BuildTabButtons()
    if not bagsBarFrame then return end
    local L = OneWoW_Bags.L
    local db = OneWoW_Bags.db
    local BagTypes = OneWoW_Bags.BagTypes
    local showWarband = db and db.global and db.global.bankShowWarband

    for _, btn in pairs(tabButtons) do
        btn:Hide()
        btn:ClearAllPoints()
        btn:SetParent(UIParent)
    end
    tabButtons = {}

    local bagList = showWarband and BagTypes.WARBAND_BAGS or BagTypes.BANK_BAGS
    local xOffset = S("SM")

    local numPurchased = 0
    if OneWoW_Bags.bankOpen then
        local bankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
        numPurchased = C_Bank.FetchNumPurchasedBankTabs(bankType) or 0
    end

    local lastBtn = nil
    for i, bagID in ipairs(bagList) do
        local isPurchased = (i <= numPurchased)
        local btn = BankBagsBar:CreateTabButton(bagsBarFrame, bagID, i, isPurchased)
        btn:SetPoint("LEFT", bagsBarFrame, "LEFT", xOffset, ROW1_Y)
        tabButtons[bagID] = btn
        lastBtn = btn
        xOffset = xOffset + 30
    end

    bagsBarFrame._lastTabBtn = lastBtn
end

function BankBagsBar:GetTabSettingsMenu()
    if not tabSettingsMenu then
        local bankWindow = OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI:GetMainWindow()
        local parent = bankWindow or UIParent
        tabSettingsMenu = CreateFrame("Frame", "OneWoW_BankTabSettingsMenu", parent, "BankPanelTabSettingsMenuTemplate")
        tabSettingsMenu:SetClampedToScreen(true)
        tabSettingsMenu:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, 0)
        tabSettingsMenu:Hide()
    end
    return tabSettingsMenu
end

function BankBagsBar:CreateTabButton(parent, bagID, tabIndex, isPurchased)
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
        local tabData = BankBagsBar:GetTabData(bagID, tabIndex)
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
            local tabData = BankBagsBar:GetTabData(self.bagID, self.tabIndex)
            local tabName = (tabData and tabData.name and tabData.name ~= "") and tabData.name or (L["BANK_TAB"]:format(self.tabIndex))
            GameTooltip:SetText(tabName, 1, 1, 1)
            local numSlots = C_Container.GetContainerNumSlots(self.bagID)
            if numSlots > 0 then
                local usedSlots = 0
                for slotID = 1, numSlots do
                    local info = C_Container.GetContainerItemInfo(self.bagID, slotID)
                    if info and info.hyperlink then
                        usedSlots = usedSlots + 1
                    end
                end
                GameTooltip:AddLine(string.format("%d/%d", usedSlots, numSlots), 0.7, 0.7, 0.7)
            end
        else
            GameTooltip:SetText(L["BANK_TAB_LOCKED"], 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function(self, mouseButton)
        if not self.isPurchased then return end

        if mouseButton == "RightButton" and OneWoW_Bags.bankOpen then
            local db = OneWoW_Bags.db
            local showWarband = db and db.global and db.global.bankShowWarband
            local bType = showWarband and Enum.BankType.Account or Enum.BankType.Character
            local tabData = BankBagsBar:GetTabData(self.bagID, self.tabIndex)

            if BankFrame and BankFrame.BankPanel then
                BankFrame.BankPanel:SetBankType(bType)
            end

            local menu = BankBagsBar:GetTabSettingsMenu()

            local capturedBagID = self.bagID
            local capturedTabData = tabData
            local dataFunc = function()
                return {
                    GetTabData = function(tabID)
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
            return
        end

        local db = OneWoW_Bags.db
        if db.global.bankSelectedTab == self.bagID then
            db.global.bankSelectedTab = nil
        else
            db.global.bankSelectedTab = self.bagID
        end
        BankBagsBar:UpdateTabHighlights()
        if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
            OneWoW_Bags.BankGUI:RefreshLayout()
        end
    end)

    return btn
end

function BankBagsBar:GetTabData(bagID, tabIndex)
    local db = OneWoW_Bags.db
    local showWarband = db and db.global and db.global.bankShowWarband
    local bankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
    local tabDataList = C_Bank.FetchPurchasedBankTabData(bankType)
    if tabDataList and tabDataList[tabIndex] then
        return tabDataList[tabIndex]
    end
    return nil
end

function BankBagsBar:UpdateTabHighlights()
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

function BankBagsBar:UpdateViewButtons()
    if OneWoW_Bags.BankInfoBar and OneWoW_Bags.BankInfoBar.UpdateViewButtons then
        OneWoW_Bags.BankInfoBar:UpdateViewButtons()
    end
end

function BankBagsBar:UpdateWarbandButton()
    if not bagsBarFrame or not bagsBarFrame.warbandBtn then return end
    local db = OneWoW_Bags.db
    local L = OneWoW_Bags.L
    local showWarband = db and db.global and db.global.bankShowWarband

    local btn = bagsBarFrame.warbandBtn
    if showWarband then
        if btn.text then btn.text:SetText(L["BANK_PERSONAL"]) end
        btn:SetBackdropColor(T("BG_ACTIVE"))
        btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
        if btn.text then btn.text:SetTextColor(T("TEXT_ACCENT")) end
    else
        if btn.text then btn.text:SetText(L["BANK_WARBAND"]) end
        btn:SetBackdropColor(T("BTN_NORMAL"))
        btn:SetBackdropBorderColor(T("BTN_BORDER"))
        if btn.text then btn.text:SetTextColor(T("TEXT_PRIMARY")) end
    end

    BankBagsBar:UpdateDepositWithdrawVisibility()
end

function BankBagsBar:UpdateDepositWithdrawVisibility()
    if not bagsBarFrame then return end
    local db = OneWoW_Bags.db
    local showWarband = db and db.global and db.global.bankShowWarband
    if bagsBarFrame.depositBtn then
        bagsBarFrame.depositBtn:SetShown(showWarband == true)
    end
    if bagsBarFrame.withdrawBtn then
        bagsBarFrame.withdrawBtn:SetShown(showWarband == true)
    end
end

function BankBagsBar:UpdateGold()
    if not bagsBarFrame or not bagsBarFrame.goldText then return end
    local db = OneWoW_Bags.db
    local showWarband = db and db.global and db.global.bankShowWarband

    local money
    if showWarband then
        money = C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
    else
        money = GetMoney() or 0
    end

    bagsBarFrame.goldText:SetText(FormatGold(money))
end

function BankBagsBar:UpdateFreeSlots(free, total)
    if not bagsBarFrame or not bagsBarFrame.freeSlots then return end
    local L = OneWoW_Bags.L
    local text = string.format(L["BANK_FREE_SLOTS_FORMAT"], total - free, total)
    bagsBarFrame.freeSlots:SetText(text)
end

function BankBagsBar:GetFrame()
    return bagsBarFrame
end

function BankBagsBar:Reset()
    if tabSettingsMenu then
        tabSettingsMenu:Hide()
    end
    if bagsBarFrame then
        if bagsBarFrame.hoverZone then
            bagsBarFrame.hoverZone:Hide()
            bagsBarFrame.hoverZone:SetParent(UIParent)
        end
        bagsBarFrame:Hide()
        bagsBarFrame:SetParent(UIParent)
    end
    bagsBarFrame = nil
    tabButtons = {}
end
