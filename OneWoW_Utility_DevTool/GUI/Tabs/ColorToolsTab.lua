local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local C = OneWoW_GUI.Constants
local L = Addon.L or {}

local function updateColor(tab)
    local r = tab.rSlider:GetValue() / 255
    local g = tab.gSlider:GetValue() / 255
    local b = tab.bSlider:GetValue() / 255

    tab.colorPreview.bg:SetColorTexture(r, g, b, 1)

    local rHex = string.format("%02X", tab.rSlider:GetValue())
    local gHex = string.format("%02X", tab.gSlider:GetValue())
    local bHex = string.format("%02X", tab.bSlider:GetValue())

    tab.currentColorCode = rHex .. gHex .. bHex
    if tab.copyHexBtn then
        tab.copyHexBtn.text:SetText(tab.currentColorCode)
    end
end

local function copyColorCode(tab)
    if tab.currentColorCode then
        Addon:CopyToClipboard(tab.currentColorCode)
    end
end

local function updateLayout(tab)
    if not tab.scrollFrame or not tab.scrollChild then return end
    local w = math.max(250, tab.scrollFrame:GetWidth())
    local rowLeftPadding = OneWoW_GUI:GetSpacing("SM")
    tab.scrollChild:SetWidth(w)
    for _, row in ipairs(tab.colorRows or {}) do
        row:SetSize(w - rowLeftPadding, tab.rowHeight or 25)
    end
end

function Addon.UI:CreateColorToolsTab(parent)
    local DU = Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
    local PICKER_TOP = DU.COLOR_TOOLS_PICKER_TOP_PADDING or 10
    local PICKER_GAP = DU.COLOR_TOOLS_PICKER_VERTICAL_GAP or 20
    local ROW_H = DU.COLOR_TOOLS_ROW_HEIGHT or 25
    local ROW_SP = DU.COLOR_TOOLS_ROW_SPACING or 27
    local pickerW = DU.COLOR_PICKER_PANEL_WIDTH or 280
    local pickerH = DU.COLOR_PICKER_PANEL_HEIGHT or 297
    local classPanelMin = DU.COLOR_CLASS_PANEL_MIN_WIDTH or 200

    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()
    tab.colorRows = {}
    tab.rowHeight = ROW_H

    local ColorTools = Addon.ColorTools
    local classColors = ColorTools and ColorTools:GetClassColorRows() or {}

    local pickerPanel = OneWoW_GUI:CreateFrame(tab, {
        backdrop = C.BACKDROP_INNER_NO_INSETS,
        width = pickerW,
        height = pickerH,
    })
    pickerPanel:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -10)
    pickerPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    pickerPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    pickerPanel.title = pickerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pickerPanel.title:SetPoint("TOP", 0, -PICKER_TOP)
    pickerPanel.title:SetText(L["COLOR_TOOLS_TITLE_PICKER"])
    pickerPanel.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    tab.colorPreview = OneWoW_GUI:CreateFrame(pickerPanel, {
        backdrop = C.BACKDROP_INNER_NO_INSETS,
        width = 260,
        height = 100,
    })
    tab.colorPreview:SetPoint("TOP", pickerPanel.title, "BOTTOM", 0, -PICKER_GAP)
    tab.colorPreview:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    tab.colorPreview:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    tab.colorPreview.bg = tab.colorPreview:CreateTexture(nil, "ARTWORK")
    tab.colorPreview.bg:SetAllPoints()
    tab.colorPreview.bg:SetColorTexture(1, 1, 1, 1)

    local sliderContainer = CreateFrame("Frame", nil, pickerPanel)
    sliderContainer:SetSize(180, 130)
    sliderContainer:SetPoint("TOP", tab.colorPreview, "BOTTOM", 0, -PICKER_GAP)

    local rLabel = sliderContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rLabel:SetPoint("TOPLEFT", sliderContainer, "TOPLEFT", 0, 0)
    rLabel:SetText(L["COLOR_TOOLS_LABEL_R"])
    rLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local rContainer = OneWoW_GUI:CreateSlider(sliderContainer, {
        minVal = 0, maxVal = 255, step = 1, currentVal = 255,
        onChange = function() updateColor(tab) end,
        width = 150, fmt = "%.0f"
    })
    rContainer:SetPoint("LEFT", rLabel, "RIGHT", 10, 0)
    tab.rSlider = select(1, rContainer:GetChildren())

    local gLabel = sliderContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gLabel:SetPoint("TOPLEFT", rLabel, "BOTTOMLEFT", 0, -25)
    gLabel:SetText(L["COLOR_TOOLS_LABEL_G"])
    gLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local gContainer = OneWoW_GUI:CreateSlider(sliderContainer, {
        minVal = 0, maxVal = 255, step = 1, currentVal = 255,
        onChange = function() updateColor(tab) end,
        width = 150, fmt = "%.0f"
    })
    gContainer:SetPoint("LEFT", gLabel, "RIGHT", 10, 0)
    tab.gSlider = select(1, gContainer:GetChildren())

    local bLabel = sliderContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bLabel:SetPoint("TOPLEFT", gLabel, "BOTTOMLEFT", 0, -25)
    bLabel:SetText(L["COLOR_TOOLS_LABEL_B"])
    bLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local bContainer = OneWoW_GUI:CreateSlider(sliderContainer, {
        minVal = 0, maxVal = 255, step = 1, currentVal = 255,
        onChange = function() updateColor(tab) end,
        width = 150, fmt = "%.0f"
    })
    bContainer:SetPoint("LEFT", bLabel, "RIGHT", 10, 0)
    tab.bSlider = select(1, bContainer:GetChildren())

    tab.copyHexBtn = OneWoW_GUI:CreateButton(sliderContainer, { text = "FFFFFF", width = 80, height = 25 })
    tab.copyHexBtn:SetPoint("TOP", sliderContainer, "TOP", 0, -105)
    tab.copyHexBtn:SetScript("OnClick", function()
        copyColorCode(tab)
    end)
    tab.copyHexBtn:HookScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["COLOR_TOOLS_CLICK_TO_COPY"], 1, 1, 1)
        GameTooltip:Show()
    end)
    tab.copyHexBtn:HookScript("OnLeave", GameTooltip_Hide)

    local classColorsPanel = OneWoW_GUI:CreateFrame(tab, {
        backdrop = C.BACKDROP_INNER_NO_INSETS,
        width = classPanelMin,
        height = 200,
    })
    classColorsPanel:ClearAllPoints()
    classColorsPanel:SetPoint("TOPLEFT", pickerPanel, "TOPRIGHT", 5, 0)
    classColorsPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -10, 10)
    classColorsPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    classColorsPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local ROW_LEFT_PADDING = OneWoW_GUI:GetSpacing("SM")
    classColorsPanel.title = classColorsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classColorsPanel.title:SetPoint("TOPLEFT", ROW_LEFT_PADDING, -10)
    classColorsPanel.title:SetText(L["COLOR_TOOLS_TITLE_CLASS"])
    classColorsPanel.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(classColorsPanel, {})
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", classColorsPanel.title, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", classColorsPanel, "BOTTOMRIGHT", -25, 10)
    scrollChild:SetWidth(math.max(250, (parent:GetWidth() or 0) - 320))

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(math.max(250, w))
    end)

    tab.scrollFrame = scrollFrame
    tab.scrollChild = scrollChild

    local yOffset = -10
    for _, data in ipairs(classColors) do
        local colorMixin = data.colorMixin
        local className = data.className
        local colorStr = colorMixin:GenerateHexColorNoAlpha()

        local row = OneWoW_GUI:CreateFrame(scrollChild, {
            backdrop = C.BACKDROP_SIMPLE,
            width = math.max(200, scrollChild:GetWidth()) - ROW_LEFT_PADDING,
            height = ROW_H,
        })
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        tinsert(tab.colorRows, row)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", ROW_LEFT_PADDING, yOffset)

        row.colorBox = row:CreateTexture(nil, "ARTWORK")
        row.colorBox:SetSize(20, 20)
        row.colorBox:SetPoint("LEFT", 5, 0)
        row.colorBox:SetColorTexture(colorMixin:GetRGB())

        row.copyBtn = OneWoW_GUI:CreateButton(row, { text = colorStr, width = 60, height = 20 })
        row.copyBtn:SetPoint("RIGHT", -5, 0)
        row.copyBtn:SetScript("OnClick", function()
            Addon:CopyToClipboard(colorStr)
        end)
        row.copyBtn:HookScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["COLOR_TOOLS_CLICK_TO_COPY"], 1, 1, 1)
            GameTooltip:Show()
        end)
        row.copyBtn:HookScript("OnLeave", GameTooltip_Hide)

        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameText:SetPoint("LEFT", row.colorBox, "RIGHT", 5, 0)
        row.nameText:SetPoint("RIGHT", row.copyBtn, "LEFT", -5, 0)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetText(className)
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        yOffset = yOffset - ROW_SP
    end

    local commonTitle = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    commonTitle:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset - 10)
    commonTitle:SetText(L["COLOR_TOOLS_TITLE_COMMON"])
    commonTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    yOffset = yOffset - 40
    local commonList = Addon.Constants and Addon.Constants.COLOR_TOOLS_COMMON or {}
    for _, entry in ipairs(commonList) do
        local hex = entry.hex
        local name = L[entry.nameKey] or entry.nameKey
        local r, g, b = 1, 1, 1
        if ColorTools and ColorTools.HexToRGB then
            r, g, b = ColorTools:HexToRGB(hex)
        end

        local row = OneWoW_GUI:CreateFrame(scrollChild, {
            backdrop = C.BACKDROP_SIMPLE,
            width = math.max(200, scrollChild:GetWidth()) - ROW_LEFT_PADDING,
            height = ROW_H,
        })
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        tinsert(tab.colorRows, row)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", ROW_LEFT_PADDING, yOffset)

        row.colorBox = row:CreateTexture(nil, "ARTWORK")
        row.colorBox:SetSize(20, 20)
        row.colorBox:SetPoint("LEFT", 5, 0)
        row.colorBox:SetColorTexture(r, g, b, 1)

        row.copyBtn = OneWoW_GUI:CreateButton(row, { text = hex, width = 60, height = 20 })
        row.copyBtn:SetPoint("RIGHT", -5, 0)
        row.copyBtn:SetScript("OnClick", function()
            Addon:CopyToClipboard(hex)
        end)
        row.copyBtn:HookScript("OnEnter", function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["COLOR_TOOLS_CLICK_TO_COPY"], 1, 1, 1)
            GameTooltip:Show()
        end)
        row.copyBtn:HookScript("OnLeave", GameTooltip_Hide)

        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameText:SetPoint("LEFT", row.colorBox, "RIGHT", 5, 0)
        row.nameText:SetPoint("RIGHT", row.copyBtn, "LEFT", -5, 0)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetText(name)
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        yOffset = yOffset - ROW_SP
    end

    scrollChild:SetHeight(math.abs(yOffset) + 20)

    tab:SetScript("OnShow", function()
        updateLayout(tab)
    end)
    tab:SetScript("OnSizeChanged", function()
        if tab:IsVisible() then
            updateLayout(tab)
        end
    end)

    updateColor(tab)

    return tab
end
