local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.GuildBankBagsBar = {}
local GBBagsBar = OneWoW_Bags.GuildBankBagsBar

local bagsBarFrame = nil
local tabButtons = {}
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

function GBBagsBar:Create(parent)
    if bagsBarFrame then return bagsBarFrame end

    local Constants = OneWoW_Bags.Constants
    local L = OneWoW_Bags.L
    local C = Constants.GUI

    bagsBarFrame = CreateFrame("Frame", "OneWoW_GuildBankBagsBar", parent, "BackdropTemplate")
    bagsBarFrame:SetHeight(BAR_HEIGHT)
    bagsBarFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bagsBarFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bagsBarFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    bagsBarFrame:SetBackdropColor(T("BG_TERTIARY"))
    bagsBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    GBBagsBar:BuildTabButtons()

    local withdrawBtn = CreateBarButton(bagsBarFrame, L["GUILD_BANK_WITHDRAW"])
    withdrawBtn:SetPoint("RIGHT", bagsBarFrame, "RIGHT", -S("SM"), ROW1_Y)
    withdrawBtn:SetScript("OnClick", function(self)
        if not OneWoW_Bags.guildBankOpen then return end
        local withdrawConfig = nil
        if CanWithdrawGuildBankMoney() then
            withdrawConfig = function(copper)
                WithdrawGuildBankMoney(copper)
                C_Timer.After(0.3, function() GBBagsBar:UpdateGold() end)
            end
        end
        if not withdrawConfig then return end
        OneWoW_Bags:ShowMoneyDialog({
            title = L["GUILD_BANK_TITLE"],
            anchorFrame = self,
            onWithdraw = withdrawConfig,
        })
    end)
    bagsBarFrame.withdrawBtn = withdrawBtn

    local depositBtn = CreateBarButton(bagsBarFrame, L["GUILD_BANK_DEPOSIT"])
    depositBtn:SetPoint("RIGHT", withdrawBtn, "LEFT", -4, 0)
    depositBtn:SetScript("OnClick", function(self)
        if not OneWoW_Bags.guildBankOpen then return end
        OneWoW_Bags:ShowMoneyDialog({
            title = L["GUILD_BANK_TITLE"],
            anchorFrame = self,
            onDeposit = function(copper)
                DepositGuildBankMoney(copper)
                C_Timer.After(0.3, function() GBBagsBar:UpdateGold() end)
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

    local row2 = CreateFrame("Frame", nil, bagsBarFrame)
    row2:SetPoint("BOTTOMLEFT", bagsBarFrame, "BOTTOMLEFT", S("SM"), 3)
    row2:SetPoint("BOTTOMRIGHT", bagsBarFrame, "BOTTOMRIGHT", -(S("SM") + 18), 3)
    row2:SetHeight(22)
    bagsBarFrame.row2 = row2

    local gap = 4

    local logBtn = CreateBarButton(row2, L["GUILD_BANK_LOG"])
    logBtn:SetPoint("LEFT", row2, "LEFT", 0, 0)
    logBtn:SetHeight(22)
    logBtn:SetScript("OnClick", function()
        if OneWoW_Bags.GuildBankGUI then
            local currentMode = OneWoW_Bags.GuildBankGUI:GetContentMode()
            if currentMode == "log" then
                OneWoW_Bags.GuildBankGUI:SetContentMode("items")
            else
                OneWoW_Bags.GuildBankGUI:SetContentMode("log")
            end
            GBBagsBar:UpdateRow2Highlights()
        end
    end)
    bagsBarFrame.logBtn = logBtn

    local moneyLogBtn = CreateBarButton(row2, L["GUILD_BANK_MONEY_LOG"])
    moneyLogBtn:SetPoint("LEFT", logBtn, "RIGHT", gap, 0)
    moneyLogBtn:SetHeight(22)
    moneyLogBtn:SetScript("OnClick", function()
        if OneWoW_Bags.GuildBankGUI then
            local currentMode = OneWoW_Bags.GuildBankGUI:GetContentMode()
            if currentMode == "moneylog" then
                OneWoW_Bags.GuildBankGUI:SetContentMode("items")
            else
                OneWoW_Bags.GuildBankGUI:SetContentMode("moneylog")
            end
            GBBagsBar:UpdateRow2Highlights()
        end
    end)
    bagsBarFrame.moneyLogBtn = moneyLogBtn

    local infoBtn = CreateBarButton(row2, L["GUILD_BANK_INFO"])
    infoBtn:SetPoint("LEFT", moneyLogBtn, "RIGHT", gap, 0)
    infoBtn:SetHeight(22)
    infoBtn:SetScript("OnClick", function()
        if OneWoW_Bags.GuildBankGUI then
            local currentMode = OneWoW_Bags.GuildBankGUI:GetContentMode()
            if currentMode == "info" then
                OneWoW_Bags.GuildBankGUI:SetContentMode("items")
            else
                OneWoW_Bags.GuildBankGUI:SetContentMode("info")
            end
            GBBagsBar:UpdateRow2Highlights()
        end
    end)
    bagsBarFrame.infoBtn = infoBtn

    local function UpdateRow2Widths()
        local w = row2:GetWidth()
        if w < 10 then return end
        local btnW = math.floor((w - (2 * gap)) / 3)
        logBtn:SetWidth(btnW)
        moneyLogBtn:SetWidth(btnW)
        infoBtn:SetWidth(w - (2 * btnW) - (2 * gap))
    end
    row2:SetScript("OnSizeChanged", UpdateRow2Widths)
    C_Timer.After(0, UpdateRow2Widths)

    GBBagsBar:UpdateGold()

    return bagsBarFrame
end

function GBBagsBar:BuildTabButtons()
    if not bagsBarFrame then return end

    for _, btn in pairs(tabButtons) do
        btn:Hide()
        btn:ClearAllPoints()
        btn:SetParent(UIParent)
    end
    tabButtons = {}

    local numTabs = GetNumGuildBankTabs() or 0
    local xOffset = S("SM")

    local lastBtn = nil
    for tabID = 1, numTabs do
        local name, icon, isViewable = GetGuildBankTabInfo(tabID)
        local btn = GBBagsBar:CreateTabButton(bagsBarFrame, tabID, name, icon, isViewable)
        btn:SetPoint("LEFT", bagsBarFrame, "LEFT", xOffset, ROW1_Y)
        tabButtons[tabID] = btn
        lastBtn = btn
        xOffset = xOffset + 30
    end

    bagsBarFrame._lastTabBtn = lastBtn
end

function GBBagsBar:CreateTabButton(parent, tabID, tabName, tabIcon, isViewable)
    local L = OneWoW_Bags.L

    local btn = CreateFrame("Button", "OneWoW_GuildBankTab" .. tabID, parent)
    btn:SetSize(26, 26)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    btn.icon = icon
    btn.tabID = tabID
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
        local tName = tabName or (L["GUILD_BANK_TAB"]:format(self.tabID))
        GameTooltip:SetText(tName, 1, 1, 1)
        if self.isViewable then
            local itemCount = 0
            for slotID = 1, 98 do
                local tex = GetGuildBankItemInfo(self.tabID, slotID)
                if tex then itemCount = itemCount + 1 end
            end
            GameTooltip:AddLine(string.format("%d/98", itemCount), 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine(L["GUILD_BANK_NO_ACCESS"], 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function(self, mouseButton)
        if not self.isViewable then return end

        if mouseButton == "RightButton" and OneWoW_Bags.guildBankOpen then
            SetCurrentGuildBankTab(self.tabID)
            GBBagsBar:OpenTabEditor(self.tabID)
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
        GBBagsBar:UpdateTabHighlights()
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

function GBBagsBar:OpenTabEditor(tabID)
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

function GBBagsBar:UpdateTabHighlights()
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

function GBBagsBar:UpdateViewButtons()
    if OneWoW_Bags.GuildBankInfoBar and OneWoW_Bags.GuildBankInfoBar.UpdateViewButtons then
        OneWoW_Bags.GuildBankInfoBar:UpdateViewButtons()
    end
end

function GBBagsBar:UpdateRow2Highlights()
    if not bagsBarFrame then return end
    local currentMode = "items"
    if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.GetContentMode then
        currentMode = OneWoW_Bags.GuildBankGUI:GetContentMode()
    end

    local buttons = {
        { btn = bagsBarFrame.logBtn, mode = "log" },
        { btn = bagsBarFrame.moneyLogBtn, mode = "moneylog" },
        { btn = bagsBarFrame.infoBtn, mode = "info" },
    }

    for _, entry in ipairs(buttons) do
        local btn = entry.btn
        if btn then
            if entry.mode == currentMode then
                btn.isActive = true
                btn:SetBackdropColor(T("BG_ACTIVE"))
                btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
                if btn.text then btn.text:SetTextColor(T("TEXT_ACCENT")) end
            else
                btn.isActive = false
                btn:SetBackdropColor(T("BTN_NORMAL"))
                btn:SetBackdropBorderColor(T("BTN_BORDER"))
                if btn.text then btn.text:SetTextColor(T("TEXT_PRIMARY")) end
            end
        end
    end
end

function GBBagsBar:UpdateFreeSlots(free, total)
    if not bagsBarFrame or not bagsBarFrame.freeSlots then return end
    local L = OneWoW_Bags.L
    bagsBarFrame.freeSlots:SetText(string.format(L["BANK_FREE_SLOTS_FORMAT"], total - free, total))
end

function GBBagsBar:UpdateGold()
    if not bagsBarFrame or not bagsBarFrame.goldText then return end
    local money = GetGuildBankMoney() or 0
    bagsBarFrame.goldText:SetText(FormatGold(money))
end

function GBBagsBar:GetFrame() return bagsBarFrame end

function GBBagsBar:Reset()
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
