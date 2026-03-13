-- OneWoW_QoL Addon File
-- OneWoW_QoL/UI/MainFrame.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

ns.UI = ns.UI or {}

local MainWindow = nil

function ns.UI:Show(tabName)
    if not MainWindow then
        local savedTab = _G.OneWoW_QoL.db.global.lastTab
        self:CreateMainFrame(tabName or savedTab or "features")
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
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db or not addon.db.global then return nil end

    local savedSize = addon.db.global.mainFrameSize
    local width  = (savedSize and savedSize.width)  or ns.Constants.GUI.MAIN_FRAME_WIDTH
    local height = (savedSize and savedSize.height) or ns.Constants.GUI.MAIN_FRAME_HEIGHT

    local frame = CreateFrame("Frame", "OneWoW_QoLMainFrame", UIParent, "BackdropTemplate")
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
    frame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
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
    resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("XS") / 2, OneWoW_GUI:GetSpacing("XS") / 2)
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

    local titleBg = OneWoW_GUI:CreateTitleBar(frame, {
        title = L["ADDON_TITLE_FRAME"],
        height = 20,
        showBrand = true,
        onClose = function() frame:Hide() end,
    })
    titleBg:ClearAllPoints()
    titleBg:SetPoint("TOPLEFT", frame, "TOPLEFT", OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))
    titleBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))
    titleBg:EnableMouse(true)
    titleBg:RegisterForDrag("LeftButton")
    titleBg:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBg:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local w, h = frame:GetSize()
        addon.db.global.mainFrameSize = { width = w, height = h }
    end)

    tinsert(UISpecialFrames, "OneWoW_QoLMainFrame")

    local tabButtonContainer = CreateFrame("Frame", nil, frame)
    tabButtonContainer:SetPoint("TOPLEFT", titleBg, "BOTTOMLEFT", OneWoW_GUI:GetSpacing("SM"), -OneWoW_GUI:GetSpacing("SM"))
    tabButtonContainer:SetPoint("TOPRIGHT", titleBg, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("SM"), -OneWoW_GUI:GetSpacing("SM"))
    tabButtonContainer:SetHeight(ns.Constants.GUI.TAB_BUTTON_HEIGHT)

    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetPoint("TOPLEFT", tabButtonContainer, "BOTTOMLEFT", 0, -OneWoW_GUI:GetSpacing("SM"))
    tabContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("SM"), OneWoW_GUI:GetSpacing("SM"))

    local tabs = {}
    local tabButtons = {}
    local tabOrder = {}
    local currentTabName = nil

    local function SelectTab(tabName)
        currentTabName = tabName
        addon.db.global.lastTab = tabName
        for name, tabFrame in pairs(tabs) do
            if name == tabName then tabFrame:Show() else tabFrame:Hide() end
        end
        for name, btn in pairs(tabButtons) do
            if name == tabName then
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            else
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end
    end

    local function UpdateTabLayout()
        local containerWidth = tabButtonContainer:GetWidth()
        if not containerWidth or containerWidth <= 0 then return end
        local numButtons = #tabOrder
        if numButtons == 0 then return end
        local spacing = OneWoW_GUI:GetSpacing("SM")
        local totalSpacing = spacing * (numButtons - 1)
        local buttonWidth = math.floor((containerWidth - totalSpacing) / numButtons)
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
        local btn = OneWoW_GUI:CreateButton(tabButtonContainer, { text = displayName, width = 100, height = ns.Constants.GUI.TAB_BUTTON_HEIGHT })

        btn:SetScript("OnClick", function() SelectTab(name) end)
        btn:SetScript("OnEnter", function(self)
            if currentTabName ~= name then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if currentTabName ~= name then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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

    local featuresTab = CreateTab("features", L["TAB_FEATURES"])
    ns.UI.CreateFeaturesTab(featuresTab)

    local togglesTab = CreateTab("toggles", L["TAB_TOGGLES"])
    ns.UI.CreateTogglesTab(togglesTab)

    local settingsTab = CreateTab("settings", L["TAB_SETTINGS"])
    ns.UI.CreateSettingsTab(settingsTab)

    C_Timer.After(0.1, function() UpdateTabLayout() end)
    SelectTab(defaultTab or "features")

    frame.tabs = tabs
    frame.tabButtons = tabButtons
    frame.SelectTab = SelectTab

    MainWindow = frame
    return frame
end
