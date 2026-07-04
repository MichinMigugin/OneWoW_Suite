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
-- Options UI lives in cursorenhancer-ui.lua; this file exposes the CE table
-- and Apply* refreshers it calls.
-- ============================================================================

local _, ns = ...
local CursorEnhancerModule, L = ns.ModuleRegistry:Current()
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
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local GetUnitEmpowerHoldAtMaxTime = GetUnitEmpowerHoldAtMaxTime
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local hooksecurefunc = hooksecurefunc

local CE = {}

local MEDIA = "Interface\\AddOns\\OneWoW_QoL\\Media\\"

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
    local _, class = UnitClass("player")
    local classColor = RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }
    return {
        ringSize          = 90,
        offsetX           = 0,
        offsetY           = 0,
        combatAlpha       = 1.0,
        outOfCombatAlpha  = 1.0,
        showOutOfCombat   = true,
        showInInstance    = true,
        onlyWhenHidden    = false,
        visibility        = "always",
        outerRingEnabled  = true,
        outerRingColor    = { classColor.r, classColor.g, classColor.b },
        outerRingClassColor = false,
        middleRingEnabled = false,
        middleRingColor   = { 1.0, 1.0, 1.0 },
        centerMarker      = "Dot",
        centerMarkerColor = { 1.0, 1.0, 1.0 },
        mouseTrail        = false,
        trailColor        = { 1.0, 1.0, 1.0 },
        trailFadeTime     = 0.6,
        trailStyle        = "ring",
        trailSize         = 36,
        middleSwipe       = { enabled = false, fill = false },
        outerSwipe        = { enabled = false, fill = false },
        pipsEnabled       = false,
        gcd = {
            enabled      = false,
            attached     = true,
            radius       = 21,
            ringTex      = "c1",
            scale        = 100,
            color        = { 1.0, 1.0, 1.0 },
            useClassColor = false,
            alpha        = 0.8,
            instanceOnly = false,
        },
        castCircle = {
            enabled       = false,
            attached      = true,
            radius        = 30,
            ringTex       = "c1",
            scale         = 100,
            color         = { classColor.r, classColor.g, classColor.b },
            useClassColor = true,
            alpha         = 0.8,
            sparkEnabled  = true,
            instanceOnly  = false,
        },
    }
end

--- Fill any keys missing from dst using src (recurses one level into subtables).
--- Backfills new defaults onto profiles saved before those keys existed.
---@param dst table
---@param src table
local function MergeMissing(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            MergeMissing(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
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
    MergeMissing(profile, GetDefaults())
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

local function InInstanceContent()
    local inInst, t = IsInInstance()
    return inInst and (t == "party" or t == "raid" or t == "pvp" or t == "arena" or t == "scenario")
end

-- ----------------------------------------------------------------------------
-- Visibility
-- ----------------------------------------------------------------------------
--- Whether the cursor circle should currently be visible.
---@return boolean
function CE:ShouldShow()
    if not CursorEnhancerModule._moduleEnabled then return false end
    local settings = self:GetSettings()
    local inCombat = OneWoW.Restriction.IsInCombat() or UnitAffectingCombat("player")

    local mode = settings.visibility or "always"
    if mode == "never" then
        return false
    elseif mode == "in_combat" then
        if not inCombat then return false end
    elseif mode == "out_of_combat" then
        if inCombat then return false end
    elseif mode == "in_raid" then
        if not IsInRaid() then return false end
    elseif mode == "in_party" then
        if not (IsInGroup() and not IsInRaid()) then return false end
    elseif mode == "solo" then
        if IsInGroup() then return false end
    end

    -- Base combat / instance rules (legacy toggles, layered on top of mode).
    local baseShow
    if inCombat then
        baseShow = true
    elseif InInstanceContent() and settings.showInInstance then
        baseShow = true
    else
        baseShow = settings.showOutOfCombat
    end
    if not baseShow then return false end

    if settings.onlyWhenHidden and not mouselookActive then
        return false
    end
    return true
end

function CE:GetCursorAlpha()
    local settings = self:GetSettings()
    local inCombat = OneWoW.Restriction.IsInCombat()
    local combatContext = inCombat or InInstanceContent()
    return combatContext and (settings.combatAlpha or 1.0) or (settings.outOfCombatAlpha or 1.0)
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

    self:RefreshSwipeVisibility()
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
    local settings = self:GetSettings()
    local size = settings.ringSize or 90

    offX = settings.offsetX or 0
    offY = settings.offsetY or 0

    mainFrame:SetSize(size, size)

    outerRing:SetSize(size, size)
    outerRing:SetVertexColor(ResolveColor(settings.outerRingColor, settings.outerRingClassColor))
    outerRing:SetShown(settings.outerRingEnabled ~= false)

    middleRing:SetSize(size * 0.75, size * 0.75)
    middleRing:SetVertexColor(ResolveColor(settings.middleRingColor))
    middleRing:SetShown(settings.middleRingEnabled == true)

    outerSwipeCD:SetSize(size, size)
    local oR, oG, oB = ResolveColor(settings.outerRingColor, settings.outerRingClassColor)
    outerSwipeCD:SetSwipeColor(oR, oG, oB, 1)
    outerSwipeCD:SetReverse(settings.outerSwipe.fill == true)
    if not settings.outerSwipe.enabled then outerSwipeCD:Hide() end

    middleSwipeCD:SetSize(size * 0.75, size * 0.75)
    local mR, mG, mB = ResolveColor(settings.middleRingColor)
    middleSwipeCD:SetSwipeColor(mR, mG, mB, 1)
    middleSwipeCD:SetReverse(settings.middleSwipe.fill == true)
    if not settings.middleSwipe.enabled then middleSwipeCD:Hide() end

    self:ApplySwipeDriver()
    self:UpdatePips()

    if settings.centerMarkerHidden then
        centerMarker:Hide()
    else
        local markerType = settings.centerMarker or "Dot"
        if markerType == "None" then
            centerMarker:Hide()
        else
            centerMarker:Show()
            if markerType == "Dot" then
                centerMarker:SetTexture(MEDIA .. "sparkle")
                centerMarker:SetSize(12, 12)
            elseif markerType == "Star" then
                centerMarker:SetTexture(MEDIA .. "c3")
                centerMarker:SetSize(20, 20)
            elseif markerType == "Cross" then
                centerMarker:SetAtlas("uitools-icon-plus")
                centerMarker:SetSize(16, 16)
            elseif markerType == "Diamond" then
                centerMarker:SetAtlas("UF-SoulShard-FX-FrameGlow")
                centerMarker:SetSize(20, 20)
            elseif markerType == "Ring" then
                centerMarker:SetTexture(MEDIA .. "c2")
                centerMarker:SetSize(24, 24)
            end
            centerMarker:SetVertexColor(ResolveColor(settings.centerMarkerColor))
        end
    end

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
    if not (settings.mouseTrail and CE:ShouldShow()) then return end

    local s = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / s, y / s
    trailTimer = trailTimer + elapsed
    local dx, dy = x - trailLastX, y - trailLastY
    local moved = (dx * dx + dy * dy) ^ 0.5
    if trailTimer < TRAIL_DENSITY or moved < 0.5 then return end
    trailTimer = 0
    trailLastX, trailLastY = x, y

    local c = settings.trailColor
    local size = settings.trailSize or 36
    local fade = settings.trailFadeTime or 0.6
    local stylePath = CE.TRAIL_STYLES[settings.trailStyle or "ring"] or CE.TRAIL_STYLES.ring

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
    local settings = self:GetSettings()
    if settings.mouseTrail and CursorEnhancerModule._moduleEnabled then
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
        local g2 = CE:GetSettings().gcd
        if not g2.enabled then return end
        if g2.instanceOnly and not InInstanceContent() then return end
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
    local g = self:GetSettings().gcd
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

    if g.instanceOnly and not InInstanceContent() then
        gcdRoot:Hide()
        gcdRoot:SetScript("OnUpdate", nil)
        return
    end
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
        local c2 = CE:GetSettings().castCircle
        if not c2.enabled then return end
        if c2.instanceOnly and not InInstanceContent() then return end

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
    local c = self:GetSettings().castCircle
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

    if c.instanceOnly and not InInstanceContent() then
        castRoot:Hide()
        castRoot:SetScript("OnUpdate", nil)
        return
    end
    castRoot:Show()
    ApplySwipeTracking(castRoot, c.attached ~= false)
end

--- Re-evaluate instance-only gating on the swipe rings when zone/state changes.
function CE:RefreshSwipeVisibility()
    if gcdRoot then self:ApplyGCD() end
    if castRoot then self:ApplyCast() end
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
    local s = self:GetSettings()
    local wantMiddle = s.middleSwipe.enabled and CursorEnhancerModule._moduleEnabled
    local wantOuter  = s.outerSwipe.enabled and CursorEnhancerModule._moduleEnabled

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
            local s2 = CE:GetSettings()
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
-- ----------------------------------------------------------------------------
local PIP_COLORS = {
    HOLY_POWER     = { 1.00, 0.85, 0.30 },
    COMBO_POINTS   = { 1.00, 0.60, 0.20 },
    SOUL_SHARDS    = { 0.60, 0.30, 0.90 },
    ARCANE_CHARGES = { 0.35, 0.60, 1.00 },
    CHI            = { 0.40, 1.00, 0.70 },
    ESSENCE        = { 0.20, 0.80, 0.80 },
    RUNES          = { 0.80, 0.20, 0.30 },
}

-- classFile -> { powerType (or "RUNES"), palette key }
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

local pipDriver

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
        return 6, ready, info[2]
    end

    local maxPower = UnitPowerMax("player", info[1])
    if not maxPower or maxPower <= 0 then return nil end
    local current = UnitPower("player", info[1])
    return maxPower, current or 0, info[2]
end

--- Rebuild/refresh the pip display from current class power.
function CE:UpdatePips()
    if not pipFrame then return end
    local s = self:GetSettings()
    if not (s.pipsEnabled and CursorEnhancerModule._moduleEnabled) then
        pipFrame:Hide()
        return
    end

    local maxPower, current, paletteKey = GetPipPower()
    if not maxPower or current <= 0 then
        pipFrame:Hide()
        return
    end

    local size = s.ringSize or 90
    local radius = size * 0.5
    local pipSize = Clamp(floor(size * 0.13), 8, 16)
    local spacing = 22 -- degrees between pips
    local startAngle = 270 + ((maxPower - 1) * spacing * 0.5)
    local color = PIP_COLORS[paletteKey] or { 1, 1, 1 }

    for i = 1, maxPower do
        local pip = pipTextures[i]
        if not pip then
            pip = pipFrame:CreateTexture(nil, "OVERLAY")
            pip:SetTexture(MEDIA .. "sparkle")
            pipTextures[i] = pip
        end
        local angle = rad(startAngle - ((i - 1) * spacing))
        pip:SetSize(pipSize, pipSize)
        pip:ClearAllPoints()
        pip:SetPoint("CENTER", pipFrame, "CENTER", cos(angle) * radius, sin(angle) * radius)
        if i <= current then
            pip:SetVertexColor(color[1], color[2], color[3], 1)
        else
            pip:SetVertexColor(0.4, 0.4, 0.4, 0.45)
        end
        pip:Show()
    end
    for i = maxPower + 1, #pipTextures do
        pipTextures[i]:Hide()
    end

    pipFrame:Show()
end

--- Register/unregister the pip power-event frame per settings.
function CE:ApplyPips()
    local s = self:GetSettings()
    local want = s.pipsEnabled and CursorEnhancerModule._moduleEnabled

    if not want then
        if pipDriver then pipDriver:UnregisterAllEvents() end
        if pipFrame then pipFrame:Hide() end
        return
    end

    if not pipDriver then
        pipDriver = CreateFrame("Frame", "OneWoW_QoL_CursorEnhancerPips")
        pipDriver:SetScript("OnEvent", function()
            CE:UpdatePips()
        end)
    end

    pipDriver:UnregisterAllEvents()
    pipDriver:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    pipDriver:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    pipDriver:RegisterEvent("RUNE_POWER_UPDATE")
    pipDriver:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

    self:UpdatePips()
end

-- ----------------------------------------------------------------------------
-- "Only Show When Hidden" — show the ring only while mouselooking (cursor
-- hidden). Post-hook WoW's world mouse handlers; a press must be HELD past a
-- short delay to count (ignores quick UI clicks).
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
    local settings = self:GetSettings()
    mlFeatureOn = settings.onlyWhenHidden and CursorEnhancerModule._moduleEnabled or false
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
    if pipDriver then pipDriver:UnregisterAllEvents() end
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
    settings.showOutOfCombat    = ns.ModuleRegistry:GetToggleValue("cursorenhancer", "show_out_of_combat")
    settings.showInInstance     = ns.ModuleRegistry:GetToggleValue("cursorenhancer", "show_in_instance")
    settings.mouseTrail         = ns.ModuleRegistry:GetToggleValue("cursorenhancer", "mouse_trail")

    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_CursorEnhancerEvents")
        self._eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        self._eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        self._eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        self._eventFrame:SetScript("OnEvent", function()
            CE:UpdateVisibility()
        end)
    end

    OneWoW_QoL:RegisterEnteringWorldHandler("cursorenhancer", function()
        CE:CreateCursorRing()
        CE:ApplyAll()
    end)

    CE:CreateCursorRing()
    CE:ApplyAll()
end

function CursorEnhancerModule:OnDisable()
    self._moduleEnabled = false
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
    elseif toggleId == "show_out_of_combat" then
        settings.showOutOfCombat = value
    elseif toggleId == "show_in_instance" then
        settings.showInInstance = value
    elseif toggleId == "mouse_trail" then
        settings.mouseTrail = value
        CE:ApplyTrail()
    end
    CE:UpdateAll()
end

-- ============================================================================
-- Options panel (feature-panel detail)
-- ============================================================================
-- Rows are appended directly onto the feature panel's detailScrollChild,
-- continuing the layout the framework already built above (labels at x=12,
-- controls right-aligned at -12, sub-controls indented). No container, no
-- rebuild pass: every control is always visible, and the engine's Apply*
-- entry points no-op while the module is disabled.
-- ============================================================================

local function RingTexItems()
    return {
        { value = "c1", text = L["CURSORENHANCER_TEX_C1"] },
        { value = "c2", text = L["CURSORENHANCER_TEX_C2"] },
    }
end

local function RingTexLabel(v)
    return v == "c2" and L["CURSORENHANCER_TEX_C2"] or L["CURSORENHANCER_TEX_C1"]
end

local TRAIL_STYLE_LABEL = {
    ring  = "CURSORENHANCER_TRAIL_STYLE_RING",
    glow  = "CURSORENHANCER_TRAIL_STYLE_GLOW",
    spark = "CURSORENHANCER_TRAIL_STYLE_SPARK",
}

local function TrailStyleLabel(v)
    return L[TRAIL_STYLE_LABEL[v] or "CURSORENHANCER_TRAIL_STYLE_RING"]
end

local function TrailStyleItems()
    return {
        { value = "ring",  text = TrailStyleLabel("ring") },
        { value = "glow",  text = TrailStyleLabel("glow") },
        { value = "spark", text = TrailStyleLabel("spark") },
    }
end

local MARKER_ORDER = { "Dot", "Star", "Cross", "Diamond", "Ring", "None" }
local MARKER_LABEL = {
    Dot     = "CURSORENHANCER_MARKER_DOT",
    Star    = "CURSORENHANCER_MARKER_STAR",
    Cross   = "CURSORENHANCER_MARKER_CROSS",
    Diamond = "CURSORENHANCER_MARKER_DIAMOND",
    Ring    = "CURSORENHANCER_MARKER_RING",
}

local function MarkerLabel(v)
    if v == "None" then return NONE end
    return L[MARKER_LABEL[v] or "CURSORENHANCER_MARKER_DOT"]
end

local function MarkerItems()
    local items = {}
    for _, key in ipairs(MARKER_ORDER) do
        items[#items + 1] = { value = key, text = MarkerLabel(key) }
    end
    return items
end

local VIS_ORDER = { "always", "never", "in_combat", "out_of_combat", "in_raid", "in_party", "solo" }

local function VisLabel(v)
    if v == "never" then return NEVER end
    if v == "solo" then return SOLO end
    if v == "in_combat" then return L["CURSORENHANCER_VIS_IN_COMBAT"] end
    if v == "out_of_combat" then return L["CURSORENHANCER_VIS_OUT_OF_COMBAT"] end
    if v == "in_raid" then return L["CURSORENHANCER_VIS_IN_RAID"] end
    if v == "in_party" then return L["CURSORENHANCER_VIS_IN_PARTY"] end
    return L["CURSORENHANCER_VIS_ALWAYS"]
end

local function VisItems()
    local items = {}
    for _, key in ipairs(VIS_ORDER) do
        items[#items + 1] = { value = key, text = VisLabel(key) }
    end
    return items
end

function CursorEnhancerModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled)
    local s = CE:GetSettings()
    local labelColor = isEnabled and "TEXT_PRIMARY" or "TEXT_MUTED"

    -- Row builders: each appends one row at the current yOffset and advances it.
    -- Layout mirrors the framework-built rows above: labels at x=12, controls
    -- right-aligned at -12, sub-controls indented to x=24.

    local function Label(x, text)
        local fs = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", x, yOffset)
        fs:SetText(text)
        fs:SetTextColor(OneWoW_GUI:GetThemeColor(labelColor))
        return fs
    end

    local function SliderRow(labelText, minV, maxV, step, cur, fmt, onChange)
        local lbl = Label(12, labelText)
        yOffset = yOffset - lbl:GetStringHeight() - 4
        local sl = OneWoW_GUI:CreateSlider(detailScrollChild, {
            minVal = minV, maxVal = maxV, step = step, currentVal = cur,
            width = 240, fmt = fmt,
            onChange = onChange,
        })
        sl:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 24, yOffset)
        yOffset = yOffset - 42
    end

    local function CheckboxRow(labelText, checked, onClick)
        local cb = OneWoW_GUI:CreateCheckbox(detailScrollChild, {
            label = labelText, checked = checked, onClick = onClick,
        })
        cb:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
        yOffset = yOffset - 28
    end

    local function DropdownRow(labelText, curText, buildItems, getActive, onSelect)
        local lbl = Label(12, labelText)
        yOffset = yOffset - lbl:GetStringHeight() - 4
        local dd, ddText = OneWoW_GUI:CreateDropdown(detailScrollChild, {
            width = 200, height = 22, text = curText,
        })
        dd:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 24, yOffset)
        OneWoW_GUI:AttachFilterMenu(dd, {
            searchable = false,
            getActiveValue = getActive,
            buildItems = buildItems,
            onSelect = function(value, text)
                ddText:SetText(text)
                onSelect(value)
            end,
        })
        yOffset = yOffset - 30
    end

    -- Same shape as the original color rows: label left, swatch right.
    local function ColorRow(labelText, colorTbl, apply)
        Label(12, labelText)
        local swatch = OneWoW_GUI:CreateColorSwatch(detailScrollChild, {
            size = 22,
            getColor = function()
                return colorTbl[1] or 1, colorTbl[2] or 1, colorTbl[3] or 1
            end,
            onColorChanged = function(r, g, b)
                colorTbl[1], colorTbl[2], colorTbl[3] = r, g, b
                apply()
            end,
        })
        swatch:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
        yOffset = yOffset - 28 - 6
    end

    -- ─── Cursor Circle ───────────────────────────────────────────────────────
    yOffset = OneWoW_GUI:CreateSection(detailScrollChild, {
        title = L["CURSORENHANCER_SECTION_CURSOR"], yOffset = yOffset,
    })

    SliderRow(L["CURSORENHANCER_RING_SIZE"], 40, 200, 1, s.ringSize or 90, "%d",
        function(val)
            s.ringSize = val
            CE:UpdateAll()
        end)

    SliderRow(L["CURSORENHANCER_OFFSET_X"], -200, 200, 1, s.offsetX or 0, "%d",
        function(val)
            s.offsetX = val
            CE:UpdateAll()
        end)

    SliderRow(L["CURSORENHANCER_OFFSET_Y"], -200, 200, 1, s.offsetY or 0, "%d",
        function(val)
            s.offsetY = val
            CE:UpdateAll()
        end)

    SliderRow(L["CURSORENHANCER_COMBAT_ALPHA"], 0, 100, 5,
        floor((s.combatAlpha or 1) * 100 + 0.5), "%d%%",
        function(val)
            s.combatAlpha = val / 100
            CE:UpdateVisibility()
        end)

    SliderRow(L["CURSORENHANCER_OOC_ALPHA"], 0, 100, 5,
        floor((s.outOfCombatAlpha or 1) * 100 + 0.5), "%d%%",
        function(val)
            s.outOfCombatAlpha = val / 100
            CE:UpdateVisibility()
        end)

    SliderRow(L["CURSORENHANCER_TRAIL_FADE"], 0.2, 2.0, 0.1, s.trailFadeTime or 0.6, "%.1f",
        function(val)
            s.trailFadeTime = val
        end)

    SliderRow(L["CURSORENHANCER_TRAIL_SIZE"], 8, 96, 1, s.trailSize or 36, "%d",
        function(val)
            s.trailSize = val
        end)

    DropdownRow(L["CURSORENHANCER_TRAIL_STYLE"], TrailStyleLabel(s.trailStyle or "ring"), TrailStyleItems,
        function() return s.trailStyle or "ring" end,
        function(value)
            s.trailStyle = value
        end)

    DropdownRow(L["CURSORENHANCER_VISIBILITY"], VisLabel(s.visibility or "always"), VisItems,
        function() return s.visibility or "always" end,
        function(value)
            s.visibility = value
            CE:UpdateVisibility()
        end)

    DropdownRow(L["CURSORENHANCER_CENTER_MARKER_STYLE"], MarkerLabel(s.centerMarker or "Dot"), MarkerItems,
        function() return s.centerMarker or "Dot" end,
        function(value)
            s.centerMarker = value
            CE:UpdateAll()
        end)

    CheckboxRow(L["CURSORENHANCER_ONLY_WHEN_HIDDEN"], s.onlyWhenHidden, function(myself)
        s.onlyWhenHidden = myself:GetChecked()
        CE:ApplyOnlyWhenHidden()
    end)

    CheckboxRow(L["CURSORENHANCER_USE_CLASS_COLOR"], s.outerRingClassColor, function(myself)
        s.outerRingClassColor = myself:GetChecked()
        CE:UpdateAll()
    end)

    ColorRow(L["CURSORENHANCER_OUTER_RING_COLOR"], s.outerRingColor, function() CE:UpdateAll() end)
    ColorRow(L["CURSORENHANCER_MIDDLE_RING_COLOR"], s.middleRingColor, function() CE:UpdateAll() end)
    ColorRow(L["CURSORENHANCER_CENTER_MARKER_COLOR"], s.centerMarkerColor, function() CE:UpdateAll() end)
    ColorRow(L["CURSORENHANCER_TRAIL_COLOR"], s.trailColor, function() CE:UpdateAll() end)

    -- ─── On-ring swipes (GCD on middle ring, cast on outer ring) ─────────────
    yOffset = OneWoW_GUI:CreateSection(detailScrollChild, {
        title = L["CURSORENHANCER_SECTION_SWIPES"], yOffset = yOffset,
    })

    CheckboxRow(L["CURSORENHANCER_GCD_MIDDLE"], s.middleSwipe.enabled, function(myself)
        s.middleSwipe.enabled = myself:GetChecked()
        CE:UpdateAll()
    end)

    CheckboxRow(L["CURSORENHANCER_SWIPE_FILL"], s.middleSwipe.fill, function(myself)
        s.middleSwipe.fill = myself:GetChecked()
        CE:UpdateAll()
    end)

    CheckboxRow(L["CURSORENHANCER_CAST_OUTER"], s.outerSwipe.enabled, function(myself)
        s.outerSwipe.enabled = myself:GetChecked()
        CE:UpdateAll()
    end)

    CheckboxRow(L["CURSORENHANCER_SWIPE_FILL"], s.outerSwipe.fill, function(myself)
        s.outerSwipe.fill = myself:GetChecked()
        CE:UpdateAll()
    end)

    -- ─── Resource pips ────────────────────────────────────────────────────────
    yOffset = OneWoW_GUI:CreateSection(detailScrollChild, {
        title = L["CURSORENHANCER_SECTION_PIPS"], yOffset = yOffset,
    })

    CheckboxRow(L["CURSORENHANCER_PIPS_ENABLE"], s.pipsEnabled, function(myself)
        s.pipsEnabled = myself:GetChecked()
        CE:ApplyPips()
    end)

    -- ─── GCD / Cast swipe rings (same row shape) ─────────────────────────────
    local function SwipeSection(sectionKey, cfg, enableLabel, apply, hasSpark)
        yOffset = OneWoW_GUI:CreateSection(detailScrollChild, {
            title = L[sectionKey], yOffset = yOffset,
        })

        CheckboxRow(enableLabel, cfg.enabled, function(myself)
            cfg.enabled = myself:GetChecked()
            apply()
        end)

        DropdownRow(L["CURSORENHANCER_RING_TEXTURE"], RingTexLabel(cfg.ringTex or "c1"), RingTexItems,
            function() return cfg.ringTex or "c1" end,
            function(value)
                cfg.ringTex = value
                apply()
            end)

        SliderRow(L["CURSORENHANCER_RADIUS"], 8, 80, 1, cfg.radius or 21, "%d",
            function(val)
                cfg.radius = val
                apply()
            end)

        SliderRow(OPACITY, 0, 100, 5, floor((cfg.alpha or 0.8) * 100 + 0.5), "%d%%",
            function(val)
                cfg.alpha = val / 100
                apply()
            end)

        CheckboxRow(L["CURSORENHANCER_ATTACH"], cfg.attached ~= false, function(myself)
            cfg.attached = myself:GetChecked()
            apply()
        end)

        CheckboxRow(L["CURSORENHANCER_INSTANCE_ONLY"], cfg.instanceOnly, function(myself)
            cfg.instanceOnly = myself:GetChecked()
            apply()
        end)

        if hasSpark then
            CheckboxRow(L["CURSORENHANCER_SHOW_SPARK"], cfg.sparkEnabled ~= false, function(myself)
                cfg.sparkEnabled = myself:GetChecked()
                apply()
            end)
        end

        CheckboxRow(L["CURSORENHANCER_USE_CLASS_COLOR"], cfg.useClassColor, function(myself)
            cfg.useClassColor = myself:GetChecked()
            apply()
        end)

        ColorRow(COLOR, cfg.color, apply)
    end

    SwipeSection("CURSORENHANCER_SECTION_GCD", s.gcd, L["CURSORENHANCER_ENABLE_GCD"],
        function() CE:ApplyGCD() end, false)
    SwipeSection("CURSORENHANCER_SECTION_CAST", s.castCircle, L["CURSORENHANCER_ENABLE_CAST"],
        function() CE:ApplyCast() end, true)

    return yOffset
end

CursorEnhancerModule.CE = CE
