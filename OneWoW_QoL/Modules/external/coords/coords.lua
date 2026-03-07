-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/coords/coords.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local CoordsModule = {
    id          = "coords",
    title       = "COORDS_TITLE",
    category    = "INTERFACE",
    description = "COORDS_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "show_map_id",      label = "COORDS_TOGGLE_MAPID",         description = "COORDS_TOGGLE_MAPID_DESC",         default = true  },
        { id = "show_zone",        label = "COORDS_TOGGLE_ZONE",          description = "COORDS_TOGGLE_ZONE_DESC",          default = false },
        { id = "show_subzone",     label = "COORDS_TOGGLE_SUBZONE",       description = "COORDS_TOGGLE_SUBZONE_DESC",       default = false },
        { id = "show_facing",      label = "COORDS_TOGGLE_FACING",        description = "COORDS_TOGGLE_FACING_DESC",        default = false },
        { id = "show_speed",       label = "COORDS_TOGGLE_SPEED",         description = "COORDS_TOGGLE_SPEED_DESC",         default = false },
        { id = "hide_in_instance", label = "COORDS_TOGGLE_HIDE_INSTANCE", description = "COORDS_TOGGLE_HIDE_INSTANCE_DESC", default = true  },
    },
    defaultEnabled = true,
    _frame       = nil,
    _mapIDText   = nil,
    _coordText   = nil,
    _extraText   = nil,
    _ticker               = nil,
    _extraLines           = {},
    _coordAnchoredToMapID = nil,
}

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("coords", id)
end

local function GetSavedPos()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then return nil end
    local mods = addon.db.global.modules
    if not mods["coords"] then mods["coords"] = {} end
    return mods["coords"].position
end

local function SavePos(point, relativePoint, x, y)
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then return end
    local mods = addon.db.global.modules
    if not mods["coords"] then mods["coords"] = {} end
    mods["coords"].position = {point = point, relativePoint = relativePoint, x = x, y = y}
end

function CoordsModule:GetCardinalDirection(degrees)
    if     degrees >= 337.5 or degrees < 22.5  then return "N"
    elseif degrees >= 22.5  and degrees < 67.5  then return "NE"
    elseif degrees >= 67.5  and degrees < 112.5 then return "E"
    elseif degrees >= 112.5 and degrees < 157.5 then return "SE"
    elseif degrees >= 157.5 and degrees < 202.5 then return "S"
    elseif degrees >= 202.5 and degrees < 247.5 then return "SW"
    elseif degrees >= 247.5 and degrees < 292.5 then return "W"
    elseif degrees >= 292.5 and degrees < 337.5 then return "NW"
    end
    return ""
end

function CoordsModule:CreateFrame()
    local f = CreateFrame("Frame", "OneWoW_QoL_CoordsFrame", UIParent, "BackdropTemplate")
    f:SetSize(120, 32)
    f:SetFrameStrata("MEDIUM")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    f:SetBackdropBorderColor(0.8, 0.6, 0.1, 0.9)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint()
        SavePos(point, relativePoint, x, y)
    end)

    local savedPos = GetSavedPos()
    if savedPos then
        f:SetPoint(savedPos.point, UIParent, savedPos.relativePoint, savedPos.x, savedPos.y)
    else
        f:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 5, -8)
    end

    local mapIDText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mapIDText:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -3)
    mapIDText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -3)
    mapIDText:SetJustifyH("LEFT")
    mapIDText:SetTextColor(1, 0.82, 0, 1)

    local coordText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    coordText:SetPoint("TOPLEFT", mapIDText, "BOTTOMLEFT", 0, -2)
    coordText:SetPoint("TOPRIGHT", mapIDText, "BOTTOMRIGHT", 0, -2)
    coordText:SetJustifyH("CENTER")
    coordText:SetTextColor(0.9, 1, 0.9, 1)

    local extraText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    extraText:SetPoint("TOPLEFT", coordText, "BOTTOMLEFT", 0, -2)
    extraText:SetPoint("TOPRIGHT", coordText, "BOTTOMRIGHT", 0, -2)
    extraText:SetJustifyH("CENTER")
    extraText:SetTextColor(0.7, 0.9, 1, 1)

    f:SetScript("OnMouseUp", function(frame, button)
        if button == "RightButton" then
            self:CopyCoordinates()
        end
    end)

    self._frame     = f
    self._mapIDText = mapIDText
    self._coordText = coordText
    self._extraText = extraText
end

function CoordsModule:UpdateDisplay()
    if not self._frame or not self._frame:IsShown() then return end

    local inInstance = IsInInstance()
    if GetToggle("hide_in_instance") and inInstance then
        self._frame:Hide()
        return
    end

    if C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() then
        self._frame:Hide()
        return
    end

    self._frame:Show()

    local mapID = C_Map.GetBestMapForUnit("player")
    local L = ns.L

    local showMapID = GetToggle("show_map_id") and mapID
    if showMapID then
        self._mapIDText:SetText(string.format(L["COORDS_MAP"] or "Map: %d", mapID))
        self._mapIDText:Show()
        if self._coordAnchoredToMapID ~= true then
            self._coordText:ClearAllPoints()
            self._coordText:SetPoint("TOPLEFT", self._mapIDText, "BOTTOMLEFT", 0, -2)
            self._coordText:SetPoint("TOPRIGHT", self._mapIDText, "BOTTOMRIGHT", 0, -2)
            self._coordAnchoredToMapID = true
        end
    else
        self._mapIDText:Hide()
        if self._coordAnchoredToMapID ~= false then
            self._coordText:ClearAllPoints()
            self._coordText:SetPoint("TOPLEFT", self._frame, "TOPLEFT", 4, -3)
            self._coordText:SetPoint("TOPRIGHT", self._frame, "TOPRIGHT", -4, -3)
            self._coordAnchoredToMapID = false
        end
    end

    if mapID then
        local position = C_Map.GetPlayerMapPosition(mapID, "player")
        if position then
            local x, y = position:GetXY()
            if x and y then
                self._coordText:SetText(string.format("%.2f, %.2f", x * 100, y * 100))
            else
                self._coordText:SetText("--.--, --.--")
            end
        else
            self._coordText:SetText("--.--, --.--")
        end
    else
        self._coordText:SetText("--.--, --.--")
    end

    wipe(self._extraLines)
    local extraLines = self._extraLines

    if GetToggle("show_zone") and mapID then
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.name then
            table.insert(extraLines, mapInfo.name)
        end
    end

    if GetToggle("show_subzone") then
        local subzone = GetSubZoneText()
        if subzone and subzone ~= "" then table.insert(extraLines, subzone) end
    end

    if GetToggle("show_facing") then
        local facing = GetPlayerFacing()
        if facing then
            local degrees = (math.deg(facing) + 360) % 360
            table.insert(extraLines, string.format("%d° %s", math.floor(degrees), self:GetCardinalDirection(degrees)))
        end
    end

    if GetToggle("show_speed") then
        local speed = GetUnitSpeed("player")
        if speed and speed > 0 then
            table.insert(extraLines, string.format("%.1f yd/s", speed))
        end
    end

    if #extraLines > 0 then
        self._extraText:SetText(table.concat(extraLines, "  "))
        self._extraText:Show()
    else
        self._extraText:Hide()
    end

    local h = 6
    if self._mapIDText:IsShown() then
        local mh = self._mapIDText:GetStringHeight()
        if mh > 0 then h = h + mh + 2 end
    end
    local ch = self._coordText:GetStringHeight()
    if ch > 0 then h = h + ch end
    if self._extraText:IsShown() then
        local eh = self._extraText:GetStringHeight()
        if eh > 0 then h = h + 2 + eh end
    end
    self._frame:SetHeight(math.max(h, 20))
end

function CoordsModule:CopyCoordinates()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then return end
    local x, y = position:GetXY()
    if x and y then
        local coordString = string.format("%.2f %.2f", x * 100, y * 100)
        local lib = LibStub and LibStub("LibCopyPaste-1.0", true)
        if lib then
            lib:Copy("Coordinates", coordString)
        end
        print("|cFFFFD100OneWoW QoL:|r " .. string.format(ns.L["COORDS_COPIED"] or "Coordinates copied: %s", coordString))
    end
end

local COORDS_UPDATE_INTERVAL = 0.2

function CoordsModule:StartUpdates()
    self:StopUpdates()
    self._ticker = C_Timer.NewTicker(COORDS_UPDATE_INTERVAL, function()
        if not InCombatLockdown() then
            self:UpdateDisplay()
        end
    end)
end

function CoordsModule:StopUpdates()
    if self._ticker then
        self._ticker:Cancel()
        self._ticker = nil
    end
end

function CoordsModule:OnEnable()
    if not self._frame then
        self:CreateFrame()
    end
    self._frame:Show()
    self:UpdateDisplay()
    self:StartUpdates()
end

function CoordsModule:OnDisable()
    self:StopUpdates()
    if self._frame then
        self._frame:Hide()
    end
end

function CoordsModule:OnToggle(toggleId, value)
    self:UpdateDisplay()
end

ns.CoordsModule = CoordsModule
