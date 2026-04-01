local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_Bags.GuildBankGUI = OneWoW_Bags.GuildBankGUI or {}
local GuildBankGUI = OneWoW_Bags.GuildBankGUI
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

function GuildBankGUI:InitMainWindow()
    if isInitialized then return end
    if not Constants or not Constants.GUI then return end

    local C = Constants.GUI
    local db = OneWoW_Bags.db
    local savedHeight = db and db.global and db.global.guildBankFramePosition and db.global.guildBankFramePosition.height
    local windowHeight = savedHeight or C.WINDOW_HEIGHT

    MainWindow = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_GuildBankMainWindow",
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
            d.global.guildBankFramePosition = d.global.guildBankFramePosition or {}
            OneWoW_GUI:SaveWindowPosition(self, d.global.guildBankFramePosition)
        end
    end)
    MainWindow:SetClampedToScreen(true)
    MainWindow:SetClampRectInsets(0, 0, 0, 0)
    MainWindow:SetFrameStrata("MEDIUM")
    MainWindow:SetToplevel(true)
    MainWindow:SetScript("OnHide", function()
        if not isInitialized then return end
        GuildBankGUI:CleanupAllViews()
        if OneWoW_Bags.GuildBankInfoBar and OneWoW_Bags.GuildBankInfoBar.ClearSearch then
            OneWoW_Bags.GuildBankInfoBar:ClearSearch()
        end
        if OneWoW_Bags.GuildBankLog then
            OneWoW_Bags.GuildBankLog:Hide()
        end
        local d = OneWoW_Bags.db
        if d and d.global then
            d.global.guildBankFramePosition = d.global.guildBankFramePosition or {}
            OneWoW_GUI:SaveWindowPosition(MainWindow, d.global.guildBankFramePosition)
        end
        if OneWoW_Bags.guildBankOpen then
            OneWoW_Bags.guildBankOpen = false
            if OneWoW_Bags.GuildBankSet then
                OneWoW_Bags.GuildBankSet:ReleaseAll()
                OneWoW_Bags.GuildBankSet:ClearCache()
            end
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
        title = L["GUILD_BANK_TITLE"] or "Guild Bank",
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

    local infoBar = OneWoW_Bags.GuildBankInfoBar:Create(contentArea)
    local guildBankBar = OneWoW_Bags.GuildBankBar:Create(contentArea)
    OneWoW_Bags.GuildBankBar:SetShown(true)

    local hideScrollBar = OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.bankHideScrollBar
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
    local GuildBankSet = OneWoW_Bags.GuildBankSet
    if GuildBankSet and GuildBankSet.isBuilt then
        local allButtons = GuildBankSet:GetAllButtons()
        for _, button in ipairs(allButtons) do
            button:Hide()
            button:ClearAllPoints()
        end
    end

    if OneWoW_Bags.GuildBankCategoryManager then
        OneWoW_Bags.GuildBankCategoryManager:ReleaseAllSections()
    end
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

function GuildBankGUI:RefreshLayout()
    if not isInitialized or not MainWindow then return end
    if not MainWindow:IsShown() then return end

    local GuildBankSet = OneWoW_Bags.GuildBankSet
    if not GuildBankSet or not GuildBankSet.isBuilt then return end

    GuildBankGUI:UpdateWindowWidth()

    if contentFrame and GuildBankSet.bagContainerFrames then
        for _, tabFrame in pairs(GuildBankSet.bagContainerFrames) do
            tabFrame:SetParent(contentFrame)
        end
    end

    GuildBankGUI:CleanupAllViews()

    local db = OneWoW_Bags.db

    local allButtons = GuildBankSet:GetAllButtons()
    local visibleButtons = WH:FilterByTab(allButtons, db and db.global.guildBankSelectedTab)
    local searchText = OneWoW_Bags.GuildBankInfoBar:GetSearchText()
    local filteredButtons = WH:FilterBySearch(visibleButtons, searchText)

    local viewMode = db and db.global and db.global.guildBankViewMode or "list"
    local cols, iconSize, spacing, contentWidth = WH:GetLayoutMetrics("bankColumns", 14)

    local layoutHeight = 100

    if viewMode == "tab" then
        layoutHeight = OneWoW_Bags.GuildBankTabView:Layout(contentFrame, contentWidth, filteredButtons)
    else
        layoutHeight = OneWoW_Bags.ListView:Layout(contentFrame, filteredButtons, contentWidth)
    end

    contentFrame:SetHeight(layoutHeight)

    local freeSlots = GuildBankSet:GetFreeSlotCount()
    local totalSlots = GuildBankSet:GetSlotCount()
    if OneWoW_Bags.GuildBankBar and OneWoW_Bags.GuildBankBar.UpdateFreeSlots then
        OneWoW_Bags.GuildBankBar:UpdateFreeSlots(freeSlots, totalSlots)
    end
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

    local db = OneWoW_Bags.db
    if db and db.global then
        db.global.guildBankSelectedTab = nil
    end

    MainWindow:Show()

    local GuildBankSet = OneWoW_Bags.GuildBankSet
    if GuildBankSet and not GuildBankSet.isBuilt then
        GuildBankSet:Build()
    end

    if OneWoW_Bags.GuildBankBar then
        OneWoW_Bags.GuildBankBar:BuildTabButtons()
        OneWoW_Bags.GuildBankBar:UpdateTabHighlights()
        OneWoW_Bags.GuildBankBar:UpdateGold()
    end

    if OneWoW_Bags.GuildBankInfoBar then
        OneWoW_Bags.GuildBankInfoBar:UpdateViewButtons()
    end

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
    if OneWoW_Bags.GuildBankLog then
        OneWoW_Bags.GuildBankLog:Reset()
    end

    if OneWoW_Bags.GuildBankSet then
        OneWoW_Bags.GuildBankSet:ReleaseAll()
    end

    if OneWoW_Bags.GuildBankInfoBar and OneWoW_Bags.GuildBankInfoBar.Reset then
        OneWoW_Bags.GuildBankInfoBar:Reset()
    end

    if OneWoW_Bags.GuildBankBar and OneWoW_Bags.GuildBankBar.Reset then
        OneWoW_Bags.GuildBankBar:Reset()
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

function GuildBankGUI:ApplyTheme()
    if not MainWindow then return end

    WH:ApplyBaseTheme(MainWindow, titleBar, OneWoW_Bags.GuildBankInfoBar, OneWoW_Bags.GuildBankBar)

    OneWoW_Bags.GuildBankInfoBar:UpdateViewButtons()

    if OneWoW_Bags.GuildBankLog then
        OneWoW_Bags.GuildBankLog:ApplyTheme()
    end

    self:RefreshLayout()
end

function GuildBankGUI:GetMainWindow()
    return MainWindow
end
