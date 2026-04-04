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
