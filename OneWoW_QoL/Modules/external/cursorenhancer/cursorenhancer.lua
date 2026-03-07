-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/cursorenhancer/cursorenhancer.lua
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local CursorEnhancerModule = {
    id          = "cursorenhancer",
    title       = "CURSORENHANCER_TITLE",
    category    = "INTERFACE",
    description = "CURSORENHANCER_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {
        { id = "outer_ring",         label = "CURSORENHANCER_OUTER_RING",  default = true  },
        { id = "middle_ring",        label = "CURSORENHANCER_MIDDLE_RING", default = false },
        { id = "center_marker",      label = "CURSORENHANCER_CENTER_MARKER", default = true },
        { id = "show_out_of_combat", label = "CURSORENHANCER_SHOW_OOC",   default = true  },
        { id = "mouse_trail",        label = "CURSORENHANCER_MOUSE_TRAIL", default = false },
    },
    _moduleEnabled = false,
    _eventFrame    = nil,
}

local CE = {}

CE.COLOR_SETTINGS = {
    { toggleId = "outer_ring",      dbKey = "outerRingColor",      colorLabel = "CURSORENHANCER_OUTER_RING_COLOR" },
    { toggleId = "middle_ring",     dbKey = "middleRingColor",     colorLabel = "CURSORENHANCER_MIDDLE_RING_COLOR" },
    { toggleId = "center_marker",   dbKey = "centerMarkerColor",   colorLabel = "CURSORENHANCER_CENTER_MARKER_COLOR" },
    { toggleId = "mouse_trail",     dbKey = "trailColor",          colorLabel = "CURSORENHANCER_TRAIL_COLOR" },
}

local mainFrame
local outerRing, middleRing, centerMarker
local trailGroup = {}
local trailTexPool = {}
local trailPointPool = {}
local MAX_TRAIL_POINTS = 20
local updateTicker = nil
local lastCX, lastCY = -1, -1
local lastAlphaCheck = 0

local function Clamp(val, min, max)
    if val < min then return min elseif val > max then return max end
    return val
end

local function GetDB()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then return nil end
    if not addon.db.global.modules["cursorenhancer"] then
        addon.db.global.modules["cursorenhancer"] = {}
    end
    local ceDb = addon.db.global.modules["cursorenhancer"]
    if not ceDb.cedata then
        ceDb.cedata = {}
    end
    return ceDb.cedata
end

local function GetDefaults()
    local _, class = UnitClass("player")
    local classColor = RAID_CLASS_COLORS[class] or {r=1, g=1, b=1}
    return {
        ringSize          = 90,
        combatAlpha       = 1.0,
        outOfCombatAlpha  = 1.0,
        showOutOfCombat   = true,
        outerRingEnabled  = true,
        outerRingColor    = {classColor.r, classColor.g, classColor.b},
        middleRingEnabled = false,
        middleRingColor   = {1.0, 1.0, 1.0},
        centerMarker      = "Dot",
        centerMarkerColor = {1.0, 1.0, 1.0},
        mouseTrail        = false,
        trailColor        = {1.0, 1.0, 1.0},
        trailFadeTime     = 0.6,
        currentProfile    = "Default",
        profiles          = {},
    }
end

function CE:GetSettings()
    local ceDb = GetDB()
    if not ceDb then return GetDefaults() end
    if not ceDb.profiles then
        ceDb.profiles = {}
    end
    local profileName = ceDb.currentProfile or "Default"
    if not ceDb.profiles[profileName] then
        ceDb.profiles[profileName] = GetDefaults()
    end
    return ceDb.profiles[profileName]
end

function CE:SwitchProfile(profileName)
    local ceDb = GetDB()
    if not ceDb then return end
    ceDb.currentProfile = profileName
    self:UpdateAll()
end

function CE:CreateProfile(profileName)
    local ceDb = GetDB()
    if not ceDb then return false end
    if not ceDb.profiles then ceDb.profiles = {} end
    ceDb.profiles[profileName] = GetDefaults()
    return true
end

function CE:DeleteProfile(profileName)
    if profileName == "Default" then return false end
    local ceDb = GetDB()
    if not ceDb then return false end
    if ceDb.profiles then
        ceDb.profiles[profileName] = nil
    end
    if (ceDb.currentProfile or "Default") == profileName then
        ceDb.currentProfile = "Default"
        self:UpdateAll()
    end
    return true
end

function CE:CopyProfile(fromProfile, toProfile)
    local ceDb = GetDB()
    if not ceDb or not ceDb.profiles then return false end
    local sourceProfile = ceDb.profiles[fromProfile]
    if not sourceProfile then return false end
    local newProfile = {}
    for key, value in pairs(sourceProfile) do
        if type(value) == "table" then
            newProfile[key] = {unpack(value)}
        else
            newProfile[key] = value
        end
    end
    ceDb.profiles[toProfile] = newProfile
    return true
end

function CE:GetAllProfiles()
    local ceDb = GetDB()
    if not ceDb or not ceDb.profiles then return {"Default"} end
    local profiles = {}
    for name, _ in pairs(ceDb.profiles) do
        table.insert(profiles, name)
    end
    table.sort(profiles)
    return profiles
end

function CE:GetCurrentProfileName()
    local ceDb = GetDB()
    if not ceDb then return "Default" end
    return ceDb.currentProfile or "Default"
end

function CE:CreateCursorRing()
    if mainFrame then return end

    local settings = CE:GetSettings()
    local size = settings.ringSize or 90

    mainFrame = CreateFrame("Frame", "OneWoW_QoL_CursorEnhancer", UIParent)
    mainFrame:SetSize(size, size)
    mainFrame:SetFrameStrata("TOOLTIP")
    mainFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 0, 0)
    mainFrame:EnableMouse(false)

    outerRing = mainFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    outerRing:SetAllPoints()
    outerRing:SetTexture("Interface\\AddOns\\OneWoW_QoL\\Media\\c1")
    outerRing:SetVertexColor(1, 1, 1, 1)

    middleRing = mainFrame:CreateTexture(nil, "ARTWORK", nil, 2)
    middleRing:SetSize(size * 0.75, size * 0.75)
    middleRing:SetPoint("CENTER")
    middleRing:SetTexture("Interface\\AddOns\\OneWoW_QoL\\Media\\c2")
    middleRing:SetVertexColor(1, 1, 1, 1)

    centerMarker = mainFrame:CreateTexture(nil, "OVERLAY")
    centerMarker:SetSize(16, 16)
    centerMarker:SetPoint("CENTER")
    centerMarker:SetTexture("Interface\\AddOns\\OneWoW_QoL\\Media\\c3")
    centerMarker:SetVertexColor(1, 1, 1, 1)

    for i = 1, MAX_TRAIL_POINTS do
        local tex = mainFrame:CreateTexture(nil, "BACKGROUND")
        tex:SetTexture("Interface\\AddOns\\OneWoW_QoL\\Media\\c1")
        tex:SetBlendMode("ADD")
        tex:Hide()
        trailTexPool[i] = tex
    end

    CE:StartUpdateTicker()
    CE:UpdateAll()
end

local function CleanupTrailPoints()
    for i = 1, #trailGroup do
        local point = trailGroup[i]
        if point.tex then
            point.tex:Hide()
            trailTexPool[#trailTexPool + 1] = point.tex
            point.tex = nil
        end
        wipe(point)
        trailPointPool[#trailPointPool + 1] = point
    end
    wipe(trailGroup)
end

function CE:StartUpdateTicker()
    if updateTicker then
        updateTicker:Cancel()
        updateTicker = nil
    end

    local lastTickTime = GetTime()
    updateTicker = C_Timer.NewTicker(0.033, function()
        if not mainFrame or not mainFrame:IsShown() then return end
        if not UIParent:IsShown() then return end

        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = x / scale, y / scale
        if cx ~= lastCX or cy ~= lastCY then
            lastCX, lastCY = cx, cy
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
        end

        local now = GetTime()
        local deltaTime = now - lastTickTime
        lastTickTime = now
        lastAlphaCheck = lastAlphaCheck + deltaTime
        if lastAlphaCheck >= 0.5 then
            lastAlphaCheck = 0
            CE:UpdateAlpha()
        end

        CE:UpdateMouseTrail()
    end)
end

function CE:StopUpdateTicker()
    if updateTicker then
        updateTicker:Cancel()
        updateTicker = nil
    end
end

function CE:UpdateAll()
    if not mainFrame then return end

    local settings = self:GetSettings()
    local size = settings.ringSize or 90

    mainFrame:SetSize(size, size)

    if outerRing then
        outerRing:SetSize(size, size)
        local c = settings.outerRingColor
        outerRing:SetVertexColor(c[1], c[2], c[3], 1)
        outerRing:SetShown(settings.outerRingEnabled ~= false)
    end

    if middleRing then
        middleRing:SetSize(size * 0.75, size * 0.75)
        local c = settings.middleRingColor
        middleRing:SetVertexColor(c[1], c[2], c[3], 1)
        middleRing:SetShown(settings.middleRingEnabled == true)
    end

    if centerMarker then
        if settings.centerMarkerHidden then
            centerMarker:Hide()
        else
            local markerType = settings.centerMarker or "Dot"
            if markerType == "None" then
                centerMarker:Hide()
            else
                centerMarker:Show()
                if markerType == "Dot" then
                    centerMarker:SetTexture("Interface\\AddOns\\OneWoW_QoL\\Media\\sparkle")
                    centerMarker:SetSize(12, 12)
                elseif markerType == "Star" then
                    centerMarker:SetTexture("Interface\\AddOns\\OneWoW_QoL\\Media\\c3")
                    centerMarker:SetSize(20, 20)
                elseif markerType == "Cross" then
                    centerMarker:SetAtlas("uitools-icon-plus")
                    centerMarker:SetSize(16, 16)
                elseif markerType == "Diamond" then
                    centerMarker:SetAtlas("UF-SoulShard-FX-FrameGlow")
                    centerMarker:SetSize(20, 20)
                elseif markerType == "Ring" then
                    centerMarker:SetTexture("Interface\\AddOns\\OneWoW_QoL\\Media\\c2")
                    centerMarker:SetSize(24, 24)
                end
                local c = settings.centerMarkerColor
                centerMarker:SetVertexColor(c[1], c[2], c[3], 1)
            end
        end
    end

    self:UpdateVisibility()
    CE:UpdateColorSwatches()
end

function CE:UpdateVisibility()
    if not mainFrame then return end
    local shouldShow = CursorEnhancerModule._moduleEnabled and self:ShouldShowAllowedByCombatRules()
    mainFrame:SetShown(shouldShow)
    if shouldShow then
        self:UpdateAlpha()
        if not updateTicker then
            CE:StartUpdateTicker()
        end
    else
        CE:StopUpdateTicker()
    end
end

function CE:ShouldShowAllowedByCombatRules()
    if InCombatLockdown() or UnitAffectingCombat("player") then return true end
    local inInst, t = IsInInstance()
    if inInst and (t == "party" or t == "raid" or t == "pvp" or t == "arena" or t == "scenario") then
        return true
    end
    local settings = self:GetSettings()
    return settings.showOutOfCombat
end

function CE:UpdateAlpha()
    if not mainFrame then return end
    local settings = self:GetSettings()
    local inCombat = InCombatLockdown()
    local inInst, t = IsInInstance()
    local inInstance = inInst and (t == "party" or t == "raid" or t == "pvp" or t == "arena" or t == "scenario")
    local alpha = (inCombat or inInstance) and (settings.combatAlpha or 1.0) or (settings.outOfCombatAlpha or 1.0)
    mainFrame:SetAlpha(alpha)
end

function CE:GetCursorAlpha()
    local settings = self:GetSettings()
    local inCombat = InCombatLockdown()
    local inInst, t = IsInInstance()
    local inInstance = inInst and (t == "party" or t == "raid" or t == "pvp" or t == "arena" or t == "scenario")
    return (inCombat or inInstance) and (settings.combatAlpha or 1.0) or (settings.outOfCombatAlpha or 1.0)
end

function CE:UpdateMouseTrail()
    local settings = self:GetSettings()
    local mouseTrailActive = settings.mouseTrail and self:ShouldShowAllowedByCombatRules()

    if not mouseTrailActive then
        CleanupTrailPoints()
        return
    end

    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale

    local now = GetTime()
    local newPoint = trailPointPool[#trailPointPool]
    if newPoint then
        trailPointPool[#trailPointPool] = nil
    else
        newPoint = {}
    end
    newPoint.x       = x
    newPoint.y       = y
    newPoint.created = now
    newPoint.tex     = nil
    table.insert(trailGroup, newPoint)

    while #trailGroup > MAX_TRAIL_POINTS do
        local old = table.remove(trailGroup, 1)
        if old.tex then
            old.tex:Hide()
            trailTexPool[#trailTexPool + 1] = old.tex
            old.tex = nil
        end
        wipe(old)
        trailPointPool[#trailPointPool + 1] = old
    end

    local inCombat = InCombatLockdown()
    local inInst, t = IsInInstance()
    local inInstance = inInst and (t == "party" or t == "raid" or t == "pvp" or t == "arena" or t == "scenario")
    local alpha    = (inCombat or inInstance) and (settings.combatAlpha or 1.0) or (settings.outOfCombatAlpha or 1.0)
    local size     = settings.ringSize or 90
    local fadeTime = settings.trailFadeTime or 0.6
    local c        = settings.trailColor

    for i = #trailGroup, 1, -1 do
        local point = trailGroup[i]
        local age   = now - point.created
        local fade  = 1 - (age / fadeTime)

        if fade <= 0 then
            if point.tex then
                point.tex:Hide()
                trailTexPool[#trailTexPool + 1] = point.tex
                point.tex = nil
            end
            wipe(point)
            trailPointPool[#trailPointPool + 1] = point
            table.remove(trailGroup, i)
        else
            if not point.tex then
                local tex = trailTexPool[#trailTexPool]
                if tex then
                    trailTexPool[#trailTexPool] = nil
                else
                    tex = mainFrame:CreateTexture(nil, "BACKGROUND")
                    tex:SetTexture("Interface\\AddOns\\OneWoW_QoL\\Media\\c1")
                    tex:SetBlendMode("ADD")
                end
                point.tex = tex
            end

            point.tex:ClearAllPoints()
            point.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", point.x, point.y)
            point.tex:SetVertexColor(c[1], c[2], c[3], Clamp(fade * 0.8, 0, 1))
            point.tex:SetAlpha(fade * alpha)
            point.tex:SetSize(size * 0.4 * fade, size * 0.4 * fade)
            point.tex:Show()
        end
    end
end

function CursorEnhancerModule:OnEnable()
    self._moduleEnabled = true

    local settings = CE:GetSettings()
    settings.outerRingEnabled  = ns.ModuleRegistry:GetToggleValue("cursorenhancer", "outer_ring")
    settings.middleRingEnabled = ns.ModuleRegistry:GetToggleValue("cursorenhancer", "middle_ring")
    settings.centerMarkerHidden = not ns.ModuleRegistry:GetToggleValue("cursorenhancer", "center_marker")
    settings.showOutOfCombat   = ns.ModuleRegistry:GetToggleValue("cursorenhancer", "show_out_of_combat")
    settings.mouseTrail        = ns.ModuleRegistry:GetToggleValue("cursorenhancer", "mouse_trail")

    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_CursorEnhancerEvents")
        self._eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        self._eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        self._eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        self._eventFrame:SetScript("OnEvent", function(frame, event)
            if event == "PLAYER_ENTERING_WORLD" then
                CE:CreateCursorRing()
            else
                CE:UpdateVisibility()
            end
        end)
    end

    CE:CreateCursorRing()
    CE:UpdateAll()
end

function CursorEnhancerModule:OnDisable()
    self._moduleEnabled = false
    CE:StopUpdateTicker()
    CE:UpdateVisibility()
end

function CursorEnhancerModule:OnToggle(toggleId, value)
    local settings = CE:GetSettings()
    if toggleId == "outer_ring" then
        settings.outerRingEnabled = value
    elseif toggleId == "middle_ring" then
        settings.middleRingEnabled = value
    elseif toggleId == "center_marker" then
        settings.centerMarkerHidden = not value
    elseif toggleId == "show_out_of_combat" then
        settings.showOutOfCombat = value
    elseif toggleId == "mouse_trail" then
        settings.mouseTrail = value
    end
    CE:UpdateAll()
end

local colorSwatches = {}

local function OpenColorPicker(dbKey)
    local settings = CE:GetSettings()
    local color = settings[dbKey] or {1, 1, 1}
    ColorPickerFrame:SetupColorPickerAndShow({
        r = color[1], g = color[2], b = color[3], opacity = 1,
        swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            settings[dbKey] = {r, g, b}
            CE:UpdateAll()
            if colorSwatches[dbKey] then colorSwatches[dbKey]:UpdateColor() end
        end,
        cancelFunc = function() end,
    })
end

function CE:CreateColorSwatch(parent, dbKey, colorLabel)
    local L = ns.L
    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetSize(24, 24)
    swatch:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    swatch:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    swatch.dbKey = dbKey
    swatch.UpdateColor = function(self)
        local color = CE:GetSettings()[self.dbKey] or {1, 1, 1}
        swatch:SetBackdropColor(color[1], color[2], color[3], 1)
    end
    swatch:SetScript("OnClick", function() OpenColorPicker(dbKey) end)
    swatch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L[colorLabel] or colorLabel)
        GameTooltip:Show()
    end)
    swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)
    swatch:UpdateColor()
    colorSwatches[dbKey] = swatch
    return swatch
end

function CE:UpdateColorSwatches()
    for _, swatch in pairs(colorSwatches) do
        if swatch then swatch:UpdateColor() end
    end
end

function CursorEnhancerModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled)
    local L = ns.L

    local headerHeight = 20
    local colorHeader = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorHeader:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    colorHeader:SetText(L["CURSORENHANCER_COLORS_HEADER"] or "Colors")
    colorHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - headerHeight - 8

    local colorDivider = detailScrollChild:CreateTexture(nil, "ARTWORK")
    colorDivider:SetHeight(1)
    colorDivider:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    colorDivider:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    colorDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    for _, colorSetting in ipairs(CE.COLOR_SETTINGS or {}) do
        local label = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
        label:SetText(L[colorSetting.colorLabel] or colorSetting.colorLabel)
        if isEnabled then
            label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end

        local swatch = CE:CreateColorSwatch(detailScrollChild, colorSetting.dbKey, colorSetting.colorLabel)
        swatch:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
        if not isEnabled then
            swatch:EnableMouse(false)
        end

        yOffset = yOffset - 28 - 6
    end

    return yOffset
end

CursorEnhancerModule.CE = CE
ns.CursorEnhancerModule = CursorEnhancerModule
