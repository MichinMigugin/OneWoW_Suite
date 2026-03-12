local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER = OneWoW_GUI.Constants.BACKDROP_INNER

local GUI = {}
Addon.GUI = GUI

function GUI:CreateButton(name, parent, text, width, height)
    local C = Addon.Constants and Addon.Constants.BUTTON_HEIGHT or 28
    local btn = CreateFrame("Button", name, parent, "BackdropTemplate")
    btn:SetSize(width or 100, height or C)
    btn:SetBackdrop(BACKDROP_INNER)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end)

    btn:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED"))
    end)

    btn:SetScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        else
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        end
    end)

    return btn
end

function GUI:CreateEditBox(name, parent, width, height)
    local C = Addon.Constants and Addon.Constants.SEARCH_HEIGHT or 32
    local box = CreateFrame("EditBox", name, parent, "BackdropTemplate")
    box:SetSize(width or 200, height or C)
    box:SetBackdrop(BACKDROP_INNER)
    box:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    box:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    box:SetFontObject(GameFontHighlight)
    box:SetTextInsets(OneWoW_GUI:GetSpacing("SM") + 2, OneWoW_GUI:GetSpacing("SM"), 0, 0)
    box:SetAutoFocus(false)
    box:EnableMouse(true)
    box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
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
            scrollBar.Background:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        end

        if scrollBar.ThumbTexture then
            scrollBar.ThumbTexture:SetWidth(8)
            scrollBar.ThumbTexture:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        end
    end

    local content = CreateFrame("Frame", name .. "Content", scrollFrame)
    content:SetWidth(width - 32)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    return scrollFrame, content
end

return GUI
