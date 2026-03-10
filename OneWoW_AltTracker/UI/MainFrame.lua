local addonName, ns = ...
local OneWoWAltTracker = OneWoW_AltTracker
local L = ns.L
local T = ns.T
local S = ns.S

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

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
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
    resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -S("XS")/2, S("XS")/2)
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
        brandIconTex = "Interface\\AddOns\\OneWoW_AltTracker\\Media\\alliance-mini.png"
    elseif factionTheme == "neutral" then
        brandIconTex = "Interface\\AddOns\\OneWoW_AltTracker\\Media\\neutral-mini.png"
    else
        brandIconTex = "Interface\\AddOns\\OneWoW_AltTracker\\Media\\horde-mini.png"
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

    local closeButton = ns.UI.CreateButton(nil, titleBg, "X", 20, 20)
    closeButton:SetPoint("RIGHT", titleBg, "RIGHT", -S("XS") / 2, 0)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    tinsert(UISpecialFrames, "OneWoWAltTrackerMainFrame")

    local tabButtonContainer = CreateFrame("Frame", nil, frame)
    tabButtonContainer:SetPoint("TOPLEFT", titleBg, "BOTTOMLEFT", S("SM"), -S("SM"))
    tabButtonContainer:SetPoint("TOPRIGHT", titleBg, "BOTTOMRIGHT", -S("SM"), -S("SM"))
    tabButtonContainer:SetHeight(ns.Constants.GUI.TAB_BUTTON_HEIGHT)

    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetPoint("TOPLEFT", tabButtonContainer, "BOTTOMLEFT", 0, -S("SM"))
    tabContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -S("SM"), S("SM"))

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
                button:SetBackdropColor(T("BG_ACTIVE"))
                button:SetBackdropBorderColor(T("BORDER_ACCENT"))
            else
                button:SetBackdropColor(T("BG_SECONDARY"))
                button:SetBackdropBorderColor(T("BORDER_SUBTLE"))
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

        local spacing = S("SM")
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
        local button = CreateFrame("Button", nil, tabButtonContainer, "BackdropTemplate")
        button:SetHeight(28)

        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        button:SetBackdropColor(T("BG_SECONDARY"))
        button:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER", button, "CENTER")
        text:SetText(displayName)
        text:SetTextColor(T("TEXT_PRIMARY"))

        button:SetScript("OnClick", function() SelectTab(name) end)
        button:SetScript("OnEnter", function(self)
            if tabs[name] and not tabs[name]:IsShown() then
                self:SetBackdropColor(T("BG_HOVER"))
            end
        end)
        button:SetScript("OnLeave", function(self)
            if tabs[name] and not tabs[name]:IsShown() then
                self:SetBackdropColor(T("BG_SECONDARY"))
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
