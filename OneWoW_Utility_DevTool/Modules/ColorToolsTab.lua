local AddonName, Addon = ...

local ColorToolsTab = {}
Addon.ColorToolsTab = ColorToolsTab

ColorToolsTab.classColors = {
    {class = "Death Knight", color = "C41E3A"},
    {class = "Demon Hunter", color = "A330C9"},
    {class = "Druid", color = "FF7C0A"},
    {class = "Evoker", color = "33937F"},
    {class = "Hunter", color = "AAD372"},
    {class = "Mage", color = "3FC7EB"},
    {class = "Monk", color = "00FF98"},
    {class = "Paladin", color = "F48CBA"},
    {class = "Priest", color = "FFFFFF"},
    {class = "Rogue", color = "FFF468"},
    {class = "Shaman", color = "0070DD"},
    {class = "Warlock", color = "8788EE"},
    {class = "Warrior", color = "C69B6D"},
}

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

    local pickerPanel = CreateFrame("Frame", nil, parent)
    pickerPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
    pickerPanel:SetSize(400, 350)

    pickerPanel.bg = pickerPanel:CreateTexture(nil, "BACKGROUND")
    pickerPanel.bg:SetAllPoints()
    pickerPanel.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

    pickerPanel.title = pickerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pickerPanel.title:SetPoint("TOP", 0, -10)
    pickerPanel.title:SetText("Custom Color Picker")

    self.colorPreview = CreateFrame("Frame", nil, pickerPanel)
    self.colorPreview:SetSize(200, 100)
    self.colorPreview:SetPoint("TOP", pickerPanel.title, "BOTTOM", 0, -20)

    self.colorPreview.bg = self.colorPreview:CreateTexture(nil, "BACKGROUND")
    self.colorPreview.bg:SetAllPoints()
    self.colorPreview.bg:SetColorTexture(1, 1, 1, 1)

    local rLabel = pickerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rLabel:SetPoint("TOPLEFT", self.colorPreview, "BOTTOMLEFT", 10, -20)
    rLabel:SetText("R:")

    self.rSlider = CreateFrame("Slider", nil, pickerPanel, "OptionsSliderTemplate")
    self.rSlider:SetPoint("LEFT", rLabel, "RIGHT", 10, 0)
    self.rSlider:SetWidth(150)
    self.rSlider:SetMinMaxValues(0, 255)
    self.rSlider:SetValueStep(1)
    self.rSlider:SetValue(255)
    self.rSlider:SetScript("OnValueChanged", function()
        ColorToolsTab:UpdateColor()
    end)

    local gLabel = pickerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gLabel:SetPoint("TOPLEFT", rLabel, "BOTTOMLEFT", 0, -25)
    gLabel:SetText("G:")

    self.gSlider = CreateFrame("Slider", nil, pickerPanel, "OptionsSliderTemplate")
    self.gSlider:SetPoint("LEFT", gLabel, "RIGHT", 10, 0)
    self.gSlider:SetWidth(150)
    self.gSlider:SetMinMaxValues(0, 255)
    self.gSlider:SetValueStep(1)
    self.gSlider:SetValue(255)
    self.gSlider:SetScript("OnValueChanged", function()
        ColorToolsTab:UpdateColor()
    end)

    local bLabel = pickerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bLabel:SetPoint("TOPLEFT", gLabel, "BOTTOMLEFT", 0, -25)
    bLabel:SetText("B:")

    self.bSlider = CreateFrame("Slider", nil, pickerPanel, "OptionsSliderTemplate")
    self.bSlider:SetPoint("LEFT", bLabel, "RIGHT", 10, 0)
    self.bSlider:SetWidth(150)
    self.bSlider:SetMinMaxValues(0, 255)
    self.bSlider:SetValueStep(1)
    self.bSlider:SetValue(255)
    self.bSlider:SetScript("OnValueChanged", function()
        ColorToolsTab:UpdateColor()
    end)

    self.colorCodeText = pickerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.colorCodeText:SetPoint("TOP", self.bSlider, "BOTTOM", 50, -30)
    self.colorCodeText:SetText("|cFFFFFFFF|cFFFFFFFF|r")

    local copyButton = CreateFrame("Button", nil, pickerPanel, "UIPanelButtonTemplate")
    copyButton:SetSize(150, 25)
    copyButton:SetPoint("TOP", self.colorCodeText, "BOTTOM", 0, -10)
    copyButton:SetText("Copy Color Code")
    copyButton:SetScript("OnClick", function()
        ColorToolsTab:CopyColorCode()
    end)

    local classColorsPanel = CreateFrame("Frame", nil, parent)
    classColorsPanel:SetPoint("TOPLEFT", pickerPanel, "TOPRIGHT", 10, 0)
    classColorsPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)

    classColorsPanel.bg = classColorsPanel:CreateTexture(nil, "BACKGROUND")
    classColorsPanel.bg:SetAllPoints()
    classColorsPanel.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

    classColorsPanel.title = classColorsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classColorsPanel.title:SetPoint("TOP", 0, -10)
    classColorsPanel.title:SetText("Class Colors")

    local scrollFrame = CreateFrame("ScrollFrame", nil, classColorsPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", classColorsPanel.title, "BOTTOMLEFT", 5, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", classColorsPanel, "BOTTOMRIGHT", -25, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetWidth(scrollFrame:GetWidth() - 10)

    local yOffset = -10
    for _, data in ipairs(self.classColors) do
        local frame = CreateFrame("Frame", nil, scrollChild)
        frame:SetSize(scrollChild:GetWidth() - 10, 25)
        frame:SetPoint("TOP", scrollChild, "TOP", 0, yOffset)

        frame.colorBox = frame:CreateTexture(nil, "ARTWORK")
        frame.colorBox:SetSize(20, 20)
        frame.colorBox:SetPoint("LEFT", 10, 0)
        frame.colorBox:SetColorTexture(
            tonumber(data.color:sub(1,2), 16) / 255,
            tonumber(data.color:sub(3,4), 16) / 255,
            tonumber(data.color:sub(5,6), 16) / 255,
            1
        )

        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.text:SetPoint("LEFT", frame.colorBox, "RIGHT", 10, 0)
        frame.text:SetText(data.class .. ": |cFF" .. data.color .. data.color .. "|r")

        frame.copyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        frame.copyBtn:SetSize(60, 20)
        frame.copyBtn:SetPoint("RIGHT", -10, 0)
        frame.copyBtn:SetText("Copy")
        frame.copyBtn:SetScript("OnClick", function()
            Addon:CopyToClipboard("|cFF" .. data.color)
        end)

        yOffset = yOffset - 27
    end

    local commonTitle = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    commonTitle:SetPoint("TOP", scrollChild, "TOP", 0, yOffset - 10)
    commonTitle:SetText("Common Colors")

    yOffset = yOffset - 40
    for _, data in ipairs(self.commonColors) do
        local frame = CreateFrame("Frame", nil, scrollChild)
        frame:SetSize(scrollChild:GetWidth() - 10, 25)
        frame:SetPoint("TOP", scrollChild, "TOP", 0, yOffset)

        frame.colorBox = frame:CreateTexture(nil, "ARTWORK")
        frame.colorBox:SetSize(20, 20)
        frame.colorBox:SetPoint("LEFT", 10, 0)
        frame.colorBox:SetColorTexture(
            tonumber(data.color:sub(1,2), 16) / 255,
            tonumber(data.color:sub(3,4), 16) / 255,
            tonumber(data.color:sub(5,6), 16) / 255,
            1
        )

        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.text:SetPoint("LEFT", frame.colorBox, "RIGHT", 10, 0)
        frame.text:SetText(data.name .. ": |cFF" .. data.color .. data.color .. "|r")

        frame.copyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        frame.copyBtn:SetSize(60, 20)
        frame.copyBtn:SetPoint("RIGHT", -10, 0)
        frame.copyBtn:SetText("Copy")
        frame.copyBtn:SetScript("OnClick", function()
            Addon:CopyToClipboard("|cFF" .. data.color)
        end)

        yOffset = yOffset - 27
    end

    scrollChild:SetHeight(math.abs(yOffset) + 20)

    self:UpdateColor()
end

function ColorToolsTab:UpdateColor()
    local r = self.rSlider:GetValue() / 255
    local g = self.gSlider:GetValue() / 255
    local b = self.bSlider:GetValue() / 255

    self.colorPreview.bg:SetColorTexture(r, g, b, 1)

    local rHex = string.format("%02X", self.rSlider:GetValue())
    local gHex = string.format("%02X", self.gSlider:GetValue())
    local bHex = string.format("%02X", self.bSlider:GetValue())

    local colorCode = "|cFF" .. rHex .. gHex .. bHex

    self.colorCodeText:SetText(colorCode .. colorCode .. "|r")
    self.currentColorCode = colorCode
end

function ColorToolsTab:CopyColorCode()
    if self.currentColorCode then
        Addon:CopyToClipboard(self.currentColorCode)
    end
end

function ColorToolsTab:OnShow()
end

function ColorToolsTab:OnHide()
end
