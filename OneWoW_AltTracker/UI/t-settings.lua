local addonName, ns = ...
local OneWoWAltTracker = OneWoW_AltTracker
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

function ns.UI.CreateSettingsTab(parent)
    local scrollFrame, scrollContent = ns.UI.CreateScrollFrame(nil, parent, parent:GetWidth(), parent:GetHeight())
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local yOffset = -10

    if not _G.OneWoW then

    local splitContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    splitContainer:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 15, yOffset)
    splitContainer:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -15, yOffset)
    splitContainer:SetHeight(165)
    splitContainer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    splitContainer:SetBackdropColor(T("BG_SECONDARY"))
    splitContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local leftPanel = CreateFrame("Frame", nil, splitContainer)
    leftPanel:SetPoint("TOPLEFT", splitContainer, "TOPLEFT", 0, 0)
    leftPanel:SetPoint("BOTTOMRIGHT", splitContainer, "BOTTOM", 0, 0)

    local langTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    langTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -12)
    langTitle:SetText(L["LANGUAGE_SELECTION"])
    langTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local langDescText = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDescText:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -38)
    langDescText:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -10, -38)
    langDescText:SetJustifyH("LEFT")
    langDescText:SetWordWrap(true)
    langDescText:SetText(L["LANGUAGE_DESC"])
    langDescText:SetTextColor(T("TEXT_SECONDARY"))

    local currentLang = OneWoWAltTracker.db.global.language or "enUS"
    local langNames = {
        ["enUS"] = "English",
        ["koKR"] = "한국어"
    }

    local langCurrentLabel = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langCurrentLabel:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -90)
    langCurrentLabel:SetText(L["LANGUAGE_CURRENT"] .. " " .. (langNames[currentLang] or currentLang))
    langCurrentLabel:SetTextColor(T("ACCENT_PRIMARY"))

    local languageDropdown = CreateFrame("Button", nil, leftPanel, "BackdropTemplate")
    languageDropdown:SetSize(190, 30)
    languageDropdown:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -115)
    languageDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    languageDropdown:SetBackdropColor(T("BG_TERTIARY"))
    languageDropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local langDropdownText = languageDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDropdownText:SetPoint("CENTER")
    langDropdownText:SetText(langNames[currentLang] or currentLang)
    langDropdownText:SetTextColor(T("TEXT_PRIMARY"))

    local langDropdownArrow = languageDropdown:CreateTexture(nil, "OVERLAY")
    langDropdownArrow:SetSize(16, 16)
    langDropdownArrow:SetPoint("RIGHT", languageDropdown, "RIGHT", -5, 0)
    langDropdownArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    languageDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(T("BG_HOVER")) self:SetBackdropBorderColor(T("BORDER_FOCUS")) end)
    languageDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(T("BG_TERTIARY")) self:SetBackdropBorderColor(T("BORDER_SUBTLE")) end)

    languageDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(190, 64)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:EnableMouse(true)

        local function createLangButton(parent, langName, langCode, yPos)
            local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
            btn:SetSize(180, 25)
            btn:SetPoint("TOP", parent, "TOP", 0, yPos)
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("CENTER")
            text:SetText(langName)
            text:SetTextColor(0.9, 0.9, 0.9)
            btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) text:SetTextColor(1, 0.82, 0) end)
            btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) text:SetTextColor(0.9, 0.9, 0.9) end)
            btn:SetScript("OnClick", function()
                OneWoWAltTracker.db.global.language = langCode
                OneWoWAltTracker.db.global.lastTab = "settings"
                if ns.ApplyLanguage then ns.ApplyLanguage() end
                menu:Hide()
                ns.UI:Reset()
                C_Timer.After(0.1, function()
                    local tabToShow = OneWoWAltTracker.db.global.lastTab or "summary"
                    ns.UI:Show(tabToShow)
                end)
            end)
            return btn
        end

        createLangButton(menu, langNames["enUS"], "enUS", -5)
        createLangButton(menu, langNames["koKR"], "koKR", -32)

        menu:SetScript("OnShow", function(self)
            local timeOutside = 0
            self:SetScript("OnUpdate", function(self, elapsed)
                if not MouseIsOver(menu) and not MouseIsOver(languageDropdown) then
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

    local currentTheme = OneWoWAltTracker.db.global.theme or "green"
    local themeNames = {
        ["green"] = L["THEME_FOREST_GREEN"],
        ["blue"] = L["THEME_OCEAN_BLUE"],
        ["purple"] = L["THEME_ROYAL_PURPLE"],
        ["red"] = L["THEME_CRIMSON_RED"],
        ["orange"] = L["THEME_SUNSET_ORANGE"],
        ["teal"] = L["THEME_DEEP_TEAL"],
        ["gold"] = L["THEME_GOLDEN_AMBER"],
        ["pink"] = L["THEME_ROSE_PINK"],
        ["slate"] = L["THEME_SLATE_GRAY"],
        ["dark"] = L["THEME_MIDNIGHT_BLACK"],
        ["amber"] = L["THEME_AMBER_FIRE"],
        ["cyan"] = L["THEME_ARCTIC_CYAN"],
        ["voidblack"] = L["THEME_VOID_BLACK"],
        ["charcoal"] = L["THEME_CHARCOAL_DEEP"],
        ["forestnight"] = L["THEME_FOREST_NIGHT"],
        ["obsidian"] = L["THEME_OBSIDIAN_MINIMAL"],
        ["monochrome"] = L["THEME_MONOCHROME_PRO"],
        ["twilight"] = L["THEME_TWILIGHT_COMPACT"],
        ["neon"] = L["THEME_NEON_SYNTHWAVE"],
        ["glassmorphic"] = L["THEME_GLASSMORPHIC"],
        ["lightmode"] = L["THEME_MINIMAL_WHITE"],
        ["retro"] = L["THEME_RETRO_CLASSIC"],
        ["fantasy"] = L["THEME_RPG_FANTASY"],
        ["nightfae"] = L["THEME_COVENANT_TWILIGHT"],
    }

    local themeTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    themeTitle:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -12)
    themeTitle:SetText(L["THEME_SELECTION"])
    themeTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local themeDescText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDescText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -38)
    themeDescText:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -10, -38)
    themeDescText:SetJustifyH("LEFT")
    themeDescText:SetWordWrap(true)
    themeDescText:SetText(L["THEME_DESC"])
    themeDescText:SetTextColor(T("TEXT_SECONDARY"))

    local currentThemeLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentThemeLabel:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -90)
    currentThemeLabel:SetText(L["THEME_CURRENT"] .. " " .. (themeNames[currentTheme] or currentTheme))
    currentThemeLabel:SetTextColor(T("ACCENT_PRIMARY"))

    local themeDropdown = CreateFrame("Button", nil, rightPanel, "BackdropTemplate")
    themeDropdown:SetSize(210, 30)
    themeDropdown:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -115)
    themeDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    themeDropdown:SetBackdropColor(T("BG_TERTIARY"))
    themeDropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local dropdownText = themeDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dropdownText:SetPoint("LEFT", themeDropdown, "LEFT", 30, 0)
    dropdownText:SetText(themeNames[currentTheme] or currentTheme)
    dropdownText:SetTextColor(T("TEXT_PRIMARY"))

    local currentColorPreview = themeDropdown:CreateTexture(nil, "OVERLAY")
    currentColorPreview:SetSize(14, 14)
    currentColorPreview:SetPoint("LEFT", themeDropdown, "LEFT", 8, 0)
    local currentThemeData = ns.Constants.THEMES[currentTheme]
    if currentThemeData then
        currentColorPreview:SetColorTexture(unpack(currentThemeData.ACCENT_PRIMARY))
    end

    local dropdownArrow = themeDropdown:CreateTexture(nil, "OVERLAY")
    dropdownArrow:SetSize(16, 16)
    dropdownArrow:SetPoint("RIGHT", themeDropdown, "RIGHT", -5, 0)
    dropdownArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    themeDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(T("BG_HOVER")) self:SetBackdropBorderColor(T("BORDER_FOCUS")) end)
    themeDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(T("BG_TERTIARY")) self:SetBackdropBorderColor(T("BORDER_SUBTLE")) end)

    themeDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(240, 318)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:EnableMouse(true)

        local scrollFrame = CreateFrame("ScrollFrame", nil, menu, "BackdropTemplate")
        scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
        scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -15, 2)
        scrollFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
        scrollFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.5)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(scrollFrame:GetWidth())
        scrollFrame:SetScrollChild(scrollChild)

        local scrollBar = scrollFrame.ScrollBar or CreateFrame("Slider", nil, scrollFrame, "BackdropTemplate")
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, -2)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 2)
        scrollBar:SetWidth(12)
        scrollBar:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
        scrollBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        scrollBar:EnableMouse(true)
        scrollBar:SetScript("OnValueChanged", function(self, value)
            scrollFrame:SetVerticalScroll(value)
        end)

        local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(8, 40)
        thumb:SetPoint("TOP", scrollBar, "TOP", 0, -2)
        thumb:SetColorTexture(0.5, 0.5, 0.5)
        scrollBar.thumb = thumb
        scrollBar:SetThumbTexture(thumb)

        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(self, direction)
            local currentScroll = scrollFrame:GetVerticalScroll()
            local maxScroll = scrollChild:GetHeight() - scrollFrame:GetHeight()
            local newScroll = math.max(0, math.min(maxScroll, currentScroll - (direction * 30)))
            scrollFrame:SetVerticalScroll(newScroll)
            scrollBar:SetValue(newScroll)
        end)

        local themeOrder = {"green", "blue", "purple", "red", "orange", "teal", "gold", "pink", "slate", "dark", "amber", "cyan", "voidblack", "charcoal", "forestnight", "obsidian", "monochrome", "twilight", "neon", "glassmorphic", "lightmode", "retro", "fantasy", "nightfae"}

        local function createThemeButton(parent, themeName, themeKey, yPos)
            local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
            btn:SetSize(230, 26)
            btn:SetPoint("TOP", parent, "TOP", 0, yPos)
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

            local themeData = ns.Constants.THEMES[themeKey]
            if themeData then
                local colorPreview = btn:CreateTexture(nil, "OVERLAY")
                colorPreview:SetSize(14, 14)
                colorPreview:SetPoint("LEFT", btn, "LEFT", 8, 0)
                colorPreview:SetColorTexture(unpack(themeData.ACCENT_PRIMARY))
            end

            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", btn, "LEFT", 28, 0)
            text:SetText(themeName)
            text:SetTextColor(0.9, 0.9, 0.9)

            btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) text:SetTextColor(1, 0.82, 0) end)
            btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) text:SetTextColor(0.9, 0.9, 0.9) end)

            btn:SetScript("OnClick", function()
                OneWoWAltTracker.db.global.theme = themeKey
                OneWoWAltTracker.db.global.lastTab = "settings"
                if ns.Constants.THEMES and ns.Constants.THEMES[themeKey] then
                    local selectedTheme = ns.Constants.THEMES[themeKey]
                    for key, value in pairs(selectedTheme) do
                        if key ~= "name" then ns.Constants.THEME[key] = value end
                    end
                end
                dropdownText:SetText(themeNames[themeKey] or themeKey)
                currentColorPreview:SetColorTexture(unpack(ns.Constants.THEMES[themeKey].ACCENT_PRIMARY))
                menu:Hide()
                ns.UI:Reset()
                C_Timer.After(0.1, function()
                    local tabToShow = OneWoWAltTracker.db.global.lastTab or "summary"
                    ns.UI:Show(tabToShow)
                end)
            end)

            return btn
        end

        local yPos = -5
        for _, themeKey in ipairs(themeOrder) do
            createThemeButton(scrollChild, themeNames[themeKey], themeKey, yPos)
            yPos = yPos - 28
        end
        scrollChild:SetHeight(math.abs(yPos) + 5)
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

    local minimapSplit = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    minimapSplit:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 15, yOffset)
    minimapSplit:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -15, yOffset)
    minimapSplit:SetHeight(140)
    minimapSplit:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    minimapSplit:SetBackdropColor(T("BG_SECONDARY"))
    minimapSplit:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local mmLeftPanel = CreateFrame("Frame", nil, minimapSplit)
    mmLeftPanel:SetPoint("TOPLEFT", minimapSplit, "TOPLEFT", 0, 0)
    mmLeftPanel:SetPoint("BOTTOMRIGHT", minimapSplit, "BOTTOM", 0, 0)

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

    local mmCheckbox = CreateFrame("CheckButton", nil, mmLeftPanel, "UICheckButtonTemplate")
    mmCheckbox:SetSize(26, 26)
    mmCheckbox:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -70)

    local isMinimapEnabled = not (OneWoWAltTracker.db.global.minimap and OneWoWAltTracker.db.global.minimap.hide)
    mmCheckbox:SetChecked(isMinimapEnabled)

    local mmCheckLabel = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmCheckLabel:SetPoint("LEFT", mmCheckbox, "RIGHT", 4, 0)
    mmCheckLabel:SetText(L["MINIMAP_SHOW_BTN"])
    mmCheckLabel:SetTextColor(T("TEXT_PRIMARY"))

    mmCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if checked then
            OneWoWAltTracker.db.global.minimap.hide = false
            if ns.MinimapButton then ns.MinimapButton:Show() end
        else
            OneWoWAltTracker.db.global.minimap.hide = true
            if ns.MinimapButton then ns.MinimapButton:Hide() end
        end
    end)

    local mmVertDiv = minimapSplit:CreateTexture(nil, "ARTWORK")
    mmVertDiv:SetWidth(1)
    mmVertDiv:SetPoint("TOP", minimapSplit, "TOP", 0, -8)
    mmVertDiv:SetPoint("BOTTOM", minimapSplit, "BOTTOM", 0, 8)
    mmVertDiv:SetColorTexture(T("BORDER_SUBTLE"))

    local mmRightPanel = CreateFrame("Frame", nil, minimapSplit)
    mmRightPanel:SetPoint("TOPLEFT", minimapSplit, "TOP", 0, 0)
    mmRightPanel:SetPoint("BOTTOMRIGHT", minimapSplit, "BOTTOMRIGHT", 0, 0)

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

    local currentIconTheme = OneWoWAltTracker.db.global.minimap and OneWoWAltTracker.db.global.minimap.theme or "horde"
    local iconThemeNames = {
        ["horde"]    = L["MINIMAP_ICON_HORDE"],
        ["alliance"] = L["MINIMAP_ICON_ALLIANCE"],
        ["neutral"]  = L["MINIMAP_ICON_NEUTRAL"],
    }
    local iconThemePaths = {
        ["horde"]    = "Interface\\AddOns\\OneWoW_AltTracker\\Media\\horde-mini.png",
        ["alliance"] = "Interface\\AddOns\\OneWoW_AltTracker\\Media\\alliance-mini.png",
        ["neutral"]  = "Interface\\AddOns\\OneWoW_AltTracker\\Media\\neutral-mini.png",
    }

    local mmIconDropdown = CreateFrame("Button", nil, mmRightPanel, "BackdropTemplate")
    mmIconDropdown:SetSize(190, 30)
    mmIconDropdown:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -70)
    mmIconDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    mmIconDropdown:SetBackdropColor(T("BG_TERTIARY"))
    mmIconDropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local mmIconPreview = mmIconDropdown:CreateTexture(nil, "OVERLAY")
    mmIconPreview:SetSize(18, 18)
    mmIconPreview:SetPoint("LEFT", mmIconDropdown, "LEFT", 8, 0)
    mmIconPreview:SetTexture(iconThemePaths[currentIconTheme] or iconThemePaths["horde"])

    local mmIconText = mmIconDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmIconText:SetPoint("LEFT", mmIconPreview, "RIGHT", 6, 0)
    mmIconText:SetText(iconThemeNames[currentIconTheme] or currentIconTheme)
    mmIconText:SetTextColor(T("TEXT_PRIMARY"))

    local mmIconArrow = mmIconDropdown:CreateTexture(nil, "OVERLAY")
    mmIconArrow:SetSize(16, 16)
    mmIconArrow:SetPoint("RIGHT", mmIconDropdown, "RIGHT", -5, 0)
    mmIconArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    mmIconDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(T("BG_HOVER")) self:SetBackdropBorderColor(T("BORDER_FOCUS")) end)
    mmIconDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(T("BG_TERTIARY")) self:SetBackdropBorderColor(T("BORDER_SUBTLE")) end)

    mmIconDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(190, 88)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:EnableMouse(true)

        local iconOrder = {"horde", "alliance", "neutral"}
        local function createIconBtn(parent, themeKey, yPos)
            local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
            btn:SetSize(180, 25)
            btn:SetPoint("TOP", parent, "TOP", 0, yPos)
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            local ico = btn:CreateTexture(nil, "OVERLAY")
            ico:SetSize(18, 18)
            ico:SetPoint("LEFT", btn, "LEFT", 8, 0)
            ico:SetTexture(iconThemePaths[themeKey])
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", ico, "RIGHT", 6, 0)
            text:SetText(iconThemeNames[themeKey])
            text:SetTextColor(0.9, 0.9, 0.9)
            btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) text:SetTextColor(1, 0.82, 0) end)
            btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) text:SetTextColor(0.9, 0.9, 0.9) end)
            btn:SetScript("OnClick", function()
                OneWoWAltTracker.db.global.minimap.theme = themeKey
                OneWoWAltTracker.db.global.lastTab = "settings"
                if ns.MinimapButton then ns.MinimapButton:UpdateIcon() end
                menu:Hide()
                ns.UI:Reset()
                C_Timer.After(0.1, function()
                    ns.UI:Show("settings")
                end)
            end)
            return btn
        end

        local yPos = -5
        for _, themeKey in ipairs(iconOrder) do
            createIconBtn(menu, themeKey, yPos)
            yPos = yPos - 27
        end

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

    yOffset = yOffset - 155

    end -- if not _G.OneWoW

    local importSection = ns.UI.CreateSectionHeader(scrollContent, L["IMPORT_FROM_WOWNOTES"] or "Import Data", yOffset)
    yOffset = importSection.bottomY - 8

    local importDesc = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importDesc:SetPoint("TOPLEFT", 15, yOffset)
    importDesc:SetPoint("TOPRIGHT", -15, yOffset)
    importDesc:SetJustifyH("LEFT")
    importDesc:SetWordWrap(true)
    importDesc:SetText("Import character data from WoWNotes. Imports character info, professions, endgame progression, and action bars. Bag and bank item data is not imported - log in on each character to collect that data.")
    importDesc:SetTextColor(T("TEXT_SECONDARY"))
    importDesc:SetSpacing(3)

    C_Timer.After(0.01, function()
        local textHeight = importDesc:GetStringHeight()
        yOffset = yOffset - textHeight - 12
    end)
    yOffset = yOffset - 20

    local importBtn = CreateFrame("Button", nil, scrollContent, "BackdropTemplate")
    importBtn:SetSize(280, 35)
    importBtn:SetPoint("TOPLEFT", 25, yOffset)
    importBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    importBtn:SetBackdropColor(T("BG_SECONDARY"))
    importBtn:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local importBtnText = importBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importBtnText:SetPoint("CENTER")
    importBtnText:SetText("Import from WoWNotes")
    importBtnText:SetTextColor(T("TEXT_PRIMARY"))

    importBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        importBtnText:SetTextColor(T("TEXT_ACCENT"))
    end)

    importBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_SECONDARY"))
        importBtnText:SetTextColor(T("TEXT_PRIMARY"))
    end)

    importBtn:SetScript("OnClick", function()
        if not (_G.WoWNotes and _G.WoWNotes.db and _G.WoWNotes.db.global and _G.WoWNotes.db.global.altTracker) then
            print("|cFFFFD100OneWoW - AltTracker:|r No WoWNotes data found to import.")
            return
        end
        local wownotes = _G.WoWNotes.db.global
        if not wownotes.altTracker or not wownotes.altTracker.characters then
            print("|cFFFFD100OneWoW - AltTracker:|r No WoWNotes character data found.")
            return
        end
        local charCount = 0
        for _ in pairs(wownotes.altTracker.characters) do
            charCount = charCount + 1
        end
        if charCount == 0 then
            print("|cFFFFD100OneWoW - AltTracker:|r No characters found to import.")
            return
        end
        ns.Core:ShowMigrationDialog(charCount)
    end)

    yOffset = yOffset - 45

    local dbSection = ns.UI.CreateSectionHeader(scrollContent, "Database Manager", yOffset)
    yOffset = dbSection.bottomY - 8

    local dbDesc = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dbDesc:SetPoint("TOPLEFT", 15, yOffset)
    dbDesc:SetPoint("TOPRIGHT", -15, yOffset)
    dbDesc:SetJustifyH("LEFT")
    dbDesc:SetWordWrap(true)
    dbDesc:SetText("Manage addon databases. Click Reset to completely clear a database and force a UI reload.")
    dbDesc:SetTextColor(T("TEXT_SECONDARY"))
    dbDesc:SetSpacing(3)

    C_Timer.After(0.01, function()
        local textHeight = dbDesc:GetStringHeight()
        yOffset = yOffset - textHeight - 12
    end)
    yOffset = yOffset - 25

    local databases = {
        { key = "OneWoW_AltTracker", name = "AltTracker Core", desc = "Main addon settings and UI state" },
        { key = "OneWoW_AltTracker_Character", name = "Character Data", desc = "Character info, stats, equipment, and progression" },
        { key = "OneWoW_AltTracker_Storage", name = "Storage & Mail", desc = "Bags, banks, guild banks, and mail data" },
        { key = "OneWoW_AltTracker_Professions", name = "Professions", desc = "Profession data for all characters" },
        { key = "OneWoW_AltTracker_Endgame", name = "Endgame Content", desc = "Mythic+, raids, currencies, and gear" },
        { key = "OneWoW_AltTracker_Accounting", name = "Accounting", desc = "Gold tracking and transactions" },
        { key = "OneWoW_AltTracker_Auctions", name = "Auctions", desc = "Auction house history" },
        { key = "OneWoW_AltTracker_Collections", name = "Collections", desc = "Mounts, pets, and transmog" },
    }

    local function GetTableSize(dbKey)
        if not _G[dbKey .. "_DB"] then return 0 end
        local db = _G[dbKey .. "_DB"]

        if db.characters then
            local size = 0
            for _ in pairs(db.characters) do size = size + 1 end
            return size
        else
            local size = 0
            for _ in pairs(db) do size = size + 1 end
            return math.max(0, size - 5)
        end
    end

    local function CreateDatabaseEntry(parent, dbData, yPos)
        local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yPos)
        container:SetSize(770, 60)
        container:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        container:SetBackdropColor(T("BG_TERTIARY"))
        container:SetBackdropBorderColor(T("BORDER_DEFAULT"))

        local nameText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("TOPLEFT", 12, -10)
        nameText:SetText(dbData.name)
        nameText:SetTextColor(T("TEXT_PRIMARY"))

        local descText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descText:SetPoint("TOPLEFT", 12, -28)
        descText:SetText(dbData.desc)
        descText:SetTextColor(T("TEXT_SECONDARY"))
        descText:SetWidth(400)

        local sizeText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sizeText:SetPoint("TOPLEFT", 450, -18)

        local function UpdateSize()
            local db = _G[dbData.key .. "_DB"]
            if db then
                local size = GetTableSize(dbData.key)
                sizeText:SetText("Entries: " .. size)
                sizeText:SetTextColor(T("TEXT_SECONDARY"))
            else
                sizeText:SetText("Not Loaded")
                sizeText:SetTextColor(1, 0.5, 0.5)
            end
        end
        UpdateSize()

        local resetBtn = CreateFrame("Button", nil, container, "BackdropTemplate")
        resetBtn:SetSize(75, 28)
        resetBtn:SetPoint("TOPRIGHT", -12, -16)
        resetBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        resetBtn:SetBackdropColor(1, 0.3, 0.3)
        resetBtn:SetBackdropBorderColor(T("BORDER_DEFAULT"))

        local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        resetText:SetPoint("CENTER")
        resetText:SetText("Reset")
        resetText:SetTextColor(1, 1, 1)

        resetBtn:EnableMouse(true)
        resetBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(1, 0.1, 0.1)
            resetText:SetTextColor(1, 1, 1)
        end)

        resetBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(1, 0.3, 0.3)
            resetText:SetTextColor(1, 1, 1)
        end)

        resetBtn:SetScript("OnClick", function()
            StaticPopupDialogs["WNAT_RESET_DB_CONFIRM"] = {
                text = "Are you sure you want to reset " .. dbData.name .. "?\n\nThis will permanently delete all data in this database.",
                button1 = "Reset",
                button2 = "Cancel",
                OnAccept = function()
                    _G[dbData.key .. "_DB"] = nil
                    C_UI.Reload()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("WNAT_RESET_DB_CONFIRM")
        end)

        return 65
    end

    for _, dbData in ipairs(databases) do
        local height = CreateDatabaseEntry(scrollContent, dbData, yOffset)
        yOffset = yOffset - height - 8
    end

    yOffset = yOffset - 10

    local overrideSection = ns.UI.CreateSectionHeader(scrollContent, L["OVERRIDE_BTN"], yOffset)
    yOffset = overrideSection.bottomY - 8

    local overrideDesc = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    overrideDesc:SetPoint("TOPLEFT", 15, yOffset)
    overrideDesc:SetPoint("TOPRIGHT", -15, yOffset)
    overrideDesc:SetJustifyH("LEFT")
    overrideDesc:SetWordWrap(true)
    overrideDesc:SetText(L["OVERRIDE_SYSTEM_DESC"])
    overrideDesc:SetTextColor(T("TEXT_SECONDARY"))
    overrideDesc:SetSpacing(3)

    C_Timer.After(0.01, function()
        local textHeight = overrideDesc:GetStringHeight()
        yOffset = yOffset - textHeight - 12
    end)
    yOffset = yOffset - 50

    local overrideBtn = CreateFrame("Button", nil, scrollContent, "BackdropTemplate")
    overrideBtn:SetSize(280, 35)
    overrideBtn:SetPoint("TOPLEFT", 25, yOffset)
    overrideBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    overrideBtn:SetBackdropColor(T("BG_SECONDARY"))
    overrideBtn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))

    local overrideBtnText = overrideBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    overrideBtnText:SetPoint("CENTER")
    overrideBtnText:SetText(L["OVERRIDE_BTN"])
    overrideBtnText:SetTextColor(T("ACCENT_PRIMARY"))

    overrideBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        overrideBtnText:SetTextColor(T("TEXT_ACCENT"))
    end)

    overrideBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_SECONDARY"))
        overrideBtnText:SetTextColor(T("ACCENT_PRIMARY"))
    end)

    local overrideDialog = nil

    local KNOWN_BOSS_NAMES = {}

    local function GetCurrencyIDs()
        if OneWoWAltTracker.db.global.overrides and
           OneWoWAltTracker.db.global.overrides.progress and
           OneWoWAltTracker.db.global.overrides.progress.trackedCurrencyIDs then
            return OneWoWAltTracker.db.global.overrides.progress.trackedCurrencyIDs
        end
        return {}
    end

    local function GetBossQuestIDs()
        if OneWoWAltTracker.db.global.overrides and
           OneWoWAltTracker.db.global.overrides.progress and
           OneWoWAltTracker.db.global.overrides.progress.worldBossQuestIDs then
            return OneWoWAltTracker.db.global.overrides.progress.worldBossQuestIDs
        end
        return {}
    end

    local function GetOrCreateOverrideDialog()
        if overrideDialog and overrideDialog:IsShown() then
            overrideDialog:Raise()
            return
        end

        if overrideDialog then
            overrideDialog:Show()
            overrideDialog:Raise()
            return
        end

        overrideDialog = CreateFrame("Frame", "OneWoWOverrideDialog", UIParent, "BackdropTemplate")
        overrideDialog:SetSize(600, 660)
        overrideDialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        overrideDialog:SetFrameStrata("DIALOG")
        overrideDialog:SetMovable(true)
        overrideDialog:SetClampedToScreen(true)
        overrideDialog:EnableMouse(true)
        overrideDialog:RegisterForDrag("LeftButton")
        overrideDialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
        overrideDialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        overrideDialog:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        overrideDialog:SetBackdropColor(T("BG_PRIMARY"))
        overrideDialog:SetBackdropBorderColor(T("BORDER_DEFAULT"))
        tinsert(UISpecialFrames, "OneWoWOverrideDialog")

        local titleBar = CreateFrame("Frame", nil, overrideDialog, "BackdropTemplate")
        titleBar:SetPoint("TOPLEFT", overrideDialog, "TOPLEFT", 1, -1)
        titleBar:SetPoint("TOPRIGHT", overrideDialog, "TOPRIGHT", -1, -1)
        titleBar:SetHeight(26)
        titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        titleBar:SetBackdropColor(T("BG_SECONDARY"))

        local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
        titleText:SetText(L["OVERRIDE_SYSTEM_TITLE"])
        titleText:SetTextColor(T("ACCENT_PRIMARY"))

        local closeX = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
        closeX:SetSize(22, 22)
        closeX:SetPoint("RIGHT", titleBar, "RIGHT", -3, 0)
        closeX:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        closeX:SetBackdropColor(T("BG_TERTIARY"))
        local closeXText = closeX:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        closeXText:SetPoint("CENTER")
        closeXText:SetText("X")
        closeXText:SetTextColor(T("TEXT_PRIMARY"))
        closeX:SetScript("OnEnter", function(self) self:SetBackdropColor(T("BG_HOVER")); closeXText:SetTextColor(T("TEXT_ACCENT")) end)
        closeX:SetScript("OnLeave", function(self) self:SetBackdropColor(T("BG_TERTIARY")); closeXText:SetTextColor(T("TEXT_PRIMARY")) end)
        closeX:SetScript("OnClick", function() overrideDialog:Hide() end)

        local scrollFrame, sc = ns.UI.CreateScrollFrame(nil, overrideDialog, 580, 580)
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", overrideDialog, "TOPLEFT", 1, -28)
        scrollFrame:SetPoint("BOTTOMRIGHT", overrideDialog, "BOTTOMRIGHT", -1, 46)

        local dy = -8

        local descText = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        descText:SetPoint("TOPLEFT", 10, dy)
        descText:SetPoint("TOPRIGHT", -10, dy)
        descText:SetJustifyH("LEFT")
        descText:SetWordWrap(true)
        descText:SetText(L["OVERRIDE_SYSTEM_DESC"])
        descText:SetTextColor(T("TEXT_SECONDARY"))
        descText:SetSpacing(3)
        dy = dy - 55

        local function MakeListRow(parent, col1, col2, yPos, r, g, b)
            local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            row:SetPoint("TOPLEFT", 8, yPos)
            row:SetPoint("TOPRIGHT", -8, yPos)
            row:SetHeight(28)
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            row:SetBackdropColor(T("BG_TERTIARY"))
            row:SetBackdropBorderColor(T("BORDER_SUBTLE"))

            local t1 = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            t1:SetPoint("LEFT", row, "LEFT", 8, 0)
            t1:SetWidth(80)
            t1:SetText(col1)
            t1:SetTextColor(T("TEXT_SECONDARY"))

            local t2 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            t2:SetPoint("LEFT", row, "LEFT", 92, 0)
            t2:SetPoint("RIGHT", row, "RIGHT", -90, 0)
            t2:SetJustifyH("LEFT")
            t2:SetText(col2)
            t2:SetTextColor(r or T("TEXT_PRIMARY"))
            row.nameText = t2

            return row
        end

        local function MakeRemoveBtn(parent, row, onClick)
            local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
            btn:SetSize(60, 20)
            btn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            btn:SetBackdropColor(0.5, 0.15, 0.15)
            btn:SetBackdropBorderColor(T("BORDER_DEFAULT"))
            local bt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            bt:SetPoint("CENTER")
            bt:SetText(L["OVERRIDE_REMOVE"] .. " Remove")
            bt:SetTextColor(1, 0.7, 0.7)
            btn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.7, 0.1, 0.1) end)
            btn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.5, 0.15, 0.15) end)
            btn:SetScript("OnClick", onClick)
            return btn
        end

        local currencyListFrames = {}
        local bossListFrames = {}

        local function RebuildCurrencyList()
            for _, f in ipairs(currencyListFrames) do f:Hide(); f:SetParent(nil) end
            wipe(currencyListFrames)

            local ids = GetCurrencyIDs()
            local startDY = sc.currencyListStartDY or dy
            local ldY = startDY
            for i, id in ipairs(ids) do
                local info = C_CurrencyInfo.GetCurrencyInfo(id)
                local nm = (info and info.name) or ("Currency ID: " .. id)
                local row = MakeListRow(sc, "ID: " .. id, nm, ldY)
                MakeRemoveBtn(sc, row, function()
                    table.remove(ids, i)
                    RebuildCurrencyList()
                end)
                ldY = ldY - 32
                table.insert(currencyListFrames, row)
            end
            if sc.currencyAddRow then
                sc.currencyAddRow:ClearAllPoints()
                sc.currencyAddRow:SetPoint("TOPLEFT", 8, ldY)
                sc.currencyAddRow:SetPoint("TOPRIGHT", -8, ldY)
                ldY = ldY - 36
            end
            sc.currencyListEndDY = ldY
            if sc.bossListStartDY then
                local bossStartDY = ldY - 8
                sc.bossListStartDY = bossStartDY
                RebuildBossList()
            end
        end

        local function RebuildBossList()
            for _, f in ipairs(bossListFrames) do f:Hide(); f:SetParent(nil) end
            wipe(bossListFrames)

            local ids = GetBossQuestIDs()
            local startDY = sc.bossListStartDY or (sc.currencyListEndDY or dy) - 80
            local ldY = startDY
            for i, id in ipairs(ids) do
                local nm = KNOWN_BOSS_NAMES[id] or C_QuestLog.GetTitleForQuestID(id) or ("Quest ID: " .. id)
                local done = C_QuestLog.IsQuestFlaggedCompleted(id)
                local r, g, b = done and 0.2 or 0.8, done and 0.9 or 0.8, done and 0.2 or 0.8
                local row = MakeListRow(sc, "Quest: " .. id, nm, ldY, r, g, b)
                if done then
                    local doneTag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    doneTag:SetPoint("RIGHT", row, "RIGHT", -70, 0)
                    doneTag:SetText("Done")
                    doneTag:SetTextColor(0.2, 0.9, 0.2)
                end
                MakeRemoveBtn(sc, row, function()
                    table.remove(ids, i)
                    RebuildBossList()
                end)
                ldY = ldY - 32
                table.insert(bossListFrames, row)
            end
            if sc.bossAddRow then
                sc.bossAddRow:ClearAllPoints()
                sc.bossAddRow:SetPoint("TOPLEFT", 8, ldY)
                sc.bossAddRow:SetPoint("TOPRIGHT", -8, ldY)
                ldY = ldY - 36
            end
            local noteText = sc.noteText
            if noteText then
                noteText:ClearAllPoints()
                noteText:SetPoint("TOPLEFT", 12, ldY - 4)
                ldY = ldY - 26
            end
            sc:SetHeight(math.abs(ldY) + 20)
        end

        local sec1 = ns.UI.CreateSectionHeader(sc, L["OVERRIDE_SECTION_SUMMARY"], dy)
        dy = sec1.bottomY - 6
        local noneText = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noneText:SetPoint("TOPLEFT", 15, dy)
        noneText:SetText(L["OVERRIDE_NO_SETTINGS"])
        noneText:SetTextColor(T("TEXT_MUTED"))
        dy = dy - 26

        local sec2 = ns.UI.CreateSectionHeader(sc, L["OVERRIDE_TRACKED_CURRENCIES"], dy)
        dy = sec2.bottomY - 6
        sc.currencyListStartDY = dy

        local addCurrRow = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        addCurrRow:SetHeight(28)
        addCurrRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        addCurrRow:SetBackdropColor(T("BG_SECONDARY"))
        addCurrRow:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        local addCurrLabel = addCurrRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        addCurrLabel:SetPoint("LEFT", 8, 0)
        addCurrLabel:SetText("Add Currency ID:")
        addCurrLabel:SetTextColor(T("TEXT_SECONDARY"))
        local addCurrBox = ns.UI.CreateEditBox(nil, addCurrRow, 90, 22)
        addCurrBox:SetPoint("LEFT", addCurrLabel, "RIGHT", 8, 0)
        addCurrBox:SetNumeric(true)
        addCurrBox:SetMaxLetters(8)
        local addCurrBtn = ns.UI.CreateButton(nil, addCurrRow, "Add", 50, 22)
        addCurrBtn:SetPoint("LEFT", addCurrBox, "RIGHT", 6, 0)
        addCurrBtn:SetScript("OnClick", function()
            local val = tonumber(addCurrBox:GetText()) or 0
            if val > 0 then
                local ids = GetCurrencyIDs()
                local exists = false
                for _, v in ipairs(ids) do if v == val then exists = true; break end end
                if not exists then
                    table.insert(ids, val)
                    addCurrBox:SetText("")
                    RebuildCurrencyList()
                end
            end
        end)
        addCurrBox:SetScript("OnEnterPressed", function(self) addCurrBtn:Click() end)
        sc.currencyAddRow = addCurrRow

        local sec3StartDY = dy
        RebuildCurrencyList()

        local sec3DY = (sc.currencyListEndDY or dy) - 12
        local sec3 = ns.UI.CreateSectionHeader(sc, L["OVERRIDE_WORLD_BOSS_QUEST"], sec3DY)
        sc.bossListStartDY = sec3.bottomY - 6
        sc.bossSecHeader = sec3

        local addBossRow = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        addBossRow:SetHeight(28)
        addBossRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        addBossRow:SetBackdropColor(T("BG_SECONDARY"))
        addBossRow:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        local addBossLabel = addBossRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        addBossLabel:SetPoint("LEFT", 8, 0)
        addBossLabel:SetText("Add Quest ID:")
        addBossLabel:SetTextColor(T("TEXT_SECONDARY"))
        local addBossBox = ns.UI.CreateEditBox(nil, addBossRow, 90, 22)
        addBossBox:SetPoint("LEFT", addBossLabel, "RIGHT", 8, 0)
        addBossBox:SetNumeric(true)
        addBossBox:SetMaxLetters(8)
        local addBossBtn = ns.UI.CreateButton(nil, addBossRow, "Add", 50, 22)
        addBossBtn:SetPoint("LEFT", addBossBox, "RIGHT", 6, 0)
        addBossBtn:SetScript("OnClick", function()
            local val = tonumber(addBossBox:GetText()) or 0
            if val > 0 then
                local ids = GetBossQuestIDs()
                local exists = false
                for _, v in ipairs(ids) do if v == val then exists = true; break end end
                if not exists then
                    table.insert(ids, val)
                    addBossBox:SetText("")
                    RebuildBossList()
                end
            end
        end)
        addBossBox:SetScript("OnEnterPressed", function(self) addBossBtn:Click() end)
        sc.bossAddRow = addBossRow

        local noteText = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noteText:SetWidth(540)
        noteText:SetJustifyH("LEFT")
        noteText:SetWordWrap(true)
        noteText:SetText(L["OVERRIDE_CURRENCY_LOGIN_NOTE"])
        noteText:SetTextColor(T("TEXT_MUTED"))
        sc.noteText = noteText

        RebuildBossList()

        local resetBtn = ns.UI.CreateButton(nil, overrideDialog, L["OVERRIDE_RESET_DEFAULTS"], 160, 30)
        resetBtn:ClearAllPoints()
        resetBtn:SetPoint("BOTTOMLEFT", overrideDialog, "BOTTOMLEFT", 10, 10)
        resetBtn:SetScript("OnClick", function()
            OneWoWAltTracker.db.global.overrides.progress.trackedCurrencyIDs = {3383, 3341, 3343, 3345, 3347, 3303, 3309, 3378, 3379, 3385, 3316}
            OneWoWAltTracker.db.global.overrides.progress.worldBossQuestIDs = {}
            RebuildCurrencyList()
            RebuildBossList()
        end)

        local closeBtn2 = ns.UI.CreateButton(nil, overrideDialog, L["OVERRIDE_CLOSE"], 100, 30)
        closeBtn2:ClearAllPoints()
        closeBtn2:SetPoint("BOTTOMRIGHT", overrideDialog, "BOTTOMRIGHT", -10, 10)
        closeBtn2:SetScript("OnClick", function() overrideDialog:Hide() end)

        overrideDialog:Show()
        overrideDialog:Raise()
    end

    overrideBtn:SetScript("OnClick", GetOrCreateOverrideDialog)

    yOffset = yOffset - 50

    local checklistSection = ns.UI.CreateSectionHeader(scrollContent, L["SEASON_CHECKLIST_BTN"], yOffset)
    yOffset = checklistSection.bottomY - 8

    local checklistDescText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    checklistDescText:SetPoint("TOPLEFT", 15, yOffset)
    checklistDescText:SetPoint("TOPRIGHT", -15, yOffset)
    checklistDescText:SetJustifyH("LEFT")
    checklistDescText:SetWordWrap(true)
    checklistDescText:SetText(L["SEASON_CHECKLIST_DESC"])
    checklistDescText:SetTextColor(T("TEXT_SECONDARY"))
    checklistDescText:SetSpacing(3)
    yOffset = yOffset - 50

    local checklistBtn = ns.UI.CreateButton(nil, scrollContent, L["SEASON_CHECKLIST_BTN"], 280, 35)
    checklistBtn:ClearAllPoints()
    checklistBtn:SetPoint("TOPLEFT", 25, yOffset)
    checklistBtn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))

    local checklistDialog = nil

    local function GetCurrencyIDsDisplay()
        local ids = (OneWoWAltTracker.db.global.overrides and
                     OneWoWAltTracker.db.global.overrides.progress and
                     OneWoWAltTracker.db.global.overrides.progress.trackedCurrencyIDs) or {}
        local parts = {}
        for _, id in ipairs(ids) do
            local info = C_CurrencyInfo.GetCurrencyInfo(id)
            table.insert(parts, (info and info.name or "ID " .. id) .. " (" .. id .. ")")
        end
        return #parts > 0 and table.concat(parts, ", ") or "None"
    end

    local function GetBossQuestIDsDisplay()
        local BOSS_NAMES = {}
        local ids = (OneWoWAltTracker.db.global.overrides and
                     OneWoWAltTracker.db.global.overrides.progress and
                     OneWoWAltTracker.db.global.overrides.progress.worldBossQuestIDs) or {}
        local parts = {}
        for _, id in ipairs(ids) do
            table.insert(parts, (BOSS_NAMES[id] or C_QuestLog.GetTitleForQuestID(id) or "Unknown") .. " (Q:" .. id .. ")")
        end
        return #parts > 0 and table.concat(parts, ", ") or "None"
    end

    local CHECKLIST_ITEMS = {
        {section = "Summary Tab"},
        {key = "s_maxlevel",  label = "Verify Max Player Level",                   auto = true,  value = function() return "Level " .. (GetMaxPlayerLevel and GetMaxPlayerLevel() or "?") end, file = "Auto-detected via API"},
        {key = "s_ilvl",      label = "Verify iLvl range for new content",          auto = false, value = function() return "Manual check required" end, file = "No single file - check new content tooltips"},
        {key = "s_toc",       label = "Update ## Interface in all TOC files",        auto = false, value = function() local v, b = GetBuildInfo(); return "Current build: " .. (b or "?") end, file = "All .toc files"},

        {section = "Progress Tab"},
        {key = "p_currencies", label = "Verify Tracked Currency IDs (change per season)", auto = false, value = GetCurrencyIDsDisplay, file = "OneWoW_AltTracker/Core/Database.lua + Override System"},
        {key = "p_bosses",    label = "Verify World Boss Quest IDs",                auto = false, value = GetBossQuestIDsDisplay, file = "OneWoW_AltTracker_Endgame/Modules/WorldBoss.lua + Database.lua"},
        {key = "p_boss_names",label = "Update KNOWN_BOSS_NAMES lookup table",       auto = false, value = function() return "See WorldBoss.lua and t-progress.lua" end, file = "OneWoW_AltTracker_Endgame/Modules/WorldBoss.lua, UI/t-progress.lua, UI/t-settings.lua"},
        {key = "p_dungeons",  label = "M+ Dungeon List",                            auto = true,  value = function() return "Auto via C_ChallengeMode.GetMapTable()" end, file = "No change needed"},
        {key = "p_raids",     label = "Raid Lockout Tracking",                      auto = true,  value = function() return "Auto via GetSavedInstanceInfo()" end, file = "No change needed"},
        {key = "p_vault",     label = "Great Vault Activity Types",                 auto = true,  value = function() return "Auto via C_WeeklyRewards.GetActivities()" end, file = "No change needed"},

        {section = "Bank / Storage Tab"},
        {key = "b_bags",      label = "Bag container IDs: 0=Backpack, 1-4=Bags, 5=Reagent", auto = true, value = function() return "Verified - using C_Container.GetContainerNumSlots(0-5)" end, file = "OneWoW_AltTracker_Storage/Modules/Bags.lua"},
        {key = "b_pbank",     label = "Personal Bank bag IDs (6-10)",               auto = true,  value = function() return "Using bankBagID = 5 + tabIndex" end, file = "OneWoW_AltTracker_Storage/Modules/PersonalBank.lua"},
        {key = "b_warband",   label = "Warband Bank bag IDs (12+)",                 auto = true,  value = function() return "Using warbandBagID = 11 + tabIndex" end, file = "OneWoW_AltTracker_Storage/Modules/WarbandBank.lua"},
        {key = "b_maxslots",  label = "Verify max bag/bank slot counts still valid", auto = false, value = function() return "Manual check - Blizzard may add new bank tabs" end, file = "Check above files if new tab types added"},

        {section = "Equipment Tab"},
        {key = "e_slots",     label = "Verify equipment slot IDs 1-19 still valid", auto = false, value = function() return "Standard slots (Head=1 through Tabard=19)" end, file = "OneWoW_AltTracker_Character/Modules/Equipment.lua"},
        {key = "e_tier",      label = "Update tier set item tracking for new season", auto = false, value = function() return "Check if new tier bonuses use new slot IDs" end, file = "UI/t-equipment.lua"},
        {key = "e_ilvl",      label = "Verify GetAverageItemLevel() still returns correct values", auto = true, value = function() return "API call - verify in-game accuracy" end, file = "OneWoW_AltTracker_Character/Modules/Equipment.lua"},

        {section = "Professions Tab"},
        {key = "pr_cooldowns", label = "Verify profession cooldown names/IDs",       auto = false, value = function() return "Manual check - cooldowns change per expansion" end, file = "OneWoW_AltTracker_Character/Modules/ (professions file)"},
        {key = "pr_maxskill",  label = "Verify max skill level (100 per expansion)", auto = false, value = function() return "Check if max profession level changed" end, file = "Professions collection module"},
        {key = "pr_tools",     label = "Verify tool/accessory slot IDs unchanged",   auto = false, value = function() return "Tool slots can change each expansion" end, file = "Professions collection module"},
        {key = "pr_new",       label = "Check for any new professions added",        auto = false, value = function() return "Unlikely but verify with GetNumSkillLines()" end, file = "Professions collection module"},

        {section = "Auctions Tab"},
        {key = "au_nothing",   label = "No seasonal updates required",               auto = true,  value = function() return "Auction API is stable" end, file = "Nothing to change"},

        {section = "Financials Tab"},
        {key = "fi_events",    label = "Verify gold tracking events still fire",     auto = false, value = function() return "PLAYER_MONEY, MAIL_SEND_SUCCESS, AUCTION_HOUSE_SHOW" end, file = "OneWoW_AltTracker_Accounting/"},
        {key = "fi_costs",     label = "Verify repair/vendor cost event names",      auto = false, value = function() return "MERCHANT_CLOSED and related events" end, file = "OneWoW_AltTracker_Accounting/"},

        {section = "Items Tab"},
        {key = "it_ah",        label = "Verify AH scan connection still works",       auto = false, value = function() return "Test with /at then Items tab" end, file = "OneWoW_AltTracker_Storage/Modules/AHScanner.lua"},

        {section = "Profiles / Settings"},
        {key = "ps_backup",    label = "Verify saved variable backup and restore",    auto = false, value = function() return "Test export/import of profile data" end, file = "OneWoW_AltTracker/Core/"},
        {key = "ps_keybinds",  label = "Check for new WoW keybind categories",       auto = false, value = function() return "GetNumBindings() - check for new binding types" end, file = "OneWoW_AltTracker_Character/Modules/ActionBars.lua"},
        {key = "ps_settings",  label = "Check for new WoW settings modules/panels",  auto = false, value = function() return "Blizzard may add new CVars or settings panels" end, file = "OneWoW_AltTracker_Character/Modules/"},

        {section = "General / Compatibility"},
        {key = "g_interface",  label = "Update ## Interface version in all TOC files", auto = false, value = function() local _, _, _, intVersion = GetBuildInfo(); return "Current: " .. (intVersion or "?") end, file = "All .toc files - ## Interface line"},
        {key = "g_midnight",   label = "Check MIDNIGHT.md for Midnight compatibility changes", auto = false, value = function() return "Secure buttons, action handling, etc." end, file = "See /home/pals/w2xyz/wow/MIDNIGHT.md"},
        {key = "g_api",        label = "Run full API verification pass on new APIs used", auto = false, value = function() return "Verify all WoW APIs on warcraft.wiki.gg" end, file = "All collection module files"},
    }

    local function OpenChecklistDialog()
        if checklistDialog and checklistDialog:IsShown() then
            checklistDialog:Raise()
            return
        end
        if checklistDialog then
            checklistDialog:Show()
            checklistDialog:Raise()
            return
        end

        checklistDialog = CreateFrame("Frame", "OneWoWSeasonChecklist", UIParent, "BackdropTemplate")
        checklistDialog:SetSize(780, 700)
        checklistDialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        checklistDialog:SetFrameStrata("DIALOG")
        checklistDialog:SetMovable(true)
        checklistDialog:SetClampedToScreen(true)
        checklistDialog:EnableMouse(true)
        checklistDialog:RegisterForDrag("LeftButton")
        checklistDialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
        checklistDialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        checklistDialog:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        checklistDialog:SetBackdropColor(T("BG_PRIMARY"))
        checklistDialog:SetBackdropBorderColor(T("BORDER_DEFAULT"))
        tinsert(UISpecialFrames, "OneWoWSeasonChecklist")

        local titleBar = CreateFrame("Frame", nil, checklistDialog, "BackdropTemplate")
        titleBar:SetPoint("TOPLEFT", checklistDialog, "TOPLEFT", 1, -1)
        titleBar:SetPoint("TOPRIGHT", checklistDialog, "TOPRIGHT", -1, -1)
        titleBar:SetHeight(26)
        titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        titleBar:SetBackdropColor(T("BG_SECONDARY"))
        local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
        titleText:SetText(L["SEASON_CHECKLIST_TITLE"])
        titleText:SetTextColor(T("ACCENT_PRIMARY"))
        local closeX = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
        closeX:SetSize(22, 22)
        closeX:SetPoint("RIGHT", titleBar, "RIGHT", -3, 0)
        closeX:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        closeX:SetBackdropColor(T("BG_TERTIARY"))
        local closeXTxt = closeX:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        closeXTxt:SetPoint("CENTER"); closeXTxt:SetText("X"); closeXTxt:SetTextColor(T("TEXT_PRIMARY"))
        closeX:SetScript("OnEnter", function(self) self:SetBackdropColor(T("BG_HOVER")); closeXTxt:SetTextColor(T("TEXT_ACCENT")) end)
        closeX:SetScript("OnLeave", function(self) self:SetBackdropColor(T("BG_TERTIARY")); closeXTxt:SetTextColor(T("TEXT_PRIMARY")) end)
        closeX:SetScript("OnClick", function() checklistDialog:Hide() end)

        local scrollFrame2, sc2 = ns.UI.CreateScrollFrame(nil, checklistDialog, 760, 640)
        scrollFrame2:ClearAllPoints()
        scrollFrame2:SetPoint("TOPLEFT", checklistDialog, "TOPLEFT", 1, -28)
        scrollFrame2:SetPoint("BOTTOMRIGHT", checklistDialog, "BOTTOMRIGHT", -1, 46)

        local cdy = -8
        local ROW_H = 54
        local checkedBoxes = {}

        for _, item in ipairs(CHECKLIST_ITEMS) do
            if item.section then
                local sh = ns.UI.CreateSectionHeader(sc2, item.section, cdy)
                cdy = sh.bottomY - 6
            else
                local row = CreateFrame("Frame", nil, sc2, "BackdropTemplate")
                row:SetPoint("TOPLEFT", 8, cdy)
                row:SetPoint("TOPRIGHT", -8, cdy)
                row:SetHeight(ROW_H)
                row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })

                local isChecked = OneWoWAltTracker.db.global.seasonChecklist[item.key] == true
                local isAuto = item.auto == true

                if isChecked then
                    row:SetBackdropColor(T("BG_SECONDARY"))
                    row:SetBackdropBorderColor(0.2, 0.5, 0.2)
                elseif isAuto then
                    row:SetBackdropColor(T("BG_TERTIARY"))
                    row:SetBackdropBorderColor(0.2, 0.5, 0.2, 0.5)
                else
                    row:SetBackdropColor(T("BG_TERTIARY"))
                    row:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                end

                local checkBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
                checkBtn:SetSize(22, 22)
                checkBtn:SetPoint("LEFT", row, "LEFT", 6, 0)
                checkBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                if isChecked then
                    checkBtn:SetBackdropColor(0.2, 0.7, 0.2)
                    checkBtn:SetBackdropBorderColor(0.2, 0.9, 0.2)
                elseif isAuto then
                    checkBtn:SetBackdropColor(0.15, 0.4, 0.15)
                    checkBtn:SetBackdropBorderColor(0.2, 0.5, 0.2, 0.5)
                else
                    checkBtn:SetBackdropColor(T("BG_SECONDARY"))
                    checkBtn:SetBackdropBorderColor(T("BORDER_DEFAULT"))
                end
                local checkMark = checkBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                checkMark:SetPoint("CENTER")
                checkMark:SetText(isChecked and "X" or (isAuto and "A" or " "))
                checkMark:SetTextColor(isChecked and 0.2 or (isAuto and 0.4 or 0.5), isChecked and 0.9 or (isAuto and 0.8 or 0.5), isChecked and 0.2 or (isAuto and 0.2 or 0.5))

                local labelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                labelText:SetPoint("TOPLEFT", row, "TOPLEFT", 34, -6)
                labelText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -6)
                labelText:SetJustifyH("LEFT")
                labelText:SetText(item.label)
                if isChecked then
                    labelText:SetTextColor(T("TEXT_MUTED"))
                else
                    labelText:SetTextColor(T("TEXT_PRIMARY"))
                end

                local valStr = item.value and item.value() or ""
                local valueText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                valueText:SetPoint("TOPLEFT", row, "TOPLEFT", 34, -22)
                valueText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -22)
                valueText:SetJustifyH("LEFT")
                valueText:SetWordWrap(true)
                valueText:SetText(L["SEASON_CURRENT"] .. " " .. valStr)
                valueText:SetTextColor(isAuto and 0.3 or 0.7, isAuto and 0.7 or 0.7, isAuto and 0.3 or 0.4)

                local fileText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                fileText:SetPoint("TOPLEFT", row, "TOPLEFT", 34, -37)
                fileText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -37)
                fileText:SetJustifyH("LEFT")
                fileText:SetText(L["SEASON_FILE"] .. " " .. item.file)
                fileText:SetTextColor(T("TEXT_MUTED"))

                if not isAuto then
                    checkBtn:EnableMouse(true)
                    checkBtn:SetScript("OnClick", function()
                        local nowChecked = not (OneWoWAltTracker.db.global.seasonChecklist[item.key] == true)
                        OneWoWAltTracker.db.global.seasonChecklist[item.key] = nowChecked
                        if nowChecked then
                            checkBtn:SetBackdropColor(0.2, 0.7, 0.2)
                            checkBtn:SetBackdropBorderColor(0.2, 0.9, 0.2)
                            checkMark:SetText("X")
                            checkMark:SetTextColor(0.2, 0.9, 0.2)
                            row:SetBackdropBorderColor(0.2, 0.5, 0.2)
                            labelText:SetTextColor(T("TEXT_MUTED"))
                        else
                            checkBtn:SetBackdropColor(T("BG_SECONDARY"))
                            checkBtn:SetBackdropBorderColor(T("BORDER_DEFAULT"))
                            checkMark:SetText(" ")
                            row:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                            labelText:SetTextColor(T("TEXT_PRIMARY"))
                        end
                    end)
                    checkBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(T("BG_HOVER")) end)
                    checkBtn:SetScript("OnLeave", function(self)
                        local c = OneWoWAltTracker.db.global.seasonChecklist[item.key]
                        self:SetBackdropColor(c and {0.2, 0.7, 0.2} or {T("BG_SECONDARY")})
                    end)
                end

                table.insert(checkedBoxes, {key = item.key, btn = checkBtn, mark = checkMark, rowFrame = row, label = labelText, isAuto = isAuto})
                cdy = cdy - (ROW_H + 4)
            end
        end

        sc2:SetHeight(math.abs(cdy) + 20)

        local clearBtn = ns.UI.CreateButton(nil, checklistDialog, L["SEASON_CHECKLIST_CLEAR"], 130, 30)
        clearBtn:ClearAllPoints()
        clearBtn:SetPoint("BOTTOMLEFT", checklistDialog, "BOTTOMLEFT", 10, 10)
        clearBtn:SetScript("OnClick", function()
            OneWoWAltTracker.db.global.seasonChecklist = {}
            for _, entry in ipairs(checkedBoxes) do
                if not entry.isAuto then
                    entry.btn:SetBackdropColor(T("BG_SECONDARY"))
                    entry.btn:SetBackdropBorderColor(T("BORDER_DEFAULT"))
                    entry.mark:SetText(" ")
                    entry.rowFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                    entry.label:SetTextColor(T("TEXT_PRIMARY"))
                end
            end
        end)

        local closeBtnCL = ns.UI.CreateButton(nil, checklistDialog, L["OVERRIDE_CLOSE"], 100, 30)
        closeBtnCL:ClearAllPoints()
        closeBtnCL:SetPoint("BOTTOMRIGHT", checklistDialog, "BOTTOMRIGHT", -10, 10)
        closeBtnCL:SetScript("OnClick", function() checklistDialog:Hide() end)

        local legendText = checklistDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        legendText:SetPoint("BOTTOM", checklistDialog, "BOTTOM", 0, 14)
        legendText:SetText("[X] = Verified this season    [A] = Auto-detected, no action needed    [ ] = Needs manual verification")
        legendText:SetTextColor(T("TEXT_MUTED"))

        checklistDialog:Show()
        checklistDialog:Raise()
    end

    checklistBtn:SetScript("OnClick", OpenChecklistDialog)

    yOffset = yOffset - 50

    scrollContent:SetHeight(math.abs(yOffset) + 20)

    parent.scrollFrame = scrollFrame
    parent.scrollContent = scrollContent
end
