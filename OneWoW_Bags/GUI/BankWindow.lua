local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

local Constants = OneWoW_Bags.Constants
local db = OneWoW_Bags.db
local L = OneWoW_Bags.L
local WH = OneWoW_Bags.WindowHelpers
local BankInfoBar = OneWoW_Bags.BankInfoBar
local BankSet = OneWoW_Bags.BankSet
local BankCategoryManager = OneWoW_Bags.BankCategoryManager
local BankCategoryView = OneWoW_Bags.BankCategoryView
local Settings = OneWoW_Bags.Settings
local BankBar = OneWoW_Bags.BankBar
local BankTabView = OneWoW_Bags.BankTabView
local ListView = OneWoW_Bags.ListView

local ipairs, pairs, pcall = ipairs, pairs, pcall

local C_Timer = C_Timer
local C_PlayerInteractionManager = C_PlayerInteractionManager
local InCombatLockdown = InCombatLockdown

OneWoW_Bags.BankGUI = OneWoW_Bags.BankGUI or {}
local BankGUI = OneWoW_Bags.BankGUI

local MainWindow = nil
local isInitialized = false
local contentScrollFrame = nil
local contentFrame = nil
local titleBar = nil
local contentArea = nil
local needsCleanupAfterCombat = false

function BankGUI:InitMainWindow()
    if isInitialized then return end

    local savedHeight = db.global.bankFramePosition.height
    local windowHeight = savedHeight or Constants.GUI.WINDOW_HEIGHT

    MainWindow = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_BankMainWindow",
        width = Constants.GUI.WINDOW_WIDTH,
        height = windowHeight,
        backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT,
    })

    if not MainWindow then return end

    MainWindow:SetMovable(true)
    MainWindow:SetResizable(true)
    MainWindow:SetResizeBounds(Constants.GUI.WINDOW_WIDTH, 300, Constants.GUI.WINDOW_WIDTH, 1200)
    MainWindow:EnableMouse(true)
    MainWindow:RegisterForDrag("LeftButton")
    MainWindow:SetScript("OnDragStart", MainWindow.StartMoving)
    MainWindow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        OneWoW_GUI:SaveWindowPosition(self, db.global.bankFramePosition)
    end)
    MainWindow:SetClampedToScreen(true)
    MainWindow:SetClampRectInsets(0, 0, 0, 0)
    MainWindow:SetFrameStrata("MEDIUM")
    MainWindow:SetToplevel(true)
    MainWindow:SetScript("OnHide", function()
        if not isInitialized then return end
        BankGUI:CleanupAllViews()
        BankInfoBar:ClearSearch()
        OneWoW_Bags.activeBankExpansionFilter = nil
        OneWoW_GUI:SaveWindowPosition(MainWindow, db.global.bankFramePosition)
        if OneWoW_Bags.bankOpen then
            OneWoW_Bags.bankOpen = false
            if BankFrame and BankFrame.BankPanel then
                BankFrame.BankPanel:Hide()
            end
            BankSet:ReleaseAll()
            C_Timer.After(0, function()
                C_PlayerInteractionManager.ClearInteraction(Enum.PlayerInteractionType.Banker)
            end)
        end
    end)
    MainWindow:Hide()

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
    titleBar = OneWoW_GUI:CreateTitleBar(MainWindow, {
        title = L["BANK_TITLE"] or "Bank",
        height = Constants.GUI.TITLEBAR_HEIGHT,
        showBrand = true,
        factionTheme = factionTheme,
        onClose = function() MainWindow:Hide() end,
    })

    local settingsBtn = OneWoW_GUI:CreateFitTextButton(titleBar, { text = L["SETTINGS"], height = 20, minWidth = 30 })
    settingsBtn:SetPoint("RIGHT", titleBar._closeBtn, "LEFT", -2, 0)
    settingsBtn:SetScript("OnClick", function()
        if Settings and Settings.Toggle then
            Settings:Toggle()
        end
    end)

    contentArea = CreateFrame("Frame", nil, MainWindow)
    contentArea:SetPoint("TOPLEFT", MainWindow, "TOPLEFT", OneWoW_GUI:GetSpacing("XS"), -(OneWoW_GUI:GetSpacing("XS") + Constants.GUI.TITLEBAR_HEIGHT + OneWoW_GUI:GetSpacing("XS")))
    contentArea:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("XS"), OneWoW_GUI:GetSpacing("XS"))
    MainWindow.contentArea = contentArea

    local infoBar = BankInfoBar:Create(contentArea)
    local bankBar = BankBar:Create(contentArea)
    BankBar:SetShown(true)

    local hideScrollBar = db.global.bankHideScrollBar
    local scrollbarOffset = hideScrollBar and 0 or -12

    local scrollName = "OneWoW_BankContentScroll"
    contentScrollFrame = CreateFrame("ScrollFrame", scrollName, contentArea, "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", infoBar, "BOTTOMLEFT", 0, -2)
    contentScrollFrame:SetPoint("BOTTOMRIGHT", bankBar, "TOPRIGHT", scrollbarOffset, 2)

    OneWoW_GUI:StyleScrollBar(contentScrollFrame, { container = contentArea, offset = 0 })
    if hideScrollBar and contentScrollFrame.ScrollBar then
        contentScrollFrame.ScrollBar:Hide()
    end

    contentFrame = CreateFrame("Frame", scrollName .. "Content", contentScrollFrame)
    contentFrame:SetHeight(1)
    contentScrollFrame:SetScrollChild(contentFrame)
    contentScrollFrame:HookScript("OnSizeChanged", function(self, w)
        contentFrame:SetWidth(w)
    end)

    WH:SetupResizeButton(MainWindow, BankGUI, "bankFramePosition")

    WH:RegisterSpecialFrame("OneWoW_BankMainWindow", MainWindow)
    isInitialized = true

    WH:SaveAndRestorePosition(MainWindow, "bankFramePosition")
end

function BankGUI:CleanupAllViews()
    if InCombatLockdown() then
        needsCleanupAfterCombat = true
        return
    end
    needsCleanupAfterCombat = false
    if BankSet.isBuilt then
        local allButtons = BankSet:GetAllButtons()
        for _, button in ipairs(allButtons) do
            button:Hide()
            button:ClearAllPoints()
        end
    end

    BankCategoryManager:ReleaseAllSections()
end

local cleanupEventFrame = CreateFrame("Frame")
cleanupEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
cleanupEventFrame:SetScript("OnEvent", function()
    if needsCleanupAfterCombat and MainWindow and not MainWindow:IsShown() then
        BankGUI:CleanupAllViews()
    end
end)

function BankGUI:UpdateWindowWidth()
    if not MainWindow then return end
    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local scrollbarSpace = db.global.bankHideScrollBar and 0 or 12
    local newWidth = db.global.bankColumns * (iconSize + spacing) - spacing + 4 + scrollbarSpace + (2 * OneWoW_GUI:GetSpacing("XS"))
    MainWindow:SetWidth(newWidth)
    MainWindow:SetResizeBounds(newWidth, 300, newWidth, 1200)
end

function BankGUI:RefreshLayout()
    if not isInitialized or not MainWindow then return end
    if not MainWindow:IsShown() then return end
    if not BankSet.isBuilt then return end

    BankGUI:UpdateWindowWidth()

    if contentFrame and BankSet.bagContainerFrames then
        for _, bagFrame in pairs(BankSet.bagContainerFrames) do
            bagFrame:SetParent(contentFrame)
        end
    end

    BankGUI:CleanupAllViews()

    local allButtons = BankSet:GetAllButtons()
    local visibleButtons = WH:FilterByTab(allButtons, db.global.bankSelectedTab)
    local searchText = BankInfoBar:GetSearchText()
    local filteredButtons = WH:FilterBySearch(visibleButtons, searchText)
    filteredButtons = WH:FilterByExpansion(filteredButtons, OneWoW_Bags.activeBankExpansionFilter)

    local viewMode = db.global.bankViewMode
    local cols, iconSize, spacing, contentWidth = WH:GetLayoutMetrics("bankColumns", 14)

    local layoutHeight = 100

    if viewMode == "category" then
        layoutHeight = BankCategoryView:Layout(contentFrame, contentWidth, filteredButtons)
    elseif viewMode == "tab" then
        layoutHeight = BankTabView:Layout(contentFrame, contentWidth, filteredButtons)
    else
        layoutHeight = ListView:Layout(contentFrame, filteredButtons, contentWidth)
    end

    contentFrame:SetHeight(layoutHeight)

    local freeSlots = BankSet:GetFreeSlotCount()
    local totalSlots = BankSet:GetSlotCount()
    BankBar:UpdateFreeSlots(freeSlots, totalSlots)
end

function BankGUI:OnSearchChanged(text)
    self:RefreshLayout()
end

function BankGUI:OnBankTypeChanged()
    db.global.bankSelectedTab = nil

    local showWarband = db.global.bankShowWarband

    local newBankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
    if BankFrame and BankFrame.BankPanel then
        BankFrame.BankPanel:Show()
        BankFrame.BankPanel:SetBankType(newBankType)
    end

    BankSet:ReleaseAll()
    BankSet:Build()

    BankBar:BuildTabButtons()
    BankBar:UpdateModeButtons()

    C_Timer.After(0, function()
        if contentScrollFrame and contentFrame then
            local w = contentScrollFrame:GetWidth()
            if w and w > 10 then
                contentFrame:SetWidth(w)
            end
        end
        BankGUI:RefreshLayout()
    end)
end

function BankGUI:Show()
    if not isInitialized then
        local ok, initErr = pcall(function() BankGUI:InitMainWindow() end)
        if not ok then
            print("|cffff4444OneWoW_Bags:|r BankWindow init failed:", initErr)
            return
        end
    end

    if not MainWindow then return end

    MainWindow:Show()

    if not BankSet.isBuilt then
        BankSet:Build()
    end

    OneWoW_Bags.BankBar:UpdateModeButtons()
    OneWoW_Bags.BankBar:BuildTabButtons()
    OneWoW_Bags.BankBar:UpdateGold()

    C_Timer.After(0, function()
        if contentScrollFrame and contentFrame then
            local w = contentScrollFrame:GetWidth()
            if w and w > 10 then
                contentFrame:SetWidth(w)
            end
        end
        BankGUI:RefreshLayout()
    end)

    C_Timer.After(0.5, function()
        if MainWindow and MainWindow:IsShown() then
            BankGUI:RefreshLayout()
        end
    end)
end

function BankGUI:Hide()
    if MainWindow then
        MainWindow:Hide()
    end
end

function BankGUI:Toggle()
    if MainWindow and MainWindow:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function BankGUI:IsShown()
    return MainWindow and MainWindow:IsShown()
end

function BankGUI:FullReset()
    BankSet:ReleaseAll()
    BankInfoBar:Reset()
    BankBar:Reset()

    if MainWindow then
        MainWindow:Hide()
        MainWindow = nil
    end

    titleBar = nil
    contentArea = nil
    contentScrollFrame = nil
    contentFrame = nil
    isInitialized = false
end

function BankGUI:ApplyTheme()
    if not MainWindow then return end

    WH:ApplyBaseTheme(MainWindow, titleBar, BankInfoBar, BankBar)
    BankInfoBar:UpdateViewButtons()
    self:RefreshLayout()
end

function BankGUI:GetMainWindow()
    return MainWindow
end
