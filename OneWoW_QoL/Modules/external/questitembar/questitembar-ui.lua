local addonName, ns = ...

local function GetSettings()
    return ns.QuestItemBarModule.GetSettings()
end

local function MakeSection(parent, title, yOffset, T)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    header:SetText(title)
    header:SetTextColor(T("ACCENT_SECONDARY"))
    yOffset = yOffset - header:GetStringHeight() - 6

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    divider:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    return yOffset
end

local function ClearContainer(container)
    for _, child in ipairs({ container:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ container:GetRegions() }) do
        region:Hide()
    end
end

local function BuildContent(container, startYOffset, isEnabled)
    local L = ns.L
    local T = ns.T
    local s = GetSettings()
    local cy = 0

    cy = MakeSection(container, L["QUESTITEMBAR_SETTINGS_HEADER"], cy, T)

    local previewing = ns.QuestItemBarModule:IsPreviewActive()
    local previewBtn = ns.UI.CreateButton(nil, container,
        previewing and L["QUESTITEMBAR_HIDE_BAR"] or L["QUESTITEMBAR_SHOW_BAR"],
        120, 26)
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

    local lockBtn = ns.UI.CreateButton(nil, container,
        s.locked and (L["QUESTITEMBAR_LOCK_POSITION"] .. " (ON)") or (L["QUESTITEMBAR_LOCK_POSITION"] .. " (OFF)"),
        180, 26)
    lockBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    lockBtn:SetScript("OnClick", function()
        ns.QuestItemBarModule:SetLocked(not GetSettings().locked)
        ns.QuestItemBarModule._refreshCustomDetail()
    end)
    cy = cy - 32

    local hideCheck = CreateFrame("CheckButton", nil, container, "InterfaceOptionsCheckButtonTemplate")
    hideCheck:SetPoint("TOPLEFT", container, "TOPLEFT", 8, cy)
    hideCheck.Text:SetText(L["QUESTITEMBAR_HIDE_WHEN_EMPTY"])
    hideCheck.Text:SetTextColor(T("TEXT_PRIMARY"))
    hideCheck:SetChecked(s.hideWhenEmpty)
    hideCheck:SetScript("OnClick", function(self)
        GetSettings().hideWhenEmpty = self:GetChecked()
        ns.QuestItemBarModule:ScheduleUpdate()
    end)
    cy = cy - 28

    local sizeLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 12, cy)
    sizeLabel:SetText(string.format("%s: %d", L["QUESTITEMBAR_BUTTON_SIZE"], s.buttonSize or 36))
    sizeLabel:SetTextColor(T("TEXT_SECONDARY"))
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
    colsLabel:SetTextColor(T("TEXT_SECONDARY"))
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
    sortLabel:SetTextColor(T("TEXT_SECONDARY"))

    local sortBtn = ns.UI.CreateButton(nil, container, GetSortLabel(), 160, 26)
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
        ClearContainer(detailScrollChild._qibContainer)
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
        ClearContainer(container)
        local cy = BuildContent(container, capturedYOffset, isEnabled)
        detailScrollChild:SetHeight(math.abs(capturedYOffset) + math.abs(cy) + 20)
    end

    local cy = BuildContent(container, capturedYOffset, isEnabled)

    return yOffset + cy
end
