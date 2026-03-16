local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.GuildBankBagsBar = {}
local GBBagsBar = OneWoW_Bags.GuildBankBagsBar

local bagsBarFrame = nil
local tabButtons = {}
local OneWoW_GUI = OneWoW_Bags.GUILib

local function T(key)
    if OneWoW_GUI then return OneWoW_GUI:GetThemeColor(key) end
    if OneWoW_Bags.Constants and OneWoW_Bags.Constants.THEME and OneWoW_Bags.Constants.THEME[key] then
        return unpack(OneWoW_Bags.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if OneWoW_GUI then return OneWoW_GUI:GetSpacing(key) end
    return 8
end

local function FormatGold(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    if gold > 0 then
        return string.format("|cFFFFD100%dg|r |cFFC0C0C0%ds|r |cFFAD6A24%dc|r", gold, silver, cop)
    elseif silver > 0 then
        return string.format("|cFFC0C0C0%ds|r |cFFAD6A24%dc|r", silver, cop)
    else
        return string.format("|cFFAD6A24%dc|r", cop)
    end
end

function GBBagsBar:Create(parent)
    if bagsBarFrame then return bagsBarFrame end

    local Constants = OneWoW_Bags.Constants
    local L = OneWoW_Bags.L
    local C = Constants.GUI
    local BACKDROP = OneWoW_GUI and OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS or {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    }

    bagsBarFrame = CreateFrame("Frame", "OneWoW_GuildBankBagsBar", parent, "BackdropTemplate")
    bagsBarFrame:SetHeight(C.BAGSBAR_HEIGHT)
    bagsBarFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bagsBarFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bagsBarFrame:SetBackdrop(BACKDROP)
    bagsBarFrame:SetBackdropColor(T("BG_TERTIARY"))
    bagsBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    GBBagsBar:BuildTabButtons()

    local freeSlots = bagsBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    freeSlots:SetPoint("RIGHT", bagsBarFrame, "RIGHT", -S("SM"), 0)
    freeSlots:SetTextColor(T("TEXT_SECONDARY"))
    bagsBarFrame.freeSlots = freeSlots

    local goldText = bagsBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldText:SetPoint("RIGHT", freeSlots, "LEFT", -S("SM"), 0)
    bagsBarFrame.goldText = goldText
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

    for tabID = 1, numTabs do
        local name, icon, isViewable = GetGuildBankTabInfo(tabID)
        local btn = GBBagsBar:CreateTabButton(bagsBarFrame, tabID, name, icon, isViewable)
        btn:SetPoint("LEFT", bagsBarFrame, "LEFT", xOffset, 0)
        tabButtons[tabID] = btn
        xOffset = xOffset + 30
    end
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

    if OneWoW_GUI then
        btn._skinnedIcon = icon
        OneWoW_GUI:SkinIconFrame(btn, { preset = "clean" })
    end

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
    if bagsBarFrame then bagsBarFrame:Hide(); bagsBarFrame:SetParent(UIParent) end
    bagsBarFrame = nil
    tabButtons = {}
end
