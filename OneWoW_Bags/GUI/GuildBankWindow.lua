local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local Constants = ns.Constants
local WH = ns.WindowHelpers
local GuildBankInfoBar = ns.GuildBankInfoBar
local GuildBankBar = ns.GuildBankBar
local GuildBankSet = ns.GuildBankSet
local GuildBankCategoryManager = ns.GuildBankCategoryManager
local GuildBankTabView = ns.GuildBankTabView
local ListView = ns.ListView
local GuildBankLog = ns.GuildBankLog

local pcall, print = pcall, print
local ipairs = ipairs
local C_Timer = C_Timer
local C_PlayerInteractionManager = C_PlayerInteractionManager

ns.GuildBankGUI = ns.GuildBankGUI or {}
local GuildBankGUI = ns.GuildBankGUI

local MainWindow = nil
local isInitialized = false
local contentScrollFrame = nil
local contentFrame = nil
local titleBar = nil
local contentArea = nil

local function GetDB()
    return ns:GetDB()
end

local function GetLayoutController()
    return ns.WindowLayoutController
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
            GuildBankGUI._layoutInProgress = false
            GuildBankGUI:CleanupAllViews()
            GuildBankInfoBar:ClearSearch()
            GuildBankLog:Hide()

            OneWoW_GUI:SaveWindowPosition(MainWindow, db.global.guildBankFramePosition)
            if ns.guildBankOpen then
                ns.guildBankOpen = false
                GuildBankSet:ReleaseAll()
                GuildBankSet:ClearCache()
                if ns.RestoreGuildBankFrame then
                    ns:RestoreGuildBankFrame()
                end
                C_Timer.After(0, function()
                    C_PlayerInteractionManager.ClearInteraction(Enum.PlayerInteractionType.GuildBanker)
                end)
            end
        end,
        onDragStop = function()
            if isInitialized then ns:RequestLayoutRefresh("guild", "drag_stop") end
        end,
        scaleDBKey = "guildBankScale",
    })

    if not MainWindow then return end

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
    local guildBankSettingsBtn
    titleBar, guildBankSettingsBtn = WH:CreateWindowTitleBar(MainWindow, {
        title = GUILD_BANK,
        factionTheme = factionTheme,
        onClose = function() MainWindow:Hide() end,
        settingsText = SETTINGS,
        onSettings = function()
            if ns.Settings then
                ns.Settings:Toggle()
            end
        end,
    })
    WH:AttachSuiteTitleBarButtons(titleBar, guildBankSettingsBtn)
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
    WH:AttachLayoutOnShow(MainWindow, "guild", function()
        return GuildBankSet.isBuilt
    end)
    isInitialized = true
end

local function ReleaseAllViews()
    if GuildBankSet.isBuilt then
        local allButtons = GuildBankSet:GetAllButtons()
        for _, button in ipairs(allButtons) do
            button:Hide()
            button:ClearAllPoints()
        end
    end

    GuildBankCategoryManager:ReleaseAllSections()
end

function GuildBankGUI:CleanupAllViews()
    -- Releasing pooled section frames / labels and hiding item buttons is not a
    -- protected action, so only defer it during combat lockdown. An instanced-map
    -- restriction (Delve) must NOT block cleanup, or stale category headers linger
    -- over the relayout and overlap.
    if OneWoW.Restriction.IsInCombat() then
        -- Defer until lockdown clears, then re-check the window is still hidden:
        -- a re-show in the meantime means the views are live and must be kept.
        OneWoW.Restriction.RunWhenUnrestricted("lockdown", "OneWoW_Bags.cleanup.guildbank", function()
            if MainWindow and not MainWindow:IsShown() then
                ReleaseAllViews()
            end
        end)
        return
    end

    ReleaseAllViews()
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
    local LD = ns.LayoutDebug
    if not isInitialized or not MainWindow then
        if LD and LD.enabled then LD:Record("refresh_early", { target = "guild", note = "not initialized" }) end
        return
    end
    if not MainWindow:IsShown() then
        if LD and LD.enabled then LD:Record("refresh_early", { target = "guild", note = "frame hidden" }) end
        return
    end
    local db = GetDB()
    local controller = GetLayoutController()
    if not controller or not controller.Refresh then
        if LD and LD.enabled then LD:Record("refresh_early", { target = "guild", note = "no controller" }) end
        return
    end

    local Profile = ns.Profile
    Profile:Start("GuildBankGUI:RefreshLayout")

    WH:RunGuardedLayoutRefresh(GuildBankGUI, "guild", function()
    controller:Refresh({
        layoutDebugTarget = "guild",
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
            local visibleButtons = WH:FilterByTab(allButtons, db.global.guildBankSelectedTab, WH:GetScratchTable("guildBankTab"))
            return WH:FilterBySearch(visibleButtons, GuildBankInfoBar:GetSearchText(), WH:GetScratchTable("guildBankSearch"))
        end,
        layoutButtons = function(filteredButtons)
            local _, _, _, contentWidth = WH:GetLayoutMetrics("bankColumns")
            local tabViewContext = controller:CreateViewContext({
                sectionManager = GuildBankCategoryManager,
                showEmptySlots = ns.GuildBankController:GetShowEmptySlots(),
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
                    ns:RequestLayoutRefresh("guild", "relayout")
                end,
            })

            if db.global.guildBankViewMode == "tab" then
                return GuildBankTabView:Layout(contentFrame, contentWidth, filteredButtons, tabViewContext)
            end
            return ListView:Layout(contentFrame, filteredButtons, contentWidth, tabViewContext)
        end,
        afterLayout = function(buttons)
            -- Overlay paint only walks buttons from this layout pass (filter token),
            -- not every tab slot — IsVisible() stays true for hidden-tab buttons.
            GuildBankGUI._overlayFilterToken = buttons and buttons._owb_filterToken
            GuildBankBar:UpdateFreeSlots(GuildBankSet:GetFreeSlotCount(), GuildBankSet:GetSlotCount())
        end,
    })
    end)

    Profile:Stop("GuildBankGUI:RefreshLayout")
end

function GuildBankGUI:OnSearchChanged(text)
    -- Dedupe: the search box fires onTextChanged once during open with empty
    -- text, and can re-fire with unchanged text. Those produce a byte-identical
    -- filter result to the layout that already ran (build_done / warm open), so
    -- skip the redundant full relayout. Search text only ever changes through
    -- this handler, so tracking it here stays in sync with GetSearchText().
    text = text or ""
    if text == (self._lastSearchText or "") then return end
    self._lastSearchText = text
    ns:MarkGuildOverlaysDirty("search")
    ns:RequestLayoutRefresh("guild", "search")
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

    -- Warm path lays out synchronously below, so suppress the OnShow hook's
    -- redundant coalesced refresh that would otherwise fire during Show().
    local warm = GuildBankSet.isBuilt
    if warm then
        ns:SetOnShowLayoutSuppressed("guild", true)
    end

    MainWindow:Show()

    -- GuildBankSet:Build() emits its own RequestLayoutRefresh("guild") on completion.
    -- For the warm path (already built), lay out synchronously so the open is
    -- independent of the coalescer (which can be wedged after a zone load).
    if not warm then
        GuildBankSet:Build()
    else
        ns:ClearPendingLayoutRefresh("GuildBankGUI")
        ns:RequestLayoutRefreshNow("guild", "warm_open")
        ns:SetOnShowLayoutSuppressed("guild", false)
    end

    GuildBankBar:BuildTabButtons()
    GuildBankBar:UpdateTabHighlights()
    GuildBankBar:UpdateGold()
    GuildBankInfoBar:UpdateViewButtons()
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
    GuildBankGUI._layoutInProgress = false
    OneWoW.Restriction.CancelWhenUnrestricted("OneWoW_Bags.cleanup.guildbank")
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

    ns:RequestLayoutRefresh("guild", "theme")
end

function GuildBankGUI:GetMainWindow()
    return MainWindow
end
