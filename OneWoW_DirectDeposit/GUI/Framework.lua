local ADDON_NAME, OneWoW_DirectDeposit = ...

OneWoW_DirectDeposit.GUI = OneWoW_DirectDeposit.GUI or {}
local GUI = OneWoW_DirectDeposit.GUI

local function T(key)
    if OneWoW_DirectDeposit.Constants and OneWoW_DirectDeposit.Constants.THEME and OneWoW_DirectDeposit.Constants.THEME[key] then
        return unpack(OneWoW_DirectDeposit.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if OneWoW_DirectDeposit.Constants and OneWoW_DirectDeposit.Constants.SPACING then
        return OneWoW_DirectDeposit.Constants.SPACING[key] or 8
    end
    return 8
end

local BACKDROP_SOFT = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileEdge = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local BACKDROP_INNER = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

function GUI:CreateFrame(name, parent, width, height, useModernBackdrop)
    local frame = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    frame:SetSize(width, height)

    if useModernBackdrop then
        frame:SetBackdrop(BACKDROP_SOFT)
    else
        frame:SetBackdrop(BACKDROP_INNER)
    end

    frame:SetBackdropColor(T("BG_PRIMARY"))
    frame:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    return frame
end

function GUI:CreateButton(name, parent, text, width, height)
    local C = OneWoW_DirectDeposit.Constants and OneWoW_DirectDeposit.Constants.GUI or { BUTTON_HEIGHT = 28 }

    local btn = CreateFrame("Button", name, parent, "BackdropTemplate")
    btn:SetSize(width or 100, height or C.BUTTON_HEIGHT)
    btn:SetBackdrop(BACKDROP_INNER)
    btn:SetBackdropColor(T("BTN_NORMAL"))
    btn:SetBackdropBorderColor(T("BTN_BORDER"))

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
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
    local C = OneWoW_DirectDeposit.Constants and OneWoW_DirectDeposit.Constants.GUI or { SEARCH_HEIGHT = 32 }

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
    cb.label:SetText(label)
    cb.label:SetTextColor(T("TEXT_PRIMARY"))

    return cb
end

function GUI:CreateHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", S("MD"), yOffset or -S("MD"))
    header:SetText(text)
    header:SetTextColor(T("ACCENT_PRIMARY"))
    return header
end

function GUI:CreateDivider(parent, yOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("LEFT", S("MD"), 0)
    divider:SetPoint("RIGHT", -S("MD"), 0)
    divider:SetPoint("TOP", 0, yOffset)
    divider:SetColorTexture(T("BORDER_SUBTLE"))
    return divider
end

function GUI:CreateScrollFrame(name, parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)

    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -5, 0)
        scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -5, 0)
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

    local content = CreateFrame("Frame", name .. "Content", scrollFrame)
    content:SetWidth(width - 32)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    return scrollFrame, content
end

GUI.GetThemeColor = T
GUI.GetSpacing = S
