-- ============================================================================
-- OneWoW_GUI/OneWoW_GUI.lua
-- THIS IS THE GUI LIBRARY (OneWoW_GUI-1.0) - The single source of truth for
-- all shared UI creation functions. Other addons consume this via LibStub.
-- ALL reusable UI functions (buttons, scroll frames, split panels, etc.)
-- MUST be defined here. Do NOT duplicate these functions in any addon.
-- ============================================================================
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local CreateFrame = CreateFrame
local unpack = unpack

local Constants = OneWoW_GUI.Constants
local DEFAULT_THEME_COLOR = Constants.DEFAULT_THEME_COLOR
local DEFAULT_THEME_SPACING = Constants.DEFAULT_THEME_SPACING
local DEFAULT_THEME_KEY = Constants.DEFAULT_THEME_KEY
local DEFAULT_ICON_TEXTURE = Constants.ICON_TEXTURES.horde

local noop = OneWoW_GUI.noop

local guiConstantsMetatable = {
    __index = function(self, key)
        return Constants.GUI[key] or 0
    end,
    __newindex = noop,
}

local themeMetatable = {
    __index = function(self, key)
        -- Use rawget to avoid recursion when FALLBACK_THEME == self
        return rawget(Constants.FALLBACK_THEME, key) or DEFAULT_THEME_COLOR
    end,
    __newindex = noop,
}

local function GetThemeColor(key)
    if Constants.ACTIVE_THEME and Constants.ACTIVE_THEME[key] then
        return unpack(Constants.ACTIVE_THEME[key])
    end
    return unpack(DEFAULT_THEME_COLOR)
end

local function GetSpacing(key)
    return Constants.SPACING[key] or DEFAULT_THEME_SPACING
end

function OneWoW_GUI:GetThemeColor(key)
    return GetThemeColor(key)
end

function OneWoW_GUI:WrapThemeColor(text, themeKey)
    local r, g, b, a = GetThemeColor(themeKey)
    return CreateColor(r or 1, g or 1, b or 1, a or 1):WrapTextInColorCode(text)
end

function OneWoW_GUI:GetSpacing(key)
    return GetSpacing(key)
end

function OneWoW_GUI:GetBrandIcon(factionTheme)
    return OneWoW_GUI.Constants.ICON_TEXTURES[factionTheme] or DEFAULT_ICON_TEXTURE
end

function OneWoW_GUI:ApplyTheme(addon)
    local themeKey

    if self._settingsDB and self._settingsDB.theme then
        themeKey = self._settingsDB.theme
    elseif _G.OneWoW and _G.OneWoW.db and _G.OneWoW.db.global and _G.OneWoW.db.global.theme then
        themeKey = _G.OneWoW.db.global.theme
    elseif addon and addon.db and addon.db.global and addon.db.global.theme then
        themeKey = addon.db.global.theme
    end

    local selectedTheme = Constants.THEMES[themeKey] or Constants.THEMES[DEFAULT_THEME_KEY]
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

local function applyScrollBarStyle(scrollBar, container, offset)
    if not scrollBar then return end
    offset = offset or -2
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", offset, 0)
    scrollBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", offset, 0)
    scrollBar:SetWidth(10)
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
    if scrollBar.Background then
        scrollBar.Background:SetColorTexture(GetThemeColor("BG_TERTIARY"))
    end
    if scrollBar.Track then
        if scrollBar.Track.Begin then scrollBar.Track.Begin:SetAlpha(0) end
        if scrollBar.Track.End then scrollBar.Track.End:SetAlpha(0) end
        if scrollBar.Track.Middle then scrollBar.Track.Middle:SetColorTexture(GetThemeColor("BG_TERTIARY")) end
    end
    if scrollBar.ThumbTexture then
        scrollBar.ThumbTexture:SetWidth(8)
        scrollBar.ThumbTexture:SetColorTexture(GetThemeColor("ACCENT_PRIMARY"))
    end
    scrollBar:SetScript("OnEnter", function(self)
        if self.ThumbTexture then self.ThumbTexture:SetColorTexture(GetThemeColor("ACCENT_HIGHLIGHT")) end
    end)
    scrollBar:SetScript("OnLeave", function(self)
        if self.ThumbTexture then self.ThumbTexture:SetColorTexture(GetThemeColor("ACCENT_PRIMARY")) end
    end)
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
end
