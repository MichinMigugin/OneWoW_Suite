local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local CreateFrame = CreateFrame

local Constants = OneWoW_GUI.Constants

function OneWoW_GUI:CreateFilterBar(parent, config)
    config = config or {}
    local height = config.height or 40
    local anchorBelow = config.anchorBelow
    local offset = config.offset or -5

    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if anchorBelow then
        bar:SetPoint("TOPLEFT", anchorBelow, "BOTTOMLEFT", 0, offset)
        bar:SetPoint("TOPRIGHT", anchorBelow, "BOTTOMRIGHT", 0, offset)
    else
        bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, offset)
        bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, offset)
    end
    bar:SetHeight(height)
    bar:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    bar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    bar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    return bar
end

function OneWoW_GUI:CreateSortControls(parent, options)
    options = options or {}
    local sortFields   = options.sortFields   or {}
    local defaultField = options.defaultField or (sortFields[1] and sortFields[1].key) or ""
    local defaultAsc   = options.defaultAsc ~= false
    local onChange     = options.onChange or function(field, ascending) end
    local dropWidth    = options.dropdownWidth or 110

    local state = { field = defaultField, ascending = defaultAsc }

    local dropdown, textFS = self:CreateDropdown(parent, { width = dropWidth, height = 25 })

    local function RefreshDropText()
        for _, f in ipairs(sortFields) do
            if f.key == state.field then
                textFS:SetText(f.label)
                break
            end
        end
    end
    RefreshDropText()
    dropdown._activeValue = defaultField

    self:AttachFilterMenu(dropdown, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, f in ipairs(sortFields) do
                items[#items + 1] = { text = f.label, value = f.key }
            end
            return items
        end,
        onSelect = function(value, label)
            state.field = value
            textFS:SetText(label)
            dropdown._activeValue = value
            onChange(state.field, state.ascending)
        end,
        getActiveValue = function() return state.field end,
    })

    local dirBtn = CreateFrame("Button", nil, parent)
    dirBtn:SetSize(24, 25)

    local function UpdateDirAtlas()
        local atlas = state.ascending and "common-button-collapseExpand-up" or "common-button-collapseExpand-down"
        dirBtn:SetNormalAtlas(atlas)
        dirBtn:SetPushedAtlas(atlas)
        dirBtn:SetHighlightAtlas(atlas)
        if dirBtn:GetHighlightTexture() then
            dirBtn:GetHighlightTexture():SetAlpha(0.5)
        end
    end
    UpdateDirAtlas()

    dirBtn:SetScript("OnClick", function()
        state.ascending = not state.ascending
        UpdateDirAtlas()
        onChange(state.field, state.ascending)
    end)

    local handle = { dropdown = dropdown, dirBtn = dirBtn }

    function handle:GetSort()
        return state.field, state.ascending
    end

    function handle:SetSort(field, ascending)
        state.field     = field
        state.ascending = ascending ~= false
        dropdown._activeValue = field
        RefreshDropText()
        UpdateDirAtlas()
    end

    return handle
end

function OneWoW_GUI:CreateHeader(parent, options)
    options = options or {}
    local text = options.text or ""
    local yOffset = options.yOffset or -OneWoW_GUI:GetSpacing("MD")
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    OneWoW_GUI:SafeSetFont(header, OneWoW_GUI:GetFont(), 16)
    header:SetPoint("TOPLEFT", OneWoW_GUI:GetSpacing("MD"), yOffset)
    header:SetText(text)
    header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    return header
end

function OneWoW_GUI:CreateDivider(parent, options)
    options = options or {}
    local yOffset = options.yOffset or 0
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("LEFT", OneWoW_GUI:GetSpacing("MD"), 0)
    divider:SetPoint("RIGHT", -OneWoW_GUI:GetSpacing("MD"), 0)
    divider:SetPoint("TOP", 0, yOffset)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    return divider
end

function OneWoW_GUI:CreateSection(parent, options)
    options = options or {}
    local title = options.title or ""
    local yOffset = options.yOffset or 0
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SafeSetFont(header, OneWoW_GUI:GetFont(), 12)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", OneWoW_GUI:GetSpacing("MD"), yOffset)
    header:SetText(title)
    header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - header:GetStringHeight() - 6

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", OneWoW_GUI:GetSpacing("MD"), yOffset)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -OneWoW_GUI:GetSpacing("MD"), yOffset)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    return yOffset
end

function OneWoW_GUI:CreateTitleBar(parent, options)
    options = options or {}
    local title = options.title or ""
    local height = options.height or Constants.GUI.TITLEBAR_HEIGHT
    local onClose = options.onClose
    local showBrand = options.showBrand

    local titleBg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    titleBg:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
    titleBg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
    titleBg:SetHeight(height)
    titleBg:SetBackdrop(Constants.BACKDROP_SIMPLE)
    titleBg:SetBackdropColor(OneWoW_GUI:GetThemeColor("TITLEBAR_BG"))
    titleBg:SetFrameLevel(parent:GetFrameLevel() + 1)

    titleBg._titleText = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SafeSetFont(titleBg._titleText, OneWoW_GUI:GetFont(), 12)

    if showBrand then
        local factionTheme = options.factionTheme
        if not factionTheme then
            factionTheme = (self.GetSetting and self:GetSetting("minimap.theme")) or "horde"
        end
        local brandIcon = titleBg:CreateTexture(nil, "OVERLAY")
        brandIcon:SetSize(14, 14)
        brandIcon:SetPoint("LEFT", titleBg, "LEFT", OneWoW_GUI:GetSpacing("SM"), 0)
        brandIcon:SetTexture(self:GetBrandIcon(factionTheme))
        titleBg.brandIcon = brandIcon

        self:RegisterSettingsCallback("OnIconThemeChanged", titleBg, function(owner)
            if owner.brandIcon and owner:IsVisible() then
                owner.brandIcon:SetTexture(OneWoW_GUI:GetBrandIcon(
                    (OneWoW_GUI.GetSetting and OneWoW_GUI:GetSetting("minimap.theme")) or "horde"))
            end
        end)

        local brandText = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        OneWoW_GUI:SafeSetFont(brandText, OneWoW_GUI:GetFont(), 12)
        brandText:SetPoint("LEFT", brandIcon, "RIGHT", 4, 0)
        brandText:SetText("OneWoW")
        brandText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

        titleBg._titleText:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
        titleBg._titleText:SetText(title)
        titleBg._titleText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    else
        titleBg._titleText:SetPoint("LEFT", titleBg, "LEFT", OneWoW_GUI:GetSpacing("MD"), 0)
        titleBg._titleText:SetText(title)
        titleBg._titleText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end

    if onClose then
        local closeBtn = self:CreateButton(titleBg, { text = "X", width = 20, height = 20 })
        closeBtn:SetPoint("RIGHT", titleBg, "RIGHT", -OneWoW_GUI:GetSpacing("XS") / 2, 0)
        closeBtn:SetScript("OnClick", onClose)
        titleBg._closeBtn = closeBtn
    end

    return titleBg
end

function OneWoW_GUI:CreateSectionHeader(parent, options)
    options = options or {}
    local title = options.title or ""
    local yOffset = options.yOffset or 0
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", 0, yOffset)
    section:SetPoint("TOPRIGHT", 0, yOffset)
    section:SetHeight(30)
    section:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    section:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    section:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local titleText = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SafeSetFont(titleText, OneWoW_GUI:GetFont(), 12)
    titleText:SetPoint("LEFT", 12, 0)
    titleText:SetText(title)
    titleText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    section.bottomY = yOffset - 30

    return section
end

function OneWoW_GUI:CreateVerticalPaneResizer(options)
    options = options or {}
    local parent = options.parent
    local leftPanel = options.leftPanel
    local rightPanel = options.rightPanel
    if not parent or not leftPanel or not rightPanel then
        error("OneWoW_GUI:CreateVerticalPaneResizer requires parent, leftPanel, and rightPanel")
    end

    local floor = math.floor
    local ceil = math.ceil
    local min = math.min
    local max = math.max

    local dividerWidth = options.dividerWidth or 6
    local leftMinWidth = options.leftMinWidth or 200
    local rightMinWidth = options.rightMinWidth or 280
    local splitPadding = options.splitPadding
    if splitPadding == nil then
        splitPadding = dividerWidth + 10
    end
    local bottomOuterInset = options.bottomOuterInset or 5
    local rightOuterInset = options.rightOuterInset or 5
    local resizeCap = options.resizeCap or 0.95
    local mainFrame = options.mainFrame -- widened when drag would leave less than dynamic right reserve
    local getMinRightWidth = options.getMinRightWidth -- fun() -> number; used only to grow mainFrame (e.g. unbounded text width)
    local onWidthChanged = options.onWidthChanged -- fun(leftWidth) after mouse release (persist)
    local maxAutoGrowSteps = options.maxAutoGrowSteps or 12 -- max mainFrame widen attempts per drag tick; handles deferred layout width

    local function effectiveRightReserveForGrow()
        local r = rightMinWidth
        if getMinRightWidth then
            local n = getMinRightWidth()
            if type(n) == "number" and n > r then
                r = n
            end
        end
        return r
    end

    local divider = CreateFrame("Button", nil, parent)
    divider:SetWidth(dividerWidth)
    divider:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 0, 0)
    divider:SetPoint("BOTTOM", parent, "BOTTOM", 0, bottomOuterInset)
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
        if not self._owPaneDragActive then
            dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            SetCursor(nil)
        end
    end)

    divider:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self._owPaneDragActive = true
            local x = GetCursorPosition()
            self._owPaneStartCursorX = x / self:GetEffectiveScale()
            self._owPaneStartLeftW = leftPanel:GetWidth()
        end
    end)

    divider:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self._owPaneDragActive then
            self._owPaneDragActive = false
            dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            SetCursor(nil)
            if onWidthChanged then
                onWidthChanged(leftPanel:GetWidth())
            end
        end
    end)

    divider:SetScript("OnUpdate", function(self)
        if not self._owPaneDragActive then return end
        local cursorX = GetCursorPosition() / self:GetEffectiveScale()
        local delta = cursorX - self._owPaneStartCursorX
        local desiredLeftWidth = max(leftMinWidth, self._owPaneStartLeftW + delta)

        local neededRightGrow = effectiveRightReserveForGrow()
        local screenMax = floor(GetScreenWidth() * resizeCap)
        -- Grow host until tab can fit desiredLeft + dynamic right reserve (handles layout lag with multiple steps).
        if mainFrame then
            for _ = 1, maxAutoGrowSteps do
                local tabW = parent:GetWidth()
                local minTabW = desiredLeftWidth + neededRightGrow + splitPadding
                if tabW >= minTabW then
                    break
                end
                local gap = minTabW - tabW
                local shortage = max(1, ceil(gap - 1e-6))
                local currentMainW = mainFrame:GetWidth()
                local newMainW = min(currentMainW + shortage, screenMax)
                if newMainW <= currentMainW then
                    break
                end
                mainFrame:SetWidth(newMainW)
            end
        end

        local tabWidth = parent:GetWidth()
        -- Clamp uses fixed rightMinWidth only
        local maxLeftWidth = tabWidth - rightMinWidth - splitPadding
        if maxLeftWidth < leftMinWidth then
            maxLeftWidth = leftMinWidth
        end
        local newLeftWidth = max(leftMinWidth, min(desiredLeftWidth, maxLeftWidth))
        leftPanel:SetWidth(newLeftWidth)
    end)

    rightPanel:ClearAllPoints()
    rightPanel:SetPoint("TOPLEFT", divider, "TOPRIGHT", 0, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -rightOuterInset, bottomOuterInset)

    parent:HookScript("OnSizeChanged", function(_, w)
        local maxLeftWidth = w - rightMinWidth - splitPadding
        if maxLeftWidth < leftMinWidth then
            maxLeftWidth = leftMinWidth
        end
        local currentLeftWidth = leftPanel:GetWidth()
        if currentLeftWidth > maxLeftWidth then
            leftPanel:SetWidth(maxLeftWidth)
        end
    end)

    return divider
end

function OneWoW_GUI:CreateHorizontalPaneResizer(options)
    options = options or {}
    local parent = options.parent
    local topPanel = options.topPanel
    local bottomPanel = options.bottomPanel
    if not parent or not topPanel or not bottomPanel then
        error("OneWoW_GUI:CreateHorizontalPaneResizer requires parent, topPanel, and bottomPanel")
    end

    local floor = math.floor
    local max = math.max
    local min = math.min

    local dividerHeight = options.dividerHeight or 6
    local topMinHeight = options.topMinHeight or 100
    local bottomMinHeight = options.bottomMinHeight or 60
    local onHeightChanged = options.onHeightChanged

    local divider = CreateFrame("Button", nil, parent)
    divider:SetHeight(dividerHeight)
    divider:SetPoint("TOPLEFT", topPanel, "BOTTOMLEFT", 0, 0)
    divider:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    divider:EnableMouse(true)

    local dividerTex = divider:CreateTexture(nil, "OVERLAY")
    dividerTex:SetHeight(2)
    dividerTex:SetPoint("LEFT", divider, "LEFT", 0, 0)
    dividerTex:SetPoint("RIGHT", divider, "RIGHT", 0, 0)
    dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    divider:SetScript("OnEnter", function(self)
        dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        SetCursor("UI_RESIZE_CURSOR")
    end)
    divider:SetScript("OnLeave", function(self)
        if not self._owPaneDragActive then
            dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            SetCursor(nil)
        end
    end)

    divider:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self._owPaneDragActive = true
            local _, y = GetCursorPosition()
            self._owPaneStartCursorY = y / self:GetEffectiveScale()
            self._owPaneStartTopH = topPanel:GetHeight()
        end
    end)

    divider:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self._owPaneDragActive then
            self._owPaneDragActive = false
            dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            SetCursor(nil)
            if onHeightChanged then
                onHeightChanged(bottomPanel:GetHeight())
            end
        end
    end)

    divider:SetScript("OnUpdate", function(self)
        if not self._owPaneDragActive then return end
        local _, cursorY = GetCursorPosition()
        cursorY = cursorY / self:GetEffectiveScale()
        local delta = self._owPaneStartCursorY - cursorY
        local desiredTopH = max(topMinHeight, self._owPaneStartTopH + delta)

        local totalH = parent:GetHeight()
        local maxTopH = totalH - bottomMinHeight - dividerHeight
        if maxTopH < topMinHeight then maxTopH = topMinHeight end
        local newTopH = max(topMinHeight, min(desiredTopH, maxTopH))
        topPanel:SetHeight(newTopH)
    end)

    bottomPanel:ClearAllPoints()
    bottomPanel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, 0)
    bottomPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    parent:HookScript("OnSizeChanged", function(_, _, h)
        if not h then return end
        local maxTopH = h - bottomMinHeight - dividerHeight
        if maxTopH < topMinHeight then maxTopH = topMinHeight end
        local currentTopH = topPanel:GetHeight()
        if currentTopH > maxTopH then
            topPanel:SetHeight(maxTopH)
        end
    end)

    return divider
end
