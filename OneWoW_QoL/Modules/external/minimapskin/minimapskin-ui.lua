local addonName, ns = ...
local M = ns.MinimapSkinModule

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

-- ─── Constants ──────────────────────────────────────────────────────────────

local ROW_HEIGHT   = 28
local SLIDER_HEIGHT = 42

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

    -- ═══════════════════════════════════════════════════════════════════════
    -- Scale
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_SCALE"] or "Scale", yOffset = cy })

    local scaleLabel
    scaleLabel, cy = AddLabel(container, cy,
        string.format("%s: %.1f", L["MMSKIN_SCALE_LABEL"] or "Minimap Scale", s.scale))

    local scaleSlider = OneWoW_GUI:CreateSlider(container, {
        minVal = 0.5, maxVal = 2.0, step = 0.1,
        currentVal = s.scale, width = 260, fmt = "%.1f",
        onChange = function(val)
            s.scale = val
            scaleLabel:SetText(string.format("%s: %.1f", L["MMSKIN_SCALE_LABEL"] or "Minimap Scale", val))
            if ns.ModuleRegistry:IsEnabled("minimapskin") and M.RefreshScale then
                M.RefreshScale()
            end
        end,
    })
    scaleSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    cy = cy - SLIDER_HEIGHT

    -- ═══════════════════════════════════════════════════════════════════════
    -- Border Settings (only when border AND square toggles are on)
    -- ═══════════════════════════════════════════════════════════════════════
    if ns.ModuleRegistry:GetToggleValue("minimapskin", "showBorder") and ns.ModuleRegistry:GetToggleValue("minimapskin", "squareShape") then
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
                if ns.ModuleRegistry:IsEnabled("minimapskin") and M.RefreshBorder then
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

        if not s.useThemeColor and not ns.ModuleRegistry:GetToggleValue("minimapskin", "classBorder") then
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
    -- Zone Text Settings (only when showZoneText toggle is on)
    -- ═══════════════════════════════════════════════════════════════════════
    if ns.ModuleRegistry:GetToggleValue("minimapskin", "showZoneText") then
        cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_ZONE_FONT"] or "Zone Text", yOffset = cy })

        local _, zoneFontLabelCy = AddLabel(container, cy, L["MMSKIN_ZONE_FONT_LABEL"] or "Font")
        cy = zoneFontLabelCy

        local zoneFontDrop, zoneFontText = OneWoW_GUI:CreateDropdown(container, {
            width = 200, height = 22,
            text = GetFontLabel(s.zoneFont),
        })
        zoneFontDrop:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
        cy = cy - ROW_HEIGHT

        if OneWoW_GUI.AttachFilterMenu then
            OneWoW_GUI:AttachFilterMenu(zoneFontDrop, {
                searchable = false,
                menuHeight = 200,
                maxVisible = 10,
                getActiveValue = function() return s.zoneFont end,
                buildItems = BuildFontItems,
                onSelect = function(value, text)
                    s.zoneFont = value
                    zoneFontText:SetText(text)
                    if ns.ModuleRegistry:IsEnabled("minimapskin") and M.RefreshZoneFont then
                        M.RefreshZoneFont()
                    end
                end,
            })
        end

        local zfSizeLabel
        zfSizeLabel, cy = AddLabel(container, cy,
            string.format("%s: %d", L["MMSKIN_ZONE_FONT_SIZE"] or "Font Size", s.zoneFontSize))

        local zfSizeSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 8, maxVal = 24, step = 1,
            currentVal = s.zoneFontSize, width = 260, fmt = "%d",
            onChange = function(val)
                s.zoneFontSize = val
                zfSizeLabel:SetText(string.format("%s: %d", L["MMSKIN_ZONE_FONT_SIZE"] or "Font Size", val))
                if ns.ModuleRegistry:IsEnabled("minimapskin") and M.RefreshZoneFont then
                    M.RefreshZoneFont()
                end
            end,
        })
        zfSizeSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
        cy = cy - SLIDER_HEIGHT
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- Clock Settings (only when showClock toggle is on)
    -- ═══════════════════════════════════════════════════════════════════════
    if ns.ModuleRegistry:GetToggleValue("minimapskin", "showClock") then
        cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_CLOCK_FONT"] or "Clock", yOffset = cy })

        local _, clockFontLabelCy = AddLabel(container, cy, L["MMSKIN_CLOCK_FONT_LABEL"] or "Font")
        cy = clockFontLabelCy

        local clockFontDrop, clockFontText = OneWoW_GUI:CreateDropdown(container, {
            width = 200, height = 22,
            text = GetFontLabel(s.clockFont),
        })
        clockFontDrop:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
        cy = cy - ROW_HEIGHT

        if OneWoW_GUI.AttachFilterMenu then
            OneWoW_GUI:AttachFilterMenu(clockFontDrop, {
                searchable = false,
                menuHeight = 200,
                maxVisible = 10,
                getActiveValue = function() return s.clockFont end,
                buildItems = BuildFontItems,
                onSelect = function(value, text)
                    s.clockFont = value
                    clockFontText:SetText(text)
                    if ns.ModuleRegistry:IsEnabled("minimapskin") and M.RefreshClockFont then
                        M.RefreshClockFont()
                    end
                end,
            })
        end

        local cfSizeLabel
        cfSizeLabel, cy = AddLabel(container, cy,
            string.format("%s: %d", L["MMSKIN_CLOCK_FONT_SIZE"] or "Font Size", s.clockFontSize))

        local cfSizeSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 8, maxVal = 24, step = 1,
            currentVal = s.clockFontSize, width = 260, fmt = "%d",
            onChange = function(val)
                s.clockFontSize = val
                cfSizeLabel:SetText(string.format("%s: %d", L["MMSKIN_CLOCK_FONT_SIZE"] or "Font Size", val))
                if ns.ModuleRegistry:IsEnabled("minimapskin") and M.RefreshClockFont then
                    M.RefreshClockFont()
                end
            end,
        })
        cfSizeSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
        cy = cy - SLIDER_HEIGHT
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- Auto Zoom Settings (only when autoZoomOut toggle is on)
    -- ═══════════════════════════════════════════════════════════════════════
    if ns.ModuleRegistry:GetToggleValue("minimapskin", "autoZoomOut") then
        cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_ZOOM"] or "Auto Zoom", yOffset = cy })

        local azLabel
        azLabel, cy = AddLabel(container, cy,
            string.format("%s: %ds", L["MMSKIN_AUTO_ZOOM_DELAY"] or "Auto Zoom Delay", s.autoZoomDelay))

        local azSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 3, maxVal = 30, step = 1,
            currentVal = s.autoZoomDelay, width = 260, fmt = "%d",
            onChange = function(val)
                s.autoZoomDelay = val
                azLabel:SetText(string.format("%s: %ds", L["MMSKIN_AUTO_ZOOM_DELAY"] or "Auto Zoom Delay", val))
            end,
        })
        azSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
        cy = cy - SLIDER_HEIGHT
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- Additional Elements
    -- ═══════════════════════════════════════════════════════════════════════
    cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_ELEMENTS"] or "Additional Elements", yOffset = cy })

    local zbCB = OneWoW_GUI:CreateCheckbox(container, {
        label   = L["MMSKIN_SHOW_ZOOM_BTNS"] or "Show Zoom Buttons",
        checked = s.showZoomBtns,
        onClick = function(self)
            s.showZoomBtns = self:GetChecked()
            if ns.ModuleRegistry:IsEnabled("minimapskin") and M.RefreshElements then
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
            if ns.ModuleRegistry:IsEnabled("minimapskin") and M.RefreshElements then
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
            if ns.ModuleRegistry:IsEnabled("minimapskin") and M.RefreshUnclamp then
                M.RefreshUnclamp()
            end
        end,
    })
    unclampCB:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    cy = cy - ROW_HEIGHT

    -- ═══════════════════════════════════════════════════════════════════════
    -- Combat Fade Settings (only when combatFade toggle is on)
    -- ═══════════════════════════════════════════════════════════════════════
    if ns.ModuleRegistry:GetToggleValue("minimapskin", "combatFade") then
        cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_COMBAT"] or "Combat Fade Settings", yOffset = cy })

        local cfLabel
        cfLabel, cy = AddLabel(container, cy,
            string.format("%s: %.0f%%", L["MMSKIN_COMBAT_ALPHA"] or "Combat Opacity", s.combatFadeAlpha * 100))

        local cfSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 10, maxVal = 90, step = 5,
            currentVal = math.floor(s.combatFadeAlpha * 100),
            width = 260, fmt = "%d%%",
            onChange = function(val)
                s.combatFadeAlpha = val / 100
                cfLabel:SetText(string.format("%s: %.0f%%", L["MMSKIN_COMBAT_ALPHA"] or "Combat Opacity", val))
            end,
        })
        cfSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
        cy = cy - SLIDER_HEIGHT
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- Click Bindings (only when clickActions toggle is on)
    -- ═══════════════════════════════════════════════════════════════════════
    if ns.ModuleRegistry:GetToggleValue("minimapskin", "clickActions") then
        cy = OneWoW_GUI:CreateSection(container, { title = L["MMSKIN_SECTION_CLICKS"] or "Click Binding Settings", yOffset = cy })

        local bindings = {
            { key = "clickRight",  label = L["MMSKIN_CLICK_RIGHT"]  or "Right Click"  },
            { key = "clickMiddle", label = L["MMSKIN_CLICK_MIDDLE"] or "Middle Click" },
            { key = "clickBtn4",   label = L["MMSKIN_CLICK_BTN4"]   or "Button 4"     },
            { key = "clickBtn5",   label = L["MMSKIN_CLICK_BTN5"]   or "Button 5"     },
        }

        for _, bind in ipairs(bindings) do
            local _, newCy = AddLabel(container, cy, bind.label)
            cy = newCy

            local checkboxes = {}
            local xOff = 24
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
                xOff = xOff + 80
            end
            cy = cy - ROW_HEIGHT
        end
    end

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
