local ADDON_NAME, ns = ...

ns.GUI = ns.GUI or {}
local GUI = ns.GUI

local function T(key)
    if ns.Constants and ns.Constants.THEME and ns.Constants.THEME[key] then
        return unpack(ns.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if ns.Constants and ns.Constants.SPACING then
        return ns.Constants.SPACING[key] or 8
    end
    return 8
end

local BACKDROP_SOFT = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true,
    tileEdge = true,
    tileSize = 16,
    edgeSize = 14,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
}

local BACKDROP_INNER = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

function GUI:CreateFrame(name, parent, width, height, useSoft)
    local frame = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    if useSoft then
        frame:SetBackdrop(BACKDROP_SOFT)
    else
        frame:SetBackdrop(BACKDROP_INNER)
    end
    frame:SetBackdropColor(T("BG_PRIMARY"))
    frame:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    return frame
end

function GUI:CreateButton(name, parent, text, width, height)
    local C = ns.Constants and ns.Constants.GUI or { BUTTON_HEIGHT = 28 }
    local btn = CreateFrame("Button", name, parent, "BackdropTemplate")
    btn:SetSize(width or 100, height or C.BUTTON_HEIGHT)
    btn:SetBackdrop(BACKDROP_INNER)
    btn:SetBackdropColor(T("BTN_NORMAL"))
    btn:SetBackdropBorderColor(T("BTN_BORDER"))

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text or "")
    btn.text:SetTextColor(T("TEXT_PRIMARY"))

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BTN_HOVER"))
        self:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
        self.text:SetTextColor(T("TEXT_ACCENT"))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BTN_NORMAL"))
        self:SetBackdropBorderColor(T("BTN_BORDER"))
        self.text:SetTextColor(T("TEXT_PRIMARY"))
    end)
    btn:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(T("BTN_PRESSED"))
    end)
    btn:SetScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            self:SetBackdropColor(T("BTN_HOVER"))
        else
            self:SetBackdropColor(T("BTN_NORMAL"))
        end
    end)

    return btn
end

function GUI:CreateEditBox(name, parent, width, height)
    local C = ns.Constants and ns.Constants.GUI or { SEARCH_HEIGHT = 28 }
    local box = CreateFrame("EditBox", name, parent, "BackdropTemplate")
    box:SetSize(width or 200, height or C.SEARCH_HEIGHT)
    box:SetBackdrop(BACKDROP_INNER)
    box:SetBackdropColor(T("BG_TERTIARY"))
    box:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    box:SetFontObject(GameFontHighlight)
    box:SetTextInsets(S("SM") + 2, S("SM"), 0, 0)
    box:SetAutoFocus(false)
    box:EnableMouse(true)
    box:SetTextColor(T("TEXT_PRIMARY"))

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    return box
end

function GUI:CreateCheckbox(name, parent, label)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)

    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.label:SetPoint("LEFT", cb, "RIGHT", S("XS"), 0)
    cb.label:SetText(label or "")
    cb.label:SetTextColor(T("TEXT_PRIMARY"))

    return cb
end

function GUI:CreateHeader(parent, text, yOffset)
    local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    h:SetPoint("TOPLEFT", S("MD"), yOffset or -S("MD"))
    h:SetText(text or "")
    h:SetTextColor(T("ACCENT_PRIMARY"))
    return h
end

function GUI:CreateDivider(parent, yOffset)
    local d = parent:CreateTexture(nil, "ARTWORK")
    d:SetHeight(1)
    d:SetPoint("LEFT",  S("MD"), 0)
    d:SetPoint("RIGHT", -S("MD"), 0)
    d:SetPoint("TOP", 0, yOffset or 0)
    d:SetColorTexture(T("BORDER_SUBTLE"))
    return d
end

-- LESSON 9 compliant scroll area
-- Returns: container, scrollFrame, scrollContent, UpdateThumb
function GUI:CreateScrollArea(parent, name, offsetL, offsetR, offsetT, offsetB)
    offsetL = offsetL or 0
    offsetR = offsetR or 0
    offsetT = offsetT or 0
    offsetB = offsetB or 0

    local container = CreateFrame("Frame", name and (name .. "Container") or nil, parent)
    container:SetPoint("TOPLEFT",     parent, "TOPLEFT",     offsetL, offsetT)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", offsetR, offsetB)

    local scrollFrame = CreateFrame("ScrollFrame", name and (name .. "ScrollFrame") or nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     container, "TOPLEFT",     0,   0)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -14, 0)

    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT",    container, "TOPRIGHT",    -2, 0)
        scrollBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -2, 0)
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
            scrollBar.Background:SetColorTexture(T("BG_TERTIARY"))
        end
        if scrollBar.ThumbTexture then
            scrollBar.ThumbTexture:SetWidth(8)
            scrollBar.ThumbTexture:SetColorTexture(T("ACCENT_PRIMARY"))
        end
    end

    local scrollContent = CreateFrame("Frame", name and (name .. "Content") or nil, scrollFrame)
    scrollContent:SetHeight(1)
    scrollFrame:SetScrollChild(scrollContent)

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        scrollContent:SetWidth(w)
    end)

    container.scrollFrame   = scrollFrame
    container.scrollContent = scrollContent
    container.UpdateThumb   = function() end

    return container
end

function GUI:ApplyTheme(themeName)
    local themes = ns.Constants and ns.Constants.THEMES
    if not themes or not themes[themeName] then return end

    local t = themes[themeName]
    for k, v in pairs(t) do
        if type(v) == "table" then
            ns.Constants.THEME[k] = v
        end
    end
end

GUI.GetThemeColor = T
GUI.GetSpacing    = S
