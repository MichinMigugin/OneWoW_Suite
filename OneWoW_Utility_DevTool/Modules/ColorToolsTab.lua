local AddonName, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local C = OneWoW_GUI.Constants

local ColorToolsTab = {}
Addon.ColorToolsTab = ColorToolsTab

-- Build class colors table from game data
local classColors = {}
do
    for key, _ in pairs(RAID_CLASS_COLORS) do
        if key ~= "ADVENTURER" and key ~= "TRAVELER" then
            tinsert(classColors, key)
        end
    end
    sort(classColors)

    for i, className  in ipairs(classColors) do
        classColors[i] = {
            colorMixin = RAID_CLASS_COLORS[className],
            className = LOCALIZED_CLASS_NAMES_MALE[className]
        }
    end
end

ColorToolsTab.commonColors = {
    {name = "White", color = "FFFFFF"},
    {name = "Black", color = "000000"},
    {name = "Red", color = "FF0000"},
    {name = "Green", color = "00FF00"},
    {name = "Blue", color = "0000FF"},
    {name = "Yellow", color = "FFFF00"},
    {name = "Cyan", color = "00FFFF"},
    {name = "Magenta", color = "FF00FF"},
    {name = "Orange", color = "FFA500"},
    {name = "Purple", color = "800080"},
    {name = "Gold", color = "FFD700"},
    {name = "Silver", color = "C0C0C0"},
}

function ColorToolsTab:Initialize(parent)
    self.parent = parent

    local PICKER_TOP_PADDING = 10
    local PICKER_BOTTOM_PADDING = 15
    local PICKER_VERTICAL_GAP = 20

    local pickerPanel = OneWoW_GUI:CreateFrame(parent, {
        backdrop = C.BACKDROP_INNER_NO_INSETS,
        width = 280,
        height = 297,
    })
    pickerPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -10)
    pickerPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    pickerPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    pickerPanel.title = pickerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pickerPanel.title:SetPoint("TOP", 0, -PICKER_TOP_PADDING)
    pickerPanel.title:SetText("Custom Color Picker")
    pickerPanel.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    self.colorPreview = OneWoW_GUI:CreateFrame(pickerPanel, {
        backdrop = C.BACKDROP_INNER_NO_INSETS,
        width = 260,
        height = 100,
    })
    self.colorPreview:SetPoint("TOP", pickerPanel.title, "BOTTOM", 0, -PICKER_VERTICAL_GAP)
    self.colorPreview:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    self.colorPreview:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    self.colorPreview.bg = self.colorPreview:CreateTexture(nil, "ARTWORK")
    self.colorPreview.bg:SetAllPoints()
    self.colorPreview.bg:SetColorTexture(1, 1, 1, 1)

    local sliderContainer = CreateFrame("Frame", nil, pickerPanel)
    sliderContainer:SetSize(180, 130)
    sliderContainer:SetPoint("TOP", self.colorPreview, "BOTTOM", 0, -PICKER_VERTICAL_GAP)

    local rLabel = sliderContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rLabel:SetPoint("TOPLEFT", sliderContainer, "TOPLEFT", 0, 0)
    rLabel:SetText("R:")
    rLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local rContainer = OneWoW_GUI:CreateSlider(sliderContainer, {
        minVal = 0, maxVal = 255, step = 1, currentVal = 255,
        onChange = function() ColorToolsTab:UpdateColor() end,
        width = 150, fmt = "%.0f"
    })
    rContainer:SetPoint("LEFT", rLabel, "RIGHT", 10, 0)
    self.rSlider = select(1, rContainer:GetChildren())

    local gLabel = sliderContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gLabel:SetPoint("TOPLEFT", rLabel, "BOTTOMLEFT", 0, -25)
    gLabel:SetText("G:")
    gLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local gContainer = OneWoW_GUI:CreateSlider(sliderContainer, {
        minVal = 0, maxVal = 255, step = 1, currentVal = 255,
        onChange = function() ColorToolsTab:UpdateColor() end,
        width = 150, fmt = "%.0f"
    })
    gContainer:SetPoint("LEFT", gLabel, "RIGHT", 10, 0)
    self.gSlider = select(1, gContainer:GetChildren())

    local bLabel = sliderContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bLabel:SetPoint("TOPLEFT", gLabel, "BOTTOMLEFT", 0, -25)
    bLabel:SetText("B:")
    bLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local bContainer = OneWoW_GUI:CreateSlider(sliderContainer, {
        minVal = 0, maxVal = 255, step = 1, currentVal = 255,
        onChange = function() ColorToolsTab:UpdateColor() end,
        width = 150, fmt = "%.0f"
    })
    bContainer:SetPoint("LEFT", bLabel, "RIGHT", 10, 0)
    self.bSlider = select(1, bContainer:GetChildren())

    self.copyHexBtn = OneWoW_GUI:CreateButton(sliderContainer, { text = "FFFFFF", width = 80, height = 25 })
    self.copyHexBtn:SetPoint("TOP", sliderContainer, "TOP", 0, -105)
    self.copyHexBtn:SetScript("OnClick", function()
        ColorToolsTab:CopyColorCode()
    end)
    self.copyHexBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(Addon.L and Addon.L["COLOR_TOOLS_CLICK_TO_COPY"] or "Click to copy hex code", 1, 1, 1)
        GameTooltip:Show()
    end)
    self.copyHexBtn:HookScript("OnLeave", GameTooltip_Hide)

    local classColorsPanel = OneWoW_GUI:CreateFrame(parent, {
        backdrop = C.BACKDROP_INNER_NO_INSETS,
        width = 200,
        height = 200,
    })
    classColorsPanel:ClearAllPoints()
    classColorsPanel:SetPoint("TOPLEFT", pickerPanel, "TOPRIGHT", 5, 0)
    classColorsPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)
    classColorsPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    classColorsPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local ROW_LEFT_PADDING = OneWoW_GUI:GetSpacing("SM")
    classColorsPanel.title = classColorsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classColorsPanel.title:SetPoint("TOPLEFT", ROW_LEFT_PADDING, -10)
    classColorsPanel.title:SetText("Class Colors")
    classColorsPanel.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(classColorsPanel, { name = "ColorToolsScroll" })
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", classColorsPanel.title, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", classColorsPanel, "BOTTOMRIGHT", -25, 10)
    scrollChild:SetWidth(math.max(250, (parent:GetWidth() or 0) - 320))

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(math.max(250, w))
    end)

    self.scrollFrame = scrollFrame
    self.scrollChild = scrollChild
    self.colorRows = {}

    local yOffset = -10
    for _, data in ipairs(classColors) do
        local colorMixin = data.colorMixin
        local className = data.className
        local colorStr = colorMixin:GenerateHexColorNoAlpha()

        local frame = OneWoW_GUI:CreateFrame(scrollChild, {
            backdrop = C.BACKDROP_SIMPLE,
            width = math.max(200, scrollChild:GetWidth()) - ROW_LEFT_PADDING,
            height = 25,
        })
        frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        tinsert(self.colorRows, frame)
        frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", ROW_LEFT_PADDING, yOffset)

        frame.colorBox = frame:CreateTexture(nil, "ARTWORK")
        frame.colorBox:SetSize(20, 20)
        frame.colorBox:SetPoint("LEFT", 5, 0)
        frame.colorBox:SetColorTexture(colorMixin:GetRGB())

        frame.copyBtn = OneWoW_GUI:CreateButton(frame, { text = colorStr, width = 60, height = 20 })
        frame.copyBtn:SetPoint("RIGHT", -5, 0)
        frame.copyBtn:SetScript("OnClick", function()
            Addon:CopyToClipboard(colorStr)
        end)
        frame.copyBtn:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(Addon.L and Addon.L["COLOR_TOOLS_CLICK_TO_COPY"] or "Click to copy hex code", 1, 1, 1)
            GameTooltip:Show()
        end)
        frame.copyBtn:HookScript("OnLeave", GameTooltip_Hide)

        frame.nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.nameText:SetPoint("LEFT", frame.colorBox, "RIGHT", 5, 0)
        frame.nameText:SetPoint("RIGHT", frame.copyBtn, "LEFT", -5, 0)
        frame.nameText:SetJustifyH("LEFT")
        frame.nameText:SetText(className)
        frame.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        yOffset = yOffset - 27
    end

    local commonTitle = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    commonTitle:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset - 10)
    commonTitle:SetText("Common Colors")
    commonTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    yOffset = yOffset - 40
    for _, data in ipairs(self.commonColors) do
        local frame = OneWoW_GUI:CreateFrame(scrollChild, {
            backdrop = C.BACKDROP_SIMPLE,
            width = math.max(200, scrollChild:GetWidth()) - ROW_LEFT_PADDING,
            height = 25,
        })
        frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        tinsert(self.colorRows, frame)
        frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", ROW_LEFT_PADDING, yOffset)

        frame.colorBox = frame:CreateTexture(nil, "ARTWORK")
        frame.colorBox:SetSize(20, 20)
        frame.colorBox:SetPoint("LEFT", 5, 0)
        frame.colorBox:SetColorTexture(
            tonumber(data.color:sub(1,2), 16) / 255,
            tonumber(data.color:sub(3,4), 16) / 255,
            tonumber(data.color:sub(5,6), 16) / 255,
            1
        )

        frame.copyBtn = OneWoW_GUI:CreateButton(frame, { text = data.color, width = 60, height = 20 })
        frame.copyBtn:SetPoint("RIGHT", -5, 0)
        frame.copyBtn:SetScript("OnClick", function()
            Addon:CopyToClipboard(data.color)
        end)
        frame.copyBtn:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(Addon.L and Addon.L["COLOR_TOOLS_CLICK_TO_COPY"] or "Click to copy hex code", 1, 1, 1)
            GameTooltip:Show()
        end)
        frame.copyBtn:HookScript("OnLeave", GameTooltip_Hide)

        frame.nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.nameText:SetPoint("LEFT", frame.colorBox, "RIGHT", 5, 0)
        frame.nameText:SetPoint("RIGHT", frame.copyBtn, "LEFT", -5, 0)
        frame.nameText:SetJustifyH("LEFT")
        frame.nameText:SetText(data.name)
        frame.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        yOffset = yOffset - 27
    end

    scrollChild:SetHeight(math.abs(yOffset) + 20)

    parent:SetScript("OnShow", function()
        ColorToolsTab:OnShow()
    end)
    parent:SetScript("OnSizeChanged", function()
        if parent:IsVisible() then
            ColorToolsTab:UpdateLayout()
        end
    end)

    self:UpdateColor()
end

function ColorToolsTab:UpdateLayout()
    if not self.scrollFrame or not self.scrollChild then return end
    local w = math.max(250, self.scrollFrame:GetWidth())
    local rowLeftPadding = OneWoW_GUI:GetSpacing("SM")
    self.scrollChild:SetWidth(w)
    for _, row in ipairs(self.colorRows or {}) do
        row:SetSize(w - rowLeftPadding, 25)
    end
end

function ColorToolsTab:UpdateColor()
    local r = self.rSlider:GetValue() / 255
    local g = self.gSlider:GetValue() / 255
    local b = self.bSlider:GetValue() / 255

    self.colorPreview.bg:SetColorTexture(r, g, b, 1)

    local rHex = string.format("%02X", self.rSlider:GetValue())
    local gHex = string.format("%02X", self.gSlider:GetValue())
    local bHex = string.format("%02X", self.bSlider:GetValue())

    self.currentColorCode = rHex .. gHex .. bHex
    if self.copyHexBtn then
        self.copyHexBtn.text:SetText(self.currentColorCode)
    end
end

function ColorToolsTab:CopyColorCode()
    if self.currentColorCode then
        Addon:CopyToClipboard(self.currentColorCode)
    end
end

function ColorToolsTab:OnShow()
    self:UpdateLayout()
end

function ColorToolsTab:OnHide()
end
