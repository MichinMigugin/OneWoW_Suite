local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_Bags.WindowHelpers = {}
local WH = OneWoW_Bags.WindowHelpers

function WH:FilterBySearch(buttons, searchText)
    if not searchText or searchText == "" then
        return buttons
    end

    local SE = OneWoW_Bags.SearchEngine
    local hasKeyword = searchText:find("#") or searchText:find("[&|!~()]")
    local filtered = {}

    if hasKeyword and SE then
        for _, button in ipairs(buttons) do
            if button.owb_hasItem and button.owb_itemInfo and button.owb_itemInfo.itemID then
                local enriched = SE:EnrichItemInfo(button.owb_itemInfo.itemID, button.owb_bagID, button.owb_slotID, button.owb_itemInfo)
                if SE:CheckItem(searchText, button.owb_itemInfo.itemID, button.owb_bagID, button.owb_slotID, enriched) then
                    tinsert(filtered, button)
                end
            end
        end
    else
        local searchLower = string.lower(searchText)
        for _, button in ipairs(buttons) do
            if button.owb_hasItem and button.owb_itemInfo and button.owb_itemInfo.itemID then
                local itemName = C_Item.GetItemNameByID(button.owb_itemInfo.itemID)
                if itemName and string.find(string.lower(itemName), searchLower, 1, true) then
                    tinsert(filtered, button)
                end
            end
        end
    end

    return filtered
end

function WH:FilterByExpansion(buttons, expacFilter)
    if expacFilter == nil then
        return buttons
    end

    local SE = OneWoW_Bags.SearchEngine
    local filtered = {}
    for _, button in ipairs(buttons) do
        if button.owb_hasItem and button.owb_itemInfo and button.owb_itemInfo.itemID then
            local enriched = button.owb_itemInfo._enriched and button.owb_itemInfo
                or SE:EnrichItemInfo(button.owb_itemInfo.itemID, button.owb_bagID, button.owb_slotID, button.owb_itemInfo)
            if enriched._expansionID == expacFilter then
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
    local db = OneWoW_Bags.db
    local Constants = OneWoW_Bags.Constants
    local cols = db and db.global[columnsDBKey] or defaultCols
    local iconSize = Constants.ICON_SIZES[(db and db.global.iconSize) or 3] or 37
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
        mainWindow:StopMovingOrSizing()
        local d = OneWoW_Bags.db
        if d and d.global then
            d.global[positionDBKey] = d.global[positionDBKey] or {}
            OneWoW_GUI:SaveWindowPosition(mainWindow, d.global[positionDBKey])
        end
        if gui.RefreshLayout then gui:RefreshLayout() end
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
    local d = OneWoW_Bags.db
    if d and d.global then
        d.global[positionDBKey] = d.global[positionDBKey] or {}
        if not OneWoW_GUI:RestoreWindowPosition(mainWindow, d.global[positionDBKey]) then
            mainWindow:SetPoint("CENTER")
        end
    else
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
