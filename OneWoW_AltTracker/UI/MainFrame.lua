local addonName, ns = ...
local OneWoWAltTracker = OneWoW_AltTracker
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.UI = ns.UI or {}

local MainWindow = nil
local isInitialized = false

function ns.UI:Show(tabName)
    if not MainWindow then
        local savedTab = OneWoWAltTracker.db.global.lastTab
        local tabToSelect = tabName or savedTab or "summary"
        self:CreateMainFrame(tabToSelect)
    else
        MainWindow:Show()
        if tabName and type(tabName) == "string" and MainWindow.SelectTab then
            MainWindow:SelectTab(tabName)
        end
    end
end

function ns.UI:Hide()
    if MainWindow then
        MainWindow:Hide()
    end
end

function ns.UI:Toggle()
    if MainWindow and MainWindow:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function ns.UI:Reset()
    if MainWindow then
        MainWindow:Hide()
    end
    isInitialized = false
    MainWindow = nil
end

function ns.UI:CreateMainFrame(defaultTab)
    if not OneWoWAltTracker or not OneWoWAltTracker.db or not OneWoWAltTracker.db.global then
        print("|cFFFFD100OneWoW - AltTracker:|r Database not ready. Please wait a moment and try again.")
        return nil
    end

    if not L then
        print("|cFFFFD100OneWoW - AltTracker:|r Localization not ready. Please wait a moment and try again.")
        return nil
    end

    local frame = CreateFrame("Frame", "OneWoWAltTrackerMainFrame", UIParent, "BackdropTemplate")

    local savedSize = OneWoWAltTracker.db.global.mainFrameSize
    local width = (savedSize and savedSize.width) or ns.Constants.GUI.MAIN_FRAME_WIDTH
    local height = (savedSize and savedSize.height) or ns.Constants.GUI.MAIN_FRAME_HEIGHT

    frame:SetSize(width, height)

    local savedPos = OneWoWAltTracker.db.global.mainFramePosition
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

    frame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    frame:SetResizeBounds(ns.Constants.GUI.MIN_WIDTH, ns.Constants.GUI.MIN_HEIGHT, ns.Constants.GUI.MAX_WIDTH, ns.Constants.GUI.MAX_HEIGHT)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
        OneWoWAltTracker.db.global.mainFramePosition = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs
        }
    end)

    local resizeButton = CreateFrame("Button", nil, frame)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("XS")/2, OneWoW_GUI:GetSpacing("XS")/2)
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeButton:RegisterForDrag("LeftButton")
    resizeButton:SetScript("OnDragStart", function(self)
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeButton:SetScript("OnDragStop", function(self)
        frame:StopMovingOrSizing()
        local width, height = frame:GetSize()
        OneWoWAltTracker.db.global.mainFrameSize = {width = width, height = height}
    end)

    local titleBg = OneWoW_GUI:CreateTitleBar(frame, L["ADDON_TITLE_FRAME"], {
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
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        OneWoWAltTracker.db.global.mainFramePosition = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs
        }
    end)

    tinsert(UISpecialFrames, "OneWoWAltTrackerMainFrame")

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

        if OneWoWAltTracker and OneWoWAltTracker.db and OneWoWAltTracker.db.global then
            OneWoWAltTracker.db.global.lastTab = tabName
        end

        for name, tabFrame in pairs(tabs) do
            if name == tabName then
                tabFrame:Show()
            else
                tabFrame:Hide()
            end
        end

        for name, button in pairs(tabButtons) do
            if name == tabName then
                button:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            else
                button:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end
        end

        if tabName == "professions" and ns.UI.RefreshProfessionsTab and tabs.professions then
            C_Timer.After(0.1, function()
                ns.UI.RefreshProfessionsTab(tabs.professions)
            end)
        end
    end

    local function UpdateTabLayout()
        local containerWidth = tabButtonContainer:GetWidth()
        if not containerWidth or containerWidth <= 0 then return end

        local numButtons = #tabOrder
        if numButtons == 0 then return end

        local spacing = OneWoW_GUI:GetSpacing("SM")
        local totalSpacing = spacing * (numButtons - 1)
        local availableWidth = containerWidth - totalSpacing
        local buttonWidth = math.floor(availableWidth / numButtons)

        for i, name in ipairs(tabOrder) do
            local button = tabButtons[name]
            if button then
                button:SetWidth(buttonWidth)
                button:ClearAllPoints()
                if i == 1 then
                    button:SetPoint("TOPLEFT", tabButtonContainer, "TOPLEFT", 0, 0)
                else
                    local prevButton = tabButtons[tabOrder[i-1]]
                    button:SetPoint("TOPLEFT", prevButton, "TOPRIGHT", spacing, 0)
                end
            end
        end
    end

    tabButtonContainer:SetScript("OnSizeChanged", function(self, width, height)
        UpdateTabLayout()
    end)

    local function CreateTab(name, displayName)
        local GUI = LibStub("OneWoW_GUI-1.0", true)
        local button = GUI:CreateButton(nil, tabButtonContainer, displayName, 100, 28)
        button:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        button.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        button:SetScript("OnClick", function() SelectTab(name) end)
        button:SetScript("OnEnter", function(self)
            if tabs[name] and not tabs[name]:IsShown() then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            end
        end)
        button:SetScript("OnLeave", function(self)
            if tabs[name] and not tabs[name]:IsShown() then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end)

        tabButtons[name] = button
        table.insert(tabOrder, name)

        local tabFrame = CreateFrame("Frame", nil, tabContainer)
        tabFrame:SetAllPoints(tabContainer)
        tabFrame:Hide()
        tabs[name] = tabFrame

        return tabFrame
    end

    local summaryTab = CreateTab("summary", L["SUBTAB_SUMMARY"] or "Summary")
    ns.UI.CreateSummaryTab(summaryTab)

    local progressTab = CreateTab("progress", L["SUBTAB_PROGRESS"] or "Progress")
    ns.UI.CreateProgressTab(progressTab)

    local bankTab = CreateTab("bank", L["SUBTAB_BANK"] or "Bank")
    ns.UI.CreateBankTab(bankTab)

    local equipmentTab = CreateTab("equipment", L["SUBTAB_EQUIPMENT"] or "Equipment")
    ns.UI.CreateEquipmentTab(equipmentTab)

    local professionsTab = CreateTab("professions", L["SUBTAB_PROFESSIONS"] or "Professions")
    ns.UI.CreateProfessionsTab(professionsTab)

    local auctionsTab = CreateTab("auctions", L["SUBTAB_AUCTIONS"] or "Auctions")
    ns.UI.CreateAuctionsTab(auctionsTab)

    local financialsTab = CreateTab("financials", L["SUBTAB_FINANCIALS"] or "Financials")
    ns.UI.CreateFinancialsTab(financialsTab)
    financialsTab:SetScript("OnShow", function()
        if ns.UI.RefreshFinancialsTab then
            ns.UI.RefreshFinancialsTab(financialsTab)
        end
    end)

    local itemsTab = CreateTab("items", L["SUBTAB_ITEMS"] or "Items")
    ns.UI.CreateItemsTab(itemsTab)
    itemsTab:SetScript("OnShow", function()
        if ns.UI.RefreshItemsTab then
            ns.UI.RefreshItemsTab(itemsTab)
        end
    end)

    local profilesTab = CreateTab("actionbars", "Action Bars")
    ns.UI.CreateActionBarsTab(profilesTab)

    local lockoutsTab = CreateTab("lockouts", L["SUBTAB_LOCKOUTS"] or "Lockouts")
    ns.UI.CreateLockoutsTab(lockoutsTab)

    local settingsTab = CreateTab("settings", L["TAB_SETTINGS"] or "Settings")
    ns.UI.CreateSettingsTab(settingsTab)

    C_Timer.After(0.1, function() UpdateTabLayout() end)

    SelectTab(defaultTab or "summary")

    frame.tabs = tabs
    frame.tabButtons = tabButtons
    frame.SelectTab = SelectTab

    MainWindow = frame
    isInitialized = true

    return frame
end
