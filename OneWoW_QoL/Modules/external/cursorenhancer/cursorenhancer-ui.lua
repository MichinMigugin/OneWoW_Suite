-- ============================================================================
-- Cursor Enhancer — options UI (global look + situation cards)
-- ============================================================================

local _, ns = ...
local CursorEnhancerModule, L = ns.ModuleRegistry:Current()
if not CursorEnhancerModule then return end

local OneWoW_GUI = OneWoW_GUI
local Situations = CursorEnhancerModule.Situations
local floor = math.floor
local tinsert, tremove = tinsert, tremove
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local ipairs, type = ipairs, type
local wipe = wipe

-- Session-only collapse memory (survives tab switches; cleared on /reload)
local collapsedCards = {}

local PLACE_ORDER = {
    "everywhere", "open_world", "any_instance",
    "dungeon", "mythic_plus", "raid", "scenario", "arena", "battleground",
}
local PLACE_LABEL = {
    everywhere   = "CURSORENHANCER_PLACE_EVERYWHERE",
    open_world   = "CURSORENHANCER_PLACE_OPEN_WORLD",
    any_instance = "CURSORENHANCER_PLACE_ANY_INSTANCE",
    dungeon      = "CURSORENHANCER_PLACE_DUNGEON",
    mythic_plus  = "CURSORENHANCER_PLACE_MYTHIC_PLUS",
    raid         = "CURSORENHANCER_PLACE_RAID",
    scenario     = "CURSORENHANCER_PLACE_SCENARIO",
    arena        = "CURSORENHANCER_PLACE_ARENA",
    battleground = "CURSORENHANCER_PLACE_BATTLEGROUND",
}

local COMBAT_ORDER = { "either", "in", "out" }
local COMBAT_LABEL = {
    either = "CURSORENHANCER_COMBAT_EITHER",
    ["in"] = "CURSORENHANCER_COMBAT_IN",
    ["out"] = "CURSORENHANCER_COMBAT_OUT",
}

local THING_LABEL = {
    outerRing    = "CURSORENHANCER_THING_OUTER",
    middleRing   = "CURSORENHANCER_THING_MIDDLE",
    centerMarker = "CURSORENHANCER_THING_MARKER",
    trail        = "CURSORENHANCER_THING_TRAIL",
    gcd          = "CURSORENHANCER_SECTION_GCD",
    cast         = "CURSORENHANCER_SECTION_CAST",
    middleSwipe  = "CURSORENHANCER_GCD_MIDDLE",
    outerSwipe   = "CURSORENHANCER_CAST_OUTER",
    pips         = "CURSORENHANCER_THING_PIPS",
}

-- Collapsed summary / UI order (matches Global Look sections).
local DISPLAY_KEYS = {
    "outerRing", "middleRing", "centerMarker", "trail",
    "middleSwipe", "outerSwipe", "pips", "gcd", "cast",
}

local MARKER_ORDER = { "Dot", "Star", "Cross", "Diamond", "Ring", "None" }
local MARKER_LABEL = {
    Dot = "CURSORENHANCER_MARKER_DOT", Star = "CURSORENHANCER_MARKER_STAR",
    Cross = "CURSORENHANCER_MARKER_CROSS", Diamond = "CURSORENHANCER_MARKER_DIAMOND",
    Ring = "CURSORENHANCER_MARKER_RING",
}

local function AttachTooltip(frame, text)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

--- Dim + disable interactive widgets when a parent setting makes them unused
local function SetEnabled(widget, enabled)
    if not widget then return end
    local alpha = enabled and 1 or 0.4
    if widget.slider then
        if enabled then widget.slider:Enable() else widget.slider:Disable() end
        widget:SetAlpha(alpha)
        if widget.valLabel then
            widget.valLabel:SetTextColor(OneWoW_GUI:GetThemeColor(enabled and "TEXT_PRIMARY" or "TEXT_MUTED"))
        end
        return
    end
    if widget.Enable and widget.Disable then
        if enabled then widget:Enable() else widget:Disable() end
    end
    widget:SetAlpha(alpha)
    if widget.label then
        widget.label:SetTextColor(OneWoW_GUI:GetThemeColor(enabled and "TEXT_PRIMARY" or "TEXT_MUTED"))
    end
end

local function SetLabeledEnabled(label, control, enabled)
    if label then
        label:SetTextColor(OneWoW_GUI:GetThemeColor(enabled and "TEXT_PRIMARY" or "TEXT_MUTED"))
        label:SetAlpha(enabled and 1 or 0.4)
    end
    SetEnabled(control, enabled)
end

local function PlaceItems()
    local items = {}
    for _, key in ipairs(PLACE_ORDER) do
        items[#items + 1] = { value = key, text = L[PLACE_LABEL[key]] }
    end
    return items
end

local function CombatItems()
    local items = {}
    for _, key in ipairs(COMBAT_ORDER) do
        items[#items + 1] = { value = key, text = L[COMBAT_LABEL[key]] }
    end
    return items
end

local function MarkerItems()
    local items = {}
    for _, key in ipairs(MARKER_ORDER) do
        local text = key == "None" and NONE or L[MARKER_LABEL[key]]
        items[#items + 1] = { value = key, text = text }
    end
    return items
end

local function MarkerLabel(v)
    if v == "None" then return NONE end
    return L[MARKER_LABEL[v] or "CURSORENHANCER_MARKER_DOT"]
end

local function TrailStyleItems()
    return {
        { value = "ring",  text = L["CURSORENHANCER_TRAIL_STYLE_RING"] },
        { value = "glow",  text = L["CURSORENHANCER_TRAIL_STYLE_GLOW"] },
        { value = "spark", text = L["CURSORENHANCER_TRAIL_STYLE_SPARK"] },
    }
end

local function TrailStyleLabel(v)
    if v == "glow" then return L["CURSORENHANCER_TRAIL_STYLE_GLOW"] end
    if v == "spark" then return L["CURSORENHANCER_TRAIL_STYLE_SPARK"] end
    return L["CURSORENHANCER_TRAIL_STYLE_RING"]
end

local function RingTexItems()
    return {
        { value = "c1", text = L["CURSORENHANCER_TEX_C1"] },
        { value = "c2", text = L["CURSORENHANCER_TEX_C2"] },
    }
end

local function RingTexLabel(v)
    return v == "c2" and L["CURSORENHANCER_TEX_C2"] or L["CURSORENHANCER_TEX_C1"]
end

local function ShowSummary(sit)
    local parts = {}
    for _, key in ipairs(DISPLAY_KEYS) do
        if sit.show and sit.show[key] then
            parts[#parts + 1] = L[THING_LABEL[key]] or key
        end
    end
    if #parts == 0 then return L["CURSORENHANCER_SHOW_NONE"] end
    return table.concat(parts, ", ")
end

local function MenuTipEnter(text)
    return function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end
end

local function MenuTipLeave()
    return function()
        GameTooltip:Hide()
    end
end

local function PieceMode(sit, thingKey)
    if not sit.show or sit.show[thingKey] ~= true then return "off" end
    if type(sit.overrides) == "table" and sit.overrides[thingKey] ~= nil then return "custom" end
    return "on"
end

local function PieceModeLabel(mode)
    if mode == "custom" then return L["CURSORENHANCER_MODE_CUSTOM"] end
    if mode == "on" then return L["CURSORENHANCER_MODE_ON"] end
    return L["CURSORENHANCER_MODE_OFF"]
end

local function PieceModeItems()
    return {
        {
            value = "off", text = L["CURSORENHANCER_MODE_OFF"],
            onEnter = MenuTipEnter(L["CURSORENHANCER_MODE_OFF_TIP"]),
            onLeave = MenuTipLeave(),
        },
        {
            value = "on", text = L["CURSORENHANCER_MODE_ON"],
            onEnter = MenuTipEnter(L["CURSORENHANCER_MODE_ON_TIP"]),
            onLeave = MenuTipLeave(),
        },
        {
            value = "custom", text = L["CURSORENHANCER_MODE_CUSTOM"],
            onEnter = MenuTipEnter(L["CURSORENHANCER_MODE_CUSTOM_TIP"]),
            onLeave = MenuTipLeave(),
        },
    }
end

local function LookModeLabel(custom)
    return custom and L["CURSORENHANCER_MODE_CUSTOM"] or L["CURSORENHANCER_MODE_USE_GLOBAL"]
end

local function LookModeItems()
    return {
        {
            value = "global", text = L["CURSORENHANCER_MODE_USE_GLOBAL"],
            onEnter = MenuTipEnter(L["CURSORENHANCER_MODE_USE_GLOBAL_TIP"]),
            onLeave = MenuTipLeave(),
        },
        {
            value = "custom", text = L["CURSORENHANCER_MODE_CUSTOM"],
            onEnter = MenuTipEnter(L["CURSORENHANCER_MODE_LOOK_CUSTOM_TIP"]),
            onLeave = MenuTipLeave(),
        },
    }
end

function CursorEnhancerModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled, registerRefresh)
    local s = CursorEnhancerModule.CE:GetSettings()
    local labelColor = isEnabled and "TEXT_PRIMARY" or "TEXT_MUTED"
    local situationRows = {}
    local situationsHost
    local reorderCtrl
    local rebuildSituations
    local ROW_GAP = 6
    local cardStack

    --- Vertical stack of controls parented to `host`, advancing local `y`.
    local function NewStack(host, startY, xBase)
        local y = startY
        local x0 = xBase or 0
        local stack = {}

        function stack:GetY()
            return y
        end

        function stack:Label(text, x, colorKey)
            local fs = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetPoint("TOPLEFT", host, "TOPLEFT", x or x0, y)
            fs:SetText(text)
            fs:SetTextColor(OneWoW_GUI:GetThemeColor(colorKey or labelColor))
            y = y - fs:GetStringHeight() - 4
            return fs
        end

        function stack:Slider(labelText, minV, maxV, step, cur, fmt, onChange)
            local lbl = self:Label(labelText, x0)
            local sl = OneWoW_GUI:CreateSlider(host, {
                minVal = minV, maxVal = maxV, step = step, currentVal = cur,
                width = 240, fmt = fmt, onChange = onChange,
            })
            sl:SetPoint("TOPLEFT", host, "TOPLEFT", x0 + 12, y)
            y = y - 42 - ROW_GAP
            return lbl, sl
        end

        function stack:Checkbox(labelText, checked, onClick, tooltip, x)
            local cb = OneWoW_GUI:CreateCheckbox(host, {
                label = labelText, checked = checked, onClick = onClick,
            })
            cb:SetPoint("TOPLEFT", host, "TOPLEFT", x or x0, y)
            if tooltip then AttachTooltip(cb, tooltip) end
            y = y - 32
            return cb
        end

        function stack:Dropdown(labelText, curText, buildItems, getActive, onSelect)
            local lbl = self:Label(labelText, x0)
            local dd, ddText = OneWoW_GUI:CreateDropdown(host, {
                width = 200, height = 22, text = curText,
            })
            dd:SetPoint("TOPLEFT", host, "TOPLEFT", x0 + 12, y)
            OneWoW_GUI:AttachFilterMenu(dd, {
                searchable = false,
                getActiveValue = getActive,
                buildItems = buildItems,
                onSelect = function(value, text)
                    ddText:SetText(text)
                    onSelect(value)
                end,
            })
            y = y - 30 - ROW_GAP
            return lbl, dd
        end

        --- Color label with swatch immediately to its right (not panel far-right).
        function stack:Color(labelText, colorTbl, apply)
            local rowTop = y
            local lbl = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("TOPLEFT", host, "TOPLEFT", x0, rowTop - 4)
            lbl:SetText(labelText)
            lbl:SetTextColor(OneWoW_GUI:GetThemeColor(labelColor))
            local swatch = OneWoW_GUI:CreateColorSwatch(host, {
                size = 22,
                getColor = function()
                    return colorTbl[1] or 1, colorTbl[2] or 1, colorTbl[3] or 1
                end,
                onColorChanged = function(r, g, b)
                    colorTbl[1], colorTbl[2], colorTbl[3] = r, g, b
                    apply()
                end,
            })
            swatch:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
            y = y - 30 - ROW_GAP
            return lbl, swatch
        end

        --- Dropdown without a preceding label (group title supplies context).
        function stack:BareDropdown(curText, buildItems, getActive, onSelect, width)
            local dd, ddText = OneWoW_GUI:CreateDropdown(host, {
                width = width or 160, height = 22, text = curText,
            })
            dd:SetPoint("TOPLEFT", host, "TOPLEFT", x0, y)
            OneWoW_GUI:AttachFilterMenu(dd, {
                searchable = false,
                getActiveValue = getActive,
                buildItems = buildItems,
                onSelect = function(value, text)
                    ddText:SetText(text)
                    onSelect(value)
                end,
            })
            y = y - 30 - ROW_GAP
            return dd
        end

        return stack
    end

    --- Inline look editors bound to a situation override snapshot (not global profile).
    local function RenderThingOverrideEditors(stack, thingKey, ov, apply)
        if thingKey == "outerRing" then
            ov.color = ov.color or { 1, 1, 1 }
            local colorLbl, colorSwatch = stack:Color(COLOR, ov.color, apply)
            local classCb = stack:Checkbox(L["CURSORENHANCER_USE_CLASS_COLOR"], ov.classColor == true,
                function(myself)
                    ov.classColor = myself:GetChecked()
                    SetLabeledEnabled(colorLbl, colorSwatch, not myself:GetChecked())
                    apply()
                end, L["CURSORENHANCER_USE_CLASS_COLOR_TIP"], 22)
            SetLabeledEnabled(colorLbl, colorSwatch, not classCb:GetChecked())

        elseif thingKey == "middleRing" then
            ov.color = ov.color or { 1, 1, 1 }
            stack:Color(COLOR, ov.color, apply)

        elseif thingKey == "centerMarker" then
            local colorLbl, colorSwatch
            stack:Dropdown(L["CURSORENHANCER_CENTER_MARKER_STYLE"],
                MarkerLabel(ov.style or "Dot"), MarkerItems,
                function() return ov.style or "Dot" end,
                function(value)
                    ov.style = value
                    SetLabeledEnabled(colorLbl, colorSwatch, value ~= "None")
                    apply()
                end)
            ov.color = ov.color or { 1, 1, 1 }
            colorLbl, colorSwatch = stack:Color(COLOR, ov.color, apply)
            SetLabeledEnabled(colorLbl, colorSwatch, (ov.style or "Dot") ~= "None")

        elseif thingKey == "trail" then
            stack:Dropdown(L["CURSORENHANCER_TRAIL_STYLE"], TrailStyleLabel(ov.style or "ring"), TrailStyleItems,
                function() return ov.style or "ring" end,
                function(value) ov.style = value; apply() end)
            stack:Slider(L["CURSORENHANCER_TRAIL_SIZE"], 8, 96, 1, ov.size or 36, "%d",
                function(val) ov.size = val; apply() end)
            stack:Slider(L["CURSORENHANCER_TRAIL_FADE"], 0.2, 2.0, 0.1, ov.fadeTime or 0.6, "%.1f",
                function(val) ov.fadeTime = val; apply() end)
            ov.color = ov.color or { 1, 1, 1 }
            stack:Color(COLOR, ov.color, apply)

        elseif thingKey == "pips" then
            ov.color = ov.color or { 1, 1, 1 }
            stack:Slider(L["CURSORENHANCER_PIP_SIZE"], 12, 64, 1, ov.size or 28, "%d",
                function(val) ov.size = val; apply() end)
            stack:Slider(L["CURSORENHANCER_PIP_OFFSET_X"], -80, 80, 1, ov.offsetX or 0, "%d",
                function(val) ov.offsetX = val; apply() end)
            stack:Slider(L["CURSORENHANCER_PIP_OFFSET_Y"], -80, 80, 1, ov.offsetY or 0, "%d",
                function(val) ov.offsetY = val; apply() end)
            local colorLbl, colorSwatch = stack:Color(COLOR, ov.color, apply)
            local classCb = stack:Checkbox(L["CURSORENHANCER_USE_CLASS_COLOR"], ov.classColor == true,
                function(myself)
                    ov.classColor = myself:GetChecked()
                    SetLabeledEnabled(colorLbl, colorSwatch, not myself:GetChecked())
                    apply()
                end, L["CURSORENHANCER_USE_CLASS_COLOR_TIP"], 22)
            SetLabeledEnabled(colorLbl, colorSwatch, not classCb:GetChecked())
            stack:Checkbox(L["CURSORENHANCER_PIP_FILL_LTR"], ov.fillLtr ~= false, function(myself)
                ov.fillLtr = myself:GetChecked()
                apply()
            end, L["CURSORENHANCER_PIP_FILL_LTR_TIP"])

        elseif thingKey == "gcd" or thingKey == "cast" then
            -- Look only; show checkbox owns presence (Resolve sets enabled from show.*).
            local hasSpark = thingKey == "cast"
            ov.color = ov.color or { 1, 1, 1 }
            stack:Dropdown(L["CURSORENHANCER_RING_TEXTURE"], RingTexLabel(ov.ringTex or "c1"), RingTexItems,
                function() return ov.ringTex or "c1" end,
                function(value) ov.ringTex = value; apply() end)
            stack:Slider(L["CURSORENHANCER_RADIUS"], 8, 80, 1, ov.radius or 21, "%d",
                function(val) ov.radius = val; apply() end)
            stack:Slider(OPACITY, 0, 100, 5, floor((ov.alpha or 0.8) * 100 + 0.5), "%d%%",
                function(val) ov.alpha = val / 100; apply() end)
            stack:Checkbox(L["CURSORENHANCER_ATTACH"], ov.attached ~= false, function(myself)
                ov.attached = myself:GetChecked(); apply()
            end)
            if hasSpark then
                stack:Checkbox(L["CURSORENHANCER_SHOW_SPARK"], ov.sparkEnabled ~= false, function(myself)
                    ov.sparkEnabled = myself:GetChecked(); apply()
                end)
            end
            local colorLbl, colorSwatch = stack:Color(COLOR, ov.color, apply)
            local classCb = stack:Checkbox(L["CURSORENHANCER_USE_CLASS_COLOR"], ov.useClassColor == true,
                function(myself)
                    ov.useClassColor = myself:GetChecked()
                    SetLabeledEnabled(colorLbl, colorSwatch, not myself:GetChecked())
                    apply()
                end, L["CURSORENHANCER_USE_CLASS_COLOR_TIP"], 22)
            SetLabeledEnabled(colorLbl, colorSwatch, not classCb:GetChecked())

        elseif thingKey == "middleSwipe" or thingKey == "outerSwipe" then
            stack:Checkbox(L["CURSORENHANCER_SWIPE_FILL"], ov.fill == true, function(myself)
                ov.fill = myself:GetChecked(); apply()
            end)
        end
    end

    --- Soft inset card for a look group inside CardStack card content.
    --- finish() returns the next outer Y below the group.
    local function BeginGroup(host, outerY, titleText)
        outerY = outerY - 8
        local card = OneWoW_GUI:CreateFrame(host, {
            backdrop = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS,
            bgColor = "BG_TERTIARY",
            borderColor = "BORDER_SUBTLE",
            height = 40,
        })
        card:SetPoint("TOPLEFT", host, "TOPLEFT", 0, outerY)
        card:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, outerY)

        local pad = 10
        local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("TOPLEFT", card, "TOPLEFT", pad, -pad)
        title:SetText(titleText)
        title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local stack = NewStack(card, -pad - title:GetStringHeight() - 8, pad)

        local function Finish()
            local h = -stack:GetY() + pad
            card:SetHeight(h)
            return outerY - h - 8
        end

        return stack, Finish
    end

    local cardsHost = CreateFrame("Frame", nil, detailScrollChild)
    cardsHost:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
    cardsHost:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)

    cardStack = OneWoW_GUI:CreateCardStack(cardsHost, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })

    local function UpdateDetailHeight()
        local top = detailScrollChild:GetTop()
        local bottom = cardsHost:GetBottom()
        if top and bottom then
            detailScrollChild:SetHeight((top - bottom) + 24)
        else
            detailScrollChild:SetHeight(math.abs(yOffset) + cardsHost:GetHeight() + 20)
        end
    end
    cardStack.OnRelayout = UpdateDetailHeight

    -- ─── Global look / feel ──────────────────────────────────────────────────
    cardStack:AddCard("cursorenhancer:global", L["CURSORENHANCER_SECTION_GLOBAL"], function(content, _)
        local root = NewStack(content, 0, 0)

        root:Slider(L["CURSORENHANCER_RING_SIZE"], 40, 200, 1, s.ringSize or 90, "%d",
            function(val) s.ringSize = val; CursorEnhancerModule.CE:ApplyAll() end)
        root:Slider(L["CURSORENHANCER_OFFSET_X"], -200, 200, 1, s.offsetX or 0, "%d",
            function(val) s.offsetX = val; CursorEnhancerModule.CE:ApplyAll() end)
        root:Slider(L["CURSORENHANCER_OFFSET_Y"], -200, 200, 1, s.offsetY or 0, "%d",
            function(val) s.offsetY = val; CursorEnhancerModule.CE:ApplyAll() end)
        root:Slider(L["CURSORENHANCER_BASE_ALPHA"], 0, 100, 5,
            floor((s.alpha or 1) * 100 + 0.5), "%d%%",
            function(val) s.alpha = val / 100; CursorEnhancerModule.CE:ApplyAll() end)

        root:Checkbox(L["CURSORENHANCER_ONLY_MOUSELOOK"], s.onlyWhileMouseLook == true,
            function(myself)
                s.onlyWhileMouseLook = myself:GetChecked()
                CursorEnhancerModule.CE:ApplyAll()
            end, L["CURSORENHANCER_ONLY_MOUSELOOK_TIP"])

        local y = root:GetY()

        -- Outer Ring
        do
            local g, finish = BeginGroup(content, y, L["CURSORENHANCER_THING_OUTER"])
            local colorLbl, colorSwatch = g:Color(COLOR, s.outerRingColor,
                function() CursorEnhancerModule.CE:ApplyAll() end)
            local classCb = g:Checkbox(L["CURSORENHANCER_USE_CLASS_COLOR"], s.outerRingClassColor == true,
                function(myself)
                    s.outerRingClassColor = myself:GetChecked()
                    SetLabeledEnabled(colorLbl, colorSwatch, not myself:GetChecked())
                    CursorEnhancerModule.CE:ApplyAll()
                end, L["CURSORENHANCER_USE_CLASS_COLOR_TIP"], 22)
            SetLabeledEnabled(colorLbl, colorSwatch, not classCb:GetChecked())
            y = finish()
        end

        -- Middle Ring
        do
            local g, finish = BeginGroup(content, y, L["CURSORENHANCER_THING_MIDDLE"])
            g:Color(COLOR, s.middleRingColor,
                function() CursorEnhancerModule.CE:ApplyAll() end)
            y = finish()
        end

        -- Center Marker
        do
            local g, finish = BeginGroup(content, y, L["CURSORENHANCER_THING_MARKER"])
            local colorLbl, colorSwatch
            g:Dropdown(L["CURSORENHANCER_CENTER_MARKER_STYLE"],
                MarkerLabel(s.centerMarker or "Dot"), MarkerItems,
                function() return s.centerMarker or "Dot" end,
                function(value)
                    s.centerMarker = value
                    SetLabeledEnabled(colorLbl, colorSwatch, value ~= "None")
                    CursorEnhancerModule.CE:ApplyAll()
                end)
            colorLbl, colorSwatch = g:Color(COLOR, s.centerMarkerColor,
                function() CursorEnhancerModule.CE:ApplyAll() end)
            SetLabeledEnabled(colorLbl, colorSwatch, (s.centerMarker or "Dot") ~= "None")
            y = finish()
        end

        -- Trail
        do
            local g, finish = BeginGroup(content, y, L["CURSORENHANCER_THING_TRAIL"])
            g:Dropdown(L["CURSORENHANCER_TRAIL_STYLE"], TrailStyleLabel(s.trailStyle or "ring"), TrailStyleItems,
                function() return s.trailStyle or "ring" end,
                function(value) s.trailStyle = value end)
            g:Slider(L["CURSORENHANCER_TRAIL_SIZE"], 8, 96, 1, s.trailSize or 36, "%d",
                function(val) s.trailSize = val end)
            g:Slider(L["CURSORENHANCER_TRAIL_FADE"], 0.2, 2.0, 0.1, s.trailFadeTime or 0.6, "%.1f",
                function(val) s.trailFadeTime = val end)
            g:Color(COLOR, s.trailColor,
                function() CursorEnhancerModule.CE:ApplyAll() end)
            y = finish()
        end

        return math.max(1, -y)
    end)

    -- ─── Swipes ──────────────────────────────────────────────────────────────
    cardStack:AddCard("cursorenhancer:swipes", L["CURSORENHANCER_SECTION_SWIPES"], function(content, _)
        local root = NewStack(content, 0, 0)
        local middleFillCb
        local middleSwipeCb = root:Checkbox(L["CURSORENHANCER_GCD_MIDDLE"], s.middleSwipe.enabled == true, function(myself)
            s.middleSwipe.enabled = myself:GetChecked()
            SetEnabled(middleFillCb, myself:GetChecked())
            CursorEnhancerModule.CE:ApplyAll()
        end)
        middleFillCb = root:Checkbox(L["CURSORENHANCER_SWIPE_FILL"], s.middleSwipe.fill == true, function(myself)
            s.middleSwipe.fill = myself:GetChecked(); CursorEnhancerModule.CE:ApplyAll()
        end, nil, 24)
        SetEnabled(middleFillCb, middleSwipeCb:GetChecked())

        local outerFillCb
        local outerSwipeCb = root:Checkbox(L["CURSORENHANCER_CAST_OUTER"], s.outerSwipe.enabled == true, function(myself)
            s.outerSwipe.enabled = myself:GetChecked()
            SetEnabled(outerFillCb, myself:GetChecked())
            CursorEnhancerModule.CE:ApplyAll()
        end)
        outerFillCb = root:Checkbox(L["CURSORENHANCER_SWIPE_FILL"], s.outerSwipe.fill == true, function(myself)
            s.outerSwipe.fill = myself:GetChecked(); CursorEnhancerModule.CE:ApplyAll()
        end, nil, 24)
        SetEnabled(outerFillCb, outerSwipeCb:GetChecked())

        return math.max(1, -root:GetY())
    end)

    -- ─── Pips ────────────────────────────────────────────────────────────────
    cardStack:AddCard("cursorenhancer:pips", L["CURSORENHANCER_SECTION_PIPS"], function(content, _)
        local root = NewStack(content, 0, 0)
        root:Checkbox(L["CURSORENHANCER_PIPS_ENABLE"], s.pipsEnabled == true, function(myself)
            s.pipsEnabled = myself:GetChecked(); CursorEnhancerModule.CE:ApplyAll()
        end, L["CURSORENHANCER_PIPS_ENABLE_TIP"])

        s.pipColor = s.pipColor or { 1, 1, 1 }
        root:Slider(L["CURSORENHANCER_PIP_SIZE"], 12, 64, 1, s.pipSize or 28, "%d",
            function(val) s.pipSize = val; CursorEnhancerModule.CE:ApplyAll() end)
        root:Slider(L["CURSORENHANCER_PIP_OFFSET_X"], -80, 80, 1, s.pipOffsetX or 0, "%d",
            function(val) s.pipOffsetX = val; CursorEnhancerModule.CE:ApplyAll() end)
        root:Slider(L["CURSORENHANCER_PIP_OFFSET_Y"], -80, 80, 1, s.pipOffsetY or 0, "%d",
            function(val) s.pipOffsetY = val; CursorEnhancerModule.CE:ApplyAll() end)

        local pipColorLbl, pipColorSwatch = root:Color(COLOR, s.pipColor,
            function() CursorEnhancerModule.CE:ApplyAll() end)
        local pipClassCb = root:Checkbox(L["CURSORENHANCER_USE_CLASS_COLOR"], s.pipClassColor == true,
            function(myself)
                s.pipClassColor = myself:GetChecked()
                SetLabeledEnabled(pipColorLbl, pipColorSwatch, not myself:GetChecked())
                CursorEnhancerModule.CE:ApplyAll()
            end, L["CURSORENHANCER_USE_CLASS_COLOR_TIP"], 22)
        SetLabeledEnabled(pipColorLbl, pipColorSwatch, not pipClassCb:GetChecked())

        root:Checkbox(L["CURSORENHANCER_PIP_FILL_LTR"], s.pipFillLtr ~= false, function(myself)
            s.pipFillLtr = myself:GetChecked()
            CursorEnhancerModule.CE:ApplyAll()
        end, L["CURSORENHANCER_PIP_FILL_LTR_TIP"])

        return math.max(1, -root:GetY())
    end)

    local function SwipeDefaults(content, cfg, enableLabel, apply, hasSpark)
        local root = NewStack(content, 0, 0)
        local deps = {}

        local function RefreshDeps()
            local on = cfg.enabled == true
            for _, w in ipairs(deps) do
                if w.kind == "color" then
                    SetLabeledEnabled(w.label, w.control, on and not cfg.useClassColor)
                elseif w.kind == "classColor" then
                    SetEnabled(w.control, on)
                elseif w.label then
                    SetLabeledEnabled(w.label, w.control, on)
                else
                    SetEnabled(w.control, on)
                end
            end
        end

        root:Checkbox(enableLabel, cfg.enabled == true, function(myself)
            cfg.enabled = myself:GetChecked()
            RefreshDeps()
            apply()
        end)

        local texLbl, texDd = root:Dropdown(L["CURSORENHANCER_RING_TEXTURE"], RingTexLabel(cfg.ringTex or "c1"), RingTexItems,
            function() return cfg.ringTex or "c1" end,
            function(value) cfg.ringTex = value; apply() end)
        deps[#deps + 1] = { label = texLbl, control = texDd }

        local radLbl, radSl = root:Slider(L["CURSORENHANCER_RADIUS"], 8, 80, 1, cfg.radius or 21, "%d",
            function(val) cfg.radius = val; apply() end)
        deps[#deps + 1] = { label = radLbl, control = radSl }

        local opLbl, opSl = root:Slider(OPACITY, 0, 100, 5, floor((cfg.alpha or 0.8) * 100 + 0.5), "%d%%",
            function(val) cfg.alpha = val / 100; apply() end)
        deps[#deps + 1] = { label = opLbl, control = opSl }

        local attachCb = root:Checkbox(L["CURSORENHANCER_ATTACH"], cfg.attached ~= false, function(myself)
            cfg.attached = myself:GetChecked(); apply()
        end)
        deps[#deps + 1] = { control = attachCb }

        if hasSpark then
            local sparkCb = root:Checkbox(L["CURSORENHANCER_SHOW_SPARK"], cfg.sparkEnabled ~= false, function(myself)
                cfg.sparkEnabled = myself:GetChecked(); apply()
            end)
            deps[#deps + 1] = { control = sparkCb }
        end

        local colorLbl, colorSwatch = root:Color(COLOR, cfg.color, apply)
        local classCb = root:Checkbox(L["CURSORENHANCER_USE_CLASS_COLOR"], cfg.useClassColor == true,
            function(myself)
                cfg.useClassColor = myself:GetChecked()
                RefreshDeps()
                apply()
            end, L["CURSORENHANCER_USE_CLASS_COLOR_TIP"], 22)
        deps[#deps + 1] = { kind = "classColor", control = classCb }
        deps[#deps + 1] = { kind = "color", label = colorLbl, control = colorSwatch }
        RefreshDeps()

        return math.max(1, -root:GetY())
    end

    cardStack:AddCard("cursorenhancer:gcd", L["CURSORENHANCER_SECTION_GCD"], function(content, _)
        return SwipeDefaults(content, s.gcd, L["CURSORENHANCER_ENABLE_GCD"],
            function() CursorEnhancerModule.CE:ApplyGCD() end, false)
    end)

    cardStack:AddCard("cursorenhancer:cast", L["CURSORENHANCER_SECTION_CAST"], function(content, _)
        return SwipeDefaults(content, s.castCircle, L["CURSORENHANCER_ENABLE_CAST"],
            function() CursorEnhancerModule.CE:ApplyCast() end, true)
    end)

    -- ─── Situations ──────────────────────────────────────────────────────────
    cardStack:AddCard("cursorenhancer:situations", L["CURSORENHANCER_SECTION_SITUATIONS"], function(content, _)
        local layoutY = 0

        local conflictAlert = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        conflictAlert:SetPoint("TOPLEFT", content, "TOPLEFT", 0, layoutY)
        conflictAlert:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, layoutY)
        conflictAlert:SetJustifyH("LEFT")
        conflictAlert:SetWordWrap(true)
        conflictAlert:SetTextColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
        conflictAlert:Hide()
        local conflictAlertY = layoutY
        layoutY = layoutY - 8

        local addBtn = OneWoW_GUI:CreateFitTextButton(content, {
            text = L["CURSORENHANCER_ADD_SITUATION"],
        })
        addBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, layoutY)
        addBtn:SetScript("OnClick", function()
            tinsert(s.situations, Situations.NewSituation(s))
            rebuildSituations()
            CursorEnhancerModule.CE:ApplyAll()
        end)
        layoutY = layoutY - 30

        situationsHost = CreateFrame("Frame", nil, content, "BackdropTemplate")
        situationsHost:SetPoint("TOPLEFT", content, "TOPLEFT", 0, layoutY)
        situationsHost:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, layoutY)
        situationsHost:SetHeight(40)
        local situationsHostY = layoutY

        local function ApplyCardChrome(card, sit, inConflict)
            if not sit.enabled then
                card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
                card:SetAlpha(0.55)
            elseif inConflict then
                card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
                card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
                card:SetAlpha(1)
            else
                card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                card:SetAlpha(1)
            end
        end

        local function BuildCard(parent, sit, index, conflicts)
            local inConflict = conflicts[sit.id] == true
            local expanded = sit._uiExpanded == true
            local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            card:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
            ApplyCardChrome(card, sit, inConflict)
            card._sit = sit
            card._index = index

            local y = -8
            local enableCb = OneWoW_GUI:CreateCheckbox(card, {
                label = sit.enabled ~= false and L["CURSORENHANCER_ENABLED"] or L["CURSORENHANCER_DISABLED"],
                checked = sit.enabled ~= false,
                onClick = function(myself)
                    sit.enabled = myself:GetChecked()
                    rebuildSituations()
                    CursorEnhancerModule.CE:ApplyAll()
                end,
            })
            enableCb:SetPoint("TOPLEFT", card, "TOPLEFT", 8, y)
            if sit.enabled ~= false then
                enableCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                enableCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
            end

            local delBtn = OneWoW_GUI:CreateFitTextButton(card, {
                text = DELETE,
            })
            delBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, y)
            delBtn:SetScript("OnClick", function()
                tremove(s.situations, index)
                rebuildSituations()
                CursorEnhancerModule.CE:ApplyAll()
            end)

            local expandBtn = OneWoW_GUI:CreateFitTextButton(card, {
                text = expanded and L["CURSORENHANCER_COLLAPSE"] or L["CURSORENHANCER_EXPAND"],
            })
            expandBtn:SetPoint("RIGHT", delBtn, "LEFT", -6, 0)
            expandBtn:SetScript("OnClick", function()
                sit._uiExpanded = not sit._uiExpanded
                rebuildSituations()
            end)
            y = y - 28

            local header = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header:SetPoint("TOPLEFT", card, "TOPLEFT", 12, y)
            header:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, y)
            header:SetJustifyH("LEFT")
            header:SetText(string.format("%s · %s",
                L[PLACE_LABEL[sit.place] or "CURSORENHANCER_PLACE_EVERYWHERE"],
                L[COMBAT_LABEL[sit.combat] or "CURSORENHANCER_COMBAT_EITHER"]))
            header:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            y = y - 18

            local summary = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            summary:SetPoint("TOPLEFT", card, "TOPLEFT", 12, y)
            summary:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, y)
            summary:SetJustifyH("LEFT")
            summary:SetWordWrap(true)
            summary:SetText(ShowSummary(sit))
            summary:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            y = y - summary:GetStringHeight() - 8

            if inConflict then
                local warn = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                warn:SetPoint("TOPLEFT", card, "TOPLEFT", 12, y)
                warn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, y)
                warn:SetJustifyH("LEFT")
                warn:SetWordWrap(true)
                warn:SetText(L["CURSORENHANCER_CONFLICT_TIP"])
                warn:SetTextColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
                y = y - warn:GetStringHeight() - 8
            end

            if expanded then
                local apply = function()
                    CursorEnhancerModule.CE:ApplyAll()
                end

                local function CardLabel(text)
                    local fs = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    fs:SetPoint("TOPLEFT", card, "TOPLEFT", 12, y)
                    fs:SetText(text)
                    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                    y = y - fs:GetStringHeight() - 4
                    return fs
                end

                local function BeginCardGroup(titleText)
                    local group = OneWoW_GUI:CreateFrame(card, {
                        backdrop = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS,
                        bgColor = "BG_TERTIARY",
                        borderColor = "BORDER_SUBTLE",
                        height = 40,
                    })
                    group:SetPoint("TOPLEFT", card, "TOPLEFT", 8, y)
                    group:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, y)

                    local pad = 10
                    local title = group:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    title:SetPoint("TOPLEFT", group, "TOPLEFT", pad, -pad)
                    title:SetText(titleText)
                    title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

                    local stack = NewStack(group, -pad - title:GetStringHeight() - 8, pad)

                    local function Finish()
                        local h = -stack:GetY() + pad
                        group:SetHeight(h)
                        y = y - h - 8
                    end

                    return stack, Finish
                end

                local function SetPieceMode(thingKey, mode)
                    sit.show = sit.show or {}
                    sit.overrides = sit.overrides or {}
                    if mode == "off" then
                        sit.show[thingKey] = nil
                        sit.overrides[thingKey] = nil
                    elseif mode == "on" then
                        sit.show[thingKey] = true
                        sit.overrides[thingKey] = nil
                    else
                        sit.show[thingKey] = true
                        sit.overrides[thingKey] = Situations.SnapshotOverride(s, thingKey)
                    end
                    rebuildSituations()
                    apply()
                end

                local function AddPieceMode(stack, thingKey)
                    local mode = PieceMode(sit, thingKey)
                    stack:BareDropdown(PieceModeLabel(mode), PieceModeItems,
                        function() return PieceMode(sit, thingKey) end,
                        function(value) SetPieceMode(thingKey, value) end)
                    if mode == "custom" then
                        local ov = sit.overrides[thingKey]
                        RenderThingOverrideEditors(stack, thingKey, ov, apply)
                    end
                end

                CardLabel(L["CURSORENHANCER_PLACE"])
                local placeDd, placeText = OneWoW_GUI:CreateDropdown(card, {
                    width = 180, height = 22,
                    text = L[PLACE_LABEL[sit.place] or "CURSORENHANCER_PLACE_EVERYWHERE"],
                })
                placeDd:SetPoint("TOPLEFT", card, "TOPLEFT", 24, y)
                OneWoW_GUI:AttachFilterMenu(placeDd, {
                    searchable = false,
                    getActiveValue = function() return sit.place end,
                    buildItems = PlaceItems,
                    onSelect = function(value, text)
                        placeText:SetText(text)
                        sit.place = value
                        rebuildSituations()
                        apply()
                    end,
                })
                y = y - 28

                CardLabel(COMBAT)
                local combatDd, combatText = OneWoW_GUI:CreateDropdown(card, {
                    width = 180, height = 22,
                    text = L[COMBAT_LABEL[sit.combat] or "CURSORENHANCER_COMBAT_EITHER"],
                })
                combatDd:SetPoint("TOPLEFT", card, "TOPLEFT", 24, y)
                OneWoW_GUI:AttachFilterMenu(combatDd, {
                    searchable = false,
                    getActiveValue = function() return sit.combat end,
                    buildItems = CombatItems,
                    onSelect = function(value, text)
                        combatText:SetText(text)
                        sit.combat = value
                        rebuildSituations()
                        apply()
                    end,
                })
                y = y - 28

                -- Look & Feel
                do
                    local g, finish = BeginCardGroup(L["CURSORENHANCER_SECTION_LOOK_FEEL"])
                    local lookCustom = Situations.HasLookFeelOverride(sit)
                    g:BareDropdown(LookModeLabel(lookCustom), LookModeItems,
                        function()
                            return Situations.HasLookFeelOverride(sit) and "custom" or "global"
                        end,
                        function(value)
                            if value == "custom" then
                                Situations.SnapshotLookFeel(sit, s)
                            else
                                Situations.ClearLookFeel(sit)
                            end
                            rebuildSituations()
                            apply()
                        end)

                    if lookCustom then
                        sit.overrides = sit.overrides or {}
                        local ov = sit.overrides
                        if ov.ringSize == nil then ov.ringSize = s.ringSize or 90 end
                        if ov.offsetX == nil then ov.offsetX = s.offsetX or 0 end
                        if ov.offsetY == nil then ov.offsetY = s.offsetY or 0 end
                        if ov.alpha == nil then ov.alpha = s.alpha or 1.0 end
                        if not sit.overrideMouseLook then
                            sit.overrideMouseLook = true
                            sit.onlyWhileMouseLook = s.onlyWhileMouseLook == true
                        end

                        g:Slider(L["CURSORENHANCER_RING_SIZE"], 40, 200, 1, ov.ringSize or 90, "%d",
                            function(val) ov.ringSize = val; apply() end)
                        g:Slider(L["CURSORENHANCER_OFFSET_X"], -200, 200, 1, ov.offsetX or 0, "%d",
                            function(val) ov.offsetX = val; apply() end)
                        g:Slider(L["CURSORENHANCER_OFFSET_Y"], -200, 200, 1, ov.offsetY or 0, "%d",
                            function(val) ov.offsetY = val; apply() end)
                        g:Slider(L["CURSORENHANCER_BASE_ALPHA"], 0, 100, 5,
                            floor((ov.alpha or 1) * 100 + 0.5), "%d%%",
                            function(val) ov.alpha = val / 100; apply() end)
                        g:Checkbox(L["CURSORENHANCER_ONLY_MOUSELOOK"], sit.onlyWhileMouseLook == true,
                            function(myself)
                                sit.onlyWhileMouseLook = myself:GetChecked()
                                apply()
                            end, L["CURSORENHANCER_ONLY_MOUSELOOK_TIP"])
                    end
                    finish()
                end

                do
                    local g, finish = BeginCardGroup(L["CURSORENHANCER_THING_OUTER"])
                    AddPieceMode(g, "outerRing")
                    finish()
                end
                do
                    local g, finish = BeginCardGroup(L["CURSORENHANCER_THING_MIDDLE"])
                    AddPieceMode(g, "middleRing")
                    finish()
                end
                do
                    local g, finish = BeginCardGroup(L["CURSORENHANCER_THING_MARKER"])
                    AddPieceMode(g, "centerMarker")
                    finish()
                end
                do
                    local g, finish = BeginCardGroup(L["CURSORENHANCER_THING_TRAIL"])
                    AddPieceMode(g, "trail")
                    finish()
                end

                -- Ring Swipes: two mode rows in one group
                do
                    local g, finish = BeginCardGroup(L["CURSORENHANCER_SECTION_SWIPES"])
                    g:Label(L["CURSORENHANCER_GCD_MIDDLE"])
                    AddPieceMode(g, "middleSwipe")
                    g:Label(L["CURSORENHANCER_CAST_OUTER"])
                    AddPieceMode(g, "outerSwipe")
                    finish()
                end

                do
                    local g, finish = BeginCardGroup(L["CURSORENHANCER_SECTION_PIPS"])
                    AddPieceMode(g, "pips")
                    finish()
                end
                do
                    local g, finish = BeginCardGroup(L["CURSORENHANCER_SECTION_GCD"])
                    AddPieceMode(g, "gcd")
                    finish()
                end
                do
                    local g, finish = BeginCardGroup(L["CURSORENHANCER_SECTION_CAST"])
                    AddPieceMode(g, "cast")
                    finish()
                end
            end

            card:SetHeight(-y + 10)
            return card
        end

        local function SituationsContentHeight()
            return math.max(1, math.abs(situationsHostY) + situationsHost:GetHeight())
        end

        rebuildSituations = function()
            for _, row in ipairs(situationRows) do
                if reorderCtrl then reorderCtrl:Detach(row) end
                row:Hide()
                row:SetParent(nil)
            end
            wipe(situationRows)

            local conflicts = Situations.FindConflicts(s)
            local hasConflict = next(conflicts) ~= nil
            if hasConflict then
                conflictAlert:SetText(L["CURSORENHANCER_CONFLICT_ALERT"])
                conflictAlert:Show()
                conflictAlert:ClearAllPoints()
                conflictAlert:SetPoint("TOPLEFT", content, "TOPLEFT", 0, conflictAlertY)
                conflictAlert:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, conflictAlertY)
            else
                conflictAlert:Hide()
            end

            local stackY = 0
            for i, sit in ipairs(s.situations or {}) do
                local card = BuildCard(situationsHost, sit, i, conflicts)
                card:SetPoint("TOPLEFT", situationsHost, "TOPLEFT", 0, stackY)
                card:SetPoint("TOPRIGHT", situationsHost, "TOPRIGHT", 0, stackY)
                stackY = stackY - card:GetHeight() - 8
                situationRows[#situationRows + 1] = card
                if reorderCtrl then
                    reorderCtrl:Attach(card, i)
                end
            end
            situationsHost:SetHeight(math.max(40, -stackY))

            local sitCard = content:GetParent()
            sitCard:SetContentHeight(SituationsContentHeight())
            cardStack:Relayout()
        end

        local r, g, b = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
        reorderCtrl = OneWoW_GUI:CreateReorderDrag({
            getItems = function() return situationRows end,
            dropIndicator = {
                thickness = 2, horizontalPadding = 4,
                color = { r, g, b, 1 },
            },
            onReorder = function(fromIdx, toIdx, insertBefore)
                local destIdx = insertBefore and toIdx or (toIdx + 1)
                if destIdx > fromIdx then destIdx = destIdx - 1 end
                if destIdx == fromIdx then return end
                local item = tremove(s.situations, fromIdx)
                tinsert(s.situations, destIdx, item)
                rebuildSituations()
                CursorEnhancerModule.CE:ApplyAll()
            end,
            onPickup = function(card)
                card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            end,
            onRestore = function(card)
                local sit = card._sit
                local conflicts = Situations.FindConflicts(s)
                ApplyCardChrome(card, sit, conflicts[sit.id] == true)
            end,
        })

        rebuildSituations()
        return SituationsContentHeight()
    end)

    cardStack:Finish()

    if registerRefresh then
        registerRefresh(function()
            -- Module enable/disable: re-tint is enough; full rebuild on next open.
        end)
    end

    return yOffset - cardsHost:GetHeight()
end
