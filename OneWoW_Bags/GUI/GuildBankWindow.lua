local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.GuildBankGUI = OneWoW_Bags.GuildBankGUI or {}
local GBGUI = OneWoW_Bags.GuildBankGUI
local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local OneWoW_GUI = OneWoW_Bags.GUILib

local GBWindow = nil
local isInitialized = false
local contentScrollFrame = nil
local contentFrame = nil
local titleBar = nil
local contentArea = nil

local function T(key)
    if OneWoW_GUI then return OneWoW_GUI:GetThemeColor(key) end
    if Constants and Constants.THEME and Constants.THEME[key] then return unpack(Constants.THEME[key]) end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if OneWoW_GUI then return OneWoW_GUI:GetSpacing(key) end
    if Constants and Constants.SPACING then return Constants.SPACING[key] or 8 end
    return 8
end

function GBGUI:InitWindow()
    if isInitialized then return end
    if not Constants or not Constants.GUI then return end

    local C = Constants.GUI
    local db = OneWoW_Bags.db
    local savedHeight = db and db.global and db.global.guildBankWindowHeight
    local windowHeight = savedHeight or C.WINDOW_HEIGHT

    if OneWoW_GUI then
        GBWindow = CreateFrame("Frame", "OneWoW_GuildBankMainWindow", UIParent, "BackdropTemplate")
        GBWindow:SetSize(C.WINDOW_WIDTH, windowHeight)
        GBWindow:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SOFT)
    else
        GBWindow = CreateFrame("Frame", "OneWoW_GuildBankMainWindow", UIParent, "BackdropTemplate")
        GBWindow:SetSize(C.WINDOW_WIDTH, windowHeight)
        GBWindow:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileEdge = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
    end

    if not GBWindow then return end

    GBWindow:SetBackdropColor(T("BG_PRIMARY"))
    GBWindow:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    GBWindow:SetPoint("CENTER")
    GBWindow:SetMovable(true)
    GBWindow:SetResizable(true)
    GBWindow:SetResizeBounds(C.WINDOW_WIDTH, 300, C.WINDOW_WIDTH, 1200)
    GBWindow:EnableMouse(true)
    GBWindow:RegisterForDrag("LeftButton")
    GBWindow:SetScript("OnDragStart", GBWindow.StartMoving)
    GBWindow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if db and db.global then
            local point, _, relPoint, x, y = self:GetPoint()
            db.global.guildBankWindowPosition = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    GBWindow:SetClampedToScreen(true)
    GBWindow:SetFrameStrata("MEDIUM")
    GBWindow:SetToplevel(true)

    GBWindow._ready = false
    GBWindow:SetScript("OnHide", function()
        if not GBWindow._ready then return end
        GBGUI:CleanupAllViews()
        if OneWoW_Bags.guildBankOpen then
            OneWoW_Bags.guildBankOpen = false
            if OneWoW_Bags.GuildBankSet then
                OneWoW_Bags.GuildBankSet:ReleaseAll()
            end
            CloseGuildBankFrame()
        end
    end)
    GBWindow:Hide()

    local guildName = GetGuildInfo("player") or L["GUILD_BANK_TITLE"]

    if OneWoW_GUI then
        local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
        titleBar = OneWoW_GUI:CreateTitleBar(GBWindow, {
            title = guildName,
            height = C.TITLEBAR_HEIGHT,
            showBrand = true,
            factionTheme = factionTheme,
            onClose = function() GBWindow:Hide() end,
        })
    else
        titleBar = CreateFrame("Frame", nil, GBWindow, "BackdropTemplate")
        titleBar:SetHeight(C.TITLEBAR_HEIGHT)
        titleBar:SetPoint("TOPLEFT", GBWindow, "TOPLEFT", S("XS"), -S("XS"))
        titleBar:SetPoint("TOPRIGHT", GBWindow, "TOPRIGHT", -S("XS"), -S("XS"))
        titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        titleBar:SetBackdropColor(T("TITLEBAR_BG"))
        titleBar:SetFrameLevel(GBWindow:GetFrameLevel() + 1)

        local titleFS = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleFS:SetPoint("CENTER")
        titleFS:SetText(guildName)
        titleFS:SetTextColor(T("TEXT_PRIMARY"))
        titleBar._titleText = titleFS

        local closeBtn = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
        closeBtn:SetSize(20, 20)
        closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -S("XS") / 2, 0)
        closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        closeBtn.text:SetPoint("CENTER")
        closeBtn.text:SetText("X")
        closeBtn:SetScript("OnClick", function() GBWindow:Hide() end)
    end

    contentArea = CreateFrame("Frame", nil, GBWindow)
    contentArea:SetPoint("TOPLEFT", GBWindow, "TOPLEFT", S("XS"), -(S("XS") + C.TITLEBAR_HEIGHT + S("XS")))
    contentArea:SetPoint("BOTTOMRIGHT", GBWindow, "BOTTOMRIGHT", -S("XS"), S("XS"))

    local infoBar = OneWoW_Bags.GuildBankInfoBar:Create(contentArea)
    local bagsBar = OneWoW_Bags.GuildBankBagsBar:Create(contentArea)

    local scrollName = "OneWoW_GuildBankContentScroll"
    contentScrollFrame = CreateFrame("ScrollFrame", scrollName, contentArea, "UIPanelScrollFrameTemplate")
    contentScrollFrame:SetPoint("TOPLEFT", infoBar, "BOTTOMLEFT", 0, -2)
    contentScrollFrame:SetPoint("BOTTOMRIGHT", bagsBar, "TOPRIGHT", -12, 2)

    if OneWoW_GUI then
        OneWoW_GUI:StyleScrollBar(contentScrollFrame, { container = contentArea, offset = 0 })
    end

    contentFrame = CreateFrame("Frame", scrollName .. "Content", contentScrollFrame)
    contentFrame:SetHeight(1)
    contentScrollFrame:SetScrollChild(contentFrame)

    C_Timer.After(0, function()
        if contentScrollFrame then contentFrame:SetWidth(contentScrollFrame:GetWidth()) end
    end)

    local resizeBtn = CreateFrame("Button", nil, GBWindow)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", GBWindow, "BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetFrameLevel(GBWindow:GetFrameLevel() + 10)
    resizeBtn:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then GBWindow:StartSizing("BOTTOM") end
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        GBWindow:StopMovingOrSizing()
        if db and db.global then db.global.guildBankWindowHeight = GBWindow:GetHeight() end
        GBGUI:RefreshLayout()
    end)

    tinsert(UISpecialFrames, "OneWoW_GuildBankMainWindow")
    isInitialized = true

    if db and db.global and db.global.guildBankWindowPosition then
        local pos = db.global.guildBankWindowPosition
        GBWindow:ClearAllPoints()
        GBWindow:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end
end

function GBGUI:CleanupAllViews()
    local GBSet = OneWoW_Bags.GuildBankSet
    if GBSet and GBSet.isBuilt then
        local allButtons = GBSet:GetAllButtons()
        for _, button in ipairs(allButtons) do
            button:Hide()
            button:ClearAllPoints()
        end
    end
    if OneWoW_Bags.GuildBankCategoryManager then
        OneWoW_Bags.GuildBankCategoryManager:ReleaseAllSections()
    end
end

function GBGUI:RefreshLayout()
    if not isInitialized or not GBWindow then return end
    if not GBWindow:IsShown() then return end

    local GBSet = OneWoW_Bags.GuildBankSet
    if not GBSet or not GBSet.isBuilt then return end

    if contentFrame then
        for tabID, tabSlots in pairs(GBSet.slots) do
            for slotID, button in pairs(tabSlots) do
                button:SetParent(contentFrame)
            end
        end
    end

    GBGUI:CleanupAllViews()

    local allButtons = GBSet:GetAllButtons()
    local searchText = OneWoW_Bags.GuildBankInfoBar:GetSearchText()
    local filteredButtons = {}

    if searchText and searchText ~= "" then
        local searchLower = string.lower(searchText)
        for _, button in ipairs(allButtons) do
            if button.owb_hasItem and button.owb_itemInfo and button.owb_itemInfo.itemID then
                local itemName = C_Item.GetItemNameByID(button.owb_itemInfo.itemID)
                if itemName and string.find(string.lower(itemName), searchLower, 1, true) then
                    table.insert(filteredButtons, button)
                end
            end
        end
    else
        for _, button in ipairs(allButtons) do
            table.insert(filteredButtons, button)
        end
    end

    local viewMode = OneWoW_Bags.db and OneWoW_Bags.db.global.guildBankViewMode or "tabs"
    local contentWidth = contentFrame:GetWidth()
    if contentWidth < 10 then contentWidth = Constants.GUI.WINDOW_WIDTH - 40 end

    local layoutHeight = 100
    if viewMode == "tabs" then
        layoutHeight = OneWoW_Bags.GuildBankTabView:Layout(contentFrame, contentWidth, filteredButtons)
    elseif viewMode == "list" then
        layoutHeight = OneWoW_Bags.GuildBankListView:Layout(contentFrame, filteredButtons, contentWidth)
    end

    contentFrame:SetHeight(layoutHeight)

    local freeSlots = GBSet:GetFreeSlotCount()
    local totalSlots = GBSet:GetSlotCount()
    OneWoW_Bags.GuildBankBagsBar:UpdateFreeSlots(freeSlots, totalSlots)
    OneWoW_Bags.GuildBankBagsBar:UpdateGold()
end

function GBGUI:OnSearchChanged(text) self:RefreshLayout() end

function GBGUI:Show()
    if not isInitialized then
        local ok, err = pcall(function() GBGUI:InitWindow() end)
        if not ok then return end
    end
    if not GBWindow then return end

    GBWindow._ready = true
    GBWindow:Show()

    local GBSet = OneWoW_Bags.GuildBankSet
    if GBSet and not GBSet.isBuilt then
        GBSet:Build()
    end

    if OneWoW_Bags.GuildBankBagsBar then
        OneWoW_Bags.GuildBankBagsBar:BuildTabButtons()
        OneWoW_Bags.GuildBankBagsBar:UpdateTabHighlights()
    end

    C_Timer.After(0, function()
        if not GBWindow or not GBWindow:IsShown() then return end
        if contentScrollFrame and contentFrame then
            local w = contentScrollFrame:GetWidth()
            if w and w > 10 then contentFrame:SetWidth(w) end
        end
        GBGUI:RefreshLayout()
    end)
end

function GBGUI:Hide()
    if GBWindow then GBWindow:Hide() end
end

function GBGUI:Toggle()
    if GBWindow and GBWindow:IsShown() then self:Hide() else self:Show() end
end

function GBGUI:IsShown() return GBWindow and GBWindow:IsShown() end

function GBGUI:FullReset()
    if OneWoW_Bags.GuildBankSet then OneWoW_Bags.GuildBankSet:ReleaseAll() end
    if OneWoW_Bags.GuildBankInfoBar and OneWoW_Bags.GuildBankInfoBar.Reset then OneWoW_Bags.GuildBankInfoBar:Reset() end
    if OneWoW_Bags.GuildBankBagsBar and OneWoW_Bags.GuildBankBagsBar.Reset then OneWoW_Bags.GuildBankBagsBar:Reset() end
    if GBWindow then GBWindow:Hide(); GBWindow = nil end
    titleBar = nil
    contentArea = nil
    contentScrollFrame = nil
    contentFrame = nil
    isInitialized = false
end

function GBGUI:GetMainWindow() return GBWindow end
