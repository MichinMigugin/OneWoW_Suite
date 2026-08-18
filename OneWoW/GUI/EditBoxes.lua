local OneWoW_GUI = OneWoW_GUI

local CreateFrame = CreateFrame
local unpack = unpack

local Constants = OneWoW_GUI.Constants

local CLEAR_BTN_SIZE = 14
local CLEAR_RIGHT_INSET = 18 -- room for clear button so glyphs don't sit under the X
local MIN_CLEAR_WIDTH = 80 -- narrower fixed-width boxes cannot host the X

--- Attach a clear-X to an EditBox. Hidden when the box is empty or showing
--- placeholderText. Bumps the right text inset so glyphs do not sit under the X.
---@param box EditBox
---@param options table|nil { onClear?: fun(box: EditBox), clearTooltip?: string, adjustInsets?: boolean }
function OneWoW_GUI:AttachClearButton(box, options)
    options = options or {}
    local onClear = options.onClear
    local clearTooltip = options.clearTooltip
    local adjustInsets = options.adjustInsets
    if adjustInsets ~= false then
        local left, right, top, bottom = box:GetTextInsets()
        if right < CLEAR_RIGHT_INSET then
            box:SetTextInsets(left, CLEAR_RIGHT_INSET, top, bottom)
        end
    end

    local clearBtn = CreateFrame("Button", nil, box)
    clearBtn:SetSize(CLEAR_BTN_SIZE, CLEAR_BTN_SIZE)
    clearBtn:SetPoint("RIGHT", box, "RIGHT", -3, 0)
    clearBtn:SetFrameLevel((box:GetFrameLevel() or 0) + 5)
    clearBtn:EnableMouse(true)
    clearBtn:Hide()

    local clearTex = clearBtn:CreateTexture(nil, "ARTWORK")
    clearTex:SetAllPoints()
    -- Client search-box X (grey), not common-icon-redx.
    clearTex:SetAtlas("common-search-clearbutton")
    clearBtn.icon = clearTex

    local function PaintClearIcon(hovered)
        if hovered then
            clearTex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            clearTex:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end
    PaintClearIcon(false)

    clearBtn:SetScript("OnEnter", function(myself)
        PaintClearIcon(true)
        if clearTooltip and clearTooltip ~= "" then
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(clearTooltip, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    clearBtn:SetScript("OnLeave", function()
        PaintClearIcon(false)
        GameTooltip:Hide()
    end)
    clearBtn:SetScript("OnClick", function()
        box:SetText("")
        box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        if box.RestorePlaceholder and box.placeholderText and box.placeholderText ~= "" then
            box:RestorePlaceholder()
        end
        box:ClearFocus()
        box:UpdateClearButton()
        if onClear then
            onClear(box)
        end
    end)

    box.clearButton = clearBtn

    function box:UpdateClearButton()
        local text
        if self.GetSearchText then
            text = self:GetSearchText()
        else
            text = self:GetText() or ""
            local placeholder = self.placeholderText
            if placeholder and placeholder ~= "" and text == placeholder then
                text = ""
            end
        end
        if text ~= "" then
            self.clearButton:Show()
        else
            self.clearButton:Hide()
        end
    end

    -- SetScript("OnTextChanged") replaces the handler and drops HookScripts.
    -- Split-panel tabs do that after create, so wrap SetScript and always
    -- run UpdateClearButton after whatever they install.
    local origSetScript = box.SetScript
    function box:SetScript(handler, script)
        if handler == "OnTextChanged" then
            origSetScript(self, handler, function(myself, userInput)
                if script then
                    script(myself, userInput)
                end
                myself:UpdateClearButton()
            end)
            return
        end
        return origSetScript(self, handler, script)
    end
    box:SetScript("OnTextChanged", box:GetScript("OnTextChanged"))
    box:HookScript("OnEditFocusGained", function(myself)
        myself:UpdateClearButton()
    end)
    box:UpdateClearButton()
end

function OneWoW_GUI:CreateEditBox(parent, options)
    options = options or {}
    local name = options.name
    local width = options.width
    local height = options.height or Constants.GUI.SEARCH_HEIGHT
    local placeholderText = options.placeholderText or ""
    local maxLetters = options.maxLetters
    local onTextChanged = options.onTextChanged
    local onClear = options.onClear
    local showClear = options.showClear
    if showClear == nil then
        showClear = not width or width >= MIN_CLEAR_WIDTH
    end
    local clearTooltip = options.clearTooltip
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

    box:SetScript("OnEscapePressed", function(myself) myself:ClearFocus() end)

    box:SetScript("OnEditFocusGained", function(myself)
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        if myself:GetText() == myself.placeholderText then
            myself:SetText("")
            myself:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end)

    box:SetScript("OnEditFocusLost", function(myself)
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        myself:RestorePlaceholder()
    end)

    function box:RestorePlaceholder()
        if self:GetText() == "" and self.placeholderText and self.placeholderText ~= "" then
            self:SetText(self.placeholderText)
            self:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
        if self.UpdateClearButton then
            self:UpdateClearButton()
        end
    end

    function box:GetSearchText()
        local text = self:GetText()
        if text == self.placeholderText then return "" end
        return text
    end

    if showClear then
        self:AttachClearButton(box, {
            onClear = onClear,
            clearTooltip = clearTooltip,
        })
    end

    if onTextChanged then
        box:HookScript("OnTextChanged", function(myself)
            local text = myself:GetText()
            if text == myself.placeholderText then text = "" end
            onTextChanged(text)
        end)
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

    self:ApplyScrollBarStyle(scrollFrame.ScrollBar, scrollFrame, -2)

    local editBox = CreateFrame("EditBox", name, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(maxLetters)
    editBox:SetHeight(1)
    -- Right inset clears the scrollbar gutter so glyphs do not sit under the thumb.
    local gutter = Constants.GUI.SCROLLBAR_CONTENT_GUTTER or 24
    local rightInset = math.max(ti[2], gutter - 8)
    editBox:SetTextInsets(ti[1], rightInset, ti[3], ti[4])

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

    scrollFrame:HookScript("OnSizeChanged", function(_, w)
        editBox:SetWidth(math.max(1, w - gutter))
    end)

    scrollFrame:HookScript("OnMouseDown", function()
        if editBox:IsEnabled() then
            editBox:SetFocus()
        end
    end)

    -- Keep the caret in view while typing / moving the cursor (Blizzard helpers).
    editBox:SetScript("OnCursorChanged", function(myself, x, y, w, h)
        ScrollingEdit_OnCursorChanged(myself, x, y, w, h)
    end)
    editBox:HookScript("OnUpdate", function(myself, elapsed)
        ScrollingEdit_OnUpdate(myself, elapsed, scrollFrame)
    end)

    editBox:SetScript("OnEscapePressed", function(myself)
        myself:ClearFocus()
        if onEscapePressed then onEscapePressed(myself) end
    end)

    if onTextChanged then
        editBox:SetScript("OnTextChanged", function(myself, userInput)
            onTextChanged(myself, userInput)
        end)
    end

    return scrollFrame, editBox
end
