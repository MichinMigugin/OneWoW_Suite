-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/coords/coords.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local C = OneWoW_GUI.Constants
local format = string.format
local floor = math.floor
local deg = math.deg

local TICK_MOVING    = 0.2
local TICK_STATIONARY = 1.0
local NO_COORDS      = "--.--, --.--"
local FONT_SIZE      = 11
local PADDING        = 4
local LINE_GAP       = 2

local CARDINAL = {
    [0] = "N", "NE", "E", "SE", "S", "SW", "W", "NW",
}

local CoordsModule = {
    id          = "coords",
    title       = "COORDS_TITLE",
    category    = "INTERFACE",
    description = "COORDS_DESC",
    version     = "1.1",
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
    preview     = true,
    defaultEnabled = true,
    _frame     = nil,
    _texts     = nil,
    _ticker    = nil,
    _eventFrame = nil,
    _cache     = nil,
    _hidden    = false,
    _inCombat  = false,
    _layout    = nil,
}

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("coords", id)
end

local function GetPositionStorage()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then return nil end
    local mods = addon.db.global.modules
    if not mods["coords"] then mods["coords"] = {} end
    if not mods["coords"].position then mods["coords"].position = {} end
    return mods["coords"].position
end

local function GetCardinalDirection(radians)
    local d = (deg(radians) + 360) % 360
    local idx = floor((d + 22.5) / 45) % 8
    return CARDINAL[idx], floor(d)
end

local function ApplyFont(fontString)
    local fontPath = OneWoW_GUI:GetFont()
    OneWoW_GUI:SafeSetFont(fontString, fontPath, FONT_SIZE, "")
end

function CoordsModule:ApplyThemeColors()
    if not self._frame then return end
    self._frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    self._frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
    if self._texts then
        if self._texts.mapID then
            self._texts.mapID:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        end
        if self._texts.coords then
            self._texts.coords:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
        if self._texts.extra then
            self._texts.extra:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
    end
end

function CoordsModule:ApplyFonts()
    if not self._texts then return end
    if self._texts.mapID then ApplyFont(self._texts.mapID) end
    if self._texts.coords then ApplyFont(self._texts.coords) end
    if self._texts.extra then ApplyFont(self._texts.extra) end
end

function CoordsModule:CreateFrame()
    local f = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_QoL_CoordsFrame",
        width = 130,
        height = 32,
        backdrop = C.BACKDROP_INNER_NO_INSETS,
    })
    f:SetFrameStrata("MEDIUM")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local storage = GetPositionStorage()
        if storage then
            OneWoW_GUI:SaveWindowPosition(frame, storage)
        end
    end)

    local storage = GetPositionStorage()
    if not storage or not OneWoW_GUI:RestoreWindowPosition(f, storage) then
        f:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 5, -8)
    end

    local mapIDText = f:CreateFontString(nil, "OVERLAY")
    mapIDText:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -PADDING)
    mapIDText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, -PADDING)
    mapIDText:SetJustifyH("LEFT")

    local coordText = f:CreateFontString(nil, "OVERLAY")
    coordText:SetJustifyH("CENTER")

    local extraText = f:CreateFontString(nil, "OVERLAY")
    extraText:SetJustifyH("CENTER")

    f:SetScript("OnMouseUp", function(frame, button)
        if button == "RightButton" then
            self:CopyCoordinates()
        end
    end)

    self._frame = f
    self._texts = {
        mapID  = mapIDText,
        coords = coordText,
        extra  = extraText,
    }
    self._cache = {}
    self._layout = nil

    self:ApplyFonts()
    self:ApplyThemeColors()
end

function CoordsModule:RebuildLayout()
    if not self._frame or not self._texts then return end

    local showMapID = GetToggle("show_map_id")
    local showExtra = GetToggle("show_zone") or GetToggle("show_subzone")
                      or GetToggle("show_facing") or GetToggle("show_speed")

    local layoutKey = (showMapID and "m" or "") .. (showExtra and "e" or "")
    if self._layout == layoutKey then return end
    self._layout = layoutKey

    local mapIDText = self._texts.mapID
    local coordText = self._texts.coords
    local extraText = self._texts.extra

    coordText:ClearAllPoints()
    extraText:ClearAllPoints()

    if showMapID then
        mapIDText:Show()
        coordText:SetPoint("TOPLEFT", mapIDText, "BOTTOMLEFT", 0, -LINE_GAP)
        coordText:SetPoint("TOPRIGHT", mapIDText, "BOTTOMRIGHT", 0, -LINE_GAP)
    else
        mapIDText:Hide()
        coordText:SetPoint("TOPLEFT", self._frame, "TOPLEFT", PADDING, -PADDING)
        coordText:SetPoint("TOPRIGHT", self._frame, "TOPRIGHT", -PADDING, -PADDING)
    end

    if showExtra then
        extraText:SetPoint("TOPLEFT", coordText, "BOTTOMLEFT", 0, -LINE_GAP)
        extraText:SetPoint("TOPRIGHT", coordText, "BOTTOMRIGHT", 0, -LINE_GAP)
    end

    wipe(self._cache)
end

function CoordsModule:RecalcHeight()
    if not self._frame then return end

    local h = PADDING * 2
    if self._texts.mapID:IsShown() then
        local mh = self._texts.mapID:GetStringHeight()
        if mh > 0 then h = h + mh + LINE_GAP end
    end
    local ch = self._texts.coords:GetStringHeight()
    if ch > 0 then h = h + ch end
    if self._texts.extra:IsShown() then
        local eh = self._texts.extra:GetStringHeight()
        if eh > 0 then h = h + LINE_GAP + eh end
    end

    local newH = math.max(h, 20)
    if self._cache.height ~= newH then
        self._cache.height = newH
        self._frame:SetHeight(newH)
    end
end

function CoordsModule:UpdateDisplay()
    if not self._frame or self._hidden or self._inCombat then return end

    local mapID = C_Map.GetBestMapForUnit("player")
    local cache = self._cache
    local L = ns.L

    if GetToggle("show_map_id") and mapID then
        if cache.mapID ~= mapID then
            cache.mapID = mapID
            self._texts.mapID:SetText(format(L["COORDS_MAP"] or "Map: %d", mapID))
        end
    end

    if mapID then
        local position = C_Map.GetPlayerMapPosition(mapID, "player")
        if position then
            local x, y = position:GetXY()
            if x and y then
                local cx = floor(x * 10000 + 0.5)
                local cy = floor(y * 10000 + 0.5)
                if cache.cx ~= cx or cache.cy ~= cy then
                    cache.cx = cx
                    cache.cy = cy
                    self._texts.coords:SetText(format("%.2f, %.2f", cx / 100, cy / 100))
                end
            else
                if cache.cx ~= -1 then
                    cache.cx = -1
                    cache.cy = -1
                    self._texts.coords:SetText(NO_COORDS)
                end
            end
        else
            if cache.cx ~= -1 then
                cache.cx = -1
                cache.cy = -1
                self._texts.coords:SetText(NO_COORDS)
            end
        end
    else
        if cache.cx ~= -1 then
            cache.cx = -1
            cache.cy = -1
            self._texts.coords:SetText(NO_COORDS)
        end
    end

    local showZone    = GetToggle("show_zone")
    local showSubzone = GetToggle("show_subzone")
    local showFacing  = GetToggle("show_facing")
    local showSpeed   = GetToggle("show_speed")
    local hasExtra    = showZone or showSubzone or showFacing or showSpeed

    if hasExtra then
        local parts = {}
        local n = 0

        if showZone and mapID then
            local mapInfo = C_Map.GetMapInfo(mapID)
            if mapInfo and mapInfo.name then
                n = n + 1
                parts[n] = mapInfo.name
            end
        end

        if showSubzone then
            local subzone = GetSubZoneText()
            if subzone and subzone ~= "" then
                n = n + 1
                parts[n] = subzone
            end
        end

        if showFacing then
            local facing = GetPlayerFacing()
            if facing then
                local dir, d = GetCardinalDirection(facing)
                n = n + 1
                parts[n] = format("%d %s", d, dir)
            end
        end

        if showSpeed then
            local speed = GetUnitSpeed("player")
            if speed and speed > 0 then
                n = n + 1
                parts[n] = format("%.1f yd/s", speed)
            end
        end

        if n > 0 then
            local joined = table.concat(parts, "  ", 1, n)
            if cache.extra ~= joined then
                cache.extra = joined
                self._texts.extra:SetText(joined)
            end
            self._texts.extra:Show()
        else
            if cache.extra then
                cache.extra = nil
                self._texts.extra:Hide()
            end
        end
    else
        if cache.extra then
            cache.extra = nil
            self._texts.extra:Hide()
        end
    end

    self:RecalcHeight()

    local speed = GetUnitSpeed("player")
    local isMoving = speed and speed > 0
    local targetInterval = isMoving and TICK_MOVING or TICK_STATIONARY
    if self._currentInterval ~= targetInterval then
        self:StartUpdates(targetInterval)
    end
end

function CoordsModule:CheckVisibility()
    if not self._frame then return end

    local shouldHide = false
    if GetToggle("hide_in_instance") and IsInInstance() then
        shouldHide = true
    end
    if C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() then
        shouldHide = true
    end

    if shouldHide and not self._hidden then
        self._hidden = true
        self._frame:Hide()
        self:StopUpdates()
    elseif not shouldHide and self._hidden then
        self._hidden = false
        self._frame:Show()
        wipe(self._cache)
        self:StartUpdates(TICK_MOVING)
    end
end

function CoordsModule:CopyCoordinates()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then return end
    local x, y = position:GetXY()
    if x and y then
        local coordString = format("%.2f %.2f", x * 100, y * 100)
        local lib = LibStub and LibStub("LibCopyPaste-1.0", true)
        if lib then
            lib:Copy("Coordinates", coordString)
        end
        print("|cFFFFD100OneWoW QoL:|r " .. format(ns.L["COORDS_COPIED"] or "Coordinates copied: %s", coordString))
    end
end

function CoordsModule:StartUpdates(interval)
    self:StopUpdates()
    interval = interval or TICK_MOVING
    self._currentInterval = interval
    self._ticker = C_Timer.NewTicker(interval, function()
        self:UpdateDisplay()
    end)
end

function CoordsModule:StopUpdates()
    if self._ticker then
        self._ticker:Cancel()
        self._ticker = nil
    end
    self._currentInterval = nil
end

function CoordsModule:RegisterEvents()
    if self._eventFrame then return end
    local ef = CreateFrame("Frame")
    ef:RegisterEvent("ZONE_CHANGED")
    ef:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    ef:RegisterEvent("ZONE_CHANGED_INDOORS")
    ef:RegisterEvent("PLAYER_ENTERING_WORLD")
    ef:RegisterEvent("PET_BATTLE_OPENING_START")
    ef:RegisterEvent("PET_BATTLE_CLOSE")
    ef:RegisterEvent("PLAYER_REGEN_DISABLED")
    ef:RegisterEvent("PLAYER_REGEN_ENABLED")
    ef:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            self._inCombat = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            self._inCombat = false
            if not self._hidden then
                wipe(self._cache)
                self:UpdateDisplay()
            end
        elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA"
            or event == "ZONE_CHANGED_INDOORS" or event == "PLAYER_ENTERING_WORLD" then
            self._cache.mapID = nil
            self._cache.extra = nil
            self:CheckVisibility()
            if not self._hidden and not self._inCombat then
                self:UpdateDisplay()
            end
        elseif event == "PET_BATTLE_OPENING_START" or event == "PET_BATTLE_CLOSE" then
            self:CheckVisibility()
        end
    end)
    self._eventFrame = ef
end

function CoordsModule:UnregisterEvents()
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
        self._eventFrame:Hide()
        self._eventFrame = nil
    end
end

function CoordsModule:OnEnable()
    if not self._frame then
        self:CreateFrame()
    end

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function(self2)
        self2:ApplyThemeColors()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", self, function(self2)
        self2:ApplyFonts()
        wipe(self2._cache)
        self2:RecalcHeight()
    end)

    self._hidden = false
    self._inCombat = InCombatLockdown()
    self:RebuildLayout()
    self:RegisterEvents()
    self:CheckVisibility()
    if not self._hidden then
        self._frame:Show()
        self:UpdateDisplay()
        self:StartUpdates(TICK_MOVING)
    end
end

function CoordsModule:OnDisable()
    self:StopUpdates()
    self:UnregisterEvents()
    if self._frame then
        self._frame:Hide()
    end
end

function CoordsModule:OnToggle(toggleId, value)
    self:RebuildLayout()
    if not self._hidden and not self._inCombat then
        self:UpdateDisplay()
    end
end

ns.CoordsModule = CoordsModule
