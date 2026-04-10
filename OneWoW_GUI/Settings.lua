local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_GUI.Constants
local DEFAULT_THEME_ICON = Constants.DEFAULT_THEME_ICON
local DEFAULT_THEME_KEY = Constants.DEFAULT_THEME_KEY
local DEFAULT_THEME_NAME = Constants.DEFAULT_THEME_NAME
local CreateFrame = CreateFrame
local unpack = unpack

OneWoW_GUI._settingsDB = nil
local callbacks = {}

function OneWoW_GUI:RegisterSettingsCallback(event, owner, func)
    if not callbacks[event] then callbacks[event] = {} end
    tinsert(callbacks[event], { owner = owner, func = func })
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
    if db.fontSizeOffset == nil then db.fontSizeOffset = 0 end
    if not db.minimap then db.minimap = {} end
    if db.minimap.hide == nil then db.minimap.hide = false end
    if db.minimap.theme == nil then db.minimap.theme = DEFAULT_THEME_ICON end
    if not db.minimapLaunchers then db.minimapLaunchers = {} end
    if not db.moneyDisplay then db.moneyDisplay = {} end
    if db.moneyDisplay.useLetters == nil then db.moneyDisplay.useLetters = false end
    if db.moneyDisplay.useRegionalNumbers == nil then db.moneyDisplay.useRegionalNumbers = true end
    if db.moneyDisplay.useWhiteValues == nil then db.moneyDisplay.useWhiteValues = true end
    OneWoW_GUI._settingsDB = db
    OneWoW_GUI:ApplyTheme()
end

function OneWoW_GUI:GetSetting(key)
    local db = self._settingsDB
    if not db then return nil end
    if key == "theme" then return db.theme
    elseif key == "language" then return db.language
    elseif key == "font" then return db.font
    elseif key == "fontSizeOffset" then return db.fontSizeOffset
    elseif key == "minimap.hide" then return db.minimap and db.minimap.hide
    elseif key == "minimap.theme" then return db.minimap and db.minimap.theme
    elseif key == "moneyDisplay.useLetters" then
        if not db.moneyDisplay then return false end
        return db.moneyDisplay.useLetters == true
    elseif key == "moneyDisplay.useRegionalNumbers" then
        if not db.moneyDisplay then return true end
        return db.moneyDisplay.useRegionalNumbers ~= false
    elseif key == "moneyDisplay.useWhiteValues" then
        if not db.moneyDisplay then return true end
        return db.moneyDisplay.useWhiteValues ~= false
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
    elseif key == "fontSizeOffset" then
        db.fontSizeOffset = value
        FireCallbacks("OnFontSizeChanged", value)
        FireCallbacks("OnFontChanged", db.font)
    elseif key == "minimap.hide" then
        if not db.minimap then db.minimap = {} end
        db.minimap.hide = value
        FireCallbacks("OnMinimapChanged", value)
    elseif key == "minimap.theme" then
        if not db.minimap then db.minimap = {} end
        db.minimap.theme = value
        FireCallbacks("OnIconThemeChanged", value)
    elseif key == "moneyDisplay.useLetters" then
        if not db.moneyDisplay then db.moneyDisplay = {} end
        db.moneyDisplay.useLetters = value and true or false
        FireCallbacks("OnMoneyDisplayChanged", value)
    elseif key == "moneyDisplay.useRegionalNumbers" then
        if not db.moneyDisplay then db.moneyDisplay = {} end
        db.moneyDisplay.useRegionalNumbers = value and true or false
        FireCallbacks("OnMoneyDisplayChanged", value)
    elseif key == "moneyDisplay.useWhiteValues" then
        if not db.moneyDisplay then db.moneyDisplay = {} end
        db.moneyDisplay.useWhiteValues = value and true or false
        FireCallbacks("OnMoneyDisplayChanged", value)
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
    if sourceGlobal.fontSizeOffset ~= nil then
        db.fontSizeOffset = sourceGlobal.fontSizeOffset
    end
    if sourceGlobal.minimap then
        if sourceGlobal.minimap.hide ~= nil then db.minimap.hide = sourceGlobal.minimap.hide end
        if sourceGlobal.minimap.theme then db.minimap.theme = sourceGlobal.minimap.theme end
    end
    if sourceGlobal.moneyDisplay then
        if not db.moneyDisplay then db.moneyDisplay = {} end
        if sourceGlobal.moneyDisplay.useLetters ~= nil then db.moneyDisplay.useLetters = sourceGlobal.moneyDisplay.useLetters end
        if sourceGlobal.moneyDisplay.useRegionalNumbers ~= nil then db.moneyDisplay.useRegionalNumbers = sourceGlobal.moneyDisplay.useRegionalNumbers end
        if sourceGlobal.moneyDisplay.useWhiteValues ~= nil then db.moneyDisplay.useWhiteValues = sourceGlobal.moneyDisplay.useWhiteValues end
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

local THEMES = Constants.THEMES
local THEME_SPECIAL_OPTIONS = Constants.THEME_SPECIAL_OPTIONS
local THEME_MENU_GROUPS = Constants.THEME_MENU_GROUPS
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

function OneWoW_GUI:GetFontSizeOffset()
    return self._settingsDB and self._settingsDB.fontSizeOffset or 0
end

-- Safely apply a font file; falls back to GameFontNormal if the asset is missing.
-- Use this when applying fonts from GetFont/GetFontByKey to avoid errors for missing files.
function OneWoW_GUI:SafeSetFont(fontString, fontPath, size, flags)
    if not fontString then return end
    local offset = self._settingsDB and self._settingsDB.fontSizeOffset or 0
    if not fontPath then
        if offset ~= 0 and size then
            local defaultPath = GameFontNormal:GetFont()
            local adjustedSize = math.max(6, (size or 12) + offset)
            local ok, success = pcall(fontString.SetFont, fontString, defaultPath, adjustedSize, flags or "")
            if not ok or not success then
                fontString:SetFontObject(GameFontNormal)
            end
        else
            fontString:SetFontObject(GameFontNormal)
        end
        return
    end
    local adjustedSize = math.max(6, (size or 12) + offset)
    local ok, success = pcall(fontString.SetFont, fontString, fontPath, adjustedSize, flags or "")
    if not ok or not success then
        fontString:SetFontObject(GameFontNormal)
    end
end

function OneWoW_GUI:CreateFS(parent, size, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    self:SafeSetFont(fs, self:GetFont(), size or 12)
    return fs
end

function OneWoW_GUI:ApplyFont(fs, size)
    if not fs then return end
    if size then
        fs._owBaseSize = size
    elseif not fs._owBaseSize and fs.GetFont then
        local _, currentSize = fs:GetFont()
        fs._owBaseSize = currentSize or 13
    end
    self:SafeSetFont(fs, self:GetFont(), fs._owBaseSize or 13)
end

function OneWoW_GUI:ApplyFontCapped(fs, size, maxOffset)
    if not fs then return end
    fs._owBaseSize = size
    fs._owMaxOffset = maxOffset
    local fontPath = self:GetFont()
    local offset = self:GetFontSizeOffset() or 0
    local cappedSize = math.max(6, size + math.min(offset, maxOffset))
    if fontPath then
        local ok = pcall(fs.SetFont, fs, fontPath, cappedSize, "")
        if not ok then fs:SetFontObject(GameFontNormal) end
    else
        fs:SetFontObject(GameFontNormal)
    end
end

function OneWoW_GUI:ApplyFontToFrame(frame)
    if not frame then return end
    local fontPath = self:GetFont()
    for _, region in ipairs({frame:GetRegions()}) do
        if region.GetFont and region.SetFont then
            if not region._owBaseSize then
                local _, sz = region:GetFont()
                if sz and sz > 0 then
                    region._owBaseSize = sz
                end
            end
            if region._owBaseSize then
                if region._owMaxOffset then
                    self:ApplyFontCapped(region, region._owBaseSize, region._owMaxOffset)
                else
                    self:SafeSetFont(region, fontPath, region._owBaseSize)
                end
            end
        end
    end
    for _, child in ipairs({frame:GetChildren()}) do
        if child:GetObjectType() == "EditBox" and child.GetFont then
            if not child._owBaseSize then
                local _, sz = child:GetFont()
                if sz and sz > 0 then
                    child._owBaseSize = sz
                end
            end
            if child._owBaseSize then
                local _, _, flags = child:GetFont()
                self:SafeSetFont(child, fontPath, child._owBaseSize, flags)
            end
        end
        if child.GetObjectType and child:GetObjectType() == "ScrollFrame" and child.GetScrollChild then
            local scrollChild = child:GetScrollChild()
            if scrollChild then
                self:ApplyFontToFrame(scrollChild)
            end
        end
        self:ApplyFontToFrame(child)
    end
end

function OneWoW_GUI:MigrateLSMFontName(lsmName)
    if not lsmName then return nil end
    return LSM_NAME_TO_KEY[lsmName]
end

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

function OneWoW_GUI:CreateSettingsPanel(parent, options)
    options = options or {}
    local yOffset = options.yOffset or -10

    local currentLang = self:GetSetting("language") or "enUS"
    local currentIconTheme = self:GetSetting("minimap.theme") or DEFAULT_THEME_ICON
    local currentFontKey = self:GetSetting("font") or "default"
    local currentFontData = FONT_LOOKUP[currentFontKey]
    local currentFontLabel = currentFontData and currentFontData.label or "WoW Default"
    local currentOffset = self:GetSetting("fontSizeOffset") or 0

    local settingsAddonName = options.addonName
    local isPerAddonMinimap = not _G.OneWoW and settingsAddonName
    local isMinimapHidden
    if isPerAddonMinimap then
        local launcherDB = self._settingsDB and self._settingsDB.minimapLaunchers
        isMinimapHidden = launcherDB and launcherDB[settingsAddonName] and launcherDB[settingsAddonName].hide
    else
        isMinimapHidden = self:GetSetting("minimap.hide")
    end

    local function CreateSplitRow(height)
        height = height or 165
        local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        container:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
        container:SetHeight(height)
        container:SetBackdrop(panelBackdrop)
        container:SetBackdropColor(self:GetThemeColor("BG_SECONDARY"))
        container:SetBackdropBorderColor(self:GetThemeColor("BORDER_SUBTLE"))

        local lp = CreateFrame("Frame", nil, container)
        lp:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        lp:SetPoint("BOTTOMRIGHT", container, "BOTTOM", 0, 0)

        local div = container:CreateTexture(nil, "ARTWORK")
        div:SetWidth(1)
        div:SetPoint("TOP", container, "TOP", 0, -8)
        div:SetPoint("BOTTOM", container, "BOTTOM", 0, 8)
        div:SetColorTexture(self:GetThemeColor("BORDER_SUBTLE"))

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
    langTitle:SetText("Language Selection")
    langTitle:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local langDesc = langPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDesc:SetPoint("TOPLEFT", langPanel, "TOPLEFT", 15, -38)
    langDesc:SetPoint("TOPRIGHT", langPanel, "TOPRIGHT", -15, -38)
    langDesc:SetText("Choose your preferred language.")
    langDesc:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))
    langDesc:SetJustifyH("LEFT")
    langDesc:SetWordWrap(true)

    local currentLangLabel = langPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentLangLabel:SetPoint("TOPLEFT", langPanel, "TOPLEFT", 15, -90)
    currentLangLabel:SetText("Current: " .. (LANG_LOOKUP[currentLang] or currentLang))
    currentLangLabel:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local langDropdown = CreateFrame("Button", nil, langPanel, "BackdropTemplate")
    langDropdown:SetSize(190, 30)
    langDropdown:SetPoint("TOPLEFT", langPanel, "TOPLEFT", 15, -115)
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
            tinsert(items, { label = lang.label, value = lang.key })
        end
        langMenu = CreateDropdownMenu(btn, items, function(value)
            OneWoW_GUI:SetSetting("language", value)
        end)
        langMenu:Show()
    end)

    local themeTitle = themePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    themeTitle:SetPoint("TOPLEFT", themePanel, "TOPLEFT", 15, -12)
    themeTitle:SetText("Color Theme")
    themeTitle:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local themeDesc = themePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDesc:SetPoint("TOPLEFT", themePanel, "TOPLEFT", 15, -38)
    themeDesc:SetPoint("TOPRIGHT", themePanel, "TOPRIGHT", -15, -38)
    themeDesc:SetText("Themes are grouped below. Random picks one palette each reload; reopen the menu and choose Random again to reroll this session.")
    themeDesc:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))
    themeDesc:SetJustifyH("LEFT")
    themeDesc:SetWordWrap(true)

    self:ApplyTheme()
    local currentThemeName = self:GetThemeDisplayName()
    local effThemeKey = self:GetEffectiveThemeKey()
    local currentThemeData = THEMES[effThemeKey]

    local currentThemeLabel = themePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentThemeLabel:SetPoint("TOPLEFT", themePanel, "TOPLEFT", 15, -90)
    currentThemeLabel:SetText("Current: " .. currentThemeName)
    currentThemeLabel:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local themeDropdown = CreateFrame("Button", nil, themePanel, "BackdropTemplate")
    themeDropdown:SetSize(210, 30)
    themeDropdown:SetPoint("TOPLEFT", themePanel, "TOPLEFT", 15, -115)
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
    local themeOverlayRef = nil
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
        themeOverlayRef = overlay

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

        local function addThemePickRow(capturedKey, label, dotR, dotG, dotB)
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
                currentThemeLabel:SetText("Current: " .. OneWoW_GUI:GetThemeDisplayName())
                themeDropText:SetText(OneWoW_GUI:GetThemeDisplayName())
                local eff = OneWoW_GUI:GetEffectiveThemeKey()
                local td = THEMES[eff]
                if td then
                    themeColorPreview:SetColorTexture(unpack(td.ACCENT_PRIMARY))
                end
            end)
            y = y - rowH - 2
        end

        addSectionHeader("Special")
        for _, opt in ipairs(THEME_SPECIAL_OPTIONS or {}) do
            addThemePickRow(opt.key, opt.label, 0.55, 0.45, 0.95)
        end
        for _, group in ipairs(THEME_MENU_GROUPS or {}) do
            addSectionHeader(group.title)
            for _, themeKey in ipairs(group.keys) do
                local themeData = THEMES[themeKey]
                if themeData then
                    local ap = themeData.ACCENT_PRIMARY
                    addThemePickRow(themeKey, themeData.name, ap[1], ap[2], ap[3])
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
    fontTitle:SetText("Font")
    fontTitle:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local fontDesc = fontPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontDesc:SetPoint("TOPLEFT", fontPanel, "TOPLEFT", 15, -38)
    fontDesc:SetPoint("TOPRIGHT", fontPanel, "TOPRIGHT", -15, -38)
    fontDesc:SetText("Choose the font used across all OneWoW addons.")
    fontDesc:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))
    fontDesc:SetJustifyH("LEFT")
    fontDesc:SetWordWrap(true)

    local fontCurrentLabel = fontPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontCurrentLabel:SetPoint("TOPLEFT", fontPanel, "TOPLEFT", 15, -90)
    fontCurrentLabel:SetText("Current: " .. currentFontLabel)
    fontCurrentLabel:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local fontDropdown = CreateFrame("Button", nil, fontPanel, "BackdropTemplate")
    fontDropdown:SetSize(210, 30)
    fontDropdown:SetPoint("TOPLEFT", fontPanel, "TOPLEFT", 15, -115)
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

    local fsTitle = fontSizePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fsTitle:SetPoint("TOPLEFT", fontSizePanel, "TOPLEFT", 15, -12)
    fsTitle:SetText("Font Size")
    fsTitle:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local fontPreview = fontSizePanel:CreateFontString(nil, "OVERLAY")
    fontPreview:SetPoint("TOPRIGHT", fontSizePanel, "TOPRIGHT", -15, -12)
    OneWoW_GUI:SafeSetFont(fontPreview, currentFontData and currentFontData.file, 14)
    fontPreview:SetText("AaBbCc 123")
    fontPreview:SetTextColor(self:GetThemeColor("TEXT_PRIMARY"))

    local fsDesc = fontSizePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fsDesc:SetPoint("TOPLEFT", fontSizePanel, "TOPLEFT", 15, -38)
    fsDesc:SetPoint("TOPRIGHT", fontSizePanel, "TOPRIGHT", -15, -38)
    fsDesc:SetText("Adjust font size across all addons.")
    fsDesc:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))
    fsDesc:SetJustifyH("LEFT")
    fsDesc:SetWordWrap(true)

    local fsWarning = fontSizePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fsWarning:SetPoint("TOPLEFT", fsDesc, "BOTTOMLEFT", 0, -6)
    fsWarning:SetPoint("TOPRIGHT", fsDesc, "BOTTOMRIGHT", 0, -6)
    fsWarning:SetText("EXPERIMENTAL: Not all OneWoW addons are compatible or adapted for font size adjustments yet.")
    fsWarning:SetTextColor(1.0, 0.4, 0.1)
    fsWarning:SetJustifyH("LEFT")
    fsWarning:SetWordWrap(true)

    local function FormatOffset(v)
        if v > 0 then return "+" .. v
        elseif v == 0 then return "0"
        else return tostring(v) end
    end

    local fsCurrentLabel = fontSizePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fsCurrentLabel:SetPoint("TOPLEFT", fsWarning, "BOTTOMLEFT", 0, -10)
    fsCurrentLabel:SetText("Current: " .. FormatOffset(currentOffset))
    fsCurrentLabel:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local stepperMinusBtn = CreateFrame("Button", nil, fontSizePanel, "BackdropTemplate")
    stepperMinusBtn:SetSize(28, 28)
    stepperMinusBtn:SetPoint("TOPLEFT", fsCurrentLabel, "BOTTOMLEFT", 0, -6)
    stepperMinusBtn:SetBackdrop(dropdownBackdrop)
    stepperMinusBtn:SetBackdropColor(self:GetThemeColor("BTN_NORMAL"))
    stepperMinusBtn:SetBackdropBorderColor(self:GetThemeColor("BTN_BORDER"))
    stepperMinusBtn:RegisterForClicks("AnyDown", "AnyUp")

    local minusText = stepperMinusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minusText:SetPoint("CENTER")
    minusText:SetText("-")
    minusText:SetTextColor(self:GetThemeColor("TEXT_PRIMARY"))

    local stepperPlusBtn = CreateFrame("Button", nil, fontSizePanel, "BackdropTemplate")
    stepperPlusBtn:SetSize(28, 28)
    stepperPlusBtn:SetPoint("LEFT", stepperMinusBtn, "RIGHT", 44, 0)
    stepperPlusBtn:SetBackdrop(dropdownBackdrop)
    stepperPlusBtn:SetBackdropColor(self:GetThemeColor("BTN_NORMAL"))
    stepperPlusBtn:SetBackdropBorderColor(self:GetThemeColor("BTN_BORDER"))
    stepperPlusBtn:RegisterForClicks("AnyDown", "AnyUp")

    local plusText = stepperPlusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    plusText:SetPoint("CENTER")
    plusText:SetText("+")
    plusText:SetTextColor(self:GetThemeColor("TEXT_PRIMARY"))

    local stepperValueText = fontSizePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    stepperValueText:SetPoint("LEFT", stepperMinusBtn, "RIGHT", 6, 0)
    stepperValueText:SetPoint("RIGHT", stepperPlusBtn, "LEFT", -6, 0)
    stepperValueText:SetJustifyH("CENTER")
    stepperValueText:SetText(FormatOffset(currentOffset))
    stepperValueText:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local function UpdateStepperState(val)
        stepperValueText:SetText(FormatOffset(val))
        fsCurrentLabel:SetText("Current: " .. FormatOffset(val))
        if val <= -3 then
            stepperMinusBtn:Disable()
            minusText:SetTextColor(self:GetThemeColor("TEXT_MUTED"))
        else
            stepperMinusBtn:Enable()
            minusText:SetTextColor(self:GetThemeColor("TEXT_PRIMARY"))
        end
        if val >= 5 then
            stepperPlusBtn:Disable()
            plusText:SetTextColor(self:GetThemeColor("TEXT_MUTED"))
        else
            stepperPlusBtn:Enable()
            plusText:SetTextColor(self:GetThemeColor("TEXT_PRIMARY"))
        end
        local curFontData = FONT_LOOKUP[OneWoW_GUI:GetSetting("font") or "default"]
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

    local fontMenuRef = nil
    local fontOverlayRef = nil
    fontDropdown:SetScript("OnClick", function(btn)
        if fontMenuRef and fontMenuRef:IsShown() then
            fontMenuRef:Hide()
            return
        end

        local maxMenuHeight = 400
        local rowH = 26

        local overlay = CreateFrame("Button", nil, UIParent)
        overlay:SetAllPoints(UIParent)
        overlay:SetFrameStrata("FULLSCREEN_DIALOG")
        overlay:SetFrameLevel(0)
        overlay:EnableMouse(true)
        overlay:RegisterForClicks("AnyDown", "AnyUp")
        fontOverlayRef = overlay

        local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        fontMenuRef = menu
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

        local y = -2
        for _, fontInfo in ipairs(FONTS) do
            local fbtn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            fbtn:SetHeight(rowH)
            fbtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, y)
            fbtn:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -2, y)
            fbtn:SetBackdrop(simpleBackdrop)
            fbtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

            fbtn.text = fbtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fbtn.text:SetPoint("LEFT", 8, 0)
            OneWoW_GUI:SafeSetFont(fbtn.text, fontInfo.file, 13)
            fbtn.text:SetText(fontInfo.label)
            fbtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            fbtn:SetScript("OnEnter", function(s)
                s:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                fbtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end)
            fbtn:SetScript("OnLeave", function(s)
                s:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                fbtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end)

            local capturedKey = fontInfo.key
            local capturedLabel = fontInfo.label
            local capturedFile = fontInfo.file
            fbtn:SetScript("OnClick", function()
                menu:Hide()
                fontDropText:SetText(capturedLabel)
                fontCurrentLabel:SetText("Current: " .. capturedLabel)
                OneWoW_GUI:SafeSetFont(fontPreview, capturedFile, 14)
                fontPreview:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                OneWoW_GUI:SetSetting("font", capturedKey)
            end)
            y = y - rowH - 2
        end

        scrollChild:SetHeight(math.max(1, math.abs(y) + 6))

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
    -- ROW 3: Minimap Button | Icon Theme
    ----------------------------------------------------------------
    local _, mmLeftPanel, mmRightPanel = CreateSplitRow(165)

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
        local show = cb:GetChecked()
        if isPerAddonMinimap then
            local launcher = OneWoW_GUI._launchers and OneWoW_GUI._launchers[settingsAddonName]
            if launcher then launcher:SetShown(show) end
        else
            OneWoW_GUI:SetSetting("minimap.hide", not show)
        end
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
            tinsert(items, { label = ic.label, value = ic.key, icon = ICON_TEXTURES[ic.key] })
        end
        iconMenu = CreateDropdownMenu(btn, items, function(value, label)
            iconDropIcon:SetTexture(ICON_TEXTURES[value] or ICON_TEXTURES.horde)
            iconDropText:SetText(label or ICON_LOOKUP[value] or "Horde")
            mmCurrentLabel:SetText("Current: " .. (label or ICON_LOOKUP[value] or "Horde"))
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
    valuePanel:SetHeight(158)
    valuePanel:SetBackdrop(panelBackdrop)
    valuePanel:SetBackdropColor(self:GetThemeColor("BG_SECONDARY"))
    valuePanel:SetBackdropBorderColor(self:GetThemeColor("BORDER_SUBTLE"))

    local valueTitle = valuePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    valueTitle:SetPoint("TOPLEFT", valuePanel, "TOPLEFT", 15, -12)
    valueTitle:SetText("Value display")
    valueTitle:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local valueDesc = valuePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueDesc:SetPoint("TOPLEFT", valuePanel, "TOPLEFT", 15, -38)
    valueDesc:SetPoint("TOPRIGHT", valuePanel, "TOPRIGHT", -15, -38)
    valueDesc:SetText("How gold and prices are shown across OneWoW (bags, AltTracker, Catalog, tooltips, farm value tracker, etc.).")
    valueDesc:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))
    valueDesc:SetJustifyH("LEFT")
    valueDesc:SetWordWrap(true)

    local lettersChecked = self:GetSetting("moneyDisplay.useLetters") and true or false
    local regionalChecked = self:GetSetting("moneyDisplay.useRegionalNumbers") ~= false
    local whiteValuesChecked = self:GetSetting("moneyDisplay.useWhiteValues") ~= false

    local lettersCb = self:CreateCheckbox(valuePanel, {
        label = "Show letters g, s, c (instead of coin icons)",
    })
    lettersCb:SetPoint("TOPLEFT", valuePanel, "TOPLEFT", 12, -72)
    lettersCb:SetChecked(lettersChecked)
    lettersCb:SetScript("OnClick", function(cb)
        OneWoW_GUI:SetSetting("moneyDisplay.useLetters", cb:GetChecked())
    end)

    local regionalCb = self:CreateCheckbox(valuePanel, {
        label = "Use regional number grouping (client locale)",
    })
    regionalCb:SetPoint("TOPLEFT", lettersCb, "BOTTOMLEFT", 0, -6)
    regionalCb:SetChecked(regionalChecked)
    regionalCb:SetScript("OnClick", function(cb)
        OneWoW_GUI:SetSetting("moneyDisplay.useRegionalNumbers", cb:GetChecked())
    end)

    local whiteValuesCb = self:CreateCheckbox(valuePanel, {
        label = "Use white values (letter mode; classic look when off)",
    })
    whiteValuesCb:SetPoint("TOPLEFT", regionalCb, "BOTTOMLEFT", 0, -6)
    whiteValuesCb:SetChecked(whiteValuesChecked)
    whiteValuesCb:SetScript("OnClick", function(cb)
        OneWoW_GUI:SetSetting("moneyDisplay.useWhiteValues", cb:GetChecked())
    end)

    yOffset = yOffset - 178

    ----------------------------------------------------------------
    -- ROW 5: Discord | Buy Me A Coffee
    ----------------------------------------------------------------
    local _, discordPanel, coffeePanel = CreateSplitRow(120)

    local discordTitle = discordPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    discordTitle:SetPoint("TOPLEFT", discordPanel, "TOPLEFT", 15, -12)
    discordTitle:SetText("Discord")
    discordTitle:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local discordDesc = discordPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    discordDesc:SetPoint("TOPLEFT", discordPanel, "TOPLEFT", 15, -38)
    discordDesc:SetPoint("TOPRIGHT", discordPanel, "TOPRIGHT", -15, -38)
    discordDesc:SetText("Join our community for support and updates.")
    discordDesc:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))
    discordDesc:SetJustifyH("LEFT")
    discordDesc:SetWordWrap(true)

    local discordBox = self:CreateEditBox(discordPanel, { width = 250, height = 24 })
    discordBox:SetPoint("TOPLEFT", discordPanel, "TOPLEFT", 15, -75)
    discordBox:SetText("https://discord.gg/6vnabDVnDu")
    discordBox:SetAutoFocus(false)
    discordBox:SetScript("OnEditFocusGained", function(s) s:HighlightText() end)
    discordBox:SetScript("OnEditFocusLost", function(s)
        s:HighlightText(0, 0)
        s:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    local coffeeTitle = coffeePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    coffeeTitle:SetPoint("TOPLEFT", coffeePanel, "TOPLEFT", 15, -12)
    coffeeTitle:SetText("Buy Me A Coffee")
    coffeeTitle:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local coffeeDesc = coffeePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    coffeeDesc:SetPoint("TOPLEFT", coffeePanel, "TOPLEFT", 15, -38)
    coffeeDesc:SetPoint("TOPRIGHT", coffeePanel, "TOPRIGHT", -15, -38)
    coffeeDesc:SetText("Support OneWoW development.")
    coffeeDesc:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))
    coffeeDesc:SetJustifyH("LEFT")
    coffeeDesc:SetWordWrap(true)

    local coffeeBox = self:CreateEditBox(coffeePanel, { width = 250, height = 24 })
    coffeeBox:SetPoint("TOPLEFT", coffeePanel, "TOPLEFT", 15, -75)
    coffeeBox:SetText("https://buymeacoffee.com/migugin")
    coffeeBox:SetAutoFocus(false)
    coffeeBox:SetScript("OnEditFocusGained", function(s) s:HighlightText() end)
    coffeeBox:SetScript("OnEditFocusLost", function(s)
        s:HighlightText(0, 0)
        s:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    yOffset = yOffset - 140

    local function refreshThemePickerLabels()
        OneWoW_GUI:ApplyTheme()
        local name = OneWoW_GUI:GetThemeDisplayName()
        currentThemeLabel:SetText("Current: " .. name)
        themeDropText:SetText(name)
        local eff = OneWoW_GUI:GetEffectiveThemeKey()
        local td = THEMES[eff]
        if td and themeColorPreview then
            themeColorPreview:SetColorTexture(unpack(td.ACCENT_PRIMARY))
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

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == "OneWoW_GUI" then
        InitSettingsDB()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
