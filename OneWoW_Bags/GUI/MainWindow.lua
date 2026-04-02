local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

OneWoW_Bags.GUI = OneWoW_Bags.GUI or {}
local GUI = OneWoW_Bags.GUI
local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local WH = OneWoW_Bags.WindowHelpers

local MainWindow = nil
local isInitialized = false
local contentScrollFrame = nil
local contentFrame = nil
local titleBar = nil
local contentArea = nil
local settingsBtn = nil
local needsCleanupAfterCombat = false

function GUI:InitMainWindow()
    if isInitialized then return end
    if not Constants or not Constants.GUI then return end

    local C = Constants.GUI
    local db = OneWoW_Bags.db
    local savedHeight = db.global.mainFramePosition.height
    local windowHeight = savedHeight or C.WINDOW_HEIGHT

    MainWindow = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_BagsMainWindow",
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
        local pos = DB:Ensure(OneWoW_Bags.db, "global", "mainFramePosition")
        OneWoW_GUI:SaveWindowPosition(self, pos)
    end)
    MainWindow:SetClampedToScreen(true)
    MainWindow:SetClampRectInsets(0, 0, 0, 0)
    MainWindow:SetFrameStrata("MEDIUM")
    MainWindow:SetToplevel(true)
    MainWindow:SetScript("OnHide", function()
        if not isInitialized then return end
        GUI:CleanupAllViews()
        if OneWoW_Bags.InfoBar and OneWoW_Bags.InfoBar.ClearSearch then
            OneWoW_Bags.InfoBar:ClearSearch()
        end
        OneWoW_Bags.activeExpansionFilter = nil
        local pos = DB:Ensure(OneWoW_Bags.db, "global", "mainFramePosition")
        OneWoW_GUI:SaveWindowPosition(MainWindow, pos)
    end)
    MainWindow:Hide()

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
    titleBar = OneWoW_GUI:CreateTitleBar(MainWindow, {
        title = L["ADDON_TITLE"],
        height = C.TITLEBAR_HEIGHT,
        showBrand = true,
        factionTheme = factionTheme,
        onClose = function() MainWindow:Hide() end,
    })

    settingsBtn = OneWoW_GUI:CreateFitTextButton(titleBar, { text = L["SETTINGS"], height = 20, minWidth = 30 })
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

    local infoBar = OneWoW_Bags.InfoBar:Create(contentArea)

    local bagsBar = OneWoW_Bags.BagsBar:Create(contentArea)
    local showBagsBar = OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.showBagsBar
    if showBagsBar == nil then showBagsBar = true end
    OneWoW_Bags.BagsBar:SetShown(showBagsBar)

    local hideScrollBar = OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.hideScrollBar
    local scrollbarOffset = hideScrollBar and 0 or -12

    local scrollName = "OneWoW_BagsContentScroll"
    contentScrollFrame = CreateFrame("ScrollFrame", scrollName, contentArea, "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", infoBar, "BOTTOMLEFT", 0, -2)
    if showBagsBar then
        contentScrollFrame:SetPoint("BOTTOMRIGHT", bagsBar, "TOPRIGHT", scrollbarOffset, 2)
    else
        contentScrollFrame:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", scrollbarOffset, 0)
    end

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

    WH:SetupResizeButton(MainWindow, GUI, "mainFramePosition")

    WH:RegisterSpecialFrame("OneWoW_BagsMainWindow", MainWindow)
    isInitialized = true

    WH:SaveAndRestorePosition(MainWindow, "mainFramePosition")
end

function GUI:CleanupAllViews()
    if InCombatLockdown() then
        needsCleanupAfterCombat = true
        return
    end
    needsCleanupAfterCombat = false
    local BagSet = OneWoW_Bags.BagSet
    if BagSet and BagSet.isBuilt then
        local allButtons = BagSet:GetAllButtons()
        for _, button in ipairs(allButtons) do
            button:Hide()
            button:ClearAllPoints()
        end
    end

    if OneWoW_Bags.CategoryManager then
        OneWoW_Bags.CategoryManager:ReleaseAllSections()
    end
end

local cleanupEventFrame = CreateFrame("Frame")
cleanupEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
cleanupEventFrame:SetScript("OnEvent", function()
    if needsCleanupAfterCombat and MainWindow and not MainWindow:IsShown() then
        GUI:CleanupAllViews()
    end
end)

function GUI:UpdateWindowWidth()
    if not MainWindow then return end
    local db = OneWoW_Bags.db
    local cols = db.global.bagColumns or 15
    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local scrollbarSpace = db.global.hideScrollBar and 0 or 12
    local newWidth = cols * (iconSize + spacing) - spacing + 4 + scrollbarSpace + (2 * OneWoW_GUI:GetSpacing("XS"))
    MainWindow:SetWidth(newWidth)
    MainWindow:SetResizeBounds(newWidth, 300, newWidth, 1200)
end

function GUI:RefreshLayout()
    if not isInitialized or not MainWindow then return end
    if not MainWindow:IsShown() then return end

    local BagSet = OneWoW_Bags.BagSet
    if not BagSet or not BagSet.isBuilt then return end

    GUI:UpdateWindowWidth()

    if OneWoW_Bags.InfoBar and OneWoW_Bags.InfoBar.UpdateVisibility then
        OneWoW_Bags.InfoBar:UpdateVisibility()
    end
    if OneWoW_Bags.BagsBar and OneWoW_Bags.BagsBar.UpdateRowVisibility then
        OneWoW_Bags.BagsBar:UpdateRowVisibility()
    end

    local bagsBarFrame = OneWoW_Bags.BagsBar:GetFrame()
    local infoBarFrame = OneWoW_Bags.InfoBar:GetFrame()
    if contentScrollFrame then
        local hideScrollBar = OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.hideScrollBar
        local scrollbarOffset = hideScrollBar and 0 or -12
        if contentScrollFrame.ScrollBar then
            if hideScrollBar then
                contentScrollFrame.ScrollBar:Hide()
                contentScrollFrame.ScrollBar:SetAlpha(0)
            else
                contentScrollFrame.ScrollBar:Show()
                contentScrollFrame.ScrollBar:SetAlpha(1)
            end
        end
        contentScrollFrame:ClearAllPoints()
        if infoBarFrame and infoBarFrame:IsShown() then
            contentScrollFrame:SetPoint("TOPLEFT", infoBarFrame, "BOTTOMLEFT", 0, -2)
        else
            contentScrollFrame:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 0, 0)
        end
        local showAnyBar = bagsBarFrame and bagsBarFrame:IsShown()
        if showAnyBar then
            contentScrollFrame:SetPoint("BOTTOMRIGHT", bagsBarFrame, "TOPRIGHT", scrollbarOffset, 2)
        else
            contentScrollFrame:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", scrollbarOffset, 0)
        end
    end

    if contentFrame and BagSet.bagContainerFrames then
        for _, bagFrame in pairs(BagSet.bagContainerFrames) do
            bagFrame:SetParent(contentFrame)
        end
    end

    GUI:CleanupAllViews()

    local allButtons = BagSet:GetAllButtons()
    local searchText = OneWoW_Bags.InfoBar:GetSearchText()
    local filteredButtons = WH:FilterBySearch(allButtons, searchText)
    filteredButtons = WH:FilterByExpansion(filteredButtons, OneWoW_Bags.activeExpansionFilter)

    local viewMode = OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.viewMode or "list"
    local cols, iconSize, spacing, contentWidth = WH:GetLayoutMetrics("bagColumns", 15)

    local layoutHeight = 100

    if viewMode == "list" then
        layoutHeight = OneWoW_Bags.ListView:Layout(contentFrame, filteredButtons, contentWidth)
    elseif viewMode == "category" then
        layoutHeight = OneWoW_Bags.CategoryView:Layout(contentFrame, contentWidth, filteredButtons, "backpack")
    elseif viewMode == "bag" then
        layoutHeight = OneWoW_Bags.BagView:Layout(contentFrame, contentWidth, filteredButtons)
    end

    contentFrame:SetHeight(layoutHeight)

    local freeSlots = BagSet:GetFreeSlotCount()
    local totalSlots = BagSet:GetSlotCount()
    OneWoW_Bags.BagsBar:UpdateFreeSlots(freeSlots, totalSlots)
end

function GUI:OnSearchChanged(text)
    self:RefreshLayout()
end

function GUI:Show()
    if not isInitialized then
        local ok, initErr = pcall(function() GUI:InitMainWindow() end)
        if not ok then
            print("|cffff4444OneWoW_Bags:|r MainWindow init failed:", initErr)
            return
        end
    end

    if not MainWindow then return end

    MainWindow:Show()

    local BagSet = OneWoW_Bags.BagSet
    if BagSet and not BagSet.isBuilt then
        BagSet:Build()
    end

    C_Timer.After(0, function()
        if contentScrollFrame and contentFrame then
            local w = contentScrollFrame:GetWidth()
            if w and w > 10 then
                contentFrame:SetWidth(w)
            end
        end
        GUI:RefreshLayout()
    end)
end

function GUI:Hide()
    if MainWindow then
        MainWindow:Hide()
    end
    if OneWoW_Bags.Settings then
        OneWoW_Bags.Settings:Hide()
    end
end

function GUI:Toggle()
    if MainWindow and MainWindow:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function GUI:IsShown()
    return MainWindow and MainWindow:IsShown()
end

function GUI:FullReset()
    if OneWoW_Bags.BagSet then
        OneWoW_Bags.BagSet:ReleaseAll()
    end

    if OneWoW_Bags.CategoryManager and OneWoW_Bags.CategoryManager.ReleaseAllSections then
        OneWoW_Bags.CategoryManager:ReleaseAllSections()
    end

    if OneWoW_Bags.Settings and OneWoW_Bags.Settings.Reset then
        OneWoW_Bags.Settings:Reset()
    end

    if OneWoW_Bags.InfoBar and OneWoW_Bags.InfoBar.Reset then
        OneWoW_Bags.InfoBar:Reset()
    end

    if OneWoW_Bags.BagsBar and OneWoW_Bags.BagsBar.Reset then
        OneWoW_Bags.BagsBar:Reset()
    end

    if MainWindow then
        MainWindow:Hide()
        MainWindow = nil
    end

    titleBar = nil
    contentArea = nil
    contentScrollFrame = nil
    contentFrame = nil
    settingsBtn = nil
    isInitialized = false
end

function GUI:ApplyTheme()
    if not MainWindow then return end

    WH:ApplyBaseTheme(MainWindow, titleBar, OneWoW_Bags.InfoBar, OneWoW_Bags.BagsBar)

    if MainWindow.brandText then
        MainWindow.brandText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end

    if MainWindow.titleText then
        MainWindow.titleText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end

    if contentScrollFrame and contentScrollFrame.ScrollBar then
        local scrollBar = contentScrollFrame.ScrollBar
        if scrollBar.Background then
            scrollBar.Background:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        end
        if scrollBar.ThumbTexture then
            scrollBar.ThumbTexture:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        end
    end

    OneWoW_Bags.InfoBar:UpdateViewButtons()

    self:RefreshLayout()
end

function GUI:GetMainWindow()
    return MainWindow
end

local altShowFrame = CreateFrame("Frame")
local altIsDown = false
altShowFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
altShowFrame:SetScript("OnEvent", function(self, event, key, down)
    if not MainWindow or not MainWindow:IsShown() then return end
    local db = OneWoW_Bags.db
    if not db.global.altToShow then return end

    if key == "LALT" or key == "RALT" then
        local nowDown = down == 1
        if nowDown ~= altIsDown then
            altIsDown = nowDown
            if OneWoW_Bags.BagSet then OneWoW_Bags.BagSet:UpdateAllSlots() end
            GUI:RefreshLayout()
        end
    end
end)

function GUI:IsAltShowActive()
    local db = OneWoW_Bags.db
    if not db.global.altToShow then return false end
    return altIsDown
end

function GUI:UpdateBagsBarVisibility()
    if not isInitialized or not MainWindow then return end
    self:RefreshLayout()
end
