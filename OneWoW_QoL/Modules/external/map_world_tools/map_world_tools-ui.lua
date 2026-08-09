local _, ns = ...

local MapWorldToolsModule, L = ns.ModuleRegistry:Current()
local M = MapWorldToolsModule

local OneWoW_GUI = OneWoW_GUI

local ROW_HEIGHT    = 28
local SLIDER_HEIGHT = 42
local INDENT_LABEL  = 24
local INDENT_SLIDER = 36

-- Session-only collapse memory (survives tab switches; cleared on /reload)
local collapsedCards = {}

local function AddLabelIndented(parent, cy, text, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT_LABEL, cy)
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor(color or "TEXT_SECONDARY"))
    return fs, cy - fs:GetStringHeight() - 4
end

local function BuildContent(container, onRelayout)
    local s = M.GetSettings()

    local stack = OneWoW_GUI:CreateCardStack(container, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })
    if onRelayout then
        stack.OnRelayout = onRelayout
    end

    local function InlineCB(parent, cy, id, labelKey)
        local cb = OneWoW_GUI:CreateCheckbox(parent, {
            label   = L[labelKey],
            checked = ns.ModuleRegistry:GetToggleValue("map_world_tools", id),
            onClick = function(self)
                ns.ModuleRegistry:SetToggleValue("map_world_tools", id, self:GetChecked())
            end,
        })
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, cy)
        return cy - ROW_HEIGHT
    end

    stack:AddCard("explore", L["MAPWORLD_GROUP_EXPLORE"], function(content, _)
        local cy = 0
        cy = InlineCB(content, cy, "revealMap", "MAPWORLD_REVEAL_MAP")
        cy = InlineCB(content, cy, "tintUnexplored", "MAPWORLD_TINT_UNEXPLORED")

        if ns.ModuleRegistry:GetToggleValue("map_world_tools", "tintUnexplored") then
            local unexCols = {
                { idx = "unexploredTintR", key = "MAPWORLD_UNEX_R", fb = "Red" },
                { idx = "unexploredTintG", key = "MAPWORLD_UNEX_G", fb = "Green" },
                { idx = "unexploredTintB", key = "MAPWORLD_UNEX_B", fb = "Blue" },
            }
            for _, col in ipairs(unexCols) do
                local lbl
                lbl, cy = AddLabelIndented(content, cy,
                    string.format("%s: %d", L[col.key], s[col.idx] or 255),
                    "TEXT_SECONDARY")
                local slider = OneWoW_GUI:CreateSlider(content, {
                    minVal = 0, maxVal = 255, step = 1,
                    currentVal = s[col.idx] or 255, width = 240, fmt = "%d",
                    onChange = function(val)
                        s[col.idx] = val
                        lbl:SetText(string.format("%s: %d", L[col.key], val))
                        if ns.ModuleRegistry:IsEnabled("map_world_tools") then
                            if M.RefreshExploreTint then M.RefreshExploreTint() end
                            if M.RefreshFogAppearance then M.RefreshFogAppearance() end
                        end
                    end,
                })
                slider:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
                cy = cy - SLIDER_HEIGHT
            end
            local aLbl
            aLbl, cy = AddLabelIndented(content, cy,
                string.format("%s: %.0f%%", L["MAPWORLD_UNEX_A"], (s.unexploredTintA or 1) * 100),
                "TEXT_SECONDARY")
            local aSlider = OneWoW_GUI:CreateSlider(content, {
                minVal = 10, maxVal = 100, step = 5,
                currentVal = math.floor((s.unexploredTintA or 1) * 100),
                width = 240, fmt = "%d%%",
                onChange = function(val)
                    s.unexploredTintA = val / 100
                    aLbl:SetText(string.format("%s: %.0f%%", L["MAPWORLD_UNEX_A"], val))
                    if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshExploreTint then
                        M.RefreshExploreTint()
                    end
                end,
            })
            aSlider:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
            cy = cy - SLIDER_HEIGHT
            cy = cy - 4
        end

        return math.max(1, math.abs(cy))
    end)

    stack:AddCard("fogoverlay", L["MAPWORLD_GROUP_FOGOVERLAY"], function(content, _)
        local cy = 0
        cy = InlineCB(content, cy, "removeBattleFog", "MAPWORLD_REMOVE_FOG")
        cy = InlineCB(content, cy, "fogTint", "MAPWORLD_FOG_TINT")

        if ns.ModuleRegistry:GetToggleValue("map_world_tools", "fogTint") then
            for _, col in ipairs({
                { idx = "fogTintR", key = "MAPWORLD_RED", fb = "Red" },
                { idx = "fogTintG", key = "MAPWORLD_GREEN", fb = "Green" },
                { idx = "fogTintB", key = "MAPWORLD_BLUE", fb = "Blue" },
            }) do
                local lbl
                lbl, cy = AddLabelIndented(content, cy,
                    string.format("%s: %d", L[col.key], s[col.idx]),
                    "TEXT_SECONDARY")
                local slider = OneWoW_GUI:CreateSlider(content, {
                    minVal = 0, maxVal = 255, step = 1,
                    currentVal = s[col.idx], width = 240, fmt = "%d",
                    onChange = function(val)
                        s[col.idx] = val
                        lbl:SetText(string.format("%s: %d", L[col.key], val))
                        if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshFogAppearance then
                            M.RefreshFogAppearance()
                        end
                    end,
                })
                slider:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
                cy = cy - SLIDER_HEIGHT
            end
            cy = cy - 4
        end

        return math.max(1, math.abs(cy))
    end)

    stack:AddCard("frame", L["MAPWORLD_GROUP_FRAME"], function(content, _)
        local cy = 0
        cy = InlineCB(content, cy, "clearBlackout", "MAPWORLD_CLEAR_BLACKOUT")
        return math.max(1, math.abs(cy))
    end)

    stack:AddCard("comfort", L["MAPWORLD_GROUP_COMFORT"], function(content, _)
        local cy = 0
        cy = InlineCB(content, cy, "noMapFade", "MAPWORLD_NO_MAP_FADE")
        cy = InlineCB(content, cy, "noMapEmote", "MAPWORLD_NO_MAP_EMOTE")
        return math.max(1, math.abs(cy))
    end)

    stack:AddCard("cleanup", L["MAPWORLD_GROUP_CLEANUP"], function(content, _)
        local cy = 0
        cy = InlineCB(content, cy, "hideFilterReset", "MAPWORLD_HIDE_FILTER_RESET")
        cy = InlineCB(content, cy, "hideMapTutorial", "MAPWORLD_HIDE_MAP_TUTORIAL")
        return math.max(1, math.abs(cy))
    end)

    stack:AddCard("coords", L["MAPWORLD_GROUP_COORDS"], function(content, _)
        local cy = 0
        cy = InlineCB(content, cy, "showCoords", "MAPWORLD_SHOW_COORDS")
        cy = InlineCB(content, cy, "coordsLargeFont", "MAPWORLD_COORDS_LARGE")
        cy = InlineCB(content, cy, "coordsBackground", "MAPWORLD_COORDS_BG")
        return math.max(1, math.abs(cy))
    end)

    stack:AddCard("poi", L["MAPWORLD_GROUP_POI"], function(content, _)
        local cy = 0
        cy = InlineCB(content, cy, "hideContinentPoi", "MAPWORLD_HIDE_CONTINENT_POI")
        return math.max(1, math.abs(cy))
    end)

    stack:AddCard("battle", L["MAPWORLD_GROUP_BATTLE"], function(content, _)
        local cy = 0
        cy = InlineCB(content, cy, "enhanceBattleMap", "MAPWORLD_ENHANCE_BATTLE_MAP")
        cy = InlineCB(content, cy, "unlockBattlefield", "MAPWORLD_UNLOCK_BATTLEFIELD")
        cy = InlineCB(content, cy, "battleCenterOnPlayer", "MAPWORLD_BATTLE_CENTER")

        if ns.ModuleRegistry:GetToggleValue("map_world_tools", "enhanceBattleMap") then
            local opLbl
            opLbl, cy = AddLabelIndented(content, cy,
                string.format("%s: %.0f%%", L["MAPWORLD_BATTLE_OPACITY"], (s.battleMapOpacity or 1) * 100),
                "TEXT_SECONDARY")
            local opSlider = OneWoW_GUI:CreateSlider(content, {
                minVal = 10, maxVal = 100, step = 5,
                currentVal = math.floor((s.battleMapOpacity or 1) * 100),
                width = 240, fmt = "%d%%",
                onChange = function(val)
                    s.battleMapOpacity = val / 100
                    opLbl:SetText(string.format("%s: %.0f%%", L["MAPWORLD_BATTLE_OPACITY"], val))
                    if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshBattlefieldEnhance then
                        M.RefreshBattlefieldEnhance()
                    end
                end,
            })
            opSlider:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
            cy = cy - SLIDER_HEIGHT

            local gLbl
            gLbl, cy = AddLabelIndented(content, cy,
                string.format("%s: %d", L["MAPWORLD_BATTLE_GROUP"], s.battleGroupIconSize or 8),
                "TEXT_SECONDARY")
            local gSlider = OneWoW_GUI:CreateSlider(content, {
                minVal = 8, maxVal = 32, step = 1,
                currentVal = s.battleGroupIconSize or 8, width = 240, fmt = "%d",
                onChange = function(val)
                    s.battleGroupIconSize = val
                    gLbl:SetText(string.format("%s: %d", L["MAPWORLD_BATTLE_GROUP"], val))
                    if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshBattlefieldEnhance then
                        M.RefreshBattlefieldEnhance()
                    end
                end,
            })
            gSlider:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
            cy = cy - SLIDER_HEIGHT

            local pLbl
            pLbl, cy = AddLabelIndented(content, cy,
                string.format("%s: %d", L["MAPWORLD_BATTLE_PLAYER"], s.battlePlayerArrowSize or 12),
                "TEXT_SECONDARY")
            local pSlider = OneWoW_GUI:CreateSlider(content, {
                minVal = 12, maxVal = 48, step = 1,
                currentVal = s.battlePlayerArrowSize or 12, width = 240, fmt = "%d",
                onChange = function(val)
                    s.battlePlayerArrowSize = val
                    pLbl:SetText(string.format("%s: %d", L["MAPWORLD_BATTLE_PLAYER"], val))
                    if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshBattlefieldEnhance then
                        M.RefreshBattlefieldEnhance()
                    end
                end,
            })
            pSlider:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
            cy = cy - SLIDER_HEIGHT
            cy = cy - 4
        end

        return math.max(1, math.abs(cy))
    end)

    stack:AddCard("polish", L["MAPWORLD_GROUP_POLISH"], function(content, _)
        local cy = 0
        cy = InlineCB(content, cy, "tintMenuShortcut", "MAPWORLD_TINT_MENU")
        return math.max(1, math.abs(cy))
    end)

    stack:AddCard("canvas", L["MAPWORLD_GROUP_CANVAS"], function(content, _)
        local cy = 0
        cy = InlineCB(content, cy, "canvasTint", "MAPWORLD_CANVAS_TINT")

        if ns.ModuleRegistry:GetToggleValue("map_world_tools", "canvasTint") then
            for _, col in ipairs({
                { idx = "canvasR", key = "MAPWORLD_RED", fb = "Red" },
                { idx = "canvasG", key = "MAPWORLD_GREEN", fb = "Green" },
                { idx = "canvasB", key = "MAPWORLD_BLUE", fb = "Blue" },
            }) do
                local lbl
                lbl, cy = AddLabelIndented(content, cy,
                    string.format("%s: %d", L[col.key], s[col.idx]),
                    "TEXT_SECONDARY")
                local slider = OneWoW_GUI:CreateSlider(content, {
                    minVal = 0, maxVal = 255, step = 1,
                    currentVal = s[col.idx], width = 240, fmt = "%d",
                    onChange = function(val)
                        s[col.idx] = val
                        lbl:SetText(string.format("%s: %d", L[col.key], val))
                        if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshCanvasOverlay then
                            M.RefreshCanvasOverlay()
                        end
                    end,
                })
                slider:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
                cy = cy - SLIDER_HEIGHT
            end

            local alphaLbl
            alphaLbl, cy = AddLabelIndented(content, cy,
                string.format("%s: %.0f%%", OPACITY, s.canvasA * 100),
                "TEXT_SECONDARY")

            local alphaSlider = OneWoW_GUI:CreateSlider(content, {
                minVal = 0, maxVal = 100, step = 5,
                currentVal = math.floor(s.canvasA * 100),
                width = 240, fmt = "%d%%",
                onChange = function(val)
                    s.canvasA = val / 100
                    alphaLbl:SetText(string.format("%s: %.0f%%", OPACITY, val))
                    if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshCanvasOverlay then
                        M.RefreshCanvasOverlay()
                    end
                end,
            })
            alphaSlider:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
            cy = cy - SLIDER_HEIGHT
        end

        return math.max(1, math.abs(cy))
    end)

    stack:AddCard("map", L["MAPWORLD_GROUP_MAP"], function(content, _)
        local cy = 0
        cy = InlineCB(content, cy, "useMapFrameAlpha", "MAPWORLD_MAP_ALPHA")

        if ns.ModuleRegistry:GetToggleValue("map_world_tools", "useMapFrameAlpha") then
            local mapAlphaLbl
            mapAlphaLbl, cy = AddLabelIndented(content, cy,
                string.format("%s: %.0f%%", L["MAPWORLD_MAP_ALPHA_SLIDER"], (s.mapFrameAlpha or 1) * 100),
                "TEXT_SECONDARY")

            local mapAlphaSlider = OneWoW_GUI:CreateSlider(content, {
                minVal = 10, maxVal = 100, step = 5,
                currentVal = math.floor((s.mapFrameAlpha or 1) * 100),
                width = 240, fmt = "%d%%",
                onChange = function(val)
                    s.mapFrameAlpha = val / 100
                    mapAlphaLbl:SetText(string.format("%s: %.0f%%", L["MAPWORLD_MAP_ALPHA_SLIDER"], val))
                    if ns.ModuleRegistry:IsEnabled("map_world_tools") and M.RefreshMapFrameAlpha then
                        M.RefreshMapFrameAlpha()
                    end
                end,
            })
            mapAlphaSlider:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SLIDER, cy)
            cy = cy - SLIDER_HEIGHT
            cy = cy - 4
        end

        return math.max(1, math.abs(cy))
    end)

    stack:Finish()
    return -container:GetHeight()
end

function M:CreateCustomDetail(detailScrollChild, yOffset, _)
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

    local function updateDetailHeight()
        detailScrollChild:SetHeight(math.abs(capturedYOffset) + (container:GetHeight() or 0) + 20)
        if detailScrollChild.updateThumb then
            detailScrollChild.updateThumb()
        end
    end

    self._refreshCustomDetail = function()
        OneWoW_GUI:ClearFrame(container)
        local cy = BuildContent(container, updateDetailHeight)
        detailScrollChild:SetHeight(math.abs(capturedYOffset) + math.abs(cy) + 20)
        if detailScrollChild.updateThumb then
            detailScrollChild.updateThumb()
        end
    end

    local cy = BuildContent(container, updateDetailHeight)

    return yOffset + cy
end
