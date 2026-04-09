local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local CreateFrame = CreateFrame
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
    OneWoW_GUI:SafeSetFont(btn.text, OneWoW_GUI:GetFont(), 12)
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

function OneWoW_GUI:CreateFitTextButton(parent, options)
    options = options or {}
    local text = options.text or ""
    local height = options.height or Constants.GUI.BUTTON_HEIGHT
    local minWidth = options.minWidth or 40
    local paddingX = options.paddingX or 24

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

    return btn
end

function OneWoW_GUI:CreateFitFrameButtons(parent, options)
    options = options or {}
    local yOffset = options.yOffset or 0
    local items = options.items or {}
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

        btn:SetScript("OnEnter", function(self) applyHover(self) end)
        btn:SetScript("OnLeave", function(self) applyNormal(self) end)
        btn:SetScript("OnMouseDown", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED")) end)
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

function OneWoW_GUI:CreateOnOffToggleButtons(parent, options)
    options = options or {}
    local yOffset = options.yOffset or 0
    local onLabel = options.onLabel or "On"
    local offLabel = options.offLabel or "Off"
    local width = options.width or Constants.GUI.TOGGLE_BUTTON_WIDTH
    local height = options.height or Constants.GUI.TOGGLE_BUTTON_HEIGHT
    local isEnabled = options.isEnabled
    local value = options.value
    local onValueChange = options.onValueChange

    local onBtn = self:CreateFitTextButton(parent, { text = onLabel, height = height, minWidth = width })
    local offBtn = self:CreateFitTextButton(parent, { text = offLabel, height = height, minWidth = width })

    local maxW = math.max(onBtn:GetWidth(), offBtn:GetWidth())
    onBtn:SetWidth(maxW)
    offBtn:SetWidth(maxW)

    local statusPfx = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SafeSetFont(statusPfx, OneWoW_GUI:GetFont(), 10)
    statusPfx:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    statusPfx:SetText("Status:")
    statusPfx:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local statusVal = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SafeSetFont(statusVal, OneWoW_GUI:GetFont(), 10)
    statusVal:SetPoint("LEFT", statusPfx, "RIGHT", 4, 0)

    onBtn:SetPoint("LEFT", statusVal, "RIGHT", 10, 0)
    offBtn:SetPoint("LEFT", onBtn, "RIGHT", 4, 0)

    local function applyHover(btn)
        if btn.isActive then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        end
    end

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

    for _, btn in ipairs({ onBtn, offBtn }) do
        btn:SetScript("OnEnter", function(self) applyHover(self) end)
        btn:SetScript("OnLeave", function(self) applyNormal(self) end)
        btn:SetScript("OnMouseDown", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED")) end)
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
            onBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            onBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            offBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            offBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            onBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            offBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            statusPfx:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            statusVal:SetText(val and onLabel or offLabel)
            statusVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        else
            applyNormal(onBtn)
            applyNormal(offBtn)
            statusPfx:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            if val then
                statusVal:SetText(onLabel)
                statusVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                statusVal:SetText(offLabel)
                statusVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
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
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetAtlas(self:GetFavoriteAtlas())

    local function applyVisual(on)
        btn._favorite = on and true or false
        if on then
            tex:SetDesaturated(false)
            tex:SetAlpha(1)
        else
            tex:SetDesaturated(true)
            tex:SetAlpha(0.38)
        end
    end

    applyVisual(options.favorite)

    btn.SetFavorite = function(self, on)
        applyVisual(on)
    end
    btn.GetFavorite = function(self)
        return self._favorite
    end

    btn:SetScript("OnClick", function(self)
        local nv = not self._favorite
        applyVisual(nv)
        if options.onClick then
            options.onClick(self, nv)
        end
    end)

    local tTitle = options.tooltipTitle
    local tText = options.tooltipText
    if tTitle or tText then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
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
