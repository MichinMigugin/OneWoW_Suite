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
    local height = options.height or 20
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
    titleText:SetPoint("LEFT", 12, 0)
    titleText:SetText(title)
    titleText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    section.bottomY = yOffset - 30

    return section
end
