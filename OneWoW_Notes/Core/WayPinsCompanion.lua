local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Location = OneWoW.Location

local ipairs, wipe, tinsert = ipairs, wipe, tinsert

-- ============================================================================
-- WayPinsCompanion
-- ============================================================================
-- List of OneWay Pins for the current map, docked to the right of a Zone Notes
-- pinned window. One companion per map (not per zone note). Gated by the host
-- note's pinEnabled window being shown and showWayPins ~= false.
-- ============================================================================

local Companion = {}
ns.WayPinsCompanion = Companion

local ROW_HEIGHT = 26
local COMPANION_WIDTH = 220
local C = OneWoW_GUI.Constants

local frame
local hostFrame
local rowPool = {}
local activeRows = {}

local function EnsureFrame()
    if frame then return frame end

    frame = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_WayPinsCompanion",
        width = COMPANION_WIDTH,
        height = 200,
        backdrop = C.BACKDROP_SOFT,
    })
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:Hide()
    OneWoW_GUI:RegisterFontRoot(frame, function()
        Companion:RefreshRows()
    end)

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 8, -6)
    titleBar:SetPoint("TOPRIGHT", -8, -6)
    titleBar:SetHeight(20)
    frame.titleBar = titleBar

    local title = OneWoW_GUI:CreateFS(titleBar, 12)
    title:SetPoint("LEFT", 0, 0)
    title:SetPoint("RIGHT", -20, 0)
    title:SetJustifyH("LEFT")
    title:SetText(L["TAB_WAYPINS"])
    title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    frame.title = title

    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("RIGHT", 0, 0)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetScript("OnClick", function()
        Companion:CollapseHost()
    end)

    local scroll, child = OneWoW_GUI:CreateScrollFrame(frame, {})
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -28)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame.scroll = scroll
    frame.child = child

    return frame
end

local function ApplyChrome()
    if not frame then return end
    frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    frame.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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
            GameTooltip:SetText(pin.title or L["WAYPINS_UNTITLED"], 1, 1, 1)
            GameTooltip:AddLine(L["WAYPINS_GO_TT"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(myself)
        Companion:PaintRow(myself)
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(myself)
        if myself.pinData then
            ns.WayPins:Track(myself.pinData.id)
        end
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
    self:Hide()
end

function Companion:ApplyTheme()
    ApplyChrome()
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

function Companion:ShowDocked(host, _)
    EnsureFrame()
    ApplyChrome()
    hostFrame = host
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", host, "TOPRIGHT", 4, 0)
    frame:SetPoint("BOTTOMLEFT", host, "BOTTOMRIGHT", 4, 0)
    frame:SetWidth(COMPANION_WIDTH)
    frame:Show()
    self:RefreshRows()
end

function Companion:Sync()
    local mapID = Location.GetPlayerMapID()
    local pins = ns.WayPins:GetForMap(mapID)
    if #pins == 0 then
        self:Hide()
        return
    end

    local host
    if ns.zonePins then
        for noteId, pinFrame in pairs(ns.zonePins) do
            if pinFrame and pinFrame:IsShown() then
                local zd = ns.Zones:GetZone(noteId)
                if zd and zd.showWayPins ~= false then
                    host = pinFrame
                    break
                end
            end
        end
    end

    if host then
        self:ShowDocked(host, pins)
    else
        self:Hide()
    end
end
