local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local OverlayIcons = OneWoW.OverlayIcons

-- ============================================================================
-- WayPinsVisual
-- ============================================================================
-- Paints a OneWay Pin button: icon, optional background, optional spin/zoom
-- effects. Reuses OverlayIcons specs and the same atlas names overlays use
-- for backgrounds. Animation stays on the pin frame so Overlays2 contracts
-- are unchanged. Extra layers cost frames and anim groups; the edit dialog
-- warns about that.
-- ============================================================================

local Visual = {}
ns.WayPinsVisual = Visual

local DEFAULT_WORLD = 22
local DEFAULT_MINIMAP = 16
local ICON_ZOOM = 1.5
local BG_ZOOM = 1.8

Visual.BG_STYLES = {
    "Solid-Circle",
    "Solid-Square",
    "Glow Pulse",
    "Spinning Orbs",
    "Portal Spiral",
    "bags-glow-white",
    "bags-glow-purple",
    "ArtifactsFX-SpinningGlowys",
    "PowerSwirlAnimation-YellowRing",
    "auctionhouse-itemicon-border-purple",
}

local function Clamp(n, lo, hi)
    n = tonumber(n)
    if not n then return nil end
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

function Visual.WorldDefault()
    return Clamp(ns.db.global.waypinWorldSize, 12, 48) or DEFAULT_WORLD
end

function Visual.MinimapDefault()
    return Clamp(ns.db.global.waypinMinimapSize, 10, 28) or DEFAULT_MINIMAP
end

function Visual.WorldSize(pin)
    if pin and pin.mapSize then
        return Clamp(pin.mapSize, 12, 64)
    end
    return Visual.WorldDefault()
end

function Visual.ShowWorld()
    return ns.db.global.waypinShowWorld ~= false
end

function Visual.ShowMinimap()
    return ns.db.global.waypinShowMinimap ~= false
end

local function SetupIconAnim(look)
    if look.iconAnim then return end
    local ag = look.iconFrame:CreateAnimationGroup()
    local spin1 = ag:CreateAnimation("Rotation")
    spin1:SetDuration(1.5)
    spin1:SetDegrees(-360)
    spin1:SetOrder(1)
    local scaleUp = ag:CreateAnimation("Scale")
    scaleUp:SetDuration(0.75)
    scaleUp:SetScale(ICON_ZOOM, ICON_ZOOM)
    scaleUp:SetOrder(1)
    local spin2 = ag:CreateAnimation("Rotation")
    spin2:SetDuration(1.5)
    spin2:SetDegrees(-360)
    spin2:SetOrder(2)
    local scaleDown = ag:CreateAnimation("Scale")
    scaleDown:SetDuration(0.75)
    scaleDown:SetScale(1 / ICON_ZOOM, 1 / ICON_ZOOM)
    scaleDown:SetOrder(2)
    ag:SetLooping("REPEAT")
    look.iconAnim = ag
    look.iconSpin1 = spin1
    look.iconSpin2 = spin2
    look.iconScaleUp = scaleUp
    look.iconScaleDown = scaleDown
end

local function SetupBgAnim(look)
    if look.bgAnim then return end
    local ag = look.bgTex:CreateAnimationGroup()
    local spin1 = ag:CreateAnimation("Rotation")
    spin1:SetDuration(1.5)
    spin1:SetDegrees(-360)
    spin1:SetOrder(1)
    local scaleUp = ag:CreateAnimation("Scale")
    scaleUp:SetDuration(0.75)
    scaleUp:SetScale(BG_ZOOM, BG_ZOOM)
    scaleUp:SetOrder(1)
    local spin2 = ag:CreateAnimation("Rotation")
    spin2:SetDuration(1.5)
    spin2:SetDegrees(-360)
    spin2:SetOrder(2)
    local scaleDown = ag:CreateAnimation("Scale")
    scaleDown:SetDuration(0.75)
    scaleDown:SetScale(1 / BG_ZOOM, 1 / BG_ZOOM)
    scaleDown:SetOrder(2)
    ag:SetLooping("REPEAT")

    local pulse = look.bgTex:CreateAnimationGroup()
    local fadeOut = pulse:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1.0)
    fadeOut:SetToAlpha(0.3)
    fadeOut:SetDuration(0.75)
    fadeOut:SetOrder(1)
    local fadeIn = pulse:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.3)
    fadeIn:SetToAlpha(1.0)
    fadeIn:SetDuration(0.75)
    fadeIn:SetOrder(2)
    pulse:SetLooping("REPEAT")

    look.bgAnim = ag
    look.bgSpin1 = spin1
    look.bgSpin2 = spin2
    look.bgScaleUp = scaleUp
    look.bgScaleDown = scaleDown
    look.bgPulse = pulse
end

local function ConfigureSpinZoom(spin1, spin2, scaleUp, scaleDown, effect, zoom)
    local hasSpin = (effect == "spinning" or effect == "both")
    local hasZoom = (effect == "zooming" or effect == "both")
    spin1:SetDegrees(hasSpin and -360 or 0)
    spin2:SetDegrees(hasSpin and -360 or 0)
    scaleUp:SetScale(hasZoom and zoom or 1, hasZoom and zoom or 1)
    scaleDown:SetScale(hasZoom and (1 / zoom) or 1, hasZoom and (1 / zoom) or 1)
end

local function StopAnims(look)
    if look.iconAnim then look.iconAnim:Stop() end
    if look.bgAnim then look.bgAnim:Stop() end
    if look.bgPulse then look.bgPulse:Stop() end
end

function Visual.Attach(btn)
    if btn._wayLook then return btn._wayLook end

    local bgFrame = CreateFrame("Frame", nil, btn)
    bgFrame:SetAllPoints()
    bgFrame:EnableMouse(false)
    local bgTex = bgFrame:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()

    local iconFrame = CreateFrame("Frame", nil, btn)
    iconFrame:SetAllPoints()
    iconFrame:EnableMouse(false)
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()

    local glow = btn:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("CENTER")
    glow:SetAtlas("UI-QuestPoiImportant-OuterGlow")
    glow:Hide()

    local look = {
        bgFrame = bgFrame,
        bgTex = bgTex,
        iconFrame = iconFrame,
        icon = icon,
        glow = glow,
        bgMask = nil,
        bgMaskOn = false,
    }
    btn._wayLook = look
    btn.icon = icon
    btn.glow = glow
    return look
end

local function ApplyCircleMask(look)
    if not look.bgMask then
        local mask = look.bgFrame:CreateMaskTexture()
        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(look.bgFrame)
        look.bgMask = mask
    end
    if not look.bgMaskOn then
        look.bgTex:AddMaskTexture(look.bgMask)
        look.bgMaskOn = true
    end
    look.bgMask:Show()
end

local function RemoveCircleMask(look)
    if look.bgMask and look.bgMaskOn then
        look.bgTex:RemoveMaskTexture(look.bgMask)
        look.bgMaskOn = false
        look.bgMask:Hide()
    end
end

local function ApplyBackground(look, bg, size)
    if not bg or not bg.enabled then
        StopAnims(look)
        look.bgFrame:Hide()
        return
    end

    SetupBgAnim(look)
    look.bgAnim:Stop()
    look.bgPulse:Stop()

    local style = bg.style or "Solid-Circle"
    local scale = tonumber(bg.scale) or 1
    local color = bg.color or { 1, 1, 1 }
    local bgSize = size * 1.6 * scale
    look.bgFrame:SetSize(bgSize, bgSize)
    look.bgFrame:ClearAllPoints()
    look.bgFrame:SetPoint("CENTER")
    look.bgTex:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1)

    local stylePulse = false
    local styleSpin = false
    if style == "Spinning Orbs" then
        RemoveCircleMask(look)
        look.bgTex:SetTexture(nil)
        look.bgTex:SetAtlas("ArtifactsFX-SpinningGlowys-Purple", false)
        styleSpin = true
    elseif style == "Portal Spiral" then
        RemoveCircleMask(look)
        look.bgTex:SetTexture(nil)
        look.bgTex:SetAtlas("UI-Frame-jailerstower-Portrait-QualityEpic", false)
        styleSpin = true
    elseif style == "Glow Pulse" then
        look.bgTex:SetAtlas("")
        look.bgTex:SetTexture("Interface\\Buttons\\WHITE8x8")
        ApplyCircleMask(look)
        stylePulse = true
    elseif C_Texture.GetAtlasInfo(style) then
        RemoveCircleMask(look)
        look.bgTex:SetTexture(nil)
        look.bgTex:SetAtlas(style, false)
        if style:find("PowerSwirlAnimation", 1, true) or style:find("ArtifactsFX", 1, true) then
            styleSpin = true
        end
    else
        look.bgTex:SetAtlas("")
        look.bgTex:SetTexture("Interface\\Buttons\\WHITE8x8")
        if style == "Solid-Circle" then
            ApplyCircleMask(look)
        else
            RemoveCircleMask(look)
        end
    end

    local userEffect = bg.effect
    if userEffect and userEffect ~= "none" then
        ConfigureSpinZoom(look.bgSpin1, look.bgSpin2, look.bgScaleUp, look.bgScaleDown, userEffect, BG_ZOOM)
        look.bgAnim:Play()
    elseif stylePulse then
        look.bgPulse:Play()
    elseif styleSpin then
        ConfigureSpinZoom(look.bgSpin1, look.bgSpin2, look.bgScaleUp, look.bgScaleDown, "both", BG_ZOOM)
        look.bgAnim:Play()
    end
    look.bgFrame:Show()
end

local function ApplyIconEffect(look, effect)
    if not effect or effect == "none" then
        if look.iconAnim then look.iconAnim:Stop() end
        return
    end
    SetupIconAnim(look)
    look.iconAnim:Stop()
    ConfigureSpinZoom(look.iconSpin1, look.iconSpin2, look.iconScaleUp, look.iconScaleDown, effect, ICON_ZOOM)
    look.iconAnim:Play()
end

--- Paint icon / background / effects and size the button.
---@param btn Button
---@param pin table
---@param opts table|nil { size = number, tracked = boolean }
function Visual.Apply(btn, pin, opts)
    opts = opts or {}
    local look = Visual.Attach(btn)
    local size = opts.size or Visual.WorldSize(pin)
    btn:SetSize(size, size)
    look.iconFrame:SetFrameLevel(btn:GetFrameLevel() + 2)
    look.bgFrame:SetFrameLevel(btn:GetFrameLevel())

    OverlayIcons:ApplyIconSpec(look.icon, pin.icon)
    if opts.tracked then
        look.icon:SetVertexColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
        look.glow:SetSize(size + 10, size + 10)
        look.glow:Show()
    else
        look.glow:Hide()
    end

    ApplyBackground(look, pin.bg, size)
    ApplyIconEffect(look, pin.effect)
end

function Visual.Hide(btn)
    if not btn then return end
    if btn._wayLook then
        StopAnims(btn._wayLook)
    end
    btn:Hide()
end
