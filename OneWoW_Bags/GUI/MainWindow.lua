local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.GUI = OneWoW_Bags.GUI or {}
local GUI = OneWoW_Bags.GUI
local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local OneWoW_GUI = OneWoW_Bags.GUILib
local T = OneWoW_Bags.T
local S = OneWoW_Bags.S

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
    local savedHeight = db and db.global and db.global.mainFramePosition and db.global.mainFramePosition.height
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
        local d = OneWoW_Bags.db
        if d and d.global then
            d.global.mainFramePosition = d.global.mainFramePosition or {}
            OneWoW_GUI:SaveWindowPosition(self, d.global.mainFramePosition)
        end
    end)
    MainWindow:SetClampedToScreen(true)
    MainWindow:SetFrameStrata("MEDIUM")
    MainWindow:SetToplevel(true)
    MainWindow:SetScript("OnHide", function()
        if not isInitialized then return end
        GUI:CleanupAllViews()
        if OneWoW_Bags.InfoBar and OneWoW_Bags.InfoBar.ClearSearch then
            OneWoW_Bags.InfoBar:ClearSearch()
        end
        local d = OneWoW_Bags.db
        if d and d.global then
            d.global.mainFramePosition = d.global.mainFramePosition or {}
            OneWoW_GUI:SaveWindowPosition(MainWindow, d.global.mainFramePosition)
        end
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
    contentArea:SetPoint("TOPLEFT", MainWindow, "TOPLEFT", S("XS"), -(S("XS") + C.TITLEBAR_HEIGHT + S("XS")))
    contentArea:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -S("XS"), S("XS"))
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

    local resizeBtn = CreateFrame("Button", nil, MainWindow)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetFrameLevel(MainWindow:GetFrameLevel() + 10)
    resizeBtn:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            MainWindow:StartSizing("BOTTOM")
        end
    end)
    resizeBtn:SetScript("OnMouseUp", function(self)
        MainWindow:StopMovingOrSizing()
        local d = OneWoW_Bags.db
        if d and d.global then
            d.global.mainFramePosition = d.global.mainFramePosition or {}
            OneWoW_GUI:SaveWindowPosition(MainWindow, d.global.mainFramePosition)
        end
        if GUI.RefreshLayout then GUI:RefreshLayout() end
    end)

    _G["OneWoW_BagsMainWindow"] = MainWindow
    local alreadyRegistered = false
    for _, name in ipairs(UISpecialFrames) do
        if name == "OneWoW_BagsMainWindow" then alreadyRegistered = true; break end
    end
    if not alreadyRegistered then
        tinsert(UISpecialFrames, "OneWoW_BagsMainWindow")
    end
    isInitialized = true

    local d = OneWoW_Bags.db
    if d and d.global then
        d.global.mainFramePosition = d.global.mainFramePosition or {}
        if not OneWoW_GUI:RestoreWindowPosition(MainWindow, d.global.mainFramePosition) then
            MainWindow:SetPoint("CENTER")
        end
    else
        MainWindow:SetPoint("CENTER")
    end
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
    if not db or not db.global then return end
    local cols = db.global.bagColumns or 15
    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local scrollbarSpace = db.global.hideScrollBar and 0 or 12
    local newWidth = cols * (iconSize + spacing) - spacing + 4 + scrollbarSpace + (2 * S("XS"))
    MainWindow:SetWidth(newWidth)
    MainWindow:SetResizeBounds(newWidth, 300, newWidth, 1200)
end

function GUI:RefreshLayout()
    if not isInitialized or not MainWindow then return end
    if not MainWindow:IsShown() then return end

    local BagSet = OneWoW_Bags.BagSet
    if not BagSet or not BagSet.isBuilt then return end

    GUI:UpdateWindowWidth()

    if contentFrame and BagSet.bagContainerFrames then
        for _, bagFrame in pairs(BagSet.bagContainerFrames) do
            bagFrame:SetParent(contentFrame)
        end
    end

    GUI:CleanupAllViews()

    local allButtons = BagSet:GetAllButtons()

    local searchText = OneWoW_Bags.InfoBar:GetSearchText()
    local filteredButtons = {}

    if searchText and searchText ~= "" then
        local searchLower = string.lower(searchText)
        for _, button in ipairs(allButtons) do
            if button.owb_hasItem and button.owb_itemInfo and button.owb_itemInfo.itemID then
                local itemName = C_Item.GetItemNameByID(button.owb_itemInfo.itemID)
                if itemName then
                    local nameLower = string.lower(itemName)
                    if string.find(nameLower, searchLower, 1, true) then
                        table.insert(filteredButtons, button)
                    end
                end
            end
        end
    else
        for _, button in ipairs(allButtons) do
            table.insert(filteredButtons, button)
        end
    end

    local viewMode = OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.viewMode or "list"

    local db = OneWoW_Bags.db
    local cols = db and db.global.bagColumns or 15
    local iconSize = Constants.ICON_SIZES[(db and db.global.iconSize) or 3] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local contentWidth = cols * (iconSize + spacing) - spacing + 4

    local layoutHeight = 100

    if viewMode == "list" then
        layoutHeight = OneWoW_Bags.ListView:Layout(contentFrame, filteredButtons, contentWidth)
    elseif viewMode == "category" then
        layoutHeight = OneWoW_Bags.CategoryView:Layout(contentFrame, contentWidth, filteredButtons)
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
        local ok, err = pcall(function() GUI:InitMainWindow() end)
        if not ok then return end
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

    MainWindow:SetBackdropColor(T("BG_PRIMARY"))
    MainWindow:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    if titleBar then
        titleBar:SetBackdropColor(T("TITLEBAR_BG"))
    end

    if MainWindow.brandText then
        MainWindow.brandText:SetTextColor(T("ACCENT_PRIMARY"))
    end

    if MainWindow.titleText then
        MainWindow.titleText:SetTextColor(T("TEXT_PRIMARY"))
    end

    local infoBarFrame = OneWoW_Bags.InfoBar:GetFrame()
    if infoBarFrame then
        infoBarFrame:SetBackdropColor(T("BG_TERTIARY"))
        infoBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end

    local bagsBarFrame = OneWoW_Bags.BagsBar:GetFrame()
    if bagsBarFrame then
        bagsBarFrame:SetBackdropColor(T("BG_TERTIARY"))
        bagsBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end

    if contentScrollFrame and contentScrollFrame.ScrollBar then
        local scrollBar = contentScrollFrame.ScrollBar
        if scrollBar.Background then
            scrollBar.Background:SetColorTexture(T("BG_TERTIARY"))
        end
        if scrollBar.ThumbTexture then
            scrollBar.ThumbTexture:SetColorTexture(T("ACCENT_PRIMARY"))
        end
    end

    OneWoW_Bags.InfoBar:UpdateViewButtons()

    self:RefreshLayout()
end

function GUI:GetMainWindow()
    return MainWindow
end

function GUI:UpdateBagsBarVisibility()
    if not isInitialized or not MainWindow then return end

    local db = OneWoW_Bags.db
    local showBags = db and db.global and db.global.showBagsBar
    local showMoney = db and db.global and db.global.showMoneyBar
    if showBags == nil then showBags = true end
    if showMoney == nil then showMoney = true end

    local showAnyBar = showBags or showMoney
    OneWoW_Bags.BagsBar:SetShown(showAnyBar)
    if OneWoW_Bags.BagsBar.UpdateRowVisibility then
        OneWoW_Bags.BagsBar:UpdateRowVisibility()
    end

    if OneWoW_Bags.InfoBar and OneWoW_Bags.InfoBar.UpdateVisibility then
        OneWoW_Bags.InfoBar:UpdateVisibility()
    end

    local bagsBarFrame = OneWoW_Bags.BagsBar:GetFrame()
    local infoBarFrame = OneWoW_Bags.InfoBar:GetFrame()
    if contentScrollFrame then
        local hideScrollBar = db and db.global and db.global.hideScrollBar
        local scrollbarOffset = hideScrollBar and 0 or -12
        contentScrollFrame:ClearAllPoints()
        if infoBarFrame and infoBarFrame:IsShown() then
            contentScrollFrame:SetPoint("TOPLEFT", infoBarFrame, "BOTTOMLEFT", 0, -2)
        else
            contentScrollFrame:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 0, 0)
        end
        if showAnyBar and bagsBarFrame and bagsBarFrame:IsShown() then
            contentScrollFrame:SetPoint("BOTTOMRIGHT", bagsBarFrame, "TOPRIGHT", scrollbarOffset, 2)
        else
            contentScrollFrame:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", scrollbarOffset, 0)
        end
    end

    self:RefreshLayout()
end
