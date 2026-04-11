local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local InfoBar = OneWoW_Bags.InfoBar
local WH = OneWoW_Bags.WindowHelpers
local Settings = OneWoW_Bags.Settings
local BagsBar = OneWoW_Bags.BagsBar
local BagSet = OneWoW_Bags.BagSet
local CategoryManager = OneWoW_Bags.CategoryManager
local Categories = OneWoW_Bags.Categories
local ListView = OneWoW_Bags.ListView
local BagView = OneWoW_Bags.BagView
local CategoryView = OneWoW_Bags.CategoryView

local print, pcall, pairs = print, pcall, pairs
local InCombatLockdown = InCombatLockdown

OneWoW_Bags.GUI = OneWoW_Bags.GUI or {}
local GUI = OneWoW_Bags.GUI

local MainWindow = nil
local isInitialized = false
local contentScrollFrame = nil
local contentFrame = nil
local titleBar = nil
local contentArea = nil
local settingsBtn = nil
local needsCleanupAfterCombat = false
local cleanupEventFrame = nil

local function GetDB()
    return OneWoW_Bags:GetDB()
end

local function GetLayoutController()
    return OneWoW_Bags.WindowLayoutController
end

function GUI:InitMainWindow()
    if isInitialized then return end

    local db = GetDB()
    MainWindow = WH:CreateWindowShell({
        name = "OneWoW_BagsMainWindow",
        positionDBKey = "mainFramePosition",
        defaultHeight = Constants.GUI.WINDOW_HEIGHT,
        onHide = function()
            if not isInitialized then return end
            GUI:CleanupAllViews()
            InfoBar:ClearSearch()
            OneWoW_Bags.activeExpansionFilter = nil
            OneWoW_GUI:SaveWindowPosition(MainWindow, db.global.mainFramePosition)
        end,
    })

    if not MainWindow then return end

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
    titleBar, settingsBtn = WH:CreateWindowTitleBar(MainWindow, {
        title = L["ADDON_TITLE"],
        factionTheme = factionTheme,
        onClose = function() MainWindow:Hide() end,
        settingsText = L["SETTINGS"],
        onSettings = function()
            Settings:Toggle()
        end,
    })
    WH:AttachShoppingListCartButton(titleBar, settingsBtn)

    contentArea = WH:CreateContentArea(MainWindow)

    local infoBar = InfoBar:Create(contentArea)

    local bagsBar = BagsBar:Create(contentArea)
    BagsBar:SetShown(true)
    BagsBar:UpdateRowVisibility()

    local hideScrollBar = db.global.hideScrollBar
    contentScrollFrame, contentFrame = WH:CreateScrollScaffold({
        contentArea = contentArea,
        scrollName = "OneWoW_BagsContentScroll",
        topAnchor = infoBar,
        bottomAnchor = bagsBar,
        hideScrollBar = hideScrollBar,
    })

    WH:SetupResizeButton(MainWindow, GUI, "mainFramePosition")
    isInitialized = true

    if not cleanupEventFrame then
        cleanupEventFrame = WH:RegisterDeferredCleanup({
            shouldCleanup = function()
                return needsCleanupAfterCombat and MainWindow and not MainWindow:IsShown()
            end,
            cleanup = function()
                GUI:CleanupAllViews()
            end,
        })
    end
end

function GUI:CleanupAllViews()
    if InCombatLockdown() then
        needsCleanupAfterCombat = true
        return
    end
    needsCleanupAfterCombat = false

    if BagSet.isBuilt then
        local allButtons = BagSet:GetAllButtons()
        for _, button in ipairs(allButtons) do
            button:Hide()
            button:ClearAllPoints()
        end
    end

    CategoryManager:ReleaseAllSections()
end

function GUI:UpdateWindowWidth()
    if not MainWindow then return end
    local controller = GetLayoutController()
    if controller and controller.UpdateFixedWidth then
        controller:UpdateFixedWidth({
            mainWindow = MainWindow,
            columnsKey = "bagColumns",
            defaultColumns = 15,
            hideScrollKey = "hideScrollBar",
            outerPadding = OneWoW_GUI:GetSpacing("XS"),
        })
    end
end

function GUI:RefreshLayout()
    if not isInitialized or not MainWindow then return end
    if not MainWindow:IsShown() then return end
    local db = GetDB()
    local controller = GetLayoutController()
    if not controller or not controller.Refresh then return end

    controller:Refresh({
        mainWindow = MainWindow,
        isBuilt = function()
            return BagSet.isBuilt
        end,
        updateWindowWidth = function()
            GUI:UpdateWindowWidth()
        end,
        beforeLayout = function()
            InfoBar:UpdateVisibility()
            BagsBar:UpdateRowVisibility()
            controller:BindScrollFrame({
                scrollFrame = contentScrollFrame,
                hideScrollBar = db.global.hideScrollBar,
                topAnchor = InfoBar:GetFrame(),
                bottomAnchor = BagsBar:GetFrame(),
                contentArea = contentArea,
            })
        end,
        contentFrame = contentFrame,
        containerFrames = BagSet.bagContainerFrames,
        cleanup = function()
            GUI:CleanupAllViews()
        end,
        getButtons = function()
            return BagSet:GetAllButtons()
        end,
        filterButtons = function(allButtons)
            local filteredButtons = WH:FilterBySearch(allButtons, InfoBar:GetSearchText())
            return WH:FilterByExpansion(filteredButtons, OneWoW_Bags.activeExpansionFilter)
        end,
        layoutButtons = function(filteredButtons)
            local _, _, _, contentWidth = WH:GetLayoutMetrics("bagColumns", 15)
            local viewMode = db.global.viewMode
            local viewContext = controller:CreateViewContext({
                sectionManager = CategoryManager,
                containerType = "backpack",
                sortMode = db.global.itemSort,
                getCollapsed = function(kind, key)
                    if kind == "category" then
                        return db.global.collapsedSections[key]
                    end
                    if kind == "bag" then
                        return db.global.collapsedBagSections[key]
                    end
                    if kind == "section" then
                        local section = db.global.categorySections and db.global.categorySections[key]
                        return section and section.collapsed or false
                    end
                end,
                setCollapsed = function(kind, key, collapsed)
                    if kind == "category" then
                        db.global.collapsedSections[key] = collapsed or nil
                    elseif kind == "bag" then
                        db.global.collapsedBagSections[key] = collapsed or nil
                    elseif kind == "section" then
                        local section = db.global.categorySections and db.global.categorySections[key]
                        if section then
                            section.collapsed = collapsed
                        end
                    end
                end,
                requestRelayout = function()
                    GUI:RefreshLayout()
                end,
            })

            if viewMode == "list" then
                return ListView:Layout(contentFrame, filteredButtons, contentWidth, viewContext)
            end
            if viewMode == "category" then
                return CategoryView:Layout(contentFrame, contentWidth, filteredButtons, "backpack", viewContext)
            end
            return BagView:Layout(contentFrame, contentWidth, filteredButtons, viewContext)
        end,
        afterLayout = function()
            BagsBar:UpdateFreeSlots(BagSet:GetFreeSlotCount(), BagSet:GetSlotCount())
            BagsBar:UpdateTrackers()
            BagsBar:RefreshTrackerCounts()
        end,
    })
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

    if not BagSet.isBuilt then
        BagSet:Build()
    end

    WH:QueueContentRefresh(contentScrollFrame, contentFrame, function()
        GUI:RefreshLayout()
    end)

    Categories:BeginRecentExpiryTicker()
end

function GUI:Hide()
    Categories:EndRecentExpiryTicker()
    if MainWindow then
        MainWindow:Hide()
    end
    Settings:Hide()
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
    Categories:EndRecentExpiryTicker()
    OneWoW_Bags.BagSet:ReleaseAll()
    CategoryManager:ReleaseAllSections()
    Settings:Reset()
    InfoBar:Reset()
    BagsBar:Reset()

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

    InfoBar:UpdateViewButtons()
    self:RefreshLayout()
end

function GUI:GetMainWindow()
    return MainWindow
end

local altShowFrame = CreateFrame("Frame")
altShowFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
altShowFrame:SetScript("OnEvent", function(self, event, key, down)
    if not MainWindow or not MainWindow:IsShown() then return end
    local db = GetDB()
    if not db.global.altToShow then return end

    if key == "LALT" or key == "RALT" then
        local nowDown = down == 1
        if nowDown ~= OneWoW_Bags.inventoryPresentationState.altShowActive then
            OneWoW_Bags:SetAltShowActive(nowDown)
            BagSet:UpdateAllSlots()
            GUI:RefreshLayout()
        end
    end
end)

function GUI:IsAltShowActive()
    return OneWoW_Bags:IsAltShowActive()
end

function GUI:UpdateBagsBarVisibility()
    if not isInitialized or not MainWindow then return end
    self:RefreshLayout()
end
