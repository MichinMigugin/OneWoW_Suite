local ADDON_NAME, Addon = ...

local GUI = {}
Addon.GUI = GUI

local function T(key)
    if Addon.Constants and Addon.Constants.THEME and Addon.Constants.THEME[key] then
        return unpack(Addon.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if Addon.Constants and Addon.Constants.SPACING then
        return Addon.Constants.SPACING[key] or 8
    end
    return 8
end

function GUI:CreateButton(name, parent, text, width, height)
    local C = Addon.Constants and Addon.Constants.BUTTON_HEIGHT or 28
    local btn = CreateFrame("Button", name, parent, "BackdropTemplate")
    btn:SetSize(width or 100, height or C)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
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
    local C = Addon.Constants and Addon.Constants.SEARCH_HEIGHT or 32
    local box = CreateFrame("EditBox", name, parent, "BackdropTemplate")
    box:SetSize(width or 200, height or C)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
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

return GUI
