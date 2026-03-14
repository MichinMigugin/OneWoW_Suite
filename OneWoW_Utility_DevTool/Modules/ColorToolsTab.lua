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

    local pickerPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    pickerPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -10)
    pickerPanel:SetSize(280, 350)
    pickerPanel:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)
    pickerPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    pickerPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    pickerPanel.title = pickerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pickerPanel.title:SetPoint("TOP", 0, -10)
    pickerPanel.title:SetText("Custom Color Picker")
    pickerPanel.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    self.colorPreview = CreateFrame("Frame", nil, pickerPanel, "BackdropTemplate")
    self.colorPreview:SetSize(260, 100)
    self.colorPreview:SetPoint("TOP", pickerPanel.title, "BOTTOM", 0, -20)
    self.colorPreview:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)
    self.colorPreview:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    self.colorPreview:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    self.colorPreview.bg = self.colorPreview:CreateTexture(nil, "ARTWORK")
    self.colorPreview.bg:SetAllPoints()
    self.colorPreview.bg:SetColorTexture(1, 1, 1, 1)

    local rLabel = pickerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rLabel:SetPoint("TOPLEFT", self.colorPreview, "BOTTOMLEFT", 10, -20)
    rLabel:SetText("R:")
    rLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local rContainer = OneWoW_GUI:CreateSlider(pickerPanel, {
        minVal = 0, maxVal = 255, step = 1, currentVal = 255,
        onChange = function() ColorToolsTab:UpdateColor() end,
        width = 150, fmt = "%.0f"
    })
    rContainer:SetPoint("LEFT", rLabel, "RIGHT", 10, 0)
    self.rSlider = select(1, rContainer:GetChildren())

    local gLabel = pickerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gLabel:SetPoint("TOPLEFT", rLabel, "BOTTOMLEFT", 0, -25)
    gLabel:SetText("G:")
    gLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local gContainer = OneWoW_GUI:CreateSlider(pickerPanel, {
        minVal = 0, maxVal = 255, step = 1, currentVal = 255,
        onChange = function() ColorToolsTab:UpdateColor() end,
        width = 150, fmt = "%.0f"
    })
    gContainer:SetPoint("LEFT", gLabel, "RIGHT", 10, 0)
    self.gSlider = select(1, gContainer:GetChildren())

    local bLabel = pickerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bLabel:SetPoint("TOPLEFT", gLabel, "BOTTOMLEFT", 0, -25)
    bLabel:SetText("B:")
    bLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local bContainer = OneWoW_GUI:CreateSlider(pickerPanel, {
        minVal = 0, maxVal = 255, step = 1, currentVal = 255,
        onChange = function() ColorToolsTab:UpdateColor() end,
        width = 150, fmt = "%.0f"
    })
    bContainer:SetPoint("LEFT", bLabel, "RIGHT", 10, 0)
    self.bSlider = select(1, bContainer:GetChildren())

    self.colorCodeText = pickerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.colorCodeText:SetPoint("TOP", bContainer, "BOTTOM", 0, -30)
    self.colorCodeText:SetText("|cFFFFFFFF|cFFFFFFFF|r")

    local copyButton = OneWoW_GUI:CreateButton(pickerPanel, { text = "Copy Color Code", width = 150, height = 25 })
    copyButton:SetPoint("TOP", self.colorCodeText, "BOTTOM", 0, -10)
    copyButton:SetScript("OnClick", function()
        ColorToolsTab:CopyColorCode()
    end)

    local classColorsPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    classColorsPanel:SetPoint("TOPLEFT", pickerPanel, "TOPRIGHT", 5, 0)
    classColorsPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)
    classColorsPanel:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)
    classColorsPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    classColorsPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    classColorsPanel.title = classColorsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classColorsPanel.title:SetPoint("TOPLEFT", 0, -10)
    classColorsPanel.title:SetText("Class Colors")
    classColorsPanel.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local scrollFrame = CreateFrame("ScrollFrame", nil, classColorsPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", classColorsPanel.title, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", classColorsPanel, "BOTTOMRIGHT", -25, 10)
    OneWoW_GUI:StyleScrollBar(scrollFrame, { container = classColorsPanel })

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetWidth(math.max(250, (parent:GetWidth() or 0) - 320))

    self.scrollFrame = scrollFrame
    self.scrollChild = scrollChild
    self.colorRows = {}

    local yOffset = -10
    for _, data in ipairs(classColors) do
        local colorMixin = data.colorMixin
        local className = data.className
        local colorStr = colorMixin:GenerateHexColorNoAlpha()

        local frame = CreateFrame("Frame", nil, scrollChild)
        frame:SetSize(math.max(200, scrollChild:GetWidth()), 25)
        tinsert(self.colorRows, frame)
        frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)

        frame.colorBox = frame:CreateTexture(nil, "ARTWORK")
        frame.colorBox:SetSize(20, 20)
        frame.colorBox:SetPoint("LEFT", 5, 0)
        frame.colorBox:SetColorTexture(colorMixin:GetRGB())

        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.text:SetPoint("LEFT", frame.colorBox, "RIGHT", 5, 0)
        frame.text:SetText(className .. ": " .. colorMixin:WrapTextInColorCode(colorStr, colorStr))

        frame.copyBtn = OneWoW_GUI:CreateButton(frame, { text = "Copy", width = 60, height = 20 })
        frame.copyBtn:SetPoint("RIGHT", -5, 0)
        frame.copyBtn:SetScript("OnClick", function()
            Addon:CopyToClipboard(colorStr)
        end)
        frame.text:SetPoint("RIGHT", frame.copyBtn, "LEFT", -5, 0)

        yOffset = yOffset - 27
    end

    local commonTitle = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    commonTitle:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset - 10)
    commonTitle:SetText("Common Colors")
    commonTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    yOffset = yOffset - 40
    for _, data in ipairs(self.commonColors) do
        local frame = CreateFrame("Frame", nil, scrollChild)
        frame:SetSize(math.max(200, scrollChild:GetWidth()), 25)
        tinsert(self.colorRows, frame)
        frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)

        frame.colorBox = frame:CreateTexture(nil, "ARTWORK")
        frame.colorBox:SetSize(20, 20)
        frame.colorBox:SetPoint("LEFT", 5, 0)
        frame.colorBox:SetColorTexture(
            tonumber(data.color:sub(1,2), 16) / 255,
            tonumber(data.color:sub(3,4), 16) / 255,
            tonumber(data.color:sub(5,6), 16) / 255,
            1
        )

        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.text:SetPoint("LEFT", frame.colorBox, "RIGHT", 5, 0)
        frame.text:SetText(data.name .. ": |cFF" .. data.color .. data.color .. "|r")

        frame.copyBtn = OneWoW_GUI:CreateButton(frame, { text = "Copy", width = 60, height = 20 })
        frame.copyBtn:SetPoint("RIGHT", -5, 0)
        frame.copyBtn:SetScript("OnClick", function()
            Addon:CopyToClipboard(data.color)
        end)
        frame.text:SetPoint("RIGHT", frame.copyBtn, "LEFT", -5, 0)

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
    self.scrollChild:SetWidth(w)
    for _, row in ipairs(self.colorRows or {}) do
        row:SetSize(w, 25)
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

    local colorCode = "|cFF" .. rHex .. gHex .. bHex

    self.colorCodeText:SetText(colorCode .. colorCode .. "|r")
    self.currentColorCode = rHex .. gHex .. bHex
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
