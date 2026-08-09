local _, ns = ...
local MapMiniToolsModule, L = ns.ModuleRegistry:Current()
local M = MapMiniToolsModule

local OneWoW_GUI = OneWoW_GUI

-- ─── Constants ──────────────────────────────────────────────────────────────

local ROW_HEIGHT    = 28
local SLIDER_HEIGHT = 42
local INDENT_LABEL  = 24   -- indented label x for sub-settings
local INDENT_SLIDER = 36   -- indented slider x for sub-settings

local CLICK_OPTIONS = { "none", "calendar", "tracking", "missions", "map" }
local CLICK_LABEL_KEYS = {
    none     = "MMSKIN_ACTION_NONE",
    calendar = "MMSKIN_ACTION_CALENDAR",
    tracking = "MMSKIN_ACTION_TRACKING",
    missions = "MMSKIN_ACTION_MISSIONS",
    map      = "MMSKIN_ACTION_MAP",
}

-- Session-only collapse memory (survives tab switches; cleared on /reload)
local collapsedCards = {}

-- ─── Helpers ────────────────────────────────────────────────────────────────

local function AddLabelAt(parent, xOff, cy, text, color)
    local fs = OneWoW_GUI:CreateFS(parent, 12)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, cy)
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor(color or "TEXT_SECONDARY"))
    return fs, cy - fs:GetStringHeight() - 4
end

local function AddLabel(parent, cy, text, color)
    return AddLabelAt(parent, 12, cy, text, color)
end

local function AddLabelIndented(parent, cy, text, color)
    return AddLabelAt(parent, INDENT_LABEL, cy, text, color)
end

-- Long muted blurbs under controls (card content width may still be 0 at build).
local function AddWrappedDesc(parent, cy, text, contentWidth, xOff)
    xOff = xOff or 12
    local right = 12
    local fs = OneWoW_GUI:CreateFS(parent, 12)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, cy)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetSpacing(2)
    local w = tonumber(contentWidth) or 0
    if w < 1 then
        w = parent:GetWidth() or 0
    end
    if w >= 1 then
        fs:SetWidth(math.max(1, w - xOff - right))
    else
        fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -right, cy)
    end
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    return fs, cy - (fs:GetStringHeight() or 14) - 4
end

local function GetFontLabel(fontKey)
    if not fontKey or fontKey == "global" then
        return L["MMSKIN_FONT_GLOBAL"]
    end
    if fontKey == "wow_default" then
        return L["MMSKIN_FONT_WOW_DEFAULT"]
    end
    for _, f in ipairs(OneWoW_GUI:GetFontList()) do
        if f.key == fontKey then return f.label end
    end
    return fontKey
end

local function BuildFontItems()
    local items = {
        { value = "global",      text = L["MMSKIN_FONT_GLOBAL"] },
        { value = "wow_default", text = L["MMSKIN_FONT_WOW_DEFAULT"] },
    }
    for _, f in ipairs(OneWoW_GUI:GetFontList()) do
        table.insert(items, { value = f.key, text = f.label })
    end
    return items
end

local function BuildAlignItems()
    return {
        { value = "LEFT",   text = L["MMSKIN_ALIGN_LEFT"]   },
        { value = "CENTER", text = L["MMSKIN_ALIGN_CENTER"] },
        { value = "RIGHT",  text = L["MMSKIN_ALIGN_RIGHT"]  },
    }
end

local function GetAlignLabel(val)
    if val == "LEFT"  then return L["MMSKIN_ALIGN_LEFT"]  end
    if val == "RIGHT" then return L["MMSKIN_ALIGN_RIGHT"] end
    return L["MMSKIN_ALIGN_CENTER"]
end

-- When the module is disabled, every widget registered here is made
-- non-interactive so the user cannot toggle checkboxes / move sliders /
-- click buttons that would otherwise reach into engine code paths.
-- Checkboxes and buttons respond to :Disable(); the slider API returns a
-- wrapper Frame, so we walk children to find the OptionsSliderTemplate.
local function DisableWidget(w)
    if not w then return end
    if w.Disable then
        w:Disable()
        return
    end
    for _, child in ipairs({ w:GetChildren() }) do
        if child.Disable then child:Disable() end
    end
end

-- ─── Content Builder ────────────────────────────────────────────────────────

local function BuildContent(container, onRelayout)
    local s = M.GetSettings()
    local isEnabled = ns.ModuleRegistry:IsEnabled("map_mini_tools")
    local controls = {}

    local function track(w)
        controls[#controls + 1] = w
        return w
    end

    local stack = OneWoW_GUI:CreateCardStack(container, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })
    if onRelayout then
        stack.OnRelayout = onRelayout
    end

    -- Inline toggle checkbox. Calls SetToggleValue which triggers
    -- M:OnToggle → behavior + detail refresh.
    local function InlineCB(parent, cy, id, labelKey)
        local cb = OneWoW_GUI:CreateCheckbox(parent, {
            label   = L[labelKey],
            checked = ns.ModuleRegistry:GetToggleValue("map_mini_tools", id),
            onClick = function(self)
                ns.ModuleRegistry:SetToggleValue("map_mini_tools", id, self:GetChecked())
            end,
        })
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, cy)
        track(cb)
        return cb, cy - ROW_HEIGHT
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- 1. Scale & Opacity
    -- ═══════════════════════════════════════════════════════════════════════
    stack:AddCard("opacity", L["MMSKIN_SECTION_OPACITY"], function(content, _)
        local cy = 0

        local scaleLabel
        scaleLabel, cy = AddLabel(content, cy,
            string.format("%s: %.1f", L["MMSKIN_SCALE_LABEL"], s.scale))

        local scaleSlider = OneWoW_GUI:CreateSlider(content, {
            minVal = 0.5, maxVal = 2.0, step = 0.1,
            currentVal = s.scale, width = 260, fmt = "%.1f",
            onChange = function(val)
                s.scale = val
                scaleLabel:SetText(string.format("%s: %.1f", L["MMSKIN_SCALE_LABEL"], val))
                if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshScale then
                    M.RefreshScale()
                end
            end,
        })
        scaleSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 24, cy)
        track(scaleSlider)
        cy = cy - SLIDER_HEIGHT

        if s.minimapAlpha == nil then s.minimapAlpha = 1.0 end
        local opacityLabel
        opacityLabel, cy = AddLabel(content, cy,
            string.format("%s: %.0f%%", L["MMSKIN_OPACITY"], s.minimapAlpha * 100))

        local opacitySlider = OneWoW_GUI:CreateSlider(content, {
            minVal = 10, maxVal = 100, step = 5,
            currentVal = math.floor(s.minimapAlpha * 100),
            width = 260, fmt = "%d%%",
            onChange = function(val)
                s.minimapAlpha = val / 100
                opacityLabel:SetText(string.format("%s: %.0f%%", L["MMSKIN_OPACITY"], val))
                if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshAlpha then
                    M.RefreshAlpha()
                end
            end,
        })
        opacitySlider:SetPoint("TOPLEFT", content, "TOPLEFT", 24, cy)
        track(opacitySlider)
        cy = cy - SLIDER_HEIGHT

        return math.max(1, math.abs(cy))
    end)

    -- ═══════════════════════════════════════════════════════════════════════
    -- 2. Border Settings (only when showBorder + squareShape are both on)
    -- ═══════════════════════════════════════════════════════════════════════
    if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "showBorder")
        and ns.ModuleRegistry:GetToggleValue("map_mini_tools", "squareShape") then
        stack:AddCard("border", L["MMSKIN_SECTION_BORDER"], function(content, _)
            local cy = 0

            local bsLabel
            bsLabel, cy = AddLabel(content, cy,
                string.format("%s: %d", L["MMSKIN_BORDER_SIZE"], s.borderSize))

            local bsSlider = OneWoW_GUI:CreateSlider(content, {
                minVal = 1, maxVal = 15, step = 1,
                currentVal = s.borderSize, width = 260, fmt = "%d",
                onChange = function(val)
                    s.borderSize = val
                    bsLabel:SetText(string.format("%s: %d", L["MMSKIN_BORDER_SIZE"], val))
                    if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshBorder then
                        M.RefreshBorder()
                    end
                end,
            })
            bsSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 24, cy)
            track(bsSlider)
            cy = cy - SLIDER_HEIGHT

            local themeCB = OneWoW_GUI:CreateCheckbox(content, {
                label   = L["MMSKIN_USE_THEME_COLOR"],
                checked = s.useThemeColor,
                onClick = function(self)
                    s.useThemeColor = self:GetChecked()
                    if M.RefreshBorder then M.RefreshBorder() end
                    if M._refreshCustomDetail then M._refreshCustomDetail() end
                end,
            })
            themeCB:SetPoint("TOPLEFT", content, "TOPLEFT", 12, cy)
            track(themeCB)
            cy = cy - ROW_HEIGHT

            if not s.useThemeColor and not ns.ModuleRegistry:GetToggleValue("map_mini_tools", "classBorder") then
                if not s.borderColor then s.borderColor = { 0, 0, 0, 1 } end

                local colorSliders = {
                    { idx = 1, key = "MMSKIN_BORDER_RED"   },
                    { idx = 2, key = "MMSKIN_BORDER_GREEN" },
                    { idx = 3, key = "MMSKIN_BORDER_BLUE"  },
                }

                for _, cs in ipairs(colorSliders) do
                    local csLabel
                    local labelText = L[cs.key]
                    csLabel, cy = AddLabel(content, cy,
                        string.format("%s: %d", labelText, math.floor((s.borderColor[cs.idx] or 0) * 255)))

                    local cSlider = OneWoW_GUI:CreateSlider(content, {
                        minVal = 0, maxVal = 255, step = 1,
                        currentVal = math.floor((s.borderColor[cs.idx] or 0) * 255),
                        width = 260, fmt = "%d",
                        onChange = function(val)
                            s.borderColor[cs.idx] = val / 255
                            csLabel:SetText(string.format("%s: %d", labelText, val))
                            if M.RefreshBorder then M.RefreshBorder() end
                        end,
                    })
                    cSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 24, cy)
                    track(cSlider)
                    cy = cy - SLIDER_HEIGHT
                end
            end

            return math.max(1, math.abs(cy))
        end)
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- 3. Information Overlays — Zone Text & Clock, each with inline toggle
    -- ═══════════════════════════════════════════════════════════════════════
    stack:AddCard("info", L["MMSKIN_GROUP_INFO"], function(content, _)
        local cy = 0

        local zoneClockInsideCB
        zoneClockInsideCB, cy = InlineCB(content, cy, "zoneClockInside", "MMSKIN_ZONE_CLOCK_INSIDE")
        local zoneClockDragCB
        zoneClockDragCB, cy = InlineCB(content, cy, "zoneClockDraggable", "MMSKIN_ZONE_CLOCK_DRAG")

        -- Indented sub-toggle: only meaningful when draggable is on.
        local anchorMmCB = OneWoW_GUI:CreateCheckbox(content, {
            label   = L["MMSKIN_ZONE_CLOCK_ANCHOR_MM"],
            checked = ns.ModuleRegistry:GetToggleValue("map_mini_tools", "zoneClockAnchorMinimap"),
            onClick = function(self)
                ns.ModuleRegistry:SetToggleValue("map_mini_tools", "zoneClockAnchorMinimap", self:GetChecked())
            end,
        })
        anchorMmCB:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_LABEL, cy)
        track(anchorMmCB)
        cy = cy - ROW_HEIGHT

        -- These three controls only affect the zone/clock frames. If neither text
        -- is shown, they have nothing to act on, so disable them until the user
        -- enables at least one of the text toggles below.
        local zoneOrClockOn = ns.ModuleRegistry:GetToggleValue("map_mini_tools", "showZoneText")
            or ns.ModuleRegistry:GetToggleValue("map_mini_tools", "showClock")
        if not zoneOrClockOn then
            DisableWidget(zoneClockInsideCB)
            DisableWidget(zoneClockDragCB)
            DisableWidget(anchorMmCB)
        end

        -- Anchor-to-minimap only takes effect while draggable is on.
        if not ns.ModuleRegistry:GetToggleValue("map_mini_tools", "zoneClockDraggable") then
            DisableWidget(anchorMmCB)
        end

        -- Coalesce rapid bursts (Blizzard's color picker fires its swatchFunc /
        -- opacityFunc continuously while the user drags) into one refresh per
        -- ~50ms window so we never push more than ~20 redraws per second.
        local function Debounce(fn, delay)
            local pending = false
            return function()
                if pending then return end
                pending = true
                C_Timer.After(delay or 0.05, function()
                    pending = false
                    if fn then fn() end
                end)
            end
        end

        -- Background block: enable checkbox + RGBA color swatch on one row.
        -- enableKey/colorKey live on s (the saved settings table); refreshFn is
        -- the engine's immediate refresh — wrapped here in a debounce because
        -- the color picker fires its callbacks continuously while dragging.
        local function BuildBackgroundBlock(enableKey, colorKey, labelKey, refreshFn)
            local debouncedRefresh = Debounce(refreshFn, 0.05)
            local function applyAndRefresh()
                if refreshFn and ns.ModuleRegistry:IsEnabled("map_mini_tools") then
                    debouncedRefresh()
                end
            end

            local bgCB = OneWoW_GUI:CreateCheckbox(content, {
                label   = L[labelKey],
                checked = s[enableKey],
                onClick = function(self)
                    s[enableKey] = self:GetChecked()
                    applyAndRefresh()
                end,
            })
            bgCB:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_LABEL, cy)
            track(bgCB)

            local swatch = OneWoW_GUI:CreateColorSwatch(content, {
                size       = 22,
                hasOpacity = true,
                getColor   = function()
                    local c = s[colorKey]
                    return c[1] or 0, c[2] or 0, c[3] or 0
                end,
                onColorChanged = function(r, g, b)
                    local c = s[colorKey]
                    c[1], c[2], c[3] = r, g, b
                    applyAndRefresh()
                end,
                getOpacity = function()
                    return s[colorKey][4] or 1
                end,
                onOpacityChanged = function(a)
                    s[colorKey][4] = a
                    applyAndRefresh()
                end,
            })
            swatch:SetPoint("LEFT", bgCB, "RIGHT", 200, 0)
            track(swatch)

            cy = cy - ROW_HEIGHT
        end

        -- Zone Text toggle + sub-settings
        _, cy = InlineCB(content, cy, "showZoneText", "MMSKIN_ZONE_TEXT")
        if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "showZoneText") then
            _, cy = AddLabelIndented(content, cy, L["MMSKIN_ZONE_FONT_LABEL"])

            local zoneFontDrop, zoneFontText = OneWoW_GUI:CreateDropdown(content, {
                width = 200, height = 22,
                text = GetFontLabel(s.zoneFont),
            })
            zoneFontDrop:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
            track(zoneFontDrop)
            cy = cy - ROW_HEIGHT

            OneWoW_GUI:AttachFilterMenu(zoneFontDrop, {
                searchable = true, menuHeight = 320,
                getActiveValue = function() return s.zoneFont end,
                buildItems = BuildFontItems,
                onSelect = function(value, text)
                    s.zoneFont = value
                    zoneFontText:SetText(text)
                    if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshZoneFont then
                        M.RefreshZoneFont()
                    end
                end,
            })

            local zfSizeLabel
            zfSizeLabel, cy = AddLabelIndented(content, cy,
                string.format("%s: %d", FONT_SIZE, s.zoneFontSize))

            local zfSizeSlider = OneWoW_GUI:CreateSlider(content, {
                minVal = 8, maxVal = 24, step = 1,
                currentVal = s.zoneFontSize, width = 240, fmt = "%d",
                onChange = function(val)
                    s.zoneFontSize = val
                    zfSizeLabel:SetText(string.format("%s: %d", FONT_SIZE, val))
                    if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshZoneFont then
                        M.RefreshZoneFont()
                    end
                end,
            })
            zfSizeSlider:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
            track(zfSizeSlider)
            cy = cy - SLIDER_HEIGHT

            local _, zaCy = AddLabelIndented(content, cy, L["MMSKIN_ZONE_ALIGN_LABEL"])
            cy = zaCy

            local zoneAlignDrop, zoneAlignText = OneWoW_GUI:CreateDropdown(content, {
                width = 200, height = 22,
                text = GetAlignLabel(s.zoneAlign),
            })
            zoneAlignDrop:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
            track(zoneAlignDrop)
            cy = cy - ROW_HEIGHT

            OneWoW_GUI:AttachFilterMenu(zoneAlignDrop, {
                searchable = false,
                getActiveValue = function() return s.zoneAlign or "CENTER" end,
                buildItems = BuildAlignItems,
                onSelect = function(value, text)
                    s.zoneAlign = value
                    zoneAlignText:SetText(text)
                    if ns.ModuleRegistry:IsEnabled("map_mini_tools") then
                        if M.RefreshZoneFont       then M.RefreshZoneFont()       end
                        if M.RefreshZoneLayout     then M.RefreshZoneLayout()     end
                        if M.RefreshZoneBackground then M.RefreshZoneBackground() end
                    end
                end,
            })
            cy = cy - 4

            BuildBackgroundBlock("zoneBg", "zoneBgColor", "MMSKIN_ZONE_BG", M.RefreshZoneBackground)
        end

        -- Clock toggle + sub-settings
        _, cy = InlineCB(content, cy, "showClock", "MMSKIN_CLOCK")
        if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "showClock") then
            _, cy = AddLabelIndented(content, cy, L["MMSKIN_CLOCK_FONT_LABEL"])

            local clockFontDrop, clockFontText = OneWoW_GUI:CreateDropdown(content, {
                width = 200, height = 22,
                text = GetFontLabel(s.clockFont),
            })
            clockFontDrop:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
            track(clockFontDrop)
            cy = cy - ROW_HEIGHT

            OneWoW_GUI:AttachFilterMenu(clockFontDrop, {
                searchable = true, menuHeight = 320,
                getActiveValue = function() return s.clockFont end,
                buildItems = BuildFontItems,
                onSelect = function(value, text)
                    s.clockFont = value
                    clockFontText:SetText(text)
                    if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshClockFont then
                        M.RefreshClockFont()
                    end
                end,
            })

            local cfSizeLabel
            cfSizeLabel, cy = AddLabelIndented(content, cy,
                string.format("%s: %d", FONT_SIZE, s.clockFontSize))

            local cfSizeSlider = OneWoW_GUI:CreateSlider(content, {
                minVal = 8, maxVal = 24, step = 1,
                currentVal = s.clockFontSize, width = 240, fmt = "%d",
                onChange = function(val)
                    s.clockFontSize = val
                    cfSizeLabel:SetText(string.format("%s: %d", FONT_SIZE, val))
                    if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshClockFont then
                        M.RefreshClockFont()
                    end
                end,
            })
            cfSizeSlider:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
            track(cfSizeSlider)
            cy = cy - SLIDER_HEIGHT

            local classClockCB = OneWoW_GUI:CreateCheckbox(content, {
                label   = L["MMSKIN_CLASS_CLOCK_COLOR"],
                checked = ns.ModuleRegistry:GetToggleValue("map_mini_tools", "classClockColor"),
                onClick = function(self)
                    ns.ModuleRegistry:SetToggleValue("map_mini_tools", "classClockColor", self:GetChecked())
                end,
            })
            classClockCB:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_LABEL, cy)
            track(classClockCB)
            cy = cy - ROW_HEIGHT

            local _, caCy = AddLabelIndented(content, cy, L["MMSKIN_CLOCK_ALIGN_LABEL"])
            cy = caCy

            local clockAlignDrop, clockAlignText = OneWoW_GUI:CreateDropdown(content, {
                width = 200, height = 22,
                text = GetAlignLabel(s.clockAlign),
            })
            clockAlignDrop:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
            track(clockAlignDrop)
            cy = cy - ROW_HEIGHT

            OneWoW_GUI:AttachFilterMenu(clockAlignDrop, {
                searchable = false,
                getActiveValue = function() return s.clockAlign or "CENTER" end,
                buildItems = BuildAlignItems,
                onSelect = function(value, text)
                    s.clockAlign = value
                    clockAlignText:SetText(text)
                    if ns.ModuleRegistry:IsEnabled("map_mini_tools") then
                        if M.RefreshClockFont       then M.RefreshClockFont()       end
                        if M.RefreshClockLayout     then M.RefreshClockLayout()     end
                        if M.RefreshClockBackground then M.RefreshClockBackground() end
                    end
                end,
            })
            cy = cy - 4

            BuildBackgroundBlock("clockBg", "clockBgColor", "MMSKIN_CLOCK_BG", M.RefreshClockBackground)
        end

        return math.max(1, math.abs(cy))
    end)

    -- ═══════════════════════════════════════════════════════════════════════
    -- 4. Zoom & Scroll — Auto Zoom (inline toggle + delay), plus map controls
    -- ═══════════════════════════════════════════════════════════════════════
    stack:AddCard("zoom", L["MMSKIN_GROUP_ZOOM"], function(content, _)
        local cy = 0

        -- Auto Zoom Out toggle + delay sub-setting
        _, cy = InlineCB(content, cy, "autoZoomOut", "MMSKIN_AUTO_ZOOM")
        if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "autoZoomOut") then
            local azLabel
            azLabel, cy = AddLabelIndented(content, cy,
                string.format("%s: %ds", L["MMSKIN_AUTO_ZOOM_DELAY"], s.autoZoomDelay))

            local azSlider = OneWoW_GUI:CreateSlider(content, {
                minVal = 3, maxVal = 30, step = 1,
                currentVal = s.autoZoomDelay, width = 240, fmt = "%d",
                onChange = function(val)
                    s.autoZoomDelay = val
                    azLabel:SetText(string.format("%s: %ds", L["MMSKIN_AUTO_ZOOM_DELAY"], val))
                end,
            })
            azSlider:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
            track(azSlider)
            cy = cy - SLIDER_HEIGHT
            cy = cy - 4
        end

        -- Additional map control checkboxes
        local zbCB = OneWoW_GUI:CreateCheckbox(content, {
            label   = L["MMSKIN_SHOW_ZOOM_BTNS"],
            checked = s.showZoomBtns,
            onClick = function(self)
                s.showZoomBtns = self:GetChecked()
                if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshElements then
                    M.RefreshElements()
                end
            end,
        })
        zbCB:SetPoint("TOPLEFT", content, "TOPLEFT", 12, cy)
        track(zbCB)
        cy = cy - ROW_HEIGHT

        local compCB = OneWoW_GUI:CreateCheckbox(content, {
            label   = L["MMSKIN_SHOW_COMPARTMENT"],
            checked = s.showCompartment,
            onClick = function(self)
                s.showCompartment = self:GetChecked()
                if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshElements then
                    M.RefreshElements()
                end
            end,
        })
        compCB:SetPoint("TOPLEFT", content, "TOPLEFT", 12, cy)
        track(compCB)
        cy = cy - ROW_HEIGHT

        local unclampCB = OneWoW_GUI:CreateCheckbox(content, {
            label   = L["MMSKIN_UNCLAMP"],
            checked = s.unclampMinimap,
            onClick = function(self)
                s.unclampMinimap = self:GetChecked()
                if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshUnclamp then
                    M.RefreshUnclamp()
                end
            end,
        })
        unclampCB:SetPoint("TOPLEFT", content, "TOPLEFT", 12, cy)
        track(unclampCB)
        cy = cy - ROW_HEIGHT

        _, cy = InlineCB(content, cy, "hideWorldMapButton", "MMSKIN_HIDE_WM_BTN")

        return math.max(1, math.abs(cy))
    end)

    -- ═══════════════════════════════════════════════════════════════════════
    -- 5. Combat Fade — inline toggle + opacity sub-setting
    -- ═══════════════════════════════════════════════════════════════════════
    stack:AddCard("combat", L["MMSKIN_SECTION_COMBAT"], function(content, _)
        local cy = 0

        _, cy = InlineCB(content, cy, "combatFade", "MMSKIN_COMBAT_FADE")
        if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "combatFade") then
            local fadeCfLabel
            fadeCfLabel, cy = AddLabelIndented(content, cy,
                string.format("%s: %.0f%%", L["MMSKIN_COMBAT_ALPHA"], s.combatFadeAlpha * 100))

            local fadeCfSlider = OneWoW_GUI:CreateSlider(content, {
                minVal = 10, maxVal = 90, step = 5,
                currentVal = math.floor(s.combatFadeAlpha * 100),
                width = 240, fmt = "%d%%",
                onChange = function(val)
                    s.combatFadeAlpha = val / 100
                    fadeCfLabel:SetText(string.format("%s: %.0f%%", L["MMSKIN_COMBAT_ALPHA"], val))
                end,
            })
            fadeCfSlider:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
            track(fadeCfSlider)
            cy = cy - SLIDER_HEIGHT
        end

        return math.max(1, math.abs(cy))
    end)

    -- ═══════════════════════════════════════════════════════════════════════
    -- 6. Click Actions — inline toggle + per-button binding rows
    -- ═══════════════════════════════════════════════════════════════════════
    stack:AddCard("clicks", L["MMSKIN_SECTION_CLICKS"], function(content, _)
        local cy = 0

        _, cy = InlineCB(content, cy, "clickActions", "MMSKIN_CLICK_ACTIONS")
        if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "clickActions") then
            local bindings = {
                { key = "clickRight",  label = L["MMSKIN_CLICK_RIGHT"]  },
                { key = "clickMiddle", label = L["MMSKIN_CLICK_MIDDLE"] },
                { key = "clickBtn4",   label = L["MMSKIN_CLICK_BTN4"]   },
                { key = "clickBtn5",   label = L["MMSKIN_CLICK_BTN5"]   },
            }

            local function ClickActionLabel(opt)
                return L[CLICK_LABEL_KEYS[opt]] or tostring(opt)
            end

            local clickMenuItems
            local function BuildClickActionItems()
                if clickMenuItems then return clickMenuItems end
                clickMenuItems = {}
                for _, opt in ipairs(CLICK_OPTIONS) do
                    tinsert(clickMenuItems, { value = opt, text = ClickActionLabel(opt) })
                end
                return clickMenuItems
            end

            for _, bind in ipairs(bindings) do
                local capturedKey = bind.key
                local cur = s[capturedKey] or "none"

                local bindLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                bindLabel:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_LABEL, cy)
                bindLabel:SetText(bind.label .. ":")
                bindLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

                local drop, dropText = OneWoW_GUI:CreateDropdown(content, {
                    width = 140,
                    height = 26,
                    text = ClickActionLabel(cur),
                })
                drop:SetPoint("LEFT", bindLabel, "RIGHT", 8, 0)
                drop._activeValue = cur
                track(drop)

                OneWoW_GUI:AttachFilterMenu(drop, {
                    searchable = false,
                    menuHeight = 160,
                    buildItems = BuildClickActionItems,
                    getActiveValue = function()
                        return s[capturedKey] or "none"
                    end,
                    onSelect = function(value, text)
                        s[capturedKey] = value
                        drop._activeValue = value
                        dropText:SetText(text)
                    end,
                })
                cy = cy - 32
            end
        end

        return math.max(1, math.abs(cy))
    end)

    -- ═══════════════════════════════════════════════════════════════════════
    -- 7. Compatibility — Plumber / expansion minimap duplicate
    -- ═══════════════════════════════════════════════════════════════════════
    stack:AddCard("compat", L["MMSKIN_GROUP_COMPAT"], function(content, _)
        local cy = 0

        _, cy = InlineCB(content, cy, "hideBlizzardExpansionWhenPlumber", "MMSKIN_PLUMBER_HIDE_BLIZZARD")

        local plumberStatus = (M.IsPlumberLoaded and M.IsPlumberLoaded())
            and L["MMSKIN_PLUMBER_STATUS_ON"]
            or  L["MMSKIN_PLUMBER_STATUS_OFF"]
        local _, statusCy = AddLabelIndented(content, cy, plumberStatus, "TEXT_MUTED")
        cy = statusCy

        return math.max(1, math.abs(cy))
    end)

    -- ═══════════════════════════════════════════════════════════════════════
    -- 8. Developer Tools — debug icon overlay button
    -- ═══════════════════════════════════════════════════════════════════════
    stack:AddCard("debug", L["MMSKIN_SECTION_DEBUG"], function(content, contentWidth)
        local cy = 0

        local debugBtnLabel = M._debugActive
            and L["MMSKIN_DEBUG_HIDE"]
            or  L["MMSKIN_DEBUG_SHOW"]

        local debugBtn = OneWoW_GUI:CreateFitTextButton(content, { text = debugBtnLabel, height = 24 })
        debugBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 12, cy)
        debugBtn:SetScript("OnClick", function()
            if M.DebugIconsToggle then
                M.DebugIconsToggle()
                if M._refreshCustomDetail then M._refreshCustomDetail() end
            end
        end)
        track(debugBtn)
        cy = cy - 32

        local _, descCy = AddWrappedDesc(content, cy, L["MMSKIN_DEBUG_DESC"], contentWidth)
        cy = descCy

        return math.max(1, math.abs(cy))
    end)

    stack:Finish()

    if not isEnabled then
        for _, w in ipairs(controls) do DisableWidget(w) end
    end

    -- Features may host this on belowHost (yOffset=0); always report stack height.
    return -container:GetHeight()
end

-- ─── CreateCustomDetail ─────────────────────────────────────────────────────

function M:CreateCustomDetail(detailScrollChild, yOffset, _, registerRefresh)
    if detailScrollChild._mmskinContainer then
        OneWoW_GUI:ClearFrame(detailScrollChild._mmskinContainer)
    end

    local container = detailScrollChild._mmskinContainer or CreateFrame("Frame", nil, detailScrollChild)
    detailScrollChild._mmskinContainer = container
    container:SetParent(detailScrollChild)
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT",  detailScrollChild, "TOPLEFT",  0, yOffset)
    container:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)
    container:Show()

    local capturedYOffset = yOffset

    -- Host may be Features belowHost (not the scroll child). Size the host from
    -- the card stack container; Features registerRefresh remasures the scroll.
    local function applyHostHeight(cy)
        cy = cy or -container:GetHeight()
        detailScrollChild:SetHeight(math.abs(capturedYOffset) + math.abs(cy) + 20)
        if detailScrollChild.updateThumb then
            detailScrollChild.updateThumb()
        end
    end

    self._refreshCustomDetail = function()
        OneWoW_GUI:ClearFrame(container)
        local cy = BuildContent(container, applyHostHeight)
        applyHostHeight(cy)
    end

    -- Flipping the module's master toggle re-queries IsEnabled on the next
    -- build, so tracked controls pick up the new enabled/disabled state.
    if registerRefresh then
        registerRefresh(function()
            if self._refreshCustomDetail then
                self._refreshCustomDetail()
            end
        end)
    end

    local cy = BuildContent(container, applyHostHeight)

    return yOffset + cy
end
