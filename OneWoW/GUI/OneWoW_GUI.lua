local _, ns = ...

-- ============================================================================
-- OneWoW/GUI/OneWoW_GUI.lua
-- THIS IS THE GUI TOOLKIT (OneWoW_GUI global) - The single source of truth for
-- all shared UI creation functions. Other addons consume the plain global.
-- ALL reusable UI functions (buttons, scroll frames, split panels, etc.)
-- MUST be defined here. Do NOT duplicate these functions in any addon.
-- ============================================================================
local OneWoW_GUI = OneWoW_GUI

local CreateFrame = CreateFrame
local unpack = unpack

local Constants = OneWoW_GUI.Constants
local DEFAULT_THEME_COLOR = Constants.DEFAULT_THEME_COLOR
local DEFAULT_THEME_SPACING = Constants.DEFAULT_THEME_SPACING
local DEFAULT_THEME_KEY = Constants.DEFAULT_THEME_KEY
local DEFAULT_ICON_TEXTURE = Constants.ICON_TEXTURES.horde

local noop = OneWoW_GUI.noop

local guiConstantsMetatable = {
    __index = function(_, key)
        return Constants.GUI[key] or 0
    end,
    __newindex = noop,
}

local themeMetatable = {
    __index = function(_, key)
        -- Use rawget to avoid recursion when FALLBACK_THEME == self
        return rawget(Constants.FALLBACK_THEME, key) or DEFAULT_THEME_COLOR
    end,
    __newindex = noop,
}

---@param key string
---@param themeKey string|nil When set, resolves from Constants.THEMES[themeKey] instead of ACTIVE_THEME (settings preview).
local function GetThemeColor(key, themeKey)
    if themeKey then
        local theme = Constants.THEMES[themeKey]
        if theme and theme[key] then
            return unpack(theme[key])
        end
        return unpack(rawget(Constants.FALLBACK_THEME, key) or DEFAULT_THEME_COLOR)
    end
    if Constants.ACTIVE_THEME and Constants.ACTIVE_THEME[key] then
        return unpack(Constants.ACTIVE_THEME[key])
    end
    return unpack(DEFAULT_THEME_COLOR)
end

local function GetSpacing(key)
    return Constants.SPACING[key] or DEFAULT_THEME_SPACING
end

---@param key string
---@param themeKey string|nil Optional palette key for non-active theme preview (e.g. settings swatches).
function OneWoW_GUI:GetThemeColor(key, themeKey)
    return GetThemeColor(key, themeKey)
end

function OneWoW_GUI:WrapThemeColor(text, themeKey)
    local r, g, b, a = GetThemeColor(themeKey)
    return CreateColor(r or 1, g or 1, b or 1, a or 1):WrapTextInColorCode(text)
end

-- Scrollbar thumb color, derived from the theme's brightest accent and blended
-- hard toward white so it reads as a vivid, fully-opaque handle that clearly
-- stands out from the ACCENT_PRIMARY row selection (same hue family, but much
-- lighter). hover = true brightens it further. Theme-matched, no per-theme token.
local function BlendToWhite(r, g, b, t)
    return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
end

function OneWoW_GUI:GetScrollThumbColor(hover)
    local r, g, b = GetThemeColor("ACCENT_HIGHLIGHT")
    r, g, b = BlendToWhite(r, g, b, hover and 0.75 or 0.5)
    return r, g, b, 1
end

function OneWoW_GUI:GetSpacing(key)
    return GetSpacing(key)
end

function OneWoW_GUI:GetBrandIcon(factionTheme)
    return OneWoW_GUI.Constants.ICON_TEXTURES[factionTheme] or DEFAULT_ICON_TEXTURE
end

local function GetRawThemeKeyFromSources(self, addon)
    -- _settingsDB is ns.db.global (core's OneWoW_DB); the addon fallback
    -- covers calls before InitializeSettings binds.
    local themeKey
    if self._settingsDB and self._settingsDB.theme then
        themeKey = self._settingsDB.theme
    elseif addon and addon.db and addon.db.global and addon.db.global.theme then
        themeKey = addon.db.global.theme
    end
    if not themeKey or themeKey == "" then
        themeKey = DEFAULT_THEME_KEY
    end
    return themeKey
end

-- Palette key actually driving colors this session (resolves "random").
function OneWoW_GUI:GetEffectiveThemeKey()
    local raw = GetRawThemeKeyFromSources(self, nil)
    if raw == "random" then
        if not Constants.SESSION_RANDOM_THEME_KEY then
            self:ApplyTheme()
        end
        return Constants.SESSION_RANDOM_THEME_KEY or DEFAULT_THEME_KEY
    end
    return raw
end

-- Localized display name for a theme key. Theme names live in the shared locale
-- scope as THEME_<UPPER themeKey> (e.g. green -> THEME_GREEN); resolved at runtime
-- because the locale files load after this GUI block. Falls back to the English
-- Constants.THEMES[key].name when no translation is registered.
function OneWoW_GUI:GetThemeName(themeKey)
    local data = Constants.THEMES[themeKey]
    if themeKey then
        local v = ns.Locale:GetOptional("OneWoW", "THEME_" .. string.upper(themeKey))
        if v then return v end
    end
    return (data and data.name) or themeKey or Constants.DEFAULT_THEME_NAME
end

-- Human-readable label for the settings UI (includes Random → resolved name).
function OneWoW_GUI:GetThemeDisplayName()
    local raw = GetRawThemeKeyFromSources(self, nil)
    if raw == "random" then
        local eff = self:GetEffectiveThemeKey()
        local fmt = ns.Locale:GetOptional("OneWoW", "THEME_RANDOM_CURRENT") or "Random (%s)"
        return string.format(fmt, self:GetThemeName(eff))
    end
    return self:GetThemeName(raw)
end

function OneWoW_GUI:ApplyTheme(addon)
    local raw = GetRawThemeKeyFromSources(self, addon)
    if raw ~= "random" then
        Constants.SESSION_RANDOM_THEME_KEY = nil
    end

    local effectiveKey = raw
    if raw == "random" then
        if not Constants.SESSION_RANDOM_THEME_KEY then
            local order = Constants.THEMES_ORDER
            if order and #order > 0 then
                Constants.SESSION_RANDOM_THEME_KEY = order[math.random(1, #order)]
            else
                Constants.SESSION_RANDOM_THEME_KEY = DEFAULT_THEME_KEY
            end
        end
        effectiveKey = Constants.SESSION_RANDOM_THEME_KEY
    end

    local selectedTheme = Constants.THEMES[effectiveKey] or Constants.THEMES[DEFAULT_THEME_KEY]
    Constants.ACTIVE_THEME = setmetatable(selectedTheme, themeMetatable)
end

function OneWoW_GUI:RegisterGUIConstants(guiConstants)
    return setmetatable(guiConstants, guiConstantsMetatable)
end

function OneWoW_GUI:CreateFrame(parent, options)
    options = options or {}
    local name = options.name
    local width = options.width
    local height = options.height
    local backdrop = options.backdrop or Constants.BACKDROP_INNER_NO_INSETS
    local bgColor = options.bgColor or "BG_PRIMARY"
    local borderColor = options.borderColor or "BORDER_DEFAULT"
    parent = parent or UIParent
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    if width and height then
        frame:SetSize(width, height)
    elseif width then
        frame:SetWidth(width)
    elseif height then
        frame:SetHeight(height)
    end
    frame:SetBackdrop(backdrop)
    frame:SetBackdropColor(GetThemeColor(bgColor))
    frame:SetBackdropBorderColor(GetThemeColor(borderColor))
    return frame
end

function OneWoW_GUI:CreateLayoutFrame(parent, options)
    options = options or {}
    local frame = CreateFrame("Frame", options.name, parent or UIParent)
    if options.width and options.height then
        frame:SetSize(options.width, options.height)
    elseif options.width then
        frame:SetWidth(options.width)
    elseif options.height then
        frame:SetHeight(options.height)
    end
    return frame
end

-- UIPanelScrollFrameTemplate always paints the thumb. scrollBarHideable would
-- hide it when range is 0, but Blizzard's range-changed handler also re-Shows
-- the up/down buttons we strip in the skin. Hook after that handler instead.
-- Callers that always hide (Bags, Notes pins, Crafting Orders) set
-- _oneWoWAlwaysHidden via SetScrollBarAlwaysHidden so this never Shows.
-- Optional scrollFrame._oneWoWOnScrollBarShown(shown) reclaims reserved gutter.
local floor = math.floor

local function keepScrollButtonsHidden(scrollBar)
    if scrollBar.ScrollUpButton then
        scrollBar.ScrollUpButton:Hide()
        scrollBar.ScrollUpButton:SetAlpha(0)
        scrollBar.ScrollUpButton:EnableMouse(false)
    end
    if scrollBar.ScrollDownButton then
        scrollBar.ScrollDownButton:Hide()
        scrollBar.ScrollDownButton:SetAlpha(0)
        scrollBar.ScrollDownButton:EnableMouse(false)
    end
end

local function syncScrollBarVisibility(scrollFrame, yrange)
    local scrollBar = scrollFrame.ScrollBar
    if not scrollBar then
        return
    end
    if scrollFrame._oneWoWScrollBarSyncing then
        return
    end
    scrollFrame._oneWoWScrollBarSyncing = true

    keepScrollButtonsHidden(scrollBar)

    if yrange == nil then
        yrange = scrollFrame:GetVerticalScrollRange()
    end
    local needed = (not scrollBar._oneWoWAlwaysHidden) and floor(yrange) > 0
    -- Do not read IsShown() here. Blizzard's OnScrollRangeChanged runs first
    -- and Shows the bar, so IsShown is already true and the gutter callback
    -- would never fire (Category Manager icons sitting under the thumb).
    local prevNeeded = scrollFrame._oneWoWScrollBarNeeded
    scrollFrame._oneWoWScrollBarNeeded = needed
    if needed then
        scrollBar:Show()
    else
        scrollBar:Hide()
    end
    keepScrollButtonsHidden(scrollBar)

    if prevNeeded ~= needed then
        local onShown = scrollFrame._oneWoWOnScrollBarShown
        if onShown then
            onShown(needed)
        end
    end

    scrollFrame._oneWoWScrollBarSyncing = nil
end

local function wireHideIfUnscrollable(scrollBar)
    local scrollFrame = scrollBar:GetParent()
    if not scrollFrame or scrollFrame._oneWoWScrollBarWired then
        return
    end
    scrollFrame._oneWoWScrollBarWired = true
    scrollFrame:HookScript("OnScrollRangeChanged", function(myself, _, yrange)
        syncScrollBarVisibility(myself, yrange)
    end)
    scrollFrame:HookScript("OnShow", function(myself)
        syncScrollBarVisibility(myself)
    end)
    syncScrollBarVisibility(scrollFrame)
end

local function applyScrollBarStyle(scrollBar, container, offset)
    if not scrollBar then return end
    offset = offset or -2
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", offset, 0)
    scrollBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", offset, 0)
    scrollBar:SetWidth(Constants.GUI.SCROLLBAR_WIDTH)
    keepScrollButtonsHidden(scrollBar)
    if scrollBar.Background then
        scrollBar.Background:SetColorTexture(GetThemeColor("BG_TERTIARY"))
    end
    if scrollBar.Track then
        if scrollBar.Track.Begin then scrollBar.Track.Begin:SetAlpha(0) end
        if scrollBar.Track.End then scrollBar.Track.End:SetAlpha(0) end
        if scrollBar.Track.Middle then scrollBar.Track.Middle:SetColorTexture(GetThemeColor("BG_TERTIARY")) end
    end
    if scrollBar.ThumbTexture then
        scrollBar.ThumbTexture:SetWidth(Constants.GUI.SCROLLBAR_THUMB_WIDTH)
        -- Bright theme-derived thumb so it stands out hard from the
        -- ACCENT_PRIMARY row selection (see GetScrollThumbColor).
        scrollBar.ThumbTexture:SetColorTexture(OneWoW_GUI:GetScrollThumbColor(false))
    end
    scrollBar:SetScript("OnEnter", function(self)
        if self.ThumbTexture then self.ThumbTexture:SetColorTexture(OneWoW_GUI:GetScrollThumbColor(true)) end
    end)
    scrollBar:SetScript("OnLeave", function(self)
        if self.ThumbTexture then self.ThumbTexture:SetColorTexture(OneWoW_GUI:GetScrollThumbColor(false)) end
    end)
    wireHideIfUnscrollable(scrollBar)
end

function OneWoW_GUI:ApplyScrollBarStyle(scrollBar, container, offset)
    applyScrollBarStyle(scrollBar, container, offset)
end

function OneWoW_GUI:StyleScrollBar(scrollFrame, options)
    local opt = options or {}
    local scrollBar = scrollFrame.ScrollBar
    if not scrollBar then return end
    local container = opt.container or scrollFrame
    local offset = opt.offset or -2
    applyScrollBarStyle(scrollBar, container, offset)
    if opt.alwaysHidden then
        self:SetScrollBarAlwaysHidden(scrollFrame, true)
    end
end

--- Keep a styled bar hidden even when the list overflows (Bags / Notes pins /
--- Crafting Orders "hide scrollbar"). Mouse wheel still scrolls. Pass false to
--- return to hide-when-unscrollable.
---@param scrollFrame Frame
---@param hidden boolean
function OneWoW_GUI:SetScrollBarAlwaysHidden(scrollFrame, hidden)
    local scrollBar = scrollFrame and scrollFrame.ScrollBar
    if not scrollBar then
        return
    end
    scrollBar._oneWoWAlwaysHidden = hidden and true or false
    syncScrollBarVisibility(scrollFrame)
end
