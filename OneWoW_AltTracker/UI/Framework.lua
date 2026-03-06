local addonName, ns = ...
local OneWoWAltTracker = OneWoW_AltTracker
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

function ns.UI.CreateScrollFrame(name, parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -5, 5)

    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -3, 0)
        scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -3, 0)
        scrollBar:SetWidth(8)

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

    local contentName = name and (name .. "Content") or nil
    local content = CreateFrame("Frame", contentName, scrollFrame)
    content:SetWidth(width - 20)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    return scrollFrame, content
end

function ns.UI.CreateButton(name, parent, text, width, height)
    local C = ns.Constants.GUI

    local btn = CreateFrame("Button", name, parent, "BackdropTemplate")
    btn:SetSize(width or 100, height or C.BUTTON_HEIGHT)
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

function ns.UI.CreateEditBox(name, parent, width, height)
    local C = ns.Constants.GUI

    local box = CreateFrame("EditBox", name, parent, "BackdropTemplate")
    box:SetSize(width or 200, height or C.SEARCH_HEIGHT)
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

function ns.UI.CreateCheckbox(name, parent, label)
    local checkbox = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24)

    if label then
        local text = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
        text:SetText(label)
        text:SetTextColor(T("TEXT_PRIMARY"))
        checkbox.label = text
    end

    return checkbox
end

function ns.UI.CreateSectionHeader(parent, title, yOffset)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", 8, yOffset)
    section:SetPoint("TOPRIGHT", -8, yOffset)
    section:SetHeight(30)
    section:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    section:SetBackdropColor(T("BG_SECONDARY"))
    section:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local titleText = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", 12, 0)
    titleText:SetText(title)
    titleText:SetTextColor(T("ACCENT_PRIMARY"))

    section.bottomY = yOffset - 30

    return section
end
