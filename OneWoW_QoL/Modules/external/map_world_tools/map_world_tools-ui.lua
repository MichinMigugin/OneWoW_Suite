local addonName, ns = ...
local M = ns.MapWorldToolsModule

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local ROW_HEIGHT    = 28
local SLIDER_HEIGHT = 42
local INDENT_LABEL  = 24
local INDENT_SLIDER = 36

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

local function BuildContent(container)
    local L = ns.L
    local s = M.GetSettings()
    local cy = 0

    local function InlineCB(id, labelKey, fallback)
        local cb = OneWoW_GUI:CreateCheckbox(container, {
            label   = L[labelKey] or fallback,
            checked = ns.ModuleRegistry:GetToggleValue("map_world_tools", id),
            onClick = function(self)
                ns.ModuleRegistry:SetToggleValue("map_world_tools", id, self:GetChecked())
            end,
        })
        cb:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
        cy = cy - ROW_HEIGHT
    end

    cy = OneWoW_GUI:CreateSection(container, { title = L["MAPWORLD_GROUP_FOG"] or "Fog of War", yOffset = cy })

    InlineCB("removeBattleFog", "MAPWORLD_REMOVE_FOG", "Remove Battle Fog")
    InlineCB("fogTint", "MAPWORLD_FOG_TINT", "Tint Fog Layer")

    if ns.ModuleRegistry:GetToggleValue("map_world_tools", "fogTint") then
        local fogCols = {
            { idx = "fogTintR", key = "MAPWORLD_RED",   fallback = "Red"   },
            { idx = "fogTintG", key = "MAPWORLD_GREEN", fallback = "Green" },
            { idx = "fogTintB", key = "MAPWORLD_BLUE",  fallback = "Blue"  },
        }
        for _, col in ipairs(fogCols) do
            local lblKey = col.key
            local lbl
            lbl, cy = AddLabelIndented(container, cy,
                string.format("%s: %d", L[lblKey] or col.fallback, s[col.idx]),
                "TEXT_SECONDARY")

            local slider = OneWoW_GUI:CreateSlider(container, {
                minVal = 0, maxVal = 255, step = 1,
                currentVal = s[col.idx], width = 240, fmt = "%d",
                onChange = function(val)
                    s[col.idx] = val
                    lbl:SetText(string.format("%s: %d", L[lblKey] or col.fallback, val))
                    if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshFogAppearance then
                        M.RefreshFogAppearance()
                    end
                end,
            })
            slider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
            cy = cy - SLIDER_HEIGHT
        end
        cy = cy - 4
    end

    cy = OneWoW_GUI:CreateSection(container, { title = L["MAPWORLD_GROUP_CANVAS"] or "Map Overlay", yOffset = cy })

    InlineCB("canvasTint", "MAPWORLD_CANVAS_TINT", "Full Map Color Overlay")

    if ns.ModuleRegistry:GetToggleValue("map_world_tools", "canvasTint") then
        local canvasCols = {
            { idx = "canvasR", key = "MAPWORLD_RED",   fallback = "Red"   },
            { idx = "canvasG", key = "MAPWORLD_GREEN", fallback = "Green" },
            { idx = "canvasB", key = "MAPWORLD_BLUE",  fallback = "Blue"  },
        }
        for _, col in ipairs(canvasCols) do
            local lblKey = col.key
            local lbl
            lbl, cy = AddLabelIndented(container, cy,
                string.format("%s: %d", L[lblKey] or col.fallback, s[col.idx]),
                "TEXT_SECONDARY")

            local slider = OneWoW_GUI:CreateSlider(container, {
                minVal = 0, maxVal = 255, step = 1,
                currentVal = s[col.idx], width = 240, fmt = "%d",
                onChange = function(val)
                    s[col.idx] = val
                    lbl:SetText(string.format("%s: %d", L[lblKey] or col.fallback, val))
                    if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshCanvasOverlay then
                        M.RefreshCanvasOverlay()
                    end
                end,
            })
            slider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
            cy = cy - SLIDER_HEIGHT
        end

        local alphaLbl
        alphaLbl, cy = AddLabelIndented(container, cy,
            string.format("%s: %.0f%%", L["MAPWORLD_ALPHA"] or "Opacity", s.canvasA * 100),
            "TEXT_SECONDARY")

        local alphaSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 0, maxVal = 100, step = 5,
            currentVal = math.floor(s.canvasA * 100),
            width = 240, fmt = "%d%%",
            onChange = function(val)
                s.canvasA = val / 100
                alphaLbl:SetText(string.format("%s: %.0f%%", L["MAPWORLD_ALPHA"] or "Opacity", val))
                if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshCanvasOverlay then
                    M.RefreshCanvasOverlay()
                end
            end,
        })
        alphaSlider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        cy = cy - SLIDER_HEIGHT
    end

    cy = OneWoW_GUI:CreateSection(container, { title = L["MAPWORLD_GROUP_MAP"] or "World Map Frame", yOffset = cy })

    InlineCB("useMapFrameAlpha", "MAPWORLD_MAP_ALPHA", "World Map Opacity")

    if ns.ModuleRegistry:GetToggleValue("map_world_tools", "useMapFrameAlpha") then
        local mapAlphaLbl
        mapAlphaLbl, cy = AddLabelIndented(container, cy,
            string.format("%s: %.0f%%", L["MAPWORLD_MAP_ALPHA_SLIDER"] or "Map window opacity", (s.mapFrameAlpha or 1) * 100),
            "TEXT_SECONDARY")

        local mapAlphaSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 10, maxVal = 100, step = 5,
            currentVal = math.floor((s.mapFrameAlpha or 1) * 100),
            width = 240, fmt = "%d%%",
            onChange = function(val)
                s.mapFrameAlpha = val / 100
                mapAlphaLbl:SetText(string.format("%s: %.0f%%", L["MAPWORLD_MAP_ALPHA_SLIDER"] or "Map window opacity", val))
                if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshMapFrameAlpha then
                    M.RefreshMapFrameAlpha()
                end
            end,
        })
        mapAlphaSlider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        cy = cy - SLIDER_HEIGHT
        cy = cy - 4
    end

    container:SetHeight(math.abs(cy))
    return cy
end

function M:CreateCustomDetail(detailScrollChild, yOffset, isEnabled)
    if detailScrollChild._mapworldContainer then
        OneWoW_GUI:ClearFrame(detailScrollChild._mapworldContainer)
    end

    local container = detailScrollChild._mapworldContainer or CreateFrame("Frame", nil, detailScrollChild)
    detailScrollChild._mapworldContainer = container
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
