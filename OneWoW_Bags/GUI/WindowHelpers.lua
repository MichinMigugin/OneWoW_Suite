local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

local Constants = OneWoW_Bags.Constants
local PE = OneWoW_Bags.PredicateEngine

local tinsert, sort = tinsert, sort
local ipairs, pairs = ipairs, pairs
local type = type
local floor = math.floor
local Enum = Enum
local PixelUtil = PixelUtil

OneWoW_Bags.WindowHelpers = {}
local WH = OneWoW_Bags.WindowHelpers

local ITEM_GRID_H_PADDING = 2
local SCROLLBAR_RESERVE_WIDTH = 12

function WH:GetItemGridChromeInsets(hideScrollbar)
    local gutter = hideScrollbar and 0 or SCROLLBAR_RESERVE_WIDTH
    return ITEM_GRID_H_PADDING, ITEM_GRID_H_PADDING + gutter
end

-- Snap a frame's physical top-left to the nearest integer pixel by adjusting
-- its current anchor offset. Call AFTER StopMovingOrSizing / SetPoint so the
-- frame already has a resolvable position. Keeps the existing anchor point
-- (TOPLEFT, CENTER, etc.) and relativeTo to preserve movement semantics, then
-- nudges the offset by at most 1 physical pixel to land on an integer. This
-- is the root cause fix for 1-px BackdropTemplate borders rendering dim or
-- missing: any ancestor at a fractional physical position causes its
-- descendants' 1-px edges to smear across two rows of physical pixels.
function WH:SnapFrameToPixel(frame)
    if not frame then return end
    local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(1)
    if not point or not offsetX or not offsetY then return end
    local scale = frame:GetEffectiveScale()
    if not scale or scale <= 0 then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if not left or not top then return end
    local physLeft = left * scale
    local physTop = top * scale
    local snappedPhysLeft = floor(physLeft + 0.5)
    local snappedPhysTop = floor(physTop + 0.5)
    local deltaX = (snappedPhysLeft - physLeft) / scale
    local deltaY = (snappedPhysTop - physTop) / scale
    if deltaX == 0 and deltaY == 0 then return end
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, offsetX + deltaX, offsetY + deltaY)
end

-- Snap a region's absolute physical top-left to an integer pixel, regardless of
-- how fractional the parent's physical position is. PixelUtil.SetPoint only
-- snaps the offset (delta from parent), so ancestors at fractional positions
-- smear 1-px edges across 2 rows of physical pixels. This helper solves for
-- the offset required to land the region's top-left exactly on an integer
-- pixel, guaranteeing crisp 1-px BackdropTemplate borders.
function WH:SetPointPixelAligned(region, parent, offsetX, offsetY)
    local pScale = parent and parent.GetEffectiveScale and parent:GetEffectiveScale()
    local pLeft = parent and parent.GetLeft and parent:GetLeft()
    local pTop = parent and parent.GetTop and parent:GetTop()
    if not pScale or not pLeft or not pTop then
        region:SetPoint("TOPLEFT", parent, "TOPLEFT", offsetX, offsetY)
        return
    end
    local targetPhysX = floor((pLeft + offsetX) * pScale + 0.5)
    local targetPhysY = floor((pTop + offsetY) * pScale + 0.5)
    region:SetPoint("TOPLEFT", parent, "TOPLEFT",
        targetPhysX / pScale - pLeft,
        targetPhysY / pScale - pTop)
end

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
        WH:SnapFrameToPixel(self)
        OneWoW_GUI:SaveWindowPosition(self, position)
        if config.onDragStop then config.onDragStop(self) end
    end)
    mainWindow:SetClampedToScreen(true)
    mainWindow:SetClampRectInsets(0, 0, 0, 0)
    mainWindow:SetFrameStrata(config.frameStrata or "MEDIUM")
    mainWindow:SetToplevel(true)
    mainWindow:SetScript("OnHide", config.onHide)
    mainWindow:HookScript("OnShow", function(self)
        WH:SnapFrameToPixel(self)
    end)
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
        settingsBtn = OneWoW_GUI:CreateAtlasIconButton(titleBar, {
            atlas = config.settingsAtlas or "mechagon-projects",
            width = 20,
            height = 20,
        })
        if settingsBtn then
            if titleBar and titleBar._closeBtn then
                settingsBtn:SetPoint("RIGHT", titleBar._closeBtn, "LEFT", -2, 0)
            elseif titleBar then
                settingsBtn:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0)
            end
            settingsBtn:SetScript("OnClick", config.onSettings)
            local settingsTooltipTitle = config.settingsText
            settingsBtn:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(settingsTooltipTitle, 1, 1, 1)
                GameTooltip:Show()
            end)
            settingsBtn:HookScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
    end

    return titleBar, settingsBtn
end

function WH:AttachShoppingListCartButton(titleBar, settingsBtn)
    if not titleBar or not settingsBtn then return end
    if titleBar._owbShoppingCartBtn then return end

    local L = OneWoW_Bags.L
    local function createCart()
        if titleBar._owbShoppingCartBtn then return end
        local cartBtn = CreateFrame("Button", nil, titleBar)
        cartBtn:SetSize(22, 22)
        cartBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -2, 0)
        cartBtn:SetNormalAtlas("Perks-ShoppingCart")
        cartBtn:SetPushedAtlas("Perks-ShoppingCart")
        cartBtn:SetHighlightAtlas("Perks-ShoppingCart")
        cartBtn:GetHighlightTexture():SetAlpha(0.5)
        cartBtn:SetScript("OnClick", function()
            if _G.OneWoW_ShoppingList and _G.OneWoW_ShoppingList.MainWindow then
                _G.OneWoW_ShoppingList.MainWindow:Toggle()
            end
        end)
        cartBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["SHOPPING_LIST"], 1, 1, 1)
            GameTooltip:AddLine(L["SHOPPING_LIST_DESC"], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        cartBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        titleBar._owbShoppingCartBtn = cartBtn
        local waitFrame = titleBar._owbShoppingListEventFrame
        if waitFrame then
            waitFrame:UnregisterAllEvents()
            waitFrame:SetScript("OnEvent", nil)
            titleBar._owbShoppingListEventFrame = nil
        end
    end

    if _G.OneWoW_ShoppingList then
        createCart()
    else
        local f = CreateFrame("Frame")
        titleBar._owbShoppingListEventFrame = f
        f:RegisterEvent("ADDON_LOADED")
        f:SetScript("OnEvent", function(_, _, addonName)
            if addonName == "OneWoW_ShoppingList" then
                createCart()
            end
        end)
    end
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

    local rawSetVerticalScroll = scrollFrame.SetVerticalScroll
    scrollFrame.SetVerticalScroll = function(self, value)
        local scale = self:GetEffectiveScale()
        local snapped = PixelUtil.GetNearestPixelSize(value or 0, scale, 0)
        rawSetVerticalScroll(self, snapped)
    end

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

function WH:GetExpansionName(expansionID)
    if expansionID == nil then
        return nil
    end
    return _G["EXPANSION_NAME" .. expansionID]
end

function WH:GetKnownExpansionIDs()
    local expansionEnum = Enum and Enum.ExpansionLevel
    local ids = {}
    local seen = {}
    if type(expansionEnum) ~= "table" then
        return ids
    end

    for _, expansionID in pairs(expansionEnum) do
        if type(expansionID) == "number" and not seen[expansionID] then
            seen[expansionID] = true
            tinsert(ids, expansionID)
        end
    end

    sort(ids)
    return ids
end

function WH:ResolveExpansionID(itemInfo, bagID, slotID)
    if not itemInfo or not itemInfo.itemID then
        return nil
    end

    local props = PE:BuildProps(itemInfo.itemID, bagID, slotID, itemInfo)
    if props and props.expansionID ~= nil then
        return props.expansionID
    end

    return nil
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
            local expansionID = self:ResolveExpansionID(button.owb_itemInfo, button.owb_bagID, button.owb_slotID)
            if expansionID == expacFilter then
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
        WH:SnapFrameToPixel(mainWindow)
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
    WH:SnapFrameToPixel(mainWindow)
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
