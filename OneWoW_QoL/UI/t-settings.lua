-- OneWoW_QoL Addon File
-- OneWoW_QoL/UI/t-settings.lua
-- Created by MichinMuggin (Ricky)
local _, ns = ...
local L = ns.L

local addon = _G.OneWoW_QoL

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local THEME_LOCALE_KEYS = {
    green  = "THEME_NAME_GREEN",
    blue   = "THEME_NAME_BLUE",
    purple = "THEME_NAME_PURPLE",
    red    = "THEME_NAME_RED",
    orange = "THEME_NAME_ORANGE",
    teal   = "THEME_NAME_TEAL",
    gold   = "THEME_NAME_GOLD",
    pink   = "THEME_NAME_PINK",
    dark   = "THEME_NAME_DARK",
    amber  = "THEME_NAME_AMBER",
    cyan   = "THEME_NAME_CYAN",
    slate  = "THEME_NAME_SLATE",
    voidblack   = "THEME_NAME_VOID_BLACK",
    charcoal    = "THEME_NAME_CHARCOAL_DEEP",
    forestnight = "THEME_NAME_FOREST_NIGHT",
    obsidian    = "THEME_NAME_OBSIDIAN_MINIMAL",
    monochrome  = "THEME_NAME_MONOCHROME_PRO",
    twilight    = "THEME_NAME_TWILIGHT_COMPACT",
    neon        = "THEME_NAME_NEON_SYNTHWAVE",
    glassmorphic = "THEME_NAME_GLASSMORPHIC",
    lightmode   = "THEME_NAME_MINIMAL_WHITE",
    retro       = "THEME_NAME_RETRO_CLASSIC",
    fantasy     = "THEME_NAME_RPG_FANTASY",
    nightfae    = "THEME_NAME_COVENANT_TWILIGHT",
}

local LANGUAGES = {
    { key = "enUS", labelKey = "LANG_ENGLISH" },
    { key = "koKR", labelKey = "LANG_KOREAN" },
}

local THEMES = OneWoW_GUI.Constants.THEMES
local THEMES_ORDER = OneWoW_GUI.Constants.THEMES_ORDER
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local backdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

local function ShowDevHelpDialog()
    if _G.OneWoW_QoLDevHelpDialog then
        _G.OneWoW_QoLDevHelpDialog:Show()
        _G.OneWoW_QoLDevHelpDialog:Raise()
        return
    end

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_QoLDevHelpDialog",
        title = L["DEVHELP_TITLE"],
        width = 520,
        height = 560,
        buttons = {
            { text = L["DEVHELP_CLOSE"], onClick = function(dialog) dialog:Hide() end },
        },
    })

    local dialog = result.frame
    local cf = result.contentFrame

    local scrollFrame = CreateFrame("ScrollFrame", nil, cf)
    scrollFrame:SetPoint("TOPLEFT", cf, "TOPLEFT", 16, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -24, 4)
    scrollFrame:EnableMouseWheel(true)

    local scrollTrack = CreateFrame("Frame", nil, cf, "BackdropTemplate")
    scrollTrack:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -4, -4)
    scrollTrack:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -4, 4)
    scrollTrack:SetWidth(8)
    scrollTrack:SetBackdrop(BACKDROP_SIMPLE)
    scrollTrack:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(40)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop(BACKDROP_SIMPLE)
    scrollThumb:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

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
            scrollThumb:ClearAllPoints()
            scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
            return
        end
        local trackH = scrollTrack:GetHeight()
        local thumbH = math.max(20, (frameH / contentH) * trackH)
        scrollThumb:SetHeight(thumbH)
        local maxOffset = trackH - thumbH
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -(scroll / scrollRange) * maxOffset)
    end

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        self:SetVerticalScroll(delta > 0 and math.max(0, current - 30) or math.min(maxScroll, current + 30))
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
    scrollThumb:SetScript("OnMouseUp", function(self) self.dragging = false end)
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

    local bodyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bodyText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -8)
    bodyText:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -8, -8)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetWordWrap(true)
    bodyText:SetSpacing(4)
    bodyText:SetText(L["DEVHELP_BODY"])
    bodyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    scrollChild:SetHeight(bodyText:GetStringHeight() + 30)
    C_Timer.After(0.1, function() UpdateThumb() end)

    dialog:Show()
end

local function CreateSectionHeader(parent, text, yOffset)
    return OneWoW_GUI:CreateSectionHeader(parent, { title = text, yOffset = yOffset })
end

local function CreateSectionDivider(parent, yOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yOffset)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
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
    scrollTrack:SetBackdrop(BACKDROP_SIMPLE)
    scrollTrack:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(40)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop(BACKDROP_SIMPLE)
    scrollThumb:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

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
            scrollThumb:ClearAllPoints()
            scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
            return
        end
        local trackH = scrollTrack:GetHeight()
        local thumbH = math.max(20, (frameH / contentH) * trackH)
        scrollThumb:SetHeight(thumbH)
        local maxOffset = trackH - thumbH
        scrollThumb:ClearAllPoints()
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
    scrollThumb:SetScript("OnMouseUp", function(self) self.dragging = false end)
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

    local yOffset = -20

    if not _G.OneWoW then
        yOffset = OneWoW_GUI:CreateSettingsPanel(scrollChild, { yOffset = yOffset, addonName = "OneWoW_QoL" })
    end

    yOffset = yOffset - 20
    local devHeader = CreateSectionHeader(scrollChild, L["SETTINGS_DEVELOPER_HEADER"], yOffset)
    yOffset = yOffset - devHeader:GetHeight() - 8
    CreateSectionDivider(scrollChild, yOffset)
    yOffset = yOffset - 12

    local devDesc = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    devDesc:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, yOffset)
    devDesc:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -16, yOffset)
    devDesc:SetJustifyH("LEFT")
    devDesc:SetWordWrap(true)
    devDesc:SetSpacing(3)
    devDesc:SetText(L["SETTINGS_DEVELOPER_DESC"])
    devDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - devDesc:GetStringHeight() - 14

    local devHelpBtn = OneWoW_GUI:CreateFitTextButton(scrollChild, { text = L["SETTINGS_DEV_HELP_BTN"], height = 32 })
    devHelpBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, yOffset)
    devHelpBtn:SetScript("OnClick", function()
        ShowDevHelpDialog()
    end)

    yOffset = yOffset - 50

    scrollChild:SetHeight(math.abs(yOffset) + 20)
    C_Timer.After(0.1, function() UpdateThumb() end)
end
