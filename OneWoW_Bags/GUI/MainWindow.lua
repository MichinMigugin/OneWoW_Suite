local ADDON_NAME, OneWoW_Bags = ...

local GUI = OneWoW_Bags.GUI
local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L

local MainWindow = nil
local isInitialized = false
local contentScrollFrame = nil
local contentFrame = nil
local titleBar = nil
local contentArea = nil
local settingsBtn = nil
local needsCleanupAfterCombat = false

local function T(key)
    if Constants and Constants.THEME and Constants.THEME[key] then
        return unpack(Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if Constants and Constants.SPACING then
        return Constants.SPACING[key] or 8
    end
    return 8
end

function GUI:InitMainWindow()
    if isInitialized then return end

    if not Constants or not Constants.GUI then return end

    local C = Constants.GUI

    local savedHeight = OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.windowHeight
    local windowHeight = savedHeight or C.WINDOW_HEIGHT

    MainWindow = GUI:CreateFrame("OneWoW_BagsMainWindow", UIParent, C.WINDOW_WIDTH, windowHeight, true)
    if not MainWindow then return end

    MainWindow:SetBackdropColor(T("BG_PRIMARY"))
    MainWindow:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    MainWindow:SetPoint("CENTER")
    MainWindow:SetMovable(true)
    MainWindow:SetResizable(true)
    MainWindow:SetResizeBounds(C.WINDOW_WIDTH, 300, C.WINDOW_WIDTH, 1200)
    MainWindow:EnableMouse(true)
    MainWindow:RegisterForDrag("LeftButton")
    MainWindow:SetScript("OnDragStart", MainWindow.StartMoving)
    MainWindow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if OneWoW_Bags.db and OneWoW_Bags.db.global then
            local point, _, relPoint, x, y = self:GetPoint()
            OneWoW_Bags.db.global.windowPosition = {
                point = point,
                relPoint = relPoint,
                x = x,
                y = y,
            }
        end
    end)
    MainWindow:SetClampedToScreen(true)
    MainWindow:SetFrameStrata("MEDIUM")
    MainWindow:SetToplevel(true)
    MainWindow:SetScript("OnHide", function()
        GUI:CleanupAllViews()
    end)
    MainWindow:Hide()

    titleBar = CreateFrame("Frame", nil, MainWindow, "BackdropTemplate")
    titleBar:SetHeight(C.TITLEBAR_HEIGHT)
    titleBar:SetPoint("TOPLEFT", MainWindow, "TOPLEFT", S("XS"), -S("XS"))
    titleBar:SetPoint("TOPRIGHT", MainWindow, "TOPRIGHT", -S("XS"), -S("XS"))
    titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    titleBar:SetBackdropColor(T("TITLEBAR_BG"))
    titleBar:SetFrameLevel(MainWindow:GetFrameLevel() + 1)

    local brandIcon = titleBar:CreateTexture(nil, "OVERLAY")
    brandIcon:SetSize(14, 14)
    brandIcon:SetPoint("LEFT", titleBar, "LEFT", S("SM"), 0)
    local factionTheme = OneWoW_Bags.db and OneWoW_Bags.db.global and
                         OneWoW_Bags.db.global.minimap and
                         OneWoW_Bags.db.global.minimap.theme or "horde"
    local brandIconTex
    if factionTheme == "alliance" then
        brandIconTex = "Interface\\AddOns\\OneWoW_Bags\\Media\\alliance-mini.png"
    elseif factionTheme == "neutral" then
        brandIconTex = "Interface\\AddOns\\OneWoW_Bags\\Media\\neutral-mini.png"
    else
        brandIconTex = "Interface\\AddOns\\OneWoW_Bags\\Media\\horde-mini.png"
    end
    brandIcon:SetTexture(brandIconTex)
    MainWindow.brandIcon = brandIcon

    local brandText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    brandText:SetPoint("LEFT", brandIcon, "RIGHT", 4, 0)
    brandText:SetText("OneWoW")
    brandText:SetTextColor(T("ACCENT_PRIMARY"))
    MainWindow.brandText = brandText

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    titleText:SetText(L["ADDON_TITLE"])
    titleText:SetTextColor(T("TEXT_PRIMARY"))
    MainWindow.titleText = titleText

    local closeBtn = GUI:CreateButton(nil, titleBar, "X", 20, 20)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -S("XS") / 2, 0)
    closeBtn:SetScript("OnClick", function() MainWindow:Hide() end)

    settingsBtn = GUI:CreateButton(nil, titleBar, "S", 20, 20)
    settingsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
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

    local scrollName = "OneWoW_BagsContentScroll"
    contentScrollFrame = CreateFrame("ScrollFrame", scrollName, contentArea, "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", infoBar, "BOTTOMLEFT", 0, -2)
    if showBagsBar then
        contentScrollFrame:SetPoint("BOTTOMRIGHT", bagsBar, "TOPRIGHT", -12, 2)
    else
        contentScrollFrame:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -12, 0)
    end

    local scrollBar = contentScrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", contentScrollFrame, "TOPRIGHT", 12, 0)
        scrollBar:SetPoint("BOTTOMRIGHT", contentScrollFrame, "BOTTOMRIGHT", 12, 0)
        scrollBar:SetWidth(10)

        if scrollBar.ScrollUpButton then
            scrollBar.ScrollUpButton:Hide()
            scrollBar.ScrollUpButton:SetAlpha(0)
            scrollBar.ScrollUpButton:EnableMouse(false)
        end
        if scrollBar.ScrollDownButton then
            scrollBar.ScrollDownButton:Hide()
            scrollBar.ScrollDownButton:SetAlpha(0)
            scrollBar.ScrollDownButton:EnableMouse(false)
        end

        if scrollBar.Background then
            scrollBar.Background:SetColorTexture(T("BG_TERTIARY"))
        end

        if scrollBar.ThumbTexture then
            scrollBar.ThumbTexture:SetWidth(8)
            scrollBar.ThumbTexture:SetColorTexture(T("ACCENT_PRIMARY"))
        end
    end

    contentFrame = CreateFrame("Frame", scrollName .. "Content", contentScrollFrame)
    contentFrame:SetHeight(1)
    contentScrollFrame:SetScrollChild(contentFrame)

    C_Timer.After(0, function()
        if contentScrollFrame then
            contentFrame:SetWidth(contentScrollFrame:GetWidth())
        end
    end)

    if OneWoW_Bags.Settings then
        OneWoW_Bags.Settings:Create()
    end

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
        if OneWoW_Bags.db and OneWoW_Bags.db.global then
            OneWoW_Bags.db.global.windowHeight = MainWindow:GetHeight()
        end
        if GUI.RefreshLayout then GUI:RefreshLayout() end
    end)

    tinsert(UISpecialFrames, "OneWoW_BagsMainWindow")
    isInitialized = true

    if OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.windowPosition then
        local pos = OneWoW_Bags.db.global.windowPosition
        MainWindow:ClearAllPoints()
        MainWindow:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
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

function GUI:RefreshLayout()
    if not isInitialized or not MainWindow then return end
    if not MainWindow:IsShown() then return end

    local BagSet = OneWoW_Bags.BagSet
    if not BagSet or not BagSet.isBuilt then return end

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

    local contentWidth = contentFrame:GetWidth()
    if contentWidth < 10 then
        contentWidth = Constants.GUI.WINDOW_WIDTH - 40
    end

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

    local showBagsBar = OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.showBagsBar
    if showBagsBar == nil then showBagsBar = true end

    OneWoW_Bags.BagsBar:SetShown(showBagsBar)

    local bagsBarFrame = OneWoW_Bags.BagsBar:GetFrame()
    if contentScrollFrame then
        contentScrollFrame:ClearAllPoints()
        local infoBarFrame = OneWoW_Bags.InfoBar:GetFrame()
        contentScrollFrame:SetPoint("TOPLEFT", infoBarFrame, "BOTTOMLEFT", 0, -2)
        if showBagsBar and bagsBarFrame then
            contentScrollFrame:SetPoint("BOTTOMRIGHT", bagsBarFrame, "TOPRIGHT", -12, 2)
        else
            contentScrollFrame:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -12, 0)
        end
    end

    self:RefreshLayout()
end
