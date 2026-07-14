-- ============================================================================
-- Cursor Enhancer — engine
-- ============================================================================
-- Renders a cursor circle (outer/middle ring + center marker + optional dot
-- trail) plus two independent cooldown-swipe rings that follow the cursor:
--   * GCD circle  — sweeps on the global cooldown (reference spell 61304)
--   * Cast circle — sweeps on casts / channels / empowered spells, with a spark
--
-- Movement is per-frame (OnUpdate) with integer-pixel rounding so the ring
-- tracks the pointer without stepping/jitter. The trail lives on its own
-- always-shown container so dots keep fading after the ring is hidden.
--
-- Options UI lives in cursorenhancer-ui.lua; situations match/resolve in
-- cursorenhancer-situations.lua. This file exposes the CE table and Apply*
-- entry points.
-- ============================================================================

local _, ns = ...
local CursorEnhancerModule = ns.ModuleRegistry:Current()
if not CursorEnhancerModule then return end

local OneWoW_GUI = OneWoW_GUI

local floor = math.floor
local cos, sin, rad = math.cos, math.sin, math.rad
local tinsert, tremove = tinsert, tremove
local pairs, type = pairs, type
local GetTime = GetTime
local GetCursorPosition = GetCursorPosition
local C_Timer = C_Timer
local C_Spell = C_Spell
local UnitClass = UnitClass
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerDisplayMod = UnitPowerDisplayMod
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local GetUnitEmpowerHoldAtMaxTime = GetUnitEmpowerHoldAtMaxTime
local GetRuneCooldown = GetRuneCooldown
local C_SpecializationInfo = C_SpecializationInfo
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local hooksecurefunc = hooksecurefunc

local CE = {}

local MEDIA = OneWoW_GUI.Constants.MEDIA_BASE .. "OneWoW_QoL\\cursorenhancer\\"

-- Ring textures shared by the swipe rings (GCD + cast). Keys are stored in DB.
CE.RING_TEXTURES = {
    c1 = MEDIA .. "c1",
    c2 = MEDIA .. "c2",
}

-- GCD reference spell (any 1.5s GCD-triggering ability shares this cooldown).
local GCD_SPELL = 61304

local mainFrame
local outerRing, middleRing, centerMarker
local middleSwipeCD, outerSwipeCD
local swipeDriver
local pipFrame
local pipTextures = {}
local cursorVisible = false
local lastX, lastY = -1, -1
local mouselookActive = false

-- Pixel offsets cached from settings (read per-frame in OnUpdate, so no
-- GetSettings call on the hot path). Refreshed by UpdateAll.
local offX, offY = 0, 0

-- ----------------------------------------------------------------------------
-- Settings / profiles
-- ----------------------------------------------------------------------------
local function Clamp(val, minV, maxV)
    if val < minV then return minV elseif val > maxV then return maxV end
    return val
end

local function GetDB()
    local ceDb = ns.ModuleRegistry:GetModuleBucket("cursorenhancer")
    if not ceDb.cedata then
        ceDb.cedata = {}
    end
    return ceDb.cedata
end

local function GetDefaults()
    return CursorEnhancerModule.Situations.GlobalDefaults()
end

--- Resolve the active profile's settings table, backfilling missing defaults.
---@return table
function CE:GetSettings()
    local ceDb = GetDB()
    if not ceDb.profiles then
        ceDb.profiles = {}
    end
    local profileName = ceDb.currentProfile or "Default"
    if not ceDb.profiles[profileName] then
        ceDb.profiles[profileName] = GetDefaults()
    end
    local profile = ceDb.profiles[profileName]
    CursorEnhancerModule.Situations.MigrateProfile(profile)
    return profile
end

function CE:SwitchProfile(profileName)
    GetDB().currentProfile = profileName
    self:ApplyAll()
end

function CE:CreateProfile(profileName)
    local ceDb = GetDB()
    if not ceDb.profiles then ceDb.profiles = {} end
    ceDb.profiles[profileName] = GetDefaults()
    return true
end

function CE:DeleteProfile(profileName)
    if profileName == "Default" then return false end
    local ceDb = GetDB()
    if ceDb.profiles then
        ceDb.profiles[profileName] = nil
    end
    if (ceDb.currentProfile or "Default") == profileName then
        ceDb.currentProfile = "Default"
        self:ApplyAll()
    end
    return true
end

function CE:CopyProfile(fromProfile, toProfile)
    local ceDb = GetDB()
    if not ceDb.profiles then return false end
    local source = ceDb.profiles[fromProfile]
    if not source then return false end
    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = {}
            for k2, v2 in pairs(value) do copy[key][k2] = v2 end
        else
            copy[key] = value
        end
    end
    ceDb.profiles[toProfile] = copy
    return true
end

function CE:GetAllProfiles()
    local ceDb = GetDB()
    if not ceDb.profiles then return { "Default" } end
    local profiles = {}
    for name in pairs(ceDb.profiles) do
        tinsert(profiles, name)
    end
    table.sort(profiles)
    if #profiles == 0 then tinsert(profiles, "Default") end
    return profiles
end

function CE:GetCurrentProfileName()
    return GetDB().currentProfile or "Default"
end

-- ----------------------------------------------------------------------------
-- Color resolution: class color wins over the stored custom color.
-- ----------------------------------------------------------------------------
---@param colorTbl table|nil
---@param useClassColor boolean|nil
---@return number r, number g, number b
local function ResolveColor(colorTbl, useClassColor)
    if useClassColor then
        local _, class = UnitClass("player")
        local cc = class and RAID_CLASS_COLORS[class]
        if cc then return cc.r, cc.g, cc.b end
    end
    local c = colorTbl or { 1, 1, 1 }
    return c[1] or 1, c[2] or 1, c[3] or 1
end

-- ----------------------------------------------------------------------------
-- Visibility (situation-driven)
-- ----------------------------------------------------------------------------
--- Effective show/look for the current place × combat context.
---@return table
function CE:GetResolvedState()
    return CursorEnhancerModule.Situations.Resolve(self:GetSettings())
end

--- Whether the cursor circle should currently be visible.
---@return boolean
function CE:ShouldShow()
    if not CursorEnhancerModule._moduleEnabled then return false end
    local resolved = self:GetResolvedState()
    if not resolved.anyVisual then return false end
    if resolved.onlyWhileMouseLook and not mouselookActive then
        return false
    end
    return true
end

function CE:GetCursorAlpha()
    return self:GetResolvedState().alpha or 1.0
end

function CE:UpdateVisibility()
    if not mainFrame then return end
    local shouldShow = self:ShouldShow()
    if shouldShow and not cursorVisible then
        cursorVisible = true
        -- Snap to the current cursor before showing so the ring never flashes
        -- one frame at its last (stale) position.
        local s = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        x, y = floor(x / s + 0.5), floor(y / s + 0.5)
        lastX, lastY = x, y
        mainFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + offX, y + offY)
        mainFrame:SetAlpha(self:GetCursorAlpha())
        mainFrame:Show()
    elseif not shouldShow and cursorVisible then
        cursorVisible = false
        mainFrame:Hide()
    elseif shouldShow then
        mainFrame:SetAlpha(self:GetCursorAlpha())
    end
end

-- ----------------------------------------------------------------------------
-- Cursor circle (outer / middle ring + center marker)
-- ----------------------------------------------------------------------------
local function CursorOnUpdate()
    local s = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = floor(x / s + 0.5), floor(y / s + 0.5)
    if x ~= lastX or y ~= lastY then
        lastX, lastY = x, y
        mainFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + offX, y + offY)
    end
end

function CE:CreateCursorRing()
    if mainFrame then return end
    local size = self:GetSettings().ringSize or 90

    mainFrame = CreateFrame("Frame", "OneWoW_QoL_CursorEnhancer", UIParent)
    mainFrame:SetSize(size, size)
    mainFrame:SetFrameStrata("TOOLTIP")
    mainFrame:SetFrameLevel(9999)
    mainFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 0, 0)
    mainFrame:EnableMouse(false)
    mainFrame:SetScript("OnUpdate", CursorOnUpdate)
    mainFrame:Hide()

    outerRing = mainFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    outerRing:SetAllPoints()
    outerRing:SetTexture(MEDIA .. "c1")

    middleRing = mainFrame:CreateTexture(nil, "ARTWORK", nil, 2)
    middleRing:SetSize(size * 0.75, size * 0.75)
    middleRing:SetPoint("CENTER")
    middleRing:SetTexture(MEDIA .. "c2")

    centerMarker = mainFrame:CreateTexture(nil, "OVERLAY")
    centerMarker:SetSize(16, 16)
    centerMarker:SetPoint("CENTER")
    centerMarker:SetTexture(MEDIA .. "c3")

    -- On-ring cooldown swipes: GCD sweeps the middle ring, cast sweeps the
    -- outer ring. Swipe texture = the same ring art, so the sweep looks like
    -- the ring itself filling or emptying.
    local function CreateRingSwipe(tex, level)
        local cd = CreateFrame("Cooldown", nil, mainFrame, "CooldownFrameTemplate")
        cd:SetPoint("CENTER")
        cd:SetFrameLevel(mainFrame:GetFrameLevel() + level)
        cd:SetHideCountdownNumbers(true)
        cd:SetDrawEdge(false)
        cd:SetDrawBling(false)
        cd:SetSwipeTexture(tex)
        cd:Hide()
        return cd
    end
    outerSwipeCD  = CreateRingSwipe(MEDIA .. "c1", 1)
    middleSwipeCD = CreateRingSwipe(MEDIA .. "c2", 2)

    -- Resource pips: small dots arced along the bottom of the ring.
    pipFrame = CreateFrame("Frame", nil, mainFrame)
    pipFrame:SetAllPoints(mainFrame)
    pipFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 3)
    pipFrame:Hide()

    self:UpdateAll()
end

function CE:UpdateAll()
    if not mainFrame then return end
    local resolved = self:GetResolvedState()
    local size = resolved.ringSize or 90

    offX = resolved.offsetX or 0
    offY = resolved.offsetY or 0

    mainFrame:SetSize(size, size)

    outerRing:SetSize(size, size)
    outerRing:SetVertexColor(ResolveColor(resolved.outerRingColor, resolved.outerRingClassColor))
    outerRing:SetShown(resolved.show.outerRing == true)

    middleRing:SetSize(size * 0.75, size * 0.75)
    middleRing:SetVertexColor(ResolveColor(resolved.middleRingColor))
    middleRing:SetShown(resolved.show.middleRing == true)

    outerSwipeCD:SetSize(size, size)
    local oR, oG, oB = ResolveColor(resolved.outerRingColor, resolved.outerRingClassColor)
    outerSwipeCD:SetSwipeColor(oR, oG, oB, 1)
    outerSwipeCD:SetReverse(resolved.outerSwipe.fill == true)
    if not resolved.outerSwipe.enabled then outerSwipeCD:Hide() end

    middleSwipeCD:SetSize(size * 0.75, size * 0.75)
    local mR, mG, mB = ResolveColor(resolved.middleRingColor)
    middleSwipeCD:SetSwipeColor(mR, mG, mB, 1)
    middleSwipeCD:SetReverse(resolved.middleSwipe.fill == true)
    if not resolved.middleSwipe.enabled then middleSwipeCD:Hide() end

    self:ApplySwipeDriver()
    self:UpdatePips()

    -- Style None is already folded into show by Resolve. Do not call
    -- SetTexture(nil) after Hide — SetTexture re-shows the region in WoW.
    local markerType = resolved.centerMarker or "Dot"
    local showMarker = resolved.show.centerMarker == true and markerType ~= "None"
    if not showMarker then
        centerMarker:Hide()
    else
        centerMarker:Show()
        if markerType == "Dot" then
            centerMarker:SetTexture(MEDIA .. "sparkle")
            centerMarker:SetBlendMode("ADD")
            centerMarker:SetSize(12, 12)
        elseif markerType == "Star" then
            centerMarker:SetBlendMode("BLEND")
            centerMarker:SetTexture(MEDIA .. "c3")
            centerMarker:SetSize(20, 20)
        elseif markerType == "Cross" then
            centerMarker:SetBlendMode("BLEND")
            centerMarker:SetAtlas("uitools-icon-plus")
            centerMarker:SetSize(16, 16)
        elseif markerType == "Diamond" then
            centerMarker:SetBlendMode("BLEND")
            centerMarker:SetAtlas("UF-SoulShard-FX-FrameGlow")
            centerMarker:SetSize(20, 20)
        elseif markerType == "Ring" then
            centerMarker:SetBlendMode("BLEND")
            centerMarker:SetTexture(MEDIA .. "c2")
            centerMarker:SetSize(24, 24)
        end
        centerMarker:SetVertexColor(ResolveColor(resolved.centerMarkerColor))
    end

    -- Keep settings.ringSize etc. as global identity; resolved drives display.
    self:UpdateVisibility()
end

-- ----------------------------------------------------------------------------
-- Cursor trail (own always-shown container so dots finish fading)
-- ----------------------------------------------------------------------------
local trailContainer
local trailPool = {}
local trailActive = {}
local trailEntryPool = {}
local trailLastX, trailLastY = 0, 0
local trailTimer = 0
local TRAIL_MAX = 40
local TRAIL_DENSITY = 0.01

-- Trail dot art per style. "glow" uses a Blizzard built-in texture that ships
-- with the client, so there is no custom asset to bundle.
CE.TRAIL_STYLES = {
    ring  = MEDIA .. "c1",
    glow  = "Interface\\Challenges\\challenges-metalglow",
    spark = MEDIA .. "sparkle",
}

local function AcquireTrailTex(stylePath)
    local tex = tremove(trailPool)
    if not tex then
        tex = trailContainer:CreateTexture(nil, "BACKGROUND")
        tex:SetBlendMode("ADD")
    end
    if tex._stylePath ~= stylePath then
        tex:SetTexture(stylePath)
        tex._stylePath = stylePath
    end
    return tex
end

local function ReleaseTrailEntry(e)
    if e.tex then
        e.tex:Hide()
        trailPool[#trailPool + 1] = e.tex
        e.tex = nil
    end
    trailEntryPool[#trailEntryPool + 1] = e
end

local function TrailOnUpdate(_, elapsed)
    for i = #trailActive, 1, -1 do
        local e = trailActive[i]
        e.life = e.life - elapsed
        if e.life <= 0 then
            trailActive[i] = trailActive[#trailActive]
            trailActive[#trailActive] = nil
            ReleaseTrailEntry(e)
        else
            local pct = e.life / e.maxLife
            e.tex:SetAlpha(Clamp(pct * 0.8, 0, 1))
            e.tex:SetSize(e.size * pct, e.size * pct)
        end
    end

    local settings = CE:GetSettings()
    local resolved = CE:GetResolvedState()
    if not (resolved.show.trail and CE:ShouldShow()) then return end

    local s = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / s, y / s
    trailTimer = trailTimer + elapsed
    local dx, dy = x - trailLastX, y - trailLastY
    local moved = (dx * dx + dy * dy) ^ 0.5
    if trailTimer < TRAIL_DENSITY or moved < 0.5 then return end
    trailTimer = 0
    trailLastX, trailLastY = x, y

    local trail = resolved.trail
    local c = trail.color or settings.trailColor
    local size = trail.size or 36
    local fade = trail.fadeTime or 0.6
    local stylePath = CE.TRAIL_STYLES[trail.style or "ring"] or CE.TRAIL_STYLES.ring

    local tex = AcquireTrailTex(stylePath)
    tex:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1, 0.8)
    tex:SetSize(size, size)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", trailContainer, "BOTTOMLEFT", x, y)
    tex:SetAlpha(0.8)
    tex:Show()

    local e = tremove(trailEntryPool) or {}
    e.tex, e.life, e.maxLife, e.size = tex, fade, fade, size
    trailActive[#trailActive + 1] = e

    while #trailActive > TRAIL_MAX do
        local old = tremove(trailActive, 1)
        ReleaseTrailEntry(old)
    end
end

local function HideAllTrail()
    for i = #trailActive, 1, -1 do
        ReleaseTrailEntry(trailActive[i])
        trailActive[i] = nil
    end
end

function CE:ApplyTrail()
    local resolved = self:GetResolvedState()
    if resolved.show.trail and CursorEnhancerModule._moduleEnabled then
        if not trailContainer then
            trailContainer = CreateFrame("Frame", "OneWoW_QoL_CursorEnhancerTrail", UIParent)
            trailContainer:SetAllPoints(UIParent)
            trailContainer:SetFrameStrata("TOOLTIP")
            trailContainer:SetFrameLevel(9998)
            trailContainer:EnableMouse(false)
        end
        trailContainer:SetScript("OnUpdate", TrailOnUpdate)
    else
        HideAllTrail()
        if trailContainer then trailContainer:SetScript("OnUpdate", nil) end
    end
end

-- ----------------------------------------------------------------------------
-- Swipe ring engine (cooldown-swipe based, reused by GCD + cast)
-- ----------------------------------------------------------------------------
---@class CE_SwipeRing : Frame
---@field _cd table
---@field _r number
---@field _g number
---@field _b number
---@field _a number
---@field dur number
---@field maxDur number
---@field StartRing fun(self: CE_SwipeRing, elapsed: number, maxDur: number)
---@field StopRing fun(self: CE_SwipeRing)
---@field SetRingColor fun(self: CE_SwipeRing, r: number, g: number, b: number, a: number)
---@field SetRingRadius fun(self: CE_SwipeRing, radius: number)
---@field SetRingTexture fun(self: CE_SwipeRing, key: string)

--- Create a smooth circular-fill ring driven by a Cooldown swipe.
---@param parent Frame
---@param radius number
---@param texKey string
---@param r number
---@param g number
---@param b number
---@param a number
---@return CE_SwipeRing ring
local function CreateSwipeRing(parent, radius, texKey, r, g, b, a)
    local ring = CreateFrame("Frame", nil, parent) --[[@as CE_SwipeRing]]
    ring:SetSize(radius * 2, radius * 2)
    ring:SetPoint("CENTER", parent, "CENTER", 0, 0)
    ring:SetFrameLevel(parent:GetFrameLevel() + 1)
    ring.dur, ring.maxDur = 0, 0
    ring._r, ring._g, ring._b, ring._a = r, g, b, a

    local texPath = CE.RING_TEXTURES[texKey] or CE.RING_TEXTURES.c1

    ring._cd = CreateFrame("Cooldown", nil, ring, "CooldownFrameTemplate")
    ring._cd:SetAllPoints(ring)
    ring._cd:SetFrameLevel(ring:GetFrameLevel() + 1)
    ring._cd:SetHideCountdownNumbers(true)
    ring._cd:SetDrawEdge(false)
    ring._cd:SetDrawBling(false)
    ring._cd:SetReverse(true)
    ring._cd:SetSwipeTexture(texPath, r, g, b, a)
    ring._cd:Hide()

    function ring:SetRingColor(nr, ng, nb, na)
        self._r, self._g, self._b, self._a = nr, ng, nb, na
        self._cd:SetSwipeColor(nr, ng, nb, na)
    end

    function ring:SetRingRadius(newRadius)
        self:SetSize(newRadius * 2, newRadius * 2)
    end

    function ring:SetRingTexture(newKey)
        self._cd:SetSwipeTexture(CE.RING_TEXTURES[newKey] or CE.RING_TEXTURES.c1,
            self._r, self._g, self._b, self._a)
    end

    function ring:StartRing(elapsed, maxDur)
        self.dur = elapsed > 0 and elapsed or 0
        self.maxDur = maxDur
        self._cd:SetCooldown(GetTime() - elapsed, maxDur)
        self._cd:Show()
        self:Show()
    end

    function ring:StopRing()
        self._cd:Hide()
        self.dur, self.maxDur = 0, 0
        self:Hide()
    end

    ring:SetScript("OnUpdate", function(_, dt)
        if ring.maxDur <= 0 then return end
        ring.dur = ring.dur + dt
        if ring.dur >= ring.maxDur then
            ring:StopRing()
        end
    end)

    ring:Hide()
    return ring
end

--- Attach a swipe-ring root to the cursor (own OnUpdate) or park it at center.
---@param root Frame
---@param attached boolean
local function ApplySwipeTracking(root, attached)
    if attached then
        root:SetScript("OnUpdate", function()
            local s = UIParent:GetEffectiveScale()
            local x, y = GetCursorPosition()
            root:ClearAllPoints()
            root:SetPoint("CENTER", UIParent, "BOTTOMLEFT", floor(x / s + 0.5) + offX, floor(y / s + 0.5) + offY)
        end)
    else
        root:SetScript("OnUpdate", nil)
        root:ClearAllPoints()
        root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- ----------------------------------------------------------------------------
-- GCD circle
-- ----------------------------------------------------------------------------
local gcdRoot, gcdRing

local function GetGCDCooldown()
    local data = C_Spell.GetSpellCooldown(GCD_SPELL)
    if not data or not data.startTime then return nil end
    -- Duration/startTime may be secret in instanced content; guard the math.
    local ok, elapsed, dur = pcall(function()
        local d, s = data.duration, data.startTime
        if d and d > 0 and d <= 1.6 and s and s > 0 then
            return GetTime() - s, d
        end
    end)
    if ok and elapsed then return elapsed, dur end
    return nil
end

local function CreateGCDCircle()
    if gcdRoot then return end
    local g = CE:GetSettings().gcd
    local radius = g.radius or 21
    local r, gg, b = ResolveColor(g.color, g.useClassColor)

    gcdRoot = CreateFrame("Frame", "OneWoW_QoL_CursorEnhancerGCD", UIParent)
    gcdRoot:SetSize(radius * 2, radius * 2)
    gcdRoot:SetFrameStrata("TOOLTIP")
    gcdRoot:SetFrameLevel(9990)
    gcdRoot:EnableMouse(false)
    gcdRoot:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    gcdRing = CreateSwipeRing(gcdRoot, radius, g.ringTex or "c1", r, gg, b, g.alpha or 0.8)

    gcdRoot:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    gcdRoot:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    gcdRoot:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    gcdRoot:SetScript("OnEvent", function(_, event)
        local g2 = CE:GetResolvedState().gcd
        if not g2.enabled then return end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            local elapsed, dur = GetGCDCooldown()
            if elapsed then gcdRing:StartRing(elapsed, dur) end
        else
            local elapsed = GetGCDCooldown()
            if not elapsed then gcdRing:StopRing() end
        end
    end)

    gcdRoot:Hide()
end

function CE:ApplyGCD()
    local g = self:GetResolvedState().gcd
    if not (g.enabled and CursorEnhancerModule._moduleEnabled) then
        if gcdRoot then
            gcdRoot:Hide()
            gcdRoot:SetScript("OnUpdate", nil)
        end
        return
    end
    if not gcdRoot then CreateGCDCircle() end

    local radius = g.radius or 21
    gcdRoot:SetScale((g.scale or 100) / 100)
    gcdRoot:SetSize(radius * 2, radius * 2)
    gcdRing:SetRingRadius(radius)
    gcdRing:SetRingTexture(g.ringTex or "c1")
    local r, gg, b = ResolveColor(g.color, g.useClassColor)
    gcdRing:SetRingColor(r, gg, b, g.alpha or 0.8)

    gcdRoot:Show()
    ApplySwipeTracking(gcdRoot, g.attached ~= false)
end

-- ----------------------------------------------------------------------------
-- Cast circle (with spark)
-- ----------------------------------------------------------------------------
local castRoot, castRing

local function CreateCastCircle()
    if castRoot then return end
    local c = CE:GetSettings().castCircle
    local radius = c.radius or 30
    local r, g, b = ResolveColor(c.color, c.useClassColor)

    castRoot = CreateFrame("Frame", "OneWoW_QoL_CursorEnhancerCast", UIParent)
    castRoot:SetSize(radius * 2, radius * 2)
    castRoot:SetFrameStrata("TOOLTIP")
    castRoot:SetFrameLevel(9988)
    castRoot:EnableMouse(false)
    castRoot:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    castRing = CreateSwipeRing(castRoot, radius, c.ringTex or "c1", r, g, b, c.alpha or 0.8)

    local sparkOverlay = CreateFrame("Frame", nil, castRoot)
    sparkOverlay:SetAllPoints(castRoot)
    sparkOverlay:SetFrameLevel(castRoot:GetFrameLevel() + 3)

    castRoot._spark = sparkOverlay:CreateTexture(nil, "OVERLAY")
    castRoot._spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    castRoot._spark:SetBlendMode("ADD")
    castRoot._spark:SetSize(radius * 0.6, radius * 0.6)
    castRoot._spark:Hide()

    sparkOverlay:SetScript("OnUpdate", function()
        local spark = castRoot._spark
        if not spark:IsShown() then return end
        local dur, maxDur = castRing.dur, castRing.maxDur
        if not dur or maxDur <= 0 then spark:Hide(); return end
        local pct = dur / maxDur
        if pct <= 0 or pct >= 1 then spark:Hide(); return end
        local c2 = CE:GetSettings().castCircle
        local ringRadius = c2.radius or 30
        local angleDeg = 90 - (pct * 360)
        local aRad = rad(angleDeg)
        local orbit = ringRadius * 0.9
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", castRoot, "CENTER", cos(aRad) * orbit, sin(aRad) * orbit)
        spark:SetRotation(rad(angleDeg - 90))
    end)

    castRoot._castID = nil
    castRoot:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    castRoot:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
    castRoot:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
    castRoot:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    castRoot:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    castRoot:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    castRoot:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
    castRoot:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
    castRoot:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "player")
    castRoot:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", "player")
    castRoot:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")

    castRoot:SetScript("OnEvent", function(self, event, _, castID)
        local c2 = CE:GetResolvedState().castCircle
        if not c2.enabled then return end

        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
            local name, _, _, startMS, endMS, _, cID = UnitCastingInfo("player")
            if name then
                self._castID = cID
                castRing:StartRing(GetTime() - startMS * 0.001, (endMS - startMS) * 0.001)
                if c2.sparkEnabled then self._spark:Show() end
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
            or event == "UNIT_SPELLCAST_EMPOWER_START" or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
            local name, _, _, startMS, endMS, _, _, _, numStages = UnitChannelInfo("player")
            if name then
                self._castID = nil
                if numStages and numStages > 0 and GetUnitEmpowerHoldAtMaxTime then
                    endMS = endMS + GetUnitEmpowerHoldAtMaxTime("player")
                end
                castRing:StartRing(GetTime() - startMS * 0.001, (endMS - startMS) * 0.001)
                if c2.sparkEnabled then self._spark:Show() end
            end
        elseif event == "UNIT_SPELLCAST_STOP" then
            if castID == self._castID then
                self._castID = nil
                castRing:StopRing()
                self._spark:Hide()
            end
        else
            if not castID or castID == self._castID then
                self._castID = nil
                castRing:StopRing()
                self._spark:Hide()
            end
        end
    end)

    castRoot:Hide()
end

function CE:ApplyCast()
    local c = self:GetResolvedState().castCircle
    if not (c.enabled and CursorEnhancerModule._moduleEnabled) then
        if castRoot then
            castRoot:Hide()
            castRoot:SetScript("OnUpdate", nil)
        end
        return
    end
    if not castRoot then CreateCastCircle() end

    local radius = c.radius or 30
    castRoot:SetScale((c.scale or 100) / 100)
    castRoot:SetSize(radius * 2, radius * 2)
    castRing:SetRingRadius(radius)
    castRing:SetRingTexture(c.ringTex or "c1")
    local r, g, b = ResolveColor(c.color, c.useClassColor)
    castRing:SetRingColor(r, g, b, c.alpha or 0.8)
    if castRoot._spark then
        castRoot._spark:SetSize(radius * 0.6, radius * 0.6)
        castRoot._spark:SetVertexColor(r, g, b, 1)
    end

    castRoot:Show()
    ApplySwipeTracking(castRoot, c.attached ~= false)
end

--- Re-evaluate situation-gated pieces when zone/combat/restriction changes.
function CE:RefreshSwipeVisibility()
    self:UpdateAll()
    self:ApplyTrail()
    self:ApplyGCD()
    self:ApplyCast()
    self:ApplySwipeDriver()
    self:ApplyPips()
end

-- ----------------------------------------------------------------------------
-- On-ring swipe driver — one event frame feeds the middle-ring GCD swipe and
-- the outer-ring cast swipe (independent of the detached GCD/cast circles).
-- ----------------------------------------------------------------------------
local function DriveMiddleGCDSwipe(event)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local elapsed, dur = GetGCDCooldown()
        if elapsed then
            middleSwipeCD:SetCooldown(GetTime() - elapsed, dur)
            middleSwipeCD:Show()
        end
    else -- FAILED / INTERRUPTED: clear unless a GCD is genuinely running
        if not GetGCDCooldown() then
            middleSwipeCD:Clear()
            middleSwipeCD:Hide()
        end
    end
end

local function DriveOuterCastSwipe(event)
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
        local name, _, _, startMS, endMS = UnitCastingInfo("player")
        if name then
            outerSwipeCD:SetCooldown(startMS * 0.001, (endMS - startMS) * 0.001)
            outerSwipeCD:Show()
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        or event == "UNIT_SPELLCAST_EMPOWER_START" or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        local name, _, _, startMS, endMS, _, _, _, numStages = UnitChannelInfo("player")
        if name then
            if numStages and numStages > 0 and GetUnitEmpowerHoldAtMaxTime then
                endMS = endMS + GetUnitEmpowerHoldAtMaxTime("player")
            end
            outerSwipeCD:SetCooldown(startMS * 0.001, (endMS - startMS) * 0.001)
            outerSwipeCD:Show()
        end
    else -- STOP / FAILED / INTERRUPTED / CHANNEL_STOP / EMPOWER_STOP
        if not UnitCastingInfo("player") and not UnitChannelInfo("player") then
            outerSwipeCD:Clear()
            outerSwipeCD:Hide()
        end
    end
end

local SWIPE_GCD_EVENTS = {
    UNIT_SPELLCAST_SUCCEEDED = true,
    UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true,
}

--- Register/unregister the shared on-ring swipe event frame per settings.
function CE:ApplySwipeDriver()
    if not middleSwipeCD then return end
    local resolved = self:GetResolvedState()
    local wantMiddle = resolved.middleSwipe.enabled and CursorEnhancerModule._moduleEnabled
    local wantOuter  = resolved.outerSwipe.enabled and CursorEnhancerModule._moduleEnabled

    if not (wantMiddle or wantOuter) then
        if swipeDriver then
            swipeDriver:UnregisterAllEvents()
        end
        if middleSwipeCD then middleSwipeCD:Clear(); middleSwipeCD:Hide() end
        if outerSwipeCD then outerSwipeCD:Clear(); outerSwipeCD:Hide() end
        return
    end

    if not swipeDriver then
        swipeDriver = CreateFrame("Frame", "OneWoW_QoL_CursorEnhancerSwipes")
        swipeDriver:SetScript("OnEvent", function(_, event, unit)
            if unit ~= "player" then return end
            local s2 = CE:GetResolvedState()
            if SWIPE_GCD_EVENTS[event] and s2.middleSwipe.enabled then
                DriveMiddleGCDSwipe(event)
            end
            -- SUCCEEDED is GCD-only; every other registered event concerns casts.
            if event ~= "UNIT_SPELLCAST_SUCCEEDED" and s2.outerSwipe.enabled then
                DriveOuterCastSwipe(event)
            end
        end)
    end

    swipeDriver:UnregisterAllEvents()
    if wantMiddle then
        swipeDriver:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        swipeDriver:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
        swipeDriver:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    else
        middleSwipeCD:Clear()
        middleSwipeCD:Hide()
    end
    if wantOuter then
        swipeDriver:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
        swipeDriver:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
        swipeDriver:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
        swipeDriver:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
        swipeDriver:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
        swipeDriver:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
        swipeDriver:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
        swipeDriver:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
        swipeDriver:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "player")
        swipeDriver:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", "player")
        swipeDriver:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")
    else
        outerSwipeCD:Clear()
        outerSwipeCD:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- Resource pips — class power (Holy Power, combo points, shards, …) shown as
-- dots arced along the bottom of the cursor ring. Player-own power values are
-- not secret, so reading them is safe in instanced content.
-- Runtime visibility is situation-driven (resolved.pipsEnabled), not the global
-- pipsEnabled template flag used when adding new situation cards.
-- ----------------------------------------------------------------------------

-- classFile -> { powerType (or "RUNES"), palette key (unused; look uses pipColor) }
local CLASS_POWER = {
    PALADIN     = { Enum.PowerType.HolyPower,     "HOLY_POWER" },
    ROGUE       = { Enum.PowerType.ComboPoints,   "COMBO_POINTS" },
    DRUID       = { Enum.PowerType.ComboPoints,   "COMBO_POINTS" },
    WARLOCK     = { Enum.PowerType.SoulShards,    "SOUL_SHARDS" },
    MAGE        = { Enum.PowerType.ArcaneCharges, "ARCANE_CHARGES" },
    MONK        = { Enum.PowerType.Chi,           "CHI" },
    EVOKER      = { Enum.PowerType.Essence,       "ESSENCE" },
    DEATHKNIGHT = { "RUNES",                      "RUNES" },
}

local SPEC_WARLOCK_DESTRUCTION = 267
local pipDriver
local pipNeedsFrequent

--- Soul Shards: unmodified power is fragment-scaled (× UnitPowerDisplayMod).
--- Aff/Demo expose whole shards; Destruction keeps fractional fragments.
local function GetWarlockShards(powerType)
    local raw = UnitPower("player", powerType, true) or 0
    local mod = UnitPowerDisplayMod(powerType) or 0
    local shards = (mod ~= 0) and (raw / mod) or (UnitPower("player", powerType) or 0)
    local specIndex = C_SpecializationInfo.GetSpecialization()
    local specID = specIndex and (C_SpecializationInfo.GetSpecializationInfo(specIndex))
    if specID ~= SPEC_WARLOCK_DESTRUCTION then
        shards = floor(shards + 1e-6)
    end
    return shards
end

local function GetPipPower()
    local _, class = UnitClass("player")
    local info = CLASS_POWER[class]
    if not info then return nil end

    if info[1] == "RUNES" then
        local ready = 0
        for i = 1, 6 do
            local _, _, runeReady = GetRuneCooldown(i)
            if runeReady then ready = ready + 1 end
        end
        return 6, ready, info[2], false
    end

    local powerType = info[1]
    local maxPower = UnitPowerMax("player", powerType)
    if not maxPower or maxPower <= 0 then return nil end

    local current
    local frequent = false
    if class == "WARLOCK" then
        current = GetWarlockShards(powerType)
        frequent = current > 0 and current < maxPower and current ~= floor(current)
    else
        current = UnitPower("player", powerType) or 0
    end
    return maxPower, current, info[2], frequent
end

--- Rebuild/refresh the pip display from current class power.
function CE:UpdatePips()
    if not pipFrame then return end
    if not CursorEnhancerModule._moduleEnabled then
        pipFrame:Hide()
        pipNeedsFrequent = false
        return
    end

    local resolved = self:GetResolvedState()
    if not resolved.pipsEnabled then
        pipFrame:Hide()
        pipNeedsFrequent = false
        return
    end

    local maxPower, current, _, frequent = GetPipPower()
    if not maxPower then
        pipFrame:Hide()
        pipNeedsFrequent = false
        return
    end
    current = current or 0
    pipNeedsFrequent = frequent == true

    local ringSize = resolved.ringSize or 90
    local radius = ringSize * 0.42 -- sit just inside the outer ring rim
    local spacing = 22 -- degrees between pips
    -- +1 = left→right along the bottom arc; -1 = right→left (legacy layout).
    local dir = (resolved.pipFillLtr ~= false) and 1 or -1
    local startAngle = 270 - dir * ((maxPower - 1) * spacing * 0.5)
    local pipSize = Clamp(resolved.pipSize or 28, 12, 64)
    local ox = resolved.pipOffsetX or 0
    local oy = resolved.pipOffsetY or 0
    local fr, fg, fb = ResolveColor(resolved.pipColor, resolved.pipClassColor)
    local filled = floor(current)
    local partial = current - filled

    for i = 1, maxPower do
        local pip = pipTextures[i]
        if not pip then
            pip = pipFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            pipTextures[i] = pip
        end
        -- Same sparkle asset as the mouse trail; ADD blend is required or the
        -- soft glow reads as invisible even on a black background.
        pip:SetTexture(MEDIA .. "sparkle")
        pip:SetBlendMode("ADD")
        local angle = rad(startAngle + dir * ((i - 1) * spacing))
        pip:SetSize(pipSize, pipSize)
        pip:ClearAllPoints()
        pip:SetPoint("CENTER", pipFrame, "CENTER",
            cos(angle) * radius + ox, sin(angle) * radius + oy)
        if i <= filled then
            pip:SetVertexColor(fr, fg, fb, 1)
        elseif i == filled + 1 and partial > 0.05 then
            local a = 0.40 + (0.60 * Clamp(partial, 0, 1))
            pip:SetVertexColor(fr, fg, fb, a)
        else
            -- Dim empty slots still need enough RGB for ADD to show a ghost pip
            pip:SetVertexColor(fr * 0.45, fg * 0.45, fb * 0.45, 0.70)
        end
        pip:Show()
    end
    for i = maxPower + 1, #pipTextures do
        pipTextures[i]:Hide()
    end

    -- Keep above ring art / cooldown swipes if mainFrame level shifts.
    pipFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 5)
    pipFrame:Show()
end

--- Register/unregister the pip power-event frame per resolved situation.
function CE:ApplyPips()
    local resolved = self:GetResolvedState()
    local want = resolved.pipsEnabled and CursorEnhancerModule._moduleEnabled

    local function SyncFrequentDriver()
        if not pipDriver then return end
        if pipNeedsFrequent then
            if pipDriver._pipFrequent then return end
            pipDriver._pipFrequent = true
            local elapsed = 0
            pipDriver:SetScript("OnUpdate", function(_, dt)
                elapsed = elapsed + dt
                if elapsed < 0.05 then return end
                elapsed = 0
                CE:UpdatePips()
                if not pipNeedsFrequent then
                    pipDriver._pipFrequent = nil
                    pipDriver:SetScript("OnUpdate", nil)
                end
            end)
        else
            pipDriver._pipFrequent = nil
            pipDriver:SetScript("OnUpdate", nil)
        end
    end

    if not want then
        if pipDriver then
            pipDriver:UnregisterAllEvents()
            pipDriver._pipFrequent = nil
            pipDriver:SetScript("OnUpdate", nil)
        end
        pipNeedsFrequent = false
        if pipFrame then pipFrame:Hide() end
        return
    end

    if not pipDriver then
        pipDriver = CreateFrame("Frame", "OneWoW_QoL_CursorEnhancerPips")
        pipDriver:SetScript("OnEvent", function()
            CE:UpdatePips()
            SyncFrequentDriver()
        end)
    end

    pipDriver:UnregisterAllEvents()
    pipDriver:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    pipDriver:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    pipDriver:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    pipDriver:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    pipDriver:RegisterEvent("RUNE_POWER_UPDATE")
    pipDriver:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

    self:UpdatePips()
    SyncFrequentDriver()
end

-- ----------------------------------------------------------------------------
-- Only while mouse look — show the ring only while mouselooking (cursor
-- hidden). Post-hook WoW's world mouse handlers; a press must be HELD past a
-- short delay to count (ignores quick UI clicks). Always hook when the module
-- is enabled so situation overrides can gate without reinstalling hooks.
-- ----------------------------------------------------------------------------
local mlFeatureOn = false
local mlLeft, mlRight, mlPending = false, false, false
local ML_HOLD_DELAY = 0.15
local mlHooked = false

local function ML_Show()
    mlPending = false
    if mlFeatureOn and (mlLeft or mlRight) and not mouselookActive then
        mouselookActive = true
        CE:UpdateVisibility()
        CE:UpdateAll()
    end
end

local function ML_ControlStart()
    if not mlFeatureOn or mouselookActive or mlPending then return end
    mlPending = true
    C_Timer.After(ML_HOLD_DELAY, ML_Show)
end

local function ML_ControlStop()
    if mlFeatureOn and not (mlLeft or mlRight) and mouselookActive then
        mouselookActive = false
        CE:UpdateVisibility()
        CE:UpdateAll()
    end
end

local function ML_InstallHooks()
    if mlHooked then return end
    mlHooked = true
    if type(CameraOrSelectOrMoveStart) == "function" then
        hooksecurefunc("CameraOrSelectOrMoveStart", function() mlLeft = true; ML_ControlStart() end)
        hooksecurefunc("CameraOrSelectOrMoveStop", function() mlLeft = false; ML_ControlStop() end)
    end
    if type(TurnOrActionStart) == "function" then
        hooksecurefunc("TurnOrActionStart", function() mlRight = true; ML_ControlStart() end)
        hooksecurefunc("TurnOrActionStop", function() mlRight = false; ML_ControlStop() end)
    end
end

function CE:ApplyOnlyWhenHidden()
    mlFeatureOn = CursorEnhancerModule._moduleEnabled and true or false
    if mlFeatureOn then
        ML_InstallHooks()
    else
        mlLeft, mlRight, mlPending, mouselookActive = false, false, false, false
    end
    self:UpdateVisibility()
end

-- ----------------------------------------------------------------------------
-- Aggregate apply / ticker lifecycle
-- ----------------------------------------------------------------------------
function CE:ApplyAll()
    self:UpdateAll()
    self:ApplyTrail()
    self:ApplyGCD()
    self:ApplyCast()
    self:ApplySwipeDriver()
    self:ApplyPips()
    self:ApplyOnlyWhenHidden()
end

function CE:StopUpdateTicker()
    if mainFrame then mainFrame:Hide() end
    cursorVisible = false
    HideAllTrail()
    if gcdRoot then gcdRoot:Hide(); gcdRoot:SetScript("OnUpdate", nil) end
    if castRoot then castRoot:Hide(); castRoot:SetScript("OnUpdate", nil) end
    if swipeDriver then swipeDriver:UnregisterAllEvents() end
    if pipDriver then
        pipDriver:UnregisterAllEvents()
        pipDriver._pipFrequent = nil
        pipDriver:SetScript("OnUpdate", nil)
    end
    pipNeedsFrequent = false
    if pipFrame then pipFrame:Hide() end
end

-- ----------------------------------------------------------------------------
-- Module lifecycle
-- ----------------------------------------------------------------------------
function CursorEnhancerModule:OnEnable()
    self._moduleEnabled = true

    local settings = CE:GetSettings()
    settings.outerRingEnabled   = ns.ModuleRegistry:GetToggleValue("cursorenhancer", "outer_ring")
    settings.middleRingEnabled  = ns.ModuleRegistry:GetToggleValue("cursorenhancer", "middle_ring")
    settings.centerMarkerHidden = not ns.ModuleRegistry:GetToggleValue("cursorenhancer", "center_marker")
    settings.mouseTrail         = ns.ModuleRegistry:GetToggleValue("cursorenhancer", "mouse_trail")

    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_CursorEnhancerEvents")
        self._eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        self._eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        self._eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        self._eventFrame:SetScript("OnEvent", function()
            CE:RefreshSwipeVisibility()
        end)
    end

    OneWoW.Restriction.RegisterStateCallback("cursorenhancer", function()
        CE:RefreshSwipeVisibility()
    end)

    OneWoW_QoL:RegisterEnteringWorldHandler("cursorenhancer", function()
        CE:CreateCursorRing()
        CE:ApplyAll()
    end)

    CE:CreateCursorRing()
    CE:ApplyAll()
end

function CursorEnhancerModule:OnDisable()
    self._moduleEnabled = false
    OneWoW.Restriction.UnregisterStateCallback("cursorenhancer")
    CE:StopUpdateTicker()
    CE:ApplyOnlyWhenHidden()
    OneWoW_QoL:UnregisterEnteringWorldHandler("cursorenhancer")
end

function CursorEnhancerModule:OnToggle(toggleId, value)
    local settings = CE:GetSettings()
    if toggleId == "outer_ring" then
        settings.outerRingEnabled = value
    elseif toggleId == "middle_ring" then
        settings.middleRingEnabled = value
    elseif toggleId == "center_marker" then
        settings.centerMarkerHidden = not value
    elseif toggleId == "mouse_trail" then
        settings.mouseTrail = value
    end
    CE:ApplyAll()
end

CursorEnhancerModule.CE = CE
