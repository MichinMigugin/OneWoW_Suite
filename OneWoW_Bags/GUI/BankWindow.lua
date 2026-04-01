local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_Bags.BankGUI = OneWoW_Bags.BankGUI or {}
local BankGUI = OneWoW_Bags.BankGUI
local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local WH = OneWoW_Bags.WindowHelpers

local MainWindow = nil
local isInitialized = false
local contentScrollFrame = nil
local contentFrame = nil
local titleBar = nil
local contentArea = nil
local needsCleanupAfterCombat = false

function BankGUI:InitMainWindow()
    if isInitialized then return end
    if not Constants or not Constants.GUI then return end

    local C = Constants.GUI
    local db = OneWoW_Bags.db
    local savedHeight = db and db.global and db.global.bankFramePosition and db.global.bankFramePosition.height
    local windowHeight = savedHeight or C.WINDOW_HEIGHT

    MainWindow = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_BankMainWindow",
        width = C.WINDOW_WIDTH,
        height = windowHeight,
        backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT,
    })

    if not MainWindow then return end

    MainWindow:SetMovable(true)
    MainWindow:SetResizable(true)
    MainWindow:SetResizeBounds(C.WINDOW_WIDTH, 300, C.WINDOW_WIDTH, 1200)
    MainWindow:EnableMouse(true)
    MainWindow:RegisterForDrag("LeftButton")
    MainWindow:SetScript("OnDragStart", MainWindow.StartMoving)
    MainWindow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local d = OneWoW_Bags.db
        if d and d.global then
            d.global.bankFramePosition = d.global.bankFramePosition or {}
            OneWoW_GUI:SaveWindowPosition(self, d.global.bankFramePosition)
        end
    end)
    MainWindow:SetClampedToScreen(true)
    MainWindow:SetClampRectInsets(0, 0, 0, 0)
    MainWindow:SetFrameStrata("MEDIUM")
    MainWindow:SetToplevel(true)
    MainWindow:SetScript("OnHide", function()
        if not isInitialized then return end
        BankGUI:CleanupAllViews()
        if OneWoW_Bags.BankInfoBar and OneWoW_Bags.BankInfoBar.ClearSearch then
            OneWoW_Bags.BankInfoBar:ClearSearch()
        end
        OneWoW_Bags.activeBankExpansionFilter = nil
        local d = OneWoW_Bags.db
        if d and d.global then
            d.global.bankFramePosition = d.global.bankFramePosition or {}
            OneWoW_GUI:SaveWindowPosition(MainWindow, d.global.bankFramePosition)
        end
        if OneWoW_Bags.bankOpen then
            OneWoW_Bags.bankOpen = false
            if BankFrame and BankFrame.BankPanel then
                BankFrame.BankPanel:Hide()
            end
            if OneWoW_Bags.BankSet then
                OneWoW_Bags.BankSet:ReleaseAll()
            end
            C_Timer.After(0, function()
                C_PlayerInteractionManager.ClearInteraction(Enum.PlayerInteractionType.Banker)
            end)
        end
    end)
    MainWindow:Hide()

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
    titleBar = OneWoW_GUI:CreateTitleBar(MainWindow, {
        title = L["BANK_TITLE"] or "Bank",
        height = C.TITLEBAR_HEIGHT,
        showBrand = true,
        factionTheme = factionTheme,
        onClose = function() MainWindow:Hide() end,
    })

    local settingsBtn = OneWoW_GUI:CreateFitTextButton(titleBar, { text = L["SETTINGS"], height = 20, minWidth = 30 })
    settingsBtn:SetPoint("RIGHT", titleBar._closeBtn, "LEFT", -2, 0)
    settingsBtn:SetScript("OnClick", function()
        if OneWoW_Bags.Settings and OneWoW_Bags.Settings.Toggle then
            OneWoW_Bags.Settings:Toggle()
        end
    end)

    contentArea = CreateFrame("Frame", nil, MainWindow)
    contentArea:SetPoint("TOPLEFT", MainWindow, "TOPLEFT", OneWoW_GUI:GetSpacing("XS"), -(OneWoW_GUI:GetSpacing("XS") + C.TITLEBAR_HEIGHT + OneWoW_GUI:GetSpacing("XS")))
    contentArea:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("XS"), OneWoW_GUI:GetSpacing("XS"))
    MainWindow.contentArea = contentArea

    local infoBar = OneWoW_Bags.BankInfoBar:Create(contentArea)
    local bankBar = OneWoW_Bags.BankBar:Create(contentArea)
    OneWoW_Bags.BankBar:SetShown(true)

    local hideScrollBar = OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.bankHideScrollBar
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
    local BankSet = OneWoW_Bags.BankSet
    if BankSet and BankSet.isBuilt then
        local allButtons = BankSet:GetAllButtons()
        for _, button in ipairs(allButtons) do
            button:Hide()
            button:ClearAllPoints()
        end
    end

    if OneWoW_Bags.BankCategoryManager then
        OneWoW_Bags.BankCategoryManager:ReleaseAllSections()
    end
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
    local db = OneWoW_Bags.db
    if not db or not db.global then return end
    local cols = db.global.bankColumns or 14
    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local scrollbarSpace = db.global.bankHideScrollBar and 0 or 12
    local newWidth = cols * (iconSize + spacing) - spacing + 4 + scrollbarSpace + (2 * OneWoW_GUI:GetSpacing("XS"))
    MainWindow:SetWidth(newWidth)
    MainWindow:SetResizeBounds(newWidth, 300, newWidth, 1200)
end

function BankGUI:RefreshLayout()
    if not isInitialized or not MainWindow then return end
    if not MainWindow:IsShown() then return end

    local BankSet = OneWoW_Bags.BankSet
    if not BankSet or not BankSet.isBuilt then return end

    BankGUI:UpdateWindowWidth()

    if contentFrame and BankSet.bagContainerFrames then
        for _, bagFrame in pairs(BankSet.bagContainerFrames) do
            bagFrame:SetParent(contentFrame)
        end
    end

    BankGUI:CleanupAllViews()

    local db = OneWoW_Bags.db

    local allButtons = BankSet:GetAllButtons()
    local visibleButtons = WH:FilterByTab(allButtons, db and db.global.bankSelectedTab)
    local searchText = OneWoW_Bags.BankInfoBar:GetSearchText()
    local filteredButtons = WH:FilterBySearch(visibleButtons, searchText)
    filteredButtons = WH:FilterByExpansion(filteredButtons, OneWoW_Bags.activeBankExpansionFilter)

    local viewMode = db and db.global and db.global.bankViewMode or "list"
    local cols, iconSize, spacing, contentWidth = WH:GetLayoutMetrics("bankColumns", 14)

    local layoutHeight = 100

    if viewMode == "category" then
        layoutHeight = OneWoW_Bags.BankCategoryView:Layout(contentFrame, contentWidth, filteredButtons)
    elseif viewMode == "tab" then
        layoutHeight = OneWoW_Bags.BankTabView:Layout(contentFrame, contentWidth, filteredButtons)
    else
        layoutHeight = OneWoW_Bags.ListView:Layout(contentFrame, filteredButtons, contentWidth)
    end

    contentFrame:SetHeight(layoutHeight)

    local freeSlots = BankSet:GetFreeSlotCount()
    local totalSlots = BankSet:GetSlotCount()
    OneWoW_Bags.BankBar:UpdateFreeSlots(freeSlots, totalSlots)
end

function BankGUI:OnSearchChanged(text)
    self:RefreshLayout()
end

function BankGUI:OnBankTypeChanged()
    local db = OneWoW_Bags.db
    db.global.bankSelectedTab = nil

    local showWarband = db.global.bankShowWarband

    local newBankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
    if BankFrame and BankFrame.BankPanel then
        BankFrame.BankPanel:Show()
        BankFrame.BankPanel:SetBankType(newBankType)
    end

    local BankSet = OneWoW_Bags.BankSet
    if BankSet then
        BankSet:ReleaseAll()
        BankSet:Build()
    end

    if OneWoW_Bags.BankBar then
        OneWoW_Bags.BankBar:BuildTabButtons()
        OneWoW_Bags.BankBar:UpdateModeButtons()
    end

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

    local BankSet = OneWoW_Bags.BankSet
    if BankSet and not BankSet.isBuilt then
        BankSet:Build()
    end

    if OneWoW_Bags.BankBar then
        OneWoW_Bags.BankBar:UpdateModeButtons()
        OneWoW_Bags.BankBar:BuildTabButtons()
        OneWoW_Bags.BankBar:UpdateGold()
    end

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
    if OneWoW_Bags.BankSet then
        OneWoW_Bags.BankSet:ReleaseAll()
    end

    if OneWoW_Bags.BankInfoBar and OneWoW_Bags.BankInfoBar.Reset then
        OneWoW_Bags.BankInfoBar:Reset()
    end

    if OneWoW_Bags.BankBar and OneWoW_Bags.BankBar.Reset then
        OneWoW_Bags.BankBar:Reset()
    end

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

    WH:ApplyBaseTheme(MainWindow, titleBar, OneWoW_Bags.BankInfoBar, OneWoW_Bags.BankBar)

    OneWoW_Bags.BankInfoBar:UpdateViewButtons()

    self:RefreshLayout()
end

function BankGUI:GetMainWindow()
    return MainWindow
end
