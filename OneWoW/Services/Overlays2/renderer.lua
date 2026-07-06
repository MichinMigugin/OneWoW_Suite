local _, ns = ...

-- ============================================================================
-- Overlays 2.0 — renderer
-- ============================================================================
-- Pure painting layer: owns the per-button overlay container, the icon pool
-- (up to MAX_ICON_OVERLAYS entries), the item level FontString, and the
-- quality border texture. Knows nothing about settings storage or matching;
-- the engine hands it normalized paint configs.
--
-- Deliberately absent from 1.0's renderer: no reads of Blizzard's
-- ItemContextOverlay or button alpha (the source of the Warband Bank
-- darkening bug). Blizzard's dim layer is left entirely alone.
-- ============================================================================

local OneWoW_GUI = OneWoW_GUI

ns.Overlays2Renderer = {}
local Renderer = ns.Overlays2Renderer

local ipairs, math_min = ipairs, math.min
local CreateFrame = CreateFrame

local PositionOffsets = {
    TOPLEFT     = {1, -1},
    TOPRIGHT    = {-1, -1},
    BOTTOMLEFT  = {1,  1},
    BOTTOMRIGHT = {-1,  1},
    BOTTOM      = {0,  1},
    TOP         = {0, -1},
    LEFT        = {1,  0},
    RIGHT       = {-1,  0},
    CENTER      = {0,  0},
}

local OuterPositionData = {
    ["Outer-Top-Left"]      = { "TOPLEFT",     4, -4 },
    ["Outer-Top-Middle"]    = { "TOP",         0, -4 },
    ["Outer-Top-Right"]     = { "TOPRIGHT",   -4, -4 },
    ["Outer-Bottom-Left"]   = { "BOTTOMLEFT",  4,  4 },
    ["Outer-Bottom-Middle"] = { "BOTTOM",      0,  4 },
    ["Outer-Bottom-Right"]  = { "BOTTOMRIGHT",-4,  4 },
}

local InnerAnchorSign = {
    TOPLEFT     = {  1, -1 },
    TOP         = {  0, -1 },
    TOPRIGHT    = { -1, -1 },
    LEFT        = {  1,  0 },
    CENTER      = {  0,  0 },
    RIGHT       = { -1,  0 },
    BOTTOMLEFT  = {  1,  1 },
    BOTTOM      = {  0,  1 },
    BOTTOMRIGHT = { -1,  1 },
}


-- ----------------------------------------------------------------------------
-- Container
-- ----------------------------------------------------------------------------

local function GetOrCreateContainer(button)
    if not button.onewow_overlayContainer then
        local c = CreateFrame("Frame", nil, button)
        c:SetAllPoints(button)
        c:EnableMouse(false)
        -- OneWoW_GUI's rarity border sits at button FrameLevel + 1; keep the
        -- overlay container above it so ilvl/quality overlays stay on top.
        c:SetFrameLevel(button:GetFrameLevel() + 2)
        c:Hide()
        button.onewow_overlayContainer = c
    end
    return button.onewow_overlayContainer
end

--- Pre-anchor the overlay container onto a sub-icon of a composite frame
--- (EJ rows, quest reward buttons, map pins) before the first paint.
function Renderer:PresetContainerOnIcon(button, iconFrame, inset)
    if button.onewow_overlayContainer then return end
    inset = inset or 0
    local c = CreateFrame("Frame", nil, button)
    c:SetPoint("TOPLEFT",     iconFrame, "TOPLEFT",      inset, -inset)
    c:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -inset,  inset)
    c:EnableMouse(false)
    c:SetFrameStrata("HIGH")
    c:Hide()
    button.onewow_overlayContainer = c
end

--- Pre-anchor a fixed-size overlay container (AH browse rows).
function Renderer:PresetContainerFixed(button, parent, w, h, anchorPoint, anchorTo, ox, oy)
    if button.onewow_overlayContainer then return end
    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(w, h)
    c:SetPoint(anchorPoint, anchorTo, anchorPoint, ox, oy)
    c:EnableMouse(false)
    c:SetFrameStrata("HIGH")
    c:Hide()
    button.onewow_overlayContainer = c
end

function Renderer:ShowContainer(button)
    if button.onewow_overlayContainer then
        button.onewow_overlayContainer:Show()
    end
end

local function GetButtonVisualSize(button)
    local container = button.onewow_overlayContainer
    if container then
        local cw, ch = container:GetSize()
        if cw and cw > 1 and ch and ch > 1 then
            return cw, ch
        end
    end
    return button:GetSize()
end

-- ----------------------------------------------------------------------------
-- Clean
-- ----------------------------------------------------------------------------

function Renderer:CleanButton(button)
    if not button then return end
    if button.onewow_overlayContainer then
        button.onewow_overlayContainer:Hide()
    end
    if button.onewow_overlayPool then
        for _, entry in ipairs(button.onewow_overlayPool) do
            if entry.frame then
                entry.frame:ClearAllPoints()
                entry.frame:Hide()
            end
            if entry.iconAnim then entry.iconAnim:Stop() end
            if entry.bgAnim then entry.bgAnim:Stop() end
            if entry.bgPulseAnim then entry.bgPulseAnim:Stop() end
            if entry.bgFrame then entry.bgFrame:Hide() end
        end
    end
    if button.onewow_ilvl then
        button.onewow_ilvl:Hide()
    end
    if button.onewow_qualityBorder then
        button.onewow_qualityBorder:Hide()
    end
    if button.onewow_qualityBorderFrame then
        button.onewow_qualityBorderFrame:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- Icon pool
-- ----------------------------------------------------------------------------

local function GetOrCreatePoolEntry(button, index)
    button.onewow_overlayPool = button.onewow_overlayPool or {}
    if not button.onewow_overlayPool[index] then
        local container = GetOrCreateContainer(button)
        local f = CreateFrame("Frame", nil, container)
        f:SetFrameLevel(button:GetFrameLevel() + 3)
        f:EnableMouse(false)
        local iconFr = CreateFrame("Frame", nil, f)
        iconFr:SetAllPoints(f)
        iconFr:EnableMouse(false)
        iconFr:SetFrameLevel(f:GetFrameLevel() + 1)
        local t = iconFr:CreateTexture(nil, "OVERLAY", nil, 3)
        t:SetAllPoints(iconFr)
        button.onewow_overlayPool[index] = { frame = f, iconFrame = iconFr, texture = t }
    end
    return button.onewow_overlayPool[index]
end

-- ----------------------------------------------------------------------------
-- Icon effects (lazy animation groups)
-- ----------------------------------------------------------------------------

local function SetupIconAnimation(entry)
    if entry.iconAnim then return end
    local ag = entry.iconFrame:CreateAnimationGroup()

    local spin1 = ag:CreateAnimation("Rotation")
    spin1:SetDuration(1.5)
    spin1:SetDegrees(-360)
    spin1:SetOrder(1)

    local scaleUp = ag:CreateAnimation("Scale")
    scaleUp:SetDuration(0.75)
    scaleUp:SetScale(1.5, 1.5)
    scaleUp:SetOrder(1)

    local spin2 = ag:CreateAnimation("Rotation")
    spin2:SetDuration(1.5)
    spin2:SetDegrees(-360)
    spin2:SetOrder(2)

    local scaleDown = ag:CreateAnimation("Scale")
    scaleDown:SetDuration(0.75)
    scaleDown:SetScale(1 / 1.5, 1 / 1.5)
    scaleDown:SetOrder(2)

    ag:SetLooping("REPEAT")

    entry.iconAnim = ag
    entry.iconSpin1 = spin1
    entry.iconSpin2 = spin2
    entry.iconScaleUp = scaleUp
    entry.iconScaleDown = scaleDown
end

local function ApplyIconEffect(entry, effect)
    if not effect or effect == "none" then
        if entry.iconAnim then
            entry.iconAnim:Stop()
        end
        return
    end

    SetupIconAnimation(entry)
    entry.iconAnim:Stop()

    local hasSpin = (effect == "spinning" or effect == "both")
    local hasZoom = (effect == "zooming" or effect == "both")

    entry.iconSpin1:SetDegrees(hasSpin and -360 or 0)
    entry.iconSpin2:SetDegrees(hasSpin and -360 or 0)
    entry.iconScaleUp:SetScale(hasZoom and 1.5 or 1, hasZoom and 1.5 or 1)
    entry.iconScaleDown:SetScale(hasZoom and (1 / 1.5) or 1, hasZoom and (1 / 1.5) or 1)

    entry.iconAnim:Play()
end

-- ----------------------------------------------------------------------------
-- Backgrounds (lazy frames + animation groups)
-- ----------------------------------------------------------------------------

local function SetupBackground(entry)
    if entry.bgFrame then return end
    local bf = CreateFrame("Frame", nil, entry.frame)
    bf:SetPoint("CENTER", entry.frame, "CENTER", 0, 0)
    bf:SetFrameLevel(entry.frame:GetFrameLevel() - 1)
    bf:EnableMouse(false)

    local tex = bf:CreateTexture(nil, "ARTWORK")

    local ag = tex:CreateAnimationGroup()
    local spin1 = ag:CreateAnimation("Rotation")
    spin1:SetDuration(1.5)
    spin1:SetDegrees(-360)
    spin1:SetOrder(1)
    local scaleUp = ag:CreateAnimation("Scale")
    scaleUp:SetDuration(0.75)
    scaleUp:SetScale(1.8, 1.8)
    scaleUp:SetOrder(1)
    local spin2 = ag:CreateAnimation("Rotation")
    spin2:SetDuration(1.5)
    spin2:SetDegrees(-360)
    spin2:SetOrder(2)
    local scaleDown = ag:CreateAnimation("Scale")
    scaleDown:SetDuration(0.75)
    scaleDown:SetScale(1 / 1.8, 1 / 1.8)
    scaleDown:SetOrder(2)
    ag:SetLooping("REPEAT")

    local pulseAg = tex:CreateAnimationGroup()
    local fadeOut = pulseAg:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1.0)
    fadeOut:SetToAlpha(0.3)
    fadeOut:SetDuration(0.75)
    fadeOut:SetOrder(1)
    local fadeIn = pulseAg:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.3)
    fadeIn:SetToAlpha(1.0)
    fadeIn:SetDuration(0.75)
    fadeIn:SetOrder(2)
    pulseAg:SetLooping("REPEAT")

    entry.bgFrame = bf
    entry.bgTexture = tex
    entry.bgAnim = ag
    entry.bgPulseAnim = pulseAg
    entry.bgMask = nil
    entry.bgMaskApplied = false
    bf:Hide()
end

--- bgFrame is behind entry.frame; icon lives on iconFrame above bg.
local function SyncEntryLayerLevels(entry)
    local f = entry.frame
    if entry.bgFrame then
        entry.bgFrame:SetFrameLevel(f:GetFrameLevel() - 1)
    end
    if entry.iconFrame then
        entry.iconFrame:SetFrameLevel(f:GetFrameLevel() + 1)
    end
end

local function ApplyBackground(entry, bg, iconSize, itemLink)
    if not bg or not bg.enabled then
        if entry.bgFrame then
            entry.bgAnim:Stop()
            entry.bgPulseAnim:Stop()
            entry.bgFrame:Hide()
        end
        return
    end

    SetupBackground(entry)
    SyncEntryLayerLevels(entry)

    local style = bg.style or "Solid-Circle"
    local bgScale = bg.scale or 1.0
    local bgColor = bg.color or {1, 1, 1}

    if bg.useRarityColor and itemLink then
        local quality = select(3, C_Item.GetItemInfo(itemLink))
        if quality then
            local r, g, b = C_Item.GetItemQualityColor(quality)
            bgColor = {r, g, b}
        end
    end

    local baseSize = (iconSize or 20) * 1.6
    local finalSize = baseSize * bgScale

    entry.bgFrame:SetSize(finalSize, finalSize)
    entry.bgTexture:ClearAllPoints()
    entry.bgTexture:SetAllPoints(entry.bgFrame)
    entry.bgTexture:SetVertexColor(bgColor[1], bgColor[2], bgColor[3])

    local function ApplyCircleMask()
        if not entry.bgMask then
            local mask = entry.bgFrame:CreateMaskTexture()
            mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(entry.bgFrame)
            entry.bgMask = mask
        end
        if not entry.bgMaskApplied then
            entry.bgTexture:AddMaskTexture(entry.bgMask)
            entry.bgMaskApplied = true
        end
        entry.bgMask:Show()
    end

    local function RemoveCircleMask()
        if entry.bgMask and entry.bgMaskApplied then
            entry.bgTexture:RemoveMaskTexture(entry.bgMask)
            entry.bgMaskApplied = false
            entry.bgMask:Hide()
        end
    end

    if style == "Spinning Orbs" then
        RemoveCircleMask()
        entry.bgTexture:SetTexture(nil)
        entry.bgTexture:SetAtlas("ArtifactsFX-SpinningGlowys-Purple", false)
        entry.bgPulseAnim:Stop()
        entry.bgAnim:Play()
    elseif style == "Portal Spiral" then
        RemoveCircleMask()
        entry.bgTexture:SetTexture(nil)
        entry.bgTexture:SetAtlas("UI-Frame-jailerstower-Portrait-QualityEpic", false)
        entry.bgPulseAnim:Stop()
        entry.bgAnim:Play()
    elseif style == "Glow Pulse" then
        entry.bgAnim:Stop()
        entry.bgTexture:SetAtlas("")
        entry.bgTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        ApplyCircleMask()
        entry.bgPulseAnim:Play()
    elseif C_Texture.GetAtlasInfo(style) then
        RemoveCircleMask()
        entry.bgTexture:SetTexture(nil)
        entry.bgTexture:SetAtlas(style, false)
        entry.bgPulseAnim:Stop()
        if style:find("PowerSwirlAnimation", 1, true)
            or style:find("ArtifactsFX", 1, true) then
            entry.bgAnim:Play()
        else
            entry.bgAnim:Stop()
        end
    else
        entry.bgAnim:Stop()
        entry.bgPulseAnim:Stop()
        entry.bgTexture:SetAtlas("")
        entry.bgTexture:SetTexture("Interface\\Buttons\\WHITE8x8")

        if style == "Solid-Circle" then
            ApplyCircleMask()
        else
            RemoveCircleMask()
        end
    end

    entry.bgFrame:Show()
end

-- ----------------------------------------------------------------------------
-- Paint one icon overlay
-- ----------------------------------------------------------------------------

--- Paint one icon overlay into pool slot `index`.
--- paint = { iconSpec = {kind, value, tint}, position, scale, alpha, effect,
---           bg = {enabled, style, scale, color, useRarityColor}|nil }
function Renderer:ApplyOverlay(button, paint, index, itemLink)
    local container = GetOrCreateContainer(button)
    local entry = GetOrCreatePoolEntry(button, index)

    local position  = paint.position or "TOPRIGHT"
    local scale     = paint.scale or 1.0
    local alpha     = math_min(paint.alpha or 1.0, 1.0)
    local bw, bh    = GetButtonVisualSize(button)
    local baseSize  = math_min(bw or 37, bh or 37) * 0.54
    local finalSize = baseSize * scale

    entry.frame:ClearAllPoints()
    local outerData = OuterPositionData[position]
    if outerData then
        entry.frame:SetPoint("CENTER", container, outerData[1], outerData[2], outerData[3])
        entry.frame:SetFrameStrata("HIGH")
        entry.frame:SetFrameLevel(button:GetFrameLevel() + 10)
    else
        local offsets = PositionOffsets[position] or {0, 0}
        local sign = InnerAnchorSign[position] or InnerAnchorSign.CENTER
        local centerX = offsets[1] + sign[1] * (baseSize / 2)
        local centerY = offsets[2] + sign[2] * (baseSize / 2)
        entry.frame:SetPoint("CENTER", container, position, centerX, centerY)
        entry.frame:SetFrameStrata(container:GetFrameStrata())
        entry.frame:SetFrameLevel(button:GetFrameLevel() + 3)
    end
    entry.frame:SetSize(finalSize, finalSize)

    local visible = ns.OverlayIcons:ApplyIconSpec(entry.texture, paint.iconSpec)
    if visible then
        entry.texture:SetAlpha(alpha)
    end
    entry.frame:Show()
    entry.iconFrame:Show()

    ApplyIconEffect(entry, paint.effect)
    ApplyBackground(entry, paint.bg, finalSize, itemLink)
    SyncEntryLayerLevels(entry)
end

-- ----------------------------------------------------------------------------
-- Item level
-- ----------------------------------------------------------------------------

--- Paint the item level text. cfg is the overlays.itemlevel settings table;
--- text is the precomputed value (ilvl, pet level, or container slots);
--- quality drives colorMode = "quality".
function Renderer:ApplyItemLevel(button, cfg, text, quality)
    if not button.onewow_ilvl then
        local container = GetOrCreateContainer(button)
        button.onewow_ilvl = OneWoW_GUI:CreateFS(container, 10)
    end

    local fontPath = OneWoW_GUI:GetFont() or "Fonts\\FRIZQT__.TTF"
    local fontKey = OneWoW_GUI:MigrateLSMFontName(cfg.fontFamily) or cfg.fontFamily
    if fontKey then
        local path = OneWoW_GUI:GetFontByKey(fontKey)
        if path then
            fontPath = path
        end
    end
    OneWoW_GUI:SafeSetFont(button.onewow_ilvl, fontPath, cfg.fontSize or 10, cfg.fontOutline or "OUTLINE")

    local position  = cfg.position or "TOPRIGHT"
    local container = GetOrCreateContainer(button)
    button.onewow_ilvl:ClearAllPoints()
    local outerData = OuterPositionData[position]
    if outerData then
        button.onewow_ilvl:SetPoint("CENTER", container, outerData[1], outerData[2], outerData[3])
    else
        local offsets = PositionOffsets[position] or {0, 0}
        button.onewow_ilvl:SetPoint(position, container, position, offsets[1], offsets[2])
    end

    local colorMode = cfg.colorMode or "custom"
    if colorMode == "quality" then
        local r, g, b = C_Item.GetItemQualityColor(quality or 1)
        button.onewow_ilvl:SetTextColor(r, g, b)
    elseif colorMode == "theme" then
        button.onewow_ilvl:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    else
        local c = cfg.customColor or {1, 1, 1}
        button.onewow_ilvl:SetTextColor(c[1], c[2], c[3])
    end

    button.onewow_ilvl:SetText(tostring(text))
    button.onewow_ilvl:SetAlpha(1)
    button.onewow_ilvl:Show()
end

-- ----------------------------------------------------------------------------
-- Quality border
-- ----------------------------------------------------------------------------

--- Paint the Auction-House-style quality border over the button icon.
function Renderer:ApplyQualityBorder(button, cfg, quality)
    if not quality then
        if button.onewow_qualityBorderFrame then
            button.onewow_qualityBorderFrame:Hide()
        end
        return
    end

    local container = GetOrCreateContainer(button)
    local alpha = math_min(cfg.alpha or 1.0, 1.0)
    -- OneWoW clean border only. scale = edge thickness in pixels (1-6).
    local edge = math.max(1, math.floor((cfg.scale or 2) + 0.5))

    local f = button.onewow_qualityBorderFrame
    if not f then
        f = CreateFrame("Frame", nil, container, "BackdropTemplate")
        f:SetAllPoints(container)
        f:SetFrameLevel(container:GetFrameLevel() + 1)
        f:EnableMouse(false)
        button.onewow_qualityBorderFrame = f
    end
    f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = edge })
    local r, g, b = C_Item.GetItemQualityColor(quality)
    f:SetBackdropBorderColor(r, g, b, alpha)
    f:Show()
end
