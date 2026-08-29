local _, ns = ...

ns.TrackerMap = {}
local TM = ns.TrackerMap

local Location = OneWoW.Location

local pairs, ipairs, next = pairs, ipairs, next
local tinsert = tinsert
local abs, sqrt = math.abs, math.sqrt
local GetTime = GetTime

local C_Minimap = C_Minimap
local GetCVar, GetPlayerFacing = GetCVar, GetPlayerFacing
local Minimap = Minimap

local initialized = false
local MINIMAP_PIN_SIZE = 16
local PERCENT_FMT = "percent"
local TrackerDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)

function TrackerDataProviderMixin:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate("TrackerWorldMapPinTemplate")
end

function TrackerDataProviderMixin:RefreshAllData()
    self:RemoveAllData()

    local mapID = self:GetMap():GetMapID()
    if not mapID then return end

    local TD = ns.TrackerData
    if not TD then return end

    local lists = TD:GetListsDB()
    for listID, list in pairs(lists) do
        if list.pinned then
        for _, sec in ipairs(list.sections) do
            for _, step in ipairs(sec.steps or {}) do
                if step.mapID and tonumber(step.mapID) == mapID and step.coordX and step.coordY then
                    local completed = TD:IsStepComplete(listID, sec.key, step.key)
                    local x = (step.coordX or 0) / 100
                    local y = (step.coordY or 0) / 100

                    if x > 0 and x < 1 and y > 0 and y < 1 then
                        local pin = self:GetMap():AcquirePin("TrackerWorldMapPinTemplate", {
                            listID = listID,
                            listTitle = list.title,
                            sectionKey = sec.key,
                            sectionLabel = sec.label,
                            stepKey = step.key,
                            label = step.label,
                            stepDesc = step.description,
                            x = step.coordX,
                            y = step.coordY,
                            completed = completed,
                        })
                        pin:SetPosition(x, y)
                    end
                end

                for _, obj in ipairs(step.objectives or {}) do
                    if obj.type == "coordinates" and obj.params then
                        local objMapID = tonumber(obj.params.mapID)
                        if objMapID == mapID and obj.params.x and obj.params.y then
                            local completed = TD:GetObjectiveProgress(listID, sec.key, step.key, obj.key)
                            local x = (obj.params.x or 0) / 100
                            local y = (obj.params.y or 0) / 100

                            if x > 0 and x < 1 and y > 0 and y < 1 then
                                local pin = self:GetMap():AcquirePin("TrackerWorldMapPinTemplate", {
                                    listID = listID,
                                    listTitle = list.title,
                                    sectionKey = sec.key,
                                    sectionLabel = sec.label,
                                    stepKey = step.key,
                                    objKey = obj.key,
                                    label = obj.description ~= "" and obj.description or step.label,
                                    stepDesc = "",
                                    x = obj.params.x,
                                    y = obj.params.y,
                                    completed = completed,
                                })
                                pin:SetPosition(x, y)
                            end
                        end
                    end
                end
            end
        end
        end
    end
end

function TM:Initialize()
    if initialized then return end
    initialized = true

    if not WorldMapFrame then return end

    local pinFrame = CreateFrame("Frame", "TrackerWorldMapPinTemplate", nil)
    pinFrame:Hide()

    WorldMapFrame:AddDataProvider(CreateFromMixins(TrackerDataProviderMixin))
end

function TM:RefreshWorldMap()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        for _, provider in ipairs(WorldMapFrame.dataProviders or {}) do
            if provider.RefreshAllData and provider.RemoveAllData then
                local isOurs = false
                local ok = pcall(function()
                    isOurs = (provider.RemoveAllData == TrackerDataProviderMixin.RemoveAllData)
                end)
                if ok and isOurs then
                    provider:RefreshAllData()
                    break
                end
            end
        end
    end
end

local minimapPinPool = {}
local minimapActive = {}
local minimapDirty = true
local lastMinimapMapID
local lastMinimapSync = 0
local minimapDriver

local function MinimapPinKey(listID, secKey, stepKey, objKey)
    if objKey then
        return listID .. "\0" .. secKey .. "\0" .. stepKey .. "\0" .. objKey
    end
    return listID .. "\0" .. secKey .. "\0" .. stepKey
end

local function AcquireMinimapPin()
    for _, pin in ipairs(minimapPinPool) do
        if not pin._inUse then
            return pin
        end
    end

    local pin = CreateFrame("Button", nil, Minimap)
    pin:SetSize(MINIMAP_PIN_SIZE, MINIMAP_PIN_SIZE)
    pin:SetFrameStrata("MEDIUM")
    pin:SetFrameLevel(10)

    local icon = pin:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAtlas("Waypoint-MapPin-Untracked")
    icon:SetTexelSnappingBias(0)
    icon:SetSnapToPixelGrid(false)
    pin.icon = icon

    pin:EnableMouse(true)
    pin:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(myself.label or MAP_PIN, 1, 0.82, 0)
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", GameTooltip_Hide)
    pin:Hide()

    tinsert(minimapPinPool, pin)
    return pin
end

local function ReleaseMinimapPin(pin)
    pin._inUse = false
    pin.label = nil
    pin.targetX = nil
    pin.targetY = nil
    pin:Hide()
end

local function FloatOnMinimapEdge(nx, ny)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
        local ax, ay = abs(nx), abs(ny)
        local m = ax > ay and ax or ay
        if m > 1 then
            return nx / m, ny / m
        end
        return nx, ny
    end
    local mag2 = nx * nx + ny * ny
    if mag2 > 1 then
        local mag = sqrt(mag2)
        return nx / mag, ny / mag
    end
    return nx, ny
end

local function CollectMinimapTargets(mapID)
    local TD = ns.TrackerData
    if not TD then return end

    local lists = TD:GetListsDB()
    for listID, list in pairs(lists) do
        if list.pinned then
            for _, sec in ipairs(list.sections) do
                for _, step in ipairs(sec.steps or {}) do
                    if step.mapID and tonumber(step.mapID) == mapID and step.coordX and step.coordY then
                        if not TD:IsStepComplete(listID, sec.key, step.key) then
                            local key = MinimapPinKey(listID, sec.key, step.key)
                            local pin = minimapActive[key]
                            if not pin then
                                pin = AcquireMinimapPin()
                                pin._inUse = true
                                minimapActive[key] = pin
                            end
                            pin._keep = true
                            pin.targetX = step.coordX
                            pin.targetY = step.coordY
                            pin.label = step.label
                        end
                    end

                    for _, obj in ipairs(step.objectives or {}) do
                        if obj.type == "coordinates" and obj.params then
                            local objMapID = tonumber(obj.params.mapID)
                            if objMapID == mapID and obj.params.x and obj.params.y then
                                if not TD:GetObjectiveProgress(listID, sec.key, step.key, obj.key) then
                                    local key = MinimapPinKey(listID, sec.key, step.key, obj.key)
                                    local pin = minimapActive[key]
                                    if not pin then
                                        pin = AcquireMinimapPin()
                                        pin._inUse = true
                                        minimapActive[key] = pin
                                    end
                                    pin._keep = true
                                    pin.targetX = obj.params.x
                                    pin.targetY = obj.params.y
                                    pin.label = obj.description ~= "" and obj.description or step.label
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function SyncMinimapPinSet(mapID)
    for _, pin in pairs(minimapActive) do
        pin._keep = false
    end
    if mapID then
        CollectMinimapTargets(mapID)
    end
    for key, pin in pairs(minimapActive) do
        if not pin._keep then
            ReleaseMinimapPin(pin)
            minimapActive[key] = nil
        end
    end
end

local function PositionMinimapPins(mapID, px, py)
    local view = C_Minimap.GetViewRadius()
    if not view or view <= 0 or not px then
        for _, pin in pairs(minimapActive) do
            pin:Hide()
        end
        return
    end

    local rotate = GetCVar("rotateMinimap") == "1"
    local facing = rotate and GetPlayerFacing() or nil
    local radiusPx = Minimap:GetWidth() / 2 - 4

    for _, pin in pairs(minimapActive) do
        local dWx, dWy = Location.WorldDelta(mapID, pin.targetX, pin.targetY, px, py, PERCENT_FMT)
        local nx, ny
        if dWx then
            nx, ny = Location.MinimapOffset(dWx, dWy, view, facing)
        end
        if nx then
            local mag = sqrt(nx * nx + ny * ny)
            nx, ny = FloatOnMinimapEdge(nx, ny)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", Minimap, "CENTER", nx * radiusPx, ny * radiusPx)
            if mag > 1 then
                mag = 1
            end
            pin:SetAlpha(1.0 - (mag * 0.35))
            pin:Show()
        else
            pin:Hide()
        end
    end
end

function TM:UpdateMinimapPins()
    if not Minimap:IsVisible() then
        if next(minimapActive) then
            SyncMinimapPinSet(nil)
        end
        return
    end

    local mapID, px, py = Location.GetPlayerLocation()
    local now = GetTime()
    if minimapDirty or mapID ~= lastMinimapMapID or (now - lastMinimapSync) > 0.5 then
        SyncMinimapPinSet(mapID)
        lastMinimapMapID = mapID
        lastMinimapSync = now
        minimapDirty = false
    end

    PositionMinimapPins(mapID, px, py)
end

function TM:MarkMinimapDirty()
    minimapDirty = true
end

function TM:StartMinimapDriver()
    if minimapDriver then return end
    minimapDriver = CreateFrame("Frame")
    minimapDriver:SetScript("OnUpdate", function()
        TM:UpdateMinimapPins()
    end)
end
