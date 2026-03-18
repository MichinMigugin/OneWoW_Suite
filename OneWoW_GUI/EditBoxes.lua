local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local CreateFrame = CreateFrame
local unpack = unpack

local Constants = OneWoW_GUI.Constants

function OneWoW_GUI:CreateEditBox(parent, options)
    options = options or {}
    local name = options.name
    local width = options.width
    local height = options.height or Constants.GUI.SEARCH_HEIGHT
    local placeholderText = options.placeholderText or ""
    local maxLetters = options.maxLetters
    local onTextChanged = options.onTextChanged
    local spacing = OneWoW_GUI:GetSpacing("SM")

    local box = CreateFrame("EditBox", name, parent, "BackdropTemplate")
    box.placeholderText = placeholderText

    if width then
        box:SetSize(width, height)
    else
        box:SetHeight(height)
    end
    box:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    box:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    box:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    box:SetFontObject(GameFontHighlight)
    box:SetTextInsets(spacing, spacing, 0, 0)
    box:SetAutoFocus(false)
    box:EnableMouse(true)
    box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    box:SetText(placeholderText)

    if maxLetters then
        box:SetMaxLetters(maxLetters)
    end

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        if self:GetText() == self.placeholderText then
            self:SetText("")
            self:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end)

    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        if self:GetText() == "" then
            self:SetText(self.placeholderText)
            self:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end)

    if onTextChanged then
        box:SetScript("OnTextChanged", function(self)
            local text = self:GetText()
            if text == self.placeholderText then text = "" end
            onTextChanged(text)
        end)
    end

    function box:GetSearchText()
        local text = self:GetText()
        if text == self.placeholderText then return "" end
        return text
    end

    return box
end

function OneWoW_GUI:CreateScrollEditBox(parent, options)
    options = options or {}
    local name            = options.name
    local fontSize        = options.fontSize or 12
    local fontFlags       = options.fontFlags or ""
    local maxLetters      = options.maxLetters or 0
    local onTextChanged   = options.onTextChanged
    local onEscapePressed = options.onEscapePressed
    local ti              = options.textInsets or { 4, 4, 4, 4 }

    local scrollFrame = CreateFrame("ScrollFrame", name and (name .. "Scroll") or nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)
    scrollFrame:EnableMouse(true)
    scrollFrame:EnableMouseWheel(true)

    self:ApplyScrollBarStyle(scrollFrame.ScrollBar, parent, -2)

    local editBox = CreateFrame("EditBox", name, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(maxLetters)
    editBox:SetHeight(1)
    editBox:SetTextInsets(ti[1], ti[2], ti[3], ti[4])

    local resolvedFont = options.font or self:GetFont()
    if resolvedFont then
        editBox:SetFont(resolvedFont, fontSize, fontFlags)
    else
        editBox:SetFontObject(ChatFontNormal)
    end

    if options.textColor then
        editBox:SetTextColor(unpack(options.textColor))
    else
        editBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end

    scrollFrame:SetScrollChild(editBox)

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        editBox:SetWidth(math.max(1, w))
    end)

    scrollFrame:HookScript("OnMouseDown", function()
        editBox:SetFocus()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if onEscapePressed then onEscapePressed(self) end
    end)

    if onTextChanged then
        editBox:SetScript("OnTextChanged", function(self, userInput)
            onTextChanged(self, userInput)
        end)
    end

    return scrollFrame, editBox
end
