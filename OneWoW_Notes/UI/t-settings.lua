-- OneWoW_Notes Addon File
-- OneWoW_Notes/UI/t-settings.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

local THEMES_ORDER = { "green", "blue", "purple", "red", "orange", "teal", "gold", "pink", "dark", "amber", "cyan", "slate", "voidblack", "charcoal", "forestnight", "obsidian", "monochrome", "twilight", "neon", "glassmorphic", "lightmode", "retro", "fantasy", "nightfae" }
local THEME_LOCALE_KEYS = {
    green  = "THEME_GREEN",
    blue   = "THEME_BLUE",
    purple = "THEME_PURPLE",
    red    = "THEME_RED",
    orange = "THEME_ORANGE",
    teal   = "THEME_TEAL",
    gold   = "THEME_GOLD",
    pink   = "THEME_PINK",
    dark   = "THEME_DARK",
    amber  = "THEME_AMBER",
    cyan   = "THEME_CYAN",
    slate  = "THEME_SLATE",
    voidblack   = "THEME_VOID_BLACK",
    charcoal    = "THEME_CHARCOAL_DEEP",
    forestnight = "THEME_FOREST_NIGHT",
    obsidian    = "THEME_OBSIDIAN_MINIMAL",
    monochrome  = "THEME_MONOCHROME_PRO",
    twilight    = "THEME_TWILIGHT_COMPACT",
    neon        = "THEME_NEON_SYNTHWAVE",
    glassmorphic = "THEME_GLASSMORPHIC",
    lightmode   = "THEME_MINIMAL_WHITE",
    retro       = "THEME_RETRO_CLASSIC",
    fantasy     = "THEME_RPG_FANTASY",
    nightfae    = "THEME_COVENANT_TWILIGHT",
}

local LANGUAGES = {
    { key = "enUS", labelKey = "LANG_ENUS" },
    { key = "koKR", labelKey = "LANG_KOKR" },
}

local function CreateSectionHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    header:SetText(text)
    header:SetTextColor(T("ACCENT_PRIMARY"))
    return header
end

local function CreateSectionDivider(parent, yOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yOffset)
    divider:SetColorTexture(T("BORDER_SUBTLE"))
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
    scrollTrack:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    scrollTrack:SetBackdropColor(T("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(40)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    scrollThumb:SetBackdropColor(T("ACCENT_PRIMARY"))

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
            scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
            return
        end
        local trackH = scrollTrack:GetHeight()
        local thumbH = math.max(20, (frameH / contentH) * trackH)
        scrollThumb:SetHeight(thumbH)
        local maxOffset = trackH - thumbH
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
    scrollThumb:SetScript("OnMouseUp",  function(self) self.dragging = false end)
    scrollThumb:SetScript("OnDragStop", function(self) self.dragging = false end)
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

    local addon = _G.OneWoW_Notes
    local yOffset = -20

    if not _G.OneWoW then

    local splitContainer = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    splitContainer:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, yOffset)
    splitContainer:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -16, yOffset)
    splitContainer:SetHeight(165)
    splitContainer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    splitContainer:SetBackdropColor(T("BG_SECONDARY"))
    splitContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local leftPanel = CreateFrame("Frame", nil, splitContainer)
    leftPanel:SetPoint("TOPLEFT", splitContainer, "TOPLEFT", 0, 0)
    leftPanel:SetPoint("BOTTOMRIGHT", splitContainer, "BOTTOM", 0, 0)

    local langTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    langTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -12)
    langTitle:SetText(L["SETTINGS_LANGUAGE"])
    langTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local langDescText = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDescText:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -38)
    langDescText:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -10, -38)
    langDescText:SetJustifyH("LEFT")
    langDescText:SetWordWrap(true)
    langDescText:SetText(L["SETTINGS_LANGUAGE_DESC"])
    langDescText:SetTextColor(T("TEXT_SECONDARY"))

    local currentLang = addon.db.global.language or "enUS"
    local currentLangName = L["LANG_ENUS"]
    for _, lang in ipairs(LANGUAGES) do
        if lang.key == currentLang then currentLangName = L[lang.labelKey] or lang.key break end
    end

    local langCurrentLabel = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langCurrentLabel:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -90)
    langCurrentLabel:SetText(L["SETTINGS_LANGUAGE"] .. ": " .. currentLangName)
    langCurrentLabel:SetTextColor(T("ACCENT_PRIMARY"))

    local langDropdown = CreateFrame("Button", nil, leftPanel, "BackdropTemplate")
    langDropdown:SetSize(190, 30)
    langDropdown:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -115)
    langDropdown:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    langDropdown:SetBackdropColor(T("BG_TERTIARY"))
    langDropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local langDropText = langDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDropText:SetPoint("CENTER")
    langDropText:SetText(currentLangName)
    langDropText:SetTextColor(T("TEXT_PRIMARY"))

    local langDropArrow = langDropdown:CreateTexture(nil, "OVERLAY")
    langDropArrow:SetSize(16, 16)
    langDropArrow:SetPoint("RIGHT", langDropdown, "RIGHT", -5, 0)
    langDropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    langDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(T("BG_HOVER")) self:SetBackdropBorderColor(T("BORDER_FOCUS")) end)
    langDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(T("BG_TERTIARY")) self:SetBackdropBorderColor(T("BORDER_SUBTLE")) end)

    langDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(190, #LANGUAGES * 27 + 10)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:EnableMouse(true)
        for i, lang in ipairs(LANGUAGES) do
            local btn = CreateFrame("Button", nil, menu, "BackdropTemplate")
            btn:SetSize(180, 25)
            btn:SetPoint("TOP", menu, "TOP", 0, -(5 + (i - 1) * 27))
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
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
    vertDivider:SetColorTexture(T("BORDER_SUBTLE"))

    local rightPanel = CreateFrame("Frame", nil, splitContainer)
    rightPanel:SetPoint("TOPLEFT", splitContainer, "TOP", 0, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", splitContainer, "BOTTOMRIGHT", 0, 0)

    local currentTheme = addon.db.global.theme or "green"
    local themeTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    themeTitle:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -12)
    themeTitle:SetText(L["SETTINGS_THEME"])
    themeTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local themeDescText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDescText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -38)
    themeDescText:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -10, -38)
    themeDescText:SetJustifyH("LEFT")
    themeDescText:SetWordWrap(true)
    themeDescText:SetText(L["SETTINGS_THEME_DESC"])
    themeDescText:SetTextColor(T("TEXT_SECONDARY"))

    local currentThemeData = ns.Constants.THEMES[currentTheme]
    local currentThemeName = L[THEME_LOCALE_KEYS[currentTheme]] or currentTheme

    local themeCurrentLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeCurrentLabel:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -90)
    themeCurrentLabel:SetText(L["SETTINGS_THEME"] .. ": " .. currentThemeName)
    themeCurrentLabel:SetTextColor(T("ACCENT_PRIMARY"))

    local themeDropdown = CreateFrame("Button", nil, rightPanel, "BackdropTemplate")
    themeDropdown:SetSize(210, 30)
    themeDropdown:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -115)
    themeDropdown:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    themeDropdown:SetBackdropColor(T("BG_TERTIARY"))
    themeDropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local themeDropText = themeDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDropText:SetPoint("LEFT", themeDropdown, "LEFT", 25, 0)
    themeDropText:SetText(currentThemeName)
    themeDropText:SetTextColor(T("TEXT_PRIMARY"))

    local themeColorPreview = themeDropdown:CreateTexture(nil, "OVERLAY")
    themeColorPreview:SetSize(14, 14)
    themeColorPreview:SetPoint("LEFT", themeDropdown, "LEFT", 6, 0)
    if currentThemeData then themeColorPreview:SetColorTexture(unpack(currentThemeData.ACCENT_PRIMARY)) end

    local themeDropArrow = themeDropdown:CreateTexture(nil, "OVERLAY")
    themeDropArrow:SetSize(16, 16)
    themeDropArrow:SetPoint("RIGHT", themeDropdown, "RIGHT", -5, 0)
    themeDropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    themeDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(T("BG_HOVER")) self:SetBackdropBorderColor(T("BORDER_FOCUS")) end)
    themeDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(T("BG_TERTIARY")) self:SetBackdropBorderColor(T("BORDER_SUBTLE")) end)

    themeDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(240, 318)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
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
        scrollBar:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
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
            local themeData = ns.Constants.THEMES[themeKey]
            if themeData then
                local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                btn:SetSize(230, 26)
                btn:SetPoint("TOP", scrollChild, "TOP", 0, -(5 + (i - 1) * 28))
                btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
                btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                local dot = btn:CreateTexture(nil, "OVERLAY")
                dot:SetSize(14, 14)
                dot:SetPoint("LEFT", btn, "LEFT", 8, 0)
                dot:SetColorTexture(unpack(themeData.ACCENT_PRIMARY))
                local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                txt:SetPoint("LEFT", btn, "LEFT", 28, 0)
                txt:SetText(L[THEME_LOCALE_KEYS[themeKey]] or themeKey)
                txt:SetTextColor(0.9, 0.9, 0.9)
                btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) txt:SetTextColor(1, 0.82, 0) end)
                btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) txt:SetTextColor(0.9, 0.9, 0.9) end)
                local capturedKey = themeKey
                btn:SetScript("OnClick", function()
                    addon.db.global.theme = capturedKey
                    themeDropText:SetText(L[THEME_LOCALE_KEYS[capturedKey]] or capturedKey)
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
    mmContainer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    mmContainer:SetBackdropColor(T("BG_SECONDARY"))
    mmContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local mmLeftPanel = CreateFrame("Frame", nil, mmContainer)
    mmLeftPanel:SetPoint("TOPLEFT", mmContainer, "TOPLEFT", 0, 0)
    mmLeftPanel:SetPoint("BOTTOMRIGHT", mmContainer, "BOTTOM", 0, 0)

    local mmLeftTitle = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mmLeftTitle:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -12)
    mmLeftTitle:SetText(L["MINIMAP_SECTION"])
    mmLeftTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local mmLeftDesc = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmLeftDesc:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -38)
    mmLeftDesc:SetPoint("TOPRIGHT", mmLeftPanel, "TOPRIGHT", -10, -38)
    mmLeftDesc:SetJustifyH("LEFT")
    mmLeftDesc:SetWordWrap(true)
    mmLeftDesc:SetText(L["MINIMAP_SECTION_DESC"])
    mmLeftDesc:SetTextColor(T("TEXT_SECONDARY"))

    local mmShowCheck = CreateFrame("CheckButton", nil, mmLeftPanel, "UICheckButtonTemplate")
    mmShowCheck:SetSize(26, 26)
    mmShowCheck:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 10, -85)
    local isMinimapHidden = addon.db and addon.db.global and addon.db.global.minimap and addon.db.global.minimap.hide
    mmShowCheck:SetChecked(not isMinimapHidden)

    local mmShowLabel = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmShowLabel:SetPoint("LEFT", mmShowCheck, "RIGHT", 4, 0)
    mmShowLabel:SetText(L["MINIMAP_SHOW_BTN"])
    mmShowLabel:SetTextColor(T("TEXT_PRIMARY"))

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
    mmVertDivider:SetColorTexture(T("BORDER_SUBTLE"))

    local mmRightPanel = CreateFrame("Frame", nil, mmContainer)
    mmRightPanel:SetPoint("TOPLEFT", mmContainer, "TOP", 0, 0)
    mmRightPanel:SetPoint("BOTTOMRIGHT", mmContainer, "BOTTOMRIGHT", 0, 0)

    local mmRightTitle = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mmRightTitle:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -12)
    mmRightTitle:SetText(L["MINIMAP_ICON_SECTION"])
    mmRightTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local mmRightDesc = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmRightDesc:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -38)
    mmRightDesc:SetPoint("TOPRIGHT", mmRightPanel, "TOPRIGHT", -10, -38)
    mmRightDesc:SetJustifyH("LEFT")
    mmRightDesc:SetWordWrap(true)
    mmRightDesc:SetText(L["MINIMAP_ICON_DESC"])
    mmRightDesc:SetTextColor(T("TEXT_SECONDARY"))

    local currentMMTheme = addon.db.global.minimap and addon.db.global.minimap.theme or "horde"
    local iconThemeNames = {
        ["horde"]    = L["MINIMAP_ICON_HORDE"],
        ["alliance"] = L["MINIMAP_ICON_ALLIANCE"],
        ["neutral"]  = L["MINIMAP_ICON_NEUTRAL"],
    }

    local mmCurrentLabel = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmCurrentLabel:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -80)
    mmCurrentLabel:SetText(L["MINIMAP_ICON_CURRENT"] .. ": " .. (iconThemeNames[currentMMTheme] or L["MINIMAP_ICON_HORDE"]))
    mmCurrentLabel:SetTextColor(T("ACCENT_PRIMARY"))

    local mmIconDropdown = CreateFrame("Button", nil, mmRightPanel, "BackdropTemplate")
    mmIconDropdown:SetSize(180, 30)
    mmIconDropdown:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -100)
    mmIconDropdown:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    mmIconDropdown:SetBackdropColor(T("BG_TERTIARY"))
    mmIconDropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local mmDropIcon = mmIconDropdown:CreateTexture(nil, "OVERLAY")
    mmDropIcon:SetSize(18, 18)
    mmDropIcon:SetPoint("LEFT", mmIconDropdown, "LEFT", 6, 0)
    local mmDropIconTex
    if currentMMTheme == "alliance" then
        mmDropIconTex = "Interface\\AddOns\\OneWoW_Notes\\Media\\alliance-mini.png"
    elseif currentMMTheme == "neutral" then
        mmDropIconTex = "Interface\\AddOns\\OneWoW_Notes\\Media\\neutral-mini.png"
    else
        mmDropIconTex = "Interface\\AddOns\\OneWoW_Notes\\Media\\horde-mini.png"
    end
    mmDropIcon:SetTexture(mmDropIconTex)

    local mmDropText = mmIconDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmDropText:SetPoint("LEFT", mmDropIcon, "RIGHT", 4, 0)
    mmDropText:SetText(iconThemeNames[currentMMTheme] or L["MINIMAP_ICON_HORDE"])
    mmDropText:SetTextColor(T("TEXT_PRIMARY"))

    local mmDropArrow = mmIconDropdown:CreateTexture(nil, "OVERLAY")
    mmDropArrow:SetSize(16, 16)
    mmDropArrow:SetPoint("RIGHT", mmIconDropdown, "RIGHT", -5, 0)
    mmDropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    mmIconDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(T("BG_HOVER")) self:SetBackdropBorderColor(T("BORDER_FOCUS")) end)
    mmIconDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(T("BG_TERTIARY")) self:SetBackdropBorderColor(T("BORDER_SUBTLE")) end)

    local ICON_TEXTURES = {
        ["horde"]    = "Interface\\AddOns\\OneWoW_Notes\\Media\\horde-mini.png",
        ["alliance"] = "Interface\\AddOns\\OneWoW_Notes\\Media\\alliance-mini.png",
        ["neutral"]  = "Interface\\AddOns\\OneWoW_Notes\\Media\\neutral-mini.png",
    }

    mmIconDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(180, 100)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:EnableMouse(true)

        local function createIconBtn(parent, themeKey, yPos)
            local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
            btn:SetSize(170, 26)
            btn:SetPoint("TOP", parent, "TOP", 0, yPos)
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
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

    -- =============================================
    -- DETECTION & ALERTS SECTION
    -- =============================================
    yOffset = yOffset - 20
    local detectionHeader = CreateSectionHeader(scrollChild, L["SETTINGS_DETECTION"] or "Detection & Alerts", yOffset)
    yOffset = yOffset - detectionHeader:GetStringHeight() - 8
    CreateSectionDivider(scrollChild, yOffset)
    yOffset = yOffset - 16

    local function CreateDetectionRow(parent, labelKey, descKey, isEnabled, onToggle, yPos)
        local rowFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        rowFrame:SetPoint("TOPLEFT",  parent, "TOPLEFT",  16, yPos)
        rowFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yPos)
        rowFrame:SetHeight(62)
        rowFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = true, tileSize = 16, edgeSize = 1,
        })
        rowFrame:SetBackdropColor(T("BG_SECONDARY"))
        rowFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        -- Toggle button (left side)
        local toggleBtn = CreateFrame("Button", nil, rowFrame, "BackdropTemplate")
        toggleBtn:SetSize(70, 28)
        toggleBtn:SetPoint("LEFT", rowFrame, "LEFT", 10, 0)
        toggleBtn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        local toggleLabel = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        toggleLabel:SetPoint("CENTER")

        local function RefreshToggle(enabled)
            if enabled then
                toggleBtn:SetBackdropColor(T("BG_ACTIVE"))
                toggleBtn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
                toggleLabel:SetText(L["SETTINGS_ENABLED"] or "On")
                toggleLabel:SetTextColor(T("ACCENT_PRIMARY"))
            else
                toggleBtn:SetBackdropColor(T("BG_TERTIARY"))
                toggleBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                toggleLabel:SetText(L["SETTINGS_DISABLED"] or "Off")
                toggleLabel:SetTextColor(T("TEXT_MUTED"))
            end
        end

        RefreshToggle(isEnabled())

        toggleBtn:SetScript("OnClick", function()
            local newState = onToggle()
            RefreshToggle(newState)
        end)
        toggleBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
        end)
        toggleBtn:SetScript("OnLeave", function(self)
            RefreshToggle(isEnabled())
        end)

        -- Label (right of toggle)
        local label = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT",  rowFrame, "TOPLEFT", 90, -12)
        label:SetPoint("TOPRIGHT", rowFrame, "TOPRIGHT", -10, -12)
        label:SetJustifyH("LEFT")
        label:SetText(L[labelKey] or labelKey)
        label:SetTextColor(T("TEXT_PRIMARY"))

        -- Description
        local desc = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        desc:SetPoint("TOPLEFT",  label, "BOTTOMLEFT", 0, -4)
        desc:SetPoint("TOPRIGHT", rowFrame, "TOPRIGHT", -10, 0)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetText(L[descKey] or "")
        desc:SetTextColor(T("TEXT_MUTED"))

        return rowFrame
    end

    -- NPC Detection
    local npcRow = CreateDetectionRow(
        scrollChild,
        "SETTINGS_NPC_DETECTION",
        "SETTINGS_NPC_DETECTION_DESC",
        function() return ns.NPCs and ns.NPCs:IsScanning() end,
        function()
            if ns.NPCs then
                if ns.NPCs:IsScanning() then
                    ns.NPCs:DisableScanning()
                    return false
                else
                    ns.NPCs:EnableScanning()
                    return true
                end
            end
            return false
        end,
        yOffset
    )
    yOffset = yOffset - 70

    -- Player Detection
    local playerRow = CreateDetectionRow(
        scrollChild,
        "SETTINGS_PLAYER_DETECTION",
        "SETTINGS_PLAYER_DETECTION_DESC",
        function() return ns.Players and ns.Players:IsScanning() end,
        function()
            if ns.Players then
                if ns.Players:IsScanning() then
                    ns.Players:DisableScanning()
                    return false
                else
                    ns.Players:EnableScanning()
                    return true
                end
            end
            return false
        end,
        yOffset
    )
    yOffset = yOffset - 70

    -- Zone Alerts
    local zoneRow = CreateDetectionRow(
        scrollChild,
        "SETTINGS_ZONE_ALERTS",
        "SETTINGS_ZONE_ALERTS_DESC",
        function() return ns.Zones and ns.Zones:IsScanning() end,
        function()
            if ns.Zones then
                if ns.Zones:IsScanning() then
                    ns.Zones:DisableScanning()
                    return false
                else
                    ns.Zones:EnableScanning()
                    return true
                end
            end
            return false
        end,
        yOffset
    )
    yOffset = yOffset - 70

    -- =============================================
    -- IMPORT FROM WOWNOTES SECTION
    -- =============================================
    yOffset = yOffset - 20
    local importHeader = CreateSectionHeader(scrollChild, L["SETTINGS_IMPORT_SECTION"] or "Import From WoWNotes", yOffset)
    yOffset = yOffset - importHeader:GetStringHeight() - 8
    CreateSectionDivider(scrollChild, yOffset)
    yOffset = yOffset - 16

    local importContainer = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    importContainer:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  16, yOffset)
    importContainer:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -16, yOffset)
    importContainer:SetHeight(160)
    importContainer:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true, tileSize = 16, edgeSize = 1,
    })
    importContainer:SetBackdropColor(T("BG_SECONDARY"))
    importContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local importDesc = importContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importDesc:SetPoint("TOPLEFT",  importContainer, "TOPLEFT",  16, -14)
    importDesc:SetPoint("TOPRIGHT", importContainer, "TOPRIGHT", -16, -14)
    importDesc:SetJustifyH("LEFT")
    importDesc:SetWordWrap(true)
    importDesc:SetText(L["SETTINGS_IMPORT_DESC"] or "")
    importDesc:SetTextColor(T("TEXT_SECONDARY"))

    local importBtn = CreateFrame("Button", nil, importContainer, "BackdropTemplate")
    importBtn:SetSize(200, 28)
    importBtn:SetPoint("BOTTOMLEFT", importContainer, "BOTTOMLEFT", 16, 14)
    importBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    importBtn:SetBackdropColor(T("BG_TERTIARY"))
    importBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local importBtnLabel = importBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importBtnLabel:SetPoint("CENTER")
    importBtnLabel:SetText(L["SETTINGS_IMPORT_BUTTON"] or "Import From WoWNotes")
    importBtnLabel:SetTextColor(T("TEXT_PRIMARY"))

    importBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
    end)
    importBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    local importStatus = importContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importStatus:SetPoint("LEFT",  importBtn,       "RIGHT", 12,   0)
    importStatus:SetPoint("RIGHT", importContainer, "RIGHT", -16,  0)
    importStatus:SetJustifyH("LEFT")
    importStatus:SetWordWrap(true)
    importStatus:SetText("")

    importBtn:SetScript("OnClick", function()
        if not ns.ImportFromWoWNotes then return end
        local success, result = ns.ImportFromWoWNotes:Run()
        if not success then
            importStatus:SetText(L["SETTINGS_IMPORT_NO_DATA"] or "WoWNotes data not found.")
            importStatus:SetTextColor(1, 0.3, 0.3)
        else
            importStatus:SetText(string.format(
                L["SETTINGS_IMPORT_SUCCESS"] or "Done! Notes: %d, Players: %d, NPCs: %d, Zones: %d, Items: %d",
                result.notes, result.players, result.npcs, result.zones, result.items))
            importStatus:SetTextColor(T("ACCENT_PRIMARY"))
            if ns.UI.Reset then ns.UI:Reset() end
            C_Timer.After(0.05, function()
                if ns.UI.Show then ns.UI:Show("settings") end
            end)
        end
    end)

    yOffset = yOffset - 175

    scrollChild:SetHeight(math.abs(yOffset) + 20)
    C_Timer.After(0.1, function() UpdateThumb() end)
end
