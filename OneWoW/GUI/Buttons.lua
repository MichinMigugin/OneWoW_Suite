local OneWoW_GUI = OneWoW_GUI

local CreateFrame = CreateFrame
local ceil = math.ceil
local tinsert = tinsert

local Constants = OneWoW_GUI.Constants

function OneWoW_GUI:CreateButton(parent, options)
    options = options or {}
    local name = options.name
    local text = options.text or ""
    local width = options.width or Constants.GUI.BUTTON_WIDTH
    local height = options.height or Constants.GUI.BUTTON_HEIGHT
    local btn = CreateFrame("Button", name, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop(Constants.BACKDROP_INNER)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SetFontBaseSize(btn.text, 12)
    OneWoW_GUI:SafeSetFont(btn.text, OneWoW_GUI:GetFont(), 12)
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local function applyEnabledChrome(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end

    local function applyDisabledChrome(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    btn:SetScript("OnEnter", function(myself)
        if not myself:IsEnabled() then return end
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    end)
    btn:SetScript("OnLeave", function(myself)
        if myself:IsEnabled() then
            applyEnabledChrome(myself)
        else
            applyDisabledChrome(myself)
        end
    end)
    btn:SetScript("OnMouseDown", function(myself)
        if not myself:IsEnabled() then return end
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED"))
    end)
    btn:SetScript("OnMouseUp", function(myself)
        if not myself:IsEnabled() then return end
        if myself:IsMouseOver() then
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        else
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        end
    end)

    local widgetSetEnabled = btn.SetEnabled
    function btn:SetEnabled(enabled)
        widgetSetEnabled(self, enabled and true or false)
        if enabled then
            applyEnabledChrome(self)
        else
            applyDisabledChrome(self)
        end
    end

    return btn
end

-- Plated icon button (CreateButton chrome). Prefer CreateIconButton for
-- row/header actions; keep this for title-bar clusters that sit on a bar.
function OneWoW_GUI:CreateAtlasIconButton(parent, options)
    options = options or {}
    local atlas = options.atlas
    if not atlas then
        return nil
    end
    local width = options.width or 20
    local height = options.height or 20
    local inset = options.iconInset or 2
    local name = options.name
    local btn = self:CreateButton(parent, { name = name, text = " ", width = width, height = height })
    btn.text:Hide()
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
    icon:SetAtlas(atlas)
    btn.icon = icon
    return btn
end

-- Plated icon button (CreateButton chrome). Prefer CreateIconButton for
-- row/header actions; keep this for title-bar clusters that sit on a bar.
function OneWoW_GUI:CreateTextureIconButton(parent, options)
    options = options or {}
    local iconTexture = options.iconTexture
    if not iconTexture then
        return nil
    end
    local width = options.width or 20
    local height = options.height or 20
    local inset = options.iconInset or 2
    local name = options.name
    local btn = self:CreateButton(parent, { name = name, text = " ", width = width, height = height })
    btn.text:Hide()
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
    icon:SetTexture(iconTexture)
    btn.icon = icon
    return btn
end

--- Chrome-less icon button (Notes row/header style). Texture or atlas, no
--- CreateButton plate. Check mode matches Notes header pin/favorite visuals.
---@param parent Frame
---@param options table
---  iconTexture = string file path (xor atlas)
---  atlas = string
---  size / width / height  default Constants.GUI.ICON_BUTTON_SIZE
---  texCoord = {l, r, t, b}
---  tint = boolean  vertex-color ACCENT_PRIMARY (atlases next to gold MEDIA)
---  tooltipTitle, tooltipText
---  onClick
---  check = boolean  CheckButton + SetActiveVisual
---  checked = boolean  initial check visual
---  onToggle = function(isActive)  check mode owns the click
---@return Button|CheckButton
function OneWoW_GUI:CreateIconButton(parent, options)
    options = options or {}
    local iconTexture = options.iconTexture
    local atlas = options.atlas
    assert(iconTexture or atlas, "OneWoW_GUI:CreateIconButton requires iconTexture or atlas")

    local size = options.size or Constants.GUI.ICON_BUTTON_SIZE
    local width = options.width or size
    local height = options.height or size
    local highlightAlpha = options.highlightAlpha or 0.5
    local texCoord = options.texCoord
    local tint = options.tint == true

    local function applyFace(tex)
        if atlas then
            tex:SetAtlas(atlas)
        else
            tex:SetTexture(iconTexture)
        end
        if texCoord then
            tex:SetTexCoord(texCoord[1], texCoord[2], texCoord[3], texCoord[4])
        end
        if tint then
            tex:SetVertexColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        end
    end

    local function applyButtonFaces(faceBtn)
        if atlas then
            faceBtn:SetNormalAtlas(atlas)
            faceBtn:SetPushedAtlas(atlas)
            faceBtn:SetHighlightAtlas(atlas)
        else
            faceBtn:SetNormalTexture(iconTexture)
            faceBtn:SetPushedTexture(iconTexture)
            faceBtn:SetHighlightTexture(iconTexture)
        end
        local normal = faceBtn:GetNormalTexture()
        local pushed = faceBtn:GetPushedTexture()
        local highlight = faceBtn:GetHighlightTexture()
        if texCoord then
            normal:SetTexCoord(texCoord[1], texCoord[2], texCoord[3], texCoord[4])
            pushed:SetTexCoord(texCoord[1], texCoord[2], texCoord[3], texCoord[4])
            highlight:SetTexCoord(texCoord[1], texCoord[2], texCoord[3], texCoord[4])
        end
        if tint then
            local r, g, b = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
            normal:SetVertexColor(r, g, b)
            pushed:SetVertexColor(r, g, b)
            highlight:SetVertexColor(r, g, b)
        end
        highlight:SetAlpha(highlightAlpha)
        faceBtn.icon = normal
    end

    local btn
    if options.check then
        btn = CreateFrame("CheckButton", options.name, parent)
        btn:SetSize(width, height)
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp")

        local normalTex = btn:CreateTexture(nil, "BACKGROUND")
        normalTex:SetAllPoints()
        applyFace(normalTex)
        btn:SetNormalTexture(normalTex)

        local checkedTex = btn:CreateTexture(nil, "BACKGROUND")
        checkedTex:SetAllPoints()
        applyFace(checkedTex)
        btn:SetCheckedTexture(checkedTex)

        local highlightTex = btn:CreateTexture(nil, "HIGHLIGHT")
        highlightTex:SetAllPoints()
        applyFace(highlightTex)
        highlightTex:SetAlpha(highlightAlpha)
        btn:SetHighlightTexture(highlightTex)
        btn.icon = normalTex

        function btn:SetActiveVisual(active)
            local on = active and true or false
            self._active = on
            local tex = self:GetNormalTexture()
            if on then
                tex:SetDesaturated(false)
                tex:SetAlpha(1)
                self:SetChecked(true)
            else
                tex:SetDesaturated(true)
                tex:SetAlpha(0.3)
                self:SetChecked(false)
            end
        end

        btn:SetActiveVisual(options.checked)

        if options.onToggle then
            btn:SetScript("OnClick", function(myself)
                local newState = not myself._active
                myself:SetActiveVisual(newState)
                options.onToggle(newState)
            end)
        elseif options.onClick then
            btn:SetScript("OnClick", options.onClick)
        end
    else
        btn = CreateFrame("Button", options.name, parent)
        btn:SetSize(width, height)
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp")
        applyButtonFaces(btn)
        if options.onClick then
            btn:SetScript("OnClick", options.onClick)
        end
    end

    local tTitle = options.tooltipTitle
    local tText = options.tooltipText
    if tTitle or tText then
        btn:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            if tTitle then
                GameTooltip:SetText(tTitle, 1, 1, 1)
            end
            if tText then
                GameTooltip:AddLine(tText, 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return btn
end

function OneWoW_GUI:CreateFitTextButton(parent, options)
    options = options or {}
    local text = options.text or ""
    local height = options.height or Constants.GUI.BUTTON_HEIGHT
    local minWidth = options.minWidth or 40
    local paddingX = options.paddingX or 24
    local danger = options.danger == true
    -- danger and toggleable are mutually exclusive; danger wins.
    local toggleable = (not danger) and options.toggleable == true

    local btn = self:CreateButton(parent, { text = text, width = minWidth, height = height })
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

    if danger then
        local function applyNormal(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
            myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        local function applyHover(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_HOVER"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER_HOVER"))
            myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        local function applyDisabled(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
            myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end

        btn:SetScript("OnEnter", function(myself)
            if not myself:IsEnabled() then return end
            applyHover(myself)
        end)
        btn:SetScript("OnLeave", function(myself)
            if myself:IsEnabled() then
                applyNormal(myself)
            else
                applyDisabled(myself)
            end
        end)
        btn:SetScript("OnMouseDown", function(myself)
            if not myself:IsEnabled() then return end
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_HOVER"))
        end)
        btn:SetScript("OnMouseUp", function(myself)
            if not myself:IsEnabled() then return end
            if myself:IsMouseOver() then
                applyHover(myself)
            else
                applyNormal(myself)
            end
        end)

        local widgetSetEnabled = btn.SetEnabled
        function btn:SetEnabled(enabled)
            widgetSetEnabled(self, enabled and true or false)
            if enabled then
                applyNormal(self)
            else
                applyDisabled(self)
            end
        end

        applyNormal(btn)
    elseif toggleable then
        btn.isActive = false

        local function applyNormal(myself)
            if myself.isActive then
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            else
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end

        local function applyHover(myself)
            if myself.isActive then
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
                myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            else
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
                myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
                myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        end

        btn:SetScript("OnEnter", applyHover)
        btn:SetScript("OnLeave", applyNormal)
        btn:SetScript("OnMouseDown", function(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED"))
        end)
        btn:SetScript("OnMouseUp", function(myself)
            if myself:IsMouseOver() then
                applyHover(myself)
            else
                applyNormal(myself)
            end
        end)

        function btn:SetActive(active)
            self.isActive = active and true or false
            if self:IsMouseOver() then
                applyHover(self)
            else
                applyNormal(self)
            end
        end

        applyNormal(btn)
    end

    return btn
end

--- Backdrop-less text that acts as a clickable link. Width fits the label.
--- Idle LINK_IDLE + LINK_UNDERLINE, hover LINK_HOVER, Point cursor.
--- `nav = true` appends a smaller ASCII `>` (font-safe) after the label.
---@param parent Frame
---@param options { text?: string, fontSize?: number, nav?: boolean, onClick?: fun(self: Button) }
---@return Button
function OneWoW_GUI:CreateTextLink(parent, options)
    options = options or {}
    local text = options.text or ""
    local fontSize = options.fontSize or 12
    local onClick = options.onClick
    local nav = options.nav and true or false

    local btn = CreateFrame("Button", nil, parent)
    btn:EnableMouse(true)

    local label = OneWoW_GUI:CreateFS(btn, fontSize)
    label:SetPoint("LEFT", btn, "LEFT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    btn.text = label

    local chevron
    if nav then
        local chevronSize = math.max(fontSize - 2, 9)
        chevron = OneWoW_GUI:CreateFS(btn, chevronSize)
        chevron:SetPoint("LEFT", label, "RIGHT", 3, 0)
        chevron:SetJustifyH("LEFT")
        chevron:SetText(">")
        btn.chevron = chevron
    end

    local underline = btn:CreateTexture(nil, "ARTWORK")
    underline:SetHeight(1)
    underline:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -1)
    if chevron then
        underline:SetPoint("TOPRIGHT", chevron, "BOTTOMRIGHT", 0, -1)
    else
        underline:SetPoint("TOPRIGHT", label, "BOTTOMRIGHT", 0, -1)
    end
    btn.underline = underline

    local function ApplyLinkColors(state)
        if state == "disabled" then
            local r, g, b, a = OneWoW_GUI:GetThemeColor("TEXT_MUTED")
            label:SetTextColor(r, g, b, a)
            if chevron then chevron:SetTextColor(r, g, b, a) end
            underline:SetColorTexture(r, g, b, 0.25)
            return
        end
        if state == "hover" then
            label:SetTextColor(OneWoW_GUI:GetThemeColor("LINK_HOVER"))
            if chevron then chevron:SetTextColor(OneWoW_GUI:GetThemeColor("LINK_HOVER")) end
            underline:SetColorTexture(OneWoW_GUI:GetThemeColor("LINK_UNDERLINE"))
            return
        end
        label:SetTextColor(OneWoW_GUI:GetThemeColor("LINK_IDLE"))
        if chevron then chevron:SetTextColor(OneWoW_GUI:GetThemeColor("LINK_IDLE")) end
        underline:SetColorTexture(OneWoW_GUI:GetThemeColor("LINK_UNDERLINE"))
    end

    local function FitWidth()
        local w = label:GetStringWidth() or 0
        if chevron then
            w = w + 3 + (chevron:GetStringWidth() or 0)
        end
        local h = label:GetStringHeight() or fontSize
        if w < 1 then w = 1 end
        if h < fontSize then h = fontSize end
        -- +2 leaves room for the underline below the baseline.
        btn:SetSize(w, h + 2)
    end
    ApplyLinkColors("idle")
    FitWidth()

    function btn:SetText(newText)
        label:SetText(newText or "")
        FitWidth()
    end

    local widgetSetEnabled = btn.SetEnabled
    function btn:SetEnabled(enabled)
        widgetSetEnabled(self, enabled and true or false)
        if enabled then
            ApplyLinkColors("idle")
        else
            ApplyLinkColors("disabled")
        end
    end

    btn:SetScript("OnEnter", function(myself)
        if not myself:IsEnabled() then return end
        ApplyLinkColors("hover")
        SetCursor("Interface\\CURSOR\\Point")
    end)
    btn:SetScript("OnLeave", function(myself)
        if myself:IsEnabled() then
            ApplyLinkColors("idle")
        else
            ApplyLinkColors("disabled")
        end
        ResetCursor()
    end)
    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    return btn
end

function OneWoW_GUI:CreateFitFrameButtons(parent, options)
    options = options or {}
    local yOffset = options.yOffset or 0
    local items = options.items or {}
    local height = options.height or 26
    local gap = options.gap or 4
    local marginX = options.marginX or 12
    local paddingX = options.paddingX or 24
    local onSelect = options.onSelect
    local availWidth = (options.width or parent:GetWidth()) - (marginX * 2)
    local n = #items

    local buttons = {}
    if n == 0 then
        return buttons, yOffset
    end

    local measure = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    measure._owBaseSize = 12
    OneWoW_GUI:SafeSetFont(measure, OneWoW_GUI:GetFont(), 12)
    local minTextWidth = 0
    for _, item in ipairs(items) do
        measure:SetText(item.text or "")
        minTextWidth = math.max(minTextWidth, measure:GetStringWidth())
    end
    measure:Hide()
    measure:SetParent(nil)

    local bw = math.max(30, ceil(minTextWidth + paddingX), math.floor((availWidth - gap * (n - 1)) / n))

    local function applyNormal(btn)
        if btn.isActive then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    local function applyHover(btn)
        if btn.isActive then
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
    end

    local xPos = marginX
    local rowY = yOffset

    for i, item in ipairs(items) do
        local btn = self:CreateButton(parent, { text = item.text, width = bw, height = height })
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xPos, rowY)
        btn.itemValue = item.value
        btn.isActive = item.isActive or false

        applyNormal(btn)

        btn:SetScript("OnEnter", function(myself) applyHover(myself) end)
        btn:SetScript("OnLeave", function(myself) applyNormal(myself) end)
        btn:SetScript("OnMouseDown", function(myself) myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED")) end)
        btn:SetScript("OnMouseUp", function(myself) applyNormal(myself) end)
        btn:SetScript("OnClick", function(myself)
            for _, ob in ipairs(buttons) do
                ob.isActive = (ob == myself)
                applyNormal(ob)
            end
            if onSelect then
                onSelect(myself.itemValue, item.text, myself)
            end
        end)

        tinsert(buttons, btn)
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

--- Single-state On/Off toggle. Button shows current state; click flips it.
--- On: soft BG_FEATURES_ENABLED fill + green label. Off: muted chrome + red label.
--- Parent-disabled (isEnabled=false): fully muted / non-interactive.
--- Caller must SetPoint the button (or use CreateToggleRow).
---@param parent Frame
---@param options {
---  onLabel?: string,
---  offLabel?: string,
---  width?: number,
---  height?: number,
---  isEnabled?: boolean,
---  value?: boolean,
---  onValueChange?: fun(newValue: boolean),
---  clickTooltipFormat?: string,
--- }
---@return Button btn
---@return fun(enabled: boolean, value: boolean) refresh
function OneWoW_GUI:CreateOnOffToggleButtons(parent, options)
    options = options or {}
    local onLabel = options.onLabel or "On"
    local offLabel = options.offLabel or "Off"
    local width = options.width or Constants.GUI.TOGGLE_BUTTON_WIDTH
    local height = options.height or Constants.GUI.TOGGLE_BUTTON_HEIGHT
    local isEnabled = options.isEnabled
    local value = options.value
    local onValueChange = options.onValueChange
    local clickFmt = options.clickTooltipFormat
        or OneWoW.Locale:GetOptional("shared", "TOGGLE_CLICK")

    local btn = self:CreateFitTextButton(parent, {
        text = onLabel,
        height = height,
        minWidth = width,
        paddingX = options.paddingX or Constants.GUI.TOGGLE_BUTTON_PADDING_X,
    })

    -- Size to the wider of On/Off so the control does not jump when toggled.
    local wOn = btn:GetWidth()
    btn:SetFitText(offLabel)
    local wOff = btn:GetWidth()
    local maxW = math.max(wOn, wOff)
    btn._minWidth = maxW
    btn:SetWidth(maxW)

    local currentValue = value == true

    local function applyNormal()
        if not btn:GetParent() then return end
        if isEnabled ~= true then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            return
        end
        if currentValue then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_FEATURES_ENABLED"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("DOT_FEATURES_ENABLED"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end
    end

    local function applyHover()
        if not btn:GetParent() or isEnabled ~= true then return end
        if currentValue then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_FEATURES_ENABLED_HOVER"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end
    end

    local function showTooltip(owner)
        if isEnabled ~= true or not clickFmt then return end
        GameTooltip:SetOwner(owner, "ANCHOR_TOP")
        local nextLabel = currentValue and offLabel or onLabel
        GameTooltip:SetText(string.format(clickFmt, nextLabel), 1, 1, 1)
        GameTooltip:Show()
    end

    local function refresh(enabled, val)
        isEnabled = enabled
        currentValue = val == true
        if not btn:GetParent() then return end
        btn:EnableMouse(enabled == true)
        btn:SetFitText(currentValue and onLabel or offLabel)
        if btn:IsMouseOver() and enabled == true then
            applyHover()
        else
            applyNormal()
        end
    end

    btn:SetScript("OnEnter", function(myself)
        applyHover()
        showTooltip(myself)
    end)
    btn:SetScript("OnLeave", function()
        applyNormal()
        GameTooltip:Hide()
    end)
    btn:SetScript("OnMouseDown", function(myself)
        if isEnabled ~= true then return end
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED"))
    end)
    btn:SetScript("OnMouseUp", function(myself)
        if myself:IsMouseOver() and isEnabled == true then
            applyHover()
        else
            applyNormal()
        end
    end)
    btn:SetScript("OnClick", function()
        if isEnabled ~= true or not onValueChange then return end
        local newVal = not currentValue
        if onValueChange(newVal) == false then
            return
        end
        refresh(isEnabled, newVal)
        C_Timer.After(0, function()
            if btn:GetParent() and btn:IsMouseOver() and isEnabled == true then
                applyHover()
                showTooltip(btn)
            end
        end)
    end)

    refresh(isEnabled, value)
    return btn, refresh
end

function OneWoW_GUI:GetFavoriteAtlas()
    return Constants.FAVORITE_ATLAS or "auctionhouse-icon-favorite"
end

--- Apply the standard OneWoW favorite atlas to an existing texture.
function OneWoW_GUI:SetFavoriteAtlasTexture(tex)
    if not tex or not tex.SetAtlas then return end
    tex:SetAtlas(self:GetFavoriteAtlas())
end

--- Small icon-only favorite toggle (auction house star). options: size, favorite (bool), onClick(btn, isFavorite), tooltipTitle, tooltipText
function OneWoW_GUI:CreateFavoriteToggleButton(parent, options)
    options = options or {}
    local size = options.size or 22
    local atlasOn = options.atlasOn or self:GetFavoriteAtlas()
    local atlasOff = options.atlasOff or "auctionhouse-icon-favorite-off"
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()

    local function applyVisual(on)
        btn._favorite = on and true or false
        if on then
            tex:SetAtlas(atlasOn)
            tex:SetDesaturated(false)
            tex:SetAlpha(1)
        else
            tex:SetAtlas(atlasOff)
            tex:SetDesaturated(false)
            tex:SetAlpha(1)
        end
    end

    applyVisual(options.favorite)

    btn.SetFavorite = function(_, on)
        applyVisual(on)
    end
    btn.GetFavorite = function(myself)
        return myself._favorite
    end

    btn:SetScript("OnClick", function(myself)
        local nv = not myself._favorite
        applyVisual(nv)
        if options.onClick then
            options.onClick(myself, nv)
        end
    end)

    local tTitle = options.tooltipTitle
    local tText = options.tooltipText
    if tTitle or tText then
        btn:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            if tTitle then
                GameTooltip:SetText(tTitle, 1, 1, 1)
            end
            if tText then
                GameTooltip:AddLine(tText, 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return btn
end
