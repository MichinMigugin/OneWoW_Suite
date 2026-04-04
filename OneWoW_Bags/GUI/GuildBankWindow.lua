local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

local Constants = OneWoW_Bags.Constants
local db = OneWoW_Bags.db
local L = OneWoW_Bags.L
local WH = OneWoW_Bags.WindowHelpers
local GuildBankInfoBar = OneWoW_Bags.GuildBankInfoBar
local GuildBankBar = OneWoW_Bags.GuildBankBar
local GuildBankSet = OneWoW_Bags.GuildBankSet
local GuildBankCategoryManager = OneWoW_Bags.GuildBankCategoryManager
local GuildBankTabView = OneWoW_Bags.GuildBankTabView
local ListView = OneWoW_Bags.ListView
local GuildBankLog = OneWoW_Bags.GuildBankLog

local pcall, print = pcall, print
local pairs, ipairs = pairs, ipairs
local InCombatLockdown = InCombatLockdown
local C_Timer = C_Timer
local C_PlayerInteractionManager = C_PlayerInteractionManager

OneWoW_Bags.GuildBankGUI = OneWoW_Bags.GuildBankGUI or {}
local GuildBankGUI = OneWoW_Bags.GuildBankGUI

local MainWindow = nil
local isInitialized = false
local contentScrollFrame = nil
local contentFrame = nil
local titleBar = nil
local contentArea = nil
local needsCleanupAfterCombat = false

function GuildBankGUI:InitMainWindow()
    if isInitialized then return end

    local savedHeight = db.global.guildBankFramePosition.height
    local windowHeight = savedHeight or Constants.GUI.WINDOW_HEIGHT

    MainWindow = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_GuildBankMainWindow",
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
        OneWoW_GUI:SaveWindowPosition(self, db.global.guildBankFramePosition)
    end)
    MainWindow:SetClampedToScreen(true)
    MainWindow:SetClampRectInsets(0, 0, 0, 0)
    MainWindow:SetFrameStrata("MEDIUM")
    MainWindow:SetToplevel(true)
    MainWindow:SetScript("OnHide", function()
        if not isInitialized then return end
        GuildBankGUI:CleanupAllViews()
        GuildBankInfoBar:ClearSearch()
        GuildBankLog:Hide()

        OneWoW_GUI:SaveWindowPosition(MainWindow, db.global.guildBankFramePosition)
        if OneWoW_Bags.guildBankOpen then
            OneWoW_Bags.guildBankOpen = false
            GuildBankSet:ReleaseAll()
            GuildBankSet:ClearCache()
            if OneWoW_Bags.RestoreGuildBankFrame then
                OneWoW_Bags:RestoreGuildBankFrame()
            end
            C_Timer.After(0, function()
                C_PlayerInteractionManager.ClearInteraction(Enum.PlayerInteractionType.GuildBanker)
            end)
        end
    end)
    MainWindow:Hide()

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
    titleBar = OneWoW_GUI:CreateTitleBar(MainWindow, {
        title = L["GUILD_BANK_TITLE"],
        height = Constants.GUI.TITLEBAR_HEIGHT,
        showBrand = true,
        factionTheme = factionTheme,
        onClose = function() MainWindow:Hide() end,
    })

    local settingsBtn = OneWoW_GUI:CreateFitTextButton(titleBar, { text = L["SETTINGS"], height = 20, minWidth = 30 })
    settingsBtn:SetPoint("RIGHT", titleBar._closeBtn, "LEFT", -2, 0)
    settingsBtn:SetScript("OnClick", function()
        if OneWoW_Bags.Settings then
            OneWoW_Bags.Settings:Toggle()
        end
    end)

    contentArea = CreateFrame("Frame", nil, MainWindow)
    contentArea:SetPoint("TOPLEFT", MainWindow, "TOPLEFT", OneWoW_GUI:GetSpacing("XS"), -(OneWoW_GUI:GetSpacing("XS") + Constants.GUI.TITLEBAR_HEIGHT + OneWoW_GUI:GetSpacing("XS")))
    contentArea:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("XS"), OneWoW_GUI:GetSpacing("XS"))
    MainWindow.contentArea = contentArea

    local infoBar = GuildBankInfoBar:Create(contentArea)
    local guildBankBar = GuildBankBar:Create(contentArea)
    GuildBankBar:SetShown(true)

    local hideScrollBar = db.global.bankHideScrollBar
    local scrollbarOffset = hideScrollBar and 0 or -12

    local scrollName = "OneWoW_GuildBankContentScroll"
    contentScrollFrame = CreateFrame("ScrollFrame", scrollName, contentArea, "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", infoBar, "BOTTOMLEFT", 0, -2)
    contentScrollFrame:SetPoint("BOTTOMRIGHT", guildBankBar, "TOPRIGHT", scrollbarOffset, 2)

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

    WH:SetupResizeButton(MainWindow, GuildBankGUI, "guildBankFramePosition")

    WH:RegisterSpecialFrame("OneWoW_GuildBankMainWindow", MainWindow)
    isInitialized = true

    WH:SaveAndRestorePosition(MainWindow, "guildBankFramePosition")
end

function GuildBankGUI:CleanupAllViews()
    if InCombatLockdown() then
        needsCleanupAfterCombat = true
        return
    end
    needsCleanupAfterCombat = false
 
    if GuildBankSet.isBuilt then
        local allButtons = GuildBankSet:GetAllButtons()
        for _, button in ipairs(allButtons) do
            button:Hide()
            button:ClearAllPoints()
        end
    end

    GuildBankCategoryManager:ReleaseAllSections()
end

local cleanupEventFrame = CreateFrame("Frame")
cleanupEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
cleanupEventFrame:SetScript("OnEvent", function()
    if needsCleanupAfterCombat and MainWindow and not MainWindow:IsShown() then
        GuildBankGUI:CleanupAllViews()
    end
end)

function GuildBankGUI:UpdateWindowWidth()
    if not MainWindow then return end

    local cols = db.global.bankColumns
    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local scrollbarSpace = db.global.bankHideScrollBar and 0 or 12
    local newWidth = cols * (iconSize + spacing) - spacing + 4 + scrollbarSpace + (2 * OneWoW_GUI:GetSpacing("XS"))
    MainWindow:SetWidth(newWidth)
    MainWindow:SetResizeBounds(newWidth, 300, newWidth, 1200)
end

function GuildBankGUI:RefreshLayout()
    if not isInitialized or not MainWindow then return end
    if not MainWindow:IsShown() then return end
    if not GuildBankSet.isBuilt then return end

    GuildBankGUI:UpdateWindowWidth()

    if contentFrame and GuildBankSet.bagContainerFrames then
        for _, tabFrame in pairs(GuildBankSet.bagContainerFrames) do
            tabFrame:SetParent(contentFrame)
        end
    end

    GuildBankGUI:CleanupAllViews()

    local allButtons = GuildBankSet:GetAllButtons()
    local visibleButtons = WH:FilterByTab(allButtons, db.global.guildBankSelectedTab)
    local searchText = GuildBankInfoBar:GetSearchText()
    local filteredButtons = WH:FilterBySearch(visibleButtons, searchText)

    local viewMode = db.global.guildBankViewMode
    local cols, iconSize, spacing, contentWidth = WH:GetLayoutMetrics("bankColumns", 14)

    local layoutHeight = 100

    if viewMode == "tab" then
        layoutHeight = GuildBankTabView:Layout(contentFrame, contentWidth, filteredButtons)
    else
        layoutHeight = ListView:Layout(contentFrame, filteredButtons, contentWidth)
    end

    contentFrame:SetHeight(layoutHeight)

    local freeSlots = GuildBankSet:GetFreeSlotCount()
    local totalSlots = GuildBankSet:GetSlotCount()
    GuildBankBar:UpdateFreeSlots(freeSlots, totalSlots)
end

function GuildBankGUI:OnSearchChanged(text)
    self:RefreshLayout()
end

function GuildBankGUI:Show()
    if not isInitialized then
        local ok, initErr = pcall(function() GuildBankGUI:InitMainWindow() end)
        if not ok then
            print("|cffff4444OneWoW_Bags:|r GuildBankWindow init failed:", initErr)
            return
        end
    end

    if not MainWindow then return end
    db.global.guildBankSelectedTab = nil

    MainWindow:Show()

    if not GuildBankSet.isBuilt then
        GuildBankSet:Build()
    end

    GuildBankBar:BuildTabButtons()
    GuildBankBar:UpdateTabHighlights()
    GuildBankBar:UpdateGold()
    GuildBankInfoBar:UpdateViewButtons()

    C_Timer.After(0, function()
        if contentScrollFrame and contentFrame then
            local w = contentScrollFrame:GetWidth()
            if w and w > 10 then
                contentFrame:SetWidth(w)
            end
        end
        GuildBankGUI:RefreshLayout()
    end)
end

function GuildBankGUI:Hide()
    if MainWindow then
        MainWindow:Hide()
    end
end

function GuildBankGUI:Toggle()
    if MainWindow and MainWindow:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function GuildBankGUI:IsShown()
    return MainWindow and MainWindow:IsShown()
end

function GuildBankGUI:FullReset()
    GuildBankLog:Reset()
    GuildBankSet:ReleaseAll()
    GuildBankInfoBar:Reset()
    GuildBankBar:Reset()

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

function GuildBankGUI:ApplyTheme()
    if not MainWindow then return end

    WH:ApplyBaseTheme(MainWindow, titleBar, GuildBankInfoBar, GuildBankBar)

    GuildBankInfoBar:UpdateViewButtons()
    GuildBankLog:ApplyTheme()

    self:RefreshLayout()
end

function GuildBankGUI:GetMainWindow()
    return MainWindow
end
