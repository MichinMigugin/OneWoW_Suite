local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

local Constants = OneWoW_Bags.Constants
local PE = OneWoW_GUI.PredicateEngine

local tinsert, sort, wipe = tinsert, sort, wipe
local ipairs, pairs = ipairs, pairs
local type = type
local floor = math.floor
local Enum = Enum
local PixelUtil = PixelUtil

OneWoW_Bags.WindowHelpers = {}
local WH = OneWoW_Bags.WindowHelpers

local ITEM_GRID_H_PADDING = 2
local SCROLLBAR_RESERVE_WIDTH = 12
local scratchTables = {}

--- Run a layout refresh body with reentrancy guard and pcall so _layoutInProgress cannot stick.
---@param owner table GUI module (GUI, BankGUI, GuildBankGUI)
---@param targetKey "bags"|"bank"|"guild"
---@param body function
function WH:RunGuardedLayoutRefresh(owner, targetKey, body)
    if owner._layoutInProgress then
        OneWoW_Bags:RequestLayoutRefresh(targetKey, "reentrant_followup")
        return
    end
    owner._layoutInProgress = true
    local ok, err = pcall(body)
    owner._layoutInProgress = false
    if not ok then
        print("|cffff4444OneWoW_Bags:|r layout refresh failed (" .. tostring(targetKey) .. "):", err)
    end
end

--- Request a coalesced layout refresh when a main window becomes visible.
---@param mainWindow table
---@param targetKey "bags"|"bank"|"guild"
---@param isBuiltFn function
function WH:AttachLayoutOnShow(mainWindow, targetKey, isBuiltFn)
    if not mainWindow or not isBuiltFn then return end
    mainWindow:HookScript("OnShow", function()
        if isBuiltFn() then
            OneWoW_Bags:RequestLayoutRefresh(targetKey, "show_onshow")
        end
    end)
end

---@param key string
---@return table scratch
function WH:GetScratchTable(key)
    local scratch = scratchTables[key]
    if not scratch then
        scratch = {}
        scratchTables[key] = scratch
    else
        wipe(scratch)
    end
    return scratch
end

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
    mainWindow:SetScript("OnDragStop", function(myself)
        myself:StopMovingOrSizing()
        WH:SnapFrameToPixel(myself)
        OneWoW_GUI:SaveWindowPosition(myself, position)
        if config.onDragStop then config.onDragStop(myself) end
    end)
    mainWindow:SetClampedToScreen(true)
    mainWindow:SetClampRectInsets(0, 0, 0, 0)
    mainWindow:SetFrameStrata(config.frameStrata or "MEDIUM")
    mainWindow:SetToplevel(true)
    mainWindow:SetScript("OnHide", config.onHide)
    mainWindow:HookScript("OnShow", function(myself)
        WH:SnapFrameToPixel(myself)
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
            settingsBtn:HookScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_TOP")
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
            if OneWoW_ShoppingList and OneWoW_ShoppingList.MainWindow then
                OneWoW_ShoppingList.MainWindow:Toggle()
            end
        end)
        cartBtn:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_TOP")
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

    if OneWoW_ShoppingList then
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
    scrollFrame:HookScript("OnSizeChanged", function(_, width)
        contentFrame:SetWidth(width)
    end)

    local rawSetVerticalScroll = scrollFrame.SetVerticalScroll
    scrollFrame.SetVerticalScroll = function(myself, value)
        local scale = myself:GetEffectiveScale()
        local snapped = PixelUtil.GetNearestPixelSize(value or 0, scale, 0)
        rawSetVerticalScroll(myself, snapped)
    end

    return scrollFrame, contentFrame
end

--- Defer content width correction and refresh until the scroll frame has size.
---@param scrollFrame table|nil
---@param contentFrame table|nil
---@param refreshCallback function|nil
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

--- Register a PLAYER_REGEN_ENABLED cleanup for work deferred out of combat.
--- `config` must provide shouldCleanup() and cleanup() callbacks.
---@param config table
---@return table eventFrame
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

function WH:GetKnownExpansionIDs()
    local ids = {}
    local seen = {}

    for _, expansionID in pairs(Enum.ExpansionLevel) do
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

---@param button table
---@return number|nil expansionID
function WH:GetButtonExpansionID(button)
    local itemInfo = button.owb_itemInfo
    if button._owb_expansionID ~= nil and not (button._owb_expansionID == -1 and itemInfo and itemInfo.hyperlink) then
        return button._owb_expansionID
    end
    if not button.owb_hasItem or not itemInfo or not itemInfo.itemID then
        return nil
    end
    local props = OneWoW_Bags:GetButtonProps(button)
    return props.expansionID
end

--- Filter item buttons with a PredicateEngine search expression.
--- SAVED(Name) references are expanded before evaluation.
---@param buttons table[]
---@param searchText string|nil
---@param dest table[]|nil
---@return table[] buttons
function WH:FilterBySearch(buttons, searchText, dest)
    if not searchText or searchText == "" then
        return buttons
    end

    if OneWoW_Bags.SavedSearches then
        searchText = OneWoW_Bags.SavedSearches:Expand(searchText)
    end

    local filtered = dest or {}
    wipe(filtered)
    local compiled = PE:Compile(searchText)
    if not compiled then
        return filtered
    end

    for _, button in ipairs(buttons) do
        if button.owb_hasItem and button.owb_itemInfo and button.owb_itemInfo.itemID then
            local props = OneWoW_Bags:GetButtonProps(button)
            if PE:SafeEvaluate(compiled, props) then
                tinsert(filtered, button)
            end
        end
    end

    return filtered
end

--- Filter item buttons to a single expansion ID.
---@param buttons table[]
---@param expacFilter number|nil
---@param dest table[]|nil
---@return table[] buttons
function WH:FilterByExpansion(buttons, expacFilter, dest)
    if expacFilter == nil then
        return buttons
    end

    local filtered = dest or {}
    wipe(filtered)
    for _, button in ipairs(buttons) do
        if button.owb_hasItem and button.owb_itemInfo and button.owb_itemInfo.itemID then
            local expansionID = self:GetButtonExpansionID(button)
            if expansionID == expacFilter then
                tinsert(filtered, button)
            end
        end
    end
    return filtered
end

--- Filter item buttons to a bag/container tab.
---@param buttons table[]
---@param selectedTab number|nil
---@param dest table[]|nil
---@return table[] buttons
function WH:FilterByTab(buttons, selectedTab, dest)
    if not selectedTab then return buttons end

    local filtered = dest or {}
    wipe(filtered)
    for _, btn in ipairs(buttons) do
        if btn.owb_bagID == selectedTab then
            tinsert(filtered, btn)
        end
    end
    return filtered
end

--- Calculate grid metrics from the current database settings.
---@param columnsDBKey string
---@param defaultCols number
---@return number cols
---@return number iconSize
---@return number spacing
---@return number contentWidth
function WH:GetLayoutMetrics(columnsDBKey, defaultCols)
    local db = OneWoW_Bags:GetDB()
    local cols = db.global[columnsDBKey] or defaultCols
    local iconSize = Constants.ICON_SIZES[db.global.iconSize or 3] or 37
    local spacing = Constants.GUI.ITEM_BUTTON_SPACING
    local contentWidth = cols * (iconSize + spacing) - spacing + 4
    return cols, iconSize, spacing, contentWidth
end

--- Attach a resize grabber that saves window height and refreshes layout.
---@param mainWindow table
---@param gui table
---@param positionDBKey string
---@return table resizeBtn
function WH:SetupResizeButton(mainWindow, gui, positionDBKey)
    local resizeBtn = CreateFrame("Button", nil, mainWindow)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", mainWindow, "BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetFrameLevel(mainWindow:GetFrameLevel() + 10)
    resizeBtn:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            mainWindow:StartSizing("BOTTOM")
        end
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        local db = OneWoW_Bags:GetDB()
        mainWindow:StopMovingOrSizing()
        WH:SnapFrameToPixel(mainWindow)
        local pos = DB:Ensure(db, "global", positionDBKey)
        OneWoW_GUI:SaveWindowPosition(mainWindow, pos)
        local target = (gui == OneWoW_Bags.GUI and "bags")
            or (gui == OneWoW_Bags.BankGUI and "bank")
            or (gui == OneWoW_Bags.GuildBankGUI and "guild")
        if target then
            OneWoW_Bags:RequestLayoutRefresh(target, "resize")
        elseif gui.RefreshLayout then
            gui:RefreshLayout()
        end
    end)
    return resizeBtn
end

--- Register a named window as a UISpecialFrame for Escape-key closing.
---@param globalName string
---@param mainWindow table
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

--- Restore a saved window position or fall back to center.
---@param mainWindow table
---@param positionDBKey string
function WH:SaveAndRestorePosition(mainWindow, positionDBKey)
    local db = OneWoW_Bags:GetDB()
    local pos = DB:Ensure(db, "global", positionDBKey)
    if not OneWoW_GUI:RestoreWindowPosition(mainWindow, pos) then
        mainWindow:SetPoint("CENTER")
    end
    WH:SnapFrameToPixel(mainWindow)
end

--- Apply standard OneWoW_Bags theme colors to window chrome.
---@param mainWindow table
---@param titleBar table|nil
---@param infoBarRef table|nil
---@param bottomBarRef table|nil
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
