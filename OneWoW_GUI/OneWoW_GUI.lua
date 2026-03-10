local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local CreateFrame = CreateFrame
local unpack = unpack

local Constants = OneWoW_GUI.Constants
local DEFAULT_THEME = Constants.DEFAULT_THEME
local DEFAULT_THEME_COLOR = DEFAULT_THEME.COLOR
local DEFAULT_THEME_SPACING = DEFAULT_THEME.SPACING
local DEFAULT_ICON_TEXTURE = Constants.ICON_TEXTURES.horde

local _splitPanelCount = 0

local noop = function() end

local themeMetatable = {
    __index = function(self, key)
        return Constants.FALLBACK_THEME[key] or DEFAULT_THEME_COLOR
    end,
    __newindex = noop,
}

local guiConstantsMetatable = {
    __index = function(self, key)
        return Constants.GUI[key] or 0
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

function OneWoW_GUI:RegisterGUIConstants(guiConstants)
    return setmetatable(guiConstants, guiConstantsMetatable)
end

function OneWoW_GUI:GetThemeColor(key)
    return GetThemeColor(key)
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

    local selectedTheme = Constants.THEMES[themeKey] or Constants.THEMES["green"]
    Constants.ACTIVE_THEME = setmetatable(selectedTheme, themeMetatable)
end

function OneWoW_GUI:CreateFrame(name, parent, width, height, backdrop)
    local frame = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetBackdrop(backdrop or Constants.BACKDROP_SOFT)
    frame:SetBackdropColor(GetThemeColor("BG_PRIMARY"))
    frame:SetBackdropBorderColor(GetThemeColor("BORDER_DEFAULT"))
    return frame
end

function OneWoW_GUI:CreateMovableDialog(name, parent, width, height)
    local dialog = OneWoW_GUI:CreateFrame(name, parent, width, height, Constants.BACKDROP_INNER_NO_INSETS)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:SetMovable(true)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
    -- allow ESC to close the dialog
    tinsert(UISpecialFrames, name)
    return dialog
end

function OneWoW_GUI:CreateButton(name, parent, text, width, height)
    local btn = CreateFrame("Button", name, parent, "BackdropTemplate")
    btn:SetSize(width or Constants.GUI.BUTTON_WIDTH, height or Constants.GUI.BUTTON_HEIGHT)
    btn:SetBackdrop(Constants.BACKDROP_INNER)
    btn:SetBackdropColor(GetThemeColor("BTN_NORMAL"))
    btn:SetBackdropBorderColor(GetThemeColor("BTN_BORDER"))

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text or "")
    btn.text:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(GetThemeColor("BTN_HOVER"))
        self:SetBackdropBorderColor(GetThemeColor("BTN_BORDER_HOVER"))
        self.text:SetTextColor(GetThemeColor("TEXT_ACCENT"))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(GetThemeColor("BTN_NORMAL"))
        self:SetBackdropBorderColor(GetThemeColor("BTN_BORDER"))
        self.text:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
    end)
    btn:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(GetThemeColor("BTN_PRESSED"))
    end)
    btn:SetScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            self:SetBackdropColor(GetThemeColor("BTN_HOVER"))
        else
            self:SetBackdropColor(GetThemeColor("BTN_NORMAL"))
        end
    end)

    return btn
end

function OneWoW_GUI:CreateFitTextButton(parent, text, options)
    options = options or {}
    local height = options.height or Constants.GUI.BUTTON_HEIGHT
    local minWidth = options.minWidth or 40
    local paddingX = options.paddingX or 24

    local btn = self:CreateButton(nil, parent, text, minWidth, height)
    local textWidth = btn.text:GetStringWidth()
    local finalWidth = math.max(minWidth, textWidth + paddingX)
    btn:SetWidth(finalWidth)

    btn._minWidth = minWidth
    btn._paddingX = paddingX

    function btn:SetFitText(newText)
        self.text:SetText(newText)
        local w = self.text:GetStringWidth()
        self:SetWidth(math.max(self._minWidth, w + self._paddingX))
    end

    return btn
end

function OneWoW_GUI:CreateFitFrameButtons(parent, yOffset, items, options)
    options = options or {}
    local height = options.height or 26
    local gap = options.gap or 4
    local marginX = options.marginX or 12
    local onSelect = options.onSelect
    local availWidth = (options.width or parent:GetWidth()) - (marginX * 2)
    local n = #items
    local bw = math.max(30, math.floor((availWidth - gap * (n - 1)) / n))

    local buttons = {}

    local function applyNormal(btn)
        if btn.isActive then
            btn:SetBackdropColor(GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(GetThemeColor("BORDER_ACCENT"))
            btn.text:SetTextColor(GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(GetThemeColor("BTN_NORMAL"))
            btn:SetBackdropBorderColor(GetThemeColor("BTN_BORDER"))
            btn.text:SetTextColor(GetThemeColor("TEXT_MUTED"))
        end
    end

    local function applyHover(btn)
        if btn.isActive then
            btn:SetBackdropBorderColor(GetThemeColor("BORDER_FOCUS"))
        else
            btn:SetBackdropColor(GetThemeColor("BTN_HOVER"))
            btn:SetBackdropBorderColor(GetThemeColor("BTN_BORDER_HOVER"))
            btn.text:SetTextColor(GetThemeColor("TEXT_SECONDARY"))
        end
    end

    local xPos = marginX
    local rowY = yOffset

    for i, item in ipairs(items) do
        local btn = self:CreateButton(nil, parent, item.text, bw, height)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xPos, rowY)
        btn.itemValue = item.value
        btn.isActive = item.isActive or false

        applyNormal(btn)

        btn:SetScript("OnEnter", function(self) applyHover(self) end)
        btn:SetScript("OnLeave", function(self) applyNormal(self) end)
        btn:SetScript("OnMouseDown", function(self) self:SetBackdropColor(GetThemeColor("BTN_PRESSED")) end)
        btn:SetScript("OnMouseUp", function(self) applyNormal(self) end)
        btn:SetScript("OnClick", function(self)
            for _, ob in ipairs(buttons) do
                ob.isActive = (ob == self)
                applyNormal(ob)
            end
            if onSelect then
                onSelect(self.itemValue, item.text, self)
            end
        end)

        table.insert(buttons, btn)
        xPos = xPos + bw + gap

        if i < n and (xPos + bw) > (availWidth + marginX) then
            xPos = marginX
            rowY = rowY - height - gap
        end
    end

    local finalY = rowY - height

    buttons.SetActiveByValue = function(value)
        for _, btn in ipairs(buttons) do
            btn.isActive = (btn.itemValue == value)
            applyNormal(btn)
        end
    end

    return buttons, finalY
end

function OneWoW_GUI:CreateOnOffToggleButtons(parent, yOffset, onLabel, offLabel, width, height, isEnabled, value, onValueChange)
    width = width or Constants.TOGGLE_BUTTON_WIDTH
    height = height or Constants.TOGGLE_BUTTON_HEIGHT

    local onBtn = self:CreateFitTextButton(parent, onLabel, { height = height, minWidth = width })
    local offBtn = self:CreateFitTextButton(parent, offLabel, { height = height, minWidth = width })

    local maxW = math.max(onBtn:GetWidth(), offBtn:GetWidth())
    onBtn:SetWidth(maxW)
    offBtn:SetWidth(maxW)

    local statusPfx = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusPfx:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    statusPfx:SetText("Status:")
    statusPfx:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

    local statusVal = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusVal:SetPoint("LEFT", statusPfx, "RIGHT", 4, 0)

    onBtn:SetPoint("LEFT", statusVal, "RIGHT", 10, 0)
    offBtn:SetPoint("LEFT", onBtn, "RIGHT", 4, 0)

    local function applyHover(btn)
        if btn.isActive then
            btn:SetBackdropColor(GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(GetThemeColor("BORDER_FOCUS"))
            btn.text:SetTextColor(GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(GetThemeColor("BTN_HOVER"))
            btn:SetBackdropBorderColor(GetThemeColor("BTN_BORDER_HOVER"))
            btn.text:SetTextColor(GetThemeColor("TEXT_SECONDARY"))
        end
    end

    local function applyNormal(btn)
        if btn.isActive then
            btn:SetBackdropColor(GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(GetThemeColor("BORDER_ACCENT"))
            btn.text:SetTextColor(GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(GetThemeColor("BTN_NORMAL"))
            btn:SetBackdropBorderColor(GetThemeColor("BTN_BORDER"))
            btn.text:SetTextColor(GetThemeColor("TEXT_MUTED"))
        end
    end

    for _, btn in ipairs({ onBtn, offBtn }) do
        btn:SetScript("OnEnter", function(self) applyHover(self) end)
        btn:SetScript("OnLeave", function(self) applyNormal(self) end)
        btn:SetScript("OnMouseDown", function(self) self:SetBackdropColor(GetThemeColor("BTN_PRESSED")) end)
        btn:SetScript("OnMouseUp", function(self) applyNormal(self) end)
    end

    local function refresh(enabled, val)
        isEnabled = enabled
        if not onBtn:GetParent() or not offBtn:GetParent() then
            return
        end
        enabled = enabled == true
        val = val == true
        onBtn.isActive = enabled and val
        offBtn.isActive = enabled and not val
        onBtn:EnableMouse(enabled)
        offBtn:EnableMouse(enabled)
        if not enabled then
            onBtn:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
            onBtn:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
            offBtn:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
            offBtn:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
            onBtn.text:SetTextColor(GetThemeColor("TEXT_MUTED"))
            offBtn.text:SetTextColor(GetThemeColor("TEXT_MUTED"))
            statusPfx:SetTextColor(GetThemeColor("TEXT_MUTED"))
            statusVal:SetText(val and onLabel or offLabel)
            statusVal:SetTextColor(GetThemeColor("TEXT_MUTED"))
        else
            applyNormal(onBtn)
            applyNormal(offBtn)
            statusPfx:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
            if val then
                statusVal:SetText(onLabel)
                statusVal:SetTextColor(GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                statusVal:SetText(offLabel)
                statusVal:SetTextColor(GetThemeColor("TEXT_FEATURES_DISABLED"))
            end
        end
    end

    onBtn:SetScript("OnClick", function()
        onValueChange(true)
        refresh(isEnabled, true)
        C_Timer.After(0, function()
            if onBtn:GetParent() and offBtn:GetParent() then
                if onBtn:IsMouseOver() then
                    applyHover(onBtn)
                elseif offBtn:IsMouseOver() then
                    applyHover(offBtn)
                end
            end
        end)
    end)
    offBtn:SetScript("OnClick", function()
        onValueChange(false)
        refresh(isEnabled, false)
        C_Timer.After(0, function()
            if onBtn:GetParent() and offBtn:GetParent() then
                if onBtn:IsMouseOver() then
                    applyHover(onBtn)
                elseif offBtn:IsMouseOver() then
                    applyHover(offBtn)
                end
            end
        end)
    end)

    refresh(isEnabled, value)
    return onBtn, offBtn, refresh, statusPfx, statusVal
end

--[[
    TODO: Pass in onTextChanged callback or a filter function to use in onTextChanged event
]]
function OneWoW_GUI:CreateEditBox(name, parent, options)
    local options = options or {}
    local width = options.width or Constants.GUI.SEARCH_WIDTH
    local height = options.height or Constants.GUI.SEARCH_HEIGHT
    local placeholderText = options.placeholderText or ""
    local maxLetters = options.maxLetters or nil
    local spacing = GetSpacing("SM")

    local box = CreateFrame("EditBox", name, parent, "BackdropTemplate")
    box.placeholderText = placeholderText

    box:SetSize(width, height)
    box:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    box:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
    box:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
    box:SetFontObject(GameFontHighlight)
    box:SetTextInsets(spacing, spacing, 0, 0)
    box:SetAutoFocus(false)
    box:EnableMouse(true)
    box:SetTextColor(GetThemeColor("TEXT_MUTED"))
    box:SetText(placeholderText)

    if maxLetters then
        box:SetMaxLetters(maxLetters)
    end

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(GetThemeColor("BORDER_ACCENT"))

        if self:GetText() == self.placeholderText then
            self:SetText("")
            self:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
        end
    end)

    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))

        if self:GetText() == "" then
            self:SetText(self.placeholderText)
            self:SetTextColor(GetThemeColor("TEXT_MUTED"))
        end
    end)

    return box
end

function OneWoW_GUI:CreateSearchBox(parent, options)
    options = options or {}
    local height = options.height or Constants.GUI.SEARCH_HEIGHT
    local placeholderText = options.placeholderText or ""
    local onTextChanged = options.onTextChanged

    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box.placeholderText = placeholderText
    box:SetHeight(height)
    box:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    box:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
    box:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
    box:SetFontObject(GameFontHighlight)
    box:SetTextInsets(GetSpacing("SM"), GetSpacing("SM"), 0, 0)
    box:SetAutoFocus(false)
    box:EnableMouse(true)
    box:SetTextColor(GetThemeColor("TEXT_MUTED"))
    box:SetText(placeholderText)

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(GetThemeColor("BORDER_ACCENT"))
        if self:GetText() == self.placeholderText then
            self:SetText("")
            self:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
        end
    end)

    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
        if self:GetText() == "" then
            self:SetText(self.placeholderText)
            self:SetTextColor(GetThemeColor("TEXT_MUTED"))
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

function OneWoW_GUI:CreateStatusDot(parent, options)
    options = options or {}
    local size = options.size or 8

    local dot = parent:CreateTexture(nil, "OVERLAY")
    dot:SetSize(size, size)
    dot:SetTexture("Interface\\Buttons\\WHITE8x8")

    if options.enabled == true then
        dot:SetVertexColor(GetThemeColor("DOT_FEATURES_ENABLED"))
    elseif options.enabled == false then
        dot:SetVertexColor(GetThemeColor("DOT_FEATURES_DISABLED"))
    end

    function dot:SetStatus(enabled)
        if enabled then
            self:SetVertexColor(GetThemeColor("DOT_FEATURES_ENABLED"))
        else
            self:SetVertexColor(GetThemeColor("DOT_FEATURES_DISABLED"))
        end
    end

    return dot
end

function OneWoW_GUI:CreateListRowBasic(parent, options)
    options = options or {}
    local height = options.height or 30
    local labelText = options.label or ""
    local onClick = options.onClick
    local showDot = options.showDot
    local dotEnabled = options.dotEnabled
    local showValueText = options.showValueText
    local valueText = options.valueText or ""

    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(height)
    row:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    row:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
    row:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
    row.isActive = false

    if showDot then
        row.dot = self:CreateStatusDot(row, { enabled = dotEnabled })
        row.dot:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    end

    if showValueText then
        row.valueText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.valueText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.valueText:SetTextColor(GetThemeColor("TEXT_MUTED"))
        row.valueText:SetJustifyH("RIGHT")
        row.valueText:SetText(valueText)
    end

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", row, "LEFT", 10, 0)
    if showDot then
        row.label:SetPoint("RIGHT", row, "RIGHT", -24, 0)
    elseif showValueText and row.valueText then
        row.label:SetPoint("RIGHT", row.valueText, "LEFT", -4, 0)
    else
        row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    end
    row.label:SetJustifyH("LEFT")
    row.label:SetText(labelText)
    row.label:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

    function row:SetActive(active)
        self.isActive = active
        if active then
            self:SetBackdropColor(GetThemeColor("BG_ACTIVE"))
            self:SetBackdropBorderColor(GetThemeColor("BORDER_ACCENT"))
            self.label:SetTextColor(GetThemeColor("TEXT_ACCENT"))
        else
            self:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
            self:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
            self.label:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
        end
    end

    row:SetScript("OnEnter", function(self)
        if not self.isActive then
            self:SetBackdropColor(GetThemeColor("BG_HOVER"))
            self.label:SetTextColor(GetThemeColor("TEXT_ACCENT"))
        end
    end)
    row:SetScript("OnLeave", function(self)
        if not self.isActive then
            self:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
            self.label:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
        end
    end)

    if onClick then
        row:SetScript("OnClick", function(self) onClick(self) end)
    end

    return row
end

function OneWoW_GUI:CreateCheckbox(name, parent, label)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetSize(Constants.GUI.CHECKBOX_SIZE, Constants.GUI.CHECKBOX_SIZE)

    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.label:SetPoint("LEFT", cb, "RIGHT", GetSpacing("XS"), 0)
    cb.label:SetText(label)
    cb.label:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

    return cb
end

function OneWoW_GUI:CreateHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", GetSpacing("MD"), yOffset or -GetSpacing("MD"))
    header:SetText(text)
    header:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))
    return header
end

function OneWoW_GUI:CreateDivider(parent, yOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("LEFT", GetSpacing("MD"), 0)
    divider:SetPoint("RIGHT", -GetSpacing("MD"), 0)
    divider:SetPoint("TOP", 0, yOffset)
    divider:SetColorTexture(GetThemeColor("BORDER_SUBTLE"))
    return divider
end

function OneWoW_GUI:CreateSection(parent, title, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", GetSpacing("MD"), yOffset)
    header:SetText(title)
    header:SetTextColor(GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - header:GetStringHeight() - 6

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", GetSpacing("MD"), yOffset)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -GetSpacing("MD"), yOffset)
    divider:SetColorTexture(GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    return yOffset
end

function OneWoW_GUI:CreateTitleBar(parent, title, options)
    options = options or {}
    local height = options.height or 20
    local onClose = options.onClose
    local showBrand = options.showBrand

    local titleBg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    titleBg:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
    titleBg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
    titleBg:SetHeight(height)
    titleBg:SetBackdrop(Constants.BACKDROP_SIMPLE)
    titleBg:SetBackdropColor(GetThemeColor("TITLEBAR_BG"))
    titleBg:SetFrameLevel(parent:GetFrameLevel() + 1)

    titleBg._titleText = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    
    if showBrand then
        local factionTheme = options.factionTheme or "horde"
        local brandIcon = titleBg:CreateTexture(nil, "OVERLAY")
        brandIcon:SetSize(14, 14)
        brandIcon:SetPoint("LEFT", titleBg, "LEFT", GetSpacing("SM"), 0)
        brandIcon:SetTexture(self:GetBrandIcon(factionTheme))
        titleBg.brandIcon = brandIcon

        local brandText = titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        brandText:SetPoint("LEFT", brandIcon, "RIGHT", 4, 0)
        brandText:SetText("OneWoW")
        brandText:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))
        
        titleBg._titleText:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
        titleBg._titleText:SetText(title)
        titleBg._titleText:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
    else
        titleBg._titleText:SetPoint("LEFT", titleBg, "LEFT", GetSpacing("MD"), 0)
        titleBg._titleText:SetText(title)
        titleBg._titleText:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))
    end

    if onClose then
        local closeBtn = self:CreateButton(nil, titleBg, "X", 20, 20)
        closeBtn:SetPoint("RIGHT", titleBg, "RIGHT", -GetSpacing("XS") / 2, 0)
        closeBtn:SetScript("OnClick", onClose)
    end

    return titleBg
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

function OneWoW_GUI:StyleScrollBar(scrollFrame, options)
    local opt = options or {}
    local scrollBar = scrollFrame.ScrollBar
    if not scrollBar then return end
    local container = opt.container or scrollFrame
    local offset = opt.offset or -2
    applyScrollBarStyle(scrollBar, container, offset)
end

function OneWoW_GUI:CreateScrollFrame(name, parent)
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)

    applyScrollBarStyle(scrollFrame.ScrollBar, parent, -2)

    local content = CreateFrame("Frame", name .. "Content", scrollFrame)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        content:SetWidth(w)
    end)

    return scrollFrame, content
end

function OneWoW_GUI:CreateSplitPanel(parent, options)
    local panelGap = Constants.GUI.PANEL_GAP or 10

    local backdrop = {
        bgFile = Constants.BACKDROP_INNER.bgFile,
        edgeFile = Constants.BACKDROP_INNER.edgeFile,
        edgeSize = Constants.BACKDROP_INNER.edgeSize
    }

    options = options or {}
    local showSearch = options.showSearch

    _splitPanelCount = _splitPanelCount + 1
    local uid = _splitPanelCount

    local listPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    listPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 35)
    listPanel:SetWidth(Constants.GUI.LEFT_PANEL_WIDTH)
    listPanel:SetBackdrop(backdrop)
    listPanel:SetBackdropColor(GetThemeColor("BG_PRIMARY"))
    listPanel:SetBackdropBorderColor(GetThemeColor("BORDER_DEFAULT"))

    local listTitle = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 10, -10)
    listTitle:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -10, -10)
    listTitle:SetJustifyH("LEFT")
    listTitle:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))

    local searchBox
    if showSearch then
        searchBox = self:CreateSearchBox(listPanel, {
            placeholderText = options.searchPlaceholder or "",
        })
        searchBox:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 8, -30)
        searchBox:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -8, -30)
    end

    local containerTopY = showSearch and -58 or -32
    local listContainer = CreateFrame("Frame", nil, listPanel)
    listContainer:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 8, containerTopY)
    listContainer:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -8, 8)

    local listScrollFrame = CreateFrame("ScrollFrame", "OneWoWGUI_Split_List" .. uid, listContainer, "UIPanelScrollFrameTemplate")
    listScrollFrame:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, 0)
    listScrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -14, 0)
    listScrollFrame:EnableMouseWheel(true)

    applyScrollBarStyle(listScrollFrame.ScrollBar, listContainer, -2)

    local listScrollChild = CreateFrame("Frame", "OneWoWGUI_Split_ListContent" .. uid, listScrollFrame)
    listScrollChild:SetHeight(1)
    listScrollFrame:SetScrollChild(listScrollChild)
    listScrollFrame:HookScript("OnSizeChanged", function(self, w)
        listScrollChild:SetWidth(w)
    end)

    local detailPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    detailPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", panelGap, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 35)
    detailPanel:SetBackdrop(backdrop)
    detailPanel:SetBackdropColor(GetThemeColor("BG_PRIMARY"))
    detailPanel:SetBackdropBorderColor(GetThemeColor("BORDER_DEFAULT"))

    local detailTitle = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailTitle:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 10, -10)
    detailTitle:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -10, -10)
    detailTitle:SetJustifyH("LEFT")
    detailTitle:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))

    local detailContainer = CreateFrame("Frame", nil, detailPanel)
    detailContainer:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 8, -32)
    detailContainer:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8, 8)

    local detailScrollFrame = CreateFrame("ScrollFrame", "OneWoWGUI_Split_Detail" .. uid, detailContainer, "UIPanelScrollFrameTemplate")
    detailScrollFrame:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 0, 0)
    detailScrollFrame:SetPoint("BOTTOMRIGHT", detailContainer, "BOTTOMRIGHT", -14, 0)
    detailScrollFrame:EnableMouseWheel(true)

    applyScrollBarStyle(detailScrollFrame.ScrollBar, detailContainer, -2)

    local detailScrollChild = CreateFrame("Frame", "OneWoWGUI_Split_DetailContent" .. uid, detailScrollFrame)
    detailScrollChild:SetHeight(1)
    detailScrollFrame:SetScrollChild(detailScrollChild)
    detailScrollFrame:HookScript("OnSizeChanged", function(self, w)
        detailScrollChild:SetWidth(w)
    end)

    local leftStatusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    leftStatusBar:SetPoint("TOPLEFT", listPanel, "BOTTOMLEFT", 0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)
    leftStatusBar:SetBackdrop(backdrop)
    leftStatusBar:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
    leftStatusBar:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))

    local leftStatusText = leftStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(GetThemeColor("TEXT_SECONDARY"))
    leftStatusText:SetText("")

    local rightStatusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rightStatusBar:SetPoint("TOPLEFT", detailPanel, "BOTTOMLEFT", 0, -5)
    rightStatusBar:SetPoint("TOPRIGHT", detailPanel, "BOTTOMRIGHT", 0, -5)
    rightStatusBar:SetHeight(25)
    rightStatusBar:SetBackdrop(backdrop)
    rightStatusBar:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
    rightStatusBar:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))

    local rightStatusText = rightStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
    rightStatusText:SetTextColor(GetThemeColor("TEXT_SECONDARY"))
    rightStatusText:SetText("")

    return {
        listPanel = listPanel,
        listTitle = listTitle,
        listScrollFrame = listScrollFrame,
        listScrollChild = listScrollChild,
        UpdateListThumb = noop,
        detailPanel = detailPanel,
        detailTitle = detailTitle,
        detailScrollFrame = detailScrollFrame,
        detailScrollChild = detailScrollChild,
        UpdateDetailThumb = noop,
        searchBox = searchBox,
        leftStatusBar = leftStatusBar,
        leftStatusText = leftStatusText,
        rightStatusBar = rightStatusBar,
        rightStatusText = rightStatusText,
    }
end

function OneWoW_GUI:CreateDropdown(parent, options)
    options = options or {}
    local width = options.width or 200
    local height = options.height or 26
    local defaultText = options.text or ""

    local dropdown = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dropdown:SetSize(width, height)
    dropdown:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    dropdown:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
    dropdown:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))

    local text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    text:SetPoint("RIGHT", dropdown, "RIGHT", -20, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(defaultText)
    text:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

    local arrow = dropdown:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", dropdown, "RIGHT", -4, 0)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    dropdown:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(GetThemeColor("BORDER_FOCUS"))
    end)
    dropdown:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
    end)

    dropdown._text = text
    dropdown._activeValue = nil

    return dropdown, text
end

local _dropdownMenuCount = 0

function OneWoW_GUI:AttachFilterMenu(dropdown, dropdownText, options)
    options = options or {}
    local searchable = options.searchable ~= false
    local buildItems = options.buildItems
    local onSelect = options.onSelect
    local maxVisible = options.maxVisible or 20
    local menuHeight = options.menuHeight or 314
    local getActiveValue = options.getActiveValue

    dropdown:SetScript("OnClick", function(self)
        if self._menu and self._menu:IsShown() then
            self._menu:Hide()
            return
        end

        local items = buildItems and buildItems() or {}

        _dropdownMenuCount = _dropdownMenuCount + 1
        local uid = _dropdownMenuCount

        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        self._menu = menu
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetSize(self:GetWidth() + 20, menuHeight)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
        menu:SetBackdropColor(GetThemeColor("BG_SECONDARY"))
        menu:SetBackdropBorderColor(GetThemeColor("BORDER_DEFAULT"))
        menu:EnableMouse(true)

        local searchBox
        local contentTopY = -2

        if searchable then
            searchBox = CreateFrame("EditBox", nil, menu, "BackdropTemplate")
            searchBox:SetSize(menu:GetWidth() - 15, 28)
            searchBox:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
            searchBox:SetBackdrop(Constants.BACKDROP_INNER)
            searchBox:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
            searchBox:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
            searchBox:SetFontObject(GameFontHighlight)
            searchBox:SetTextInsets(8, 8, 0, 0)
            searchBox:SetAutoFocus(false)
            searchBox:SetMaxLetters(50)
            searchBox:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
            searchBox:SetScript("OnEditFocusGained", function(s)
                s:SetBackdropBorderColor(GetThemeColor("BORDER_FOCUS"))
            end)
            searchBox:SetScript("OnEditFocusLost", function(s)
                s:SetBackdropBorderColor(GetThemeColor("BORDER_SUBTLE"))
            end)

            local separator = menu:CreateTexture(nil, "ARTWORK")
            separator:SetSize(menu:GetWidth() - 4, 1)
            separator:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -32)
            separator:SetColorTexture(GetThemeColor("BORDER_DEFAULT"))

            contentTopY = -36
        end

        local scrollContainer = CreateFrame("Frame", nil, menu)
        scrollContainer:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, contentTopY)
        scrollContainer:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -2, 2)

        local scrollFrame = CreateFrame("ScrollFrame", "OneWoWGUI_DropMenu_" .. uid, scrollContainer, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", 0, 0)
        scrollFrame:EnableMouseWheel(true)

        applyScrollBarStyle(scrollFrame.ScrollBar, scrollContainer, -2)

        local scrollChild = CreateFrame("Frame", "OneWoWGUI_DropMenuContent_" .. uid, scrollFrame)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)
        scrollFrame:HookScript("OnSizeChanged", function(sf, w)
            scrollChild:SetWidth(w)
        end)

        local elements = {}
        local activeValue = getActiveValue and getActiveValue() or dropdown._activeValue

        for _, item in ipairs(items) do
            local itemType = item.type or "item"

            if itemType == "header" then
                local header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                header:SetText(item.text)
                header:SetTextColor(GetThemeColor("ACCENT_PRIMARY"))
                table.insert(elements, { frame = header, type = "header", height = 24 })

            elseif itemType == "divider" then
                local divider = scrollChild:CreateTexture(nil, "ARTWORK")
                divider:SetHeight(1)
                divider:SetColorTexture(GetThemeColor("BORDER_SUBTLE"))
                table.insert(elements, { frame = divider, type = "divider", height = 10 })

            elseif itemType == "checkbox" then
                local row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                row:SetHeight(26)
                row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                row:SetBackdropColor(0, 0, 0, 0)

                local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                cb:SetSize(18, 18)
                cb:SetPoint("LEFT", row, "LEFT", 4, 0)
                cb:SetChecked(item.checked or false)

                local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
                label:SetText(item.text)
                label:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

                row:SetScript("OnEnter", function(r)
                    r:SetBackdropColor(GetThemeColor("BG_HOVER"))
                    label:SetTextColor(GetThemeColor("TEXT_ACCENT"))
                end)
                row:SetScript("OnLeave", function(r)
                    r:SetBackdropColor(0, 0, 0, 0)
                    label:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
                end)

                local onToggle = item.onToggle
                cb:SetScript("OnClick", function(c)
                    if onToggle then onToggle(c:GetChecked()) end
                end)
                row:SetScript("OnClick", function()
                    cb:SetChecked(not cb:GetChecked())
                    if onToggle then onToggle(cb:GetChecked()) end
                end)

                row.checkbox = cb
                table.insert(elements, { frame = row, type = "checkbox", height = 26 })

            else
                local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                btn:SetSize(scrollChild:GetWidth() or (menu:GetWidth() - 20), 26)
                btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })

                if activeValue == item.value then
                    btn:SetBackdropColor(GetThemeColor("ACCENT_PRIMARY"))
                else
                    btn:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
                end

                local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                txt:SetPoint("LEFT", btn, "LEFT", 8, 0)
                txt:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
                txt:SetJustifyH("LEFT")
                txt:SetText(item.text)
                txt:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

                btn:SetScript("OnEnter", function(b)
                    if activeValue ~= item.value then
                        b:SetBackdropColor(GetThemeColor("BG_HOVER"))
                        txt:SetTextColor(GetThemeColor("TEXT_ACCENT"))
                    end
                end)
                btn:SetScript("OnLeave", function(b)
                    if activeValue ~= item.value then
                        b:SetBackdropColor(GetThemeColor("BG_TERTIARY"))
                        txt:SetTextColor(GetThemeColor("TEXT_PRIMARY"))
                    end
                end)
                btn:SetScript("OnClick", function()
                    menu:Hide()
                    dropdown._activeValue = item.value
                    if onSelect then
                        onSelect(item.value, item.text)
                    end
                end)

                btn.filterKey = item.text:lower()
                btn:Hide()
                table.insert(elements, { frame = btn, type = "item", height = 28, filterKey = btn.filterKey })
            end
        end

        local function renderList(filter)
            local yPos = -2
            local shown = 0
            local isFiltering = filter ~= ""
            for _, elem in ipairs(elements) do
                if isFiltering and elem.type ~= "item" then
                    elem.frame:Hide()
                elseif elem.type == "item" then
                    if not isFiltering or string.find(elem.filterKey, filter, 1, true) then
                        if shown < maxVisible or isFiltering then
                            elem.frame:ClearAllPoints()
                            elem.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, yPos)
                            elem.frame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -2, yPos)
                            elem.frame:Show()
                            yPos = yPos - elem.height
                            shown = shown + 1
                        else
                            elem.frame:Hide()
                        end
                    else
                        elem.frame:Hide()
                    end
                elseif elem.type == "header" then
                    elem.frame:ClearAllPoints()
                    elem.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, yPos - 4)
                    elem.frame:Show()
                    yPos = yPos - elem.height
                elseif elem.type == "divider" then
                    elem.frame:ClearAllPoints()
                    elem.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, yPos - 4)
                    elem.frame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -8, yPos - 4)
                    elem.frame:Show()
                    yPos = yPos - elem.height
                elseif elem.type == "checkbox" then
                    elem.frame:ClearAllPoints()
                    elem.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, yPos)
                    elem.frame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -2, yPos)
                    elem.frame:Show()
                    yPos = yPos - elem.height
                end
            end
            local totalH = math.max(28, math.abs(yPos) + 2)
            scrollChild:SetHeight(totalH)
        end

        renderList("")

        if searchBox then
            searchBox:SetScript("OnTextChanged", function(s)
                renderList(s:GetText():lower())
            end)
            searchBox:SetScript("OnEscapePressed", function(s)
                if s:GetText() ~= "" then
                    s:SetText("")
                    renderList("")
                else
                    menu:Hide()
                end
            end)
        end

        menu:SetScript("OnShow", function(m)
            local timeOutside = 0
            m:SetScript("OnUpdate", function(m2, elapsed)
                if not MouseIsOver(menu) and not MouseIsOver(self) and (not searchBox or not searchBox:HasFocus()) then
                    timeOutside = timeOutside + elapsed
                    if timeOutside > 0.5 then
                        m2:Hide()
                        m2:SetScript("OnUpdate", nil)
                    end
                else
                    timeOutside = 0
                end
            end)
        end)

        menu:Show()
        if searchBox then
            searchBox:SetFocus()
        end
    end)
end

function OneWoW_GUI:CreateSlider(parent, minVal, maxVal, step, currentVal, onChange, width, fmt)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width or 200, 36)

    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT",  container, "TOPLEFT",  0,   0)
    slider:SetPoint("TOPRIGHT", container, "TOPRIGHT", -40, 0)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetValue(currentVal)
    slider:SetObeyStepOnDrag(true)

    local valLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valLabel:SetPoint("LEFT", slider, "RIGHT", 6, 0)
    valLabel:SetText(string.format(fmt or "%.1f", currentVal))
    valLabel:SetTextColor(GetThemeColor("TEXT_PRIMARY"))

    if slider.Low  then slider.Low:SetText(tostring(minVal)) end
    if slider.High then slider.High:SetText(tostring(maxVal)) end
    if slider.Text then slider.Text:SetText("") end

    slider:SetScript("OnValueChanged", function(self, val)
        local rounded = math.floor(val / step + 0.5) * step
        rounded = math.max(minVal, math.min(maxVal, rounded))
        valLabel:SetText(string.format(fmt or "%.1f", rounded))
        onChange(rounded)
    end)

    return container
end

function OneWoW_GUI:ClearFrame(frame)
    if not frame then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        region:Hide()
    end
end
