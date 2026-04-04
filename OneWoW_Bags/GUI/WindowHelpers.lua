local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

local Constants = OneWoW_Bags.Constants
local PE = OneWoW_Bags.PredicateEngine

local tinsert = tinsert
local ipairs = ipairs

OneWoW_Bags.WindowHelpers = {}
local WH = OneWoW_Bags.WindowHelpers

function WH:CreateWindowShell(config)
    local db = OneWoW_Bags:GetDB()
    local position = DB:Ensure(db, "global", config.positionDBKey)
    local windowHeight = position.height or config.defaultHeight or Constants.GUI.WINDOW_HEIGHT

    local mainWindow = OneWoW_GUI:CreateFrame(UIParent, {
        name = config.name,
        width = config.width or Constants.GUI.WINDOW_WIDTH,
        height = windowHeight,
        backdrop = config.backdrop or OneWoW_GUI.Constants.BACKDROP_SOFT,
    })

    if not mainWindow then return nil end

    mainWindow:SetMovable(true)
    mainWindow:SetResizable(true)
    mainWindow:SetResizeBounds(config.minWidth or Constants.GUI.WINDOW_WIDTH, config.minHeight or 300, config.maxWidth or Constants.GUI.WINDOW_WIDTH, config.maxHeight or 1200)
    mainWindow:EnableMouse(true)
    mainWindow:RegisterForDrag("LeftButton")
    mainWindow:SetScript("OnDragStart", mainWindow.StartMoving)
    mainWindow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        OneWoW_GUI:SaveWindowPosition(self, position)
    end)
    mainWindow:SetClampedToScreen(true)
    mainWindow:SetClampRectInsets(0, 0, 0, 0)
    mainWindow:SetFrameStrata(config.frameStrata or "MEDIUM")
    mainWindow:SetToplevel(true)
    mainWindow:SetScript("OnHide", config.onHide)
    mainWindow:Hide()

    self:RegisterSpecialFrame(config.name, mainWindow)
    self:SaveAndRestorePosition(mainWindow, config.positionDBKey)

    return mainWindow
end

function WH:CreateWindowTitleBar(mainWindow, config)
    local titleBar = OneWoW_GUI:CreateTitleBar(mainWindow, {
        title = config.title,
        height = config.height or Constants.GUI.TITLEBAR_HEIGHT,
        showBrand = config.showBrand ~= false,
        factionTheme = config.factionTheme,
        onClose = config.onClose,
    })

    local settingsBtn = nil
    if config.settingsText and config.onSettings then
        settingsBtn = OneWoW_GUI:CreateFitTextButton(titleBar, {
            text = config.settingsText,
            height = 20,
            minWidth = 30,
        })
        if settingsBtn then
            if titleBar and titleBar._closeBtn then
                settingsBtn:SetPoint("RIGHT", titleBar._closeBtn, "LEFT", -2, 0)
            elseif titleBar then
                settingsBtn:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0)
            end
            settingsBtn:SetScript("OnClick", config.onSettings)
        end
    end

    return titleBar, settingsBtn
end

function WH:CreateContentArea(mainWindow)
    local spacing = OneWoW_GUI:GetSpacing("XS")
    local contentArea = CreateFrame("Frame", nil, mainWindow)
    contentArea:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", spacing, -(spacing + Constants.GUI.TITLEBAR_HEIGHT + spacing))
    contentArea:SetPoint("BOTTOMRIGHT", mainWindow, "BOTTOMRIGHT", -spacing, spacing)
    mainWindow.contentArea = contentArea
    return contentArea
end

function WH:CreateScrollScaffold(config)
    local scrollbarOffset = config.hideScrollBar and 0 or -12
    local scrollFrame = CreateFrame("ScrollFrame", config.scrollName, config.contentArea, "UIPanelScrollFrameTemplate")
    if config.topAnchor and config.topAnchor:IsShown() then
        scrollFrame:SetPoint("TOPLEFT", config.topAnchor, "BOTTOMLEFT", 0, -2)
    else
        scrollFrame:SetPoint("TOPLEFT", config.contentArea, "TOPLEFT", 0, 0)
    end
    if config.bottomAnchor and config.bottomAnchor:IsShown() then
        scrollFrame:SetPoint("BOTTOMRIGHT", config.bottomAnchor, "TOPRIGHT", scrollbarOffset, 2)
    else
        scrollFrame:SetPoint("BOTTOMRIGHT", config.contentArea, "BOTTOMRIGHT", scrollbarOffset, 0)
    end

    OneWoW_GUI:StyleScrollBar(scrollFrame, { container = config.contentArea, offset = 0 })
    if config.hideScrollBar and scrollFrame.ScrollBar then
        scrollFrame.ScrollBar:Hide()
    end

    local contentFrame = CreateFrame("Frame", config.scrollName .. "Content", scrollFrame)
    contentFrame:SetHeight(1)
    scrollFrame:SetScrollChild(contentFrame)
    scrollFrame:HookScript("OnSizeChanged", function(self, width)
        contentFrame:SetWidth(width)
    end)

    return scrollFrame, contentFrame
end

function WH:QueueContentRefresh(scrollFrame, contentFrame, refreshCallback)
    C_Timer.After(0, function()
        if scrollFrame and contentFrame then
            local width = scrollFrame:GetWidth()
            if width and width > 10 then
                contentFrame:SetWidth(width)
            end
        end
        if refreshCallback then
            refreshCallback()
        end
    end)
end

function WH:RegisterDeferredCleanup(config)
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function()
        if config.shouldCleanup and config.shouldCleanup() and config.cleanup then
            config.cleanup()
        end
    end)
    return eventFrame
end

function WH:FilterBySearch(buttons, searchText)
    if not searchText or searchText == "" then
        return buttons
    end

    local filtered = {}
    for _, button in ipairs(buttons) do
        if button.owb_hasItem and button.owb_itemInfo and button.owb_itemInfo.itemID then
            if PE:CheckItem(searchText, button.owb_itemInfo.itemID, button.owb_bagID, button.owb_slotID, button.owb_itemInfo) then
                tinsert(filtered, button)
            end
        end
    end

    return filtered
end

function WH:FilterByExpansion(buttons, expacFilter)
    if expacFilter == nil then
        return buttons
    end

    local filtered = {}
    for _, button in ipairs(buttons) do
        if button.owb_hasItem and button.owb_itemInfo and button.owb_itemInfo.itemID then
            local props = PE:BuildProps(button.owb_itemInfo.itemID, button.owb_bagID, button.owb_slotID, button.owb_itemInfo)
            if props.expansionID == expacFilter then
                tinsert(filtered, button)
            end
        end
    end
    return filtered
end

function WH:FilterByTab(buttons, selectedTab)
    if not selectedTab then return buttons end

    local filtered = {}
    for _, btn in ipairs(buttons) do
        if btn.owb_bagID == selectedTab then
            tinsert(filtered, btn)
        end
    end
    return filtered
end

function WH:GetLayoutMetrics(columnsDBKey, defaultCols)
    local db = OneWoW_Bags:GetDB()
    local cols = db.global[columnsDBKey] or defaultCols
    local iconSize = Constants.ICON_SIZES[db.global.iconSize or 3] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local contentWidth = cols * (iconSize + spacing) - spacing + 4
    return cols, iconSize, spacing, contentWidth
end

function WH:SetupResizeButton(mainWindow, gui, positionDBKey)
    local resizeBtn = CreateFrame("Button", nil, mainWindow)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", mainWindow, "BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetFrameLevel(mainWindow:GetFrameLevel() + 10)
    resizeBtn:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            mainWindow:StartSizing("BOTTOM")
        end
    end)
    resizeBtn:SetScript("OnMouseUp", function(self)
        local db = OneWoW_Bags:GetDB()
        mainWindow:StopMovingOrSizing()
        local pos = DB:Ensure(db, "global", positionDBKey)
        OneWoW_GUI:SaveWindowPosition(mainWindow, pos)
        gui:RefreshLayout()
    end)
    return resizeBtn
end

function WH:RegisterSpecialFrame(globalName, mainWindow)
    _G[globalName] = mainWindow
    local alreadyRegistered = false
    for _, name in ipairs(UISpecialFrames) do
        if name == globalName then alreadyRegistered = true; break end
    end
    if not alreadyRegistered then
        tinsert(UISpecialFrames, globalName)
    end
end

function WH:SaveAndRestorePosition(mainWindow, positionDBKey)
    local db = OneWoW_Bags:GetDB()
    local pos = DB:Ensure(db, "global", positionDBKey)
    if not OneWoW_GUI:RestoreWindowPosition(mainWindow, pos) then
        mainWindow:SetPoint("CENTER")
    end
end

function WH:ApplyBaseTheme(mainWindow, titleBar, infoBarRef, bottomBarRef)
    if not mainWindow then return end

    mainWindow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    mainWindow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    if titleBar then
        titleBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("TITLEBAR_BG"))
    end

    if infoBarRef then
        local f = infoBarRef:GetFrame()
        if f then
            f:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            f:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end
    end

    if bottomBarRef then
        local f = bottomBarRef:GetFrame()
        if f then
            f:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            f:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end
    end
end
