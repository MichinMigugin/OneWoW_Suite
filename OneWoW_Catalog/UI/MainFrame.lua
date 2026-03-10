-- OneWoW Addon File
-- OneWoW_Catalog/UI/MainFrame.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local MainWindow = nil

function ns.UI:Show(tabName)
    if not MainWindow then
        local savedTab = _G.OneWoW_Catalog.db.global.lastTab
        self:CreateMainFrame(tabName or savedTab or "journal")
    else
        MainWindow:Show()
        if tabName and MainWindow.SelectTab then
            MainWindow:SelectTab(tabName)
        end
    end
end

function ns.UI:Hide()
    if MainWindow then MainWindow:Hide() end
end

function ns.UI:Toggle()
    if MainWindow and MainWindow:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function ns.UI:Reset()
    if MainWindow then MainWindow:Hide() end
    MainWindow = nil
end

function ns.UI:CreateMainFrame(defaultTab)
    local addon = _G.OneWoW_Catalog
    if not addon or not addon.db or not addon.db.global then return nil end

    local savedSize = addon.db.global.mainFrameSize
    local width  = (savedSize and savedSize.width)  or ns.Constants.GUI.MAIN_FRAME_WIDTH
    local height = (savedSize and savedSize.height) or ns.Constants.GUI.MAIN_FRAME_HEIGHT

    local frame = CreateFrame("Frame", "OneWoW_CatalogMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(width, height)

    local savedPos = addon.db.global.mainFramePosition
    if savedPos and savedPos.point then
        frame:SetPoint(savedPos.point, UIParent, savedPos.relativePoint or "CENTER", savedPos.xOfs or 0, savedPos.yOfs or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(T("BG_PRIMARY"))
    frame:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    frame:SetResizeBounds(ns.Constants.GUI.MIN_WIDTH, ns.Constants.GUI.MIN_HEIGHT, ns.Constants.GUI.MAX_WIDTH, ns.Constants.GUI.MAX_HEIGHT)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        addon.db.global.mainFramePosition = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs }
    end)

    local resizeButton = CreateFrame("Button", nil, frame)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -S("XS") / 2, S("XS") / 2)
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeButton:RegisterForDrag("LeftButton")
    resizeButton:SetScript("OnDragStart", function() frame:StartSizing("BOTTOMRIGHT") end)
    resizeButton:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local w, h = frame:GetSize()
        addon.db.global.mainFrameSize = { width = w, height = h }
    end)

    local titleBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBg:SetPoint("TOPLEFT", frame, "TOPLEFT", S("XS"), -S("XS"))
    titleBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -S("XS"), -S("XS"))
    titleBg:SetHeight(20)
    titleBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    titleBg:SetBackdropColor(T("TITLEBAR_BG"))
    titleBg:SetFrameLevel(frame:GetFrameLevel() + 1)

    local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
    local factionTheme = (OneWoW_GUI and OneWoW_GUI.GetSetting and OneWoW_GUI:GetSetting("minimap.theme")) or "horde"
    local brandIconTex
    if factionTheme == "alliance" then
        brandIconTex = "Interface\\AddOns\\OneWoW_Catalog\\Media\\alliance-mini.png"
    elseif factionTheme == "neutral" then
        brandIconTex = "Interface\\AddOns\\OneWoW_Catalog\\Media\\neutral-mini.png"
    else
        brandIconTex = "Interface\\AddOns\\OneWoW_Catalog\\Media\\horde-mini.png"
    end

    local brandIcon = titleBg:CreateTexture(nil, "OVERLAY")
    brandIcon:SetSize(14, 14)
    brandIcon:SetPoint("LEFT", titleBg, "LEFT", S("SM"), 0)
    brandIcon:SetTexture(brandIconTex)

    local brandText = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    brandText:SetPoint("LEFT", brandIcon, "RIGHT", 4, 0)
    brandText:SetText("OneWoW")
    brandText:SetTextColor(T("ACCENT_PRIMARY"))

    local titleText = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
    titleText:SetText(L["ADDON_TITLE_FRAME"])
    titleText:SetTextColor(T("TEXT_PRIMARY"))

    local closeBtn = ns.UI.CreateButton(nil, titleBg, "X", 20, 20)
    closeBtn:SetPoint("RIGHT", titleBg, "RIGHT", -S("XS") / 2, 0)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    tinsert(UISpecialFrames, "OneWoW_CatalogMainFrame")

    local tabButtonContainer = CreateFrame("Frame", nil, frame)
    tabButtonContainer:SetPoint("TOPLEFT", titleBg, "BOTTOMLEFT", S("SM"), -S("SM"))
    tabButtonContainer:SetPoint("TOPRIGHT", titleBg, "BOTTOMRIGHT", -S("SM"), -S("SM"))
    tabButtonContainer:SetHeight(ns.Constants.GUI.TAB_BUTTON_HEIGHT)

    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetPoint("TOPLEFT", tabButtonContainer, "BOTTOMLEFT", 0, -S("SM"))
    tabContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -S("SM"), S("SM"))

    local tabs       = {}
    local tabButtons = {}
    local tabOrder   = {}
    local currentTabName = nil

    local function SelectTab(tabName)
        currentTabName = tabName
        addon.db.global.lastTab = tabName
        for name, tabFrame in pairs(tabs) do
            if name == tabName then tabFrame:Show() else tabFrame:Hide() end
        end
        for name, btn in pairs(tabButtons) do
            if name == tabName then
                btn:SetBackdropColor(T("BG_ACTIVE"))
                btn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                btn.text:SetTextColor(T("TEXT_ACCENT"))
            else
                btn:SetBackdropColor(T("BG_SECONDARY"))
                btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                btn.text:SetTextColor(T("TEXT_PRIMARY"))
            end
        end
    end

    local function UpdateTabLayout()
        local containerWidth = tabButtonContainer:GetWidth()
        if not containerWidth or containerWidth <= 0 then return end
        local numButtons = #tabOrder
        if numButtons == 0 then return end
        local spacing      = S("SM")
        local totalSpacing = spacing * (numButtons - 1)
        local buttonWidth  = math.floor((containerWidth - totalSpacing) / numButtons)
        for i, name in ipairs(tabOrder) do
            local btn = tabButtons[name]
            if btn then
                btn:SetWidth(buttonWidth)
                btn:ClearAllPoints()
                if i == 1 then
                    btn:SetPoint("TOPLEFT", tabButtonContainer, "TOPLEFT", 0, 0)
                else
                    btn:SetPoint("TOPLEFT", tabButtons[tabOrder[i - 1]], "TOPRIGHT", spacing, 0)
                end
            end
        end
    end

    tabButtonContainer:SetScript("OnSizeChanged", function() UpdateTabLayout() end)

    local function CreateTab(name, displayName)
        local btn = CreateFrame("Button", nil, tabButtonContainer, "BackdropTemplate")
        btn:SetHeight(ns.Constants.GUI.TAB_BUTTON_HEIGHT)
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(T("BG_SECONDARY"))
        btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(displayName)
        btn.text:SetTextColor(T("TEXT_PRIMARY"))

        btn:SetScript("OnClick", function() SelectTab(name) end)
        btn:SetScript("OnEnter", function(self)
            if currentTabName ~= name then
                self:SetBackdropColor(T("BG_HOVER"))
                self.text:SetTextColor(T("TEXT_ACCENT"))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if currentTabName ~= name then
                self:SetBackdropColor(T("BG_SECONDARY"))
                self.text:SetTextColor(T("TEXT_PRIMARY"))
            end
        end)

        tabButtons[name] = btn
        table.insert(tabOrder, name)

        local tabFrame = CreateFrame("Frame", nil, tabContainer)
        tabFrame:SetAllPoints(tabContainer)
        tabFrame:Hide()
        tabs[name] = tabFrame

        return tabFrame
    end

    local journalTab = CreateTab("journal", L["TAB_JOURNAL"])
    ns.UI.CreateJournalTab(journalTab)

    local vendorsTab = CreateTab("vendors", L["TAB_VENDORS"])
    ns.UI.CreateVendorsTab(vendorsTab)

    local tradeskillsTab = CreateTab("tradeskills", L["TAB_TRADESKILLS"])
    ns.UI.CreateTradeskillsTab(tradeskillsTab)

    local questsTab = CreateTab("quests", L["TAB_QUESTS"])
    ns.UI.CreateQuestsTab(questsTab)

    local itemsearchTab = CreateTab("itemsearch", L["TAB_ITEMSEARCH"])
    ns.UI.CreateItemSearchTab(itemsearchTab)

    local settingsTab = CreateTab("settings", L["TAB_SETTINGS"])
    ns.UI.CreateSettingsTab(settingsTab)

    C_Timer.After(0.1, function() UpdateTabLayout() end)
    SelectTab(defaultTab or "journal")

    frame.tabs       = tabs
    frame.tabButtons = tabButtons
    frame.SelectTab  = SelectTab

    MainWindow      = frame
    addon.mainFrame = frame
    return frame
end
