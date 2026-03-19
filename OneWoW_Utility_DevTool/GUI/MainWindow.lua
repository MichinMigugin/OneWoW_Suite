local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local DEFAULT_THEME_ICON = OneWoW_GUI.Constants.DEFAULT_THEME_ICON

local UI = {}
Addon.UI = UI

UI.tabs = {}
UI.currentTab = nil

local L = Addon.L or {}

local function StyleContentPanel(panel)
    panel:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    panel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    panel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
end

function UI:Initialize()
    if self.mainFrame then return end

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or DEFAULT_THEME_ICON
    local frame = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_UtilityDevToolFrame",
        width = 750,
        height = 450,
        backdrop = BACKDROP_INNER_NO_INSETS,
    })
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        frame:SetClampedToScreen(true)
    end)
    frame:SetClampedToScreen(true)
    frame:SetResizable(true)
    local maxW = math.floor(GetScreenWidth() * 0.95)
    local maxH = math.floor(GetScreenHeight() * 0.95)
    frame:SetResizeBounds(750, 450, maxW, maxH)

    local resizeHandle = CreateFrame("Button", nil, frame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeHandle:SetScript("OnMouseDown", function()
        frame:SetClampedToScreen(false)
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        frame:SetClampedToScreen(true)
    end)

    frame:Hide()

    local titleBar = OneWoW_GUI:CreateTitleBar(frame, {
        title = Addon.L and Addon.L["ADDON_TITLE"] or "DevTool",
        height = 20,
        showBrand = true,
        factionTheme = factionTheme,
        onClose = function() UI:Hide() end,
    })
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -OneWoW_GUI:GetSpacing("XS"), -OneWoW_GUI:GetSpacing("XS"))

    tinsert(UISpecialFrames, "OneWoW_UtilityDevToolFrame")

    local TAB_GAP = 4
    local TAB_HEIGHT = 28
    local NUM_TABS = 8
    local tabLabels = {
        Addon.L and Addon.L["TAB_FRAME"] or "Frame",
        Addon.L and Addon.L["TAB_EVENTS"] or "Events",
        Addon.L and Addon.L["TAB_LUA"] or "Lua",
        Addon.L and Addon.L["TAB_TEXTURES"] or "Textures",
        Addon.L and Addon.L["TAB_COLORS"] or "Colors",
        Addon.L and Addon.L["TAB_LAYOUT"] or "Layout",
        Addon.L and Addon.L["TAB_MONITOR"] or "Monitor",
        "Settings",
    }

    local tabButtons = {}
    local tabY = -(OneWoW_GUI:GetSpacing("XS") + 20 + OneWoW_GUI:GetSpacing("XS"))

    for i = 1, NUM_TABS do
        local btn = OneWoW_GUI:CreateButton(frame, { text = tabLabels[i], width = 90, height = TAB_HEIGHT })
        btn:SetID(i)
        btn.isSelected = false
        if i == 1 then
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", OneWoW_GUI:GetSpacing("SM"), tabY)
        else
            btn:SetPoint("LEFT", tabButtons[i - 1], "RIGHT", TAB_GAP, 0)
        end
        local tabID = i
        btn:SetScript("OnClick", function() UI:SelectTab(tabID) end)
        btn:SetScript("OnEnter", function(self)
            if not self.isSelected then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if not self.isSelected then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end)
        btn:SetScript("OnMouseDown", function(self)
            if not self.isSelected then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED"))
            end
        end)
        btn:SetScript("OnMouseUp", function(self)
            if not self.isSelected then
                if self:IsMouseOver() then
                    self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
                else
                    self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                end
            end
        end)
        tabButtons[i] = btn
    end

    local tab1, tab2, tab3, tab4, tab5, tab6, tab7, tab8 =
        tabButtons[1], tabButtons[2], tabButtons[3], tabButtons[4],
        tabButtons[5], tabButtons[6], tabButtons[7], tabButtons[8]

    local function ResizeTabButtons()
        local frameWidth = frame:GetWidth()
        local availWidth = frameWidth - OneWoW_GUI:GetSpacing("SM") * 2 - (NUM_TABS - 1) * TAB_GAP
        local tabWidth = math.floor(availWidth / NUM_TABS)
        for i = 1, NUM_TABS do
            tabButtons[i]:SetWidth(tabWidth)
        end
    end

    frame:HookScript("OnSizeChanged", function()
        ResizeTabButtons()
    end)
    ResizeTabButtons()

    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     OneWoW_GUI:GetSpacing("SM"), -(OneWoW_GUI:GetSpacing("XS") + 20 + OneWoW_GUI:GetSpacing("XS") + TAB_HEIGHT + OneWoW_GUI:GetSpacing("XS")))
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -OneWoW_GUI:GetSpacing("SM"), OneWoW_GUI:GetSpacing("SM"))

    self.tabs[1] = {button = tab1, content = self:CreateFrameInspectorTab(contentFrame)}
    self.tabs[2] = {button = tab2, content = self:CreateEventMonitorTab(contentFrame)}
    self.tabs[3] = {button = tab3, content = self:CreateLuaConsoleTab(contentFrame)}

    local disabledTab = CreateFrame("Frame", nil, contentFrame)
    disabledTab:SetAllPoints(contentFrame)
    disabledTab:Hide()
    self.tabs[4] = {button = tab4, content = disabledTab}
    tab4:Disable()
    tab4.text:SetTextColor(0.4, 0.4, 0.4)
    tab4:SetScript("OnClick", nil)
    tab4:SetScript("OnEnter", nil)
    tab4:SetScript("OnLeave", nil)
    tab4:SetScript("OnMouseDown", nil)
    tab4:SetScript("OnMouseUp", nil)

    self.tabs[5] = {button = tab5, content = self:CreateColorTab(contentFrame)}
    self.tabs[6] = {button = tab6, content = self:CreateLayoutTab(contentFrame)}
    self.tabs[7] = {button = tab7, content = self:CreateMonitorTab(contentFrame)}
    self.tabs[8] = {button = tab8, content = self:CreateSettingsTab(contentFrame)}

    self.mainFrame = frame
    self.contentFrame = contentFrame

    if not OneWoW_GUI:RestoreWindowPosition(frame, Addon.db.position or {}) then
        frame:SetPoint("CENTER")
    end

    frame:SetScript("OnHide", function()
        Addon.db.position = Addon.db.position or {}
        OneWoW_GUI:SaveWindowPosition(frame, Addon.db.position)
        if Addon.FrameInspector then
            Addon.FrameInspector:ClearHighlight()
        end
    end)

    self:SelectTab(1)
end

function UI:SelectTab(tabID)
    if tabID == 4 then return end
    self.currentTab = tabID

    for id, tab in pairs(self.tabs) do
        if id == 4 then
            tab.content:Hide()
        elseif id == tabID then
            tab.content:Show()
            if id == 2 and Addon.EventMonitor then
                Addon.EventMonitor:UpdateUI()
            end
            tab.button.isSelected = true
            tab.button:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            tab.button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            tab.button.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            tab.content:Hide()
            tab.button.isSelected = false
            tab.button:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            tab.button:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            tab.button.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end
end

function UI:CreateFrameInspectorTab(parent)
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
    local LEFT_DEFAULT_WIDTH = 350
    local LEFT_MIN_WIDTH = LEFT_DEFAULT_WIDTH
    local RIGHT_MIN_WIDTH = 300
    local DIVIDER_WIDTH = 6
    local PADDING = DIVIDER_WIDTH + 10

    local leftPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = LEFT_DEFAULT_WIDTH, height = 100 })
    leftPanel:ClearAllPoints()
    leftPanel:SetPoint("TOPLEFT", pickBtn, "BOTTOMLEFT", 0, -5)
    leftPanel:SetPoint("BOTTOM", tab, "BOTTOM", 0, 5)
    leftPanel:SetWidth(LEFT_DEFAULT_WIDTH)
    StyleContentPanel(leftPanel)

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

    -- Divider handle between left and right panels
    local divider = CreateFrame("Button", nil, tab)
    divider:SetWidth(DIVIDER_WIDTH)
    divider:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 0, 0)
    divider:SetPoint("BOTTOM", tab, "BOTTOM", 0, 5)
    divider:EnableMouse(true)

    local dividerTex = divider:CreateTexture(nil, "OVERLAY")
    dividerTex:SetWidth(2)
    dividerTex:SetPoint("TOP", divider, "TOP", 0, 0)
    dividerTex:SetPoint("BOTTOM", divider, "BOTTOM", 0, 0)
    dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    divider:SetScript("OnEnter", function(self)
        dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        SetCursor("UI_RESIZE_CURSOR")
    end)
    divider:SetScript("OnLeave", function(self)
        if not self.isDragging then
            dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            SetCursor(nil)
        end
    end)

    divider:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isDragging = true
            self.startX = GetCursorPosition() / self:GetEffectiveScale()
            self.startWidth = leftPanel:GetWidth()
        end
    end)

    divider:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.isDragging = false
            dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            SetCursor(nil)
        end
    end)

    local function getNeededRightWidth()
        local dt = tab.detailsText
        if dt and dt.GetUnboundedStringWidth then
            local textWidth = dt:GetUnboundedStringWidth()
            local needed = textWidth + 32
            if needed > RIGHT_MIN_WIDTH then return needed end
        end
        return RIGHT_MIN_WIDTH
    end

    divider:SetScript("OnUpdate", function(self)
        if not self.isDragging then return end
        local cursorX = GetCursorPosition() / self:GetEffectiveScale()
        local delta = cursorX - self.startX
        local desiredLeftWidth = math.max(LEFT_MIN_WIDTH, self.startWidth + delta)

        local mainFrame = Addon.UI and Addon.UI.mainFrame
        local tabWidth = tab:GetWidth()
        local neededRight = getNeededRightWidth()
        local rightAvailable = tabWidth - desiredLeftWidth - PADDING

        if rightAvailable < neededRight and mainFrame then
            local shortage = neededRight - rightAvailable
            local currentMainW = mainFrame:GetWidth()
            local screenMax = math.floor(GetScreenWidth() * 0.95)
            local newMainW = math.min(currentMainW + shortage, screenMax)
            if newMainW > currentMainW then
                mainFrame:SetWidth(newMainW)
                tabWidth = tab:GetWidth()
            end
        end

        local maxLeftWidth = tabWidth - RIGHT_MIN_WIDTH - PADDING
        local newLeftWidth = math.max(LEFT_MIN_WIDTH, math.min(desiredLeftWidth, maxLeftWidth))
        leftPanel:SetWidth(newLeftWidth)
    end)

    -- Clamp left panel when main window is resized smaller
    tab:HookScript("OnSizeChanged", function(self, w)
        local maxLeftWidth = w - RIGHT_MIN_WIDTH - PADDING
        if maxLeftWidth < LEFT_MIN_WIDTH then maxLeftWidth = LEFT_MIN_WIDTH end
        local currentLeftWidth = leftPanel:GetWidth()
        if currentLeftWidth > maxLeftWidth then
            leftPanel:SetWidth(maxLeftWidth)
        end
    end)

    -- Right panel: Frame Details
    local rightPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    rightPanel:ClearAllPoints()
    rightPanel:SetPoint("TOPLEFT", divider, "TOPRIGHT", 0, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)
    StyleContentPanel(rightPanel)

    local rightTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightTitle:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 5, -5)
    rightTitle:SetText(Addon.L and Addon.L["LABEL_FRAME_DETAILS"] or "Frame Details")
    rightTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local copyDetailsBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_COPY_DETAILS"] or "Copy All", width = 70, height = 18 })
    copyDetailsBtn:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -25, -3)

    local parentGoBtn = OneWoW_GUI:CreateButton(rightPanel, { text = "-> Parent", height = 18 })
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
            self.parentGoBtn:SetText("-> " .. (info.parentName or "Parent"))
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
                local screenMax = math.floor(GetScreenWidth() * 0.95)
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

function UI:CreateEventMonitorTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local startStopBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["BTN_START"] or "Start", height = 22, minWidth = 60 })
    startStopBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
    startStopBtn:SetScript("OnClick", function()
        if Addon.EventMonitor then
            if Addon.EventMonitor.monitoring then
                Addon.EventMonitor:Stop()
            else
                Addon.EventMonitor:Start()
            end
        end
    end)

    local pauseBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["BTN_PAUSE"] or "Pause", height = 22, minWidth = 70 })
    pauseBtn:SetPoint("LEFT", startStopBtn, "RIGHT", 5, 0)
    pauseBtn:SetScript("OnClick", function()
        if Addon.EventMonitor then
            Addon.EventMonitor:TogglePause()
        end
    end)

    local clearBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["BTN_CLEAR"] or "Clear", height = 22, minWidth = 50 })
    clearBtn:SetPoint("LEFT", pauseBtn, "RIGHT", 5, 0)
    clearBtn:SetScript("OnClick", function()
        if Addon.EventMonitor then
            Addon.EventMonitor:Clear()
        end
    end)

    local configBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["BTN_SELECT_EVENTS"] or "Select Events", height = 22, minWidth = 80 })
    configBtn:SetPoint("LEFT", clearBtn, "RIGHT", 5, 0)
    configBtn:SetScript("OnClick", function()
        UI:ShowEventSelector()
    end)

    local importBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = "Import Events", height = 22, minWidth = 80 })
    importBtn:SetPoint("LEFT", configBtn, "RIGHT", 5, 0)
    importBtn:SetScript("OnClick", function()
        UI:ShowEventImportDialog()
    end)

    local firehoseBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = "Firehose", height = 22, minWidth = 60 })
    firehoseBtn:SetPoint("LEFT", importBtn, "RIGHT", 5, 0)
    firehoseBtn:SetScript("OnClick", function()
        if Addon.EventMonitor then
            Addon.EventMonitor:FirehoseToggle()
        end
    end)

    local filterLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("TOPLEFT", startStopBtn, "BOTTOMLEFT", 0, -8)
    filterLabel:SetText(Addon.L and Addon.L["LABEL_FILTER"] or "Filter:")
    filterLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local filterBox = OneWoW_GUI:CreateEditBox(tab, {
        width = 150,
        height = 22,
        placeholderText = Addon.L and Addon.L["LABEL_FILTER"] or "Filter...",
        onTextChanged = function()
            if Addon.EventMonitor then
                Addon.EventMonitor:UpdateUI()
            end
        end,
    })
    filterBox:SetPoint("LEFT", filterLabel, "RIGHT", 5, 0)

    local panel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", startStopBtn, "BOTTOMLEFT", 0, -35)
    panel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)
    StyleContentPanel(panel)

    local scroll, content = OneWoW_GUI:CreateScrollFrame(panel, { name = "EventMonitorScroll" })
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 4)

    tab.maxRowWidth = 0
    scroll:HookScript("OnSizeChanged", function(self, w)
        content:SetWidth(math.max(w, tab.maxRowWidth or 0))
    end)

    local ROW_HEIGHT = Addon.Constants and Addon.Constants.EVENT_VIEWER_ROW_HEIGHT or 14
    local COL_EVENT = Addon.Constants and Addon.Constants.EVENT_VIEWER_COL_EVENT or 280
    local COL_ARGS = Addon.Constants and Addon.Constants.EVENT_VIEWER_COL_ARGS or 260
    local MAX_EVENT_ROWS = 201  -- 200 events + 1 truncation row

    tab.emptyStateText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.emptyStateText:SetPoint("CENTER", content, "CENTER", 0, 0)
    tab.emptyStateText:SetJustifyH("CENTER")
    tab.emptyStateText:SetText(L["MSG_CLICK_START"] or "Click 'Start' to begin monitoring (auto-selects common events)\nOr click 'Select Events' to customize")
    tab.emptyStateText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    tab.rowPool = {}
    for i = 1, MAX_EVENT_ROWS do
        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", content, "RIGHT", -2, 0)

        row.eventCol = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.eventCol:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.eventCol:SetJustifyH("LEFT")
        row.eventCol:SetWordWrap(false)

        row.argsCol = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.argsCol:SetPoint("LEFT", row, "LEFT", COL_EVENT, 0)
        row.argsCol:SetJustifyH("LEFT")
        row.argsCol:SetWordWrap(false)

        row.countCol = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.countCol:SetPoint("LEFT", row, "LEFT", COL_EVENT + COL_ARGS, 0)
        row.countCol:SetJustifyH("LEFT")
        row.countCol:SetWordWrap(false)

        row:Hide()
        tab.rowPool[i] = row
    end

    tab.content = content
    tab.ROW_HEIGHT = ROW_HEIGHT
    tab.COL_EVENT = COL_EVENT
    tab.COL_ARGS = COL_ARGS

    -- CreateScrollFrame sets content height to 1; set minimum so empty state is visible
    content:SetHeight(math.max(100, panel:GetHeight() or 100))

    tab.startStopBtn = startStopBtn
    tab.pauseBtn = pauseBtn
    tab.firehoseBtn = firehoseBtn
    tab.filterBox = filterBox
    tab.scroll = scroll

    pauseBtn:Disable()

    -- Hook OnLeave so correct styling persists: CreateButton's OnLeave always sets BTN_NORMAL,
    -- which overwrites our active state. Re-apply state-based styling.
    startStopBtn:HookScript("OnLeave", function(self)
        if Addon.EventMonitor and Addon.EventMonitor.monitoring then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end)
    pauseBtn:HookScript("OnLeave", function(self)
        if Addon.EventMonitor and Addon.EventMonitor.monitoring then
            if Addon.EventMonitor.paused then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            else
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end
    end)

    Addon.EventMonitorTab = tab
    return tab
end

function UI:CreateLuaConsoleTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local clearBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_CLEAR"] or "Clear", width = 80, height = 22 })
    clearBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
    clearBtn:SetScript("OnClick", function()
        if Addon.ErrorLogger then
            Addon.ErrorLogger:ClearErrors()
        end
    end)

    local countLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    countLabel:SetPoint("LEFT", clearBtn, "RIGHT", 10, 0)
    countLabel:SetText((Addon.L and Addon.L["LABEL_ERRORS"] or "Errors:") .. " 0")
    countLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local soundCheck = OneWoW_GUI:CreateCheckbox(tab, {
        label = Addon.L and Addon.L["ERR_PLAY_ALERT"] or "Play Alert",
    })
    soundCheck:SetPoint("LEFT", countLabel, "RIGHT", 15, 0)
    soundCheck:SetChecked(Addon.db and Addon.db.errorDB and Addon.db.errorDB.playSound or false)
    soundCheck:SetScript("OnClick", function(self)
        if Addon.db and Addon.db.errorDB then
            Addon.db.errorDB.playSound = self:GetChecked() and true or false
        end
    end)


    local listPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 250 })
    listPanel:ClearAllPoints()
    listPanel:SetPoint("TOPLEFT", clearBtn, "BOTTOMLEFT", 0, -5)
    listPanel:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -5, 0)
    listPanel:SetHeight(250)
    StyleContentPanel(listPanel)

    local listScroll, listContent = OneWoW_GUI:CreateScrollFrame(listPanel, { name = "ErrorLoggerListScroll" })
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -14, 4)

    listScroll:HookScript("OnSizeChanged", function(self, w)
        listContent:SetWidth(w)
    end)

    tab.errorButtons = {}
    for i = 1, 100 do
        local btn = OneWoW_GUI:CreateListRowBasic(listContent, {
            height = 20,
            label = "",
            onClick = function(self)
                if Addon.ErrorLogger and self.errorData then
                    Addon.ErrorLogger:ShowErrorDetails(self.errorData)
                end
            end,
        })
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -(i-1) * 20 - 2)
        btn:SetPoint("RIGHT", listContent, "RIGHT", 0, 0)
        btn.label:SetFontObject(GameFontNormalSmall)

        tab.errorButtons[i] = btn
    end

    local detailsPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    detailsPanel:ClearAllPoints()
    detailsPanel:SetPoint("TOPLEFT", listPanel, "BOTTOMLEFT", 0, -5)
    detailsPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 35)
    StyleContentPanel(detailsPanel)

    local detailsScroll, detailsContent = OneWoW_GUI:CreateScrollFrame(detailsPanel, { name = "ErrorLoggerDetailsScroll" })
    detailsScroll:ClearAllPoints()
    detailsScroll:SetPoint("TOPLEFT", detailsPanel, "TOPLEFT", 4, -4)
    detailsScroll:SetPoint("BOTTOMRIGHT", detailsPanel, "BOTTOMRIGHT", -14, 4)

    detailsScroll:HookScript("OnSizeChanged", function(self, w)
        detailsContent:SetWidth(w)
    end)

    tab.detailsText = detailsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.detailsText:SetPoint("TOPLEFT", 2, -2)
    tab.detailsText:SetPoint("RIGHT", detailsContent, "RIGHT", -2, 0)
    tab.detailsText:SetJustifyH("LEFT")
    tab.detailsText:SetText(Addon.L and Addon.L["LABEL_NO_ERROR"] or "No error selected")
    tab.detailsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local copyBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_COPY_ERROR"] or "Copy Error", width = 100, height = 25 })
    copyBtn:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 5, 5)
    copyBtn:SetScript("OnClick", function()
        if Addon.ErrorLogger then
            Addon.ErrorLogger:CopyCurrentError()
        end
    end)

    tab.listScroll = listScroll
    tab.detailsScroll = detailsScroll
    tab.countLabel = countLabel

    tab:SetScript("OnShow", function()
        if Addon.ErrorLogger then
            Addon.ErrorLogger:UpdateUI()
        end
    end)

    Addon.LuaConsoleTab = tab
    return tab
end

function UI:CreateTextureTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    tab.atlasList = Addon:LoadBuiltInAtlases()
    tab.filteredList = {}
    for _, name in ipairs(tab.atlasList) do
        tinsert(tab.filteredList, name)
    end

    local searchBox = OneWoW_GUI:CreateEditBox(tab, {
        width = 200,
        height = 22,
        placeholderText = Addon.L and Addon.L["LABEL_FILTER"] or "Filter...",
        onTextChanged = function(text)
            UI:FilterAtlases(text)
        end,
    })
    searchBox:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)

    local favsBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_FAVORITES"] or "Favorites", width = 100, height = 22 })
    favsBtn:SetPoint("LEFT", searchBox, "RIGHT", 5, 0)
    favsBtn:SetScript("OnClick", function()
        UI:ShowFavorites()
    end)

    local bookmarkBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_BOOKMARK"] or "Bookmark", width = 100, height = 22 })
    bookmarkBtn:SetPoint("LEFT", favsBtn, "RIGHT", 5, 0)
    bookmarkBtn:SetScript("OnClick", function()
        UI:ToggleBookmark()
    end)

    local leftPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 320, height = 100 })
    leftPanel:ClearAllPoints()
    leftPanel:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -5)
    leftPanel:SetPoint("BOTTOM", tab, "BOTTOM", 0, 5)
    leftPanel:SetWidth(320)
    StyleContentPanel(leftPanel)

    local listScroll, listContent = OneWoW_GUI:CreateScrollFrame(leftPanel, { name = "TextureTabListScroll" })
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", -14, 4)

    listScroll:HookScript("OnSizeChanged", function(self, w)
        listContent:SetWidth(w)
    end)

    tab.listButtons = {}
    for i = 1, 30 do
        local btn = CreateFrame("Button", nil, listContent)
        btn:SetHeight(18)
        btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -(i-1) * 18)
        btn:SetPoint("RIGHT", listContent, "RIGHT", 0, 0)
        btn:SetNormalFontObject(GameFontNormalSmall)
        btn:SetHighlightFontObject(GameFontHighlightSmall)

        btn:SetScript("OnClick", function(self)
            if self.atlasName then
                UI:SelectAtlas(self.atlasName)
            end
        end)

        tab.listButtons[i] = btn
    end

    local rightPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    rightPanel:ClearAllPoints()
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 5, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)
    StyleContentPanel(rightPanel)

    tab.nameText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tab.nameText:SetPoint("TOP", 0, -5)
    tab.nameText:SetText("")
    tab.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local zoomInBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_ZOOM_IN"] or "+", width = 40, height = 22 })
    zoomInBtn:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -5, -5)
    zoomInBtn:SetScript("OnClick", function()
        UI:ZoomTexture(1.2)
    end)

    local zoomOutBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_ZOOM_OUT"] or "-", width = 40, height = 22 })
    zoomOutBtn:SetPoint("RIGHT", zoomInBtn, "LEFT", -2, 0)
    zoomOutBtn:SetScript("OnClick", function()
        UI:ZoomTexture(0.8)
    end)

    local resetBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_RESET_ZOOM"] or "Reset", width = 60, height = 22 })
    resetBtn:SetPoint("RIGHT", zoomOutBtn, "LEFT", -2, 0)
    resetBtn:SetScript("OnClick", function()
        UI:ResetTextureZoom()
    end)

    local previewBg = rightPanel:CreateTexture(nil, "BACKGROUND")
    previewBg:SetPoint("TOP", tab.nameText, "BOTTOM", 0, -10)
    previewBg:SetSize(400, 400)
    previewBg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))

    tab.previewFrame = CreateFrame("Frame", nil, rightPanel)
    tab.previewFrame:SetPoint("CENTER", previewBg, "CENTER")
    tab.previewFrame:SetSize(256, 256)

    tab.preview = tab.previewFrame:CreateTexture(nil, "ARTWORK")
    tab.preview:SetAllPoints(tab.previewFrame)

    local border = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    border:SetPoint("TOPLEFT", previewBg, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", previewBg, "BOTTOMRIGHT", 1, -1)
    border:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    border:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    border:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local infoPanel = OneWoW_GUI:CreateFrame(rightPanel, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    infoPanel:ClearAllPoints()
    infoPanel:SetPoint("TOPLEFT", previewBg, "BOTTOMLEFT", 0, -10)
    infoPanel:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -5, 35)
    StyleContentPanel(infoPanel)

    local infoScroll, infoContent = OneWoW_GUI:CreateScrollFrame(infoPanel, { name = "TextureTabInfoScroll" })
    infoScroll:ClearAllPoints()
    infoScroll:SetPoint("TOPLEFT", 4, -4)
    infoScroll:SetPoint("BOTTOMRIGHT", -14, 4)

    infoScroll:HookScript("OnSizeChanged", function(self, w)
        infoContent:SetWidth(w)
    end)

    tab.infoText = infoContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.infoText:SetPoint("TOPLEFT", 2, -2)
    tab.infoText:SetPoint("RIGHT", infoContent, "RIGHT", -2, 0)
    tab.infoText:SetJustifyH("LEFT")
    tab.infoText:SetText("")
    tab.infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    tab.infoScroll = infoScroll

    local copyBtn = OneWoW_GUI:CreateButton(rightPanel, { text = Addon.L and Addon.L["BTN_COPY_NAME"] or "Copy Name", width = 100, height = 22 })
    copyBtn:SetPoint("BOTTOMLEFT", rightPanel, "BOTTOMLEFT", 5, 5)
    copyBtn:SetScript("OnClick", function()
        if tab.currentAtlas then
            Addon:CopyToClipboard(tab.currentAtlas)
        end
    end)

    tab.listScroll = listScroll
    tab.zoomLevel = 1.0
    tab.selectedIndex = 1

    tab:SetScript("OnKeyDown", function(self, key)
        if key == "UP" then
            UI:NavigateAtlasList(-1)
        elseif key == "DOWN" then
            UI:NavigateAtlasList(1)
        end
    end)

    tab:EnableKeyboard(true)
    tab:SetPropagateKeyboardInput(false)

    self:UpdateAtlasList()

    if #tab.atlasList > 0 then
        self:SelectAtlas(tab.atlasList[1])
    end

    Addon.TextureBrowserTab = tab
    return tab
end

function UI:NavigateAtlasList(direction)
    local tab = Addon.TextureBrowserTab
    if not tab or #tab.filteredList == 0 then return end

    tab.selectedIndex = tab.selectedIndex + direction

    if tab.selectedIndex < 1 then
        tab.selectedIndex = 1
    elseif tab.selectedIndex > #tab.filteredList then
        tab.selectedIndex = #tab.filteredList
    end

    local atlasName = tab.filteredList[tab.selectedIndex]
    if atlasName then
        self:SelectAtlas(atlasName)
        self:UpdateAtlasList()
    end
end

function UI:ZoomTexture(factor)
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    tab.zoomLevel = tab.zoomLevel * factor
    tab.zoomLevel = math.max(0.25, math.min(4.0, tab.zoomLevel))

    local newSize = 256 * tab.zoomLevel
    tab.previewFrame:SetSize(newSize, newSize)
end

function UI:ResetTextureZoom()
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    tab.zoomLevel = 1.0
    tab.previewFrame:SetSize(256, 256)
end

function UI:FilterAtlases(filter)
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    filter = (filter or ""):lower()
    tab.filteredList = {}

    if filter == "" then
        for _, name in ipairs(tab.atlasList) do
            tinsert(tab.filteredList, name)
        end
    else
        for _, name in ipairs(tab.atlasList) do
            if name:lower():find(filter, 1, true) then
                tinsert(tab.filteredList, name)
            end
        end
    end

    self:UpdateAtlasList()
end

function UI:UpdateAtlasList()
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    for i, btn in ipairs(tab.listButtons) do
        local name = tab.filteredList[i]
        if name then
            btn:SetText(name)
            btn.atlasName = name

            if name == tab.currentAtlas then
                btn:SetNormalFontObject(GameFontHighlight)
                btn:LockHighlight()
            else
                btn:SetNormalFontObject(GameFontNormalSmall)
                btn:UnlockHighlight()
            end

            btn:Show()
        else
            btn:Hide()
        end
    end

    local height = math.max(#tab.filteredList * 18 + 5, tab.listScroll:GetHeight())
    tab.listScroll:GetScrollChild():SetHeight(height)
end

function UI:SelectAtlas(atlasName)
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    for i, name in ipairs(tab.filteredList) do
        if name == atlasName then
            tab.selectedIndex = i
            break
        end
    end

    local info = C_Texture.GetAtlasInfo(atlasName)

    if info then
        tab.currentAtlas = atlasName
        tab.preview:SetAtlas(atlasName)
        tab.preview:Show()
        tab.nameText:SetText(atlasName)

        self:UpdateAtlasList()

        local isBookmarked = Addon.db.textureBookmarks and Addon.db.textureBookmarks[atlasName]

        local details = {}
        tinsert(details, (L["LABEL_WIDTH"] or "Width:") .. " " .. (info.width or 0))
        tinsert(details, (L["LABEL_HEIGHT"] or "Height:") .. " " .. (info.height or 0))
        tinsert(details, "")
        tinsert(details, (L["LABEL_FILE"] or "File:") .. " " .. (info.file or info.filename or L["LABEL_UNKNOWN"] or "Unknown"))

        if info.leftTexCoord then
            tinsert(details, "")
            tinsert(details, L["LABEL_TEX_COORDS"] or "Texture Coordinates:")
            tinsert(details, string.format((L["LABEL_LEFT"] or "  Left:") .. " %.4f", info.leftTexCoord))
            tinsert(details, string.format((L["LABEL_RIGHT"] or "  Right:") .. " %.4f", info.rightTexCoord))
            tinsert(details, string.format((L["LABEL_TOP"] or "  Top:") .. " %.4f", info.topTexCoord))
            tinsert(details, string.format((L["LABEL_BOTTOM"] or "  Bottom:") .. " %.4f", info.bottomTexCoord))
        end

        if info.tilesHorizontally or info.tilesVertically then
            tinsert(details, "")
            tinsert(details, string.format((L["LABEL_TILES"] or "Tiles:") .. " %s x %s",
                tostring(info.tilesHorizontally or false),
                tostring(info.tilesVertically or false)))
        end

        if isBookmarked then
            tinsert(details, "")
            tinsert(details, "|cff00ff00[" .. (L["LABEL_BOOKMARKED"] or "Bookmarked") .. "]|r")
        end

        tab.infoText:SetText(table.concat(details, "\n"))

        local height = tab.infoText:GetStringHeight()
        tab.infoScroll:GetScrollChild():SetHeight(math.max(height + 10, tab.infoScroll:GetHeight()))
    end
end

function UI:ToggleBookmark()
    local tab = Addon.TextureBrowserTab
    if not tab or not tab.currentAtlas then
        Addon:Print(Addon.L and Addon.L["MSG_SELECT_ATLAS"] or "Select an atlas first")
        return
    end

    if not Addon.db.textureBookmarks then
        Addon.db.textureBookmarks = {}
    end

    local name = tab.currentAtlas

    if Addon.db.textureBookmarks[name] then
        Addon.db.textureBookmarks[name] = nil
        Addon:Print((Addon.L and Addon.L["MSG_REMOVED_BOOKMARK"] or "Removed: ") .. name)
    else
        Addon.db.textureBookmarks[name] = true
        Addon:Print((Addon.L and Addon.L["MSG_BOOKMARKED"] or "Bookmarked: ") .. name)
    end

    self:SelectAtlas(name)
end

function UI:ShowFavorites()
    local tab = Addon.TextureBrowserTab
    if not tab then return end

    if not Addon.db.textureBookmarks then
        Addon:Print(Addon.L and Addon.L["MSG_NO_BOOKMARKS"] or "No bookmarks yet")
        return
    end

    tab.filteredList = {}
    for name, _ in pairs(Addon.db.textureBookmarks) do
        tinsert(tab.filteredList, name)
    end

    sort(tab.filteredList)
    self:UpdateAtlasList()
end

function UI:CreateColorTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    if Addon.ColorToolsTab and Addon.ColorToolsTab.Initialize then
        Addon.ColorToolsTab:Initialize(tab)
    end

    return tab
end

function UI:CreateLayoutTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local gridLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    gridLabel:SetPoint("TOPLEFT", tab, "TOPLEFT", 10, -10)
    gridLabel:SetText(Addon.L and Addon.L["LABEL_GRID_OVERLAY"] or "Grid Overlay")
    gridLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local toggleBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_TOGGLE_GRID"] or "Toggle Grid", width = 120, height = 25 })
    toggleBtn:SetPoint("TOPLEFT", gridLabel, "BOTTOMLEFT", 0, -10)
    toggleBtn:SetScript("OnClick", function()
        UI:ToggleGrid()
    end)

    local sizeLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", toggleBtn, "BOTTOMLEFT", 0, -15)
    sizeLabel:SetText((Addon.L and Addon.L["LABEL_GRID_SIZE"] or "Grid Size:") .. " 50")
    sizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local sizeContainer = OneWoW_GUI:CreateSlider(tab, {
        minVal = 10,
        maxVal = 200,
        step = 10,
        currentVal = 50,
        width = 200,
        fmt = "%.0f",
        onChange = function(value)
            sizeLabel:SetText((Addon.L and Addon.L["LABEL_GRID_SIZE"] or "Grid Size:") .. " " .. value)
            tab.gridSize = value
            if tab.gridActive then
                UI:UpdateGridOverlay()
            end
        end,
    })
    sizeContainer:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -5)

    local opacityLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opacityLabel:SetPoint("TOPLEFT", sizeContainer, "BOTTOMLEFT", 0, -15)
    opacityLabel:SetText((Addon.L and Addon.L["LABEL_OPACITY"] or "Opacity:") .. " 0.3")
    opacityLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local opacityContainer = OneWoW_GUI:CreateSlider(tab, {
        minVal = 0.1,
        maxVal = 1.0,
        step = 0.1,
        currentVal = 0.3,
        width = 200,
        fmt = "%.1f",
        onChange = function(value)
            opacityLabel:SetText((Addon.L and Addon.L["LABEL_OPACITY"] or "Opacity:") .. " " .. string.format("%.1f", value))
            tab.gridOpacity = value
            if tab.gridActive then
                UI:UpdateGridOverlay()
            end
        end,
    })
    opacityContainer:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 0, -5)

    local centerBtn = OneWoW_GUI:CreateButton(tab, { text = Addon.L and Addon.L["BTN_TOGGLE_CENTER"] or "Toggle Center Lines", width = 150, height = 25 })
    centerBtn:SetPoint("TOPLEFT", opacityContainer, "BOTTOMLEFT", 0, -20)
    centerBtn:SetScript("OnClick", function()
        UI:ToggleCenterLines()
    end)

    tab.gridSize = 50
    tab.gridOpacity = 0.3
    tab.gridActive = false
    tab.centerActive = false

    Addon.LayoutToolsTab = tab
    return tab
end

function UI:ToggleGrid()
    local tab = Addon.LayoutToolsTab

    if not tab.gridActive then
        if not self.gridFrame then
            self.gridFrame = CreateFrame("Frame", nil, UIParent)
            self.gridFrame:SetAllPoints()
            self.gridFrame:SetFrameStrata("BACKGROUND")
            self.gridFrame:EnableMouse(false)
            self.gridFrame.lines = {}
        end

        self:UpdateGridOverlay()
        self.gridFrame:Show()
        tab.gridActive = true
        Addon:Print(Addon.L and Addon.L["MSG_GRID_ENABLED"] or "Grid enabled")
    else
        if self.gridFrame then
            for _, line in ipairs(self.gridFrame.lines) do
                line:Hide()
            end
            self.gridFrame:Hide()
        end
        tab.gridActive = false
        Addon:Print(Addon.L and Addon.L["MSG_GRID_DISABLED"] or "Grid disabled")
    end
end

function UI:UpdateGridOverlay()
    if not self.gridFrame then return end

    local tab = Addon.LayoutToolsTab
    if not tab then return end

    for _, line in ipairs(self.gridFrame.lines) do
        line:Hide()
    end

    local width = GetScreenWidth()
    local height = GetScreenHeight()
    local gridSize = tab.gridSize or 50
    local opacity = tab.gridOpacity or 0.3
    local lineIndex = 1

    for x = 0, width, gridSize do
        if lineIndex > #self.gridFrame.lines then
            local line = self.gridFrame:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(1, 1, 1, opacity)
            tinsert(self.gridFrame.lines, line)
        end

        local line = self.gridFrame.lines[lineIndex]
        line:SetColorTexture(1, 1, 1, opacity)
        line:SetSize(1, height)
        line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 0)
        line:Show()
        lineIndex = lineIndex + 1
    end

    for y = 0, height, gridSize do
        if lineIndex > #self.gridFrame.lines then
            local line = self.gridFrame:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(1, 1, 1, opacity)
            tinsert(self.gridFrame.lines, line)
        end

        local line = self.gridFrame.lines[lineIndex]
        line:SetColorTexture(1, 1, 1, opacity)
        line:SetSize(width, 1)
        line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, y)
        line:Show()
        lineIndex = lineIndex + 1
    end
end

function UI:ToggleCenterLines()
    local tab = Addon.LayoutToolsTab

    if not tab.centerActive then
        if not self.centerFrame then
            self.centerFrame = CreateFrame("Frame", nil, UIParent)
            self.centerFrame:SetAllPoints()
            self.centerFrame:SetFrameStrata("BACKGROUND")
            self.centerFrame:EnableMouse(false)

            self.centerV = self.centerFrame:CreateTexture(nil, "ARTWORK")
            self.centerV:SetColorTexture(1, 0, 0, 0.5)
            self.centerV:SetSize(2, GetScreenHeight())
            self.centerV:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

            self.centerH = self.centerFrame:CreateTexture(nil, "ARTWORK")
            self.centerH:SetColorTexture(1, 0, 0, 0.5)
            self.centerH:SetSize(GetScreenWidth(), 2)
            self.centerH:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end

        self.centerFrame:Show()
        tab.centerActive = true
        Addon:Print(Addon.L and Addon.L["MSG_CENTER_LINES_ENABLED"] or "Center lines enabled")
    else
        if self.centerFrame then
            self.centerFrame:Hide()
        end
        tab.centerActive = false
        Addon:Print(Addon.L and Addon.L["MSG_CENTER_LINES_DISABLED"] or "Center lines disabled")
    end
end

function UI:ShowEventSelector()
    if not self.eventSelector then
        local frame = OneWoW_GUI:CreateFrame(UIParent, {
            width = 600,
            height = 500,
            backdrop = BACKDROP_INNER_NO_INSETS,
        })
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.title:SetPoint("TOP", 0, -5)
        frame.title:SetText(Addon.L and Addon.L["DIALOG_TITLE_SELECT_EVENTS"] or "Event Monitor - Select Events")
        frame.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local commonBtn = OneWoW_GUI:CreateButton(frame, { text = Addon.L and Addon.L["BTN_COMMON_EVENTS"] or "Common Events", width = 110, height = 25 })
        commonBtn:SetPoint("TOPLEFT", 10, -30)
        commonBtn:SetScript("OnClick", function()
            Addon.EventMonitor:RegisterCommonEvents()
            UI:UpdateEventSelector()
            Addon:Print((Addon.L and Addon.L["MSG_ADDED_COMMON_EVENTS"] or "Added common events ({count} total)"):gsub("{count}", Addon.EventMonitor:GetEventCount()))
        end)

        local selectAllBtn = OneWoW_GUI:CreateButton(frame, { text = Addon.L and Addon.L["BTN_SELECT_ALL"] or "Select All", width = 80, height = 25 })
        selectAllBtn:SetPoint("LEFT", commonBtn, "RIGHT", 5, 0)
        selectAllBtn:SetScript("OnClick", function()
            UI:SelectAllEvents()
            Addon:Print((Addon.L and Addon.L["MSG_SELECTED_ALL_EVENTS"] or "Selected all events ({count} total)"):gsub("{count}", Addon.EventMonitor:GetEventCount()))
        end)

        local clearAllBtn = OneWoW_GUI:CreateButton(frame, { text = Addon.L and Addon.L["BTN_CLEAR_ALL"] or "Clear All", width = 80, height = 25 })
        clearAllBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 5, 0)
        clearAllBtn:SetScript("OnClick", function()
            Addon.EventMonitor.selectedEvents = {}
            UI:UpdateEventSelector()
            Addon:Print(Addon.L and Addon.L["MSG_CLEARED_ALL_EVENTS"] or "Cleared all events")
        end)

        local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        searchLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -215, -37)
        searchLabel:SetText((Addon.L and Addon.L["LABEL_FILTER"] or "Search:"))
        searchLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local searchBox = OneWoW_GUI:CreateEditBox(frame, {
            width = 180,
            height = 25,
            placeholderText = Addon.L and Addon.L["LABEL_FILTER"] or "Filter...",
            onTextChanged = function()
                UI:UpdateEventSelector()
            end,
        })
        searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 5, 0)

        local eventCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        eventCount:SetPoint("TOPLEFT", commonBtn, "BOTTOMLEFT", 0, -8)
        eventCount:SetText((Addon.L and Addon.L["LABEL_SELECTED"] or "Selected:") .. " 0")
        eventCount:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local leftPanel = OneWoW_GUI:CreateFrame(frame, { backdrop = BACKDROP_INNER_NO_INSETS, width = 280, height = 100 })
        leftPanel:ClearAllPoints()
        leftPanel:SetPoint("TOPLEFT", eventCount, "BOTTOMLEFT", 0, -8)
        leftPanel:SetPoint("BOTTOM", frame, "BOTTOM", 0, 40)
        leftPanel:SetWidth(280)
        StyleContentPanel(leftPanel)

        local leftTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        leftTitle:SetPoint("TOP", 0, -5)
        leftTitle:SetText(Addon.L and Addon.L["LABEL_EVENT_LIST"] or "Event List")
        leftTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local leftScroll, leftContent = OneWoW_GUI:CreateScrollFrame(leftPanel, { name = "EventSelectorLeftScroll" })
        leftScroll:ClearAllPoints()
        leftScroll:SetPoint("TOPLEFT", 4, -25)
        leftScroll:SetPoint("BOTTOMRIGHT", -14, 4)

        leftScroll:HookScript("OnSizeChanged", function(self, w)
            leftContent:SetWidth(w)
        end)

        frame.eventButtons = {}
        frame.eventRowHeight = 26
        local commonCount = #Addon.EventMonitor:GetCommonEvents()
        local poolSize = commonCount + (Addon.Constants.EVENT_SELECTOR_CUSTOM_BUFFER or 100)
        for i = 1, poolSize do
            local btn = OneWoW_GUI:CreateCheckbox(leftContent, { label = "" })
            btn:SetPoint("TOPLEFT", 5, -(i-1) * frame.eventRowHeight - 5)

            btn:SetScript("OnClick", function(self)
                if self.eventName then
                    Addon.EventMonitor:ToggleEvent(self.eventName)
                    UI:UpdateEventSelector()
                end
            end)

            frame.eventButtons[i] = btn
        end

        local rightPanel = OneWoW_GUI:CreateFrame(frame, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
        rightPanel:ClearAllPoints()
        rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 5, 0)
        rightPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 40)
        StyleContentPanel(rightPanel)

        local rightTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rightTitle:SetPoint("TOP", 0, -5)
        rightTitle:SetText(Addon.L and Addon.L["LABEL_CUSTOM_ATLAS"] or "Custom Event")
        rightTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local customLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        customLabel:SetPoint("TOPLEFT", 10, -30)
        customLabel:SetText(Addon.L and Addon.L["LABEL_ENTER_EVENT"] or "Enter event name:")
        customLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local customBox = OneWoW_GUI:CreateEditBox(rightPanel, {
            width = 180,
            height = 25,
            placeholderText = Addon.L and Addon.L["LABEL_ENTER_EVENT"] or "Event name...",
        })
        customBox:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 0, -5)

        local addBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, { text = Addon.L and Addon.L["BTN_ADD_EVENT"] or "Add", height = 25 })
        addBtn:SetPoint("LEFT", customBox, "RIGHT", 5, 0)
        addBtn:SetScript("OnClick", function()
            local eventName = customBox:GetSearchText()
            if eventName and eventName ~= "" then
                Addon.EventMonitor:ToggleEvent(eventName:upper())
                customBox:SetText(customBox.placeholderText or "")
                customBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                UI:UpdateEventSelector()
                Addon:Print((Addon.L and Addon.L["MSG_ADDED_EVENT"] or "Added event: {event}"):gsub("{event}", eventName:upper()))
            end
        end)

        local helpText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        helpText:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 0, -40)
        helpText:SetPoint("RIGHT", rightPanel, "RIGHT", -10, 0)
        helpText:SetJustifyH("LEFT")
        helpText:SetText(Addon.L and Addon.L["HELP_TEXT_EVENTS"] or "Enter any WoW event name to monitor.\n\nCommon events:\nPLAYER_ENTERING_WORLD\nZONE_CHANGED\nPLAYER_REGEN_DISABLED\nPLAYER_REGEN_ENABLED\nBAG_UPDATE\nUNIT_HEALTH\nCHAT_MSG_SAY\nADDON_LOADED\n\nYou can find more events on:\nwarcraft.wiki.gg")
        helpText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local closeBtn = OneWoW_GUI:CreateButton(frame, { text = Addon.L and Addon.L["BTN_CLOSE"] or "Close", width = 80, height = 25 })
        closeBtn:SetPoint("BOTTOM", 0, 10)
        closeBtn:SetScript("OnClick", function()
            frame:Hide()
        end)

        frame.leftScroll = leftScroll
        frame.searchBox = searchBox
        frame.eventCount = eventCount

        self.eventSelector = frame

        Addon.EventMonitor:RegisterCommonEvents()
    end

    self:UpdateEventSelector()
    self.eventSelector:Show()
end

function UI:SelectAllEvents()
    for _, event in ipairs(Addon.EventMonitor:GetCommonEvents()) do
        Addon.EventMonitor.selectedEvents[event] = true
    end

    self:UpdateEventSelector()
end

function UI:UpdateEventSelector()
    if not self.eventSelector then return end

    local frame = self.eventSelector
    local searchText = (frame.searchBox:GetSearchText() or ""):upper()

    local allEvents = {}
    for _, event in ipairs(Addon.EventMonitor:GetCommonEvents()) do
        tinsert(allEvents, event)
    end

    for event in pairs(Addon.EventMonitor.selectedEvents) do
        local exists = false
        for _, e in ipairs(allEvents) do
            if e == event then
                exists = true
                break
            end
        end
        if not exists then
            tinsert(allEvents, event)
        end
    end

    sort(allEvents)

    local filteredEvents = {}
    for _, event in ipairs(allEvents) do
        if searchText == "" or string.find(event, searchText, 1, true) then
            tinsert(filteredEvents, event)
        end
    end

    local rowHeight = frame.eventRowHeight or 26
    for i, btn in ipairs(frame.eventButtons) do
        local event = filteredEvents[i]
        if event then
            btn.eventName = event
            btn.label:SetText(event)
            btn:SetChecked(Addon.EventMonitor:IsEventRegistered(event))
            btn:Show()
        else
            btn:Hide()
        end
    end

    local height = math.max(#filteredEvents * rowHeight + 10, frame.leftScroll:GetHeight())
    frame.leftScroll:GetScrollChild():SetHeight(height)

    frame.eventCount:SetText((Addon.L and Addon.L["LABEL_SELECTED"] or "Selected:") .. " " .. Addon.EventMonitor:GetEventCount())
end

function UI:CreateMonitorTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local Monitor = Addon.MonitorTab

    if Monitor then
        Monitor:Initialize()
    end

    local ROW_HEIGHT = 20
    local MAX_ROWS = 60

    local playBtn = OneWoW_GUI:CreateButton(tab, { text = L["MON_BTN_PLAY"] or "Play", width = 80, height = 22 })
    playBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)

    local updateBtn = OneWoW_GUI:CreateButton(tab, { text = L["MON_BTN_UPDATE"] or "Update", width = 80, height = 22 })
    updateBtn:SetPoint("LEFT", playBtn, "RIGHT", 5, 0)

    local resetBtn = OneWoW_GUI:CreateButton(tab, { text = L["MON_BTN_RESET"] or "Reset", width = 80, height = 22 })
    resetBtn:SetPoint("LEFT", updateBtn, "RIGHT", 5, 0)

    local cpuCheck = OneWoW_GUI:CreateCheckbox(tab, { label = L["MON_LABEL_CPU_PROFILING"] or "CPU Profiling" })
    cpuCheck:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    cpuCheck:SetChecked(Monitor and Monitor:IsCPUProfilingEnabled() or false)

    local showOnLoadCheck = OneWoW_GUI:CreateCheckbox(tab, { label = L["MON_LABEL_SHOW_ON_LOAD"] or "Show on Load" })
    showOnLoadCheck:SetPoint("LEFT", cpuCheck.label, "RIGHT", 15, 0)
    showOnLoadCheck:SetChecked(Addon.db and Addon.db.monitor and Addon.db.monitor.showOnLoad or false)

    local filterLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("TOPLEFT", playBtn, "BOTTOMLEFT", 0, -8)
    filterLabel:SetText(L["MON_LABEL_FILTER"] or "Filter:")
    filterLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local filterBox = OneWoW_GUI:CreateEditBox(tab, {
        width = 150,
        height = 22,
        placeholderText = L["MON_LABEL_FILTER"] or "Filter...",
        onTextChanged = function(text)
            if Monitor then
                Monitor:SetFilter(text)
                Monitor:GetSortedList()
                tab:RefreshList()
            end
        end,
    })
    filterBox:SetPoint("LEFT", filterLabel, "RIGHT", 5, 0)

    local hasCPU = Monitor and Monitor:IsCPUProfilingEnabled() or false

    local headerFrame = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_SIMPLE, width = 100, height = 22 })
    headerFrame:ClearAllPoints()
    headerFrame:SetPoint("TOPLEFT", playBtn, "BOTTOMLEFT", 0, -35)
    headerFrame:SetPoint("RIGHT", tab, "RIGHT", -5, 0)
    headerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local nameHeader = CreateFrame("Button", nil, headerFrame)
    nameHeader:SetPoint("LEFT", headerFrame, "LEFT", 5, 0)
    nameHeader:SetHeight(22)
    nameHeader.text = nameHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameHeader.text:SetPoint("LEFT", 0, 0)
    nameHeader.text:SetText(L["MON_HEADER_NAME"] or "Addon")
    nameHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local memHeader = CreateFrame("Button", nil, headerFrame)
    memHeader:SetSize(90, 22)
    memHeader.text = memHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    memHeader.text:SetPoint("RIGHT", 0, 0)
    memHeader.text:SetText(L["MON_HEADER_MEMORY"] or "Memory (k)")
    memHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local memPctHeader = CreateFrame("Button", nil, headerFrame)
    memPctHeader:SetSize(55, 22)
    memPctHeader.text = memPctHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    memPctHeader.text:SetPoint("RIGHT", 0, 0)
    memPctHeader.text:SetText(L["MON_HEADER_MEM_PCT"] or "Mem %")
    memPctHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local cpuHeader = CreateFrame("Button", nil, headerFrame)
    cpuHeader:SetSize(90, 22)
    cpuHeader.text = cpuHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cpuHeader.text:SetPoint("RIGHT", 0, 0)
    cpuHeader.text:SetText(L["MON_HEADER_CPU"] or "CPU (ms/s)")
    cpuHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local cpuPctHeader = CreateFrame("Button", nil, headerFrame)
    cpuPctHeader:SetSize(55, 22)
    cpuPctHeader.text = cpuPctHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cpuPctHeader.text:SetPoint("RIGHT", -14, 0)
    cpuPctHeader.text:SetText(L["MON_HEADER_CPU_PCT"] or "CPU %")
    cpuPctHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    if hasCPU then
        cpuPctHeader:SetPoint("RIGHT", headerFrame, "RIGHT", 0, 0)
        cpuHeader:SetPoint("RIGHT", cpuPctHeader, "LEFT", -5, 0)
        memPctHeader:SetPoint("RIGHT", cpuHeader, "LEFT", -5, 0)
        memHeader:SetPoint("RIGHT", memPctHeader, "LEFT", -5, 0)
    else
        cpuPctHeader:Hide()
        cpuHeader:Hide()
        memPctHeader:SetPoint("RIGHT", headerFrame, "RIGHT", -14, 0)
        memHeader:SetPoint("RIGHT", memPctHeader, "LEFT", -5, 0)
    end

    nameHeader:SetPoint("RIGHT", memHeader, "LEFT", -5, 0)

    nameHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(1); Monitor:GetSortedList(); tab:RefreshList() end
    end)
    memHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(2); Monitor:GetSortedList(); tab:RefreshList() end
    end)
    memPctHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(2); Monitor:GetSortedList(); tab:RefreshList() end
    end)
    cpuHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(3); Monitor:GetSortedList(); tab:RefreshList() end
    end)
    cpuPctHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(3); Monitor:GetSortedList(); tab:RefreshList() end
    end)

    local listPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    listPanel:ClearAllPoints()
    listPanel:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
    listPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 35)
    StyleContentPanel(listPanel)

    local listScroll, listContent = OneWoW_GUI:CreateScrollFrame(listPanel, { name = "MonitorTabListScroll" })
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 0, 0)
    listScroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -14, 0)

    listScroll:HookScript("OnSizeChanged", function(self, w)
        listContent:SetWidth(w)
    end)

    tab.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, listContent)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", listContent, "RIGHT", 0, 0)

        row.stripe = row:CreateTexture(nil, "BACKGROUND")
        row.stripe:SetAllPoints()
        if i % 2 == 0 then
            row.stripe:SetColorTexture(1, 1, 1, 0.03)
        else
            row.stripe:SetColorTexture(0, 0, 0, 0)
        end

        row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        row.highlight:SetAlpha(0.15)

        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameText:SetPoint("LEFT", row, "LEFT", 5, 0)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        row.memText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.memText:SetJustifyH("RIGHT")
        row.memText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row.memPctText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.memPctText:SetJustifyH("RIGHT")
        row.memPctText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        row.cpuText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cpuText:SetJustifyH("RIGHT")
        row.cpuText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row.cpuPctText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cpuPctText:SetJustifyH("RIGHT")
        row.cpuPctText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        if hasCPU then
            row.cpuPctText:SetPoint("RIGHT", row, "RIGHT", -14, 0)
            row.cpuPctText:SetWidth(55)
            row.cpuText:SetPoint("RIGHT", row.cpuPctText, "LEFT", -5, 0)
            row.cpuText:SetWidth(90)
            row.memPctText:SetPoint("RIGHT", row.cpuText, "LEFT", -5, 0)
            row.memPctText:SetWidth(55)
            row.memText:SetPoint("RIGHT", row.memPctText, "LEFT", -5, 0)
            row.memText:SetWidth(90)
        else
            row.cpuText:Hide()
            row.cpuPctText:Hide()
            row.memPctText:SetPoint("RIGHT", row, "RIGHT", -14, 0)
            row.memPctText:SetWidth(55)
            row.memText:SetPoint("RIGHT", row.memPctText, "LEFT", -5, 0)
            row.memText:SetWidth(90)
        end

        row.nameText:SetPoint("RIGHT", row.memText, "LEFT", -5, 0)

        row:Hide()
        tab.rows[i] = row
    end

    local totalsBar = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_SIMPLE, width = 100, height = 25 })
    totalsBar:ClearAllPoints()
    totalsBar:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 5, 5)
    totalsBar:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)
    totalsBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    tab.totalsText = totalsBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.totalsText:SetPoint("LEFT", totalsBar, "LEFT", 10, 0)
    tab.totalsText:SetText("")
    tab.totalsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    tab.noDataText = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.noDataText:SetPoint("CENTER", listPanel, "CENTER", 0, 0)
    tab.noDataText:SetText(L["MON_MSG_NO_DATA"] or "Click 'Update' or 'Play' to begin monitoring")
    tab.noDataText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    function tab:RefreshList()
        if not Monitor then return end
        local list = Monitor:GetDisplayedList()
        local t = Monitor:GetTotals()

        if t.count == 0 then
            tab.noDataText:Show()
        else
            tab.noDataText:Hide()
        end

        for i = 1, MAX_ROWS do
            local row = tab.rows[i]
            local info = list[i]
            if info then
                row.nameText:SetText(info.title)
                row.memText:SetText(Monitor:FormatMemory(info.memory))
                row.memPctText:SetText(Monitor:FormatPercent(info.memPercent))
                if hasCPU then
                    row.cpuText:SetText(Monitor:FormatCPU(info.cpuPerSec))
                    row.cpuPctText:SetText(Monitor:FormatPercent(info.cpuPercent))
                end
                row:Show()
            else
                row:Hide()
            end
        end

        local contentHeight = math.max(#list * ROW_HEIGHT + 5, listScroll:GetHeight())
        listContent:SetHeight(contentHeight)

        local cpuTotalPerSec = 0
        if t.duration > 0 then
            cpuTotalPerSec = t.cpu / t.duration
        end

        local totalsStr = (L["MON_TOTALS_ADDONS"] or "Addons:") .. " " .. t.count ..
            "    " .. (L["MON_TOTALS_MEMORY"] or "Memory:") .. " " .. Monitor:FormatMemory(t.memory) .. " k"
        if hasCPU then
            totalsStr = totalsStr .. "    " .. (L["MON_TOTALS_CPU"] or "CPU:") .. " " .. Monitor:FormatCPU(cpuTotalPerSec) .. " ms/s"
        end
        tab.totalsText:SetText(totalsStr)
    end

    local function DoUpdate()
        if Monitor then
            Monitor:GatherUsage()
            Monitor:GetSortedList()
            tab:RefreshList()
        end
    end

    playBtn:SetScript("OnClick", function()
        if not Monitor then return end
        Monitor:ToggleMonitoring()
        if Monitor:IsMonitoring() then
            playBtn.text:SetText(L["MON_BTN_PAUSE"] or "Pause")
            DoUpdate()
        else
            playBtn.text:SetText(L["MON_BTN_PLAY"] or "Play")
        end
    end)

    updateBtn:SetScript("OnClick", function()
        DoUpdate()
    end)

    resetBtn:SetScript("OnClick", function()
        if Monitor then
            Monitor:Reset()
            DoUpdate()
            Addon:Print(L["MON_MSG_RESET"] or "Memory collected and CPU usage reset")
        end
    end)

    cpuCheck:SetScript("OnClick", function()
        if Monitor then
            StaticPopupDialogs["ONEWOW_DEVTOOL_CPU_RELOAD"] = {
                text = L["MON_CPU_RELOAD_CONFIRM"] or "Changing CPU profiling requires a UI reload. Reload now?",
                button1 = YES,
                button2 = NO,
                OnAccept = function()
                    Monitor:ToggleCPUProfiling()
                end,
                OnCancel = function()
                    cpuCheck:SetChecked(Monitor:IsCPUProfilingEnabled())
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("ONEWOW_DEVTOOL_CPU_RELOAD")
        end
    end)

    showOnLoadCheck:SetScript("OnClick", function(self)
        if Addon.db and Addon.db.monitor then
            Addon.db.monitor.showOnLoad = self:GetChecked() and true or false
        end
    end)

    tab:SetScript("OnUpdate", function(self, elapsed)
        if Monitor then
            local wasMonitoring = Monitor:IsMonitoring()
            Monitor:OnUpdate(elapsed)
            if wasMonitoring then
                Monitor:GetSortedList()
            end
        end
    end)

    Addon.MonitorTabUI = tab
    return tab
end

function UI:CreateSettingsTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    OneWoW_GUI:CreateSettingsPanel(tab, { yOffset = -10, addonName = "OneWoW_UtilityDevTool" })

    return tab
end

function UI:ShowEventImportDialog()
    if not self.importDialog then
        local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetSize(650, 480)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -8)
        title:SetText("Import Events to Monitor")
        title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local instrLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        instrLabel:SetPoint("TOPLEFT", 10, -28)
        instrLabel:SetText("Paste event search output below, then click Import:")
        instrLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local panel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        panel:SetPoint("TOPLEFT", 10, -48)
        panel:SetPoint("BOTTOMRIGHT", -10, 58)
        StyleContentPanel(panel)

        local editScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        editScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
        editScroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 4)
        OneWoW_GUI:StyleScrollBar(editScroll, { container = panel })

        local editBox = CreateFrame("EditBox", nil, editScroll)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(GameFontNormalSmall)
        editBox:SetHeight(400)
        editBox:SetMaxLetters(0)
        editBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        editScroll:SetScrollChild(editBox)

        editScroll:HookScript("OnSizeChanged", function(self, w)
            editBox:SetWidth(w)
        end)

        local statusLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        statusLabel:SetPoint("BOTTOMLEFT", 10, 33)
        statusLabel:SetText("")
        statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

        local importBtn = OneWoW_GUI:CreateButton(frame, { text = "Import Events", width = 120, height = 26 })
        importBtn:SetPoint("BOTTOMRIGHT", -100, 8)
        importBtn:SetScript("OnClick", function()
            local text = editBox:GetText()
            if not text or text == "" then
                statusLabel:SetText("Nothing to import - paste event output first")
                return
            end
            local count = Addon.EventMonitor:ImportEvents(text)
            if count == 0 then
                statusLabel:SetText("No events found in pasted text")
            else
                statusLabel:SetText("Imported " .. count .. " event(s) - now monitoring")
                if not Addon.EventMonitor.monitoring then
                    Addon.EventMonitor:Start()
                end
            end
        end)

        local cancelBtn = OneWoW_GUI:CreateButton(frame, { text = "Close", width = 80, height = 26 })
        cancelBtn:SetPoint("BOTTOMRIGHT", -10, 8)
        cancelBtn:SetScript("OnClick", function()
            frame:Hide()
        end)

        frame.editBox = editBox
        frame.statusLabel = statusLabel
        self.importDialog = frame
    end

    self.importDialog.editBox:SetText("")
    self.importDialog.statusLabel:SetText("")
    self.importDialog:Show()
    self.importDialog.editBox:SetFocus()
end

function UI:Show()
    self:Initialize()
    self.mainFrame:Show()
end

function UI:Hide()
    if self.mainFrame then
        self.mainFrame:Hide()
    end
end

function UI:FullReset()
    if self.mainFrame then
        self.mainFrame:Hide()
        self.mainFrame = nil
    end
end

return UI
