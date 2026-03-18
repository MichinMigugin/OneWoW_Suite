local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BankGUI = OneWoW_Bags.BankGUI or {}
local BankGUI = OneWoW_Bags.BankGUI
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
local needsCleanupAfterCombat = false

function BankGUI:InitMainWindow()
    if isInitialized then return end
    if not Constants or not Constants.GUI then return end

    local C = Constants.GUI
    local db = OneWoW_Bags.db
    local savedHeight = db and db.global and db.global.bankFramePosition and db.global.bankFramePosition.height
    local windowHeight = savedHeight or C.WINDOW_HEIGHT

    MainWindow = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_BankMainWindow",
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
            d.global.bankFramePosition = d.global.bankFramePosition or {}
            OneWoW_GUI:SaveWindowPosition(self, d.global.bankFramePosition)
        end
    end)
    MainWindow:SetClampedToScreen(true)
    MainWindow:SetFrameStrata("MEDIUM")
    MainWindow:SetToplevel(true)
    MainWindow:SetScript("OnHide", function()
        BankGUI:CleanupAllViews()
        local d = OneWoW_Bags.db
        if d and d.global then
            d.global.bankFramePosition = d.global.bankFramePosition or {}
            OneWoW_GUI:SaveWindowPosition(MainWindow, d.global.bankFramePosition)
        end
    end)
    MainWindow:Hide()

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
    titleBar = OneWoW_GUI:CreateTitleBar(MainWindow, {
        title = L["BANK_TITLE"] or "Bank",
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
    contentArea:SetPoint("TOPLEFT", MainWindow, "TOPLEFT", S("XS"), -(S("XS") + C.TITLEBAR_HEIGHT + S("XS")))
    contentArea:SetPoint("BOTTOMRIGHT", MainWindow, "BOTTOMRIGHT", -S("XS"), S("XS"))
    MainWindow.contentArea = contentArea

    local infoBar = OneWoW_Bags.BankInfoBar:Create(contentArea)
    local bankBar = OneWoW_Bags.BankBar:Create(contentArea)
    OneWoW_Bags.BankBar:SetShown(true)

    local hideScrollBar = OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.hideScrollBar
    local scrollbarOffset = hideScrollBar and 0 or -12

    local scrollName = "OneWoW_BankContentScroll"
    contentScrollFrame = CreateFrame("ScrollFrame", scrollName, contentArea, "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", infoBar, "BOTTOMLEFT", 0, -2)
    contentScrollFrame:SetPoint("BOTTOMRIGHT", bankBar, "TOPRIGHT", scrollbarOffset, 2)

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
            d.global.bankFramePosition = d.global.bankFramePosition or {}
            OneWoW_GUI:SaveWindowPosition(MainWindow, d.global.bankFramePosition)
        end
        if BankGUI.RefreshLayout then BankGUI:RefreshLayout() end
    end)

    tinsert(UISpecialFrames, "OneWoW_BankMainWindow")
    isInitialized = true

    local d = OneWoW_Bags.db
    if d and d.global then
        d.global.bankFramePosition = d.global.bankFramePosition or {}
        if not OneWoW_GUI:RestoreWindowPosition(MainWindow, d.global.bankFramePosition) then
            MainWindow:SetPoint("CENTER")
        end
    else
        MainWindow:SetPoint("CENTER")
    end
end

function BankGUI:CleanupAllViews()
    if InCombatLockdown() then
        needsCleanupAfterCombat = true
        return
    end
    needsCleanupAfterCombat = false
    local BankSet = OneWoW_Bags.BankSet
    if BankSet and BankSet.isBuilt then
        local allButtons = BankSet:GetAllButtons()
        for _, button in ipairs(allButtons) do
            button:Hide()
            button:ClearAllPoints()
        end
    end

    if OneWoW_Bags.BankCategoryManager then
        OneWoW_Bags.BankCategoryManager:ReleaseAllSections()
    end
end

local cleanupEventFrame = CreateFrame("Frame")
cleanupEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
cleanupEventFrame:SetScript("OnEvent", function()
    if needsCleanupAfterCombat and MainWindow and not MainWindow:IsShown() then
        BankGUI:CleanupAllViews()
    end
end)

function BankGUI:UpdateWindowWidth()
    if not MainWindow then return end
    local db = OneWoW_Bags.db
    if not db or not db.global then return end
    local cols = db.global.bankColumns or 14
    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local scrollbarSpace = db.global.hideScrollBar and 0 or 12
    local newWidth = cols * (iconSize + spacing) - spacing + 4 + scrollbarSpace + (2 * S("XS"))
    MainWindow:SetWidth(newWidth)
    MainWindow:SetResizeBounds(newWidth, 300, newWidth, 1200)
end

function BankGUI:RefreshLayout()
    if not isInitialized or not MainWindow then return end
    if not MainWindow:IsShown() then return end

    local BankSet = OneWoW_Bags.BankSet
    if not BankSet or not BankSet.isBuilt then return end

    BankGUI:UpdateWindowWidth()

    if contentFrame and BankSet.bagContainerFrames then
        for _, bagFrame in pairs(BankSet.bagContainerFrames) do
            bagFrame:SetParent(contentFrame)
        end
    end

    BankGUI:CleanupAllViews()

    local allButtons = BankSet:GetAllButtons()
    local searchText = OneWoW_Bags.BankInfoBar:GetSearchText()
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

    local viewMode = OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.bankViewMode or "list"

    local db = OneWoW_Bags.db
    local cols = db and db.global.bankColumns or 14
    local iconSize = Constants.ICON_SIZES[(db and db.global.iconSize) or 3] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local contentWidth = cols * (iconSize + spacing) - spacing + 4

    local layoutHeight = 100

    if viewMode == "tab" then
        layoutHeight = OneWoW_Bags.BankTabView:Layout(contentFrame, contentWidth, filteredButtons)
    else
        layoutHeight = OneWoW_Bags.ListView:Layout(contentFrame, filteredButtons, contentWidth)
    end

    contentFrame:SetHeight(layoutHeight)

    local freeSlots = BankSet:GetFreeSlotCount()
    local totalSlots = BankSet:GetSlotCount()
    OneWoW_Bags.BankBar:UpdateFreeSlots(freeSlots, totalSlots)
end

function BankGUI:OnSearchChanged(text)
    self:RefreshLayout()
end

function BankGUI:OnBankTypeChanged()
    local db = OneWoW_Bags.db
    db.global.bankSelectedTab = nil

    local showWarband = db.global.bankShowWarband

    local newBankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
    if BankFrame and BankFrame.BankPanel then
        BankFrame.BankPanel:SetBankType(newBankType)
    end

    local BankSet = OneWoW_Bags.BankSet
    if BankSet then
        BankSet:ReleaseAll()
        BankSet:Build()
    end

    if OneWoW_Bags.BankBar then
        OneWoW_Bags.BankBar:BuildTabButtons()
        OneWoW_Bags.BankBar:UpdateModeButtons()
    end

    C_Timer.After(0, function()
        if contentScrollFrame and contentFrame then
            local w = contentScrollFrame:GetWidth()
            if w and w > 10 then
                contentFrame:SetWidth(w)
            end
        end
        BankGUI:RefreshLayout()
    end)
end

function BankGUI:Show()
    if not isInitialized then
        local ok, err = pcall(function() BankGUI:InitMainWindow() end)
        if not ok then return end
    end

    if not MainWindow then return end

    MainWindow:Show()

    local BankSet = OneWoW_Bags.BankSet
    if BankSet and not BankSet.isBuilt then
        BankSet:Build()
    end

    if OneWoW_Bags.BankBar then
        OneWoW_Bags.BankBar:UpdateModeButtons()
        OneWoW_Bags.BankBar:BuildTabButtons()
        OneWoW_Bags.BankBar:UpdateGold()
    end

    C_Timer.After(0, function()
        if contentScrollFrame and contentFrame then
            local w = contentScrollFrame:GetWidth()
            if w and w > 10 then
                contentFrame:SetWidth(w)
            end
        end
        BankGUI:RefreshLayout()
    end)
end

function BankGUI:Hide()
    if MainWindow then
        MainWindow:Hide()
    end
end

function BankGUI:Toggle()
    if MainWindow and MainWindow:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function BankGUI:IsShown()
    return MainWindow and MainWindow:IsShown()
end

function BankGUI:FullReset()
    if OneWoW_Bags.BankSet then
        OneWoW_Bags.BankSet:ReleaseAll()
    end

    if OneWoW_Bags.BankInfoBar and OneWoW_Bags.BankInfoBar.Reset then
        OneWoW_Bags.BankInfoBar:Reset()
    end

    if OneWoW_Bags.BankBar and OneWoW_Bags.BankBar.Reset then
        OneWoW_Bags.BankBar:Reset()
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

function BankGUI:ApplyTheme()
    if not MainWindow then return end

    MainWindow:SetBackdropColor(T("BG_PRIMARY"))
    MainWindow:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    if titleBar then
        titleBar:SetBackdropColor(T("TITLEBAR_BG"))
    end

    local infoBarFrame = OneWoW_Bags.BankInfoBar:GetFrame()
    if infoBarFrame then
        infoBarFrame:SetBackdropColor(T("BG_TERTIARY"))
        infoBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end

    local bankBarFrame = OneWoW_Bags.BankBar:GetFrame()
    if bankBarFrame then
        bankBarFrame:SetBackdropColor(T("BG_TERTIARY"))
        bankBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end

    OneWoW_Bags.BankInfoBar:UpdateViewButtons()

    self:RefreshLayout()
end

function BankGUI:GetMainWindow()
    return MainWindow
end
