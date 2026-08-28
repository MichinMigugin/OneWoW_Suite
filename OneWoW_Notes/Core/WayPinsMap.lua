local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Location = OneWoW.Location
local Visual = ns.WayPinsVisual

local ipairs, wipe, tinsert = ipairs, wipe, tinsert
local abs, cos, sin, sqrt = math.abs, math.cos, math.sin, math.sqrt
local C_Map, C_Timer, C_Navigation, C_Minimap = C_Map, C_Timer, C_Navigation, C_Minimap
local GetCVar, GetPlayerFacing = GetCVar, GetPlayerFacing
local MenuUtil, GameTooltip = MenuUtil, GameTooltip
local CreateVector2D = CreateVector2D

-- ============================================================================
-- WayPinsMap
-- ============================================================================
-- World-map canvas buttons + minimap radar. Minimap placement uses world-yard
-- distance against C_Minimap.GetViewRadius so a landmark stays put while you
-- walk; map-percent used to be treated as the whole minimap radius, which
-- glued every pin to the player. Clicking a pin sets the Blizzard user
-- waypoint. Arrival clears that live track only.
-- ============================================================================

local WayPinsMap = {}
ns.WayPinsMap = WayPinsMap

local ARRIVE_YARDS = 22
local PERCENT_COORDS = { format = "percent" }
local FALLBACK_MAP_PERCENT = 2.5

local initialized = false
local worldPins = {}
local worldPinPool = {}
local minimapPins = {}
local minimapPinPool = {}
local livePinID = nil
local soloPinID = nil
local arrivalTicker = nil
local minimapTicker = nil
local mapHooked = false
local mapButton

local scratchA = CreateVector2D(0, 0)
local scratchB = CreateVector2D(0, 0)

local function WorldDistanceYards(mapID, x1, y1, x2, y2)
    x1, y1, x2, y2 = tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2)
    if not (mapID and x1 and y1 and x2 and y2) then return nil end
    scratchA:SetXY(x1 / 100, y1 / 100)
    scratchB:SetXY(x2 / 100, y2 / 100)
    local _, posA = C_Map.GetWorldPosFromMapPos(mapID, scratchA)
    local _, posB = C_Map.GetWorldPosFromMapPos(mapID, scratchB)
    if not posA or not posB then return nil end
    local dx = posA.x - posB.x
    local dy = posA.y - posB.y
    return sqrt(dx * dx + dy * dy)
end

local function PinVisible(data)
    if soloPinID and data.id ~= soloPinID then
        return false
    end
    return true
end

local function StopArrivalWatch()
    if arrivalTicker then
        arrivalTicker:Cancel()
        arrivalTicker = nil
    end
end

local function ClearLiveWaypoint()
    if not livePinID then
        StopArrivalWatch()
        return
    end
    livePinID = nil
    StopArrivalWatch()
    if C_Map.HasUserWaypoint() then
        C_Map.ClearUserWaypoint()
    end
    WayPinsMap:RefreshWorldMap()
    WayPinsMap:UpdateMinimapPins()
    if ns.WayPinsCompanion then
        ns.WayPinsCompanion:RefreshRows()
    end
end

local function StartArrivalWatch()
    StopArrivalWatch()
    arrivalTicker = C_Timer.NewTicker(0.4, function()
        if not livePinID then
            StopArrivalWatch()
            return
        end
        if not C_Map.HasUserWaypoint() then
            livePinID = nil
            StopArrivalWatch()
            WayPinsMap:RefreshWorldMap()
            WayPinsMap:UpdateMinimapPins()
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:RefreshRows()
            end
            return
        end
        local dist = C_Navigation.GetDistance()
        if dist and dist > 0 and dist < ARRIVE_YARDS then
            ClearLiveWaypoint()
            return
        end
        local pin = ns.WayPins:GetPin(livePinID)
        if not pin then
            ClearLiveWaypoint()
            return
        end
        local mapID, px, py = Location.GetPlayerLocation()
        if mapID and tonumber(pin.mapID) == mapID and px then
            if Location.IsWithinRadius(pin.x, pin.y, px, py, 1.6) then
                ClearLiveWaypoint()
            end
        end
    end)
end

function WayPinsMap:GetLivePinID()
    return livePinID
end

function WayPinsMap:GetSoloPinID()
    return soloPinID
end

function WayPinsMap:ToggleSolo(pinID)
    if soloPinID == pinID then
        soloPinID = nil
    else
        soloPinID = pinID
    end
    self:Refresh()
    if ns.UI and ns.UI.RefreshWayPinsTab then
        ns.UI.RefreshWayPinsTab()
    end
end

function WayPinsMap:ClearSolo()
    if not soloPinID then return end
    soloPinID = nil
    self:Refresh()
    if ns.UI and ns.UI.RefreshWayPinsTab then
        ns.UI.RefreshWayPinsTab()
    end
end

function WayPinsMap:TrackPin(pin)
    if type(pin) ~= "table" or not pin.mapID then
        return false
    end
    local set = Location.SetWaypoint(pin.mapID, pin.x, pin.y, PERCENT_COORDS)
    if not set then
        return false
    end
    livePinID = pin.id
    StartArrivalWatch()
    self:RefreshWorldMap()
    self:UpdateMinimapPins()
    if ns.WayPinsCompanion then
        ns.WayPinsCompanion:RefreshRows()
    end
    return true
end

local function PinMenu(owner, data)
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateButton(L["WAYPINS_GO"], function()
            WayPinsMap:TrackPin(data)
        end)
        rootDescription:CreateButton(EDIT, function()
            ns.UI.OpenWayPinDialog(data)
        end)
        rootDescription:CreateButton(L["WAYPINS_ADD_TO_ZONE"], function()
            ns.WayPins:AttachToZoneNotes(data.id)
        end)
        if soloPinID == data.id then
            rootDescription:CreateButton(L["WAYPINS_SHOW_ALL"], function()
                WayPinsMap:ClearSolo()
            end)
        else
            rootDescription:CreateButton(L["WAYPINS_ONLY_THIS"], function()
                WayPinsMap:ToggleSolo(data.id)
            end)
        end
        rootDescription:CreateButton(DELETE, function()
            ns.WayPins:Remove(data.id)
        end)
    end)
end

local function AcquireWorldPin()
    for _, pin in ipairs(worldPinPool) do
        if not pin._inUse then
            return pin
        end
    end
    local btn = CreateFrame("Button", nil, WorldMapFrame:GetCanvas())
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetFrameStrata("HIGH")
    Visual.Attach(btn)

    btn:SetScript("OnEnter", function(myself)
        local data = myself.pinData
        if not data then return end
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(data.title or L["WAYPINS_UNTITLED"], 1, 1, 1)
        GameTooltip:AddLine(L["WAYPINS_MAP_TT"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:SetScript("OnClick", function(myself, button)
        local data = myself.pinData
        if not data then return end
        if button == "RightButton" then
            PinMenu(myself, data)
            return
        end
        WayPinsMap:TrackPin(data)
    end)

    tinsert(worldPinPool, btn)
    return btn
end

function WayPinsMap:RefreshWorldMap()
    for _, pin in ipairs(worldPins) do
        pin._inUse = false
        Visual.Hide(pin)
    end
    wipe(worldPins)

    if not Visual.ShowWorld() then return end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        return
    end
    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return end

    local mapID = WorldMapFrame:GetMapID()
    local pins = ns.WayPins:GetForMap(mapID)
    local cw, ch = canvas:GetWidth(), canvas:GetHeight()
    if cw == 0 or ch == 0 then return end

    for _, data in ipairs(pins) do
        if PinVisible(data) then
            local x = (data.x or 0) / 100
            local y = (data.y or 0) / 100
            if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                local pin = AcquireWorldPin()
                pin:SetParent(canvas)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", canvas, "TOPLEFT", x * cw, -y * ch)
                pin.pinData = data
                pin._inUse = true
                Visual.Apply(pin, data, {
                    size = Visual.WorldSize(data),
                    tracked = livePinID == data.id,
                })
                pin:Show()
                tinsert(worldPins, pin)
            end
        end
    end
end

local function AcquireMinimapPin()
    for _, pin in ipairs(minimapPinPool) do
        if not pin._inUse then
            return pin
        end
    end
    local btn = CreateFrame("Button", nil, Minimap)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(12)
    btn:EnableMouse(true)
    Visual.Attach(btn)

    btn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(myself.pinData and myself.pinData.title or L["WAYPINS_UNTITLED"], 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:SetScript("OnClick", function(myself)
        if myself.pinData then
            WayPinsMap:TrackPin(myself.pinData)
        end
    end)

    tinsert(minimapPinPool, btn)
    return btn
end

function WayPinsMap:UpdateMinimapPins()
    for _, pin in ipairs(minimapPins) do
        pin._inUse = false
        Visual.Hide(pin)
    end
    wipe(minimapPins)

    if not Visual.ShowMinimap() then return end

    local mapID, px, py = Location.GetPlayerLocation()
    if not mapID or not px then return end

    local pins = ns.WayPins:GetForMap(mapID)
    if #pins == 0 then return end

    local view = C_Minimap.GetViewRadius()
    if not view or view <= 0 then
        view = 70
    end
    local rotate = GetCVar("rotateMinimap") == "1"
    local facing = rotate and (GetPlayerFacing() or 0) or 0
    local radiusPx = Minimap:GetWidth() / 2 - 4
    local pinSize = Visual.MinimapDefault()

    for _, data in ipairs(pins) do
        if PinVisible(data) then
            local distYards = WorldDistanceYards(mapID, data.x, data.y, px, py)
            local mag
            if distYards then
                if distYards > view then
                    mag = nil
                else
                    mag = distYards / view
                end
            else
                local distPct = Location.DistanceMapPercent(data.x, data.y, px, py)
                if distPct and distPct <= FALLBACK_MAP_PERCENT then
                    mag = distPct / FALLBACK_MAP_PERCENT
                end
            end
            if mag then
                local mapDx = (data.x - px)
                local mapDy = (data.y - py)
                local len = sqrt(mapDx * mapDx + mapDy * mapDy)
                local ux, uy = 0, 0
                if len > 0.0001 then
                    ux = mapDx / len
                    uy = -mapDy / len
                    if rotate then
                        local c, s = cos(facing), sin(facing)
                        local rx = ux * c + uy * s
                        local ry = -ux * s + uy * c
                        ux, uy = rx, ry
                    end
                end
                local pin = AcquireMinimapPin()
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", Minimap, "CENTER", ux * mag * radiusPx, uy * mag * radiusPx)
                pin.pinData = data
                pin._inUse = true
                Visual.Apply(pin, data, {
                    size = pinSize,
                    tracked = livePinID == data.id,
                })
                pin:SetAlpha(1.0 - (mag * 0.35))
                pin:Show()
                tinsert(minimapPins, pin)
            end
        end
    end
end

local function EnsureMinimapTicker()
    if minimapTicker then return end
    minimapTicker = C_Timer.NewTicker(0.2, function()
        WayPinsMap:UpdateMinimapPins()
    end)
end

local function PlacePinAtCursor()
    if not WorldMapFrame then return end
    local sc = WorldMapFrame.ScrollContainer
    if not sc or not sc.GetNormalizedCursorPosition then return end
    local x, y = sc:GetNormalizedCursorPosition()
    local mapID = WorldMapFrame:GetMapID()
    if not mapID or not x or not y then return end
    if x <= 0 or x >= 1 or y <= 0 or y >= 1 then return end
    ns.UI.OpenWayPinDialog({
        mapID  = mapID,
        x      = x * 100,
        y      = y * 100,
        source = "map",
    })
end

local function OpenWayPinsTab()
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "waypins")
end

local function MapButtonMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(L["TAB_WAYPINS"])
        rootDescription:CreateCheckbox(L["WAYPINS_SHOW_WORLD"], function()
            return Visual.ShowWorld()
        end, function()
            ns.db.global.waypinShowWorld = not Visual.ShowWorld()
            WayPinsMap:Refresh()
        end)
        rootDescription:CreateCheckbox(L["WAYPINS_SHOW_MINIMAP"], function()
            return Visual.ShowMinimap()
        end, function()
            ns.db.global.waypinShowMinimap = not Visual.ShowMinimap()
            WayPinsMap:Refresh()
        end)
        if soloPinID then
            rootDescription:CreateButton(L["WAYPINS_SHOW_ALL"], function()
                WayPinsMap:ClearSolo()
            end)
        end
        rootDescription:CreateDivider()
        rootDescription:CreateButton(L["WAYPINS_ADD_HERE"], function()
            local mapID, x, y = Location.GetPlayerLocation()
            if mapID and x then
                ns.UI.OpenWayPinDialog({
                    mapID  = mapID,
                    x      = x,
                    y      = y,
                    source = "manual",
                })
            end
        end)
        rootDescription:CreateButton(L["WAYPINS_OPEN_TAB"], function()
            OpenWayPinsTab()
        end)
    end)
end

local function EnsureMapButton()
    if mapButton or not WorldMapFrame then return end
    mapButton = CreateFrame("Button", "OneWoW_WayPinsMapButton", WorldMapFrame)
    mapButton:SetSize(28, 28)
    mapButton:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -12, -64)
    mapButton:SetFrameStrata("HIGH")
    mapButton:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 20)
    mapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local tex = mapButton:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    OneWoW.OverlayIcons:ApplyToTexture(tex, "icon-pin")
    mapButton.icon = tex

    mapButton:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_LEFT")
        GameTooltip:SetText(L["TAB_WAYPINS"], 1, 1, 1)
        GameTooltip:AddLine(L["WAYPINS_MAP_BTN_TT"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    mapButton:SetScript("OnLeave", GameTooltip_Hide)
    mapButton:SetScript("OnClick", function(myself)
        MapButtonMenu(myself)
    end)
end

local function WireWorldMap()
    if mapHooked or not WorldMapFrame then return end
    mapHooked = true
    EnsureMapButton()

    hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
        WayPinsMap:RefreshWorldMap()
    end)
    WorldMapFrame:HookScript("OnShow", function()
        WayPinsMap:RefreshWorldMap()
    end)
    WorldMapFrame:HookScript("OnHide", function()
        for _, pin in ipairs(worldPins) do
            Visual.Hide(pin)
        end
    end)

    local canvas = WorldMapFrame:GetCanvas()
    if canvas then
        canvas:HookScript("OnSizeChanged", function()
            WayPinsMap:RefreshWorldMap()
        end)
    end

    local sc = WorldMapFrame.ScrollContainer
    if sc then
        local downX, downY
        sc:HookScript("OnMouseDown", function(myself, button)
            if button ~= "RightButton" then return end
            downX, downY = myself:GetNormalizedCursorPosition()
        end)
        sc:HookScript("OnMouseUp", function(myself, button)
            if button ~= "RightButton" then return end
            local x, y = myself:GetNormalizedCursorPosition()
            if not x or not y then return end
            if downX and (abs(x - downX) > 0.008 or abs(y - downY) > 0.008) then
                return
            end
            MenuUtil.CreateContextMenu(myself, function(_, rootDescription)
                rootDescription:CreateButton(L["WAYPINS_ADD_HERE"], function()
                    PlacePinAtCursor()
                end)
            end)
        end)
    end
end

function WayPinsMap:Refresh()
    self:RefreshWorldMap()
    self:UpdateMinimapPins()
end

function WayPinsMap:Initialize()
    if initialized then return end
    initialized = true

    local function Arm()
        WireWorldMap()
        EnsureMinimapTicker()
        self:Refresh()
    end

    if WorldMapFrame then
        Arm()
    else
        OneWoW_Notes:RegisterAddonLoadedWatcher("Blizzard_WorldMap", Arm)
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("USER_WAYPOINT_UPDATED")
    f:RegisterEvent("SUPER_TRACKING_CHANGED")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("ZONE_CHANGED")
    f:SetScript("OnEvent", function(_, event)
        if event == "USER_WAYPOINT_UPDATED" or event == "SUPER_TRACKING_CHANGED" then
            if livePinID and not C_Map.HasUserWaypoint() then
                livePinID = nil
                StopArrivalWatch()
                self:Refresh()
                if ns.WayPinsCompanion then
                    ns.WayPinsCompanion:RefreshRows()
                end
            end
        else
            self:UpdateMinimapPins()
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:Sync()
            end
        end
    end)
end
