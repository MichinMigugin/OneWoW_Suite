local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local L = Addon.L or {}

function Addon.UI:CreateFrameInspectorTab(parent)
    local DU = Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
    local resizeCap = DU.MAIN_FRAME_RESIZE_CAP or 0.95

    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local pickBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_PICK_FRAME"] or "Pick Frame", width = 100, height = 22 })
    pickBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)

    local searchBox = OneWoW_GUI:CreateEditBox(tab, {
        width = 150,
        height = 22,
        placeholderText = Addon.L and Addon.L["LABEL_FRAME_NAME"] or "Frame name...",
    })
    searchBox:SetPoint("LEFT", pickBtn, "RIGHT", 10, 0)

    local searchBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_SEARCH"] or "Search", width = 70, height = 22 })
    searchBtn:SetPoint("LEFT", searchBox, "RIGHT", 5, 0)

    pickBtn:SetScript("OnClick", function()
        if Addon.FramePicker then
            searchBox:SetText(searchBox.placeholderText or "")
            searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            Addon.FramePicker:Start()
        end
    end)

    local function doSearch()
        local text = searchBox:GetSearchText()
        if not text or text == "" then return end
        local results = Addon:SearchFramesByName(text)
        if #results == 0 then
            Addon:Print("No frames found matching: " .. text)
        else
            Addon.FrameInspector:InspectFrame(results[1])
            if #results > 1 then
                Addon:Print(string.format("Found %d frames, showing first: %s", #results, results[1].GetName and results[1]:GetName() or "Anonymous"))
            end
        end
    end
    searchBtn:SetScript("OnClick", doSearch)
    searchBox:SetScript("OnEnterPressed", function(self)
        doSearch()
        self:ClearFocus()
    end)

    -- Left panel: Frame Hierarchy (FrameTree)
    local LEFT_DEFAULT_WIDTH = DU.FRAME_INSPECTOR_LEFT_DEFAULT_WIDTH or 350
    local LEFT_MIN_WIDTH = LEFT_DEFAULT_WIDTH
    local RIGHT_MIN_WIDTH = DU.FRAME_INSPECTOR_RIGHT_MIN_WIDTH or 300
    local DIVIDER_WIDTH = DU.FRAME_INSPECTOR_DIVIDER_WIDTH or 6
    local PADDING = DIVIDER_WIDTH + 10

    local leftPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = LEFT_DEFAULT_WIDTH, height = 100 })
    leftPanel:ClearAllPoints()
    leftPanel:SetPoint("TOPLEFT", pickBtn, "BOTTOMLEFT", 0, -5)
    leftPanel:SetPoint("BOTTOM", tab, "BOTTOM", 0, 5)
    leftPanel:SetWidth(LEFT_DEFAULT_WIDTH)
    self:StyleContentPanel(leftPanel)

    local leftTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftTitle:SetPoint("TOP", leftPanel, "TOP", 0, -5)
    leftTitle:SetText(Addon.L and Addon.L["LABEL_FRAME_HIERARCHY"] or "Frame Hierarchy")
    leftTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local copyHierarchyBtn = OneWoW_GUI:CreateButton(leftPanel, { text = Addon.L and Addon.L["BTN_COPY_HIERARCHY"] or "Copy All", width = 70, height = 18 })
    copyHierarchyBtn:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -25, -3)
    copyHierarchyBtn:SetScript("OnClick", function()
        if tab.frameTree then
            Addon:CopyToClipboard(tab.frameTree:SerializeToText())
        end
    end)

    local leftScroll, leftContent = OneWoW_GUI:CreateScrollFrame(leftPanel, { name = "FrameInspectorLeftScroll" })
    leftScroll:ClearAllPoints()
    leftScroll:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 4, -25)
    leftScroll:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -14, 4)

    leftScroll:HookScript("OnSizeChanged", function(self, w)
        leftContent:SetWidth(w)
    end)

    tab.frameTree = Addon.FrameTree:Create(leftContent, leftScroll)

    local rightPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    self:StyleContentPanel(rightPanel)

    local function getNeededRightWidth()
        local dt = tab.detailsText
        if dt and dt.GetUnboundedStringWidth then
            local textWidth = dt:GetUnboundedStringWidth()
            local needed = textWidth + 32
            if needed > RIGHT_MIN_WIDTH then return needed end
        end
        return RIGHT_MIN_WIDTH
    end

    OneWoW_GUI:CreateVerticalPaneResizer({
        parent = tab,
        leftPanel = leftPanel,
        rightPanel = rightPanel,
        dividerWidth = DIVIDER_WIDTH,
        leftMinWidth = LEFT_MIN_WIDTH,
        rightMinWidth = RIGHT_MIN_WIDTH,
        splitPadding = PADDING,
        bottomOuterInset = 5,
        rightOuterInset = 5,
        resizeCap = resizeCap,
        mainFrame = Addon.UI and Addon.UI.mainFrame,
        getMinRightWidth = getNeededRightWidth,
    })

    -- Right panel: Frame Details

    local rightTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightTitle:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 5, -5)
    rightTitle:SetText(Addon.L and Addon.L["LABEL_FRAME_DETAILS"] or "Frame Details")
    rightTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local copyDetailsBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_COPY_DETAILS"] or "Copy All", width = 70, height = 18 })
    copyDetailsBtn:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -25, -3)

    local parentGoBtn = OneWoW_GUI:CreateButton(rightPanel, { text = (L["FRAME_INSPECTOR_PARENT_PREFIX"] or "-> ") .. (L["FRAME_INSPECTOR_PARENT_TARGET"] or "Parent"), height = 18 })
    parentGoBtn:SetPoint("LEFT", rightTitle, "RIGHT", 8, 0)
    parentGoBtn:SetPoint("RIGHT", copyDetailsBtn, "LEFT", -4, 0)
    parentGoBtn:SetScript("OnClick", function()
        if tab.currentParentRef then
            Addon.FrameInspector:InspectFrame(tab.currentParentRef)
        end
    end)
    parentGoBtn:Hide()
    tab.parentGoBtn = parentGoBtn
    copyDetailsBtn:SetScript("OnClick", function()
        if tab.detailsText then
            Addon:CopyToClipboard(tab.detailsText:GetText())
        end
    end)

    local rightScroll, rightContent = OneWoW_GUI:CreateScrollFrame(rightPanel, { name = "FrameInspectorRightScroll" })
    rightScroll:ClearAllPoints()
    rightScroll:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 4, -25)
    rightScroll:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -14, 4)

    rightScroll:HookScript("OnSizeChanged", function(self, w)
        rightContent:SetWidth(w)
    end)

    tab.detailsText = rightContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.detailsText:SetPoint("TOPLEFT", 2, -2)
    tab.detailsText:SetPoint("RIGHT", rightContent, "RIGHT", -2, 0)
    tab.detailsText:SetJustifyH("LEFT")
    tab.detailsText:SetText(Addon.L and Addon.L["LABEL_NO_FRAME"] or "No frame selected")
    tab.detailsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    tab.leftScroll = leftScroll
    tab.rightScroll = rightScroll

    local function boolStr(v)
        if v == nil then return nil end
        return v and "Yes" or "No"
    end

    local function fmtNum(v)
        if v == nil then return nil end
        if type(v) == "string" then return v end
        return string.format("%.1f", v)
    end

    local function fmtMulti(vals)
        if not vals then return nil end
        local parts = {}
        for _, v in ipairs(vals) do
            if type(v) == "number" then
                tinsert(parts, string.format("%.2f", v))
            else
                tinsert(parts, tostring(v))
            end
        end
        return table.concat(parts, ", ")
    end

    local function addSection(lines, title, entries)
        local any = false
        for _, entry in ipairs(entries) do
            if entry[2] ~= nil then
                any = true
                break
            end
        end
        if not any then return end
        tinsert(lines, "")
        tinsert(lines, "|cFFFFD100" .. title .. "|r")
        for _, entry in ipairs(entries) do
            if entry[2] ~= nil then
                tinsert(lines, "  " .. entry[1] .. ": " .. tostring(entry[2]))
            end
        end
    end

    function tab:UpdateFrameDetails(frame, info)
        if not info then return end

        -- Parent [Go] button
        if info.parent then
            self.currentParentRef = info.parent
            self.parentGoBtn:SetText((L["FRAME_INSPECTOR_PARENT_PREFIX"] or "-> ") .. (info.parentName or (L["FRAME_INSPECTOR_PARENT_TARGET"] or "Parent")))
            self.parentGoBtn:Show()
        else
            self.currentParentRef = nil
            self.parentGoBtn:Hide()
        end

        local lines = {}

        -- Identity
        tinsert(lines, "|cFFFFD100IDENTITY|r")
        tinsert(lines, "  Name: " .. (info.name or "Anonymous"))
        tinsert(lines, "  Type: " .. (info.type or "Unknown"))
        if info.parentName then
            tinsert(lines, "  Parent: " .. info.parentName)
        end
        if info.debugName and info.debugName ~= info.name then
            tinsert(lines, "  DebugName: " .. info.debugName)
        end
        if info.ID and info.ID ~= 0 then
            tinsert(lines, "  ID: " .. info.ID)
        end
        if info.parentKey then
            tinsert(lines, "  ParentKey: " .. info.parentKey)
        end

        -- State (Frame-only)
        if info.protected ~= nil then
            addSection(lines, "STATE", {
                { "Protected", boolStr(info.protected) },
                { "Forbidden", boolStr(info.forbidden) },
            })
        end

        -- Geometry
        addSection(lines, "GEOMETRY", {
            { "Size", (info.width and info.height) and string.format("%.1f x %.1f", info.width, info.height) or nil },
            { "Left", fmtNum(info.left) },
            { "Top", fmtNum(info.top) },
            { "Right", fmtNum(info.right) },
            { "Bottom", fmtNum(info.bottom) },
            { "Scale", fmtNum(info.scale) },
            { "Eff. Scale", fmtNum(info.effectiveScale) },
            { "BoundsRect", fmtMulti(info.boundsRect) },
        })

        -- Screen Position
        if info.screenPos then
            local sp = info.screenPos
            local spEntries = {
                { "Left", fmtNum(sp.left) },
                { "Right", fmtNum(sp.right) },
                { "Bottom", fmtNum(sp.bottom) },
                { "Top", fmtNum(sp.top) },
                { "Center", string.format("%.1f, %.1f", sp.centerX, sp.centerY) },
            }
            if info.relativeToParent then
                local rp = info.relativeToParent
                tinsert(spEntries, { "From Left Edge", fmtNum(rp.fromLeft) })
                tinsert(spEntries, { "From Right Edge", fmtNum(rp.fromRight) })
                tinsert(spEntries, { "From Bottom Edge", fmtNum(rp.fromBottom) })
                tinsert(spEntries, { "From Top Edge", fmtNum(rp.fromTop) })
                tinsert(spEntries, { "From Parent Center", string.format("%.1f, %.1f", rp.fromCenterX, rp.fromCenterY) })
            end
            addSection(lines, "SCREEN POSITION", spEntries)
        end

        -- Strata / Visibility
        addSection(lines, "STRATA / VISIBILITY", {
            { "Strata", info.strata },
            { "Level", info.level },
            { "Alpha", fmtNum(info.alpha) },
            { "Eff. Alpha", fmtNum(info.effectiveAlpha) },
            { "IsShown", boolStr(info.shown) },
            { "IsVisible", boolStr(info.isVisible) },
            { "Mouse", boolStr(info.mouse) },
            { "Keyboard", boolStr(info.keyboard) },
            { "FixedLevel", boolStr(info.fixedLevel) },
            { "FixedStrata", boolStr(info.fixedStrata) },
            { "Toplevel", boolStr(info.toplevel) },
            { "UsingParentLevel", boolStr(info.usingParentLevel) },
            { "RaisedLevel", info.raisedLevel },
            { "HighestLevel", info.highestLevel },
        })

        -- Layout
        addSection(lines, "LAYOUT", {
            { "NumChildren", info.numChildren },
            { "NumRegions", info.numRegions },
            { "ClipsChildren", boolStr(info.clipsChildren) },
            { "IgnoreChildrenBounds", boolStr(info.ignoreChildrenBounds) },
            { "ClampedToScreen", boolStr(info.clampedToScreen) },
            { "ClampInsets", fmtMulti(info.clampInsets) },
            { "HitRectInsets", fmtMulti(info.hitRectInsets) },
        })

        -- Behavior
        addSection(lines, "BEHAVIOR", {
            { "Movable", boolStr(info.movable) },
            { "Resizable", boolStr(info.resizable) },
            { "ResizeBounds", fmtMulti(info.resizeBounds) },
            { "UserPlaced", boolStr(info.userPlaced) },
            { "DontSavePosition", boolStr(info.dontSavePosition) },
            { "PropagateKeyboard", boolStr(info.propagateKeyboard) },
            { "HyperlinksEnabled", boolStr(info.hyperlinksEnabled) },
            { "HyperlinkPropagate", boolStr(info.hyperlinkPropagate) },
            { "CanChangeAttribute", boolStr(info.canChangeAttribute) },
        })

        -- Render
        addSection(lines, "RENDER", {
            { "FlattensRenderLayers", boolStr(info.flattensRenderLayers) },
            { "EffectivelyFlattens", boolStr(info.effectivelyFlattens) },
            { "IsFrameBuffer", boolStr(info.isFrameBuffer) },
            { "HasAlphaGradient", boolStr(info.hasAlphaGradient) },
        })

        -- Input
        addSection(lines, "INPUT", {
            { "GamePadButton", boolStr(info.gamePadButton) },
            { "GamePadStick", boolStr(info.gamePadStick) },
        })

        -- Anchors
        if info.points and #info.points > 0 then
            tinsert(lines, "")
            tinsert(lines, "|cFFFFD100ANCHORS|r")
            for i, pt in ipairs(info.points) do
                local x = type(pt.x) == "number" and string.format("%.1f", pt.x) or tostring(pt.x or 0)
                local y = type(pt.y) == "number" and string.format("%.1f", pt.y) or tostring(pt.y or 0)
                tinsert(lines, string.format("  Point %d -> %s.%s (%s, %s)",
                    i, pt.relativeTo or "nil", pt.relativePoint or "", x, y))
            end
        end

        -- Registered Events
        if info.registeredEvents then
            tinsert(lines, "")
            tinsert(lines, "|cFFFFD100REGISTERED EVENTS|r")
            if #info.registeredEvents > 0 then
                for _, event in ipairs(info.registeredEvents) do
                    tinsert(lines, "  " .. event)
                end
            else
                tinsert(lines, "  (none detected among " .. #Addon.Constants.COMMON_EVENTS .. " common events)")
            end
        end

        -- Scripts
        if info.scripts then
            tinsert(lines, "")
            tinsert(lines, "|cFFFFD100SCRIPTS|r")
            if #info.scripts > 0 then
                for _, scriptName in ipairs(info.scripts) do
                    tinsert(lines, "  " .. scriptName .. ": [handler]")
                end
            else
                tinsert(lines, "  no script handlers attached")
            end
        end

        -- Region properties (for non-frame objects)
        addSection(lines, "REGION", {
            { "IgnoreParentAlpha", boolStr(info.ignoreParentAlpha) },
            { "IgnoreParentScale", boolStr(info.ignoreParentScale) },
            { "ObjectLoaded", boolStr(info.objectLoaded) },
        })

        -- Debug
        addSection(lines, "DEBUG", {
            { "SourceLocation", info.sourceLocation },
            { "HasSecretValues", boolStr(info.hasSecretValues) },
            { "HasAnySecretAspect", boolStr(info.hasAnySecretAspect) },
        })

        -- Type-specific
        local ts = info.typeSpecific
        if ts then
            local tsType = ts._type
            tinsert(lines, "")
            tinsert(lines, "|cFFFFD100" .. (tsType or "TYPE-SPECIFIC") .. " PROPERTIES|r")

            if tsType == "Texture" or tsType == "MaskTexture" then
                if ts.atlas then tinsert(lines, "  Atlas: " .. tostring(ts.atlas)) end
                if ts.texture then tinsert(lines, "  Texture: " .. tostring(ts.texture)) end
                if ts.textureFileID then tinsert(lines, "  FileID: " .. tostring(ts.textureFileID)) end
                if ts.blendMode then tinsert(lines, "  BlendMode: " .. tostring(ts.blendMode)) end
                if ts.texCoord then tinsert(lines, "  TexCoord: " .. fmtMulti(ts.texCoord)) end
                if ts.drawLayer then tinsert(lines, "  DrawLayer: " .. tostring(ts.drawLayer) .. (ts.drawSublevel and (" (" .. ts.drawSublevel .. ")") or "")) end
                if ts.vertexColor then tinsert(lines, "  VertexColor: " .. fmtMulti(ts.vertexColor)) end
                if ts.desaturation then tinsert(lines, "  Desaturation: " .. fmtNum(ts.desaturation)) end
                if ts.rotation then tinsert(lines, "  Rotation: " .. fmtNum(ts.rotation)) end
                if ts.horizTile ~= nil then tinsert(lines, "  HorizTile: " .. boolStr(ts.horizTile)) end
                if ts.vertTile ~= nil then tinsert(lines, "  VertTile: " .. boolStr(ts.vertTile)) end
            elseif tsType == "FontString" then
                if ts.text then tinsert(lines, "  Text: " .. tostring(ts.text)) end
                if ts.font then tinsert(lines, "  Font: " .. fmtMulti(ts.font)) end
                if ts.justifyH then tinsert(lines, "  JustifyH: " .. tostring(ts.justifyH)) end
                if ts.justifyV then tinsert(lines, "  JustifyV: " .. tostring(ts.justifyV)) end
                if ts.spacing then tinsert(lines, "  Spacing: " .. fmtNum(ts.spacing)) end
                if ts.stringWidth then tinsert(lines, "  StringWidth: " .. fmtNum(ts.stringWidth)) end
                if ts.stringHeight then tinsert(lines, "  StringHeight: " .. fmtNum(ts.stringHeight)) end
                if ts.numLines then tinsert(lines, "  NumLines: " .. ts.numLines) end
                if ts.isTruncated ~= nil then tinsert(lines, "  IsTruncated: " .. boolStr(ts.isTruncated)) end
            elseif tsType == "Line" then
                if ts.startPoint then tinsert(lines, "  StartPoint: " .. fmtMulti(ts.startPoint)) end
                if ts.endPoint then tinsert(lines, "  EndPoint: " .. fmtMulti(ts.endPoint)) end
                if ts.thickness then tinsert(lines, "  Thickness: " .. fmtNum(ts.thickness)) end
            elseif tsType == "Button" or tsType == "CheckButton" then
                if ts.buttonState then tinsert(lines, "  ButtonState: " .. tostring(ts.buttonState)) end
                if ts.buttonText then tinsert(lines, "  Text: " .. tostring(ts.buttonText)) end
                if ts.enabled ~= nil then tinsert(lines, "  Enabled: " .. boolStr(ts.enabled)) end
            elseif tsType == "EditBox" then
                if ts.text then tinsert(lines, "  Text: " .. tostring(ts.text)) end
                if ts.cursorPosition then tinsert(lines, "  CursorPosition: " .. ts.cursorPosition) end
                if ts.numLetters then tinsert(lines, "  NumLetters: " .. ts.numLetters) end
                if ts.maxLetters then tinsert(lines, "  MaxLetters: " .. ts.maxLetters) end
                if ts.isMultiLine ~= nil then tinsert(lines, "  MultiLine: " .. boolStr(ts.isMultiLine)) end
                if ts.isAutoFocus ~= nil then tinsert(lines, "  AutoFocus: " .. boolStr(ts.isAutoFocus)) end
                if ts.isNumeric ~= nil then tinsert(lines, "  Numeric: " .. boolStr(ts.isNumeric)) end
            elseif tsType == "ScrollFrame" then
                if ts.horizontalScroll then tinsert(lines, "  HorizontalScroll: " .. fmtNum(ts.horizontalScroll)) end
                if ts.verticalScroll then tinsert(lines, "  VerticalScroll: " .. fmtNum(ts.verticalScroll)) end
            elseif tsType == "Slider" then
                if ts.minMax then tinsert(lines, "  MinMax: " .. fmtMulti(ts.minMax)) end
                if ts.value then tinsert(lines, "  Value: " .. fmtNum(ts.value)) end
                if ts.valueStep then tinsert(lines, "  ValueStep: " .. fmtNum(ts.valueStep)) end
                if ts.obeyStep ~= nil then tinsert(lines, "  ObeyStepOnDrag: " .. boolStr(ts.obeyStep)) end
            elseif tsType == "StatusBar" then
                if ts.minMax then tinsert(lines, "  MinMax: " .. fmtMulti(ts.minMax)) end
                if ts.value then tinsert(lines, "  Value: " .. fmtNum(ts.value)) end
                if ts.statusBarColor then tinsert(lines, "  Color: " .. fmtMulti(ts.statusBarColor)) end
            elseif tsType == "Cooldown" then
                if ts.cooldownTimes then tinsert(lines, "  CooldownTimes: " .. fmtMulti(ts.cooldownTimes)) end
                if ts.cooldownDuration then tinsert(lines, "  Duration: " .. fmtNum(ts.cooldownDuration)) end
            elseif tsType == "ColorSelect" then
                if ts.colorRGB then tinsert(lines, "  RGB: " .. fmtMulti(ts.colorRGB)) end
                if ts.colorHSV then tinsert(lines, "  HSV: " .. fmtMulti(ts.colorHSV)) end
            elseif tsType == "Model" or tsType == "PlayerModel" or tsType == "DressUpModel" or tsType == "CinematicModel" then
                if ts.facing then tinsert(lines, "  Facing: " .. fmtNum(ts.facing)) end
                if ts.position then tinsert(lines, "  Position: " .. fmtMulti(ts.position)) end
                if ts.modelScale then tinsert(lines, "  ModelScale: " .. fmtNum(ts.modelScale)) end
            end
        end

        self.detailsText:SetText(table.concat(lines, "\n"))

        local height = self.detailsText:GetStringHeight()
        self.rightScroll:GetScrollChild():SetHeight(math.max(height + 10, self.rightScroll:GetHeight()))

        -- Auto-expand main window if right panel is too narrow for content
        local mainFrame = Addon.UI and Addon.UI.mainFrame
        if mainFrame then
            local neededRightWidth = getNeededRightWidth()

            local currentLeftWidth = leftPanel:GetWidth()
            local neededTabWidth = currentLeftWidth + PADDING + neededRightWidth
            local tabWidth = tab:GetWidth()

            if neededTabWidth > tabWidth then
                local extraNeeded = neededTabWidth - tabWidth
                local currentMainW = mainFrame:GetWidth()
                local screenMax = math.floor(GetScreenWidth() * resizeCap)
                local newMainW = math.min(currentMainW + extraNeeded, screenMax)
                if newMainW > currentMainW then
                    mainFrame:SetWidth(newMainW)
                end
            end
        end
    end

    Addon.FrameInspectorTab = tab
    return tab
end

