local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

local Constants = ns.Constants
local PE = OneWoW.PredicateEngine
local SE = OneWoW.SearchExpand

local tinsert, sort, wipe = tinsert, sort, wipe
local ipairs, pairs = ipairs, pairs
local type, format = type, string.format
local floor, min, max = math.floor, math.min, math.max
local Enum = Enum
local PixelUtil = PixelUtil

ns.WindowHelpers = {}
local WH = ns.WindowHelpers

WH.SCALE_MIN = 50
WH.SCALE_MAX = 200
WH.SCALE_STEP = 5
WH.SCALE_DEFAULT = 100

local ITEM_GRID_H_PADDING = 2
local SCROLLBAR_RESERVE_WIDTH = OneWoW_GUI.Constants.GUI.SCROLLBAR_WIDTH + 2
local scratchTables = {}

local SUITE_TITLE_BAR_ADDONS = {
    "OneWoW_ShoppingList",
    "OneWoW_DirectDeposit",
}
local titleBarRefreshRegistry = {}
local titleBarRefreshRegistered = false
local ICON_SIZE = 20

local function IsSuiteTitleBarAddon(addonName)
    for _, name in ipairs(SUITE_TITLE_BAR_ADDONS) do
        if name == addonName then return true end
    end
    return false
end

local function GetSuiteTitleBarFeatureConfigs(L)
    return {
        {
            addonName = "OneWoW_ShoppingList",
            storageKey = "_owbShoppingCartBtn",
            atlas = "Perks-ShoppingCart",
            tooltipTitle = L["SHOPPING_LIST"],
            tooltipDesc = L["SHOPPING_LIST_DESC"],
            onReady = function()
                OneWoW_ShoppingList_API.Toggle()
            end,
        },
        {
            addonName = "OneWoW_DirectDeposit",
            storageKey = "_owbDirectDepositBtn",
            iconTexture = "Interface\\Icons\\INV_Misc_Coin_02",
            tooltipTitle = L["DIRECT_DEPOSIT"],
            tooltipDesc = L["DIRECT_DEPOSIT_DESC"],
            onReady = function()
                OneWoW_DirectDeposit_API.Toggle()
            end,
        },
    }
end

local function RegisterTitleBarForRefresh(titleBar, settingsBtn)
    for _, entry in ipairs(titleBarRefreshRegistry) do
        if entry.titleBar == titleBar then return end
    end
    tinsert(titleBarRefreshRegistry, { titleBar = titleBar, settingsBtn = settingsBtn })

    if titleBarRefreshRegistered then return end
    titleBarRefreshRegistered = true
    EventRegistry:RegisterCallback("ns.FeatureStateChanged", function(_, addonName)
        if not IsSuiteTitleBarAddon(addonName) then return end
        for _, entry in ipairs(titleBarRefreshRegistry) do
            WH:SyncSuiteTitleBarButtons(entry.titleBar, entry.settingsBtn)
        end
    end)
end

--- Run a layout refresh body with reentrancy guard and pcall so _layoutInProgress cannot stick.
---@param owner table GUI module (GUI, BankGUI, GuildBankGUI)
---@param targetKey "bags"|"bank"|"guild"
---@param body function
function WH:RunGuardedLayoutRefresh(owner, targetKey, body)
    local LD = ns.LayoutDebug
    if owner._layoutInProgress then
        if LD and LD.enabled then
            LD:Record("guard_reentrant", { target = targetKey, inProgress = true })
        end
        ns:RequestLayoutRefresh(targetKey, "reentrant_followup")
        return
    end
    if LD and LD.enabled then
        LD:Record("guard_start", { target = targetKey })
    end
    owner._layoutInProgress = true
    local ok, err = pcall(body)
    owner._layoutInProgress = false
    if not ok then
        if LD and LD.enabled then
            LD:Record("guard_err", { target = targetKey, err = tostring(err) })
        end
        print("|cffff4444OneWoW_Bags:|r layout refresh failed (" .. tostring(targetKey) .. "):", err)
    elseif LD and LD.enabled then
        LD:Record("guard_ok", { target = targetKey })
    end
end

--- Request a coalesced layout refresh when a main window becomes visible.
---@param mainWindow table
---@param targetKey "bags"|"bank"|"guild"
---@param isBuiltFn function
function WH:AttachLayoutOnShow(mainWindow, targetKey, isBuiltFn)
    if not mainWindow or not isBuiltFn then return end
    mainWindow:HookScript("OnShow", function()
        if ns:IsOnShowLayoutSuppressed(targetKey) then return end
        if isBuiltFn() then
            local LD = ns.LayoutDebug
            if LD and LD.enabled then
                LD:Record("onshow", { target = targetKey })
            end
            ns:RequestLayoutRefresh(targetKey, "show_onshow")
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

--- Clamp a window-scale percent to the supported range.
---@param percent number|nil
---@return number
function WH:ClampScalePercent(percent)
    return min(WH.SCALE_MAX, max(WH.SCALE_MIN, tonumber(percent) or WH.SCALE_DEFAULT))
end

--- Screen size in the frame's local units (UIParent size / frame:GetScale).
---@param frame table|nil
---@return number width
---@return number height
function WH:ScreenSizeInFrameUnits(frame)
    local scale = 1
    if frame then
        scale = frame:GetScale()
    end
    if scale <= 0 then scale = 1 end
    return GetScreenWidth() / scale, GetScreenHeight() / scale
end

--- Apply a percent scale (50-200) to a window and snap it to a pixel.
---@param frame table|nil
---@param percent number|nil
function WH:ApplyWindowScale(frame, percent)
    if not frame then return end
    frame:SetScale(self:ClampScalePercent(percent) / 100)
    self:SnapFrameToPixel(frame)
end

--- Resolve the scale percent for a window shell config.
---@param config table
---@return number
function WH:ResolveScalePercent(config)
    if config.getScale then
        return self:ClampScalePercent(config.getScale())
    end
    if config.scaleDBKey then
        local db = ns:GetDB()
        return self:ClampScalePercent(db.global[config.scaleDBKey])
    end
    return WH.SCALE_DEFAULT
end

--- Apply a saved scale to a bags/bank/guild window and refresh width bounds.
---@param gui table|nil
---@param percent number|nil
function WH:ApplySavedScaleToWindow(gui, percent)
    if not gui then return end
    local frame = gui:GetMainWindow()
    if not frame then return end
    self:ApplyWindowScale(frame, percent)
    gui:UpdateWindowWidth()
end

function WH:CreateWindowShell(config)
    local db = ns:GetDB()
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
    self:ApplyWindowScale(mainWindow, self:ResolveScalePercent(config))
    local screenW, screenH = self:ScreenSizeInFrameUnits(mainWindow)
    local maxW = min(config.maxWidth or Constants.GUI.WINDOW_WIDTH, screenW)
    local maxH = min(config.maxHeight or 1200, screenH)
    mainWindow:SetResizeBounds(config.minWidth or Constants.GUI.WINDOW_WIDTH, config.minHeight or 300, maxW, maxH)
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

function WH:AttachSuiteTitleBarButtons(titleBar, settingsBtn)
    if not titleBar or not settingsBtn then return end
    RegisterTitleBarForRefresh(titleBar, settingsBtn)
    self:SyncSuiteTitleBarButtons(titleBar, settingsBtn)
end

function WH:SyncSuiteTitleBarButtons(titleBar, settingsBtn)
    if not titleBar or not settingsBtn then return end

    local L = ns.L
    local configs = GetSuiteTitleBarFeatureConfigs(L)
    local shoppingConfig = configs[1]
    local ddConfig = configs[2]

    local shoppingBtn = self:_SyncFeatureButton(titleBar, settingsBtn, shoppingConfig)
    local ddAnchor = shoppingBtn or settingsBtn
    self:_SyncFeatureButton(titleBar, ddAnchor, ddConfig)
end

function WH:_SyncFeatureButton(titleBar, anchorBtn, config)
    if not titleBar or not anchorBtn or not config then return nil end

    local existing = titleBar[config.storageKey]
    local wanted = OneWoW:IsFeatureWanted(config.addonName, true)

    if not wanted then
        if existing then existing:Hide() end
        return nil
    end

    if existing then
        existing:Show()
        existing:ClearAllPoints()
        existing:SetPoint("RIGHT", anchorBtn, "LEFT", -2, 0)
        return existing
    end

    return self:_CreateFeatureButton(titleBar, anchorBtn, config)
end

function WH:_CreateFeatureButton(titleBar, anchorBtn, config)
    if not titleBar or not anchorBtn or not config then return nil end
    if titleBar[config.storageKey] then return titleBar[config.storageKey] end

    local btn
    if config.atlas then
        btn = OneWoW_GUI:CreateAtlasIconButton(titleBar, {
            atlas = config.atlas,
            width = ICON_SIZE,
            height = ICON_SIZE,
        })
    else
        btn = OneWoW_GUI:CreateTextureIconButton(titleBar, {
            iconTexture = config.iconTexture,
            width = ICON_SIZE,
            height = ICON_SIZE,
        })
    end
    if not btn then return nil end

    btn:SetPoint("RIGHT", anchorBtn, "LEFT", -2, 0)
    btn:SetScript("OnClick", function()
        OneWoW:WithAddon(config.addonName, config.onReady)
    end)
    btn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(config.tooltipTitle, 1, 1, 1)
        GameTooltip:AddLine(config.tooltipDesc, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    titleBar[config.storageKey] = btn
    return btn
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
    if config.hideScrollBar then
        OneWoW_GUI:SetScrollBarAlwaysHidden(scrollFrame, true)
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

--- Display name for expansion grouping; never nil.
---@param expansionID number|nil
---@return string
function WH:GetExpansionDisplayName(expansionID)
    local L = ns.L
    if expansionID == nil or expansionID < 0 then
        return L["EXPAC_UNKNOWN"]
    end

    local name = OneWoW:GetExpansionName(expansionID)
    if name then
        return name
    end

    local raw = _G["EXPANSION_NAME" .. tostring(expansionID)]
    if raw and raw ~= "" then
        return raw
    end

    return format(L["EXPAC_FALLBACK"], expansionID)
end

---@param button table
---@return number expansionID (-1 when unknown)
function WH:GetButtonExpansionID(button)
    local cached = button._owb_expansionID
    if cached ~= nil and cached >= 0 then
        return cached
    end

    if not button.owb_hasItem or not button.owb_itemInfo or not button.owb_itemInfo.itemID then
        return -1
    end

    local props = ns:GetButtonProps(button)
    local expansionID = props and props.expansionID
    if expansionID ~= nil and expansionID >= 0 then
        button._owb_expansionID = expansionID
        return expansionID
    end

    return -1
end

--- Filter item buttons with a PredicateEngine search expression.
--- SAVED(Name) / CATEGORY(Name) references are expanded before evaluation.
---@param buttons table[]
---@param searchText string|nil
---@param dest table[]|nil
---@return table[] buttons
function WH:FilterBySearch(buttons, searchText, dest)
    if not searchText or searchText == "" then
        return buttons
    end

    local filtered = dest or {}
    wipe(filtered)
    local compiled = SE:Compile(searchText)
    if not compiled then
        return filtered
    end

    for _, button in ipairs(buttons) do
        if button.owb_hasItem and button.owb_itemInfo and button.owb_itemInfo.itemID then
            local props = ns:GetButtonProps(button)
            if PE:SafeEvaluate(compiled, props) then
                tinsert(filtered, button)
            end
        end
    end

    return filtered
end

--- Normalize an expansion filter to a set of IDs, or nil for all.
---@param value table<number, boolean>|number|string|nil
---@return table<number, boolean>|nil
function WH:NormalizeExpansionFilter(value)
    if value == nil or value == "ALL" then
        return nil
    end
    if type(value) == "number" then
        return { [value] = true }
    end
    if type(value) ~= "table" then
        return nil
    end

    local set = {}
    local n = 0
    for id, on in pairs(value) do
        if on and type(id) == "number" then
            set[id] = true
            n = n + 1
        end
    end
    if n == 0 then
        return nil
    end
    return set
end

--- Filter item buttons to one or more expansion IDs.
---@param buttons table[]
---@param expacFilter table<number, boolean>|number|nil
---@param dest table[]|nil
---@return table[] buttons
function WH:FilterByExpansion(buttons, expacFilter, dest)
    local filterSet = self:NormalizeExpansionFilter(expacFilter)
    if filterSet == nil then
        return buttons
    end

    local filtered = dest or {}
    wipe(filtered)
    for _, button in ipairs(buttons) do
        if button.owb_hasItem and button.owb_itemInfo and button.owb_itemInfo.itemID then
            local expansionID = self:GetButtonExpansionID(button)
            if filterSet[expansionID] then
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
---@return number cols
---@return number iconSize
---@return number spacing
---@return number contentWidth
function WH:GetLayoutMetrics(columnsDBKey)
    local db = ns:GetDB()
    local cols = db.global[columnsDBKey]
    local iconSize = Constants.ICON_SIZES[db.global.iconSize] or 37
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
        local db = ns:GetDB()
        mainWindow:StopMovingOrSizing()
        WH:SnapFrameToPixel(mainWindow)
        local pos = DB:Ensure(db, "global", positionDBKey)
        OneWoW_GUI:SaveWindowPosition(mainWindow, pos)
        local target = (gui == ns.GUI and "bags")
            or (gui == ns.BankGUI and "bank")
            or (gui == ns.GuildBankGUI and "guild")
        if target then
            ns:RequestLayoutRefresh(target, "resize")
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
    local db = ns:GetDB()
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
