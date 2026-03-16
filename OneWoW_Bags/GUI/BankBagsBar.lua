local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BankBagsBar = {}
local BankBagsBar = OneWoW_Bags.BankBagsBar

local bagsBarFrame = nil
local tabButtons = {}
local tabSettingsMenu = nil
local OneWoW_GUI = OneWoW_Bags.GUILib

local function T(key)
    if OneWoW_GUI then
        return OneWoW_GUI:GetThemeColor(key)
    end
    if OneWoW_Bags.Constants and OneWoW_Bags.Constants.THEME and OneWoW_Bags.Constants.THEME[key] then
        return unpack(OneWoW_Bags.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if OneWoW_GUI then
        return OneWoW_GUI:GetSpacing(key)
    end
    if OneWoW_Bags.Constants and OneWoW_Bags.Constants.SPACING then
        return OneWoW_Bags.Constants.SPACING[key] or 8
    end
    return 8
end

function BankBagsBar:Create(parent)
    if bagsBarFrame then return bagsBarFrame end

    local Constants = OneWoW_Bags.Constants
    local L = OneWoW_Bags.L
    local C = Constants.GUI
    local BACKDROP = OneWoW_GUI and OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS or {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    }

    bagsBarFrame = CreateFrame("Frame", "OneWoW_BankBagsBar", parent, "BackdropTemplate")
    bagsBarFrame:SetHeight(C.BAGSBAR_HEIGHT)
    bagsBarFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bagsBarFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bagsBarFrame:SetBackdrop(BACKDROP)
    bagsBarFrame:SetBackdropColor(T("BG_TERTIARY"))
    bagsBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    BankBagsBar:BuildTabButtons()

    local warbandBtn
    if OneWoW_GUI then
        warbandBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["BANK_WARBAND"], height = 22 })
    else
        warbandBtn = CreateFrame("Button", nil, bagsBarFrame, "BackdropTemplate")
        warbandBtn:SetSize(100, 22)
        warbandBtn:SetBackdrop(BACKDROP)
        warbandBtn:SetBackdropColor(T("BTN_NORMAL"))
        warbandBtn:SetBackdropBorderColor(T("BTN_BORDER"))
        warbandBtn.text = warbandBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        warbandBtn.text:SetPoint("CENTER")
        warbandBtn.text:SetText(L["BANK_WARBAND"])
        warbandBtn.text:SetTextColor(T("TEXT_PRIMARY"))
        local tw = warbandBtn.text:GetStringWidth()
        warbandBtn:SetWidth(tw + 12)
    end
    warbandBtn:SetPoint("RIGHT", bagsBarFrame, "RIGHT", -S("SM"), 0)
    warbandBtn:SetScript("OnClick", function()
        local db = OneWoW_Bags.db
        db.global.bankShowWarband = not db.global.bankShowWarband
        BankBagsBar:UpdateWarbandButton()
        if OneWoW_Bags.BankGUI then
            OneWoW_Bags.BankGUI:OnBankTypeChanged()
        end
    end)
    bagsBarFrame.warbandBtn = warbandBtn

    local sortBtn
    if OneWoW_GUI then
        sortBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["BANK_SORT_DEFAULT"], height = 22 })
    else
        sortBtn = CreateFrame("Button", nil, bagsBarFrame, "BackdropTemplate")
        sortBtn:SetSize(100, 22)
        sortBtn:SetBackdrop(BACKDROP)
        sortBtn:SetBackdropColor(T("BTN_NORMAL"))
        sortBtn:SetBackdropBorderColor(T("BTN_BORDER"))
        sortBtn.text = sortBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sortBtn.text:SetPoint("CENTER")
        sortBtn.text:SetText(L["BANK_SORT_DEFAULT"])
        sortBtn.text:SetTextColor(T("TEXT_PRIMARY"))
        local tw = sortBtn.text:GetStringWidth()
        sortBtn:SetWidth(tw + 12)
    end
    sortBtn:SetPoint("RIGHT", warbandBtn, "LEFT", -4, 0)
    sortBtn:SetScript("OnClick", function()
        local db = OneWoW_Bags.db
        if db.global.bankShowWarband then
            C_Container.SortAccountBankBags()
        else
            C_Container.SortBankBags()
        end
    end)
    bagsBarFrame.sortBtn = sortBtn

    local depositBtn
    if OneWoW_GUI then
        depositBtn = OneWoW_GUI:CreateFitTextButton(bagsBarFrame, { text = L["BANK_DEPOSIT_REAGENTS"], height = 22 })
    else
        depositBtn = CreateFrame("Button", nil, bagsBarFrame, "BackdropTemplate")
        depositBtn:SetSize(120, 22)
        depositBtn:SetBackdrop(BACKDROP)
        depositBtn:SetBackdropColor(T("BTN_NORMAL"))
        depositBtn:SetBackdropBorderColor(T("BTN_BORDER"))
        depositBtn.text = depositBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        depositBtn.text:SetPoint("CENTER")
        depositBtn.text:SetText(L["BANK_DEPOSIT_REAGENTS"])
        depositBtn.text:SetTextColor(T("TEXT_PRIMARY"))
        local tw = depositBtn.text:GetStringWidth()
        depositBtn:SetWidth(tw + 12)
    end
    depositBtn:SetPoint("RIGHT", sortBtn, "LEFT", -4, 0)
    depositBtn:SetScript("OnClick", function()
        local db = OneWoW_Bags.db
        local bankType = db.global.bankShowWarband and Enum.BankType.Account or Enum.BankType.Character
        C_Bank.AutoDepositItemsIntoBank(bankType)
    end)
    bagsBarFrame.depositBtn = depositBtn

    local freeSlots = bagsBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    freeSlots:SetPoint("RIGHT", depositBtn, "LEFT", -S("SM"), 0)
    freeSlots:SetTextColor(T("TEXT_SECONDARY"))
    bagsBarFrame.freeSlots = freeSlots

    BankBagsBar:UpdateWarbandButton()

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

    for i, bagID in ipairs(bagList) do
        local isPurchased = (i <= numPurchased)
        local btn = BankBagsBar:CreateTabButton(bagsBarFrame, bagID, i, isPurchased)
        btn:SetPoint("LEFT", bagsBarFrame, "LEFT", xOffset, 0)
        tabButtons[bagID] = btn
        xOffset = xOffset + 30
    end
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

    if OneWoW_GUI then
        btn._skinnedIcon = icon
        OneWoW_GUI:SkinIconFrame(btn, { preset = "clean" })
    end

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

function BankBagsBar:UpdateWarbandButton()
    if not bagsBarFrame or not bagsBarFrame.warbandBtn then return end
    local db = OneWoW_Bags.db
    local L = OneWoW_Bags.L
    local showWarband = db and db.global and db.global.bankShowWarband

    local btn = bagsBarFrame.warbandBtn
    if showWarband then
        if btn.SetFitText then
            btn:SetFitText(L["BANK_PERSONAL"])
        elseif btn.text then
            btn.text:SetText(L["BANK_PERSONAL"])
        end
        btn:SetBackdropColor(T("BG_ACTIVE"))
        btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
        if btn.text then btn.text:SetTextColor(T("TEXT_ACCENT")) end
    else
        if btn.SetFitText then
            btn:SetFitText(L["BANK_WARBAND"])
        elseif btn.text then
            btn.text:SetText(L["BANK_WARBAND"])
        end
        btn:SetBackdropColor(T("BTN_NORMAL"))
        btn:SetBackdropBorderColor(T("BTN_BORDER"))
        if btn.text then btn.text:SetTextColor(T("TEXT_PRIMARY")) end
    end
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
        bagsBarFrame:Hide()
        bagsBarFrame:SetParent(UIParent)
    end
    bagsBarFrame = nil
    tabButtons = {}
end
