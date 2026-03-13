local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_GUI.Constants
local DEFAULT_THEME_KEY = Constants.DEFAULT_THEME_KEY
local DEFAULT_THEME_NAME = Constants.DEFAULT_THEME_NAME
local CreateFrame = CreateFrame
local unpack = unpack

OneWoW_GUI._settingsDB = nil
local callbacks = {}

function OneWoW_GUI:RegisterSettingsCallback(event, owner, func)
    if not callbacks[event] then callbacks[event] = {} end
    table.insert(callbacks[event], { owner = owner, func = func })
end

local function FireCallbacks(event, value)
    if not callbacks[event] then return end
    for _, cb in ipairs(callbacks[event]) do
        cb.func(cb.owner, value)
    end
end

local function InitSettingsDB()
    if not OneWoW_GUI_DB then
        OneWoW_GUI_DB = {}
    end
    local db = OneWoW_GUI_DB
    if not db.language then db.language = GetLocale() end
    if not db.theme then db.theme = DEFAULT_THEME_KEY end
    if not db.font then db.font = "default" end
    if not db.minimap then db.minimap = {} end
    if db.minimap.hide == nil then db.minimap.hide = false end
    if db.minimap.theme == nil then db.minimap.theme = "horde" end
    OneWoW_GUI._settingsDB = db
end

function OneWoW_GUI:GetSetting(key)
    local db = self._settingsDB
    if not db then return nil end
    if key == "theme" then return db.theme
    elseif key == "language" then return db.language
    elseif key == "font" then return db.font
    elseif key == "minimap.hide" then return db.minimap and db.minimap.hide
    elseif key == "minimap.theme" then return db.minimap and db.minimap.theme
    end
end

function OneWoW_GUI:SetSetting(key, value)
    local db = self._settingsDB
    if not db then return end
    if key == "theme" then
        db.theme = value
        self:ApplyTheme()
        FireCallbacks("OnThemeChanged", value)
    elseif key == "language" then
        db.language = value
        FireCallbacks("OnLanguageChanged", value)
    elseif key == "font" then
        db.font = value
        FireCallbacks("OnFontChanged", value)
    elseif key == "minimap.hide" then
        if not db.minimap then db.minimap = {} end
        db.minimap.hide = value
        FireCallbacks("OnMinimapChanged", value)
    elseif key == "minimap.theme" then
        if not db.minimap then db.minimap = {} end
        db.minimap.theme = value
        FireCallbacks("OnIconThemeChanged", value)
    end
end

function OneWoW_GUI:MigrateSettings(sourceGlobal)
    local db = self._settingsDB
    if not db or not sourceGlobal then return end
    if db._migrated then return end
    db._migrated = true
    if sourceGlobal.theme and sourceGlobal.theme ~= DEFAULT_THEME_KEY then
        db.theme = sourceGlobal.theme
    end
    if sourceGlobal.language then
        db.language = sourceGlobal.language
    end
    if sourceGlobal.font then
        db.font = sourceGlobal.font
    end
    if sourceGlobal.minimap then
        if sourceGlobal.minimap.hide ~= nil then db.minimap.hide = sourceGlobal.minimap.hide end
        if sourceGlobal.minimap.theme then db.minimap.theme = sourceGlobal.minimap.theme end
    end
end

local LANGUAGES = {
    { key = "enUS", label = "English" },
    { key = "esES", label = "Español" },
    { key = "koKR", label = "\237\149\156\234\181\173\236\150\180" },
    { key = "frFR", label = "Français" },
    { key = "ruRU", label = "\208\160\209\131\209\129\209\129\208\186\208\184\208\185" },
    { key = "deDE", label = "Deutsch" },
}

local LANG_LOOKUP = {}
for _, lang in ipairs(LANGUAGES) do
    LANG_LOOKUP[lang.key] = lang.label
end

local ICON_THEMES = {
    { key = "horde",    label = "Horde" },
    { key = "alliance", label = "Alliance" },
    { key = "neutral",  label = "Neutral" },
}

local ICON_LOOKUP = {}
for _, icon in ipairs(ICON_THEMES) do
    ICON_LOOKUP[icon.key] = icon.label
end

local THEMES_ORDER = Constants.THEMES_ORDER
local THEMES = Constants.THEMES

local MEDIA_BASE = Constants.MEDIA_BASE
local FONT_BASE = Constants.FONT_BASE

local FONTS = {
    { key = "default",              label = "WoW Default",          file = nil },
    { key = "actionman",            label = "Action Man",           file = FONT_BASE .. "ActionMan.ttf" },
    { key = "adventure",            label = "Adventure",            file = FONT_BASE .. "Adventure.ttf" },
    { key = "bazooka",              label = "Bazooka",              file = FONT_BASE .. "Bazooka.ttf" },
    { key = "blackchancery",        label = "Black Chancery",       file = FONT_BASE .. "BlackChancery.ttf" },
    { key = "celestia",             label = "Celestia Medium Redux", file = FONT_BASE .. "CelestiaMediumRedux1.55.ttf" },
    { key = "continuum",            label = "Continuum Medium",     file = FONT_BASE .. "ContinuumMedium.ttf" },
    { key = "dejavusans",           label = "DejaVu Sans",          file = FONT_BASE .. "DejaVuLGCSans.ttf" },
    { key = "dejavuserif",          label = "DejaVu Serif",         file = FONT_BASE .. "DejaVuLGCSerif.ttf" },
    { key = "diedidie",             label = "DieDieDie",            file = FONT_BASE .. "DieDieDie.ttf" },
    { key = "dorispp",              label = "DorisPP",              file = FONT_BASE .. "DorisPP.ttf" },
    { key = "enigmatic",            label = "Enigmatic",            file = FONT_BASE .. "EnigmaU_2.TTF" },
    { key = "expressway",           label = "Expressway",           file = FONT_BASE .. "Expressway.ttf" },
    { key = "fitzgerald",           label = "Fitzgerald",           file = FONT_BASE .. "Fitzgerald.ttf" },
    { key = "gentiumplus",          label = "Gentium Plus",         file = FONT_BASE .. "GentiumPlus-Regular.ttf" },
    { key = "hack",                 label = "Hack",                 file = FONT_BASE .. "Hack-Regular.ttf" },
    { key = "homespun",             label = "Homespun",             file = FONT_BASE .. "Homespun.ttf" },
    { key = "hookedup",             label = "All Hooked Up",        file = FONT_BASE .. "HookedUp.ttf" },
    { key = "liberationmono",       label = "Liberation Mono",      file = FONT_BASE .. "LiberationMono-Regular.ttf" },
    { key = "liberationsans",       label = "Liberation Sans",      file = FONT_BASE .. "LiberationSans-Regular.ttf" },
    { key = "liberationserif",      label = "Liberation Serif",     file = FONT_BASE .. "LiberationSerif-Regular.ttf" },
    { key = "ptsansnarrow",         label = "PT Sans Narrow",       file = FONT_BASE .. "PTSansNarrow.ttf" },
    { key = "sfatarian",            label = "SF Atarian System",    file = FONT_BASE .. "SFAtarianSystem.ttf" },
    { key = "sfcovington",          label = "SF Covington",         file = FONT_BASE .. "SFCovington.ttf" },
    { key = "sfmovieposter",        label = "SF Movie Poster",      file = FONT_BASE .. "SFMoviePoster-Bold.ttf" },
    { key = "sfwondercomic",        label = "SF Wonder Comic",      file = FONT_BASE .. "SFWonderComic.ttf" },
    { key = "swfit",                label = "SWF!T",                file = FONT_BASE .. "SWFIT.ttf" },
    { key = "texgyreadventor",      label = "TeX Gyre Adventor",    file = FONT_BASE .. "texgyreadventor-regular.otf" },
    { key = "texgyreadventorbold",  label = "TeX Gyre Adventor Bold", file = FONT_BASE .. "texgyreadventor-bold.otf" },
    { key = "wenquanyi",            label = "WenQuanYi Zen Hei",    file = FONT_BASE .. "wqy-zenhei.ttf" },
    { key = "yellowjacket",         label = "Yellowjacket",         file = FONT_BASE .. "yellow.ttf" },
}

local FONT_LOOKUP = {}
for _, f in ipairs(FONTS) do
    FONT_LOOKUP[f.key] = f
end

local LSM_NAME_TO_KEY = {
    ["Adventure"]              = "adventure",
    ["All Hooked Up"]          = "hookedup",
    ["Bazooka"]                = "bazooka",
    ["Black Chancery"]         = "blackchancery",
    ["Celestia Medium Redux"]  = "celestia",
    ["DejaVu Sans"]            = "dejavusans",
    ["DejaVu Serif"]           = "dejavuserif",
    ["DorisPP"]                = "dorispp",
    ["Enigmatic"]              = "enigmatic",
    ["Fitzgerald"]             = "fitzgerald",
    ["Gentium Plus"]           = "gentiumplus",
    ["Hack"]                   = "hack",
    ["Liberation Mono"]        = "liberationmono",
    ["Liberation Sans"]        = "liberationsans",
    ["Liberation Serif"]       = "liberationserif",
    ["SF Atarian System"]      = "sfatarian",
    ["SF Covington"]           = "sfcovington",
    ["SF Movie Poster"]        = "sfmovieposter",
    ["SF Wonder Comic"]        = "sfwondercomic",
    ["SWF!T"]                  = "swfit",
    ["TeX Gyre Adventor"]      = "texgyreadventor",
    ["TeX Gyre Adventor Bold"] = "texgyreadventorbold",
    ["WenQuanYi Zen Hei"]      = "wenquanyi",
    ["Yellowjacket"]           = "yellowjacket",
    ["Action Man"]             = "actionman",
    ["Expressway"]             = "expressway",
    ["PT Sans Narrow"]         = "ptsansnarrow",
    ["Continuum Medium"]       = "continuum",
    ["Homespun"]               = "homespun",
    ["DieDieDie"]              = "diedidie",
}

function OneWoW_GUI:GetFont()
    local fontKey = self:GetSetting("font") or "default"
    local fontData = FONT_LOOKUP[fontKey]
    if fontData and fontData.file then
        return fontData.file
    end
    return nil
end

function OneWoW_GUI:GetFontList()
    return FONTS
end

function OneWoW_GUI:GetFontByKey(key)
    if not key or key == "default" then return nil end
    local fontData = FONT_LOOKUP[key]
    if fontData and fontData.file then return fontData.file end
    return nil
end

-- Safely apply a font file; falls back to GameFontNormal if the asset is missing.
-- Use this when applying fonts from GetFont/GetFontByKey to avoid errors for missing files.
function OneWoW_GUI:SafeSetFont(fontString, fontPath, size, flags)
    if not fontString then return end
    if not fontPath then
        fontString:SetFontObject(GameFontNormal)
        return
    end
    local ok, success = pcall(fontString.SetFont, fontString, fontPath, size or 12, flags or "")
    if not ok or not success then
        fontString:SetFontObject(GameFontNormal)
    end
end

function OneWoW_GUI:MigrateLSMFontName(lsmName)
    if not lsmName then return nil end
    return LSM_NAME_TO_KEY[lsmName]
end

local ICON_TEXTURES = Constants.ICON_TEXTURES

local panelBackdrop = Constants.BACKDROP_INNER_NO_INSETS

local dropdownBackdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local simpleBackdrop = Constants.BACKDROP_SIMPLE

local function CreateDropdownMenu(parent, items, onSelect)
    local menu = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetBackdrop(dropdownBackdrop)
    menu:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    menu:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    menu:EnableMouse(true)

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
    menu:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -2)

    menu:SetScript("OnShow", function(self)
        local timeOutside = 0
        self:SetScript("OnUpdate", function(self2, elapsed)
            if not MouseIsOver(menu) and not MouseIsOver(parent) then
                timeOutside = timeOutside + elapsed
                if timeOutside > 1.0 then
                    self2:Hide()
                    self2:SetScript("OnUpdate", nil)
                end
            else
                timeOutside = 0
            end
        end)
    end)

    return menu
end

function OneWoW_GUI:CreateSettingsPanel(parent, options)
    options = options or {}
    local yOffset = options.yOffset or -10

    local currentLang = self:GetSetting("language") or "enUS"
    local currentThemeKey = self:GetSetting("theme") or DEFAULT_THEME_KEY
    local currentIconTheme = self:GetSetting("minimap.theme") or "horde"
    local isMinimapHidden = self:GetSetting("minimap.hide")

    local splitContainer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    splitContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    splitContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    splitContainer:SetHeight(165)
    splitContainer:SetBackdrop(panelBackdrop)
    splitContainer:SetBackdropColor(self:GetThemeColor("BG_SECONDARY"))
    splitContainer:SetBackdropBorderColor(self:GetThemeColor("BORDER_SUBTLE"))

    local leftPanel = CreateFrame("Frame", nil, splitContainer)
    leftPanel:SetPoint("TOPLEFT", splitContainer, "TOPLEFT", 0, 0)
    leftPanel:SetPoint("BOTTOMRIGHT", splitContainer, "BOTTOM", 0, 0)

    local vertDivider = splitContainer:CreateTexture(nil, "ARTWORK")
    vertDivider:SetWidth(1)
    vertDivider:SetPoint("TOP", splitContainer, "TOP", 0, -8)
    vertDivider:SetPoint("BOTTOM", splitContainer, "BOTTOM", 0, 8)
    vertDivider:SetColorTexture(self:GetThemeColor("BORDER_SUBTLE"))

    local rightPanel = CreateFrame("Frame", nil, splitContainer)
    rightPanel:SetPoint("TOPLEFT", splitContainer, "TOP", 0, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", splitContainer, "BOTTOMRIGHT", 0, 0)

    local langTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    langTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -12)
    langTitle:SetText("Language Selection")
    langTitle:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local langDesc = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDesc:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -38)
    langDesc:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -15, -38)
    langDesc:SetText("Choose your preferred language.")
    langDesc:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))
    langDesc:SetJustifyH("LEFT")
    langDesc:SetWordWrap(true)

    local currentLangLabel = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentLangLabel:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -90)
    currentLangLabel:SetText("Current: " .. (LANG_LOOKUP[currentLang] or currentLang))
    currentLangLabel:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local langDropdown = CreateFrame("Button", nil, leftPanel, "BackdropTemplate")
    langDropdown:SetSize(190, 30)
    langDropdown:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -115)
    langDropdown:SetBackdrop(dropdownBackdrop)
    langDropdown:SetBackdropColor(self:GetThemeColor("BG_TERTIARY"))
    langDropdown:SetBackdropBorderColor(self:GetThemeColor("BORDER_SUBTLE"))

    local langDropText = langDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDropText:SetPoint("LEFT", 10, 0)
    langDropText:SetText(LANG_LOOKUP[currentLang] or currentLang)
    langDropText:SetTextColor(self:GetThemeColor("TEXT_PRIMARY"))

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
        for _, lang in ipairs(LANGUAGES) do
            table.insert(items, { label = lang.label, value = lang.key })
        end
        langMenu = CreateDropdownMenu(btn, items, function(value)
            OneWoW_GUI:SetSetting("language", value)
        end)
        langMenu:Show()
    end)

    local themeTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    themeTitle:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -12)
    themeTitle:SetText("Color Theme")
    themeTitle:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local themeDesc = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDesc:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -38)
    themeDesc:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -15, -38)
    themeDesc:SetText("Choose your preferred theme.")
    themeDesc:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))
    themeDesc:SetJustifyH("LEFT")
    themeDesc:SetWordWrap(true)

    local currentThemeData = THEMES[currentThemeKey]
    local currentThemeName = currentThemeData and currentThemeData.name or DEFAULT_THEME_NAME

    local currentThemeLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentThemeLabel:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -90)
    currentThemeLabel:SetText("Current: " .. currentThemeName)
    currentThemeLabel:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local themeDropdown = CreateFrame("Button", nil, rightPanel, "BackdropTemplate")
    themeDropdown:SetSize(210, 30)
    themeDropdown:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -115)
    themeDropdown:SetBackdrop(dropdownBackdrop)
    themeDropdown:SetBackdropColor(self:GetThemeColor("BG_TERTIARY"))
    themeDropdown:SetBackdropBorderColor(self:GetThemeColor("BORDER_SUBTLE"))

    local themeColorPreview = themeDropdown:CreateTexture(nil, "OVERLAY")
    themeColorPreview:SetSize(14, 14)
    themeColorPreview:SetPoint("LEFT", themeDropdown, "LEFT", 6, 0)
    if currentThemeData then themeColorPreview:SetColorTexture(unpack(currentThemeData.ACCENT_PRIMARY)) end

    local themeDropText = themeDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDropText:SetPoint("LEFT", themeDropdown, "LEFT", 25, 0)
    themeDropText:SetText(currentThemeName)
    themeDropText:SetTextColor(self:GetThemeColor("TEXT_PRIMARY"))

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

        local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        themeMenuRef = menu
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(240, 318)
        menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop(dropdownBackdrop)
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
        scrollBar:SetBackdrop(simpleBackdrop)
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
                local tbtn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                tbtn:SetSize(230, 26)
                tbtn:SetPoint("TOP", scrollChild, "TOP", 0, -(5 + (i - 1) * 28))
                tbtn:SetBackdrop(simpleBackdrop)
                tbtn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                local dot = tbtn:CreateTexture(nil, "OVERLAY")
                dot:SetSize(14, 14)
                dot:SetPoint("LEFT", tbtn, "LEFT", 8, 0)
                dot:SetColorTexture(unpack(themeData.ACCENT_PRIMARY))
                local txt = tbtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                txt:SetPoint("LEFT", tbtn, "LEFT", 28, 0)
                txt:SetText(themeData.name)
                txt:SetTextColor(0.9, 0.9, 0.9)
                tbtn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) txt:SetTextColor(1, 0.82, 0) end)
                tbtn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) txt:SetTextColor(0.9, 0.9, 0.9) end)
                local capturedKey = themeKey
                tbtn:SetScript("OnClick", function()
                    menu:Hide()
                    OneWoW_GUI:SetSetting("theme", capturedKey)
                end)
            end
        end
        scrollChild:SetHeight(#THEMES_ORDER * 28 + 10)
        local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        scrollBar:SetMinMaxValues(0, maxScroll)
        scrollFrame:SetVerticalScroll(0)
        menu:SetScript("OnShow", function(self)
            local timeOutside = 0
            self:SetScript("OnUpdate", function(self2, elapsed)
                if not MouseIsOver(menu) and not MouseIsOver(btn) then
                    timeOutside = timeOutside + elapsed
                    if timeOutside > 1.0 then self2:Hide() self2:SetScript("OnUpdate", nil) end
                else timeOutside = 0 end
            end)
        end)

        menu:Show()
    end)

    yOffset = yOffset - 185

    local currentFontKey = self:GetSetting("font") or "default"
    local currentFontData = FONT_LOOKUP[currentFontKey]
    local currentFontLabel = currentFontData and currentFontData.label or "WoW Default"

    local fontContainer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    fontContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    fontContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    fontContainer:SetHeight(110)
    fontContainer:SetBackdrop(panelBackdrop)
    fontContainer:SetBackdropColor(self:GetThemeColor("BG_SECONDARY"))
    fontContainer:SetBackdropBorderColor(self:GetThemeColor("BORDER_SUBTLE"))

    local fontTitle = fontContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fontTitle:SetPoint("TOPLEFT", fontContainer, "TOPLEFT", 15, -12)
    fontTitle:SetText("Font")
    fontTitle:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local fontDesc = fontContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontDesc:SetPoint("TOPLEFT", fontContainer, "TOPLEFT", 15, -38)
    fontDesc:SetPoint("RIGHT", fontContainer, "RIGHT", -15, 0)
    fontDesc:SetText("Choose the font used across all OneWoW addons.")
    fontDesc:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))
    fontDesc:SetJustifyH("LEFT")
    fontDesc:SetWordWrap(true)

    local fontPreview = fontContainer:CreateFontString(nil, "OVERLAY")
    fontPreview:SetPoint("TOPRIGHT", fontContainer, "TOPRIGHT", -15, -12)
    OneWoW_GUI:SafeSetFont(fontPreview, currentFontData and currentFontData.file, 14)
    fontPreview:SetText("Preview: AaBbCc 123")
    fontPreview:SetTextColor(self:GetThemeColor("TEXT_PRIMARY"))

    local fontDropdown = CreateFrame("Button", nil, fontContainer, "BackdropTemplate")
    fontDropdown:SetSize(210, 30)
    fontDropdown:SetPoint("TOPLEFT", fontContainer, "TOPLEFT", 15, -65)
    fontDropdown:SetBackdrop(dropdownBackdrop)
    fontDropdown:SetBackdropColor(self:GetThemeColor("BG_TERTIARY"))
    fontDropdown:SetBackdropBorderColor(self:GetThemeColor("BORDER_SUBTLE"))

    local fontDropText = fontDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontDropText:SetPoint("LEFT", 10, 0)
    fontDropText:SetText(currentFontLabel)
    fontDropText:SetTextColor(self:GetThemeColor("TEXT_PRIMARY"))

    local fontArrow = fontDropdown:CreateTexture(nil, "OVERLAY")
    fontArrow:SetSize(16, 16)
    fontArrow:SetPoint("RIGHT", fontDropdown, "RIGHT", -5, 0)
    fontArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    local fontMenuRef = nil
    fontDropdown:SetScript("OnClick", function(btn)
        if fontMenuRef and fontMenuRef:IsShown() then
            fontMenuRef:Hide()
            return
        end

        local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        fontMenuRef = menu
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(260, 318)
        menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop(dropdownBackdrop)
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
        scrollBar:SetBackdrop(simpleBackdrop)
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

        for i, fontInfo in ipairs(FONTS) do
            local fbtn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            fbtn:SetSize(240, 26)
            fbtn:SetPoint("TOP", scrollChild, "TOP", 0, -(2 + (i - 1) * 26))
            fbtn:SetBackdrop(simpleBackdrop)
            fbtn:SetBackdropColor(0, 0, 0, 0)

            fbtn.text = fbtn:CreateFontString(nil, "OVERLAY")
            fbtn.text:SetPoint("LEFT", 8, 0)
            OneWoW_GUI:SafeSetFont(fbtn.text, fontInfo.file, 13)
            fbtn.text:SetText(fontInfo.label)
            fbtn.text:SetTextColor(0.9, 0.9, 0.9)

            fbtn:SetScript("OnEnter", function(s)
                s:SetBackdropColor(0.2, 0.2, 0.2, 1)
                fbtn.text:SetTextColor(1, 0.82, 0)
            end)
            fbtn:SetScript("OnLeave", function(s)
                s:SetBackdropColor(0, 0, 0, 0)
                fbtn.text:SetTextColor(0.9, 0.9, 0.9)
            end)

            local capturedKey = fontInfo.key
            local capturedLabel = fontInfo.label
            local capturedFile = fontInfo.file
            fbtn:SetScript("OnClick", function()
                menu:Hide()
                fontDropText:SetText(capturedLabel)
                OneWoW_GUI:SafeSetFont(fontPreview, capturedFile, 14)
                fontPreview:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                OneWoW_GUI:SetSetting("font", capturedKey)
            end)
        end

        scrollChild:SetHeight(#FONTS * 26 + 4)
        local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        scrollBar:SetMinMaxValues(0, maxScroll)
        scrollFrame:SetVerticalScroll(0)

        menu:SetScript("OnShow", function(self)
            local timeOutside = 0
            self:SetScript("OnUpdate", function(self2, elapsed)
                if not MouseIsOver(menu) and not MouseIsOver(btn) then
                    timeOutside = timeOutside + elapsed
                    if timeOutside > 1.0 then self2:Hide() self2:SetScript("OnUpdate", nil) end
                else timeOutside = 0 end
            end)
        end)

        menu:Show()
    end)

    yOffset = yOffset - 125

    local minimapContainer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    minimapContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    minimapContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    minimapContainer:SetHeight(165)
    minimapContainer:SetBackdrop(panelBackdrop)
    minimapContainer:SetBackdropColor(self:GetThemeColor("BG_SECONDARY"))
    minimapContainer:SetBackdropBorderColor(self:GetThemeColor("BORDER_SUBTLE"))

    local mmLeftPanel = CreateFrame("Frame", nil, minimapContainer)
    mmLeftPanel:SetPoint("TOPLEFT", minimapContainer, "TOPLEFT", 0, 0)
    mmLeftPanel:SetPoint("BOTTOMRIGHT", minimapContainer, "BOTTOM", 0, 0)

    local mmVertDiv = minimapContainer:CreateTexture(nil, "ARTWORK")
    mmVertDiv:SetWidth(1)
    mmVertDiv:SetPoint("TOP", minimapContainer, "TOP", 0, -8)
    mmVertDiv:SetPoint("BOTTOM", minimapContainer, "BOTTOM", 0, 8)
    mmVertDiv:SetColorTexture(self:GetThemeColor("BORDER_SUBTLE"))

    local mmRightPanel = CreateFrame("Frame", nil, minimapContainer)
    mmRightPanel:SetPoint("TOPLEFT", minimapContainer, "TOP", 0, 0)
    mmRightPanel:SetPoint("BOTTOMRIGHT", minimapContainer, "BOTTOMRIGHT", 0, 0)

    local mmTitle = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mmTitle:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -12)
    mmTitle:SetText("Minimap Button")
    mmTitle:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local mmDesc = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmDesc:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -38)
    mmDesc:SetPoint("TOPRIGHT", mmLeftPanel, "TOPRIGHT", -15, -38)
    mmDesc:SetText("Show or hide the minimap button.")
    mmDesc:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))
    mmDesc:SetJustifyH("LEFT")
    mmDesc:SetWordWrap(true)

    local mmCheckbox = self:CreateCheckbox(mmLeftPanel, { label = "Show Minimap Button" })
    mmCheckbox:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 12, -80)
    mmCheckbox:SetChecked(not isMinimapHidden)
    mmCheckbox:SetScript("OnClick", function(cb)
        OneWoW_GUI:SetSetting("minimap.hide", not cb:GetChecked())
    end)

    local mmIconTitle = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mmIconTitle:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -12)
    mmIconTitle:SetText("Icon Theme")
    mmIconTitle:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local mmIconDesc = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmIconDesc:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -38)
    mmIconDesc:SetPoint("TOPRIGHT", mmRightPanel, "TOPRIGHT", -15, -38)
    mmIconDesc:SetText("Choose your faction icon.")
    mmIconDesc:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))
    mmIconDesc:SetJustifyH("LEFT")
    mmIconDesc:SetWordWrap(true)

    local mmCurrentLabel = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmCurrentLabel:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -90)
    mmCurrentLabel:SetText("Current: " .. (ICON_LOOKUP[currentIconTheme] or "Horde"))
    mmCurrentLabel:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local iconDropdown = CreateFrame("Button", nil, mmRightPanel, "BackdropTemplate")
    iconDropdown:SetSize(190, 30)
    iconDropdown:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -115)
    iconDropdown:SetBackdrop(dropdownBackdrop)
    iconDropdown:SetBackdropColor(self:GetThemeColor("BG_TERTIARY"))
    iconDropdown:SetBackdropBorderColor(self:GetThemeColor("BORDER_SUBTLE"))

    local iconDropIcon = iconDropdown:CreateTexture(nil, "OVERLAY")
    iconDropIcon:SetSize(18, 18)
    iconDropIcon:SetPoint("LEFT", iconDropdown, "LEFT", 6, 0)
    iconDropIcon:SetTexture(ICON_TEXTURES[currentIconTheme] or ICON_TEXTURES.horde)

    local iconDropText = iconDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconDropText:SetPoint("LEFT", iconDropIcon, "RIGHT", 4, 0)
    iconDropText:SetText(ICON_LOOKUP[currentIconTheme] or "Horde")
    iconDropText:SetTextColor(self:GetThemeColor("TEXT_PRIMARY"))

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
            table.insert(items, { label = ic.label, value = ic.key, icon = ICON_TEXTURES[ic.key] })
        end
        iconMenu = CreateDropdownMenu(btn, items, function(value)
            OneWoW_GUI:SetSetting("minimap.theme", value)
        end)
        iconMenu:Show()
    end)

    yOffset = yOffset - 185

    return yOffset
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == "OneWoW_GUI" then
        InitSettingsDB()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
