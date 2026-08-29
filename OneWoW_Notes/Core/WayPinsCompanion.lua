local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Location = OneWoW.Location
local PinSupport = ns.PinSupport
local Visual = ns.WayPinsVisual

local ipairs, wipe, tinsert, pairs = ipairs, wipe, tinsert, pairs
local IsControlKeyDown = IsControlKeyDown

-- ============================================================================
-- WayPinsCompanion
-- ============================================================================
-- List of OneWay Pins for the current map, docked to the right of a Zone Notes
-- pinned window (or filling it when Show Zone Notes is off). Chrome copies the
-- host note so the two boxes read as one. One companion per map.
-- ============================================================================

local Companion = {}
ns.WayPinsCompanion = Companion

local ROW_HEIGHT = 26
local COMPANION_WIDTH = 220

local TITLE_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local frame
local hostFrame
local rowPool = {}
local activeRows = {}
local pausedForMap = false
local restoreHosts = {}

local function HostHidesNote(host)
    if not host or not host.noteId or not ns.Zones then
        return false
    end
    local zd = ns.Zones:GetZone(host.noteId)
    return Visual.Enabled() and zd and zd.hideZoneNote == true and zd.showWayPins ~= false
end

local function HostHidesScrollBar(host)
    host = host or hostFrame
    if not host or not host.noteId or not ns.Zones then
        return false
    end
    local zd = ns.Zones:GetZone(host.noteId)
    return zd and zd.hideScrollBar == true
end

local function ApplyScrollBarVisibility(host)
    if not frame or not frame.scroll then
        return
    end
    local bar = frame.scroll.ScrollBar
    if not bar then
        return
    end
    host = host or hostFrame
    if host and hostFrame and host ~= hostFrame then
        return
    end
    if HostHidesScrollBar(host or hostFrame) then
        bar:Hide()
        bar:SetAlpha(0)
        bar:EnableMouse(false)
    else
        bar:SetAlpha(1)
        bar:EnableMouse(true)
        bar:Show()
    end
end

local function EnsureFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "OneWoW_WayPinsCompanion", UIParent, "BackdropTemplate")
    frame:SetWidth(COMPANION_WIDTH)
    frame:SetHeight(200)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()
    OneWoW_GUI:RegisterFontRoot(frame, function()
        Companion:RefreshRows()
    end)

    frame:SetScript("OnDragStart", function()
        if hostFrame and hostFrame:IsMovable() then
            hostFrame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        if hostFrame then
            hostFrame:StopMovingOrSizing()
            if hostFrame.SaveGeometry then
                hostFrame:SaveGeometry()
            end
        end
    end)
    frame:SetScript("OnMouseUp", function(myself, button)
        if button == "RightButton" then
            ns.WayPinsMap:ShowAddMenu(myself)
        end
    end)
    frame:SetScript("OnEnter", function()
        if hostFrame and hostFrame.ShowHoverControls then
            hostFrame.ShowHoverControls()
        end
    end)
    frame:SetScript("OnLeave", function()
        if hostFrame and hostFrame.HideHoverControlsIfAway then
            hostFrame.HideHoverControlsIfAway()
        end
    end)

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", -4, -4)
    titleBar:SetHeight(20)
    titleBar:SetBackdrop(TITLE_BACKDROP)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        if hostFrame and hostFrame:IsMovable() then
            hostFrame:StartMoving()
        end
    end)
    titleBar:SetScript("OnDragStop", function()
        if hostFrame then
            hostFrame:StopMovingOrSizing()
            if hostFrame.SaveGeometry then
                hostFrame:SaveGeometry()
            end
        end
    end)
    titleBar:SetScript("OnMouseUp", function(myself, button)
        if button == "RightButton" then
            ns.WayPinsMap:ShowAddMenu(myself)
        end
    end)
    titleBar:SetScript("OnEnter", function()
        if hostFrame and hostFrame.ShowHoverControls then
            hostFrame.ShowHoverControls()
        end
    end)
    titleBar:SetScript("OnLeave", function()
        if hostFrame and hostFrame.HideHoverControlsIfAway then
            hostFrame.HideHoverControlsIfAway()
        end
    end)
    frame.titleBar = titleBar

    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("RIGHT", -2, 0)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetScript("OnClick", function()
        if hostFrame and HostHidesNote(hostFrame) and hostFrame.closeBtn then
            hostFrame.closeBtn:Click()
            return
        end
        Companion:CollapseHost()
    end)
    frame.closeBtn = closeBtn

    local minimizeBtn = CreateFrame("Button", nil, titleBar)
    minimizeBtn:SetSize(16, 16)
    minimizeBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    minimizeBtn:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-UP")
    minimizeBtn:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-UP")
    minimizeBtn:SetHighlightTexture("Interface\\Buttons\\UI-MinusButton-UP")
    minimizeBtn:SetScript("OnClick", function()
        if hostFrame and hostFrame.ToggleCollapsed then
            hostFrame:ToggleCollapsed()
        end
    end)
    minimizeBtn:SetScript("OnEnter", function(myself)
        PinSupport.ShowTooltip(myself, "ANCHOR_BOTTOM", MINIMIZE)
    end)
    minimizeBtn:SetScript("OnLeave", PinSupport.HideTooltip)
    minimizeBtn:Hide()
    frame.minimizeBtn = minimizeBtn

    local addBtn = OneWoW_GUI:CreateFitTextButton(titleBar, { text = ADD, height = 18, minWidth = 36 })
    addBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    addBtn:SetScript("OnClick", function(myself)
        ns.WayPinsMap:ShowAddMenu(myself)
    end)
    addBtn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["WAYPINS_ADD_PIN"], 1, 1, 1)
        GameTooltip:AddLine(L["WAYPINS_COMPANION_ADD_TT"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    addBtn:SetScript("OnLeave", GameTooltip_Hide)
    frame.addBtn = addBtn

    local title = OneWoW_GUI:CreateFS(titleBar, 12)
    title:SetPoint("LEFT", 5, 0)
    title:SetPoint("RIGHT", addBtn, "LEFT", -4, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText(L["TAB_WAYPINS"])
    title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    frame.title = title

    local scroll, child = OneWoW_GUI:CreateScrollFrame(frame, {})
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -28)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame.scroll = scroll
    frame.child = child
    local bar = scroll.ScrollBar
    if bar then
        bar:HookScript("OnShow", function(myself)
            if HostHidesScrollBar(hostFrame) then
                myself:Hide()
                myself:SetAlpha(0)
                myself:EnableMouse(false)
            end
        end)
    end
    child:EnableMouse(true)
    child:SetScript("OnMouseUp", function(myself, button)
        if button == "RightButton" then
            ns.WayPinsMap:ShowAddMenu(myself)
        end
    end)

    return frame
end

function Companion:PaintOpacity(bgColor, alpha, borderColor, titleBarColor)
    if not frame then return end
    PinSupport.ApplyOpacityBackdrop(frame, bgColor, alpha, borderColor)
    if frame.titleBar and titleBarColor then
        frame.titleBar:SetBackdrop(TITLE_BACKDROP)
        frame.titleBar:SetBackdropColor(titleBarColor[1], titleBarColor[2], titleBarColor[3], 0.8)
    end
    frame.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
end

local function ApplyHostChrome(host)
    if not frame or not host then return end
    local r, g, b, a = host:GetBackdropColor()
    local br, bg, bb = host:GetBackdropBorderColor()
    local alpha = a or 1
    PinSupport.ApplyOpacityBackdrop(frame, { r, g, b }, alpha, { br, bg, bb })
    if host.titleBar then
        local tr, tg, tb, ta = host.titleBar:GetBackdropColor()
        frame.titleBar:SetBackdrop(TITLE_BACKDROP)
        frame.titleBar:SetBackdropColor(tr, tg, tb, ta or 0.8)
    end
    frame.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    frame:SetParent(host)
    frame:SetFrameStrata(host:GetFrameStrata())
    frame:SetFrameLevel(host:GetFrameLevel() + 1)
end

function Companion:ApplyClusterLayout(host)
    host = host or hostFrame
    if not host then return end
    local hover = host.hoverPanel

    if host.collapsed then
        if frame then frame:Hide() end
        if host._widthBeforeHideNote then
            host:SetWidth(host._widthBeforeHideNote)
            host._widthBeforeHideNote = nil
        end
        if host.titleBar then host.titleBar:Show() end
        if host.closeBtn then host.closeBtn:Show() end
        if host.minimizeBtn then host.minimizeBtn:Show() end
        if host.resizeBtn then host.resizeBtn:Hide() end
        if hover then
            hover:Hide()
            hover:ClearAllPoints()
            hover:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, 0)
            hover:SetPoint("TOPRIGHT", host, "BOTTOMRIGHT", 0, 0)
        end
        return
    end

    if not frame or not frame:IsShown() then
        if host._widthBeforeHideNote then
            host:SetWidth(host._widthBeforeHideNote)
            host._widthBeforeHideNote = nil
        end
        if host.titleBar then host.titleBar:Show() end
        if host.closeBtn then host.closeBtn:Show() end
        if host.minimizeBtn then host.minimizeBtn:Show() end
        if hover then
            hover:ClearAllPoints()
            hover:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, 0)
            hover:SetPoint("TOPRIGHT", host, "BOTTOMRIGHT", 0, 0)
        end
        return
    end

    local hideNote = HostHidesNote(host)
    if hideNote then
        if not host._widthBeforeHideNote then
            host._widthBeforeHideNote = PinSupport.GetPinWidth(host, 300)
        end
        if host.titleBar then host.titleBar:Hide() end
        if host.contentFrame then host.contentFrame:Hide() end
        if host.todoMainFrame then host.todoMainFrame:Hide() end
        if host.closeBtn then host.closeBtn:Hide() end
        if host.minimizeBtn then host.minimizeBtn:Hide() end
        host:SetWidth(COMPANION_WIDTH)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
        frame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
        frame:SetWidth(COMPANION_WIDTH)
    else
        if host._widthBeforeHideNote then
            host:SetWidth(host._widthBeforeHideNote)
            host._widthBeforeHideNote = nil
        end
        if host.titleBar then host.titleBar:Show() end
        if host.closeBtn then host.closeBtn:Show() end
        if host.minimizeBtn then host.minimizeBtn:Show() end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", host, "TOPRIGHT", 4, 0)
        frame:SetPoint("BOTTOMLEFT", host, "BOTTOMRIGHT", 4, 0)
        frame:SetWidth(COMPANION_WIDTH)
    end

    if frame.minimizeBtn then
        if hideNote then
            frame.minimizeBtn:Show()
            if frame.addBtn then
                frame.addBtn:SetPoint("RIGHT", frame.minimizeBtn, "LEFT", -2, 0)
            end
        else
            frame.minimizeBtn:Hide()
            if frame.addBtn then
                frame.addBtn:SetPoint("RIGHT", frame.closeBtn, "LEFT", -2, 0)
            end
        end
    end

    if host.resizeBtn then
        host.resizeBtn:Show()
        host.resizeBtn:SetFrameLevel(frame:GetFrameLevel() + 2)
    end

    if hover then
        hover:ClearAllPoints()
        hover:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, 0)
        if frame:IsShown() and not hideNote then
            hover:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        else
            hover:SetPoint("TOPRIGHT", host, "BOTTOMRIGHT", 0, 0)
        end
    end

    ApplyScrollBarVisibility(host)
end

local function AcquireRow(parent)
    for _, row in ipairs(rowPool) do
        if not row._inUse then
            row:SetParent(parent)
            return row
        end
    end
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 2, 0)
    row.icon = icon

    local label = OneWoW_GUI:CreateFS(row, 12)
    label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    row.label = label

    row:SetScript("OnEnter", function(myself)
        myself.label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
        local pin = myself.pinData
        if pin then
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            ns.WayPinsTooltip.Fill(GameTooltip, pin, L["WAYPINS_COMPANION_TT"])
            GameTooltip:Show()
        end
        if hostFrame and hostFrame.ShowHoverControls then
            hostFrame.ShowHoverControls()
        end
    end)
    row:SetScript("OnLeave", function(myself)
        Companion:PaintRow(myself)
        GameTooltip:Hide()
        if hostFrame and hostFrame.HideHoverControlsIfAway then
            hostFrame.HideHoverControlsIfAway()
        end
    end)
    row:SetScript("OnClick", function(myself, button)
        local pin = myself.pinData
        if not pin then return end
        if button == "RightButton" then
            ns.WayPinsMap:ShowListMenu(myself, pin)
            return
        end
        if IsControlKeyDown() then
            ns.WayPinsMap:OpenPinTab(pin.id)
            return
        end
        ns.WayPins:Track(pin.id)
    end)

    tinsert(rowPool, row)
    return row
end

function Companion:PaintRow(row)
    if not row.pinData then return end
    local tracked = ns.WayPinsMap and ns.WayPinsMap:GetLivePinID() == row.pinData.id
    if tracked then
        row.label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
    else
        row.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
    OneWoW.OverlayIcons:ApplyIconSpec(row.icon, row.pinData.icon)
end

function Companion:RefreshRows()
    if not frame or not frame:IsShown() then return end
    for _, row in ipairs(activeRows) do
        row._inUse = false
        row:Hide()
    end
    wipe(activeRows)

    local mapID = Location.GetPlayerMapID()
    local pins = ns.WayPins:GetForMap(mapID)
    local y = 0
    for _, pin in ipairs(pins) do
        local row = AcquireRow(frame.child)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame.child, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", frame.child, "TOPRIGHT", 0, -y)
        row.pinData = pin
        row._inUse = true
        row.label:SetText(pin.title or L["WAYPINS_UNTITLED"])
        self:PaintRow(row)
        row:Show()
        tinsert(activeRows, row)
        y = y + ROW_HEIGHT
    end
    frame.child:SetHeight(math.max(y, 1))
    ApplyScrollBarVisibility(hostFrame)
end

function Companion:CollapseHost()
    if hostFrame and hostFrame.noteId and ns.Zones then
        local zd = ns.Zones:GetZone(hostFrame.noteId)
        if zd then
            zd.showWayPins = false
            ns.Zones:SaveZone(hostFrame.noteId, zd)
        end
        if hostFrame.showWayPinsCB then
            hostFrame.showWayPinsCB:SetChecked(false)
        end
    end
    local host = hostFrame
    self:Hide()
    if host then
        if host._widthBeforeHideNote then
            host:SetWidth(host._widthBeforeHideNote)
            host._widthBeforeHideNote = nil
        end
        if host.RefreshLayout then
            host:RefreshLayout()
        elseif host.ApplyClusterLayout then
            host:ApplyClusterLayout()
        end
    end
end

function Companion:ApplyTheme()
    if frame and hostFrame then
        ApplyHostChrome(hostFrame)
        self:ApplyClusterLayout(hostFrame)
    end
    if frame and frame:IsShown() then
        self:RefreshRows()
    end
end

function Companion:Hide()
    hostFrame = nil
    if frame then
        frame:Hide()
    end
end

function Companion:IsShown()
    return frame and frame:IsShown()
end

function Companion:IsMouseOver()
    return frame and frame:IsMouseOver()
end

function Companion:GetWidth()
    return COMPANION_WIDTH
end

function Companion:IsPausedForMap()
    return pausedForMap
end

function Companion:PauseForMap()
    pausedForMap = true
    wipe(restoreHosts)
    if ns.zonePins then
        for id, pinFrame in pairs(ns.zonePins) do
            if pinFrame and pinFrame:IsShown() then
                restoreHosts[id] = true
                pinFrame:Hide()
            end
        end
    end
    if frame then
        frame:Hide()
    end
end

function Companion:ResumeAfterMap()
    pausedForMap = false
    for id in pairs(restoreHosts) do
        local pinFrame = ns.zonePins and ns.zonePins[id]
        if pinFrame then
            pinFrame:Show()
        end
    end
    wipe(restoreHosts)
    self:Sync()
end

--- Hide or show the pin-list scrollbar. Wheel scrolling still works when hidden.
---@param host Frame|nil
function Companion:ApplyScrollBarVisibility(host)
    ApplyScrollBarVisibility(host)
end

function Companion:ShowDocked(host)
    EnsureFrame()
    hostFrame = host
    ApplyHostChrome(host)
    frame:Show()
    self:ApplyClusterLayout(host)
    self:RefreshRows()
end

function Companion:Sync()
    if pausedForMap then return end
    if not Visual.Enabled() then
        local previous = hostFrame
        self:Hide()
        if previous and previous.ApplyClusterLayout then
            previous:ApplyClusterLayout()
        end
        return
    end

    local host
    if ns.zonePins then
        for noteId, pinFrame in pairs(ns.zonePins) do
            if pinFrame and pinFrame:IsShown() and not pinFrame.collapsed then
                local zd = ns.Zones:GetZone(noteId)
                if zd and zd.showWayPins ~= false then
                    host = pinFrame
                    break
                end
            end
        end
    end

    if host then
        self:ShowDocked(host)
    else
        local previous = hostFrame
        self:Hide()
        if previous and previous.ApplyClusterLayout then
            previous:ApplyClusterLayout()
        end
    end
end
