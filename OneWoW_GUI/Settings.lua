local ADDON_NAME, _ = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB
local Constants = OneWoW_GUI.Constants
local DEFAULT_THEME_ICON = Constants.DEFAULT_THEME_ICON
local DEFAULT_THEME_KEY = Constants.DEFAULT_THEME_KEY
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
    local defaults = {
        global = {
            language = GetLocale(),
            theme = DEFAULT_THEME_KEY,
            font = "default",
            fontSizeOffset = 0,
            minimap = {
                hide = false,
                theme = DEFAULT_THEME_ICON,
            },
            minimapLaunchers = {},
            moneyDisplay = {
                useLetters = false,
                useRegionalNumbers = true,
                useWhiteValues = true,
            },
        },
    }

    local sv = _G["OneWoW_GUI_DB"]
    if sv and not sv.global and next(sv) ~= nil then
        local oldData = {}
        for k, v in pairs(sv) do
            oldData[k] = v
        end
        wipe(sv)
        sv.global = oldData
    end

    local db = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_GUI_DB",
        defaults = defaults,
    })

    DB:RunMigrations(db, {
        { version = 1, name = "cleanup_legacy_root_keys", run = function(d)
            local keepRootKeys = {
                global = true,
                chars = true,
                realms = true,
                factions = true,
                classes = true,
                specs = true,
                presets = true,
                _activePreset = true,
            }
            local root = d.root
            if not root then return end
            for key in pairs(root) do
                if not keepRootKeys[key] then
                    root[key] = nil
                end
            end
        end },
    })

    OneWoW_GUI._settingsDBHandle = db
    OneWoW_GUI._settingsDB = db.global
    OneWoW_GUI:ApplyTheme()
end

function OneWoW_GUI:GetSetting(key)
    local db = self._settingsDB

    if key == "theme" then return db.theme
    elseif key == "language" then return db.language
    elseif key == "font" then return db.font
    elseif key == "fontSizeOffset" then return db.fontSizeOffset
    elseif key == "minimap.hide" then return db.minimap.hide
    elseif key == "minimap.theme" then return db.minimap.theme
    elseif key == "moneyDisplay.useLetters" then
        return db.moneyDisplay.useLetters == true
    elseif key == "moneyDisplay.useRegionalNumbers" then
        return db.moneyDisplay.useRegionalNumbers ~= false
    elseif key == "moneyDisplay.useWhiteValues" then
        return db.moneyDisplay.useWhiteValues ~= false
    end
end

function OneWoW_GUI:SetSetting(key, value)
    local db = self._settingsDB

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
        db.moneyDisplay.useLetters = value and true or false
        FireCallbacks("OnMoneyDisplayChanged", value)
    elseif key == "moneyDisplay.useRegionalNumbers" then
        db.moneyDisplay.useRegionalNumbers = value and true or false
        FireCallbacks("OnMoneyDisplayChanged", value)
    elseif key == "moneyDisplay.useWhiteValues" then
        db.moneyDisplay.useWhiteValues = value and true or false
        FireCallbacks("OnMoneyDisplayChanged", value)
    end
end

function OneWoW_GUI:MigrateSettings(sourceGlobal)
    local db = self._settingsDB
    if not sourceGlobal then return end
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
    { key = "default",                label = "WoW Default",          file = nil },
    { key = "actionman",              label = "Action Man",           file = FONT_BASE .. "ActionMan.ttf" },
    { key = "adventure",              label = "Adventure",            file = FONT_BASE .. "Adventure.ttf" },
    { key = "atkinsonhyperlegible",   label = "Atkinson Hyperlegible", file = FONT_BASE .. "AtkinsonHyperlegibleNext-Regular.otf" },
    { key = "bazooka",                label = "Bazooka",              file = FONT_BASE .. "Bazooka.ttf" },
    { key = "blackchancery",          label = "Black Chancery",       file = FONT_BASE .. "BlackChancery.ttf" },
    { key = "celestia",               label = "Celestia Medium Redux", file = FONT_BASE .. "CelestiaMediumRedux1.55.ttf" },
    { key = "continuum",              label = "Continuum Medium",     file = FONT_BASE .. "ContinuumMedium.ttf" },
    { key = "dejavusans",             label = "DejaVu Sans",          file = FONT_BASE .. "DejaVuLGCSans.ttf" },
    { key = "dejavuserif",            label = "DejaVu Serif",         file = FONT_BASE .. "DejaVuLGCSerif.ttf" },
    { key = "diabloheavy",            label = "Diablo Heavy",         file = FONT_BASE .. "DiabloHeavy.ttf" },
    { key = "diedidie",               label = "DieDieDie",            file = FONT_BASE .. "DieDieDie.ttf" },
    { key = "dorispp",                label = "DorisPP",              file = FONT_BASE .. "DorisPP.ttf" },
    { key = "expressway",             label = "Expressway",           file = FONT_BASE .. "Expressway.ttf" },
    { key = "fitzgerald",             label = "Fitzgerald",           file = FONT_BASE .. "Fitzgerald.ttf" },
    { key = "gentiumplus",            label = "Gentium Plus",         file = FONT_BASE .. "GentiumPlus-Regular.ttf" },
    { key = "hack",                   label = "Hack",                 file = FONT_BASE .. "Hack-Regular.ttf" },
    { key = "homespun",               label = "Homespun",             file = FONT_BASE .. "Homespun.ttf" },
    { key = "hookedup",               label = "All Hooked Up",        file = FONT_BASE .. "HookedUp.ttf" },
    { key = "lato",                   label = "Lato",                 file = FONT_BASE .. "Lato-Regular.ttf" },
    { key = "liberationmono",         label = "Liberation Mono",      file = FONT_BASE .. "LiberationMono-Regular.ttf" },
    { key = "liberationsans",         label = "Liberation Sans",      file = FONT_BASE .. "LiberationSans-Regular.ttf" },
    { key = "liberationserif",        label = "Liberation Serif",     file = FONT_BASE .. "LiberationSerif-Regular.ttf" },
    { key = "poppinssemibold",        label = "Poppins SemiBold",     file = FONT_BASE .. "Poppins-SemiBold.ttf" },
    { key = "ptsansnarrow",           label = "PT Sans Narrow",       file = FONT_BASE .. "PTSansNarrow.ttf" },
    { key = "robotocondensedbold",    label = "Roboto Condensed Bold", file = FONT_BASE .. "RobotoCondensed-Bold.ttf" },
    { key = "sfatarian",              label = "SF Atarian System",    file = FONT_BASE .. "SFAtarianSystem.ttf" },
    { key = "sfcovington",            label = "SF Covington",         file = FONT_BASE .. "SFCovington.ttf" },
    { key = "sfmovieposter",          label = "SF Movie Poster",      file = FONT_BASE .. "SFMoviePoster-Bold.ttf" },
    { key = "sfwondercomic",          label = "SF Wonder Comic",      file = FONT_BASE .. "SFWonderComic.ttf" },
    { key = "swfit",                  label = "SWF!T",                file = FONT_BASE .. "SWFIT.ttf" },
    { key = "texgyreadventor",        label = "TeX Gyre Adventor",    file = FONT_BASE .. "texgyreadventor-regular.otf" },
    { key = "texgyreadventorbold",    label = "TeX Gyre Adventor Bold", file = FONT_BASE .. "texgyreadventor-bold.otf" },
    { key = "wenquanyi",              label = "WenQuanYi Zen Hei",    file = FONT_BASE .. "wqy-zenhei.ttf" },
    { key = "yellowjacket",           label = "Yellowjacket",         file = FONT_BASE .. "yellow.ttf" },
}

local FONT_LOOKUP = {}
for _, f in ipairs(FONTS) do
    FONT_LOOKUP[f.key] = f
end

local LSM_NAME_TO_KEY = {
    ["Action Man"]             = "actionman",
    ["Adventure"]              = "adventure",
    ["All Hooked Up"]          = "hookedup",
    ["Atkinson Hyperlegible"]  = "atkinsonhyperlegible",
    ["Bazooka"]                = "bazooka",
    ["Black Chancery"]         = "blackchancery",
    ["Celestia Medium Redux"]  = "celestia",
    ["Continuum Medium"]       = "continuum",
    ["DejaVu Sans"]            = "dejavusans",
    ["DejaVu Serif"]           = "dejavuserif",
    ["Diablo Heavy"]           = "diabloheavy",
    ["DieDieDie"]              = "diedidie",
    ["DorisPP"]                = "dorispp",
    ["Enigmatic"]              = "enigmatic",
    ["Expressway"]             = "expressway",
    ["Fitzgerald"]             = "fitzgerald",
    ["Gentium Plus"]           = "gentiumplus",
    ["Hack"]                   = "hack",
    ["Homespun"]               = "homespun",
    ["Lato"]                   = "lato",
    ["Liberation Mono"]        = "liberationmono",
    ["Liberation Sans"]        = "liberationsans",
    ["Liberation Serif"]       = "liberationserif",
    ["Poppins SemiBold"]       = "poppinssemibold",
    ["PT Sans Narrow"]         = "ptsansnarrow",
    ["Roboto Condensed Bold"]  = "robotocondensedbold",
    ["SF Atarian System"]      = "sfatarian",
    ["SF Covington"]           = "sfcovington",
    ["SF Movie Poster"]        = "sfmovieposter",
    ["SF Wonder Comic"]        = "sfwondercomic",
    ["SWF!T"]                  = "swfit",
    ["TeX Gyre Adventor"]      = "texgyreadventor",
    ["TeX Gyre Adventor Bold"] = "texgyreadventorbold",
    ["WenQuanYi Zen Hei"]      = "wenquanyi",
    ["Yellowjacket"]           = "yellowjacket",
}

-- Resolves an LSM-registered font name to its file path. Returns nil (not the
-- LSM default) when the name isn't registered, so callers can distinguish
-- "unknown font" from "user picked the WoW default".
local function FetchLSMFont(name)
    if not name then return nil end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if not LSM then return nil end
    return LSM:Fetch("font", name, true)
end

function OneWoW_GUI:GetFont()
    local fontKey = self:GetSetting("font") or "default"
    local fontData = FONT_LOOKUP[fontKey]
    if fontData and fontData.file then
        return fontData.file
    end
    if fontKey ~= "default" then
        local path = FetchLSMFont(fontKey)
        if path then return path end
    end
    return nil
end

-- Returns the unified font list:
--   * "WoW Default" pinned at the top,
--   * then every other hardcoded OneWoW-shipped font + every LSM-registered
--     font that isn't already represented by a hardcoded entry (skipped via
--     LSM_NAME_TO_KEY), all sorted alphabetically by label.
-- LSM-only fonts use the LSM name as both `key` and `label`, so the same
-- string round-trips through dropdowns and SavedVariables.
function OneWoW_GUI:GetFontList()
    local list = {}
    local rest = {}
    for _, entry in ipairs(FONTS) do
        if entry.key == "default" then
            tinsert(list, entry)
        else
            tinsert(rest, entry)
        end
    end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for _, name in ipairs(LSM:List("font") or {}) do
            if not LSM_NAME_TO_KEY[name] then
                local path = LSM:Fetch("font", name, true)
                if path then
                    tinsert(rest, { key = name, label = name, file = path })
                end
            end
        end
    end
    sort(rest, function(a, b) return a.label:lower() < b.label:lower() end)
    for _, entry in ipairs(rest) do
        tinsert(list, entry)
    end
    return list
end

function OneWoW_GUI:GetFontByKey(key)
    if not key or key == "default" then return nil end
    local fontData = FONT_LOOKUP[key]
    if fontData and fontData.file then return fontData.file end
    return FetchLSMFont(key)
end

-- Resolves any unified font key (hardcoded key or LSM name) into the same
-- { key, label, file } shape used by GetFontList. Returns nil for unknown
-- keys; "default" returns the WoW Default entry from FONT_LOOKUP.
function OneWoW_GUI:GetFontInfoByKey(key)
    if not key then return nil end
    local fontData = FONT_LOOKUP[key]
    if fontData then return fontData end
    local path = FetchLSMFont(key)
    if path then
        return { key = key, label = key, file = path }
    end
    return nil
end

function OneWoW_GUI:GetFontSizeOffset()
    return self._settingsDB and self._settingsDB.fontSizeOffset or 0
end

-- Safely apply a font file. Guarantees the fontstring ends with SOME valid font
-- set at the requested size, so callers can safely call SetText/SetFormattedText
-- afterwards without risking a "Font not set" error.
--
-- Mainline FontString:SetFont quirks we work around here:
--  1. SetFont's boolean return value is unreliable. Some valid custom TTFs
--     render correctly yet return false/nil. We cannot simply fall back to
--     SetFontObject(GameFontNormal) on a falsy return, because SetFontObject
--     forces BOTH font face AND size back to the object's baked defaults,
--     silently discarding the caller's size.
--  2. The first SetFont call with an uncached TTF can "fail" while loading the
--     file into WoW's font cache as a side effect; a second immediate call
--     then succeeds. We retry once.
--  3. A font file may be genuinely missing / corrupt (FONTS entry whose file
--     is not on disk). To avoid leaving the fontstring with no font (which
--     crashes SetText later), we fall back to GameFontNormal's *path* applied
--     at the caller's size - keeping the size slider functional.
local STOCK_FONT_PATH
local function GetStockFontPath()
    if not STOCK_FONT_PATH then
        STOCK_FONT_PATH = select(1, GameFontNormal:GetFont())
    end
    return STOCK_FONT_PATH
end

local function TrySetFont(fontString, path, size, flags)
    local ok, success = pcall(fontString.SetFont, fontString, path, size, flags)
    return ok, success
end

local fontMetadata = setmetatable({}, { __mode = "k" })

function OneWoW_GUI:SetFontBaseSize(fontObject, baseSize)
    if not fontObject then return nil end
    local metadata = fontMetadata[fontObject]
    if not metadata then
        metadata = {}
        fontMetadata[fontObject] = metadata
    end
    metadata.baseSize = baseSize
    return metadata
end

function OneWoW_GUI:SetFontCap(fontObject, baseSize, maxOffset)
    local metadata = self:SetFontBaseSize(fontObject, baseSize)
    if metadata then
        metadata.maxOffset = maxOffset
    end
    return metadata
end

function OneWoW_GUI:GetFontMetadata(fontObject)
    if not fontObject then return nil end
    return fontMetadata[fontObject]
end

function OneWoW_GUI:SafeSetFont(fontString, fontPath, size, flags)
    if not fontString then return end
    local offset = self._settingsDB and self._settingsDB.fontSizeOffset or 0
    local adjustedSize = math.max(6, (size or 12) + offset)
    local f = flags or ""
    local stockPath = GetStockFontPath()

    local target = fontPath or stockPath
    if target then
        local ok, success = TrySetFont(fontString, target, adjustedSize, f)
        if ok and success ~= false then
            return
        end
        if ok and success == false then
            local ok2, success2 = TrySetFont(fontString, target, adjustedSize, f)
            if ok2 and success2 ~= false then
                return
            end
        end
    end

    -- Target font is unusable (missing file, bad args, etc.). Apply the stock
    -- font at the caller's size so the fontstring is never left without a font.
    if stockPath and stockPath ~= target then
        local ok = TrySetFont(fontString, stockPath, adjustedSize, f)
        if ok then return end
    end
    fontString:SetFontObject(GameFontNormal)
end

-- Pre-warm every shipped font once at load. The first SetFont call on an
-- uncached TTF is the "slow / sometimes-fails" one; subsequent calls hit WoW's
-- font cache and render reliably. By warming all fonts on a throwaway
-- fontstring we make later font changes immediate and consistent.
local function PrewarmFonts()
    local f = UIParent:CreateFontString(nil, "BACKGROUND")
    f:Hide()
    for _, entry in ipairs(FONTS) do
        if entry.file then
            pcall(f.SetFont, f, entry.file, 12, "")
        end
    end
end

function OneWoW_GUI:CreateFS(parent, size, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    self:SetFontBaseSize(fs, size or 12)
    self:SafeSetFont(fs, self:GetFont(), size or 12)
    return fs
end

function OneWoW_GUI:ApplyFont(fs, size)
    if not fs then return end
    local metadata = self:GetFontMetadata(fs)
    if size then
        metadata = self:SetFontBaseSize(fs, size)
    elseif not metadata and fs.GetFont then
        local _, currentSize = fs:GetFont()
        metadata = self:SetFontBaseSize(fs, currentSize or 13)
    end
    self:SafeSetFont(fs, self:GetFont(), (metadata and metadata.baseSize) or 13)
end

function OneWoW_GUI:ApplyFontCapped(fs, size, maxOffset)
    if not fs then return end
    self:SetFontCap(fs, size, maxOffset)
    local fontPath = self:GetFont()
    local offset = self:GetFontSizeOffset() or 0
    local cappedSize = math.max(6, size + math.min(offset, maxOffset))
    if fontPath then
        -- See SafeSetFont: don't distrust SetFont's return value; only the pcall error.
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
            local metadata = self:GetFontMetadata(region)
            if not metadata then
                local _, sz = region:GetFont()
                if sz and sz > 0 then
                    metadata = self:SetFontBaseSize(region, sz)
                end
            end
            if metadata and metadata.baseSize then
                if metadata.maxOffset then
                    self:ApplyFontCapped(region, metadata.baseSize, metadata.maxOffset)
                else
                    self:SafeSetFont(region, fontPath, metadata.baseSize)
                end
            end
        end
    end
    for _, child in ipairs({frame:GetChildren()}) do
        if child:GetObjectType() == "EditBox" and child.GetFont then
            local metadata = self:GetFontMetadata(child)
            if not metadata then
                local _, sz = child:GetFont()
                if sz and sz > 0 then
                    metadata = self:SetFontBaseSize(child, sz)
                end
            end
            if metadata and metadata.baseSize then
                local _, _, flags = child:GetFont()
                self:SafeSetFont(child, fontPath, metadata.baseSize, flags)
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

    local settingLang = self:GetSetting("language")
    local currentLang = type(settingLang) == "string" and settingLang or "enUS"
    local currentIconTheme = self:GetSetting("minimap.theme") or DEFAULT_THEME_ICON
    local currentFontKey = self:GetSetting("font") or "default"
    local currentFontData = self:GetFontInfoByKey(currentFontKey)
    local currentFontLabel = currentFontData and currentFontData.label or "WoW Default"
    local currentOffset = self:GetSetting("fontSizeOffset") or 0

    local settingsAddonName = options.addonName
        local isPerAddonMinimap = not OneWoW and settingsAddonName
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

    local function CreateThreeColumnRow(height)
        height = height or 88
        local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        container:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
        container:SetHeight(height)
        container:SetBackdrop(panelBackdrop)
        container:SetBackdropColor(self:GetThemeColor("BG_SECONDARY"))
        container:SetBackdropBorderColor(self:GetThemeColor("BORDER_SUBTLE"))

        local lp = CreateFrame("Frame", nil, container)

        local leftDiv = container:CreateTexture(nil, "ARTWORK")
        leftDiv:SetWidth(1)
        leftDiv:SetColorTexture(self:GetThemeColor("BORDER_SUBTLE"))

        local mp = CreateFrame("Frame", nil, container)

        local rightDiv = container:CreateTexture(nil, "ARTWORK")
        rightDiv:SetWidth(1)
        rightDiv:SetColorTexture(self:GetThemeColor("BORDER_SUBTLE"))

        local rp = CreateFrame("Frame", nil, container)

        local function LayoutColumns()
            local width = container:GetWidth()
            if width <= 0 then return end

            local colWidth = width / 3

            lp:ClearAllPoints()
            lp:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            lp:SetSize(colWidth, height)

            mp:ClearAllPoints()
            mp:SetPoint("TOPLEFT", container, "TOPLEFT", colWidth, 0)
            mp:SetSize(colWidth, height)

            rp:ClearAllPoints()
            rp:SetPoint("TOPLEFT", container, "TOPLEFT", colWidth * 2, 0)
            rp:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)

            leftDiv:ClearAllPoints()
            leftDiv:SetPoint("TOPLEFT", container, "TOPLEFT", colWidth, -8)
            leftDiv:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", colWidth, 8)

            rightDiv:ClearAllPoints()
            rightDiv:SetPoint("TOPLEFT", container, "TOPLEFT", colWidth * 2, -8)
            rightDiv:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", colWidth * 2, 8)
        end

        container:SetScript("OnSizeChanged", LayoutColumns)
        container:HookScript("OnShow", LayoutColumns)
        LayoutColumns()

        return container, lp, mp, rp
    end

    -- Builds a centered clickable label inside a column. Clicking opens
    -- ShowCopyURLDialog so the user can copy the URL — keeps the row compact
    -- on smaller addon settings panels.
    local function CreateLinkPanel(panel, title, url)
        local btn = CreateFrame("Button", nil, panel)
        btn:SetAllPoints(panel)
        btn:EnableMouse(true)

        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        label:SetText(title)
        label:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

        btn:SetScript("OnEnter", function()
            label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            SetCursor("Interface\\CURSOR\\Point")
        end)
        btn:SetScript("OnLeave", function()
            label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            ResetCursor()
        end)
        btn:SetScript("OnClick", function()
            OneWoW_GUI:ShowCopyURLDialog(title, url)
        end)

        return btn
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
    fontDesc:SetText("Choose the font used across all OneWoW addons. SharedMedia fonts from other addons are also supported and will appear in the list.")
    fontDesc:SetTextColor(self:GetThemeColor("TEXT_SECONDARY"))
    fontDesc:SetJustifyH("LEFT")
    fontDesc:SetWordWrap(true)

    local fontCurrentLabel = fontPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontCurrentLabel:SetPoint("TOPLEFT", fontPanel, "TOPLEFT", 15, -90)
    fontCurrentLabel:SetText("Current: " .. currentFontLabel)
    fontCurrentLabel:SetTextColor(self:GetThemeColor("ACCENT_PRIMARY"))

    local fontDropdown = self:CreateDropdown(fontPanel, {
        width = 210,
        height = 30,
        text = currentFontLabel,
    })
    fontDropdown:SetPoint("TOPLEFT", fontPanel, "TOPLEFT", 15, -115)

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

    self:AttachFilterMenu(fontDropdown, {
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
            fontCurrentLabel:SetText("Current: " .. text)
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
    -- ROW 5: Discord | Donate | OneWoW Home
    ----------------------------------------------------------------
    -- Compact row of clickable labels. Each opens a copy-URL dialog so the
    -- row stays small on addon settings panels with limited vertical space.
    local _, discordPanel, donatePanel, homePanel = CreateThreeColumnRow(36)

    CreateLinkPanel(discordPanel, "Discord", "https://discord.gg/6vnabDVnDu")
    CreateLinkPanel(donatePanel, "Donate", "https://buymeacoffee.com/migugin")
    CreateLinkPanel(homePanel, "OneWoW Home", "https://wow2.xyz/")

    yOffset = yOffset - 56

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
eventFrame:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon == "OneWoW_GUI" then
        InitSettingsDB()
        PrewarmFonts()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
