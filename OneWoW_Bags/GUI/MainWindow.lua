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

local function GetDB()
    return OneWoW_Bags:GetDB()
end

local function GetLayoutController()
    return OneWoW_Bags.WindowLayoutController
end

function GUI:InitMainWindow()
    if isInitialized then return end

    local db = GetDB()
    local savedHeight = db.global.mainFramePosition.height
    local windowHeight = savedHeight or Constants.GUI.WINDOW_HEIGHT

    MainWindow = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_BagsMainWindow",
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
        OneWoW_GUI:SaveWindowPosition(self, db.global.mainFramePosition)
    end)
    MainWindow:SetClampedToScreen(true)
    MainWindow:SetClampRectInsets(0, 0, 0, 0)
    MainWindow:SetFrameStrata("MEDIUM")
    MainWindow:SetToplevel(true)
    MainWindow:SetScript("OnHide", function()
        if not isInitialized then return end
        GUI:CleanupAllViews()
        InfoBar:ClearSearch()
        OneWoW_Bags.activeExpansionFilter = nil
        OneWoW_GUI:SaveWindowPosition(MainWindow, db.global.mainFramePosition)
    end)
    MainWindow:Hide()

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
    titleBar = OneWoW_GUI:CreateTitleBar(MainWindow, {
        title = L["ADDON_TITLE"],
        height = Constants.GUI.TITLEBAR_HEIGHT,
        showBrand = true,
        factionTheme = factionTheme,
        onClose = function() MainWindow:Hide() end,
    })

    settingsBtn = OneWoW_GUI:CreateFitTextButton(titleBar, { text = L["SETTINGS"], height = 20, minWidth = 30 })
    settingsBtn:SetPoint("RIGHT", titleBar._closeBtn, "LEFT", -2, 0)
    settingsBtn:SetScript("OnClick", function()
        Settings:Toggle()
    end)

    contentArea = CreateFrame("Frame", nil, MainWindow)
    contentArea:SetPoint("TOPLEFT", MainWindow, "TOPLEFT", OneWoW_GUI:GetSpacing("XS"), -(OneWoW_GUI:GetSpacing("XS") + Constants.GUI.TITLEBAR_HEIGHT + OneWoW_GUI:GetSpacing("XS")))
    contentArea:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("XS"), OneWoW_GUI:GetSpacing("XS"))
    MainWindow.contentArea = contentArea

    local infoBar = InfoBar:Create(contentArea)

    local bagsBar = BagsBar:Create(contentArea)
    local showBagsBar = db.global.showBagsBar
    if showBagsBar == nil then showBagsBar = true end
    BagsBar:SetShown(showBagsBar)

    local hideScrollBar = db.global.hideScrollBar
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

    if BagSet.isBuilt then
        local allButtons = BagSet:GetAllButtons()
        for _, button in ipairs(allButtons) do
            button:Hide()
            button:ClearAllPoints()
        end
    end

    CategoryManager:ReleaseAllSections()
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
                return ListView:Layout(contentFrame, filteredButtons, contentWidth)
            end
            if viewMode == "category" then
                return CategoryView:Layout(contentFrame, contentWidth, filteredButtons, "backpack", viewContext)
            end
            return BagView:Layout(contentFrame, contentWidth, filteredButtons, viewContext)
        end,
        afterLayout = function()
            BagsBar:UpdateFreeSlots(BagSet:GetFreeSlotCount(), BagSet:GetSlotCount())
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
local altIsDown = false
altShowFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
altShowFrame:SetScript("OnEvent", function(self, event, key, down)
    if not MainWindow or not MainWindow:IsShown() then return end
    local db = GetDB()
    if not db.global.altToShow then return end

    if key == "LALT" or key == "RALT" then
        local nowDown = down == 1
        if nowDown ~= altIsDown then
            altIsDown = nowDown
            BagSet:UpdateAllSlots()
            GUI:RefreshLayout()
        end
    end
end)

function GUI:IsAltShowActive()
    local db = GetDB()
    if not db.global.altToShow then return false end
    return altIsDown
end

function GUI:UpdateBagsBarVisibility()
    if not isInitialized or not MainWindow then return end
    self:RefreshLayout()
end
