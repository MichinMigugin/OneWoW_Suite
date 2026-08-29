local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local Constants = ns.Constants
local L = ns.L
local InfoBar = ns.InfoBar
local WH = ns.WindowHelpers
local Settings = ns.Settings
local BagsBar = ns.BagsBar
local BagSet = ns.BagSet
local CategoryManager = ns.CategoryManager
local Categories = ns.Categories
local ListView = ns.ListView
local BagView = ns.BagView
local CategoryView = ns.CategoryView

local print, pcall = print, pcall

ns.GUI = ns.GUI or {}
local GUI = ns.GUI

local MainWindow = nil
local isInitialized = false
local contentScrollFrame = nil
local contentFrame = nil
local titleBar = nil
local contentArea = nil
local settingsBtn = nil

local function GetDB()
    return ns:GetDB()
end

local function GetLayoutController()
    return ns.WindowLayoutController
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
            GUI._layoutInProgress = false
            GUI:CleanupAllViews()
            InfoBar:ClearSearch()
            ns.activeExpansionFilter = nil
            OneWoW_GUI:SaveWindowPosition(MainWindow, db.global.mainFramePosition)
        end,
        onDragStop = function()
            if isInitialized then ns:RequestLayoutRefresh("bags", "drag_stop") end
        end,
        scaleDBKey = "bagScale",
    })

    if not MainWindow then return end

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
    titleBar, settingsBtn = WH:CreateWindowTitleBar(MainWindow, {
        title = L["ADDON_TITLE"],
        factionTheme = factionTheme,
        onClose = function() MainWindow:Hide() end,
        settingsText = SETTINGS,
        onSettings = function()
            Settings:Toggle()
        end,
    })
    WH:AttachSuiteTitleBarButtons(titleBar, settingsBtn)

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
    WH:AttachLayoutOnShow(MainWindow, "bags", function()
        return BagSet.isBuilt
    end)
    isInitialized = true
end

local function ReleaseAllViews()
    if BagSet.isBuilt then
        local allButtons = BagSet:GetAllButtons()
        for _, button in ipairs(allButtons) do
            button:Hide()
            button:ClearAllPoints()
        end
    end

    CategoryView:ReleaseCompactLabels()
    CategoryManager:ReleaseAllSections()
end

function GUI:CleanupAllViews()
    -- Releasing pooled section frames / labels and hiding item buttons is not a
    -- protected action, so only defer it during combat lockdown. An instanced-map
    -- restriction (Delve) must NOT block cleanup, or stale category headers linger
    -- over the relayout and overlap.
    if OneWoW.Restriction.IsInCombat() then
        -- Defer until lockdown clears, then re-check the window is still hidden:
        -- a re-show in the meantime means the views are live and must be kept.
        OneWoW.Restriction.RunWhenUnrestricted("lockdown", "OneWoW_Bags.cleanup.bags", function()
            if MainWindow and not MainWindow:IsShown() then
                ReleaseAllViews()
            end
        end)
        return
    end

    ReleaseAllViews()
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
    local LD = ns.LayoutDebug
    if not isInitialized or not MainWindow then
        if LD and LD.enabled then LD:Record("refresh_early", { target = "bags", note = "not initialized" }) end
        return
    end
    if not MainWindow:IsShown() then
        if LD and LD.enabled then LD:Record("refresh_early", { target = "bags", note = "frame hidden" }) end
        return
    end
    local db = GetDB()
    local controller = GetLayoutController()
    if not controller or not controller.Refresh then
        if LD and LD.enabled then LD:Record("refresh_early", { target = "bags", note = "no controller" }) end
        return
    end

    local Profile = ns.Profile
    Profile:Start("GUI:RefreshLayout[bags]")

    WH:RunGuardedLayoutRefresh(GUI, "bags", function()
    controller:Refresh({
        layoutDebugTarget = "bags",
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
            local filteredButtons = WH:FilterBySearch(allButtons, InfoBar:GetSearchText(), WH:GetScratchTable("mainSearch"))
            return WH:FilterByExpansion(filteredButtons, ns.activeExpansionFilter, WH:GetScratchTable("mainExpansion"))
        end,
        layoutButtons = function(filteredButtons)
            local _, _, _, contentWidth = WH:GetLayoutMetrics("bagColumns")
            local viewMode = db.global.viewMode
            local viewContext = controller:CreateViewContext({
                sectionManager = CategoryManager,
                containerType = "backpack",
                showEmptySlots = ns.BagsController:GetShowEmptySlots(),
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
                    ns:RequestLayoutRefresh("bags", "relayout")
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
            BagsBar:UpdateIcons()
            BagsBar:UpdateFreeSlots(BagSet:GetFreeSlotCount(), BagSet:GetSlotCount())
            BagsBar:UpdateTrackers()
            BagsBar:RefreshTrackerCounts()
        end,
    })
    end)

    Profile:Stop("GUI:RefreshLayout[bags]")
end

function GUI:OnSearchChanged(text)
    -- Dedupe: the search box fires onTextChanged once during open with empty
    -- text, and can re-fire with unchanged text. Those produce a byte-identical
    -- filter result to the layout that already ran (build_done / warm open), so
    -- skip the redundant full relayout. Search text only ever changes through
    -- this handler, so tracking it here stays in sync with GetSearchText().
    text = text or ""
    if text == (self._lastSearchText or "") then return end
    self._lastSearchText = text
    ns:RequestLayoutRefresh("bags", "search")
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

    -- Warm path lays out synchronously below, so suppress the OnShow hook's
    -- redundant coalesced refresh that would otherwise fire during Show().
    local warm = BagSet.isBuilt
    if warm then
        ns:SetOnShowLayoutSuppressed("bags", true)
    end

    MainWindow:Show()

    -- BagSet:Build() emits its own RequestLayoutRefresh("bags") on completion.
    -- For the warm path (already built), lay out synchronously so the open is
    -- independent of the coalescer (which can be wedged after a zone load).
    if not warm then
        BagSet:Build()
    else
        ns:ClearPendingLayoutRefresh("GUI")
        ns:RequestLayoutRefreshNow("bags")
        ns:SetOnShowLayoutSuppressed("bags", false)
    end

    ns:ScheduleTooltipCatchupRefresh()

    -- Latch-bypassing recovery: forces a layout if the window ends up shown
    -- with items but nothing visible (e.g. a coalescer wedge after a zone load).
    ns:ScheduleOpenSafetyNet("bags", function()
        return MainWindow and MainWindow:IsShown()
    end)

    Categories:BeginRecentExpiryTicker()
end

function GUI:HideWindow()
    Categories:EndRecentExpiryTicker()
    if MainWindow then
        MainWindow:Hide()
    end
end

function GUI:Hide()
    self:HideWindow()
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
    GUI._layoutInProgress = false
    OneWoW.Restriction.CancelWhenUnrestricted("OneWoW_Bags.cleanup.bags")
    Categories:EndRecentExpiryTicker()
    ns.BagSet:ReleaseAll()
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

    WH:ApplyBaseTheme(MainWindow, titleBar, ns.InfoBar, ns.BagsBar)

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
    ns:RequestLayoutRefresh("bags", "theme")
end

function GUI:GetMainWindow()
    return MainWindow
end

local altShowFrame = CreateFrame("Frame")
altShowFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
altShowFrame:SetScript("OnEvent", function(_, _, key, down)
    if not MainWindow or not MainWindow:IsShown() then return end
    local db = GetDB()
    if not db.global.altToShow then return end

    if key == "LALT" or key == "RALT" then
        local nowDown = down == 1
        if nowDown ~= ns.inventoryPresentationState.altShowActive then
            ns:SetAltShowActive(nowDown)
            BagSet:UpdateAllSlots()
            ns:RequestLayoutRefresh("bags", "alt_show")
        end
    end
end)

function GUI:IsAltShowActive()
    return ns:IsAltShowActive()
end

function GUI:UpdateBagsBarVisibility()
    if not isInitialized or not MainWindow then return end
    ns:RequestLayoutRefresh("bags", "bags_bar_visibility")
end
