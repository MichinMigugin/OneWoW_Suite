local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI

local function T(key)
    if OneWoW.Constants and OneWoW.Constants.THEME and OneWoW.Constants.THEME[key] then
        return unpack(OneWoW.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if OneWoW.Constants and OneWoW.Constants.SPACING then
        return OneWoW.Constants.SPACING[key] or 8
    end
    return 8
end

local function SyncSettingToChildAddons(settingType, value)
    local integratedAddons = {
        "OneWoW_AltTracker",
        "OneWoW_Notes",
        "OneWoW_QoL",
        "OneWoW_Catalog",
        "OneWoW_DirectDeposit",
        "OneWoW_ShoppingList",
        "OneWoW_UtilityDevTool",
        "OneWoW_UtilityExtractor",
    }

    for _, globalName in ipairs(integratedAddons) do
        local addon = _G[globalName]
        if addon then
            if settingType == "theme" and addon.ApplyTheme then
                addon:ApplyTheme()
            elseif settingType == "language" and addon.ApplyLanguage then
                if addon.db and addon.db.global then
                    addon.db.global.language = value
                end
                addon:ApplyLanguage()
            end
        end
    end
end

local function CreateDropdownMenu(parent, options, onSelect)
    local menu = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    menu:SetBackdropColor(T("BG_PRIMARY"))
    menu:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local yOff = -4
    local maxWidth = 180
    for _, opt in ipairs(options) do
        local btn = CreateFrame("Button", nil, menu, "BackdropTemplate")
        btn:SetHeight(24)
        btn:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, yOff)
        btn:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, yOff)
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        btn:SetBackdropColor(0, 0, 0, 0)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("LEFT", 8, 0)
        btn.text:SetText(opt.label)
        btn.text:SetTextColor(T("TEXT_PRIMARY"))

        local textW = btn.text:GetStringWidth() + 20
        if textW > maxWidth then maxWidth = textW end

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0)
        end)
        btn:SetScript("OnClick", function()
            menu:Hide()
            onSelect(opt.value, opt.label)
        end)

        yOff = yOff - 24
    end

    menu:SetSize(maxWidth + 16, math.abs(yOff) + 8)
    menu:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -2)

    menu:SetScript("OnShow", function(self)
        local timeOutside = 0
        self:SetScript("OnUpdate", function(self, elapsed)
            if not MouseIsOver(menu) and not MouseIsOver(parent) then
                timeOutside = timeOutside + elapsed
                if timeOutside > 0.5 then
                    self:Hide()
                    self:SetScript("OnUpdate", nil)
                end
            else
                timeOutside = 0
            end
        end)
    end)

    return menu
end

function GUI:CreateSettingsMainTab(parent)
    local L = OneWoW.L or {}
    local Constants = OneWoW.Constants

    local scrollFrame, content = GUI:CreateScrollFrame("OneWoW_SettingsScroll", parent)
    content:SetHeight(800)

    local yOffset = -10

    local splitContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    splitContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    splitContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    splitContainer:SetHeight(165)
    splitContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    splitContainer:SetBackdropColor(T("BG_SECONDARY"))
    splitContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local leftPanel = CreateFrame("Frame", nil, splitContainer)
    leftPanel:SetPoint("TOPLEFT", splitContainer, "TOPLEFT", 0, 0)
    leftPanel:SetPoint("BOTTOMRIGHT", splitContainer, "BOTTOM", 0, 0)

    local vertDivider = splitContainer:CreateTexture(nil, "ARTWORK")
    vertDivider:SetWidth(1)
    vertDivider:SetPoint("TOP", splitContainer, "TOP", 0, -8)
    vertDivider:SetPoint("BOTTOM", splitContainer, "BOTTOM", 0, 8)
    vertDivider:SetColorTexture(T("BORDER_SUBTLE"))

    local rightPanel = CreateFrame("Frame", nil, splitContainer)
    rightPanel:SetPoint("TOPLEFT", splitContainer, "TOP", 0, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", splitContainer, "BOTTOMRIGHT", 0, 0)

    local langTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    langTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -12)
    langTitle:SetText(L["LANGUAGE_SELECTION"] or "Language Selection")
    langTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local langDesc = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDesc:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -38)
    langDesc:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -15, -38)
    langDesc:SetText(L["LANGUAGE_DESC"] or "Choose your preferred language.")
    langDesc:SetTextColor(T("TEXT_SECONDARY"))
    langDesc:SetJustifyH("LEFT")
    langDesc:SetWordWrap(true)

    local currentLang = OneWoW.db and OneWoW.db.global and OneWoW.db.global.language or "enUS"
    local langNames = {
        enUS = L["ENGLISH"] or "English",
        esES = L["SPANISH"] or "Español",
        koKR = L["KOREAN"] or "한국어",
        frFR = L["FRENCH"] or "Français",
        ruRU = L["RUSSIAN"] or "Русский",
        deDE = L["GERMAN"] or "Deutsch",
    }

    local currentLangLabel = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentLangLabel:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -90)
    currentLangLabel:SetText((L["CURRENT_LANGUAGE"] or "Current") .. ": " .. (langNames[currentLang] or currentLang))
    currentLangLabel:SetTextColor(T("ACCENT_PRIMARY"))

    local langDropdown = CreateFrame("Button", nil, leftPanel, "BackdropTemplate")
    langDropdown:SetSize(190, 30)
    langDropdown:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -115)
    langDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    langDropdown:SetBackdropColor(T("BG_TERTIARY"))
    langDropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local langDropText = langDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDropText:SetPoint("LEFT", 10, 0)
    langDropText:SetText(langNames[currentLang] or currentLang)
    langDropText:SetTextColor(T("TEXT_PRIMARY"))

    local langArrow = langDropdown:CreateTexture(nil, "OVERLAY")
    langArrow:SetSize(16, 16)
    langArrow:SetPoint("RIGHT", langDropdown, "RIGHT", -5, 0)
    langArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    local langMenu = nil
    langDropdown:SetScript("OnClick", function(self)
        if langMenu and langMenu:IsShown() then
            langMenu:Hide()
            return
        end
        local options = {
            { label = "English",   value = "enUS" },
            { label = "Español",  value = "esES" },
            { label = "한국어",    value = "koKR" },
            { label = "Français", value = "frFR" },
            { label = "Русский",  value = "ruRU" },
            { label = "Deutsch",   value = "deDE" },
        }
        langMenu = CreateDropdownMenu(self, options, function(value, label)
            OneWoW.db.global.language = value
            local lang = value
            if lang == "esMX" then lang = "esES" end
            local localeData = OneWoW.Locales[lang] or OneWoW.Locales["enUS"]
            local fallback = OneWoW.Locales["enUS"]
            for k, v in pairs(fallback) do
                OneWoW.L[k] = localeData[k] or v
            end
            SyncSettingToChildAddons("language", value)
            GUI:FullReset()
            C_Timer.After(0.1, function() GUI:Show() end)
        end)
        langMenu:Show()
    end)

    local themeTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    themeTitle:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -12)
    themeTitle:SetText(L["THEME_SECTION"] or "Color Theme")
    themeTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local themeDesc = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDesc:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -38)
    themeDesc:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -15, -38)
    themeDesc:SetText(L["THEME_DESC"] or "Choose your preferred theme.")
    themeDesc:SetTextColor(T("TEXT_SECONDARY"))
    themeDesc:SetJustifyH("LEFT")
    themeDesc:SetWordWrap(true)

    local currentThemeKey = OneWoW.db and OneWoW.db.global and OneWoW.db.global.theme or "green"
    local themeNameKeys = {
        green = "THEME_GREEN", blue = "THEME_BLUE", purple = "THEME_PURPLE",
        gold = "THEME_GOLD", red = "THEME_RED", slate = "THEME_SLATE",
        orange = "THEME_ORANGE", teal = "THEME_TEAL", cyan = "THEME_CYAN",
        pink = "THEME_PINK", dark = "THEME_DARK", amber = "THEME_AMBER",
        voidblack = "THEME_VOIDBLACK", charcoal = "THEME_CHARCOAL", forestnight = "THEME_FORESTNIGHT",
        obsidian = "THEME_OBSIDIAN", monochrome = "THEME_MONOCHROME", twilight = "THEME_TWILIGHT",
        neon = "THEME_NEON", glassmorphic = "THEME_GLASSMORPHIC", lightmode = "THEME_LIGHTMODE",
        retro = "THEME_RETRO", fantasy = "THEME_FANTASY", nightfae = "THEME_NIGHTFAE",
    }
    local currentThemeName = L[themeNameKeys[currentThemeKey] or "THEME_GREEN"] or "Forest Green"

    local currentThemeLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentThemeLabel:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -90)
    currentThemeLabel:SetText((L["THEME_CURRENT"] or "Current") .. ": " .. currentThemeName)
    currentThemeLabel:SetTextColor(T("ACCENT_PRIMARY"))

    local themeDropdown = CreateFrame("Button", nil, rightPanel, "BackdropTemplate")
    themeDropdown:SetSize(190, 30)
    themeDropdown:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -115)
    themeDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    themeDropdown:SetBackdropColor(T("BG_TERTIARY"))
    themeDropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local themeDropText = themeDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDropText:SetPoint("LEFT", 10, 0)
    themeDropText:SetText(currentThemeName)
    themeDropText:SetTextColor(T("TEXT_PRIMARY"))

    local themeArrow = themeDropdown:CreateTexture(nil, "OVERLAY")
    themeArrow:SetSize(16, 16)
    themeArrow:SetPoint("RIGHT", themeDropdown, "RIGHT", -5, 0)
    themeArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    local themeMenu = nil
    themeDropdown:SetScript("OnClick", function(self)
        if themeMenu and themeMenu:IsShown() then
            themeMenu:Hide()
            return
        end
        local themeOrder = { "green", "blue", "purple", "gold", "red", "slate", "orange", "teal", "cyan", "pink", "dark", "amber", "voidblack", "charcoal", "forestnight", "obsidian", "monochrome", "twilight", "neon", "glassmorphic", "lightmode", "retro", "fantasy", "nightfae" }

        themeMenu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        themeMenu:SetFrameStrata("FULLSCREEN_DIALOG")
        themeMenu:SetSize(240, 318)
        themeMenu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        themeMenu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false,
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        themeMenu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        themeMenu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        themeMenu:EnableMouse(true)

        local scrollFrame = CreateFrame("ScrollFrame", nil, themeMenu)
        scrollFrame:SetPoint("TOPLEFT", themeMenu, "TOPLEFT", 2, -2)
        scrollFrame:SetPoint("BOTTOMRIGHT", themeMenu, "BOTTOMRIGHT", -15, 2)

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

        for i, themeKey in ipairs(themeOrder) do
            local themeData = Constants.THEMES[themeKey]
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
                txt:SetText(L[themeNameKeys[themeKey]] or themeData.name)
                txt:SetTextColor(0.9, 0.9, 0.9)
                btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) txt:SetTextColor(1, 0.82, 0) end)
                btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) txt:SetTextColor(0.9, 0.9, 0.9) end)
                local capturedKey = themeKey
                btn:SetScript("OnClick", function()
                    OneWoW.db.global.theme = capturedKey
                    themeDropText:SetText(L[themeNameKeys[capturedKey]] or themeData.name)
                    if Constants.THEMES and Constants.THEMES[capturedKey] then
                        local selectedTheme = Constants.THEMES[capturedKey]
                        for k, v in pairs(selectedTheme) do
                            if k ~= "name" then
                                Constants.THEME[k] = v
                            end
                        end
                    end
                    SyncSettingToChildAddons("theme", capturedKey)
                    themeMenu:Hide()
                    GUI:FullReset()
                    C_Timer.After(0.1, function() GUI:Show() end)
                end)
            end
        end
        scrollChild:SetHeight(#themeOrder * 28 + 10)
        local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        scrollBar:SetMinMaxValues(0, maxScroll)
        scrollFrame:SetVerticalScroll(0)
        themeMenu:SetScript("OnShow", function(self)
            local timeOutside = 0
            self:SetScript("OnUpdate", function(self, elapsed)
                if not MouseIsOver(themeMenu) and not MouseIsOver(themeDropdown) then
                    timeOutside = timeOutside + elapsed
                    if timeOutside > 0.5 then self:Hide() self:SetScript("OnUpdate", nil) end
                else timeOutside = 0 end
            end)
        end)

        themeMenu:Show()
    end)

    yOffset = yOffset - 185

    local minimapContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    minimapContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    minimapContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    minimapContainer:SetHeight(165)
    minimapContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    minimapContainer:SetBackdropColor(T("BG_SECONDARY"))
    minimapContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local mmLeftPanel = CreateFrame("Frame", nil, minimapContainer)
    mmLeftPanel:SetPoint("TOPLEFT", minimapContainer, "TOPLEFT", 0, 0)
    mmLeftPanel:SetPoint("BOTTOMRIGHT", minimapContainer, "BOTTOM", 0, 0)

    local mmVertDiv = minimapContainer:CreateTexture(nil, "ARTWORK")
    mmVertDiv:SetWidth(1)
    mmVertDiv:SetPoint("TOP", minimapContainer, "TOP", 0, -8)
    mmVertDiv:SetPoint("BOTTOM", minimapContainer, "BOTTOM", 0, 8)
    mmVertDiv:SetColorTexture(T("BORDER_SUBTLE"))

    local mmRightPanel = CreateFrame("Frame", nil, minimapContainer)
    mmRightPanel:SetPoint("TOPLEFT", minimapContainer, "TOP", 0, 0)
    mmRightPanel:SetPoint("BOTTOMRIGHT", minimapContainer, "BOTTOMRIGHT", 0, 0)

    local mmTitle = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mmTitle:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -12)
    mmTitle:SetText(L["MINIMAP_SECTION"] or "Minimap Button")
    mmTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local mmDesc = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmDesc:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -38)
    mmDesc:SetPoint("TOPRIGHT", mmLeftPanel, "TOPRIGHT", -15, -38)
    mmDesc:SetText(L["MINIMAP_SECTION_DESC"] or "Show or hide the minimap button.")
    mmDesc:SetTextColor(T("TEXT_SECONDARY"))
    mmDesc:SetJustifyH("LEFT")
    mmDesc:SetWordWrap(true)

    local mmCheckbox = GUI:CreateCheckbox("OneWoW_MinimapShowCB", mmLeftPanel, L["MINIMAP_SHOW_BTN"] or "Show Minimap Button")
    mmCheckbox:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 12, -80)
    local mmHidden = OneWoW.db and OneWoW.db.global and OneWoW.db.global.minimap and OneWoW.db.global.minimap.hide
    mmCheckbox:SetChecked(not mmHidden)
    mmCheckbox:SetScript("OnClick", function(self)
        if self:GetChecked() then
            OneWoW.Minimap:Show()
        else
            OneWoW.Minimap:Hide()
        end
    end)

    local mmIconTitle = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mmIconTitle:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -12)
    mmIconTitle:SetText(L["MINIMAP_ICON_SECTION"] or "Icon Theme")
    mmIconTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local mmIconDesc = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmIconDesc:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -38)
    mmIconDesc:SetPoint("TOPRIGHT", mmRightPanel, "TOPRIGHT", -15, -38)
    mmIconDesc:SetText(L["MINIMAP_ICON_DESC"] or "Choose your faction icon.")
    mmIconDesc:SetTextColor(T("TEXT_SECONDARY"))
    mmIconDesc:SetJustifyH("LEFT")
    mmIconDesc:SetWordWrap(true)

    local currentIconTheme = OneWoW.db and OneWoW.db.global and OneWoW.db.global.minimap and OneWoW.db.global.minimap.theme or "horde"
    local iconNames = {
        horde = L["MINIMAP_ICON_HORDE"] or "Horde",
        alliance = L["MINIMAP_ICON_ALLIANCE"] or "Alliance",
        neutral = L["MINIMAP_ICON_NEUTRAL"] or "Neutral",
    }

    local mmCurrentLabel = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmCurrentLabel:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -90)
    mmCurrentLabel:SetText((L["MINIMAP_ICON_CURRENT"] or "Current") .. ": " .. (iconNames[currentIconTheme] or "Horde"))
    mmCurrentLabel:SetTextColor(T("ACCENT_PRIMARY"))

    local iconDropdown = CreateFrame("Button", nil, mmRightPanel, "BackdropTemplate")
    iconDropdown:SetSize(190, 30)
    iconDropdown:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -115)
    iconDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    iconDropdown:SetBackdropColor(T("BG_TERTIARY"))
    iconDropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local iconDropText = iconDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconDropText:SetPoint("LEFT", 10, 0)
    iconDropText:SetText(iconNames[currentIconTheme] or "Horde")
    iconDropText:SetTextColor(T("TEXT_PRIMARY"))

    local iconArrow = iconDropdown:CreateTexture(nil, "OVERLAY")
    iconArrow:SetSize(16, 16)
    iconArrow:SetPoint("RIGHT", iconDropdown, "RIGHT", -5, 0)
    iconArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    local iconMenu = nil
    iconDropdown:SetScript("OnClick", function(self)
        if iconMenu and iconMenu:IsShown() then
            iconMenu:Hide()
            return
        end
        local options = {
            { label = L["MINIMAP_ICON_HORDE"] or "Horde", value = "horde" },
            { label = L["MINIMAP_ICON_ALLIANCE"] or "Alliance", value = "alliance" },
            { label = L["MINIMAP_ICON_NEUTRAL"] or "Neutral", value = "neutral" },
        }
        iconMenu = CreateDropdownMenu(self, options, function(value, label)
            if OneWoW.db and OneWoW.db.global and OneWoW.db.global.minimap then
                OneWoW.db.global.minimap.theme = value
            end
            SyncSettingToChildAddons("icon", value)
            OneWoW.Minimap:UpdateIcon()
            GUI:FullReset()
            C_Timer.After(0.1, function() GUI:Show() end)
        end)
        iconMenu:Show()
    end)

    yOffset = yOffset - 185

    local linksContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    linksContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    linksContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    linksContainer:SetHeight(120)
    linksContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    linksContainer:SetBackdropColor(T("BG_SECONDARY"))
    linksContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local linksTitle = linksContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    linksTitle:SetPoint("TOPLEFT", linksContainer, "TOPLEFT", 15, -12)
    linksTitle:SetText(L["LINKS_SECTION"] or "Support & Community")
    linksTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local discordLinkLabel = linksContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    discordLinkLabel:SetPoint("TOPLEFT", linksContainer, "TOPLEFT", 15, -40)
    discordLinkLabel:SetText(L["DISCORD_LABEL"] or "Discord")
    discordLinkLabel:SetTextColor(T("TEXT_SECONDARY"))

    local discordLinkBox = GUI:CreateEditBox("OneWoW_SettingsDiscord", linksContainer, 300, 24)
    discordLinkBox:SetPoint("LEFT", discordLinkLabel, "RIGHT", S("SM"), 0)
    discordLinkBox:SetText(L["DISCORD_URL"] or "https://discord.gg/6vnabDVnDu")
    discordLinkBox:SetAutoFocus(false)
    discordLinkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    discordLinkBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    local websiteLinkLabel = linksContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    websiteLinkLabel:SetPoint("TOPLEFT", linksContainer, "TOPLEFT", 15, -72)
    websiteLinkLabel:SetText(L["WEBSITE_LABEL"] or "Website")
    websiteLinkLabel:SetTextColor(T("TEXT_SECONDARY"))

    local websiteLinkBox = GUI:CreateEditBox("OneWoW_SettingsWebsite", linksContainer, 300, 24)
    websiteLinkBox:SetPoint("LEFT", websiteLinkLabel, "RIGHT", S("SM"), 0)
    websiteLinkBox:SetText(L["WEBSITE_URL"] or "https://wow2.xyz/")
    websiteLinkBox:SetAutoFocus(false)
    websiteLinkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    websiteLinkBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    content:SetHeight(math.abs(yOffset) + 140)
end

local coreSettingsTabs = {
    { name = "settings", displayName = function() return (OneWoW.L and OneWoW.L["SETTINGS_SUBTAB"] or "Settings") end, create = function(parent) GUI:CreateSettingsMainTab(parent) end },
    { name = "profiles", displayName = function() return "Profiles" end, create = function(parent) GUI:CreateProfilesTab(parent) end },
}

local qolFeatureTabs = {
    { name = "overlays",    displayName = function() return (OneWoW.L and OneWoW.L["OVERLAYS_SUBTAB"]    or "Overlays")     end, create = function(parent) GUI:CreateOverlaysTab(parent)    end },
    { name = "toastalerts", displayName = function() return (OneWoW.L and OneWoW.L["TOAST_ALERTS_SUBTAB"] or "Toast Alerts") end, create = function(parent) GUI:CreateToastAlertsTab(parent) end },
    { name = "tooltips",    displayName = function() return (OneWoW.L and OneWoW.L["TOOLTIPS_SUBTAB"]    or "Tooltips")     end, create = function(parent) GUI:CreateTooltipsTab(parent)    end },
    { name = "portals",     displayName = function() return (OneWoW.L and OneWoW.L["PORTALS_SUBTAB"]     or "Portals")      end, create = function(parent) GUI:CreatePortalsTab(parent)     end },
}

function GUI:GetQoLFeatureTabs()
    return qolFeatureTabs
end

function GUI:BuildSettingsTabs()
    local tabs = {}
    for _, tab in ipairs(coreSettingsTabs) do
        table.insert(tabs, tab)
    end
    if not OneWoW.ModuleRegistry:IsRegistered("qol") then
        for _, tab in ipairs(qolFeatureTabs) do
            table.insert(tabs, tab)
        end
    end
    local addonPanels = OneWoW.ModuleRegistry:GetSettingsPanels()
    for _, panel in ipairs(addonPanels) do
        local capturedCreate = panel.create
        table.insert(tabs, {
            name        = panel.name,
            displayName = panel.displayName,
            create      = capturedCreate,
        })
    end
    GUI.settingsTabs = tabs
end
