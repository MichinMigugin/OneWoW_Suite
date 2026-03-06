-- OneWoW Addon File
-- OneWoW_Catalog/UI/t-settings.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local OneWoWCatalog = OneWoW_Catalog
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

    local currentLang = OneWoWCatalog.db.global.language or "enUS"
    local langNames = {
        ["enUS"] = "English",
        ["koKR"] = "\237\149\156\234\181\173\236\150\180"
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
                OneWoWCatalog.db.global.language = langCode
                OneWoWCatalog.db.global.lastTab = "settings"
                if ns.ApplyLanguage then ns.ApplyLanguage() end
                menu:Hide()
                ns.UI:Reset()
                C_Timer.After(0.1, function()
                    ns.UI:Show("settings")
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

    local currentTheme = OneWoWCatalog.db.global.theme or "green"
    local themeNames = {
        ["green"]        = L["THEME_FOREST_GREEN"],
        ["blue"]         = L["THEME_OCEAN_BLUE"],
        ["purple"]       = L["THEME_ROYAL_PURPLE"],
        ["red"]          = L["THEME_CRIMSON_RED"],
        ["orange"]       = L["THEME_SUNSET_ORANGE"],
        ["teal"]         = L["THEME_DEEP_TEAL"],
        ["gold"]         = L["THEME_GOLDEN_AMBER"],
        ["pink"]         = L["THEME_ROSE_PINK"],
        ["slate"]        = L["THEME_SLATE_GRAY"],
        ["dark"]         = L["THEME_MIDNIGHT_BLACK"],
        ["amber"]        = L["THEME_AMBER_FIRE"],
        ["cyan"]         = L["THEME_ARCTIC_CYAN"],
        ["voidblack"]    = L["THEME_VOID_BLACK"],
        ["charcoal"]     = L["THEME_CHARCOAL_DEEP"],
        ["forestnight"]  = L["THEME_FOREST_NIGHT"],
        ["obsidian"]     = L["THEME_OBSIDIAN_MINIMAL"],
        ["monochrome"]   = L["THEME_MONOCHROME_PRO"],
        ["twilight"]     = L["THEME_TWILIGHT_COMPACT"],
        ["neon"]         = L["THEME_NEON_SYNTHWAVE"],
        ["glassmorphic"] = L["THEME_GLASSMORPHIC"],
        ["lightmode"]    = L["THEME_MINIMAL_WHITE"],
        ["retro"]        = L["THEME_RETRO_CLASSIC"],
        ["fantasy"]      = L["THEME_RPG_FANTASY"],
        ["nightfae"]     = L["THEME_COVENANT_TWILIGHT"],
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

        local innerContainer = CreateFrame("Frame", nil, menu)
        innerContainer:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
        innerContainer:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -2, 2)

        local innerScrollFrame = CreateFrame("ScrollFrame", nil, innerContainer, "UIPanelScrollFrameTemplate")
        innerScrollFrame:SetPoint("TOPLEFT", innerContainer, "TOPLEFT", 0, 0)
        innerScrollFrame:SetPoint("BOTTOMRIGHT", innerContainer, "BOTTOMRIGHT", -14, 0)

        local innerScrollBar = innerScrollFrame.ScrollBar
        if innerScrollBar then
            innerScrollBar:ClearAllPoints()
            innerScrollBar:SetPoint("TOPRIGHT", innerContainer, "TOPRIGHT", -2, 0)
            innerScrollBar:SetPoint("BOTTOMRIGHT", innerContainer, "BOTTOMRIGHT", -2, 0)
            innerScrollBar:SetWidth(10)
            if innerScrollBar.ScrollUpButton then
                innerScrollBar.ScrollUpButton:Hide()
                innerScrollBar.ScrollUpButton:SetAlpha(0)
                innerScrollBar.ScrollUpButton:EnableMouse(false)
            end
            if innerScrollBar.ScrollDownButton then
                innerScrollBar.ScrollDownButton:Hide()
                innerScrollBar.ScrollDownButton:SetAlpha(0)
                innerScrollBar.ScrollDownButton:EnableMouse(false)
            end
            if innerScrollBar.Background then
                innerScrollBar.Background:SetColorTexture(0.1, 0.1, 0.1, 0.8)
            end
            if innerScrollBar.ThumbTexture then
                innerScrollBar.ThumbTexture:SetWidth(8)
                innerScrollBar.ThumbTexture:SetColorTexture(0.5, 0.5, 0.5)
            end
        end

        local innerScrollChild = CreateFrame("Frame", nil, innerScrollFrame)
        innerScrollChild:SetHeight(1)
        innerScrollFrame:SetScrollChild(innerScrollChild)

        innerScrollFrame:HookScript("OnSizeChanged", function(self, w)
            innerScrollChild:SetWidth(w)
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
                OneWoWCatalog.db.global.theme = themeKey
                OneWoWCatalog.db.global.lastTab = "settings"
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
                    ns.UI:Show("settings")
                end)
            end)

            return btn
        end

        local yPos = -5
        for _, themeKey in ipairs(themeOrder) do
            createThemeButton(innerScrollChild, themeNames[themeKey], themeKey, yPos)
            yPos = yPos - 28
        end
        innerScrollChild:SetHeight(math.abs(yPos) + 5)

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

    local isMinimapEnabled = not (OneWoWCatalog.db.global.minimap and OneWoWCatalog.db.global.minimap.hide)
    mmCheckbox:SetChecked(isMinimapEnabled)

    local mmCheckLabel = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmCheckLabel:SetPoint("LEFT", mmCheckbox, "RIGHT", 4, 0)
    mmCheckLabel:SetText(L["MINIMAP_SHOW_BTN"])
    mmCheckLabel:SetTextColor(T("TEXT_PRIMARY"))

    mmCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if checked then
            OneWoWCatalog.db.global.minimap.hide = false
            if ns.MinimapButton then ns.MinimapButton:Show() end
        else
            OneWoWCatalog.db.global.minimap.hide = true
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

    local currentIconTheme = OneWoWCatalog.db.global.minimap and OneWoWCatalog.db.global.minimap.theme or "horde"
    local iconThemeNames = {
        ["horde"]    = L["MINIMAP_ICON_HORDE"],
        ["alliance"] = L["MINIMAP_ICON_ALLIANCE"],
        ["neutral"]  = L["MINIMAP_ICON_NEUTRAL"],
    }
    local iconThemePaths = {
        ["horde"]    = "Interface\\AddOns\\OneWoW_Catalog\\Media\\horde-mini.png",
        ["alliance"] = "Interface\\AddOns\\OneWoW_Catalog\\Media\\alliance-mini.png",
        ["neutral"]  = "Interface\\AddOns\\OneWoW_Catalog\\Media\\neutral-mini.png",
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
                OneWoWCatalog.db.global.minimap.theme = themeKey
                OneWoWCatalog.db.global.lastTab = "settings"
                mmIconPreview:SetTexture(iconThemePaths[themeKey])
                mmIconText:SetText(iconThemeNames[themeKey])
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

    local dbSection = ns.UI.CreateSectionHeader(scrollContent, L["DATA_MANAGER_TITLE"], yOffset)
    yOffset = dbSection.bottomY - 8

    local dbDesc = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dbDesc:SetPoint("TOPLEFT", 15, yOffset)
    dbDesc:SetPoint("TOPRIGHT", -15, yOffset)
    dbDesc:SetJustifyH("LEFT")
    dbDesc:SetWordWrap(true)
    dbDesc:SetText(L["DATA_MANAGER_DESC"])
    dbDesc:SetTextColor(T("TEXT_SECONDARY"))
    dbDesc:SetSpacing(3)
    yOffset = yOffset - 30

    local databases = {
        { key = "OneWoW_Catalog",              name = "Catalog Core",       desc = "Main addon settings and UI state" },
        { key = "OneWoW_CatalogData_Journal",  name = "Journal Data",       desc = "Instance and encounter journal data" },
        { key = "OneWoW_CatalogData_Vendors",  name = "Vendors Data",       desc = "Vendor and item data" },
        { key = "OneWoW_CatalogData_Tradeskills", name = "Tradeskills Data",desc = "Profession and recipe data" },

    }

    local function GetTableSize(dbKey)
        if not _G[dbKey .. "_DB"] then return 0 end
        local db = _G[dbKey .. "_DB"]
        local size = 0
        for _ in pairs(db) do size = size + 1 end
        return math.max(0, size - 5)
    end

    local function CreateDatabaseEntry(parent, dbData, yPos)
        local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yPos)
        container:SetSize(770, 60)
        container:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
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
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        resetBtn:SetBackdropColor(1, 0.3, 0.3)
        resetBtn:SetBackdropBorderColor(T("BORDER_DEFAULT"))

        local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        resetText:SetPoint("CENTER")
        resetText:SetText("Reset")
        resetText:SetTextColor(1, 1, 1)

        resetBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(1, 0.1, 0.1) end)
        resetBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(1, 0.3, 0.3) end)

        resetBtn:SetScript("OnClick", function()
            StaticPopupDialogs["OWCAT_RESET_DB_CONFIRM"] = {
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
            StaticPopup_Show("OWCAT_RESET_DB_CONFIRM")
        end)

        return 65
    end

    for _, dbData in ipairs(databases) do
        local height = CreateDatabaseEntry(scrollContent, dbData, yOffset)
        yOffset = yOffset - height - 8
    end

    yOffset = yOffset - 20
    scrollContent:SetHeight(math.abs(yOffset) + 20)
end
