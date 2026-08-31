local _, ns = ...

-- ============================================================================
-- Shared settings panel (hub Settings → Display sub-tab)
-- ============================================================================
-- Language, theme, font, minimap, and value display.
-- Lives in hub UI (not OneWoW_GUI) — suite units no longer embed this panel.
-- Reads/writes via OneWoW_GUI:GetSetting / SetSetting.
-- ============================================================================

local UI = ns.UI
local OneWoW_GUI = OneWoW_GUI
local Constants = OneWoW_GUI.Constants

local CreateFrame = CreateFrame
local tinsert = tinsert

local DEFAULT_THEME_ICON = Constants.DEFAULT_THEME_ICON

-- Language list comes from the Locale service (ns.Locale.SUPPORTED), the single
-- source of supported locales + native names. Resolve lazily at click time.
local function LangNative(code)
    for _, e in ipairs(ns.Locale.SUPPORTED) do
        if e.code == code then return e.native end
    end
    return code
end

-- Faction icon labels reuse Blizzard's localized FACTION_* globals (loaded before
-- addon code), so the dropdown matches the client language at zero translation cost.
local ICON_THEMES = {
    { key = "horde",    label = FACTION_HORDE },
    { key = "alliance", label = FACTION_ALLIANCE },
    { key = "neutral",  label = FACTION_NEUTRAL },
}

local ICON_LOOKUP = {}
for _, icon in ipairs(ICON_THEMES) do
    ICON_LOOKUP[icon.key] = icon.label
end

local THEMES = Constants.THEMES
local THEME_SPECIAL_OPTIONS = Constants.THEME_SPECIAL_OPTIONS
local THEME_MENU_GROUPS = Constants.THEME_MENU_GROUPS

local ICON_TEXTURES = Constants.ICON_TEXTURES
local panelBackdrop = Constants.BACKDROP_INNER_NO_INSETS
local simpleBackdrop = Constants.BACKDROP_SIMPLE

local dropdownBackdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local function CreateDropdownMenu(parent, items, onSelect)
    local overlay = CreateFrame("Button", nil, UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:SetFrameLevel(0)
    overlay:EnableMouse(true)
    overlay:RegisterForClicks("AnyDown", "AnyUp")

    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(10)
    menu:SetClampedToScreen(true)
    menu:SetBackdrop(dropdownBackdrop)
    menu:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    menu:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    menu:EnableMouse(true)

    overlay:SetScript("OnClick", function()
        menu:Hide()
    end)
    menu:SetScript("OnHide", function()
        overlay:Hide()
    end)

    local yOff = -4
    local maxWidth = 180
    for _, item in ipairs(items) do
        local btn = CreateFrame("Button", nil, menu, "BackdropTemplate")
        btn:SetHeight(24)
        btn:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, yOff)
        btn:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, yOff)
        btn:SetBackdrop(simpleBackdrop)
        btn:SetBackdropColor(0, 0, 0, 0)

        if item.icon then
            local icon = btn:CreateTexture(nil, "OVERLAY")
            icon:SetSize(18, 18)
            icon:SetPoint("LEFT", btn, "LEFT", 8, 0)
            icon:SetTexture(item.icon)

            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        else
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.text:SetPoint("LEFT", 8, 0)
        end
        btn.text:SetText(item.label)
        btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local textW = btn.text:GetStringWidth() + (item.icon and 40 or 20)
        if textW > maxWidth then maxWidth = textW end

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0)
        end)
        btn:SetScript("OnClick", function()
            menu:Hide()
            onSelect(item.value, item.label)
        end)

        yOff = yOff - 24
    end

    menu:SetSize(maxWidth + 16, math.abs(yOff) + 8)

    local screenH = UIParent:GetHeight()
    local parentBottom = parent:GetBottom() or 0
    local menuH = math.abs(yOff) + 8
    local openUpward = parentBottom < menuH and (screenH - (parent:GetTop() or screenH)) < parentBottom

    if openUpward then
        menu:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, 2)
    else
        menu:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -2)
    end

    return menu
end

function UI:BuildSharedSettingsPanel(parent, yOffset)
    yOffset = yOffset or -10

    -- Resolve the locale view at call time (post-login, after locale files load).
    local L = ns.L
    local function Current(value)
        return string.format(L["CURRENT_VALUE"], value)
    end

    local settingLang = OneWoW_GUI:GetSetting("language")
    local currentLang = type(settingLang) == "string" and settingLang or "enUS"
    local currentIconTheme = OneWoW_GUI:GetSetting("minimap.theme") or DEFAULT_THEME_ICON
    local currentFontKey = OneWoW_GUI:GetSetting("font") or "default"
    local currentFontData = OneWoW_GUI:GetFontInfoByKey(currentFontKey)
    local currentFontLabel = currentFontData and currentFontData.label or "WoW Default"
    local currentOffset = OneWoW_GUI:GetSetting("fontSizeOffset") or 0

    local isMinimapHidden = OneWoW_GUI:GetSetting("minimap.hide")

    local function CreateSplitRow(height)
        height = height or 165
        local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        container:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
        container:SetHeight(height)
        container:SetBackdrop(panelBackdrop)
        container:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        container:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local lp = CreateFrame("Frame", nil, container)
        lp:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        lp:SetPoint("BOTTOMRIGHT", container, "BOTTOM", 0, 0)

        local div = container:CreateTexture(nil, "ARTWORK")
        div:SetWidth(1)
        div:SetPoint("TOP", container, "TOP", 0, -8)
        div:SetPoint("BOTTOM", container, "BOTTOM", 0, 8)
        div:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local rp = CreateFrame("Frame", nil, container)
        rp:SetPoint("TOPLEFT", container, "TOP", 0, 0)
        rp:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)

        return container, lp, rp
    end

    ----------------------------------------------------------------
    -- ROW 1: Language | Color Theme
    ----------------------------------------------------------------
    local _, langPanel, themePanel = CreateSplitRow(165)

    local langTitle = langPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    langTitle:SetPoint("TOPLEFT", langPanel, "TOPLEFT", 15, -12)
    langTitle:SetText(L["LANGUAGE_SELECTION"])
    langTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local langDesc = langPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDesc:SetPoint("TOPLEFT", langPanel, "TOPLEFT", 15, -38)
    langDesc:SetPoint("TOPRIGHT", langPanel, "TOPRIGHT", -15, -38)
    langDesc:SetText(L["LANGUAGE_DESC"])
    langDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    langDesc:SetJustifyH("LEFT")
    langDesc:SetWordWrap(true)

    local currentLangLabel = langPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentLangLabel:SetPoint("TOPLEFT", langPanel, "TOPLEFT", 15, -90)
    currentLangLabel:SetText(Current(LangNative(currentLang)))
    currentLangLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local langDropdown = CreateFrame("Button", nil, langPanel, "BackdropTemplate")
    langDropdown:SetSize(190, 30)
    langDropdown:SetPoint("TOPLEFT", langPanel, "TOPLEFT", 15, -115)
    langDropdown:SetBackdrop(dropdownBackdrop)
    langDropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    langDropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local langDropText = langDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDropText:SetPoint("LEFT", 10, 0)
    langDropText:SetText(LangNative(currentLang))
    langDropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local langArrow = langDropdown:CreateTexture(nil, "OVERLAY")
    langArrow:SetSize(16, 16)
    langArrow:SetPoint("RIGHT", langDropdown, "RIGHT", -5, 0)
    langArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    local langMenu = nil
    langDropdown:SetScript("OnClick", function(btn)
        if langMenu and langMenu:IsShown() then
            langMenu:Hide()
            return
        end
        local items = {}
        for _, lang in ipairs(ns.Locale.SUPPORTED) do
            tinsert(items, { label = lang.native, value = lang.code })
        end
        langMenu = CreateDropdownMenu(btn, items, function(value)
            OneWoW_GUI:SetSetting("language", value)
        end)
        langMenu:Show()
    end)

    local themeTitle = themePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    themeTitle:SetPoint("TOPLEFT", themePanel, "TOPLEFT", 15, -12)
    themeTitle:SetText(L["THEME_SECTION"])
    themeTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local themeDesc = themePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDesc:SetPoint("TOPLEFT", themePanel, "TOPLEFT", 15, -38)
    themeDesc:SetPoint("TOPRIGHT", themePanel, "TOPRIGHT", -15, -38)
    themeDesc:SetText(L["THEME_DESC"])
    themeDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    themeDesc:SetJustifyH("LEFT")
    themeDesc:SetWordWrap(true)

    OneWoW_GUI:ApplyTheme()
    local currentThemeName = OneWoW_GUI:GetThemeDisplayName()
    local currentThemeLabel = themePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentThemeLabel:SetPoint("TOPLEFT", themePanel, "TOPLEFT", 15, -90)
    currentThemeLabel:SetText(Current(currentThemeName))
    currentThemeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local themeDropdown = CreateFrame("Button", nil, themePanel, "BackdropTemplate")
    themeDropdown:SetSize(210, 30)
    themeDropdown:SetPoint("TOPLEFT", themePanel, "TOPLEFT", 15, -115)
    themeDropdown:SetBackdrop(dropdownBackdrop)
    themeDropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    themeDropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local themeColorPreview = themeDropdown:CreateTexture(nil, "OVERLAY")
    themeColorPreview:SetSize(14, 14)
    themeColorPreview:SetPoint("LEFT", themeDropdown, "LEFT", 6, 0)
    themeColorPreview:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local themeDropText = themeDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDropText:SetPoint("LEFT", themeDropdown, "LEFT", 25, 0)
    themeDropText:SetText(currentThemeName)
    themeDropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local themeArrow = themeDropdown:CreateTexture(nil, "OVERLAY")
    themeArrow:SetSize(16, 16)
    themeArrow:SetPoint("RIGHT", themeDropdown, "RIGHT", -5, 0)
    themeArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    local themeMenuRef = nil
    themeDropdown:SetScript("OnClick", function(btn)
        if themeMenuRef and themeMenuRef:IsShown() then
            themeMenuRef:Hide()
            return
        end

        local maxMenuHeight = 400
        local rowH = 26
        local headerH = 20

        local overlay = CreateFrame("Button", nil, UIParent)
        overlay:SetAllPoints(UIParent)
        overlay:SetFrameStrata("FULLSCREEN_DIALOG")
        overlay:SetFrameLevel(0)
        overlay:EnableMouse(true)
        overlay:RegisterForClicks("AnyDown", "AnyUp")

        local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        themeMenuRef = menu
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(10)
        menu:SetClampedToScreen(true)
        menu:SetWidth(268)
        menu:SetBackdrop(dropdownBackdrop)
        menu:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        menu:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        menu:EnableMouse(true)

        overlay:SetScript("OnClick", function() menu:Hide() end)
        menu:SetScript("OnHide", function() overlay:Hide() end)

        local scrollContainer = CreateFrame("Frame", nil, menu)
        scrollContainer:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
        scrollContainer:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -2, 2)

        local scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", 0, 0)
        scrollFrame:EnableMouseWheel(true)
        OneWoW_GUI:StyleScrollBar(scrollFrame, { container = scrollContainer, offset = -2 })

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)
        scrollFrame:HookScript("OnSizeChanged", function(sf, w)
            scrollChild:SetWidth(math.max(1, (w or sf:GetWidth()) - 6))
        end)
        scrollChild:SetWidth(math.max(1, scrollFrame:GetWidth() - 6))

        local y = -4
        local function addSectionHeader(text)
            local h = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            OneWoW_GUI:SafeSetFont(h, OneWoW_GUI:GetFont(), 11)
            h:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 6, y)
            h:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -6, y)
            h:SetJustifyH("LEFT")
            h:SetText(text)
            h:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            y = y - headerH
        end

        local function addThemePickRow(capturedKey, label, previewThemeKey)
            local dotR, dotG, dotB
            if previewThemeKey == "random" then
                dotR, dotG, dotB = 0.55, 0.45, 0.95
            else
                dotR, dotG, dotB = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY", previewThemeKey)
            end
            local tbtn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            tbtn:SetHeight(rowH)
            tbtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, y)
            tbtn:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -2, y)
            tbtn:SetBackdrop(simpleBackdrop)
            tbtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            local dot = tbtn:CreateTexture(nil, "OVERLAY")
            dot:SetSize(14, 14)
            dot:SetPoint("LEFT", tbtn, "LEFT", 8, 0)
            dot:SetColorTexture(dotR, dotG, dotB)
            local txt = tbtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            txt:SetPoint("LEFT", tbtn, "LEFT", 28, 0)
            txt:SetPoint("RIGHT", tbtn, "RIGHT", -6, 0)
            txt:SetJustifyH("LEFT")
            txt:SetText(label)
            txt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            tbtn:SetScript("OnEnter", function(s)
                s:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                txt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end)
            tbtn:SetScript("OnLeave", function(s)
                s:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                txt:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end)
            tbtn:SetScript("OnClick", function()
                menu:Hide()
                if capturedKey == "random" then
                    Constants.SESSION_RANDOM_THEME_KEY = nil
                end
                OneWoW_GUI:SetSetting("theme", capturedKey)
                currentThemeLabel:SetText(Current(OneWoW_GUI:GetThemeDisplayName()))
                themeDropText:SetText(OneWoW_GUI:GetThemeDisplayName())
                themeColorPreview:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            end)
            y = y - rowH - 2
        end

        addSectionHeader(SPECIAL)
        for _, opt in ipairs(THEME_SPECIAL_OPTIONS or {}) do
            addThemePickRow(opt.key, (opt.labelKey and L[opt.labelKey]) or opt.label, "random")
        end
        for _, group in ipairs(THEME_MENU_GROUPS or {}) do
            addSectionHeader((group.titleKey and L[group.titleKey]) or group.title)
            for _, themeKey in ipairs(group.keys) do
                if THEMES[themeKey] then
                    addThemePickRow(themeKey, OneWoW_GUI:GetThemeName(themeKey), themeKey)
                end
            end
        end

        scrollChild:SetHeight(math.max(1, math.abs(y) + 8))

        local contentH = scrollChild:GetHeight() + 12
        local menuH = math.min(maxMenuHeight, math.max(120, contentH))
        menu:SetHeight(menuH)

        local screenH = UIParent:GetHeight()
        local btnBottom = btn:GetBottom() or 0
        local mh = menu:GetHeight()
        if btnBottom < mh and (screenH - (btn:GetTop() or screenH)) < btnBottom then
            menu:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 2)
        else
            menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        end

        scrollFrame:SetVerticalScroll(0)
        menu:Show()
    end)

    yOffset = yOffset - 185

    ----------------------------------------------------------------
    -- ROW 2: Font | Font Size
    ----------------------------------------------------------------
    local _, fontPanel, fontSizePanel = CreateSplitRow(165)

    local fontTitle = fontPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fontTitle:SetPoint("TOPLEFT", fontPanel, "TOPLEFT", 15, -12)
    fontTitle:SetText(L["FONT_SECTION"])
    fontTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local fontDesc = fontPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontDesc:SetPoint("TOPLEFT", fontPanel, "TOPLEFT", 15, -38)
    fontDesc:SetPoint("TOPRIGHT", fontPanel, "TOPRIGHT", -15, -38)
    fontDesc:SetText(L["FONT_DESC"])
    fontDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    fontDesc:SetJustifyH("LEFT")
    fontDesc:SetWordWrap(true)

    local fontCurrentLabel = fontPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontCurrentLabel:SetPoint("TOPLEFT", fontPanel, "TOPLEFT", 15, -90)
    fontCurrentLabel:SetText(Current(currentFontLabel))
    fontCurrentLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local fontDropdown = OneWoW_GUI:CreateDropdown(fontPanel, {
        width = 210,
        height = 30,
        text = currentFontLabel,
    })
    fontDropdown:SetPoint("TOPLEFT", fontPanel, "TOPLEFT", 15, -115)

    local fsTitle = fontSizePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fsTitle:SetPoint("TOPLEFT", fontSizePanel, "TOPLEFT", 15, -12)
    fsTitle:SetText(FONT_SIZE)
    fsTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local fontPreview = fontSizePanel:CreateFontString(nil, "OVERLAY")
    fontPreview:SetPoint("TOPRIGHT", fontSizePanel, "TOPRIGHT", -15, -12)
    OneWoW_GUI:SafeSetFont(fontPreview, currentFontData and currentFontData.file, 14)
    fontPreview:SetText("AaBbCc 123")
    fontPreview:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local fsDesc = fontSizePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fsDesc:SetPoint("TOPLEFT", fontSizePanel, "TOPLEFT", 15, -38)
    fsDesc:SetPoint("TOPRIGHT", fontSizePanel, "TOPRIGHT", -15, -38)
    fsDesc:SetText(L["FONT_SIZE_DESC"])
    fsDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    fsDesc:SetJustifyH("LEFT")
    fsDesc:SetWordWrap(true)

    local fsWarning = fontSizePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fsWarning:SetPoint("TOPLEFT", fsDesc, "BOTTOMLEFT", 0, -6)
    fsWarning:SetPoint("TOPRIGHT", fsDesc, "BOTTOMRIGHT", 0, -6)
    fsWarning:SetText(L["FONT_SIZE_WARNING"])
    fsWarning:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    fsWarning:SetJustifyH("LEFT")
    fsWarning:SetWordWrap(true)

    local function FormatOffset(v)
        if v > 0 then return "+" .. v
        elseif v == 0 then return "0"
        else return tostring(v) end
    end

    local fsCurrentLabel = fontSizePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fsCurrentLabel:SetPoint("TOPLEFT", fsWarning, "BOTTOMLEFT", 0, -10)
    fsCurrentLabel:SetText(Current(FormatOffset(currentOffset)))
    fsCurrentLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local stepperMinusBtn = CreateFrame("Button", nil, fontSizePanel, "BackdropTemplate")
    stepperMinusBtn:SetSize(28, 28)
    stepperMinusBtn:SetPoint("TOPLEFT", fsCurrentLabel, "BOTTOMLEFT", 0, -6)
    stepperMinusBtn:SetBackdrop(dropdownBackdrop)
    stepperMinusBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    stepperMinusBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
    stepperMinusBtn:RegisterForClicks("AnyDown", "AnyUp")

    local minusText = stepperMinusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minusText:SetPoint("CENTER")
    minusText:SetText("-")
    minusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local stepperPlusBtn = CreateFrame("Button", nil, fontSizePanel, "BackdropTemplate")
    stepperPlusBtn:SetSize(28, 28)
    stepperPlusBtn:SetPoint("LEFT", stepperMinusBtn, "RIGHT", 44, 0)
    stepperPlusBtn:SetBackdrop(dropdownBackdrop)
    stepperPlusBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    stepperPlusBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
    stepperPlusBtn:RegisterForClicks("AnyDown", "AnyUp")

    local plusText = stepperPlusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    plusText:SetPoint("CENTER")
    plusText:SetText("+")
    plusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local stepperValueText = fontSizePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    stepperValueText:SetPoint("LEFT", stepperMinusBtn, "RIGHT", 6, 0)
    stepperValueText:SetPoint("RIGHT", stepperPlusBtn, "LEFT", -6, 0)
    stepperValueText:SetJustifyH("CENTER")
    stepperValueText:SetText(FormatOffset(currentOffset))
    stepperValueText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local function UpdateStepperState(val)
        stepperValueText:SetText(FormatOffset(val))
        fsCurrentLabel:SetText(Current(FormatOffset(val)))
        if val <= -3 then
            stepperMinusBtn:Disable()
            minusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        else
            stepperMinusBtn:Enable()
            minusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
        if val >= 5 then
            stepperPlusBtn:Disable()
            plusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        else
            stepperPlusBtn:Enable()
            plusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
        local curFontData = OneWoW_GUI:GetFontInfoByKey(OneWoW_GUI:GetSetting("font") or "default")
        OneWoW_GUI:SafeSetFont(fontPreview, curFontData and curFontData.file, 14)
        fontPreview:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end

    stepperMinusBtn:SetScript("OnEnter", function(s)
        if s:IsEnabled() then
            s:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            s:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        end
    end)
    stepperMinusBtn:SetScript("OnLeave", function(s)
        s:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        s:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
    end)
    stepperMinusBtn:SetScript("OnClick", function()
        local cur = OneWoW_GUI:GetSetting("fontSizeOffset") or 0
        local newVal = math.max(-3, cur - 1)
        if newVal ~= cur then
            OneWoW_GUI:SetSetting("fontSizeOffset", newVal)
            UpdateStepperState(newVal)
        end
    end)

    stepperPlusBtn:SetScript("OnEnter", function(s)
        if s:IsEnabled() then
            s:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            s:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        end
    end)
    stepperPlusBtn:SetScript("OnLeave", function(s)
        s:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        s:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
    end)
    stepperPlusBtn:SetScript("OnClick", function()
        local cur = OneWoW_GUI:GetSetting("fontSizeOffset") or 0
        local newVal = math.min(5, cur + 1)
        if newVal ~= cur then
            OneWoW_GUI:SetSetting("fontSizeOffset", newVal)
            UpdateStepperState(newVal)
        end
    end)

    UpdateStepperState(currentOffset)

    OneWoW_GUI:AttachFilterMenu(fontDropdown, {
        searchable = true,
        buildItems = function()
            local items = {}
            for _, fontInfo in ipairs(OneWoW_GUI:GetFontList()) do
                tinsert(items, {
                    text = fontInfo.label,
                    value = fontInfo.key,
                    fontPath = fontInfo.file,
                    fontSize = 13,
                })
            end
            return items
        end,
        onSelect = function(value, text)
            fontDropdown._text:SetText(text)
            fontCurrentLabel:SetText(Current(text))
            local info = OneWoW_GUI:GetFontInfoByKey(value)
            OneWoW_GUI:SafeSetFont(fontPreview, info and info.file, 14)
            fontPreview:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            OneWoW_GUI:SetSetting("font", value)
        end,
        getActiveValue = function() return OneWoW_GUI:GetSetting("font") or "default" end,
    })

    yOffset = yOffset - 185

    ----------------------------------------------------------------
    -- ROW 3: Minimap Button | Icon Theme
    ----------------------------------------------------------------
    local _, mmLeftPanel, mmRightPanel = CreateSplitRow(165)

    local mmTitle = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mmTitle:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -12)
    mmTitle:SetText(L["MINIMAP_SECTION"])
    mmTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local mmDesc = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmDesc:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -38)
    mmDesc:SetPoint("TOPRIGHT", mmLeftPanel, "TOPRIGHT", -15, -38)
    mmDesc:SetText(L["MINIMAP_SECTION_DESC"])
    mmDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    mmDesc:SetJustifyH("LEFT")
    mmDesc:SetWordWrap(true)

    local mmCheckbox = OneWoW_GUI:CreateCheckbox(mmLeftPanel, { label = L["MINIMAP_SHOW_BTN"] })
    mmCheckbox:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 12, -80)
    mmCheckbox:SetChecked(not isMinimapHidden)
    mmCheckbox:SetScript("OnClick", function(cb)
        local show = cb:GetChecked()
        OneWoW_GUI:SetSetting("minimap.hide", not show)
    end)

    local mmIconTitle = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mmIconTitle:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -12)
    mmIconTitle:SetText(L["MINIMAP_ICON_SECTION"])
    mmIconTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local mmIconDesc = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmIconDesc:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -38)
    mmIconDesc:SetPoint("TOPRIGHT", mmRightPanel, "TOPRIGHT", -15, -38)
    mmIconDesc:SetText(L["MINIMAP_ICON_DESC"])
    mmIconDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    mmIconDesc:SetJustifyH("LEFT")
    mmIconDesc:SetWordWrap(true)

    local mmCurrentLabel = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmCurrentLabel:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -90)
    mmCurrentLabel:SetText(Current(ICON_LOOKUP[currentIconTheme] or FACTION_HORDE))
    mmCurrentLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local iconDropdown = CreateFrame("Button", nil, mmRightPanel, "BackdropTemplate")
    iconDropdown:SetSize(190, 30)
    iconDropdown:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -115)
    iconDropdown:SetBackdrop(dropdownBackdrop)
    iconDropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    iconDropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local iconDropIcon = iconDropdown:CreateTexture(nil, "OVERLAY")
    iconDropIcon:SetSize(18, 18)
    iconDropIcon:SetPoint("LEFT", iconDropdown, "LEFT", 6, 0)
    iconDropIcon:SetTexture(ICON_TEXTURES[currentIconTheme] or ICON_TEXTURES.horde)

    local iconDropText = iconDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconDropText:SetPoint("LEFT", iconDropIcon, "RIGHT", 4, 0)
    iconDropText:SetText(ICON_LOOKUP[currentIconTheme] or FACTION_HORDE)
    iconDropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local iconArrow = iconDropdown:CreateTexture(nil, "OVERLAY")
    iconArrow:SetSize(16, 16)
    iconArrow:SetPoint("RIGHT", iconDropdown, "RIGHT", -5, 0)
    iconArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    local iconMenu = nil
    iconDropdown:SetScript("OnClick", function(btn)
        if iconMenu and iconMenu:IsShown() then
            iconMenu:Hide()
            return
        end
        local items = {}
        for _, ic in ipairs(ICON_THEMES) do
            tinsert(items, { label = ic.label, value = ic.key, icon = ICON_TEXTURES[ic.key] })
        end
        iconMenu = CreateDropdownMenu(btn, items, function(value, label)
            iconDropIcon:SetTexture(ICON_TEXTURES[value] or ICON_TEXTURES.horde)
            iconDropText:SetText(label or ICON_LOOKUP[value] or FACTION_HORDE)
            mmCurrentLabel:SetText(Current(label or ICON_LOOKUP[value] or FACTION_HORDE))
            OneWoW_GUI:SetSetting("minimap.theme", value)
        end)
        iconMenu:Show()
    end)

    yOffset = yOffset - 185

    ----------------------------------------------------------------
    -- ROW 4: Value display (money)
    ----------------------------------------------------------------
    local valuePanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    valuePanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    valuePanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    valuePanel:SetHeight(236)
    valuePanel:SetBackdrop(panelBackdrop)
    valuePanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    valuePanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local valueTitle = valuePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    valueTitle:SetPoint("TOPLEFT", valuePanel, "TOPLEFT", 15, -12)
    valueTitle:SetText(L["VALUE_DISPLAY_SECTION"])
    valueTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local valueDesc = valuePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueDesc:SetPoint("TOPLEFT", valuePanel, "TOPLEFT", 15, -38)
    valueDesc:SetPoint("TOPRIGHT", valuePanel, "TOPRIGHT", -15, -38)
    valueDesc:SetText(L["VALUE_DISPLAY_DESC"])
    valueDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    valueDesc:SetJustifyH("LEFT")
    valueDesc:SetWordWrap(true)

    -- 123,456g 78s 90c in copper. FormatGold applies the live Value display settings.
    local VALUE_PREVIEW_COPPER = 123456 * 10000 + 78 * 100 + 90

    local lettersChecked = OneWoW_GUI:GetSetting("moneyDisplay.useLetters") and true or false
    local groupingChecked = OneWoW_GUI:GetSetting("moneyDisplay.useGrouping") ~= false
    local regionalChecked = OneWoW_GUI:GetSetting("moneyDisplay.useRegionalNumbers") ~= false
    local whiteValuesChecked = OneWoW_GUI:GetSetting("moneyDisplay.useWhiteValues") and true or false

    local lettersCb = OneWoW_GUI:CreateCheckbox(valuePanel, {
        label = L["VALUE_DISPLAY_LETTERS"],
    })
    lettersCb:SetPoint("TOPLEFT", valuePanel, "TOPLEFT", 12, -72)
    lettersCb:SetChecked(lettersChecked)

    local groupingCb = OneWoW_GUI:CreateCheckbox(valuePanel, {
        label = L["VALUE_DISPLAY_GROUPING"],
    })
    groupingCb:SetPoint("TOPLEFT", lettersCb, "BOTTOMLEFT", 0, -6)
    groupingCb:SetChecked(groupingChecked)

    local regionalCb = OneWoW_GUI:CreateCheckbox(valuePanel, {
        label = L["VALUE_DISPLAY_REGIONAL"],
    })
    regionalCb:SetPoint("TOPLEFT", groupingCb, "BOTTOMLEFT", 0, -6)
    regionalCb:SetChecked(regionalChecked)

    local whiteValuesCb = OneWoW_GUI:CreateCheckbox(valuePanel, {
        label = L["VALUE_DISPLAY_WHITE"],
    })
    whiteValuesCb:SetPoint("TOPLEFT", regionalCb, "BOTTOMLEFT", 0, -6)
    whiteValuesCb:SetChecked(whiteValuesChecked)

    local previewLabel = valuePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", whiteValuesCb, "BOTTOMLEFT", 4, -10)
    previewLabel:SetText(PREVIEW)
    previewLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local previewGold = valuePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    previewGold:SetPoint("LEFT", previewLabel, "RIGHT", 8, 0)
    previewGold:SetTextColor(1, 1, 1)

    local function RefreshValuePreview()
        previewGold:SetTextColor(1, 1, 1)
        previewGold:SetText(OneWoW.Format.FormatGold(VALUE_PREVIEW_COPPER))
        local groupingOn = OneWoW_GUI:GetSetting("moneyDisplay.useGrouping")
        if groupingOn then
            regionalCb:Enable()
            regionalCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            regionalCb:Disable()
            regionalCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    lettersCb:SetScript("OnClick", function(cb)
        OneWoW_GUI:SetSetting("moneyDisplay.useLetters", cb:GetChecked())
        RefreshValuePreview()
    end)
    groupingCb:SetScript("OnClick", function(cb)
        OneWoW_GUI:SetSetting("moneyDisplay.useGrouping", cb:GetChecked())
        RefreshValuePreview()
    end)
    regionalCb:SetScript("OnClick", function(cb)
        OneWoW_GUI:SetSetting("moneyDisplay.useRegionalNumbers", cb:GetChecked())
        RefreshValuePreview()
    end)
    whiteValuesCb:SetScript("OnClick", function(cb)
        OneWoW_GUI:SetSetting("moneyDisplay.useWhiteValues", cb:GetChecked())
        RefreshValuePreview()
    end)
    RefreshValuePreview()

    yOffset = yOffset - 256

    local function refreshThemePickerLabels()
        OneWoW_GUI:ApplyTheme()
        local name = OneWoW_GUI:GetThemeDisplayName()
        currentThemeLabel:SetText(Current(name))
        themeDropText:SetText(name)
        if themeColorPreview then
            themeColorPreview:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        end
    end
    if parent then
        parent._owgRefreshThemePickerLabels = refreshThemePickerLabels
        if not parent._owgThemePickerHooked then
            parent._owgThemePickerHooked = true
            OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", parent, function(owner)
                if owner._owgRefreshThemePickerLabels then
                    owner._owgRefreshThemePickerLabels()
                end
            end)
        end
    end

    return yOffset
end
