local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.TrackerMap = {}
local TM = ns.TrackerMap

local pairs, ipairs, format = pairs, ipairs, format
local tinsert, tremove, wipe = tinsert, tremove, wipe
local math_sqrt = math.sqrt

local activePins = {}
local minimapPins = {}
local worldMapProvider = nil
local initialized = false

local PIN_TEXTURE_INCOMPLETE = "Interface\\Minimap\\ObjectIconsAtlas"
local PIN_SIZE = 24
local MINIMAP_PIN_SIZE = 16

local TrackerWorldMapPinMixin = {}

function TrackerWorldMapPinMixin:OnLoad()
    self:SetSize(PIN_SIZE, PIN_SIZE)
end

function TrackerWorldMapPinMixin:OnAcquired(pinData)
    self.pinData = pinData
    self:UpdateAppearance()
end

function TrackerWorldMapPinMixin:OnReleased()
    self.pinData = nil
end

function TrackerWorldMapPinMixin:UpdateAppearance()
    if not self.pinData then return end
    local data = self.pinData

    if not self.icon then
        self.icon = self:CreateTexture(nil, "ARTWORK")
        self.icon:SetAllPoints()
    end

    if not self.label then
        self.label = OneWoW_GUI:CreateFS(self, 10)
        self.label:SetPoint("TOP", self, "BOTTOM", 0, -2)
        self.label:SetJustifyH("CENTER")
    end

    local completed = data.completed
    if completed then
        self.icon:SetAtlas("Waypoint-MapPin-Tracked")
        self.icon:SetDesaturated(true)
        self:SetAlpha(0.5)
    else
        self.icon:SetAtlas("Waypoint-MapPin-Untracked")
        self.icon:SetDesaturated(false)
        self:SetAlpha(1.0)
    end

    self.label:SetText(data.label or "")
    if completed then
        self.label:SetTextColor(0.5, 0.5, 0.5)
    else
        self.label:SetTextColor(1, 0.82, 0)
    end
end

function TrackerWorldMapPinMixin:OnMouseEnter()
    if not self.pinData then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.pinData.label or "Waypoint", 1, 1, 1)

    if self.pinData.stepDesc and self.pinData.stepDesc ~= "" then
        GameTooltip:AddLine(self.pinData.stepDesc, 0.7, 0.7, 0.7, true)
    end

    if self.pinData.listTitle then
        GameTooltip:AddDoubleLine("List:", self.pinData.listTitle, 0.5, 0.5, 0.5, 1, 0.82, 0)
    end

    if self.pinData.sectionLabel then
        GameTooltip:AddDoubleLine("Section:", self.pinData.sectionLabel, 0.5, 0.5, 0.5, 0.7, 0.7, 0.7)
    end

    local coordStr = format("%.1f, %.1f", self.pinData.x or 0, self.pinData.y or 0)
    GameTooltip:AddDoubleLine("Coords:", coordStr, 0.5, 0.5, 0.5, 0.7, 0.7, 0.7)

    if self.pinData.completed then
        GameTooltip:AddLine("Completed", 0.4, 0.8, 0.4)
    else
        GameTooltip:AddLine("Incomplete", 1, 0.5, 0.5)
    end

    GameTooltip:Show()
end

function TrackerWorldMapPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

local TrackerDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)

function TrackerDataProviderMixin:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate("TrackerWorldMapPinTemplate")
end

function TrackerDataProviderMixin:RefreshAllData(fromOnShow)
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

    local templateInfo = {
        type = "TrackerWorldMapPinTemplate",
    }

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

local minimapFrame = nil
local minimapPinPool = {}
local activeMinimapPins = {}

function TM:UpdateMinimapPins()
    for _, pin in ipairs(activeMinimapPins) do
        pin:Hide()
    end
    wipe(activeMinimapPins)

    local TD = ns.TrackerData
    if not TD then return end

    local currentMap = C_Map.GetBestMapForUnit("player")
    if not currentMap then return end

    local pos = C_Map.GetPlayerMapPosition(currentMap, "player")
    if not pos then return end

    local playerX, playerY = pos:GetXY()
    playerX = playerX * 100
    playerY = playerY * 100

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
    local dx = targetX - playerX
    local dy = targetY - playerY
    local dist = math_sqrt(dx * dx + dy * dy)

    if dist > 50 then return end

    local pin = self:GetMinimapPin()
    if not pin then return end

    local angle = math.atan2(dy, dx)
    local minimapRadius = Minimap:GetWidth() / 2

    local scale = dist / 50
    local pinX = math.cos(angle) * minimapRadius * scale
    local pinY = -math.sin(angle) * minimapRadius * scale

    pin:ClearAllPoints()
    pin:SetPoint("CENTER", Minimap, "CENTER", pinX, pinY)
    pin:SetAlpha(1.0 - (dist / 100))
    pin:Show()

    pin.label = label
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
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

function TM:GetDistanceToStep(step)
    if not step or not step.mapID or not step.coordX or not step.coordY then
        return nil
    end

    local currentMap = C_Map.GetBestMapForUnit("player")
    if not currentMap or currentMap ~= tonumber(step.mapID) then
        return nil
    end

    local pos = C_Map.GetPlayerMapPosition(currentMap, "player")
    if not pos then return nil end

    local px, py = pos:GetXY()
    px = px * 100
    py = py * 100

    local dx = px - step.coordX
    local dy = py - step.coordY
    return math_sqrt(dx * dx + dy * dy)
end

function TM:GetDistanceToCoordinate(mapID, x, y)
    local currentMap = C_Map.GetBestMapForUnit("player")
    if not currentMap or currentMap ~= tonumber(mapID) then
        return nil
    end

    local pos = C_Map.GetPlayerMapPosition(currentMap, "player")
    if not pos then return nil end

    local px, py = pos:GetXY()
    px = px * 100
    py = py * 100

    local dx = px - x
    local dy = py - y
    return math_sqrt(dx * dx + dy * dy)
end
