local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local L = Addon.L or {}

function Addon.UI:CreateLayoutTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local gridLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    gridLabel:SetPoint("TOPLEFT", tab, "TOPLEFT", 10, -10)
    gridLabel:SetText(Addon.L and Addon.L["LABEL_GRID_OVERLAY"] or "Grid Overlay")
    gridLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local colGap = 16
    local toggleBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = Addon.L and Addon.L["BTN_TOGGLE_GRID"] or "Toggle Grid",
        height = 25,
        minWidth = 120,
    })
    toggleBtn:SetScript("OnClick", function()
        Addon.UI:ToggleGrid()
    end)

    local sizeLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- Sliders anchor from grid title; horizontal inset = toggle width + gap (same as post-align toggle edge).
    sizeLabel:SetPoint("TOPLEFT", gridLabel, "BOTTOMLEFT", toggleBtn:GetWidth() + colGap, -10)
    sizeLabel:SetText((Addon.L and Addon.L["LABEL_GRID_SIZE"] or "Grid Size:") .. " 50")
    sizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local sizeContainer = OneWoW_GUI:CreateSlider(tab, {
        minVal = 10,
        maxVal = 200,
        step = 10,
        currentVal = 50,
        width = 200,
        fmt = "%.0f",
        onChange = function(value)
            sizeLabel:SetText((Addon.L and Addon.L["LABEL_GRID_SIZE"] or "Grid Size:") .. " " .. value)
            tab.gridSize = value
            if tab.gridActive then
                Addon.UI:UpdateGridOverlay()
            end
        end,
    })
    sizeContainer:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -5)

    -- Opacity slider must anchor to the grid slider's right edge, not to the size label's
    -- right edge (the label is narrower than the 200px track, which stacked both sliders).
    local opacityLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opacityLabel:SetText((Addon.L and Addon.L["LABEL_OPACITY"] or "Opacity:") .. " 0.3")
    opacityLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local opacityContainer = OneWoW_GUI:CreateSlider(tab, {
        minVal = 0.1,
        maxVal = 1.0,
        step = 0.1,
        currentVal = 0.3,
        width = 200,
        fmt = "%.1f",
        onChange = function(value)
            opacityLabel:SetText((Addon.L and Addon.L["LABEL_OPACITY"] or "Opacity:") .. " " .. string.format("%.1f", value))
            tab.gridOpacity = value
            if tab.gridActive then
                Addon.UI:UpdateGridOverlay()
            end
        end,
    })
    opacityContainer:SetPoint("TOPLEFT", sizeContainer, "TOPRIGHT", 16, 0)
    opacityLabel:SetPoint("BOTTOMLEFT", opacityContainer, "TOPLEFT", 0, 5)

    -- Zero-width strip: top of grid label through bottom of grid slider (36px control; Low/High text draws below).
    local sliderStackAlign = CreateFrame("Frame", nil, tab)
    sliderStackAlign:SetPoint("TOPLEFT", sizeLabel, "TOPLEFT", 0, 0)
    sliderStackAlign:SetPoint("BOTTOMLEFT", sizeContainer, "BOTTOMLEFT", 0, 0)
    sliderStackAlign:SetWidth(1)
    toggleBtn:SetPoint("CENTER", sliderStackAlign, "LEFT", -colGap - toggleBtn:GetWidth() / 2, 0)

    local centerBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = Addon.L and Addon.L["BTN_TOGGLE_CENTER"] or "Toggle Center Lines",
        height = 25,
        minWidth = 150,
    })
    -- Anchor below the slider track; Low/High labels sit outside the 36px container rect.
    centerBtn:SetPoint("LEFT", toggleBtn, "LEFT", 0, 0)
    centerBtn:SetPoint("TOP", sizeContainer, "BOTTOM", 0, -24)
    centerBtn:SetScript("OnClick", function()
        Addon.UI:ToggleCenterLines()
    end)

    tab.gridSize = 50
    tab.gridOpacity = 0.3
    tab.gridActive = false
    tab.centerActive = false

    Addon.LayoutToolsTab = tab
    return tab
end

function Addon.UI:ToggleGrid()
    local tab = Addon.LayoutToolsTab

    if not tab.gridActive then
        if not self.gridFrame then
            self.gridFrame = CreateFrame("Frame", nil, UIParent)
            self.gridFrame:SetAllPoints()
            self.gridFrame:SetFrameStrata("BACKGROUND")
            self.gridFrame:EnableMouse(false)
            self.gridFrame.lines = {}
        end

        self:UpdateGridOverlay()
        self.gridFrame:Show()
        tab.gridActive = true
        Addon:Print(Addon.L and Addon.L["MSG_GRID_ENABLED"] or "Grid enabled")
    else
        if self.gridFrame then
            for _, line in ipairs(self.gridFrame.lines) do
                line:Hide()
            end
            self.gridFrame:Hide()
        end
        tab.gridActive = false
        Addon:Print(Addon.L and Addon.L["MSG_GRID_DISABLED"] or "Grid disabled")
    end
end

function Addon.UI:UpdateGridOverlay()
    if not self.gridFrame then return end

    local tab = Addon.LayoutToolsTab
    if not tab then return end

    for _, line in ipairs(self.gridFrame.lines) do
        line:Hide()
    end

    local width = GetScreenWidth()
    local height = GetScreenHeight()
    local gridSize = tab.gridSize or 50
    local opacity = tab.gridOpacity or 0.3
    local lineIndex = 1

    for x = 0, width, gridSize do
        if lineIndex > #self.gridFrame.lines then
            local line = self.gridFrame:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(1, 1, 1, opacity)
            tinsert(self.gridFrame.lines, line)
        end

        local line = self.gridFrame.lines[lineIndex]
        line:SetColorTexture(1, 1, 1, opacity)
        line:SetSize(1, height)
        line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 0)
        line:Show()
        lineIndex = lineIndex + 1
    end

    for y = 0, height, gridSize do
        if lineIndex > #self.gridFrame.lines then
            local line = self.gridFrame:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(1, 1, 1, opacity)
            tinsert(self.gridFrame.lines, line)
        end

        local line = self.gridFrame.lines[lineIndex]
        line:SetColorTexture(1, 1, 1, opacity)
        line:SetSize(width, 1)
        line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, y)
        line:Show()
        lineIndex = lineIndex + 1
    end
end

function Addon.UI:ToggleCenterLines()
    local tab = Addon.LayoutToolsTab

    if not tab.centerActive then
        if not self.centerFrame then
            self.centerFrame = CreateFrame("Frame", nil, UIParent)
            self.centerFrame:SetAllPoints()
            self.centerFrame:SetFrameStrata("BACKGROUND")
            self.centerFrame:EnableMouse(false)

            self.centerV = self.centerFrame:CreateTexture(nil, "ARTWORK")
            self.centerV:SetColorTexture(1, 0, 0, 0.5)
            self.centerV:SetSize(2, GetScreenHeight())
            self.centerV:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

            self.centerH = self.centerFrame:CreateTexture(nil, "ARTWORK")
            self.centerH:SetColorTexture(1, 0, 0, 0.5)
            self.centerH:SetSize(GetScreenWidth(), 2)
            self.centerH:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end

        self.centerFrame:Show()
        tab.centerActive = true
        Addon:Print(Addon.L and Addon.L["MSG_CENTER_LINES_ENABLED"] or "Center lines enabled")
    else
        if self.centerFrame then
            self.centerFrame:Hide()
        end
        tab.centerActive = false
        Addon:Print(Addon.L and Addon.L["MSG_CENTER_LINES_DISABLED"] or "Center lines disabled")
    end
end

