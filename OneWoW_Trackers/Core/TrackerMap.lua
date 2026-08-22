local _, ns = ...

ns.TrackerMap = {}
local TM = ns.TrackerMap

local Location = OneWoW.Location

local pairs, ipairs, format = pairs, ipairs, format
local tinsert, wipe = tinsert, wipe
local math_atan2, math_cos, math_sin = math.atan2, math.cos, math.sin

local initialized = false
local MINIMAP_PIN_SIZE = 16
-- Pins fade out to nothing over this much map-percent distance.
local MINIMAP_PIN_RANGE = 50
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
local activeMinimapPins = {}

function TM:UpdateMinimapPins()
    for _, pin in ipairs(activeMinimapPins) do
        pin:Hide()
    end
    wipe(activeMinimapPins)

    local TD = ns.TrackerData
    if not TD then return end

    local currentMap, playerX, playerY = Location.GetPlayerLocation()
    if not currentMap or not playerX then return end

    local lists = TD:GetListsDB()
    for listID, list in pairs(lists) do
        if list.pinned then
        for _, sec in ipairs(list.sections) do
            for _, step in ipairs(sec.steps or {}) do
                if step.mapID and tonumber(step.mapID) == currentMap and step.coordX and step.coordY then
                    local completed = TD:IsStepComplete(listID, sec.key, step.key)
                    if not completed then
                        self:AddMinimapPin(step.coordX, step.coordY, playerX, playerY, step.label)
                    end
                end

                for _, obj in ipairs(step.objectives or {}) do
                    if obj.type == "coordinates" and obj.params then
                        local objMapID = tonumber(obj.params.mapID)
                        if objMapID == currentMap and obj.params.x and obj.params.y then
                            local completed = TD:GetObjectiveProgress(listID, sec.key, step.key, obj.key)
                            if not completed then
                                local label = obj.description ~= "" and obj.description or step.label
                                self:AddMinimapPin(obj.params.x, obj.params.y, playerX, playerY, label)
                            end
                        end
                    end
                end
            end
        end
        end
    end
end

function TM:AddMinimapPin(targetX, targetY, playerX, playerY, label)
    local dist = Location.DistanceMapPercent(targetX, targetY, playerX, playerY)
    if not dist or dist > MINIMAP_PIN_RANGE then return end

    local pin = self:GetMinimapPin()
    if not pin then return end

    local angle = math_atan2(targetY - playerY, targetX - playerX)
    local minimapRadius = Minimap:GetWidth() / 2

    local scale = dist / MINIMAP_PIN_RANGE
    local pinX = math_cos(angle) * minimapRadius * scale
    local pinY = -math_sin(angle) * minimapRadius * scale

    pin:ClearAllPoints()
    pin:SetPoint("CENTER", Minimap, "CENTER", pinX, pinY)
    pin:SetAlpha(1.0 - (dist / 100))
    pin:Show()

    pin.label = label
    pin:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(label or "Waypoint", 1, 0.82, 0)
        GameTooltip:AddLine(format("Distance: ~%.0f%%", dist), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", GameTooltip_Hide)

    tinsert(activeMinimapPins, pin)
end

function TM:GetMinimapPin()
    for _, pin in ipairs(minimapPinPool) do
        if not pin:IsShown() then
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
    pin.icon = icon

    pin:EnableMouse(true)
    pin:Hide()

    tinsert(minimapPinPool, pin)
    return pin
end
