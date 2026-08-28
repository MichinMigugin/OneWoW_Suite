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
local GetCursorPosition, UIParent = GetCursorPosition, UIParent
local OpenWorldMap = OpenWorldMap
local LibStub = LibStub

-- ============================================================================
-- WayPinsMap
-- ============================================================================
-- World-map canvas buttons + minimap radar. Minimap placement uses world-yard
-- distance against C_Minimap.GetViewRadius so a landmark stays put while you
-- walk; map-percent used to be treated as the whole minimap radius, which
-- glued every pin to the player. Clicking a pin sets the Blizzard user
-- waypoint. Arrival clears that live track only.
-- The map-chrome button parents to GetCanvasContainer like ATT and sits under
-- ATT's button when that addon is loaded; otherwise it uses ATT's Retail slot.
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
local hoverPinID = nil
local arrivalTicker = nil
local minimapTicker = nil
local mapHooked = false
local mapButton
local placingPin = false
local placeCatcher
local placeGhost

-- ATT's retail world-map button: parent GetCanvasContainer(), TOPRIGHT (-1, -65), 36x36.
local ATT_MAP_BTN_X = -1
local ATT_MAP_BTN_Y = -65
local ATT_MAP_BTN_GAP = -2

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

local previewDraft

local function PinsForMap(mapID)
    local pins = ns.WayPins:GetForMap(mapID)
    if not previewDraft or tonumber(previewDraft.mapID) ~= tonumber(mapID) then
        return pins
    end
    if previewDraft.id then
        for i, data in ipairs(pins) do
            if data.id == previewDraft.id then
                pins[i] = previewDraft
                return pins
            end
        end
    end
    tinsert(pins, previewDraft)
    return pins
end

--- Overlay the pin editor draft onto the maps without writing SavedVariables.
---@param draft table|nil
function WayPinsMap:SetPreviewDraft(draft)
    previewDraft = draft
    self:RefreshWorldMap()
    self:UpdateMinimapPins()
    if ns.UI and ns.UI.RefreshWayPinsTab then
        ns.UI.RefreshWayPinsTab()
    end
end

function WayPinsMap:ClearPreviewDraft()
    if not previewDraft then return end
    previewDraft = nil
    self:RefreshWorldMap()
    self:UpdateMinimapPins()
    if ns.UI and ns.UI.RefreshWayPinsTab then
        ns.UI.RefreshWayPinsTab()
    end
end

---@return table|nil
function WayPinsMap:GetPreviewDraft()
    return previewDraft
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

local function WorldPinPaintOpts(data)
    local hover = hoverPinID == data.id
    local size = Visual.WorldSize(data)
    if hover then
        size = size * 1.2
    end
    return {
        size = size,
        tracked = livePinID == data.id or hover,
    }
end

--- Glow / enlarge a world-map pin (Map Legend hover). Nil clears.
---@param pinID string|nil
function WayPinsMap:SetHoverPin(pinID)
    if hoverPinID == pinID then
        return
    end
    hoverPinID = pinID
    for _, pin in ipairs(worldPins) do
        local data = pin.pinData
        if data then
            Visual.Apply(pin, data, WorldPinPaintOpts(data))
        end
    end
end

function WayPinsMap:ClearHoverPin()
    self:SetHoverPin(nil)
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
    if ns.WayPinsMapPanel then
        ns.WayPinsMapPanel:RefreshRows()
    end
    return true
end

function WayPinsMap:ConfirmDelete(pin)
    if type(pin) ~= "table" or not pin.id then return end
    local pinID = pin.id
    local title = pin.title or L["WAYPINS_UNTITLED"]
    local result = OneWoW_GUI:CreateConfirmDialog({
        name = "OneWoW_NotesDeleteWayPinConfirm",
        title = L["DIALOG_CONFIRM_DELETE"],
        message = string.format(L["POPUP_DELETE_WAYPIN"], title),
        buttons = {
            {
                text = DELETE,
                color = { 0.8, 0.2, 0.2 },
                onClick = function(dlg)
                    ns.WayPins:Remove(pinID)
                    dlg:Hide()
                end,
            },
            { text = CANCEL, onClick = function(dlg) dlg:Hide() end },
        },
    })
    result.frame:Show()
end

--- Open the world map on this pin's zone, switch to Map Legend, and set a live waypoint.
--- Does not hide other pins.
---@param pin table
function WayPinsMap:ShowOnMap(pin)
    if type(pin) ~= "table" or not pin.mapID then return end
    OpenWorldMap(pin.mapID)
    WorldMapFrame:SetMapID(pin.mapID)
    QuestMapFrame:SetDisplayMode(QuestLogDisplayMode.MapLegend)
    self:TrackPin(pin)
end

function WayPinsMap:OpenPinTab(pinID)
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "waypins")
    if pinID and ns.UI.SelectWayPin then
        ns.UI.SelectWayPin(pinID)
    end
end

---@param owner Frame
---@param data table
function WayPinsMap:ShowListMenu(owner, data)
    if not data then return end
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateButton(L["WAYPINS_MENU_GO"], function()
            WayPinsMap:TrackPin(data)
        end)
        rootDescription:CreateButton(SHOW_MAP, function()
            WayPinsMap:ShowOnMap(data)
        end)
        rootDescription:CreateButton(EDIT, function()
            ns.UI.OpenWayPinDialog(data)
        end)
        rootDescription:CreateButton(L["WAYPINS_OPEN_TAB"], function()
            WayPinsMap:OpenPinTab(data.id)
        end)
        rootDescription:CreateButton(DELETE, function()
            WayPinsMap:ConfirmDelete(data)
        end)
    end)
end

---@param owner Frame
---@param data table
function WayPinsMap:ShowPinMenu(owner, data)
    if not data then return end
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateButton(L["WAYPINS_MENU_GO"], function()
            WayPinsMap:TrackPin(data)
        end)
        rootDescription:CreateButton(SHOW_MAP, function()
            WayPinsMap:ShowOnMap(data)
        end)
        rootDescription:CreateButton(EDIT, function()
            ns.UI.OpenWayPinDialog(data)
        end)
        rootDescription:CreateButton(L["WAYPINS_OPEN_TAB"], function()
            WayPinsMap:OpenPinTab(data.id)
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
            WayPinsMap:ConfirmDelete(data)
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
            WayPinsMap:ShowPinMenu(myself, data)
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
    local pins = PinsForMap(mapID)
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
                Visual.Apply(pin, data, WorldPinPaintOpts(data))
                pin._inUse = true
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

    local pins = PinsForMap(mapID)
    if #pins == 0 then return end

    local view = C_Minimap.GetViewRadius()
    if not view or view <= 0 then
        view = 70
    end
    local rotate = GetCVar("rotateMinimap") == "1"
    local facing = rotate and (GetPlayerFacing() or 0) or 0
    local radiusPx = Minimap:GetWidth() / 2 - 4
    local animate = Visual.MinimapAnimate()

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
                Visual.Apply(pin, data, {
                    size = Visual.MinimapSize(data),
                    tracked = livePinID == data.id,
                    animate = animate,
                })
                pin._inUse = true
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
    if not WorldMapFrame then return false end
    local sc = WorldMapFrame.ScrollContainer
    if not sc then return false end
    local x, y = sc:GetNormalizedCursorPosition()
    local mapID = WorldMapFrame:GetMapID()
    if not mapID or not x or not y then return false end
    if x <= 0 or x >= 1 or y <= 0 or y >= 1 then return false end
    ns.UI.OpenWayPinDialog({
        mapID  = mapID,
        x      = x * 100,
        y      = y * 100,
        source = "map",
    })
    return true
end

local function StopPlaceMode()
    placingPin = false
    if placeCatcher then
        placeCatcher:Hide()
        placeCatcher:EnableMouse(false)
        placeCatcher:EnableKeyboard(false)
    end
    if placeGhost then
        placeGhost:Hide()
    end
end

local function EnsurePlaceChrome()
    if placeGhost then return end
    placeGhost = CreateFrame("Frame", nil, UIParent)
    placeGhost:SetSize(28, 44)
    placeGhost:SetFrameStrata("TOOLTIP")
    placeGhost:EnableMouse(false)
    local gtex = placeGhost:CreateTexture(nil, "OVERLAY")
    gtex:SetSize(24, 24)
    gtex:SetPoint("TOP", 0, 0)
    OneWoW.OverlayIcons:ApplyToTexture(gtex, "icon-pin")
    placeGhost.icon = gtex
    local coords = OneWoW_GUI:CreateFS(placeGhost, 11)
    coords:SetPoint("TOP", gtex, "BOTTOM", 0, -2)
    coords:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    placeGhost.coords = coords
    placeGhost:Hide()

    local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
    placeCatcher = CreateFrame("Button", nil, sc or UIParent)
    placeCatcher:Hide()
    placeCatcher:SetAllPoints()
    placeCatcher:SetFrameStrata("HIGH")
    placeCatcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    placeCatcher:EnableMouse(false)
    placeCatcher:SetScript("OnUpdate", function()
        if not placingPin then return end
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        placeGhost:ClearAllPoints()
        placeGhost:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cx / scale, cy / scale + 8)
        local mapSC = WorldMapFrame and WorldMapFrame.ScrollContainer
        local mapID = WorldMapFrame and WorldMapFrame:GetMapID()
        if mapSC and mapID then
            local x, y = mapSC:GetNormalizedCursorPosition()
            if x and y and x > 0 and x < 1 and y > 0 and y < 1 then
                placeGhost.coords:SetText(string.format("%d  %.1f, %.1f", mapID, x * 100, y * 100))
            else
                placeGhost.coords:SetText("")
            end
        end
    end)
    placeCatcher:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            StopPlaceMode()
            return
        end
        if PlacePinAtCursor() then
            StopPlaceMode()
        end
    end)
    placeCatcher:SetScript("OnKeyDown", function(myself, key)
        if key == "ESCAPE" then
            myself:SetPropagateKeyboardInput(false)
            StopPlaceMode()
            return
        end
        myself:SetPropagateKeyboardInput(true)
    end)
end

local function StartPlaceMode()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    EnsurePlaceChrome()
    local sc = WorldMapFrame.ScrollContainer
    if sc and placeCatcher:GetParent() ~= sc then
        placeCatcher:SetParent(sc)
        placeCatcher:SetAllPoints()
    end
    placingPin = true
    placeCatcher:SetFrameLevel((sc and sc:GetFrameLevel() or 0) + 50)
    placeCatcher:EnableMouse(true)
    placeCatcher:EnableKeyboard(true)
    placeCatcher:Show()
    placeGhost:Show()
end

local function PaintMapButtonIcon()
    if not mapButton then return end
    mapButton.icon:SetTexture(OneWoW_GUI:GetBrandIcon(OneWoW_GUI:GetSetting("minimap.theme")))
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
        rootDescription:CreateCheckbox(L["WAYPINS_SHOW_MAP_PANEL"], function()
            return ns.db.global.waypinShowMapPanel ~= false
        end, function()
            ns.db.global.waypinShowMapPanel = not (ns.db.global.waypinShowMapPanel ~= false)
            if ns.WayPinsMapPanel then
                ns.WayPinsMapPanel:Sync()
            end
        end)
        if soloPinID then
            rootDescription:CreateButton(L["WAYPINS_SHOW_ALL"], function()
                WayPinsMap:ClearSolo()
            end)
        end
        rootDescription:CreateDivider()
        rootDescription:CreateButton(L["WAYPINS_ADD_PIN"], function()
            C_Timer.After(0, StartPlaceMode)
        end)
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
        rootDescription:CreateButton(L["WAYPINS_FIND_LOCATION"], function()
            ns.UI.OpenWayPinFindDialog()
        end)
        rootDescription:CreateButton(L["WAYPINS_OPEN_TAB"], function()
            WayPinsMap:OpenPinTab()
        end)
    end)
end

local function MapButtonParent()
    return WorldMapFrame:GetCanvasContainer() or WorldMapFrame
end

local function IsATTMapButton(frame)
    if not frame or not frame:IsShown() then
        return false
    end
    local name = frame:GetName()
    if type(name) == "string" and name:find("AllTheThings", 1, true) then
        return true
    end
    local tex = frame.texture
    if tex then
        local path = tex:GetTexture()
        if type(path) == "string" and path:find("AllTheThings", 1, true) then
            return true
        end
    end
    return false
end

local function ScanChildrenForATT(parent)
    if not parent then
        return nil
    end
    local children = { parent:GetChildren() }
    for i = 1, #children do
        if IsATTMapButton(children[i]) then
            return children[i]
        end
    end
    return nil
end

local function FindATTWorldMapButton()
    local named = _G["AllTheThings-WorldMap"]
    if IsATTMapButton(named) then
        return named
    end
    local krowi = LibStub("Krowi_WorldMapButtons-1.4", true)
    if krowi and krowi.Buttons then
        for _, btn in ipairs(krowi.Buttons) do
            if IsATTMapButton(btn) then
                return btn
            end
        end
    end
    return ScanChildrenForATT(WorldMapFrame)
        or ScanChildrenForATT(WorldMapFrame:GetCanvasContainer())
end

local function AnchorMapButton()
    if not mapButton or not WorldMapFrame then return end
    local parent = MapButtonParent()
    if mapButton:GetParent() ~= parent then
        mapButton:SetParent(parent)
    end
    mapButton:ClearAllPoints()
    local att = FindATTWorldMapButton()
    if att then
        mapButton:SetPoint("TOP", att, "BOTTOM", 0, ATT_MAP_BTN_GAP)
    else
        mapButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", ATT_MAP_BTN_X, ATT_MAP_BTN_Y)
    end
    mapButton:SetFrameStrata("HIGH")
    mapButton:SetFrameLevel(parent:GetFrameLevel() + 20)
end

local function EnsureMapButton()
    if mapButton or not WorldMapFrame then return end
    local size = ns.Constants.GUI.WAYPIN_MAP_BUTTON_SIZE
    mapButton = CreateFrame("Button", "OneWoW_WayPinsMapButton", MapButtonParent())
    mapButton:SetSize(size, size)
    mapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local tex = mapButton:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    mapButton.icon = tex
    PaintMapButtonIcon()

    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", mapButton, function()
        PaintMapButtonIcon()
    end)

    mapButton:SetScript("OnEnter", function(myself)
        PaintMapButtonIcon()
        GameTooltip:SetOwner(myself, "ANCHOR_LEFT")
        GameTooltip:SetText(L["TAB_WAYPINS"], 1, 1, 1)
        GameTooltip:AddLine(L["WAYPINS_MAP_BTN_TT"], OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        GameTooltip:Show()
    end)
    mapButton:SetScript("OnLeave", GameTooltip_Hide)
    mapButton:SetScript("OnClick", function(myself)
        if placingPin then
            StopPlaceMode()
        end
        MapButtonMenu(myself)
    end)
    AnchorMapButton()
end

local function WireWorldMap()
    if mapHooked or not WorldMapFrame then return end
    mapHooked = true
    EnsureMapButton()

    hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
        AnchorMapButton()
        WayPinsMap:RefreshWorldMap()
        if ns.WayPinsMapPanel then
            ns.WayPinsMapPanel:Sync()
        end
    end)
    WorldMapFrame:HookScript("OnShow", function()
        C_Timer.After(0, AnchorMapButton)
        PaintMapButtonIcon()
        WayPinsMap:RefreshWorldMap()
        if ns.WayPinsCompanion then
            ns.WayPinsCompanion:PauseForMap()
        end
        if ns.WayPinsMapPanel then
            ns.WayPinsMapPanel:Sync()
        end
    end)
    WorldMapFrame:HookScript("OnHide", function()
        StopPlaceMode()
        hoverPinID = nil
        for _, pin in ipairs(worldPins) do
            Visual.Hide(pin)
        end
        if ns.WayPinsMapPanel then
            ns.WayPinsMapPanel:Hide()
        end
        if ns.WayPinsCompanion then
            ns.WayPinsCompanion:ResumeAfterMap()
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
            if placingPin then return end
            if button ~= "RightButton" then return end
            downX, downY = myself:GetNormalizedCursorPosition()
        end)
        sc:HookScript("OnMouseUp", function(myself, button)
            if placingPin then return end
            if button ~= "RightButton" then return end
            local x, y = myself:GetNormalizedCursorPosition()
            if not x or not y then return end
            if downX and (abs(x - downX) > 0.008 or abs(y - downY) > 0.008) then
                return
            end
            MenuUtil.CreateContextMenu(myself, function(_, rootDescription)
                rootDescription:CreateButton(L["WAYPINS_ADD_PIN"], function()
                    PlacePinAtCursor()
                end)
            end)
        end)
    end

    OneWoW_Notes:RegisterAddonLoadedWatcher("AllTheThings", function()
        AnchorMapButton()
    end)
end

function WayPinsMap:Refresh()
    self:RefreshWorldMap()
    self:UpdateMinimapPins()
    if ns.WayPinsMapPanel then
        ns.WayPinsMapPanel:RefreshRows()
    end
end

function WayPinsMap:ApplyTheme()
    PaintMapButtonIcon()
    self:Refresh()
    if ns.WayPinsMapPanel then
        ns.WayPinsMapPanel:ApplyTheme()
    end
end

function WayPinsMap:Initialize()
    if initialized then return end
    initialized = true

    local function Arm()
        WireWorldMap()
        if ns.WayPinsMapPanel then
            ns.WayPinsMapPanel:Initialize()
        end
        EnsureMinimapTicker()
        self:Refresh()
        if WorldMapFrame:IsShown() then
            PaintMapButtonIcon()
            if ns.WayPinsCompanion then
                ns.WayPinsCompanion:PauseForMap()
            end
            if ns.WayPinsMapPanel then
                ns.WayPinsMapPanel:Sync()
            end
        end
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
