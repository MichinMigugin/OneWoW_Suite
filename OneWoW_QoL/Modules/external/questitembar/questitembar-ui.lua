local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local function GetSettings()
    return ns.QuestItemBarModule.GetSettings()
end

local function BuildContent(container, startYOffset, isEnabled)
    local L = ns.L
    local s = GetSettings()
    local cy = 0

    cy = OneWoW_GUI:CreateSection(container, { title = L["QUESTITEMBAR_SETTINGS_HEADER"], yOffset = cy })

    local previewing = ns.QuestItemBarModule:IsPreviewActive()
    local previewBtn = OneWoW_GUI:CreateFitTextButton(container, {
        text = previewing and L["QUESTITEMBAR_HIDE_BAR"] or L["QUESTITEMBAR_SHOW_BAR"],
        height = 26,
    })
    previewBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    previewBtn:SetScript("OnClick", function()
        if ns.QuestItemBarModule:IsPreviewActive() then
            ns.QuestItemBarModule:HidePreview()
        else
            ns.QuestItemBarModule:ShowPreview()
        end
        ns.QuestItemBarModule._refreshCustomDetail()
    end)
    cy = cy - 32

    local lockBtn = OneWoW_GUI:CreateFitTextButton(container, {
        text = s.locked and (L["QUESTITEMBAR_LOCK_POSITION"] .. " (ON)") or (L["QUESTITEMBAR_LOCK_POSITION"] .. " (OFF)"),
        height = 26,
    })
    lockBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    lockBtn:SetScript("OnClick", function()
        ns.QuestItemBarModule:SetLocked(not GetSettings().locked)
        ns.QuestItemBarModule._refreshCustomDetail()
    end)
    cy = cy - 32

    local hideCheck = CreateFrame("CheckButton", nil, container, "InterfaceOptionsCheckButtonTemplate")
    hideCheck:SetPoint("TOPLEFT", container, "TOPLEFT", 8, cy)
    hideCheck.Text:SetText(L["QUESTITEMBAR_HIDE_WHEN_EMPTY"])
    hideCheck.Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    hideCheck:SetChecked(s.hideWhenEmpty)
    hideCheck:SetScript("OnClick", function(self)
        GetSettings().hideWhenEmpty = self:GetChecked()
        ns.QuestItemBarModule:ScheduleUpdate()
    end)
    cy = cy - 28

    local sizeLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    sizeLabel:SetText(string.format("%s: %d", L["QUESTITEMBAR_BUTTON_SIZE"], s.buttonSize or 36))
    sizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    cy = cy - sizeLabel:GetStringHeight() - 4

    local sizeSlider = CreateFrame("Slider", "OneWoW_QoL_QIBarSizeSlider", container, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    sizeSlider:SetWidth(220)
    sizeSlider:SetMinMaxValues(24, 48)
    sizeSlider:SetValue(s.buttonSize or 36)
    sizeSlider:SetValueStep(2)
    sizeSlider:SetObeyStepOnDrag(true)
    _G["OneWoW_QoL_QIBarSizeSliderLow"]:SetText("24")
    _G["OneWoW_QoL_QIBarSizeSliderHigh"]:SetText("48")
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        local v = math.floor(value + 0.5)
        GetSettings().buttonSize = v
        sizeLabel:SetText(string.format("%s: %d", L["QUESTITEMBAR_BUTTON_SIZE"], v))
        ns.QuestItemBarModule:ScheduleUpdate()
    end)
    cy = cy - 46

    local colsLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colsLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    colsLabel:SetText(string.format("%s: %d", L["QUESTITEMBAR_COLUMNS"], s.columns or 12))
    colsLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    cy = cy - colsLabel:GetStringHeight() - 4

    local colsSlider = CreateFrame("Slider", "OneWoW_QoL_QIBarColsSlider", container, "OptionsSliderTemplate")
    colsSlider:SetPoint("TOPLEFT", container, "TOPLEFT", 24, cy)
    colsSlider:SetWidth(220)
    colsSlider:SetMinMaxValues(1, 12)
    colsSlider:SetValue(s.columns or 12)
    colsSlider:SetValueStep(1)
    colsSlider:SetObeyStepOnDrag(true)
    _G["OneWoW_QoL_QIBarColsSliderLow"]:SetText("1")
    _G["OneWoW_QoL_QIBarColsSliderHigh"]:SetText("12")
    colsSlider:SetScript("OnValueChanged", function(self, value)
        local v = math.floor(value + 0.5)
        GetSettings().columns = v
        colsLabel:SetText(string.format("%s: %d", L["QUESTITEMBAR_COLUMNS"], v))
        ns.QuestItemBarModule:ScheduleUpdate()
    end)
    cy = cy - 46

    local sortModes = {
        { value = 1, label = L["QUESTITEMBAR_SORT_NONE"] },
        { value = 2, label = L["QUESTITEMBAR_SORT_QUEST"] },
        { value = 3, label = L["QUESTITEMBAR_SORT_ITEM"] },
    }

    local function GetSortLabel()
        local mode = GetSettings().sortMode or 2
        for _, m in ipairs(sortModes) do
            if m.value == mode then return m.label end
        end
        return sortModes[1].label
    end

    local sortLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sortLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    sortLabel:SetText(L["QUESTITEMBAR_SORT_MODE"])
    sortLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local sortBtn = OneWoW_GUI:CreateFitTextButton(container, { text = GetSortLabel(), height = 26 })
    sortBtn:SetPoint("LEFT", sortLabel, "RIGHT", 8, 0)
    sortBtn:SetScript("OnClick", function()
        local cur = GetSettings()
        cur.sortMode = (cur.sortMode or 2) % 3 + 1
        ns.QuestItemBarModule:ScheduleUpdate()
        ns.QuestItemBarModule._refreshCustomDetail()
    end)
    cy = cy - 34

    container:SetHeight(math.abs(cy))
    return cy
end

function ns.QuestItemBarModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled)
    if detailScrollChild._qibContainer then
        OneWoW_GUI:ClearFrame(detailScrollChild._qibContainer)
    end

    local container = detailScrollChild._qibContainer or CreateFrame("Frame", nil, detailScrollChild)
    detailScrollChild._qibContainer = container
    container:SetParent(detailScrollChild)
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
    container:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)
    container:Show()

    local capturedYOffset = yOffset

    self._refreshCustomDetail = function()
        OneWoW_GUI:ClearFrame(container)
        local cy = BuildContent(container, capturedYOffset, isEnabled)
        detailScrollChild:SetHeight(math.abs(capturedYOffset) + math.abs(cy) + 20)
    end

    local cy = BuildContent(container, capturedYOffset, isEnabled)

    return yOffset + cy
end
