-- OneWoW_Notes Addon File
-- OneWoW_Notes/UI/MainFrame.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

ns.UI = ns.UI or {}

local MainWindow = nil

function ns.UI:Show(tabName)
    if not MainWindow then
        local savedTab = _G.OneWoW_Notes.db.global.lastTab
        self:CreateMainFrame(tabName or savedTab or "notes")
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
    local addon = _G.OneWoW_Notes
    if not addon or not addon.db or not addon.db.global then return nil end

    local savedSize = addon.db.global.mainFrameSize
    local width  = (savedSize and savedSize.width)  or ns.Constants.GUI.MAIN_FRAME_WIDTH
    local height = (savedSize and savedSize.height) or ns.Constants.GUI.MAIN_FRAME_HEIGHT

    local frame = CreateFrame("Frame", "OneWoW_NotesMainFrame", UIParent, "BackdropTemplate")
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

    local titleBg = OneWoW_GUI:CreateTitleBar(frame, L["ADDON_TITLE_FRAME"], {
        showBrand = true,
        onClose = function() frame:Hide() end,
    })

    tinsert(UISpecialFrames, "OneWoW_NotesMainFrame")

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
        if ns.UI.notesHelpPanel and ns.UI.notesHelpPanel:IsShown() then
            ns.UI.notesHelpPanel:Hide()
        end
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
        local btn = CreateFrame("Button", nil, tabButtonContainer, "BackdropTemplate")
        btn:SetHeight(ns.Constants.GUI.TAB_BUTTON_HEIGHT)
        btn:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(displayName)
        btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

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

    local notesTab = CreateTab("notes", L["TAB_NOTES"])
    ns.UI.CreateNotesTab(notesTab)

    local playersTab = CreateTab("players", L["TAB_PLAYERS"])
    ns.UI.CreatePlayersTab(playersTab)

    local npcsTab = CreateTab("npcs", L["TAB_NPCS"])
    ns.UI.CreateNPCsTab(npcsTab)

    local zonesTab = CreateTab("zones", L["TAB_ZONES"])
    ns.UI.CreateZonesTab(zonesTab)

    local itemsTab = CreateTab("items", L["TAB_ITEMS"])
    ns.UI.CreateItemsTab(itemsTab)

    local guidesTab = CreateTab("guides", L["TAB_GUIDES"])
    ns.UI.CreateGuidesTab(guidesTab)

    local routinesTab = CreateTab("routines", L["TAB_ROUTINES"])
    ns.UI.CreateRoutinesTab(routinesTab)

    local settingsTab = CreateTab("settings", L["TAB_SETTINGS"])
    ns.UI.CreateSettingsTab(settingsTab)

    C_Timer.After(0.1, function() UpdateTabLayout() end)
    SelectTab(defaultTab or "notes")

    frame.tabs = tabs
    frame.tabButtons = tabButtons
    frame.SelectTab = SelectTab

    MainWindow = frame
    addon.mainFrame = frame
    return frame
end
