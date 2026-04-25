local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_Bags.Constants
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
local cleanupEventFrame = nil

local function GetDB()
    return OneWoW_Bags:GetDB()
end

local function GetLayoutController()
    return OneWoW_Bags.WindowLayoutController
end

function GuildBankGUI:InitMainWindow()
    if isInitialized then return end

    local db = GetDB()
    MainWindow = WH:CreateWindowShell({
        name = "OneWoW_GuildBankMainWindow",
        positionDBKey = "guildBankFramePosition",
        defaultHeight = Constants.GUI.WINDOW_HEIGHT,
        onHide = function()
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
        end,
        onDragStop = function()
            if isInitialized then GuildBankGUI:RefreshLayout() end
        end,
    })

    if not MainWindow then return end

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
    local guildBankSettingsBtn
    titleBar, guildBankSettingsBtn = WH:CreateWindowTitleBar(MainWindow, {
        title = GUILD_BANK,
        factionTheme = factionTheme,
        onClose = function() MainWindow:Hide() end,
        settingsText = L["SETTINGS"],
        onSettings = function()
            if OneWoW_Bags.Settings then
                OneWoW_Bags.Settings:Toggle()
            end
        end,
    })
    WH:AttachShoppingListCartButton(titleBar, guildBankSettingsBtn)
    contentArea = WH:CreateContentArea(MainWindow)

    local infoBar = GuildBankInfoBar:Create(contentArea)
    local guildBankBar = GuildBankBar:Create(contentArea)
    GuildBankBar:SetShown(true)

    local hideScrollBar = db.global.bankHideScrollBar
    contentScrollFrame, contentFrame = WH:CreateScrollScaffold({
        contentArea = contentArea,
        scrollName = "OneWoW_GuildBankContentScroll",
        topAnchor = infoBar,
        bottomAnchor = guildBankBar,
        hideScrollBar = hideScrollBar,
    })

    WH:SetupResizeButton(MainWindow, GuildBankGUI, "guildBankFramePosition")
    isInitialized = true

    if not cleanupEventFrame then
        cleanupEventFrame = WH:RegisterDeferredCleanup({
            shouldCleanup = function()
                return needsCleanupAfterCombat and MainWindow and not MainWindow:IsShown()
            end,
            cleanup = function()
                GuildBankGUI:CleanupAllViews()
            end,
        })
    end
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

function GuildBankGUI:UpdateWindowWidth()
    if not MainWindow then return end
    local controller = GetLayoutController()
    if controller and controller.UpdateFixedWidth then
        controller:UpdateFixedWidth({
            mainWindow = MainWindow,
            columnsKey = "bankColumns",
            defaultColumns = 15,
            hideScrollKey = "bankHideScrollBar",
            outerPadding = OneWoW_GUI:GetSpacing("XS"),
        })
    end
end

function GuildBankGUI:RefreshLayout()
    if not isInitialized or not MainWindow then return end
    if not MainWindow:IsShown() then return end
    local db = GetDB()
    local controller = GetLayoutController()
    if not controller or not controller.Refresh then return end

    controller:Refresh({
        mainWindow = MainWindow,
        isBuilt = function()
            return GuildBankSet.isBuilt
        end,
        updateWindowWidth = function()
            GuildBankGUI:UpdateWindowWidth()
        end,
        beforeLayout = function()
            GuildBankInfoBar:UpdateVisibility()
            GuildBankBar:RefreshChromeAnchors()
            controller:BindScrollFrame({
                scrollFrame = contentScrollFrame,
                hideScrollBar = db.global.bankHideScrollBar,
                topAnchor = GuildBankInfoBar:GetFrame(),
                bottomAnchor = GuildBankBar:GetFrame(),
                contentArea = contentArea,
            })
        end,
        contentFrame = contentFrame,
        containerFrames = GuildBankSet.bagContainerFrames,
        cleanup = function()
            GuildBankGUI:CleanupAllViews()
        end,
        getButtons = function()
            return GuildBankSet:GetAllButtons()
        end,
        filterButtons = function(allButtons)
            local visibleButtons = WH:FilterByTab(allButtons, db.global.guildBankSelectedTab)
            return WH:FilterBySearch(visibleButtons, GuildBankInfoBar:GetSearchText())
        end,
        layoutButtons = function(filteredButtons)
            local _, _, _, contentWidth = WH:GetLayoutMetrics("bankColumns", 15)
            local tabViewContext = controller:CreateViewContext({
                sectionManager = GuildBankCategoryManager,
                sortMode = db.global.itemSort,
                getCollapsed = function(kind, key)
                    if kind == "tab" then
                        return db.global.collapsedGuildBankTabSections[key] or db.global.collapsedGuildBankSections[key]
                    end
                end,
                setCollapsed = function(kind, key, collapsed)
                    if kind == "tab" then
                        db.global.collapsedGuildBankTabSections[key] = collapsed or nil
                    end
                end,
                requestRelayout = function()
                    GuildBankGUI:RefreshLayout()
                end,
            })

            if db.global.guildBankViewMode == "tab" then
                return GuildBankTabView:Layout(contentFrame, contentWidth, filteredButtons, tabViewContext)
            end
            return ListView:Layout(contentFrame, filteredButtons, contentWidth, tabViewContext)
        end,
        afterLayout = function()
            GuildBankBar:UpdateFreeSlots(GuildBankSet:GetFreeSlotCount(), GuildBankSet:GetSlotCount())
        end,
    })
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
    local db = GetDB()
    db.global.guildBankSelectedTab = nil

    MainWindow:Show()

    if not GuildBankSet.isBuilt then
        GuildBankSet:Build()
    end

    GuildBankBar:BuildTabButtons()
    GuildBankBar:UpdateTabHighlights()
    GuildBankBar:UpdateGold()
    GuildBankInfoBar:UpdateViewButtons()

    WH:QueueContentRefresh(contentScrollFrame, contentFrame, function()
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
