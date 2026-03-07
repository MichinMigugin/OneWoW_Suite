-- OneWoW_QoL Addon File
-- OneWoW_QoL/UI/t-settings.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
local THEMES = OneWoW_GUI.Constants.THEMES

local THEMES_ORDER = { "green", "blue", "purple", "red", "orange", "teal", "gold", "pink", "dark", "amber", "cyan", "slate", "voidblack", "charcoal", "forestnight", "obsidian", "monochrome", "twilight", "neon", "glassmorphic", "lightmode", "retro", "fantasy", "nightfae" }
local THEME_LOCALE_KEYS = {
    green  = "THEME_NAME_GREEN",
    blue   = "THEME_NAME_BLUE",
    purple = "THEME_NAME_PURPLE",
    red    = "THEME_NAME_RED",
    orange = "THEME_NAME_ORANGE",
    teal   = "THEME_NAME_TEAL",
    gold   = "THEME_NAME_GOLD",
    pink   = "THEME_NAME_PINK",
    dark   = "THEME_NAME_DARK",
    amber  = "THEME_NAME_AMBER",
    cyan   = "THEME_NAME_CYAN",
    slate  = "THEME_NAME_SLATE",
    voidblack   = "THEME_NAME_VOID_BLACK",
    charcoal    = "THEME_NAME_CHARCOAL_DEEP",
    forestnight = "THEME_NAME_FOREST_NIGHT",
    obsidian    = "THEME_NAME_OBSIDIAN_MINIMAL",
    monochrome  = "THEME_NAME_MONOCHROME_PRO",
    twilight    = "THEME_NAME_TWILIGHT_COMPACT",
    neon        = "THEME_NAME_NEON_SYNTHWAVE",
    glassmorphic = "THEME_NAME_GLASSMORPHIC",
    lightmode   = "THEME_NAME_MINIMAL_WHITE",
    retro       = "THEME_NAME_RETRO_CLASSIC",
    fantasy     = "THEME_NAME_RPG_FANTASY",
    nightfae    = "THEME_NAME_COVENANT_TWILIGHT",
}

local LANGUAGES = {
    { key = "enUS", labelKey = "LANG_ENGLISH" },
    { key = "koKR", labelKey = "LANG_KOREAN" },
}

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local backdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

local function ShowDevHelpDialog()
    if _G.OneWoW_QoLDevHelpDialog then
        _G.OneWoW_QoLDevHelpDialog:Show()
        _G.OneWoW_QoLDevHelpDialog:Raise()
        return
    end

    local dialog = CreateFrame("Frame", "OneWoW_QoLDevHelpDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(520, 560)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:SetMovable(true)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    dialog:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    dialog:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    dialog:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    tinsert(UISpecialFrames, "OneWoW_QoLDevHelpDialog")

    local titleBar = OneWoW_GUI:CreateTitleBar(dialog, L["DEVHELP_TITLE"], { height = 28 })

    local divider = dialog:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -29)
    divider:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -1, -29)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local scrollFrame = CreateFrame("ScrollFrame", nil, dialog)
    scrollFrame:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -38)
    scrollFrame:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -24, 50)
    scrollFrame:EnableMouseWheel(true)

    local scrollTrack = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    scrollTrack:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -4, -38)
    scrollTrack:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -4, 50)
    scrollTrack:SetWidth(8)
    scrollTrack:SetBackdrop(BACKDROP_SIMPLE)
    scrollTrack:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(40)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop(BACKDROP_SIMPLE)
    scrollThumb:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    local function UpdateThumb()
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        local scroll = scrollFrame:GetVerticalScroll()
        local frameH = scrollFrame:GetHeight()
        local contentH = scrollChild:GetHeight()
        if scrollRange <= 0 or contentH <= 0 then
            scrollThumb:SetHeight(scrollTrack:GetHeight())
            scrollThumb:ClearAllPoints()
            scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
            return
        end
        local trackH = scrollTrack:GetHeight()
        local thumbH = math.max(20, (frameH / contentH) * trackH)
        scrollThumb:SetHeight(thumbH)
        local maxOffset = trackH - thumbH
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -(scroll / scrollRange) * maxOffset)
    end

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        self:SetVerticalScroll(delta > 0 and math.max(0, current - 30) or math.min(maxScroll, current + 30))
        UpdateThumb()
    end)
    scrollFrame:HookScript("OnSizeChanged", function(self, width)
        scrollChild:SetWidth(width)
        UpdateThumb()
    end)

    scrollThumb:EnableMouse(true)
    scrollThumb:RegisterForDrag("LeftButton")
    scrollThumb:SetScript("OnMouseDown", function(self)
        self.dragging = true
        self.dragStartY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    scrollThumb:SetScript("OnMouseUp", function(self) self.dragging = false end)
    scrollThumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local curY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta = self.dragStartY - curY
        local trackH = scrollTrack:GetHeight()
        local thumbH = self:GetHeight()
        local maxOffset = trackH - thumbH
        if maxOffset <= 0 then return end
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        local newScroll = self.dragStartScroll + (delta / maxOffset) * scrollRange
        scrollFrame:SetVerticalScroll(math.max(0, math.min(scrollRange, newScroll)))
        UpdateThumb()
    end)

    local bodyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bodyText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -8)
    bodyText:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -8, -8)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetWordWrap(true)
    bodyText:SetSpacing(4)
    bodyText:SetText(L["DEVHELP_BODY"])
    bodyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    scrollChild:SetHeight(bodyText:GetStringHeight() + 30)
    C_Timer.After(0.1, function() UpdateThumb() end)

    local btnDivider = dialog:CreateTexture(nil, "ARTWORK")
    btnDivider:SetHeight(1)
    btnDivider:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 1, 46)
    btnDivider:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -1, 46)
    btnDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local closeBtn = OneWoW_GUI:CreateButton(nil, dialog, L["DEVHELP_CLOSE"], 120, 32)
    closeBtn:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 8)
    closeBtn:SetScript("OnClick", function() dialog:Hide() end)

    dialog:Show()
end

local function CreateSectionHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    header:SetText(text)
    header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    return header
end

local function CreateSectionDivider(parent, yOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yOffset)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    return divider
end

function ns.UI.CreateSettingsTab(parent)
    local scrollBarWidth = 10
    local settingsContainer = CreateFrame("Frame", nil, parent)
    settingsContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    settingsContainer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -scrollBarWidth, 0)

    local scrollFrame = CreateFrame("ScrollFrame", nil, settingsContainer)
    scrollFrame:SetAllPoints(settingsContainer)
    scrollFrame:EnableMouseWheel(true)

    local scrollTrack = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    scrollTrack:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, 0)
    scrollTrack:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -2, 0)
    scrollTrack:SetWidth(8)
    scrollTrack:SetBackdrop(BACKDROP_SIMPLE)
    scrollTrack:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(40)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop(BACKDROP_SIMPLE)
    scrollThumb:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    local function UpdateThumb()
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        local scroll = scrollFrame:GetVerticalScroll()
        local frameH = scrollFrame:GetHeight()
        local contentH = scrollChild:GetHeight()
        if scrollRange <= 0 or contentH <= 0 then
            scrollThumb:SetHeight(scrollTrack:GetHeight())
            scrollThumb:ClearAllPoints()
            scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
            return
        end
        local trackH = scrollTrack:GetHeight()
        local thumbH = math.max(20, (frameH / contentH) * trackH)
        scrollThumb:SetHeight(thumbH)
        local maxOffset = trackH - thumbH
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -(scroll / scrollRange) * maxOffset)
    end

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        self:SetVerticalScroll(delta > 0 and math.max(0, current - 40) or math.min(maxScroll, current + 40))
        UpdateThumb()
    end)
    scrollFrame:HookScript("OnSizeChanged", function(self, width)
        scrollChild:SetWidth(width)
        UpdateThumb()
    end)

    scrollThumb:EnableMouse(true)
    scrollThumb:RegisterForDrag("LeftButton")
    scrollThumb:SetScript("OnMouseDown", function(self)
        self.dragging = true
        self.dragStartY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    scrollThumb:SetScript("OnMouseUp", function(self) self.dragging = false end)
    scrollThumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local curY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta = self.dragStartY - curY
        local trackH = scrollTrack:GetHeight()
        local thumbH = self:GetHeight()
        local maxOffset = trackH - thumbH
        if maxOffset <= 0 then return end
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        local newScroll = self.dragStartScroll + (delta / maxOffset) * scrollRange
        scrollFrame:SetVerticalScroll(math.max(0, math.min(scrollRange, newScroll)))
        UpdateThumb()
    end)

    local addon = _G.OneWoW_QoL
    local yOffset = -20

    if not _G.OneWoW then

    local splitContainer = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    splitContainer:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, yOffset)
    splitContainer:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -16, yOffset)
    splitContainer:SetHeight(165)
    splitContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    splitContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    splitContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local leftPanel = CreateFrame("Frame", nil, splitContainer)
    leftPanel:SetPoint("TOPLEFT", splitContainer, "TOPLEFT", 0, 0)
    leftPanel:SetPoint("BOTTOMRIGHT", splitContainer, "BOTTOM", 0, 0)

    local langTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    langTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -12)
    langTitle:SetText(L["SETTINGS_LANGUAGE_HEADER"])
    langTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local langDescText = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDescText:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -38)
    langDescText:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -10, -38)
    langDescText:SetJustifyH("LEFT")
    langDescText:SetWordWrap(true)
    langDescText:SetText(L["SETTINGS_LANGUAGE_DESC"])
    langDescText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local currentLang = addon.db.global.language or "enUS"
    local currentLangName = L["LANG_ENGLISH"]
    for _, lang in ipairs(LANGUAGES) do
        if lang.key == currentLang then currentLangName = L[lang.labelKey] or lang.key break end
    end

    local langCurrentLabel = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langCurrentLabel:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -90)
    langCurrentLabel:SetText(L["SETTINGS_LANGUAGE_HEADER"] .. ": " .. currentLangName)
    langCurrentLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local langDropdown = CreateFrame("Button", nil, leftPanel, "BackdropTemplate")
    langDropdown:SetSize(190, 30)
    langDropdown:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -115)
    langDropdown:SetBackdrop(backdrop)
    langDropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    langDropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local langDropText = langDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDropText:SetPoint("CENTER")
    langDropText:SetText(currentLangName)
    langDropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local langDropArrow = langDropdown:CreateTexture(nil, "OVERLAY")
    langDropArrow:SetSize(16, 16)
    langDropArrow:SetPoint("RIGHT", langDropdown, "RIGHT", -5, 0)
    langDropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    langDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS")) end)
    langDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE")) end)

    langDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(190, #LANGUAGES * 27 + 10)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop(backdrop)
        menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:EnableMouse(true)
        for i, lang in ipairs(LANGUAGES) do
            local btn = CreateFrame("Button", nil, menu, "BackdropTemplate")
            btn:SetSize(180, 25)
            btn:SetPoint("TOP", menu, "TOP", 0, -(5 + (i - 1) * 27))
            btn:SetBackdrop(BACKDROP_SIMPLE)
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            txt:SetPoint("CENTER")
            txt:SetText(L[lang.labelKey] or lang.key)
            txt:SetTextColor(0.9, 0.9, 0.9)
            btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) txt:SetTextColor(1, 0.82, 0) end)
            btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) txt:SetTextColor(0.9, 0.9, 0.9) end)
            local capturedKey = lang.key
            btn:SetScript("OnClick", function()
                addon.db.global.language = capturedKey
                ns.ApplyLanguage()
                menu:Hide()
                if ns.UI.Reset then ns.UI:Reset() end
                C_Timer.After(0.05, function()
                    if ns.UI.Show then ns.UI:Show("settings") end
                end)
            end)
        end
        menu:SetScript("OnShow", function(self)
            local timeOutside = 0
            self:SetScript("OnUpdate", function(self, elapsed)
                if not MouseIsOver(menu) and not MouseIsOver(langDropdown) then
                    timeOutside = timeOutside + elapsed
                    if timeOutside > 0.5 then self:Hide() self:SetScript("OnUpdate", nil) end
                else timeOutside = 0 end
            end)
        end)
    end)

    local vertDivider = splitContainer:CreateTexture(nil, "ARTWORK")
    vertDivider:SetWidth(1)
    vertDivider:SetPoint("TOP", splitContainer, "TOP", 0, -8)
    vertDivider:SetPoint("BOTTOM", splitContainer, "BOTTOM", 0, 8)
    vertDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local rightPanel = CreateFrame("Frame", nil, splitContainer)
    rightPanel:SetPoint("TOPLEFT", splitContainer, "TOP", 0, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", splitContainer, "BOTTOMRIGHT", 0, 0)

    local themeTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    themeTitle:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -12)
    themeTitle:SetText(L["SETTINGS_THEME_HEADER"])
    themeTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local themeDescText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDescText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -38)
    themeDescText:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -10, -38)
    themeDescText:SetJustifyH("LEFT")
    themeDescText:SetWordWrap(true)
    themeDescText:SetText(L["SETTINGS_THEME_DESC"])
    themeDescText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local currentTheme = addon.db.global.theme or "green"
    local currentThemeData = THEMES[currentTheme]
    local currentThemeName = (currentThemeData and (L[THEME_LOCALE_KEYS[currentTheme]] or currentThemeData.name)) or currentTheme

    local themeCurrentLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeCurrentLabel:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -90)
    themeCurrentLabel:SetText(L["SETTINGS_THEME_HEADER"] .. ": " .. currentThemeName)
    themeCurrentLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local themeDropdown = CreateFrame("Button", nil, rightPanel, "BackdropTemplate")
    themeDropdown:SetSize(210, 30)
    themeDropdown:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -115)
    themeDropdown:SetBackdrop(backdrop)
    themeDropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    themeDropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local themeDropText = themeDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDropText:SetPoint("LEFT", themeDropdown, "LEFT", 25, 0)
    themeDropText:SetText(currentThemeName)
    themeDropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local themeColorPreview = themeDropdown:CreateTexture(nil, "OVERLAY")
    themeColorPreview:SetSize(14, 14)
    themeColorPreview:SetPoint("LEFT", themeDropdown, "LEFT", 6, 0)
    if currentThemeData then themeColorPreview:SetColorTexture(unpack(currentThemeData.ACCENT_PRIMARY)) end

    local themeDropArrow = themeDropdown:CreateTexture(nil, "OVERLAY")
    themeDropArrow:SetSize(16, 16)
    themeDropArrow:SetPoint("RIGHT", themeDropdown, "RIGHT", -5, 0)
    themeDropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    themeDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS")) end)
    themeDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE")) end)

    themeDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(240, 318)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop(backdrop)
        menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:EnableMouse(true)

        local scrollFrame = CreateFrame("ScrollFrame", nil, menu)
        scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
        scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -15, 2)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(scrollFrame:GetWidth())
        scrollFrame:SetScrollChild(scrollChild)

        local scrollBar = CreateFrame("Slider", nil, scrollFrame, "BackdropTemplate")
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, -2)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 2)
        scrollBar:SetWidth(12)
        scrollBar:SetBackdrop(BACKDROP_SIMPLE)
        scrollBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        scrollBar:EnableMouse(true)
        scrollBar:SetScript("OnValueChanged", function(self, value) scrollFrame:SetVerticalScroll(value) end)

        local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(8, 40)
        thumb:SetPoint("TOP", scrollBar, "TOP", 0, -2)
        thumb:SetColorTexture(0.5, 0.5, 0.5)
        scrollBar:SetThumbTexture(thumb)

        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(self, direction)
            local currentScroll = scrollFrame:GetVerticalScroll()
            local maxScroll = scrollChild:GetHeight() - scrollFrame:GetHeight()
            local newScroll = math.max(0, math.min(maxScroll, currentScroll - (direction * 30)))
            scrollFrame:SetVerticalScroll(newScroll)
            scrollBar:SetValue(newScroll)
        end)

        for i, themeKey in ipairs(THEMES_ORDER) do
            local themeData = THEMES[themeKey]
            if themeData then
                local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                btn:SetSize(230, 26)
                btn:SetPoint("TOP", scrollChild, "TOP", 0, -(5 + (i - 1) * 28))
                btn:SetBackdrop(BACKDROP_SIMPLE)
                btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                local dot = btn:CreateTexture(nil, "OVERLAY")
                dot:SetSize(14, 14)
                dot:SetPoint("LEFT", btn, "LEFT", 8, 0)
                dot:SetColorTexture(unpack(themeData.ACCENT_PRIMARY))
                local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                txt:SetPoint("LEFT", btn, "LEFT", 28, 0)
                txt:SetText(L[THEME_LOCALE_KEYS[themeKey]] or themeData.name)
                txt:SetTextColor(0.9, 0.9, 0.9)
                btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) txt:SetTextColor(1, 0.82, 0) end)
                btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) txt:SetTextColor(0.9, 0.9, 0.9) end)
                local capturedKey = themeKey
                btn:SetScript("OnClick", function()
                    addon.db.global.theme = capturedKey
                    themeDropText:SetText(L[THEME_LOCALE_KEYS[capturedKey]] or themeData.name)
                    themeColorPreview:SetColorTexture(unpack(themeData.ACCENT_PRIMARY))
                    ns.ApplyTheme()
                    menu:Hide()
                    if ns.UI.Reset then ns.UI:Reset() end
                    C_Timer.After(0.05, function()
                        if ns.UI.Show then ns.UI:Show("settings") end
                    end)
                end)
            end
        end
        scrollChild:SetHeight(#THEMES_ORDER * 28 + 10)
        local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        scrollBar:SetMinMaxValues(0, maxScroll)
        scrollFrame:SetVerticalScroll(0)
        menu:SetScript("OnShow", function(self)
            local timeOutside = 0
            self:SetScript("OnUpdate", function(self, elapsed)
                if not MouseIsOver(menu) and not MouseIsOver(themeDropdown) then
                    timeOutside = timeOutside + elapsed
                    if timeOutside > 0.5 then self:Hide() self:SetScript("OnUpdate", nil) end
                else timeOutside = 0 end
            end)
        end)
    end)

    yOffset = yOffset - 180

    local mmContainer = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    mmContainer:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, yOffset)
    mmContainer:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -16, yOffset)
    mmContainer:SetHeight(130)
    mmContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    mmContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    mmContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local mmLeftPanel = CreateFrame("Frame", nil, mmContainer)
    mmLeftPanel:SetPoint("TOPLEFT", mmContainer, "TOPLEFT", 0, 0)
    mmLeftPanel:SetPoint("BOTTOMRIGHT", mmContainer, "BOTTOM", 0, 0)

    local mmLeftTitle = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mmLeftTitle:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -12)
    mmLeftTitle:SetText(L["MINIMAP_SECTION"])
    mmLeftTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local mmLeftDesc = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmLeftDesc:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -38)
    mmLeftDesc:SetPoint("TOPRIGHT", mmLeftPanel, "TOPRIGHT", -10, -38)
    mmLeftDesc:SetJustifyH("LEFT")
    mmLeftDesc:SetWordWrap(true)
    mmLeftDesc:SetText(L["MINIMAP_SECTION_DESC"])
    mmLeftDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local mmShowCheck = OneWoW_GUI:CreateCheckbox(nil, mmLeftPanel, L["MINIMAP_SHOW_BTN"])
    mmShowCheck:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 10, -85)
    local isMinimapHidden = addon.db and addon.db.global and addon.db.global.minimap and addon.db.global.minimap.hide
    mmShowCheck:SetChecked(not isMinimapHidden)

    mmShowCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            if ns.MinimapButton then ns.MinimapButton:Show() end
        else
            if ns.MinimapButton then ns.MinimapButton:Hide() end
        end
    end)

    local mmVertDivider = mmContainer:CreateTexture(nil, "ARTWORK")
    mmVertDivider:SetWidth(1)
    mmVertDivider:SetPoint("TOP", mmContainer, "TOP", 0, -8)
    mmVertDivider:SetPoint("BOTTOM", mmContainer, "BOTTOM", 0, 8)
    mmVertDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local mmRightPanel = CreateFrame("Frame", nil, mmContainer)
    mmRightPanel:SetPoint("TOPLEFT", mmContainer, "TOP", 0, 0)
    mmRightPanel:SetPoint("BOTTOMRIGHT", mmContainer, "BOTTOMRIGHT", 0, 0)

    local mmRightTitle = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mmRightTitle:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -12)
    mmRightTitle:SetText(L["MINIMAP_ICON_SECTION"])
    mmRightTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local mmRightDesc = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmRightDesc:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -38)
    mmRightDesc:SetPoint("TOPRIGHT", mmRightPanel, "TOPRIGHT", -10, -38)
    mmRightDesc:SetJustifyH("LEFT")
    mmRightDesc:SetWordWrap(true)
    mmRightDesc:SetText(L["MINIMAP_ICON_DESC"])
    mmRightDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local currentMMTheme = addon.db.global.minimap and addon.db.global.minimap.theme or "horde"
    local iconThemeNames = {
        ["horde"]    = L["MINIMAP_ICON_HORDE"],
        ["alliance"] = L["MINIMAP_ICON_ALLIANCE"],
        ["neutral"]  = L["MINIMAP_ICON_NEUTRAL"],
    }

    local mmCurrentLabel = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmCurrentLabel:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -80)
    mmCurrentLabel:SetText(L["MINIMAP_ICON_CURRENT"] .. ": " .. (iconThemeNames[currentMMTheme] or L["MINIMAP_ICON_HORDE"]))
    mmCurrentLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local mmIconDropdown = CreateFrame("Button", nil, mmRightPanel, "BackdropTemplate")
    mmIconDropdown:SetSize(180, 30)
    mmIconDropdown:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -100)
    mmIconDropdown:SetBackdrop(backdrop)
    mmIconDropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    mmIconDropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local mmDropIcon = mmIconDropdown:CreateTexture(nil, "OVERLAY")
    mmDropIcon:SetSize(18, 18)
    mmDropIcon:SetPoint("LEFT", mmIconDropdown, "LEFT", 6, 0)
    local mmDropIconTex
    if currentMMTheme == "alliance" then
        mmDropIconTex = "Interface\\AddOns\\OneWoW_QoL\\Media\\alliance-mini.png"
    elseif currentMMTheme == "neutral" then
        mmDropIconTex = "Interface\\AddOns\\OneWoW_QoL\\Media\\neutral-mini.png"
    else
        mmDropIconTex = "Interface\\AddOns\\OneWoW_QoL\\Media\\horde-mini.png"
    end
    mmDropIcon:SetTexture(mmDropIconTex)

    local mmDropText = mmIconDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmDropText:SetPoint("LEFT", mmDropIcon, "RIGHT", 4, 0)
    mmDropText:SetText(iconThemeNames[currentMMTheme] or L["MINIMAP_ICON_HORDE"])
    mmDropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local mmDropArrow = mmIconDropdown:CreateTexture(nil, "OVERLAY")
    mmDropArrow:SetSize(16, 16)
    mmDropArrow:SetPoint("RIGHT", mmIconDropdown, "RIGHT", -5, 0)
    mmDropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    mmIconDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS")) end)
    mmIconDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE")) end)

    local ICON_TEXTURES = {
        ["horde"]    = "Interface\\AddOns\\OneWoW_QoL\\Media\\horde-mini.png",
        ["alliance"] = "Interface\\AddOns\\OneWoW_QoL\\Media\\alliance-mini.png",
        ["neutral"]  = "Interface\\AddOns\\OneWoW_QoL\\Media\\neutral-mini.png",
    }

    mmIconDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(180, 100)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop(backdrop)
        menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:EnableMouse(true)

        local function createIconBtn(parent, themeKey, yPos)
            local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
            btn:SetSize(170, 26)
            btn:SetPoint("TOP", parent, "TOP", 0, yPos)
            btn:SetBackdrop(BACKDROP_SIMPLE)
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

            local previewIcon = btn:CreateTexture(nil, "OVERLAY")
            previewIcon:SetSize(18, 18)
            previewIcon:SetPoint("LEFT", btn, "LEFT", 8, 0)
            previewIcon:SetTexture(ICON_TEXTURES[themeKey])

            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", btn, "LEFT", 32, 0)
            text:SetText(iconThemeNames[themeKey])
            text:SetTextColor(0.9, 0.9, 0.9)

            btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) text:SetTextColor(1, 0.82, 0) end)
            btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) text:SetTextColor(0.9, 0.9, 0.9) end)

            btn:SetScript("OnClick", function()
                addon.db.global.minimap.theme = themeKey
                if ns.MinimapButton then ns.MinimapButton:UpdateIcon() end
                menu:Hide()
                if ns.UI.Reset then ns.UI:Reset() end
                C_Timer.After(0.1, function()
                    if ns.UI.Show then ns.UI:Show("settings") end
                end)
            end)
            return btn
        end

        createIconBtn(menu, "horde", -5)
        createIconBtn(menu, "alliance", -33)
        createIconBtn(menu, "neutral", -61)

        menu:SetScript("OnShow", function(self)
            local timeOutside = 0
            self:SetScript("OnUpdate", function(self, elapsed)
                if not MouseIsOver(menu) and not MouseIsOver(mmIconDropdown) then
                    timeOutside = timeOutside + elapsed
                    if timeOutside > 0.5 then self:Hide() self:SetScript("OnUpdate", nil) end
                else timeOutside = 0 end
            end)
        end)
    end)

    yOffset = yOffset - 145

    end -- if not _G.OneWoW

    yOffset = yOffset - 20
    local devHeader = CreateSectionHeader(scrollChild, L["SETTINGS_DEVELOPER_HEADER"], yOffset)
    yOffset = yOffset - devHeader:GetStringHeight() - 8
    CreateSectionDivider(scrollChild, yOffset)
    yOffset = yOffset - 12

    local devDesc = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    devDesc:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, yOffset)
    devDesc:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -16, yOffset)
    devDesc:SetJustifyH("LEFT")
    devDesc:SetWordWrap(true)
    devDesc:SetSpacing(3)
    devDesc:SetText(L["SETTINGS_DEVELOPER_DESC"])
    devDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - devDesc:GetStringHeight() - 14

    local devHelpBtn = OneWoW_GUI:CreateButton(nil, scrollChild, L["SETTINGS_DEV_HELP_BTN"], 160, 32)
    devHelpBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, yOffset)
    devHelpBtn:SetScript("OnClick", function()
        ShowDevHelpDialog()
    end)

    yOffset = yOffset - 50

    scrollChild:SetHeight(math.abs(yOffset) + 20)
    C_Timer.After(0.1, function() UpdateThumb() end)
end
