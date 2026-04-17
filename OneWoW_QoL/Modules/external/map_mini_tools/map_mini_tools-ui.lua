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

local function AddLabel(parent, cy, text, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, cy)
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor(color or "TEXT_SECONDARY"))
    return fs, cy - fs:GetStringHeight() - 4
end

local function AddLabelIndented(parent, cy, text, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT_LABEL, cy)
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor(color or "TEXT_SECONDARY"))
    return fs, cy - fs:GetStringHeight() - 4
end

local function GetFontLabel(fontKey)
    local L = ns.L
    if not fontKey or fontKey == "global" then
        return L["MMSKIN_FONT_GLOBAL"] or "Global Font"
    end
    if OneWoW_GUI.GetFontList then
        for _, f in ipairs(OneWoW_GUI:GetFontList()) do
            if f.key == fontKey then return f.label end
        end
    end
    return fontKey
end

local function BuildFontItems()
    local L = ns.L
    local items = { { value = "global", text = L["MMSKIN_FONT_GLOBAL"] or "Global Font" } }
    if OneWoW_GUI.GetFontList then
        for _, f in ipairs(OneWoW_GUI:GetFontList()) do
            table.insert(items, { value = f.key, text = f.label })
        end
    end
    return items
end

-- ─── Content Builder ────────────────────────────────────────────────────────

local function BuildContent(container)
    local L = ns.L
    local s = M.GetSettings()
    local cy = 0

    -- Inline toggle checkbox — modifies cy via Lua upvalue closure.
    -- Calls SetToggleValue which triggers M:OnToggle → behavior + detail refresh.
    local function InlineCB(id, labelKey, fallback)
        local cb = OneWoW_GUI:CreateCheckbox(container, {
            label   = L[labelKey] or fallback,
            checked = ns.ModuleRegistry:GetToggleValue("map_mini_tools", id),
            onClick = function(self)
                ns.ModuleRegistry:SetToggleValue("map_mini_tools", id, self:GetChecked())
            end,
        })
        cb:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
        cy = cy - ROW_HEIGHT
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- 1. Scale & Opacity (always visible)
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_OPACITY"] or "Scale & Opacity", yOffset = cy })

    local scaleLabel
    scaleLabel, cy = AddLabel(container, cy,
        string.format("%s: %.1f", L["MMSKIN_SCALE_LABEL"] or "Minimap Scale", s.scale))

    local scaleSlider = OneWoW_GUI:CreateSlider(container, {
        minVal = 0.5, maxVal = 2.0, step = 0.1,
        currentVal = s.scale, width = 260, fmt = "%.1f",
        onChange = function(val)
            s.scale = val
            scaleLabel:SetText(string.format("%s: %.1f", L["MMSKIN_SCALE_LABEL"] or "Minimap Scale", val))
            if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshScale then
                M.RefreshScale()
            end
        end,
    })
    scaleSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    cy = cy - SLIDER_HEIGHT

    if s.minimapAlpha == nil then s.minimapAlpha = 1.0 end
    local opacityLabel
    opacityLabel, cy = AddLabel(container, cy,
        string.format("%s: %.0f%%", L["MMSKIN_OPACITY"] or "Minimap Opacity", s.minimapAlpha * 100))

    local opacitySlider = OneWoW_GUI:CreateSlider(container, {
        minVal = 10, maxVal = 100, step = 5,
        currentVal = math.floor(s.minimapAlpha * 100),
        width = 260, fmt = "%d%%",
        onChange = function(val)
            s.minimapAlpha = val / 100
            opacityLabel:SetText(string.format("%s: %.0f%%", L["MMSKIN_OPACITY"] or "Minimap Opacity", val))
            if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshAlpha then
                M.RefreshAlpha()
            end
        end,
    })
    opacitySlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    cy = cy - SLIDER_HEIGHT

    -- ═══════════════════════════════════════════════════════════════════════
    -- 2. Border Settings (only when showBorder + squareShape are both on)
    -- ═══════════════════════════════════════════════════════════════════════
    if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "showBorder") and ns.ModuleRegistry:GetToggleValue("map_mini_tools", "squareShape") then
        cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_BORDER"] or "Border Settings", yOffset = cy })

        local bsLabel
        bsLabel, cy = AddLabel(container, cy,
            string.format("%s: %d", L["MMSKIN_BORDER_SIZE"] or "Border Size", s.borderSize))

        local bsSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 1, maxVal = 15, step = 1,
            currentVal = s.borderSize, width = 260, fmt = "%d",
            onChange = function(val)
                s.borderSize = val
                bsLabel:SetText(string.format("%s: %d", L["MMSKIN_BORDER_SIZE"] or "Border Size", val))
                if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshBorder then
                    M.RefreshBorder()
                end
            end,
        })
        bsSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
        cy = cy - SLIDER_HEIGHT

        local themeCB = OneWoW_GUI:CreateCheckbox(container, {
            label   = L["MMSKIN_USE_THEME_COLOR"] or "Use Theme Color",
            checked = s.useThemeColor,
            onClick = function(self)
                s.useThemeColor = self:GetChecked()
                if M.RefreshBorder then M.RefreshBorder() end
                if M._refreshCustomDetail then M._refreshCustomDetail() end
            end,
        })
        themeCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
        cy = cy - ROW_HEIGHT

        if not s.useThemeColor and not ns.ModuleRegistry:GetToggleValue("map_mini_tools", "classBorder") then
            if not s.borderColor then s.borderColor = { 0, 0, 0, 1 } end

            local colorSliders = {
                { idx = 1, key = "MMSKIN_BORDER_RED",   fallback = "Red"   },
                { idx = 2, key = "MMSKIN_BORDER_GREEN", fallback = "Green" },
                { idx = 3, key = "MMSKIN_BORDER_BLUE",  fallback = "Blue"  },
            }

            for _, cs in ipairs(colorSliders) do
                local csLabel
                local labelText = L[cs.key] or cs.fallback
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
                cy = cy - SLIDER_HEIGHT
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- 3. Information Overlays — Zone Text & Clock, each with inline toggle
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_GROUP_INFO"] or "Information Overlays", yOffset = cy })

    InlineCB("zoneClockInside", "MMSKIN_ZONE_CLOCK_INSIDE", "Zone & clock inside minimap")
    InlineCB("zoneClockDraggable", "MMSKIN_ZONE_CLOCK_DRAG", "Drag zone & clock (hold Shift)")

    -- Zone Text toggle + sub-settings
    InlineCB("showZoneText", "MMSKIN_ZONE_TEXT", "Zone Text")
    if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "showZoneText") then
        local zoneFontLabel
        zoneFontLabel, cy = AddLabelIndented(container, cy, L["MMSKIN_ZONE_FONT_LABEL"] or "Font")

        local zoneFontDrop, zoneFontText = OneWoW_GUI:CreateDropdown(container, {
            width = 200, height = 22,
            text = GetFontLabel(s.zoneFont),
        })
        zoneFontDrop:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        cy = cy - ROW_HEIGHT

        if OneWoW_GUI.AttachFilterMenu then
            OneWoW_GUI:AttachFilterMenu(zoneFontDrop, {
                searchable = false, menuHeight = 200, maxVisible = 10,
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
        end

        local zfSizeLabel
        zfSizeLabel, cy = AddLabelIndented(container, cy,
            string.format("%s: %d", L["MMSKIN_ZONE_FONT_SIZE"] or "Font Size", s.zoneFontSize))

        local zfSizeSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 8, maxVal = 24, step = 1,
            currentVal = s.zoneFontSize, width = 240, fmt = "%d",
            onChange = function(val)
                s.zoneFontSize = val
                zfSizeLabel:SetText(string.format("%s: %d", L["MMSKIN_ZONE_FONT_SIZE"] or "Font Size", val))
                if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshZoneFont then
                    M.RefreshZoneFont()
                end
            end,
        })
        zfSizeSlider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        cy = cy - SLIDER_HEIGHT
        cy = cy - 4
    end

    -- Clock toggle + sub-settings
    InlineCB("showClock", "MMSKIN_CLOCK", "Clock")
    if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "showClock") then
        local clockFontLabel
        clockFontLabel, cy = AddLabelIndented(container, cy, L["MMSKIN_CLOCK_FONT_LABEL"] or "Font")

        local clockFontDrop, clockFontText = OneWoW_GUI:CreateDropdown(container, {
            width = 200, height = 22,
            text = GetFontLabel(s.clockFont),
        })
        clockFontDrop:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        cy = cy - ROW_HEIGHT

        if OneWoW_GUI.AttachFilterMenu then
            OneWoW_GUI:AttachFilterMenu(clockFontDrop, {
                searchable = false, menuHeight = 200, maxVisible = 10,
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
        end

        local cfSizeLabel
        cfSizeLabel, cy = AddLabelIndented(container, cy,
            string.format("%s: %d", L["MMSKIN_CLOCK_FONT_SIZE"] or "Font Size", s.clockFontSize))

        local cfSizeSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 8, maxVal = 24, step = 1,
            currentVal = s.clockFontSize, width = 240, fmt = "%d",
            onChange = function(val)
                s.clockFontSize = val
                cfSizeLabel:SetText(string.format("%s: %d", L["MMSKIN_CLOCK_FONT_SIZE"] or "Font Size", val))
                if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshClockFont then
                    M.RefreshClockFont()
                end
            end,
        })
        cfSizeSlider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        cy = cy - SLIDER_HEIGHT
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- 4. Zoom & Scroll — Auto Zoom (inline toggle + delay), plus map controls
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_GROUP_ZOOM"] or "Zoom & Scroll", yOffset = cy })

    -- Auto Zoom Out toggle + delay sub-setting
    InlineCB("autoZoomOut", "MMSKIN_AUTO_ZOOM", "Auto Zoom Out")
    if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "autoZoomOut") then
        local azLabel
        azLabel, cy = AddLabelIndented(container, cy,
            string.format("%s: %ds", L["MMSKIN_AUTO_ZOOM_DELAY"] or "Auto Zoom Delay", s.autoZoomDelay))

        local azSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 3, maxVal = 30, step = 1,
            currentVal = s.autoZoomDelay, width = 240, fmt = "%d",
            onChange = function(val)
                s.autoZoomDelay = val
                azLabel:SetText(string.format("%s: %ds", L["MMSKIN_AUTO_ZOOM_DELAY"] or "Auto Zoom Delay", val))
            end,
        })
        azSlider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        cy = cy - SLIDER_HEIGHT
        cy = cy - 4
    end

    -- Additional map control checkboxes
    local zbCB = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMSKIN_SHOW_ZOOM_BTNS"] or "Show Zoom Buttons",
        checked = s.showZoomBtns,
        onClick = function(self)
            s.showZoomBtns = self:GetChecked()
            if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshElements then
                M.RefreshElements()
            end
        end,
    })
    zbCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    cy = cy - ROW_HEIGHT

    local compCB = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMSKIN_SHOW_COMPARTMENT"] or "Addon Compartment",
        checked = s.showCompartment,
        onClick = function(self)
            s.showCompartment = self:GetChecked()
            if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshElements then
                M.RefreshElements()
            end
        end,
    })
    compCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    cy = cy - ROW_HEIGHT

    local unclampCB = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMSKIN_UNCLAMP"] or "Unclamp from Screen",
        checked = s.unclampMinimap,
        onClick = function(self)
            s.unclampMinimap = self:GetChecked()
            if ns.ModuleRegistry:IsEnabled("map_mini_tools") and M.RefreshUnclamp then
                M.RefreshUnclamp()
            end
        end,
    })
    unclampCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    cy = cy - ROW_HEIGHT

    InlineCB("hideWorldMapButton", "MMSKIN_HIDE_WM_BTN", "Hide world map button")

    -- ═══════════════════════════════════════════════════════════════════════
    -- 5. Combat Fade — inline toggle + opacity sub-setting
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_COMBAT"] or "Combat Fade", yOffset = cy })

    InlineCB("combatFade", "MMSKIN_COMBAT_FADE", "Combat Fade")
    if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "combatFade") then
        local fadeCfLabel
        fadeCfLabel, cy = AddLabelIndented(container, cy,
            string.format("%s: %.0f%%", L["MMSKIN_COMBAT_ALPHA"] or "Combat Opacity", s.combatFadeAlpha * 100))

        local fadeCfSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 10, maxVal = 90, step = 5,
            currentVal = math.floor(s.combatFadeAlpha * 100),
            width = 240, fmt = "%d%%",
            onChange = function(val)
                s.combatFadeAlpha = val / 100
                fadeCfLabel:SetText(string.format("%s: %.0f%%", L["MMSKIN_COMBAT_ALPHA"] or "Combat Opacity", val))
            end,
        })
        fadeCfSlider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        cy = cy - SLIDER_HEIGHT
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- 6. Click Actions — inline toggle + per-button binding rows
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_CLICKS"] or "Click Binding Settings", yOffset = cy })

    InlineCB("clickActions", "MMSKIN_CLICK_ACTIONS", "Enable Click Actions")
    if ns.ModuleRegistry:GetToggleValue("map_mini_tools", "clickActions") then
        local bindings = {
            { key = "clickRight",  label = L["MMSKIN_CLICK_RIGHT"]  or "Right Click"  },
            { key = "clickMiddle", label = L["MMSKIN_CLICK_MIDDLE"] or "Middle Click" },
            { key = "clickBtn4",   label = L["MMSKIN_CLICK_BTN4"]   or "Button 4"     },
            { key = "clickBtn5",   label = L["MMSKIN_CLICK_BTN5"]   or "Button 5"     },
        }

        for _, bind in ipairs(bindings) do
            local _, newCy = AddLabelIndented(container, cy, bind.label)
            cy = newCy

            local checkboxes = {}
            local xOff = INDENT_SLIDER
            for _, opt in ipairs(CLICK_OPTIONS) do
                local capturedOpt = opt
                local capturedKey = bind.key
                local cb = OneWoW_GUI:CreateCheckbox(container, {
                    label   = L[CLICK_LABEL_KEYS[opt]] or opt,
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
                table.insert(checkboxes, cb)
                xOff = xOff + 76
            end
            cy = cy - ROW_HEIGHT
        end
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- 7. Compatibility — Plumber / expansion minimap duplicate
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_GROUP_COMPAT"] or "Compatibility", yOffset = cy })

    InlineCB("hideBlizzardExpansionWhenPlumber", "MMSKIN_PLUMBER_HIDE_BLIZZARD", "Hide duplicate Blizzard expansion button with Plumber")

    local plumberStatus = (M.IsPlumberLoaded and M.IsPlumberLoaded()) and (L["MMSKIN_PLUMBER_STATUS_ON"] or "Plumber is loaded.")
        or (L["MMSKIN_PLUMBER_STATUS_OFF"] or "Plumber is not loaded.")
    local _, statusCy = AddLabelIndented(container, cy, plumberStatus, "TEXT_MUTED")
    cy = statusCy

    -- ═══════════════════════════════════════════════════════════════════════
    -- 8. Developer Tools — debug icon overlay button
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_DEBUG"] or "Developer Tools", yOffset = cy })

    local debugBtnLabel = M._debugActive
        and (L["MMSKIN_DEBUG_HIDE"] or "Hide Debug Icons")
        or  (L["MMSKIN_DEBUG_SHOW"] or "Show Debug Icons")

    local debugBtn = OneWoW_GUI:CreateFitTextButton(container, { text = debugBtnLabel, height = 24 })
    debugBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    debugBtn:SetScript("OnClick", function()
        if M.DebugIconsToggle then
            M.DebugIconsToggle()
            if M._refreshCustomDetail then M._refreshCustomDetail() end
        end
    end)
    cy = cy - 32

    local _, descCy = AddLabel(container, cy,
        L["MMSKIN_DEBUG_DESC"] or "Force all tracked icons visible with colored labels to verify their positions.",
        "TEXT_MUTED")
    cy = descCy

    container:SetHeight(math.abs(cy))
    return cy
end

-- ─── CreateCustomDetail ─────────────────────────────────────────────────────

function M:CreateCustomDetail(detailScrollChild, yOffset, isEnabled)
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

    local cy = BuildContent(container)

    return yOffset + cy
end
