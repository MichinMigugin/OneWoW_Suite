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

    cy = OneWoW_GUI:CreateSection(container, { title = L["MAPWORLD_GROUP_EXPLORE"] or "Exploration", yOffset = cy })

    InlineCB("revealMap", "MAPWORLD_REVEAL_MAP", "Show unexplored areas")
    InlineCB("tintUnexplored", "MAPWORLD_TINT_UNEXPLORED", "Tint unexplored areas")

    if ns.ModuleRegistry:GetToggleValue("map_world_tools", "tintUnexplored") then
        local unexCols = {
            { idx = "unexploredTintR", key = "MAPWORLD_UNEX_R", fb = "Red" },
            { idx = "unexploredTintG", key = "MAPWORLD_UNEX_G", fb = "Green" },
            { idx = "unexploredTintB", key = "MAPWORLD_UNEX_B", fb = "Blue" },
        }
        for _, col in ipairs(unexCols) do
            local lbl
            lbl, cy = AddLabelIndented(container, cy,
                string.format("%s: %d", L[col.key] or col.fb, s[col.idx] or 255),
                "TEXT_SECONDARY")
            local slider = OneWoW_GUI:CreateSlider(container, {
                minVal = 0, maxVal = 255, step = 1,
                currentVal = s[col.idx] or 255, width = 240, fmt = "%d",
                onChange = function(val)
                    s[col.idx] = val
                    lbl:SetText(string.format("%s: %d", L[col.key] or col.fb, val))
                    if ns.ModuleRegistry:IsEnabled("map_world_tools") then
                        if M.RefreshExploreTint then M.RefreshExploreTint() end
                        if M.RefreshFogAppearance then M.RefreshFogAppearance() end
                    end
                end,
            })
            slider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
            cy = cy - SLIDER_HEIGHT
        end
        local aLbl
        aLbl, cy = AddLabelIndented(container, cy,
            string.format("%s: %.0f%%", L["MAPWORLD_UNEX_A"] or "Unexplored opacity", (s.unexploredTintA or 1) * 100),
            "TEXT_SECONDARY")
        local aSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 10, maxVal = 100, step = 5,
            currentVal = math.floor((s.unexploredTintA or 1) * 100),
            width = 240, fmt = "%d%%",
            onChange = function(val)
                s.unexploredTintA = val / 100
                aLbl:SetText(string.format("%s: %.0f%%", L["MAPWORLD_UNEX_A"] or "Unexplored opacity", val))
                if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshExploreTint then
                    M.RefreshExploreTint()
                end
            end,
        })
        aSlider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        cy = cy - SLIDER_HEIGHT
        cy = cy - 4
    end

    cy = OneWoW_GUI:CreateSection(container, { title = L["MAPWORLD_GROUP_FOGOVERLAY"] or "Fog overlay", yOffset = cy })

    InlineCB("removeBattleFog", "MAPWORLD_REMOVE_FOG", "Hide dark fog layer")
    InlineCB("fogTint", "MAPWORLD_FOG_TINT", "Tint fog layer (FoW)")

    if ns.ModuleRegistry:GetToggleValue("map_world_tools", "fogTint") then
        for _, col in ipairs({
            { idx = "fogTintR", key = "MAPWORLD_RED", fb = "Red" },
            { idx = "fogTintG", key = "MAPWORLD_GREEN", fb = "Green" },
            { idx = "fogTintB", key = "MAPWORLD_BLUE", fb = "Blue" },
        }) do
            local lbl
            lbl, cy = AddLabelIndented(container, cy,
                string.format("%s: %d", L[col.key] or col.fb, s[col.idx]),
                "TEXT_SECONDARY")
            local slider = OneWoW_GUI:CreateSlider(container, {
                minVal = 0, maxVal = 255, step = 1,
                currentVal = s[col.idx], width = 240, fmt = "%d",
                onChange = function(val)
                    s[col.idx] = val
                    lbl:SetText(string.format("%s: %d", L[col.key] or col.fb, val))
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

    cy = OneWoW_GUI:CreateSection(container, { title = L["MAPWORLD_GROUP_FRAME"] or "Map window", yOffset = cy })
    InlineCB("clearBlackout", "MAPWORLD_CLEAR_BLACKOUT", "Click-through world behind map")

    cy = OneWoW_GUI:CreateSection(container, { title = L["MAPWORLD_GROUP_COMFORT"] or "Comfort", yOffset = cy })
    InlineCB("noMapFade", "MAPWORLD_NO_MAP_FADE", "Disable map fade while moving")
    InlineCB("noMapEmote", "MAPWORLD_NO_MAP_EMOTE", "Disable reading emote")

    cy = OneWoW_GUI:CreateSection(container, { title = L["MAPWORLD_GROUP_CLEANUP"] or "Cleanup", yOffset = cy })
    InlineCB("hideFilterReset", "MAPWORLD_HIDE_FILTER_RESET", "Hide filter reset UI")
    InlineCB("hideMapTutorial", "MAPWORLD_HIDE_MAP_TUTORIAL", "Suppress map tutorial")

    cy = OneWoW_GUI:CreateSection(container, { title = L["MAPWORLD_GROUP_COORDS"] or "Coordinates", yOffset = cy })
    InlineCB("showCoords", "MAPWORLD_SHOW_COORDS", "Show coordinates")
    InlineCB("coordsLargeFont", "MAPWORLD_COORDS_LARGE", "Large coordinate font")
    InlineCB("coordsBackground", "MAPWORLD_COORDS_BG", "Coordinate bar background")

    cy = OneWoW_GUI:CreateSection(container, { title = L["MAPWORLD_GROUP_POI"] or "Points of interest", yOffset = cy })
    InlineCB("hideContinentPoi", "MAPWORLD_HIDE_CONTINENT_POI", "Hide town/city POI on continents")

    cy = OneWoW_GUI:CreateSection(container, { title = L["MAPWORLD_GROUP_BATTLE"] or "Battlefield minimap", yOffset = cy })
    InlineCB("enhanceBattleMap", "MAPWORLD_ENHANCE_BATTLE_MAP", "Enhance battlefield map")
    InlineCB("unlockBattlefield", "MAPWORLD_UNLOCK_BATTLEFIELD", "Drag to move battlefield map")
    InlineCB("battleCenterOnPlayer", "MAPWORLD_BATTLE_CENTER", "Keep battlefield centered on player")

    if ns.ModuleRegistry:GetToggleValue("map_world_tools", "enhanceBattleMap") then
        local opLbl
        opLbl, cy = AddLabelIndented(container, cy,
            string.format("%s: %.0f%%", L["MAPWORLD_BATTLE_OPACITY"] or "Battlefield visibility", (s.battleMapOpacity or 1) * 100),
            "TEXT_SECONDARY")
        local opSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 10, maxVal = 100, step = 5,
            currentVal = math.floor((s.battleMapOpacity or 1) * 100),
            width = 240, fmt = "%d%%",
            onChange = function(val)
                s.battleMapOpacity = val / 100
                opLbl:SetText(string.format("%s: %.0f%%", L["MAPWORLD_BATTLE_OPACITY"] or "Battlefield visibility", val))
                if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshBattlefieldEnhance then
                    M.RefreshBattlefieldEnhance()
                end
            end,
        })
        opSlider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        cy = cy - SLIDER_HEIGHT

        local gLbl
        gLbl, cy = AddLabelIndented(container, cy,
            string.format("%s: %d", L["MAPWORLD_BATTLE_GROUP"] or "Group icons", s.battleGroupIconSize or 8),
            "TEXT_SECONDARY")
        local gSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 8, maxVal = 32, step = 1,
            currentVal = s.battleGroupIconSize or 8, width = 240, fmt = "%d",
            onChange = function(val)
                s.battleGroupIconSize = val
                gLbl:SetText(string.format("%s: %d", L["MAPWORLD_BATTLE_GROUP"] or "Group icons", val))
                if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshBattlefieldEnhance then
                    M.RefreshBattlefieldEnhance()
                end
            end,
        })
        gSlider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        cy = cy - SLIDER_HEIGHT

        local pLbl
        pLbl, cy = AddLabelIndented(container, cy,
            string.format("%s: %d", L["MAPWORLD_BATTLE_PLAYER"] or "Player arrow", s.battlePlayerArrowSize or 12),
            "TEXT_SECONDARY")
        local pSlider = OneWoW_GUI:CreateSlider(container, {
            minVal = 12, maxVal = 48, step = 1,
            currentVal = s.battlePlayerArrowSize or 12, width = 240, fmt = "%d",
            onChange = function(val)
                s.battlePlayerArrowSize = val
                pLbl:SetText(string.format("%s: %d", L["MAPWORLD_BATTLE_PLAYER"] or "Player arrow", val))
                if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshBattlefieldEnhance then
                    M.RefreshBattlefieldEnhance()
                end
            end,
        })
        pSlider:SetPoint("TOPLEFT", container, "TOPLEFT", INDENT_SLIDER, cy)
        cy = cy - SLIDER_HEIGHT
        cy = cy - 4
    end

    cy = OneWoW_GUI:CreateSection(container, { title = L["MAPWORLD_GROUP_POLISH"] or "Polish", yOffset = cy })
    InlineCB("tintMenuShortcut", "MAPWORLD_TINT_MENU", "World map menu tint toggle")

    cy = OneWoW_GUI:CreateSection(container, { title = L["MAPWORLD_GROUP_CANVAS"] or "Map Overlay", yOffset = cy })

    InlineCB("canvasTint", "MAPWORLD_CANVAS_TINT", "Full Map Color Overlay")

    if ns.ModuleRegistry:GetToggleValue("map_world_tools", "canvasTint") then
        for _, col in ipairs({
            { idx = "canvasR", key = "MAPWORLD_RED", fb = "Red" },
            { idx = "canvasG", key = "MAPWORLD_GREEN", fb = "Green" },
            { idx = "canvasB", key = "MAPWORLD_BLUE", fb = "Blue" },
        }) do
            local lbl
            lbl, cy = AddLabelIndented(container, cy,
                string.format("%s: %d", L[col.key] or col.fb, s[col.idx]),
                "TEXT_SECONDARY")
            local slider = OneWoW_GUI:CreateSlider(container, {
                minVal = 0, maxVal = 255, step = 1,
                currentVal = s[col.idx], width = 240, fmt = "%d",
                onChange = function(val)
                    s[col.idx] = val
                    lbl:SetText(string.format("%s: %d", L[col.key] or col.fb, val))
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
