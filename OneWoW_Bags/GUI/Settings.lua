local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.Settings = {}
local Settings = OneWoW_Bags.Settings
local settingsFrame = nil
local isCreated = false

local function T(key)
    if OneWoW_Bags.Constants and OneWoW_Bags.Constants.THEME and OneWoW_Bags.Constants.THEME[key] then
        return unpack(OneWoW_Bags.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if OneWoW_Bags.Constants and OneWoW_Bags.Constants.SPACING then
        return OneWoW_Bags.Constants.SPACING[key] or 8
    end
    return 8
end

function Settings:Create()
    if isCreated then return settingsFrame end

    local GUI = OneWoW_Bags.GUI
    local Constants = OneWoW_Bags.Constants
    local L = OneWoW_Bags.L
    local db = OneWoW_Bags.db

    settingsFrame = CreateFrame("Frame", "OneWoW_BagsSettingsWindow", UIParent, "BackdropTemplate")
    settingsFrame:SetSize(520, 680)
    settingsFrame:SetPoint("CENTER")
    settingsFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    settingsFrame:SetBackdropColor(T("BG_PRIMARY"))
    settingsFrame:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    settingsFrame:SetFrameStrata("DIALOG")
    settingsFrame:SetMovable(true)
    settingsFrame:EnableMouse(true)
    settingsFrame:RegisterForDrag("LeftButton")
    settingsFrame:SetScript("OnDragStart", settingsFrame.StartMoving)
    settingsFrame:SetScript("OnDragStop", settingsFrame.StopMovingOrSizing)
    settingsFrame:SetClampedToScreen(true)
    settingsFrame:Hide()
    tinsert(UISpecialFrames, "OneWoW_BagsSettingsWindow")

    local titleBar = CreateFrame("Frame", nil, settingsFrame, "BackdropTemplate")
    titleBar:SetHeight(S("LG") + S("XS"))
    titleBar:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", S("XS"), -S("XS"))
    titleBar:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -S("XS"), -S("XS"))
    titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    titleBar:SetBackdropColor(T("TITLEBAR_BG"))

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    titleText:SetText(L["SETTINGS_TITLE"])
    titleText:SetTextColor(T("TEXT_PRIMARY"))

    local closeBtn = GUI:CreateButton(nil, titleBar, "X", 20, 20)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -S("XS") / 2, 0)
    closeBtn:SetScript("OnClick", function() settingsFrame:Hide() end)

    local contentArea = CreateFrame("Frame", nil, settingsFrame)
    contentArea:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", S("XS"), -(S("XS") + S("LG") + S("XS") + S("XS")))
    contentArea:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -S("XS"), S("XS"))

    local scrollFrame, scrollContent = GUI:CreateScrollFrame("OneWoW_BagsSettings", contentArea, 480, 600)
    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        if scrollContent then scrollContent:SetWidth(w - 16) end
    end)

    local yOffset = -15

    local currentLang = db.global.language or GetLocale()
    local langNames = {
        ["enUS"] = L["ENGLISH"], ["esES"] = L["SPANISH"], ["esMX"] = L["SPANISH"],
        ["koKR"] = L["KOREAN"], ["frFR"] = L["FRENCH"],
        ["ruRU"] = L["RUSSIAN"], ["deDE"] = L["GERMAN"]
    }

    local currentTheme = db.global.theme or "green"
    local themeNames = {
        ["green"] = L["THEME_GREEN"], ["blue"] = L["THEME_BLUE"], ["purple"] = L["THEME_PURPLE"],
        ["gold"] = L["THEME_GOLD"], ["slate"] = L["THEME_SLATE"], ["orange"] = L["THEME_ORANGE"],
        ["teal"] = L["THEME_TEAL"], ["cyan"] = L["THEME_CYAN"], ["pink"] = L["THEME_PINK"],
        ["dark"] = L["THEME_DARK"], ["amber"] = L["THEME_AMBER"], ["red"] = L["THEME_RED"],
        ["voidblack"] = L["THEME_VOID_BLACK"], ["charcoal"] = L["THEME_CHARCOAL_DEEP"],
        ["forestnight"] = L["THEME_FOREST_NIGHT"], ["obsidian"] = L["THEME_OBSIDIAN_MINIMAL"],
        ["monochrome"] = L["THEME_MONOCHROME_PRO"], ["twilight"] = L["THEME_TWILIGHT_COMPACT"],
        ["neon"] = L["THEME_NEON_SYNTHWAVE"], ["glassmorphic"] = L["THEME_GLASSMORPHIC"],
        ["lightmode"] = L["THEME_MINIMAL_WHITE"], ["retro"] = L["THEME_RETRO_CLASSIC"],
        ["fantasy"] = L["THEME_RPG_FANTASY"], ["nightfae"] = L["THEME_COVENANT_TWILIGHT"]
    }

    local splitContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    splitContainer:SetPoint("TOPLEFT", 10, yOffset)
    splitContainer:SetPoint("TOPRIGHT", -10, yOffset)
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

    local langTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    langTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -12)
    langTitle:SetText(L["LANGUAGE_SELECTION"])
    langTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local langDesc = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDesc:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -38)
    langDesc:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -10, -38)
    langDesc:SetJustifyH("LEFT")
    langDesc:SetWordWrap(true)
    langDesc:SetText(L["LANGUAGE_DESC"])
    langDesc:SetTextColor(T("TEXT_SECONDARY"))

    local langCurrentLabel = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langCurrentLabel:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -90)
    langCurrentLabel:SetText(L["CURRENT_LANGUAGE"] .. ": " .. (langNames[currentLang] or L["ENGLISH"]))
    langCurrentLabel:SetTextColor(T("ACCENT_PRIMARY"))

    local languageDropdown = CreateFrame("Button", nil, leftPanel, "BackdropTemplate")
    languageDropdown:SetSize(190, 30)
    languageDropdown:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -115)
    languageDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    languageDropdown:SetBackdropColor(T("BG_TERTIARY"))
    languageDropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local langDropText = languageDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDropText:SetPoint("CENTER")
    langDropText:SetText(langNames[currentLang] or L["ENGLISH"])
    langDropText:SetTextColor(T("TEXT_PRIMARY"))

    local langDropArrow = languageDropdown:CreateTexture(nil, "OVERLAY")
    langDropArrow:SetSize(16, 16)
    langDropArrow:SetPoint("RIGHT", languageDropdown, "RIGHT", -5, 0)
    langDropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    languageDropdown:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
    end)

    languageDropdown:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    languageDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(190, 171)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false,
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:EnableMouse(true)

        local function createLangButton(langParent, langName, langCode, yPos)
            local btn = CreateFrame("Button", nil, langParent, "BackdropTemplate")
            btn:SetSize(180, 25)
            btn:SetPoint("TOP", langParent, "TOP", 0, yPos)
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("CENTER")
            text:SetText(langName)
            text:SetTextColor(0.9, 0.9, 0.9)

            btn:SetScript("OnEnter", function(s)
                s:SetBackdropColor(0.2, 0.2, 0.2, 1)
                text:SetTextColor(1, 0.82, 0)
            end)

            btn:SetScript("OnLeave", function(s)
                s:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                text:SetTextColor(0.9, 0.9, 0.9)
            end)

            btn:SetScript("OnClick", function()
                menu:Hide()
                OneWoW_Bags:ReinitForLanguage(langCode)
            end)

            return btn
        end

        createLangButton(menu, langNames["enUS"], "enUS", -5)
        createLangButton(menu, langNames["esES"], "esES", -32)
        createLangButton(menu, langNames["koKR"], "koKR", -59)
        createLangButton(menu, langNames["frFR"], "frFR", -86)
        createLangButton(menu, langNames["ruRU"], "ruRU", -113)
        createLangButton(menu, langNames["deDE"], "deDE", -140)

        menu:SetScript("OnShow", function(self)
            local timeOutside = 0
            local function hideFunc()
                if self:IsShown() then self:Hide() end
                self:SetScript("OnUpdate", nil)
                timeOutside = 0
            end
            self:SetScript("OnUpdate", function(self, elapsed)
                if not MouseIsOver(menu) and not MouseIsOver(languageDropdown) then
                    timeOutside = timeOutside + elapsed
                    if timeOutside > 0.5 then hideFunc() end
                else
                    timeOutside = 0
                end
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

    local themeTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    themeTitle:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -12)
    themeTitle:SetText(L["THEME_SECTION"])
    themeTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local themeDescText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDescText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -38)
    themeDescText:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -10, -38)
    themeDescText:SetJustifyH("LEFT")
    themeDescText:SetWordWrap(true)
    themeDescText:SetText(L["THEME_DESC"])
    themeDescText:SetTextColor(T("TEXT_SECONDARY"))

    local themeCurrentLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeCurrentLabel:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -90)
    themeCurrentLabel:SetText(L["THEME_CURRENT"] .. ": " .. (themeNames[currentTheme] or L["THEME_GREEN"]))
    themeCurrentLabel:SetTextColor(T("ACCENT_PRIMARY"))

    local themeDropdown = CreateFrame("Button", nil, rightPanel, "BackdropTemplate")
    themeDropdown:SetSize(210, 30)
    themeDropdown:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -115)
    themeDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    themeDropdown:SetBackdropColor(T("BG_TERTIARY"))
    themeDropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local themeDropText = themeDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDropText:SetPoint("LEFT", themeDropdown, "LEFT", 25, 0)
    themeDropText:SetText(themeNames[currentTheme] or L["THEME_GREEN"])
    themeDropText:SetTextColor(T("TEXT_PRIMARY"))

    local themeColorPreview = themeDropdown:CreateTexture(nil, "OVERLAY")
    themeColorPreview:SetSize(14, 14)
    themeColorPreview:SetPoint("LEFT", themeDropdown, "LEFT", 6, 0)
    local currentThemeData = Constants.THEMES[currentTheme]
    if currentThemeData then
        themeColorPreview:SetColorTexture(unpack(currentThemeData.ACCENT_PRIMARY))
    end

    local themeDropArrow = themeDropdown:CreateTexture(nil, "OVERLAY")
    themeDropArrow:SetSize(16, 16)
    themeDropArrow:SetPoint("RIGHT", themeDropdown, "RIGHT", -5, 0)
    themeDropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    themeDropdown:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
    end)

    themeDropdown:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    themeDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(240, 220)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false,
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menu:EnableMouse(true)

        local themeScrollFrame = CreateFrame("ScrollFrame", nil, menu)
        themeScrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
        themeScrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -15, 2)

        local scrollChild = CreateFrame("Frame", nil, themeScrollFrame)
        scrollChild:SetWidth(themeScrollFrame:GetWidth())
        themeScrollFrame:SetScrollChild(scrollChild)

        local scrollBar = CreateFrame("Slider", nil, themeScrollFrame, "BackdropTemplate")
        scrollBar:SetPoint("TOPLEFT", themeScrollFrame, "TOPRIGHT", 0, -2)
        scrollBar:SetPoint("BOTTOMLEFT", themeScrollFrame, "BOTTOMRIGHT", 0, 2)
        scrollBar:SetWidth(12)
        scrollBar:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
        scrollBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        scrollBar:EnableMouse(true)
        scrollBar:SetScript("OnValueChanged", function(self, value) themeScrollFrame:SetVerticalScroll(value) end)

        local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(8, 40)
        thumb:SetPoint("TOP", scrollBar, "TOP", 0, -2)
        thumb:SetColorTexture(0.5, 0.5, 0.5)
        scrollBar:SetThumbTexture(thumb)

        themeScrollFrame:EnableMouseWheel(true)
        themeScrollFrame:SetScript("OnMouseWheel", function(self, direction)
            local currentScroll = themeScrollFrame:GetVerticalScroll()
            local maxScroll = scrollChild:GetHeight() - themeScrollFrame:GetHeight()
            local newScroll = math.max(0, math.min(maxScroll, currentScroll - (direction * 30)))
            themeScrollFrame:SetVerticalScroll(newScroll)
            scrollBar:SetValue(newScroll)
        end)

        local themeOrder = { "green", "blue", "purple", "gold", "red", "slate", "orange", "teal", "cyan", "pink", "dark", "amber", "voidblack", "charcoal", "forestnight", "obsidian", "monochrome", "twilight", "neon", "glassmorphic", "lightmode", "retro", "fantasy", "nightfae" }

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
                txt:SetText(themeNames[themeKey] or themeData.name)
                txt:SetTextColor(0.9, 0.9, 0.9)
                btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) txt:SetTextColor(1, 0.82, 0) end)
                btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) txt:SetTextColor(0.9, 0.9, 0.9) end)
                local capturedKey = themeKey
                btn:SetScript("OnClick", function()
                    db.global.theme = capturedKey
                    if Constants.THEMES and Constants.THEMES[capturedKey] then
                        local selectedTheme = Constants.THEMES[capturedKey]
                        for key, value in pairs(selectedTheme) do
                            if key ~= "name" then
                                Constants.THEME[key] = value
                            end
                        end
                    end
                    menu:Hide()
                    GUI:FullReset()
                    C_Timer.After(0.1, function()
                        GUI:Show()
                    end)
                end)
            end
        end
        scrollChild:SetHeight(#themeOrder * 28 + 10)
        local maxScroll = math.max(0, scrollChild:GetHeight() - themeScrollFrame:GetHeight())
        scrollBar:SetMinMaxValues(0, maxScroll)
        themeScrollFrame:SetVerticalScroll(0)
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

    local mmContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    mmContainer:SetPoint("TOPLEFT", 10, yOffset)
    mmContainer:SetPoint("TOPRIGHT", -10, yOffset)
    mmContainer:SetHeight(130)
    mmContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
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

    local mmShowCheck = GUI:CreateCheckbox(nil, mmLeftPanel, L["MINIMAP_SHOW_BTN"])
    mmShowCheck:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 10, -85)
    local isMinimapHidden = db.global.minimap and db.global.minimap.hide
    mmShowCheck:SetChecked(not isMinimapHidden)
    mmShowCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            db.global.minimap.hide = false
            OneWoW_Bags.Minimap:SetShown(true)
        else
            db.global.minimap.hide = true
            OneWoW_Bags.Minimap:SetShown(false)
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

    local currentMMTheme = db.global.minimap and db.global.minimap.theme or "horde"
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
    mmIconDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    mmIconDropdown:SetBackdropColor(T("BG_TERTIARY"))
    mmIconDropdown:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local mmDropIcon = mmIconDropdown:CreateTexture(nil, "OVERLAY")
    mmDropIcon:SetSize(18, 18)
    mmDropIcon:SetPoint("LEFT", mmIconDropdown, "LEFT", 6, 0)
    local mmDropIconTex
    if currentMMTheme == "alliance" then
        mmDropIconTex = "Interface\\AddOns\\OneWoW_Bags\\Media\\alliance-mini.png"
    elseif currentMMTheme == "neutral" then
        mmDropIconTex = "Interface\\AddOns\\OneWoW_Bags\\Media\\neutral-mini.png"
    else
        mmDropIconTex = "Interface\\AddOns\\OneWoW_Bags\\Media\\horde-mini.png"
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

    mmIconDropdown:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
    end)
    mmIconDropdown:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    mmIconDropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(180, 100)
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

        local function createIconBtn(iconParent, themeKey, yPos)
            local btn = CreateFrame("Button", nil, iconParent, "BackdropTemplate")
            btn:SetSize(170, 26)
            btn:SetPoint("TOP", iconParent, "TOP", 0, yPos)
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

            local previewIcon = btn:CreateTexture(nil, "OVERLAY")
            previewIcon:SetSize(18, 18)
            previewIcon:SetPoint("LEFT", btn, "LEFT", 8, 0)
            local previewTex
            if themeKey == "alliance" then
                previewTex = "Interface\\AddOns\\OneWoW_Bags\\Media\\alliance-mini.png"
            elseif themeKey == "neutral" then
                previewTex = "Interface\\AddOns\\OneWoW_Bags\\Media\\neutral-mini.png"
            else
                previewTex = "Interface\\AddOns\\OneWoW_Bags\\Media\\horde-mini.png"
            end
            previewIcon:SetTexture(previewTex)

            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", btn, "LEFT", 32, 0)
            text:SetText(iconThemeNames[themeKey])
            text:SetTextColor(0.9, 0.9, 0.9)

            btn:SetScript("OnEnter", function(s)
                s:SetBackdropColor(0.2, 0.2, 0.2, 1)
                text:SetTextColor(1, 0.82, 0)
            end)
            btn:SetScript("OnLeave", function(s)
                s:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                text:SetTextColor(0.9, 0.9, 0.9)
            end)

            btn:SetScript("OnClick", function()
                db.global.minimap.theme = themeKey
                if OneWoW_Bags.Minimap then
                    OneWoW_Bags.Minimap:UpdateIcon()
                end
                menu:Hide()
                GUI:FullReset()
                C_Timer.After(0.1, function()
                    GUI:Show()
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
                    if timeOutside > 0.5 then
                        self:Hide()
                        self:SetScript("OnUpdate", nil)
                        timeOutside = 0
                    end
                else
                    timeOutside = 0
                end
            end)
        end)
    end)

    yOffset = yOffset - 145

    local bagSettingsContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    bagSettingsContainer:SetPoint("TOPLEFT", 10, yOffset)
    bagSettingsContainer:SetPoint("TOPRIGHT", -10, yOffset)
    bagSettingsContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bagSettingsContainer:SetBackdropColor(T("BG_SECONDARY"))
    bagSettingsContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local bagYOffset = -12

    local cbRarity = GUI:CreateCheckbox(nil, bagSettingsContainer, L["SETTING_RARITY_COLOR"] or "Rarity Colors")
    cbRarity:SetPoint("TOPLEFT", 10, bagYOffset)
    cbRarity:SetChecked(db.global.rarityColor)
    cbRarity:SetScript("OnClick", function(self)
        db.global.rarityColor = self:GetChecked()
        if GUI.RefreshLayout then GUI:RefreshLayout() end
    end)
    bagYOffset = bagYOffset - 28

    local cbNewItems = GUI:CreateCheckbox(nil, bagSettingsContainer, L["SETTING_SHOW_NEW"] or "Highlight New Items")
    cbNewItems:SetPoint("TOPLEFT", 10, bagYOffset)
    cbNewItems:SetChecked(db.global.showNewItems)
    cbNewItems:SetScript("OnClick", function(self)
        db.global.showNewItems = self:GetChecked()
        if GUI.RefreshLayout then GUI:RefreshLayout() end
    end)
    bagYOffset = bagYOffset - 28

    local cbAutoOpen = GUI:CreateCheckbox(nil, bagSettingsContainer, L["SETTING_AUTO_OPEN"] or "Auto-Open on Loot")
    cbAutoOpen:SetPoint("TOPLEFT", 10, bagYOffset)
    cbAutoOpen:SetChecked(db.global.autoOpen)
    cbAutoOpen:SetScript("OnClick", function(self)
        db.global.autoOpen = self:GetChecked()
    end)
    bagYOffset = bagYOffset - 28

    local cbAutoClose = GUI:CreateCheckbox(nil, bagSettingsContainer, L["SETTING_AUTO_CLOSE"] or "Auto-Close")
    cbAutoClose:SetPoint("TOPLEFT", 10, bagYOffset)
    cbAutoClose:SetChecked(db.global.autoClose)
    cbAutoClose:SetScript("OnClick", function(self)
        db.global.autoClose = self:GetChecked()
    end)
    bagYOffset = bagYOffset - 28

    local cbBagsBar = GUI:CreateCheckbox(nil, bagSettingsContainer, L["SETTING_SHOW_BAGS_BAR"] or "Show Bags Bar")
    cbBagsBar:SetPoint("TOPLEFT", 10, bagYOffset)
    cbBagsBar:SetChecked(db.global.showBagsBar)
    cbBagsBar:SetScript("OnClick", function(self)
        db.global.showBagsBar = self:GetChecked()
        if OneWoW_Bags.GUI.UpdateBagsBarVisibility then
            OneWoW_Bags.GUI:UpdateBagsBarVisibility()
        end
    end)
    bagYOffset = bagYOffset - 28

    local cbLock = GUI:CreateCheckbox(nil, bagSettingsContainer, L["SETTING_LOCK"] or "Lock Window")
    cbLock:SetPoint("TOPLEFT", 10, bagYOffset)
    cbLock:SetChecked(db.global.locked)
    cbLock:SetScript("OnClick", function(self)
        db.global.locked = self:GetChecked()
    end)
    bagYOffset = bagYOffset - 35

    local sizeLabel = bagSettingsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 15, bagYOffset)
    sizeLabel:SetText(L["SETTING_ICON_SIZE"] or "Icon Size")
    sizeLabel:SetTextColor(T("ACCENT_PRIMARY"))
    bagYOffset = bagYOffset - 22

    local sizeKeys = {"S", "M", "L", "XL"}
    local sizeLabels = {L["ICON_SIZE_S"], L["ICON_SIZE_M"], L["ICON_SIZE_L"], L["ICON_SIZE_XL"]}
    local sizeBtns = {}
    local sizeXOffset = 15
    for i = 1, 4 do
        local btn = GUI:CreateButton(nil, bagSettingsContainer, sizeLabels[i] or sizeKeys[i], 100, 24)
        btn.sizeIdx = i
        btn:SetScript("OnClick", function(self)
            db.global.iconSize = self.sizeIdx
            Settings:UpdateSizeButtons(sizeBtns)
            if GUI.RefreshLayout then GUI:RefreshLayout() end
        end)
        btn:AutoFit(14)
        btn:SetPoint("TOPLEFT", sizeXOffset, bagYOffset)
        sizeXOffset = sizeXOffset + btn:GetWidth() + 8
        sizeBtns[i] = btn
    end
    Settings.sizeBtns = sizeBtns
    Settings:UpdateSizeButtons(sizeBtns)
    bagYOffset = bagYOffset - 35

    local sortLabel = bagSettingsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sortLabel:SetPoint("TOPLEFT", 15, bagYOffset)
    sortLabel:SetText(L["SETTING_CATEGORY_SORT"] or "Category Sort")
    sortLabel:SetTextColor(T("ACCENT_PRIMARY"))
    bagYOffset = bagYOffset - 22

    local sortModes = {"priority", "alphabetical"}
    local sortLabelsText = {L["SORT_PRIORITY"] or "Priority", L["SORT_ALPHABETICAL"] or "Alphabetical"}
    local sortBtns = {}
    local sortXOffset = 15
    for i, mode in ipairs(sortModes) do
        local btn = GUI:CreateButton(nil, bagSettingsContainer, sortLabelsText[i], 100, 24)
        btn.sortMode = mode
        btn:SetScript("OnClick", function(self)
            db.global.categorySort = self.sortMode
            Settings:UpdateSortButtons(sortBtns)
            if GUI.RefreshLayout then GUI:RefreshLayout() end
        end)
        btn:AutoFit(14)
        btn:SetPoint("TOPLEFT", sortXOffset, bagYOffset)
        sortXOffset = sortXOffset + btn:GetWidth() + 8
        sortBtns[i] = btn
    end
    Settings.sortBtns = sortBtns
    Settings:UpdateSortButtons(sortBtns)
    bagYOffset = bagYOffset - 35

    if _G.OneWoW then
        local overlayLabel = bagSettingsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        overlayLabel:SetPoint("TOPLEFT", 15, bagYOffset)
        overlayLabel:SetText(L["OVERLAY_SECTION"])
        overlayLabel:SetTextColor(T("ACCENT_PRIMARY"))
        bagYOffset = bagYOffset - 22

        local overlayDesc = bagSettingsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        overlayDesc:SetPoint("TOPLEFT", bagSettingsContainer, "TOPLEFT", 15, bagYOffset)
        overlayDesc:SetPoint("TOPRIGHT", bagSettingsContainer, "TOPRIGHT", -10, bagYOffset)
        overlayDesc:SetJustifyH("LEFT")
        overlayDesc:SetWordWrap(true)
        overlayDesc:SetText(L["OVERLAY_SECTION_DESC"])
        overlayDesc:SetTextColor(T("TEXT_SECONDARY"))
        bagYOffset = bagYOffset - overlayDesc:GetStringHeight() - 12

        local function UpdateOverlayButton(btn)
            if not _G.OneWoW or not _G.OneWoW.SettingsFeatureRegistry then return end
            local isEnabled = _G.OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", "general")
            if isEnabled then
                btn.text:SetText(L["OVERLAY_TOGGLE_ON"])
                btn:SetBackdropColor(T("BG_ACTIVE"))
                btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
                btn.text:SetTextColor(T("TEXT_ACCENT"))
            else
                btn.text:SetText(L["OVERLAY_TOGGLE_OFF"])
                btn:SetBackdropColor(T("BTN_NORMAL"))
                btn:SetBackdropBorderColor(T("BTN_BORDER"))
                btn.text:SetTextColor(T("TEXT_PRIMARY"))
            end
            btn:AutoFit(14)
        end

        local overlayBtn = GUI:CreateButton(nil, bagSettingsContainer, L["OVERLAY_TOGGLE_ON"], 100, 24)
        overlayBtn:SetPoint("TOPLEFT", 15, bagYOffset)
        overlayBtn:SetScript("OnClick", function(self)
            if not _G.OneWoW or not _G.OneWoW.SettingsFeatureRegistry then return end
            local nowEnabled = _G.OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", "general")
            _G.OneWoW.SettingsFeatureRegistry:SetEnabled("overlays", "general", not nowEnabled)
            _G.OneWoW.OverlayEngine:Refresh()
            UpdateOverlayButton(self)
        end)
        overlayBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["OVERLAY_SECTION"])
            GameTooltip:AddLine(L["OVERLAY_SECTION_DESC"], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        overlayBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        UpdateOverlayButton(overlayBtn)
        bagYOffset = bagYOffset - 35
    end

    bagSettingsContainer:SetHeight(math.abs(bagYOffset) + 12)

    yOffset = yOffset - (math.abs(bagYOffset) + 12) - 15

    scrollContent:SetHeight(math.abs(yOffset) + 40)

    isCreated = true
    return settingsFrame
end

function Settings:UpdateSizeButtons(btns)
    if not btns then btns = Settings.sizeBtns end
    if not btns then return end
    local size = OneWoW_Bags.db and OneWoW_Bags.db.global.iconSize or 3
    for _, btn in ipairs(btns) do
        if btn.sizeIdx == size then
            btn:SetBackdropColor(T("BG_ACTIVE"))
            btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
            btn.text:SetTextColor(T("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(T("BTN_NORMAL"))
            btn:SetBackdropBorderColor(T("BTN_BORDER"))
            btn.text:SetTextColor(T("TEXT_PRIMARY"))
        end
    end
end

function Settings:UpdateSortButtons(btns)
    if not btns then btns = Settings.sortBtns end
    if not btns then return end
    local sortMode = OneWoW_Bags.db and OneWoW_Bags.db.global.categorySort or "priority"
    for _, btn in ipairs(btns) do
        if btn.sortMode == sortMode then
            btn:SetBackdropColor(T("BG_ACTIVE"))
            btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
            btn.text:SetTextColor(T("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(T("BTN_NORMAL"))
            btn:SetBackdropBorderColor(T("BTN_BORDER"))
            btn.text:SetTextColor(T("TEXT_PRIMARY"))
        end
    end
end

function Settings:Toggle()
    if not settingsFrame then return end
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
    end
end

function Settings:Hide()
    if settingsFrame then settingsFrame:Hide() end
end

function Settings:IsShown()
    return settingsFrame and settingsFrame:IsShown()
end

function Settings:Reset()
    if settingsFrame then
        settingsFrame:Hide()
    end
    settingsFrame = nil
    isCreated = false
end
