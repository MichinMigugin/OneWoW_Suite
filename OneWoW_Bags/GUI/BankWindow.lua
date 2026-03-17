local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BankGUI = OneWoW_Bags.BankGUI or {}
local BankGUI = OneWoW_Bags.BankGUI
local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local OneWoW_GUI = OneWoW_Bags.GUILib

local BankWindow = nil
local isInitialized = false
local contentScrollFrame = nil
local contentFrame = nil
local titleBar = nil
local contentArea = nil
local needsCleanupAfterCombat = false

local function T(key)
    return OneWoW_GUI:GetThemeColor(key)
end

local function S(key)
    return OneWoW_GUI:GetSpacing(key)
end

function BankGUI:InitBankWindow()
    if isInitialized then return end
    if not Constants or not Constants.GUI then return end

    local C = Constants.GUI
    local db = OneWoW_Bags.db
    local savedHeight = db and db.global and db.global.bankWindowHeight
    local windowHeight = savedHeight or C.WINDOW_HEIGHT
    local savedWidth = db and db.global and db.global.bankWindowWidth
    local windowWidth = savedWidth or C.WINDOW_WIDTH

    BankWindow = CreateFrame("Frame", "OneWoW_BankMainWindow", UIParent, "BackdropTemplate")
    BankWindow:SetSize(windowWidth, windowHeight)
    BankWindow:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SOFT)

    if not BankWindow then return end

    BankWindow:SetBackdropColor(T("BG_PRIMARY"))
    BankWindow:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    BankWindow:SetPoint("CENTER")
    BankWindow:SetMovable(true)
    BankWindow:SetResizable(true)
    BankWindow:SetResizeBounds(300, 300, 1400, 1200)
    BankWindow:EnableMouse(true)
    BankWindow:RegisterForDrag("LeftButton")
    BankWindow:SetScript("OnDragStart", BankWindow.StartMoving)
    BankWindow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if db and db.global then
            local point, _, relPoint, x, y = self:GetPoint()
            db.global.bankWindowPosition = {
                point = point,
                relPoint = relPoint,
                x = x,
                y = y,
            }
        end
    end)
    BankWindow:SetClampedToScreen(true)
    BankWindow:SetFrameStrata("MEDIUM")
    BankWindow:SetToplevel(true)
    BankWindow._ready = false
    BankWindow:SetScript("OnHide", function()
        if not BankWindow._ready then return end
        BankGUI:CleanupAllViews()
        if OneWoW_Bags.bankOpen then
            OneWoW_Bags.bankOpen = false
            if OneWoW_Bags.BankSet then
                OneWoW_Bags.BankSet:ReleaseAll()
            end
            C_Bank.CloseBankFrame()
        end
    end)
    BankWindow:Hide()

    local titleText = L["BANK_TITLE"]
    if db and db.global and db.global.bankShowWarband then
        titleText = L["BANK_WARBAND_TITLE"]
    end

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
    titleBar = OneWoW_GUI:CreateTitleBar(BankWindow, {
        title = titleText,
        height = C.TITLEBAR_HEIGHT,
        showBrand = true,
        factionTheme = factionTheme,
        onClose = function() BankWindow:Hide() end,
    })

    local settingsBtn = OneWoW_GUI:CreateButton(titleBar, { text = "S", width = 20, height = 20 })
    settingsBtn:SetPoint("RIGHT", titleBar._closeBtn, "LEFT", -2, 0)
    settingsBtn:SetScript("OnClick", function()
        if OneWoW_Bags.Settings and OneWoW_Bags.Settings.Toggle then
            OneWoW_Bags.Settings:Toggle()
        end
    end)

    contentArea = CreateFrame("Frame", nil, BankWindow)
    contentArea:SetPoint("TOPLEFT", BankWindow, "TOPLEFT", S("XS"), -(S("XS") + C.TITLEBAR_HEIGHT + S("XS")))
    contentArea:SetPoint("BOTTOMRIGHT", BankWindow, "BOTTOMRIGHT", -S("XS"), S("XS"))
    BankWindow.contentArea = contentArea

    local infoBar = OneWoW_Bags.BankInfoBar:Create(contentArea)
    local bagsBar = OneWoW_Bags.BankBagsBar:Create(contentArea)

    local scrollName = "OneWoW_BankContentScroll"
    contentScrollFrame = CreateFrame("ScrollFrame", scrollName, contentArea, "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", infoBar, "BOTTOMLEFT", 0, -2)
    local hideScroll = db and db.global and db.global.hideScrollBar
    local scrollRightOffset = hideScroll and 0 or -16
    contentScrollFrame:SetPoint("BOTTOMRIGHT", bagsBar, "TOPRIGHT", scrollRightOffset, 2)

    OneWoW_GUI:StyleScrollBar(contentScrollFrame, { container = contentArea, offset = 0 })
    if hideScroll and contentScrollFrame.ScrollBar then
        contentScrollFrame.ScrollBar:SetAlpha(0)
        contentScrollFrame.ScrollBar:EnableMouse(false)
    end

    contentFrame = CreateFrame("Frame", scrollName .. "Content", contentScrollFrame)
    contentFrame:SetHeight(1)
    contentScrollFrame:SetScrollChild(contentFrame)

    C_Timer.After(0, function()
        if contentScrollFrame then
            contentFrame:SetWidth(contentScrollFrame:GetWidth())
        end
    end)

    local resizeBtn = CreateFrame("Button", nil, BankWindow)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", BankWindow, "BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetFrameLevel(BankWindow:GetFrameLevel() + 10)
    resizeBtn:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            BankWindow:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeBtn:SetScript("OnMouseUp", function(self)
        BankWindow:StopMovingOrSizing()
        if db and db.global then
            db.global.bankWindowHeight = BankWindow:GetHeight()
            db.global.bankWindowWidth = BankWindow:GetWidth()
        end
        if contentScrollFrame and contentFrame then
            contentFrame:SetWidth(contentScrollFrame:GetWidth())
        end
        if BankGUI.RefreshLayout then BankGUI:RefreshLayout() end
    end)

    tinsert(UISpecialFrames, "OneWoW_BankMainWindow")
    isInitialized = true

    if db and db.global and db.global.bankWindowPosition then
        local pos = db.global.bankWindowPosition
        BankWindow:ClearAllPoints()
        BankWindow:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
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
    if needsCleanupAfterCombat and BankWindow and not BankWindow:IsShown() then
        BankGUI:CleanupAllViews()
    end
end)

function BankGUI:RefreshLayout()
    if not isInitialized or not BankWindow then return end
    if not BankWindow:IsShown() then return end

    local BankSet = OneWoW_Bags.BankSet
    if not BankSet or not BankSet.isBuilt then return end

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

    local viewMode = OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.bankViewMode or "tabs"

    local contentWidth = contentFrame:GetWidth()
    if contentWidth < 10 then
        contentWidth = Constants.GUI.WINDOW_WIDTH - 40
    end

    local layoutHeight = 100

    if viewMode == "tabs" then
        layoutHeight = OneWoW_Bags.BankTabView:Layout(contentFrame, contentWidth, filteredButtons)
    elseif viewMode == "list" then
        layoutHeight = OneWoW_Bags.BankListView:Layout(contentFrame, filteredButtons, contentWidth)
    end

    contentFrame:SetHeight(layoutHeight)

    local freeSlots = BankSet:GetFreeSlotCount()
    local totalSlots = BankSet:GetSlotCount()
    OneWoW_Bags.BankBagsBar:UpdateFreeSlots(freeSlots, totalSlots)
    OneWoW_Bags.BankBagsBar:UpdateGold()
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

    if OneWoW_Bags.BankBagsBar then
        OneWoW_Bags.BankBagsBar:BuildTabButtons()
        OneWoW_Bags.BankBagsBar:UpdateTabHighlights()
    end

    BankGUI:UpdateTitle()

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

function BankGUI:UpdateTitle()
    if not titleBar then return end
    local db = OneWoW_Bags.db
    local showWarband = db and db.global and db.global.bankShowWarband
    local titleText = showWarband and L["BANK_WARBAND_TITLE"] or L["BANK_TITLE"]

    if titleBar._titleText then
        titleBar._titleText:SetText(titleText)
    elseif titleBar.title then
        titleBar.title:SetText(titleText)
    end
end

function BankGUI:Show()
    if not isInitialized then
        local ok, err = pcall(function() BankGUI:InitBankWindow() end)
        if not ok then return end
    end

    if not BankWindow then return end

    BankWindow._ready = true
    BankWindow:Show()

    local BankSet = OneWoW_Bags.BankSet
    if BankSet then
        if not BankSet.isBuilt then
            BankSet:Build()
        end
    end

    if OneWoW_Bags.BankBagsBar then
        OneWoW_Bags.BankBagsBar:BuildTabButtons()
        OneWoW_Bags.BankBagsBar:UpdateTabHighlights()
        OneWoW_Bags.BankBagsBar:UpdateWarbandButton()
    end

    C_Timer.After(0, function()
        if not BankWindow or not BankWindow:IsShown() then return end
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
    if BankWindow then
        BankWindow:Hide()
    end
end

function BankGUI:Toggle()
    if BankWindow and BankWindow:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function BankGUI:IsShown()
    return BankWindow and BankWindow:IsShown()
end

function BankGUI:FullReset()
    if OneWoW_Bags.BankSet then
        OneWoW_Bags.BankSet:ReleaseAll()
    end

    if OneWoW_Bags.BankInfoBar and OneWoW_Bags.BankInfoBar.Reset then
        OneWoW_Bags.BankInfoBar:Reset()
    end

    if OneWoW_Bags.BankBagsBar and OneWoW_Bags.BankBagsBar.Reset then
        OneWoW_Bags.BankBagsBar:Reset()
    end

    if BankWindow then
        BankWindow:Hide()
        BankWindow = nil
    end

    titleBar = nil
    contentArea = nil
    contentScrollFrame = nil
    contentFrame = nil
    isInitialized = false
end

function BankGUI:ApplyTheme()
    if not BankWindow then return end

    BankWindow:SetBackdropColor(T("BG_PRIMARY"))
    BankWindow:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    if titleBar then
        titleBar:SetBackdropColor(T("TITLEBAR_BG"))
    end

    local infoBarFrame = OneWoW_Bags.BankInfoBar:GetFrame()
    if infoBarFrame then
        infoBarFrame:SetBackdropColor(T("BG_TERTIARY"))
        infoBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end

    local bagsBarFrame = OneWoW_Bags.BankBagsBar:GetFrame()
    if bagsBarFrame then
        bagsBarFrame:SetBackdropColor(T("BG_TERTIARY"))
        bagsBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end

    OneWoW_Bags.BankInfoBar:UpdateViewButtons()

    self:RefreshLayout()
end

function BankGUI:GetMainWindow()
    return BankWindow
end
