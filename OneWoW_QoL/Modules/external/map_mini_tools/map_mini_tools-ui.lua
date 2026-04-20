local addonName, ns = ...
local M = ns.MapMiniToolsModule

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

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

local function GetFontLabel(fontKey)
    local L = ns.L
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
    local L = ns.L
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
    local L = ns.L
    return {
        { value = "LEFT",   text = L["MMSKIN_ALIGN_LEFT"]   },
        { value = "CENTER", text = L["MMSKIN_ALIGN_CENTER"] },
        { value = "RIGHT",  text = L["MMSKIN_ALIGN_RIGHT"]  },
    }
end

local function GetAlignLabel(val)
    local L = ns.L
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

local function BuildContent(container)
    local L = ns.L
    local s = M.GetSettings()
    local cy = 0
    local isEnabled = ns.ModuleRegistry:IsEnabled("map_mini_tools")
    local controls = {}

    local function track(w)
        controls[#controls + 1] = w
        return w
    end

    -- Inline toggle checkbox — modifies cy via Lua upvalue closure.
    -- Calls SetToggleValue which triggers M:OnToggle → behavior + detail refresh.
    local function InlineCB(id, labelKey)
        local cb = OneWoW_GUI:CreateCheckbox(container, {
            label   = L[labelKey],
            checked = ns.ModuleRegistry:GetToggleValue("map_mini_tools", id),
            onClick = function(self)
                ns.ModuleRegistry:SetToggleValue("map_mini_tools", id, self:GetChecked())
            end,
        })
        cb:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
        cy = cy - ROW_HEIGHT
        track(cb)
        return cb
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- 1. Scale & Opacity (always visible)
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_OPACITY"], yOffset = cy })

    local scaleLabel
    scaleLabel, cy = AddLabel(container, cy,
        string.format("%s: %.1f", L["MMSKIN_SCALE_LABEL"], s.scale))

    local scaleSlider = OneWoW_GUI:CreateSlider(container, {
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
    scaleSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    track(scaleSlider)
    cy = cy - SLIDER_HEIGHT

    if s.minimapAlpha == nil then s.minimapAlpha = 1.0 end
    local opacityLabel
    opacityLabel, cy = AddLabel(container, cy,
        string.format("%s: %.0f%%", L["MMSKIN_OPACITY"], s.minimapAlpha * 100))

    local opacitySlider = OneWoW_GUI:CreateSlider(container, {
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
    opacitySlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    track(opacitySlider)
    cy = cy - SLIDER_HEIGHT

    -- ═══════════════════════════════════════════════════════════════════════
    -- 2. Border Settings (only when showBorder + squareShape are both on)
    -- ═══════════════════════════════════════════════════════════════════════
    if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "showBorder") and ns.ModuleRegistry:GetToggleValue("map_mini_tools", "squareShape") then
        cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_BORDER"], yOffset = cy })

        local bsLabel
        bsLabel, cy = AddLabel(container, cy,
            string.format("%s: %d", L["MMSKIN_BORDER_SIZE"], s.borderSize))

        local bsSlider = OneWoW_GUI:CreateSlider(container, {
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
        bsSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
        track(bsSlider)
        cy = cy - SLIDER_HEIGHT

        local themeCB = OneWoW_GUI:CreateCheckbox(container, {
            label   = L["MMSKIN_USE_THEME_COLOR"],
            checked = s.useThemeColor,
            onClick = function(self)
                s.useThemeColor = self:GetChecked()
                if M.RefreshBorder then M.RefreshBorder() end
                if M._refreshCustomDetail then M._refreshCustomDetail() end
            end,
        })
        themeCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
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
                csLabel, cy = AddLabel(container, cy,
                    string.format("%s: %d", labelText, math.floor((s.borderColor[cs.idx] or 0) * 255)))

                local cSlider = OneWoW_GUI:CreateSlider(container, {
                    minVal = 0, maxVal = 255, step = 1,
                    currentVal = math.floor((s.borderColor[cs.idx] or 0) * 255),
                    width = 260, fmt = "%d",
                    onChange = function(val)
                        s.borderColor[cs.idx] = val / 255
                        csLabel:SetText(string.format("%s: %d", labelText, val))
                        if M.RefreshBorder then M.RefreshBorder() end
                    end,
                })
                cSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
                track(cSlider)
                cy = cy - SLIDER_HEIGHT
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- 3. Information Overlays — Zone Text & Clock, each with inline toggle
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_GROUP_INFO"], yOffset = cy })

    local zoneClockInsideCB = InlineCB("zoneClockInside", "MMSKIN_ZONE_CLOCK_INSIDE")
    local zoneClockDragCB   = InlineCB("zoneClockDraggable", "MMSKIN_ZONE_CLOCK_DRAG")

    -- These two controls only affect the zone/clock frames. If neither text is
    -- shown, they have nothing to act on, so disable them until the user enables
    -- at least one of the text toggles below.
    local zoneOrClockOn = ns.ModuleRegistry:GetToggleValue("map_mini_tools", "showZoneText")
        or ns.ModuleRegistry:GetToggleValue("map_mini_tools", "showClock")
    if not zoneOrClockOn then
        DisableWidget(zoneClockInsideCB)
        DisableWidget(zoneClockDragCB)
    end

    -- Zone Text toggle + sub-settings
    InlineCB("showZoneText", "MMSKIN_ZONE_TEXT")
    if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "showZoneText") then
        local zoneFontLabel
        zoneFontLabel, cy = AddLabelIndented(container, cy, L["MMSKIN_ZONE_FONT_LABEL"])

        local zoneFontDrop, zoneFontText = OneWoW_GUI:CreateDropdown(container, {
            width = 200, height = 22,
            text = GetFontLabel(s.zoneFont),
        })
        zoneFontDrop:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
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
        zfSizeLabel, cy = AddLabelIndented(container, cy,
            string.format("%s: %d", L["MMSKIN_ZONE_FONT_SIZE"], s.zoneFontSize))

        local zfSizeSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 8, maxVal = 24, step = 1,
            currentVal = s.zoneFontSize, width = 240, fmt = "%d",
            onChange = function(val)
                s.zoneFontSize = val
                zfSizeLabel:SetText(string.format("%s: %d", L["MMSKIN_ZONE_FONT_SIZE"], val))
                if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshZoneFont then
                    M.RefreshZoneFont()
                end
            end,
        })
        zfSizeSlider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        track(zfSizeSlider)
        cy = cy - SLIDER_HEIGHT

        local _, zaCy = AddLabelIndented(container, cy, L["MMSKIN_ZONE_ALIGN_LABEL"])
        cy = zaCy

        local zoneAlignDrop, zoneAlignText = OneWoW_GUI:CreateDropdown(container, {
            width = 200, height = 22,
            text = GetAlignLabel(s.zoneAlign),
        })
        zoneAlignDrop:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
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
                    if M.RefreshZoneFont   then M.RefreshZoneFont()   end
                    if M.RefreshZoneLayout then M.RefreshZoneLayout() end
                end
            end,
        })
        cy = cy - 4
    end

    -- Clock toggle + sub-settings
    InlineCB("showClock", "MMSKIN_CLOCK")
    if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "showClock") then
        local clockFontLabel
        clockFontLabel, cy = AddLabelIndented(container, cy, L["MMSKIN_CLOCK_FONT_LABEL"])

        local clockFontDrop, clockFontText = OneWoW_GUI:CreateDropdown(container, {
            width = 200, height = 22,
            text = GetFontLabel(s.clockFont),
        })
        clockFontDrop:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
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
        cfSizeLabel, cy = AddLabelIndented(container, cy,
            string.format("%s: %d", L["MMSKIN_CLOCK_FONT_SIZE"], s.clockFontSize))

        local cfSizeSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 8, maxVal = 24, step = 1,
            currentVal = s.clockFontSize, width = 240, fmt = "%d",
            onChange = function(val)
                s.clockFontSize = val
                cfSizeLabel:SetText(string.format("%s: %d", L["MMSKIN_CLOCK_FONT_SIZE"], val))
                if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshClockFont then
                    M.RefreshClockFont()
                end
            end,
        })
        cfSizeSlider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        track(cfSizeSlider)
        cy = cy - SLIDER_HEIGHT

        local classClockCB = OneWoW_GUI:CreateCheckbox(container, {
            label   = L["MMSKIN_CLASS_CLOCK_COLOR"],
            checked = ns.ModuleRegistry:GetToggleValue("map_mini_tools", "classClockColor"),
            onClick = function(self)
                ns.ModuleRegistry:SetToggleValue("map_mini_tools", "classClockColor", self:GetChecked())
            end,
        })
        classClockCB:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_LABEL, cy)
        track(classClockCB)
        cy = cy - ROW_HEIGHT

        local _, caCy = AddLabelIndented(container, cy, L["MMSKIN_CLOCK_ALIGN_LABEL"])
        cy = caCy

        local clockAlignDrop, clockAlignText = OneWoW_GUI:CreateDropdown(container, {
            width = 200, height = 22,
            text = GetAlignLabel(s.clockAlign),
        })
        clockAlignDrop:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
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
                    if M.RefreshClockFont   then M.RefreshClockFont()   end
                    if M.RefreshClockLayout then M.RefreshClockLayout() end
                end
            end,
        })
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- 4. Zoom & Scroll — Auto Zoom (inline toggle + delay), plus map controls
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_GROUP_ZOOM"], yOffset = cy })

    -- Auto Zoom Out toggle + delay sub-setting
    InlineCB("autoZoomOut", "MMSKIN_AUTO_ZOOM")
    if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "autoZoomOut") then
        local azLabel
        azLabel, cy = AddLabelIndented(container, cy,
            string.format("%s: %ds", L["MMSKIN_AUTO_ZOOM_DELAY"], s.autoZoomDelay))

        local azSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 3, maxVal = 30, step = 1,
            currentVal = s.autoZoomDelay, width = 240, fmt = "%d",
            onChange = function(val)
                s.autoZoomDelay = val
                azLabel:SetText(string.format("%s: %ds", L["MMSKIN_AUTO_ZOOM_DELAY"], val))
            end,
        })
        azSlider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        track(azSlider)
        cy = cy - SLIDER_HEIGHT
        cy = cy - 4
    end

    -- Additional map control checkboxes
    local zbCB = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMSKIN_SHOW_ZOOM_BTNS"],
        checked = s.showZoomBtns,
        onClick = function(self)
            s.showZoomBtns = self:GetChecked()
            if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshElements then
                M.RefreshElements()
            end
        end,
    })
    zbCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    track(zbCB)
    cy = cy - ROW_HEIGHT

    local compCB = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMSKIN_SHOW_COMPARTMENT"],
        checked = s.showCompartment,
        onClick = function(self)
            s.showCompartment = self:GetChecked()
            if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshElements then
                M.RefreshElements()
            end
        end,
    })
    compCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    track(compCB)
    cy = cy - ROW_HEIGHT

    local unclampCB = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMSKIN_UNCLAMP"],
        checked = s.unclampMinimap,
        onClick = function(self)
            s.unclampMinimap = self:GetChecked()
            if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshUnclamp then
                M.RefreshUnclamp()
            end
        end,
    })
    unclampCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    track(unclampCB)
    cy = cy - ROW_HEIGHT

    InlineCB("hideWorldMapButton", "MMSKIN_HIDE_WM_BTN")

    -- ═══════════════════════════════════════════════════════════════════════
    -- 5. Combat Fade — inline toggle + opacity sub-setting
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_COMBAT"], yOffset = cy })

    InlineCB("combatFade", "MMSKIN_COMBAT_FADE")
    if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "combatFade") then
        local fadeCfLabel
        fadeCfLabel, cy = AddLabelIndented(container, cy,
            string.format("%s: %.0f%%", L["MMSKIN_COMBAT_ALPHA"], s.combatFadeAlpha * 100))

        local fadeCfSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 10, maxVal = 90, step = 5,
            currentVal = math.floor(s.combatFadeAlpha * 100),
            width = 240, fmt = "%d%%",
            onChange = function(val)
                s.combatFadeAlpha = val / 100
                fadeCfLabel:SetText(string.format("%s: %.0f%%", L["MMSKIN_COMBAT_ALPHA"], val))
            end,
        })
        fadeCfSlider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        track(fadeCfSlider)
        cy = cy - SLIDER_HEIGHT
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- 6. Click Actions — inline toggle + per-button binding rows
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_CLICKS"], yOffset = cy })

    InlineCB("clickActions", "MMSKIN_CLICK_ACTIONS")
    if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "clickActions") then
        local bindings = {
            { key = "clickRight",  label = L["MMSKIN_CLICK_RIGHT"]  },
            { key = "clickMiddle", label = L["MMSKIN_CLICK_MIDDLE"] },
            { key = "clickBtn4",   label = L["MMSKIN_CLICK_BTN4"]   },
            { key = "clickBtn5",   label = L["MMSKIN_CLICK_BTN5"]   },
        }

        -- Column width per option is derived from the measured localized label
        -- so longer translations (e.g. "Tracking" in non-EN locales) do not
        -- visually overlap the next column.
        local COL_GAP = 20
        for _, bind in ipairs(bindings) do
            local _, newCy = AddLabelIndented(container, cy, bind.label)
            cy = newCy

            local checkboxes = {}
            local xOff = INDENT_SLIDER
            for _, opt in ipairs(CLICK_OPTIONS) do
                local capturedOpt = opt
                local capturedKey = bind.key
                local cb = OneWoW_GUI:CreateCheckbox(container, {
                    label   = L[CLICK_LABEL_KEYS[opt]],
                    checked = s[capturedKey] == capturedOpt,
                    onClick = function(self)
                        s[capturedKey] = capturedOpt
                        for _, other in ipairs(checkboxes) do
                            other:SetChecked(false)
                        end
                        self:SetChecked(true)
                    end,
                })
                cb:SetPoint("TOPLEFT", container, "TOPLEFT", xOff, cy)
                track(cb)
                table.insert(checkboxes, cb)
                local cbWidth = cb:GetWidth() or 24
                local labelWidth = cb.label and cb.label:GetStringWidth() or 0
                xOff = xOff + cbWidth + labelWidth + COL_GAP
            end
            cy = cy - ROW_HEIGHT
        end
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- 7. Compatibility — Plumber / expansion minimap duplicate
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_GROUP_COMPAT"], yOffset = cy })

    InlineCB("hideBlizzardExpansionWhenPlumber", "MMSKIN_PLUMBER_HIDE_BLIZZARD")

    local plumberStatus = (M.IsPlumberLoaded and M.IsPlumberLoaded())
        and L["MMSKIN_PLUMBER_STATUS_ON"]
        or  L["MMSKIN_PLUMBER_STATUS_OFF"]
    local _, statusCy = AddLabelIndented(container, cy, plumberStatus, "TEXT_MUTED")
    cy = statusCy

    -- ═══════════════════════════════════════════════════════════════════════
    -- 8. Developer Tools — debug icon overlay button
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_DEBUG"], yOffset = cy })

    local debugBtnLabel = M._debugActive
        and L["MMSKIN_DEBUG_HIDE"]
        or  L["MMSKIN_DEBUG_SHOW"]

    local debugBtn = OneWoW_GUI:CreateFitTextButton(container, { text = debugBtnLabel, height = 24 })
    debugBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    debugBtn:SetScript("OnClick", function()
        if M.DebugIconsToggle then
            M.DebugIconsToggle()
            if M._refreshCustomDetail then M._refreshCustomDetail() end
        end
    end)
    track(debugBtn)
    cy = cy - 32

    local _, descCy = AddLabel(container, cy, L["MMSKIN_DEBUG_DESC"], "TEXT_MUTED")
    cy = descCy

    if not isEnabled then
        for _, w in ipairs(controls) do DisableWidget(w) end
    end

    container:SetHeight(math.abs(cy))
    return cy
end

-- ─── CreateCustomDetail ─────────────────────────────────────────────────────

function M:CreateCustomDetail(detailScrollChild, yOffset, isEnabled, registerRefresh)
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

    self._refreshCustomDetail = function()
        OneWoW_GUI:ClearFrame(container)
        local cy = BuildContent(container)
        detailScrollChild:SetHeight(math.abs(capturedYOffset) + math.abs(cy) + 20)
        if detailScrollChild.updateThumb then
            detailScrollChild.updateThumb()
        end
    end

    -- Flipping the module's master toggle re-queries IsEnabled on the next
    -- build, so tracked controls pick up the new enabled/disabled state.
    if registerRefresh then registerRefresh(self._refreshCustomDetail) end

    local cy = BuildContent(container)

    return yOffset + cy
end
