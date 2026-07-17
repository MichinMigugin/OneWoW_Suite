local _, ns = ...

-- ============================================================================
-- Overlays 2.0 — renderer
-- ============================================================================
-- Pure painting layer: owns the per-button overlay container, the icon pool
-- (up to MAX_ICON_OVERLAYS entries), the item level FontString, and the
-- quality border frame (button chrome at FrameLevel + 1, under the container).
-- Knows nothing about settings storage or matching; the engine hands it
-- normalized paint configs.
--
-- Deliberately absent from 1.0's renderer: no reads of Blizzard's
-- ItemContextOverlay or button alpha (the source of the Warband Bank
-- darkening bug). Blizzard's dim layer is left entirely alone; surfaces
-- re-sync UpdateItemContextMatching after bank paint instead.
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
        -- Chrome (skin _skinBorder + Quality Border) sits at button + 1.
        -- Overlay content (ilvl, icon overlays) stays at button + 2 above chrome.
        c:SetFrameLevel(button:GetFrameLevel() + 2)
        c:Hide()
        -- Host addons (OneWoW_Bags) bulk-hide "dynamic" button children they
        -- don't recognize; this tag tells them the frame is renderer-owned and
        -- must only be hidden through Engine:CleanButton.
        c.onewow_overlayManaged = true
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
    c.onewow_overlayManaged = true
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
    c.onewow_overlayManaged = true
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

function Renderer:CleanButton(button, keepQualityBorder)
    if not button then return end

    -- Empty-slot repaint storms call Clean on every guild button. Skip when
    -- there is nothing painted (avoids 600+ no-op cleans per wave).
    if not keepQualityBorder
        and not button.onewow_itemLink
        and not button._owbQbQuality
        and (not button.onewow_qualityBorderFrame or not button.onewow_qualityBorderFrame:IsShown())
        and (not button.onewow_overlayContainer or not button.onewow_overlayContainer:IsShown())
        and (not button.onewow_ilvl or not button.onewow_ilvl:IsShown()) then
        local flashNote = OneWoW._overlayFlashNote
        if flashNote then
            flashNote("clean_skip")
        end
        return
    end

    local flashNote = OneWoW._overlayFlashNote
    if flashNote then
        flashNote("clean", { keep = keepQualityBorder and true or false })
    end
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
    -- Keep Quality Border visible across same-item repaints (guild bank layout
    -- storms / tooltip catchup). Hiding it here then re-showing causes flash.
    if not keepQualityBorder then
        if button.onewow_qualityBorderFrame then
            button.onewow_qualityBorderFrame:Hide()
        end
        button._owbQbQuality = nil
        button._owbQbEdge = nil
        button._owbQbAlpha = nil
        button.onewow_itemLink = nil
        button._owbOverlayPaintGen = nil
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

local ICON_ZOOM_SCALE = 1.5
local BG_ZOOM_SCALE = 1.8

local function ConfigureSpinZoomAnim(spin1, spin2, scaleUp, scaleDown, effect, zoomScale)
    local hasSpin = (effect == "spinning" or effect == "both")
    local hasZoom = (effect == "zooming" or effect == "both")
    spin1:SetDegrees(hasSpin and -360 or 0)
    spin2:SetDegrees(hasSpin and -360 or 0)
    scaleUp:SetScale(hasZoom and zoomScale or 1, hasZoom and zoomScale or 1)
    scaleDown:SetScale(hasZoom and (1 / zoomScale) or 1, hasZoom and (1 / zoomScale) or 1)
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
    ConfigureSpinZoomAnim(
        entry.iconSpin1, entry.iconSpin2, entry.iconScaleUp, entry.iconScaleDown,
        effect, ICON_ZOOM_SCALE)
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
    entry.bgSpin1 = spin1
    entry.bgSpin2 = spin2
    entry.bgScaleUp = scaleUp
    entry.bgScaleDown = scaleDown
    entry.bgPulseAnim = pulseAg
    entry.bgMask = nil
    entry.bgMaskApplied = false
    bf:Hide()
end

--- Style-driven spin/zoom backgrounds use the full spin + zoom cycle.
local function PlayBackgroundStyleSpinZoom(entry)
    ConfigureSpinZoomAnim(
        entry.bgSpin1, entry.bgSpin2, entry.bgScaleUp, entry.bgScaleDown,
        "both", BG_ZOOM_SCALE)
    entry.bgAnim:Play()
end

--- User-selected background effect; only runs when bg.effect is not "none".
local function ApplyBackgroundUserEffect(entry, effect)
    if not effect or effect == "none" then
        return false
    end

    entry.bgPulseAnim:Stop()
    entry.bgAnim:Stop()
    ConfigureSpinZoomAnim(
        entry.bgSpin1, entry.bgSpin2, entry.bgScaleUp, entry.bgScaleDown,
        effect, BG_ZOOM_SCALE)
    entry.bgAnim:Play()
    return true
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

local function ApplyBackground(entry, bg, referenceIconSize, itemLink)
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

    local baseSize = (referenceIconSize or 20) * 1.6
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

    local styleUsesPulse = false
    local styleUsesSpinZoom = false

    if style == "Spinning Orbs" then
        RemoveCircleMask()
        entry.bgTexture:SetTexture(nil)
        entry.bgTexture:SetAtlas("ArtifactsFX-SpinningGlowys-Purple", false)
        styleUsesSpinZoom = true
    elseif style == "Portal Spiral" then
        RemoveCircleMask()
        entry.bgTexture:SetTexture(nil)
        entry.bgTexture:SetAtlas("UI-Frame-jailerstower-Portrait-QualityEpic", false)
        styleUsesSpinZoom = true
    elseif style == "Glow Pulse" then
        entry.bgTexture:SetAtlas("")
        entry.bgTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        ApplyCircleMask()
        styleUsesPulse = true
    elseif C_Texture.GetAtlasInfo(style) then
        RemoveCircleMask()
        entry.bgTexture:SetTexture(nil)
        entry.bgTexture:SetAtlas(style, false)
        if style:find("PowerSwirlAnimation", 1, true)
            or style:find("ArtifactsFX", 1, true) then
            styleUsesSpinZoom = true
        end
    else
        entry.bgTexture:SetAtlas("")
        entry.bgTexture:SetTexture("Interface\\Buttons\\WHITE8x8")

        if style == "Solid-Circle" then
            ApplyCircleMask()
        else
            RemoveCircleMask()
        end
    end

    -- User bg.effect overrides style spin/zoom when set; "none" keeps the
    -- legacy style-driven look (Glow Pulse alpha, animated atlases, etc.).
    if not ApplyBackgroundUserEffect(entry, bg.effect) then
        entry.bgAnim:Stop()
        entry.bgPulseAnim:Stop()
        if styleUsesPulse then
            entry.bgPulseAnim:Play()
        elseif styleUsesSpinZoom then
            PlayBackgroundStyleSpinZoom(entry)
        end
    end

    entry.bgFrame:Show()
end

-- ----------------------------------------------------------------------------
-- Paint one icon overlay
-- ----------------------------------------------------------------------------

--- Paint one icon overlay into pool slot `index`.
--- paint = { iconSpec = {kind, value, tint}, position, scale, alpha, effect,
---           bg = {enabled, style, scale, color, useRarityColor, effect}|nil }
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
    ApplyBackground(entry, paint.bg, baseSize, itemLink)
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

--- Paint the quality border as button chrome (under ilvl / icon overlays).
--- Parent is the button at FrameLevel + 1 — same plane as OneWoW_GUI _skinBorder;
--- onewow_overlayContainer stays at +2 so content draws above.
function Renderer:ApplyQualityBorder(button, cfg, quality)
    local flashNote = OneWoW._overlayFlashNote
    if not quality then
        self:HideQualityBorder(button)
        return
    end

    -- OneWoW_Bags + Masque: Masque owns chrome; skip QB (covers async paint too).
    if button.owb_bagID and OneWoW_Bags_API and OneWoW_Bags_API.IsMasqueActive
        and OneWoW_Bags_API.IsMasqueActive() then
        self:HideQualityBorder(button)
        return
    end

    -- Ensure overlay container exists and stays above chrome even when only QB paints.
    GetOrCreateContainer(button)

    local alpha = math_min(cfg.alpha or 1.0, 1.0)
    -- OneWoW clean border only. scale = edge thickness in pixels (1-6).
    local edge = math.max(1, math.floor((cfg.scale or 2) + 0.5))

    local f = button.onewow_qualityBorderFrame
    -- SetBackdrop recreates edge textures and flashes even when values are
    -- unchanged (guild tooltip-catchup / layout re-paint). No-op when stable.
    if f and f:IsShown()
        and button._owbQbQuality == quality
        and button._owbQbEdge == edge
        and button._owbQbAlpha == alpha then
        f:SetFrameLevel(button:GetFrameLevel() + 1)
        if flashNote then flashNote("qb_noop") end
        return
    end

    local created = not f
    if not f then
        f = CreateFrame("Frame", nil, button, "BackdropTemplate")
        f:EnableMouse(false)
        f.onewow_overlayManaged = true
        button.onewow_qualityBorderFrame = f
    end
    if f:GetParent() ~= button then
        f:SetParent(button)
    end
    f:SetAllPoints(button)
    f:SetFrameLevel(button:GetFrameLevel() + 1)
    if button._owbQbEdge ~= edge then
        f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = edge })
    elseif not f:GetBackdrop() then
        f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = edge })
    end
    local r, g, b = OneWoW_GUI:GetItemQualityColor(quality)
    f:SetBackdropBorderColor(r, g, b, alpha)
    f:Show()
    button._owbQbQuality = quality
    button._owbQbEdge = edge
    button._owbQbAlpha = alpha
    if flashNote then
        flashNote(created and "qb_create" or "qb_update")
    end
end

--- Hide quality border only (Masque owns bag-button chrome when active).
function Renderer:HideQualityBorder(button)
    if not button then return end
    local flashNote = OneWoW._overlayFlashNote
    if flashNote and button.onewow_qualityBorderFrame and button.onewow_qualityBorderFrame:IsShown() then
        flashNote("qb_hide")
    end
    if button.onewow_qualityBorderFrame then
        button.onewow_qualityBorderFrame:Hide()
    end
    button._owbQbQuality = nil
    button._owbQbEdge = nil
    button._owbQbAlpha = nil
end
