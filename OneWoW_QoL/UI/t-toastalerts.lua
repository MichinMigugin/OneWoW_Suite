local _, ns = ...

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI

-- Locale strings stay in core OneWoW.L during the QoL transition
-- (MIGRATION step 9 shared rules).
local L = OneWoW.L

local SOUND_OPTIONS = {
    { labelKey = "TOAST_SOUND_NONE",      id = 0 },
    { labelKey = "TOAST_SOUND_RAIDALERT", id = SOUNDKIT.READY_CHECK },
    { labelKey = "TOAST_SOUND_CHIME",     id = SOUNDKIT.ACHIEVEMENT_MENU_OPEN },
}

local function GetSoundLabel(soundId)
    for _, opt in ipairs(SOUND_OPTIONS) do
        if opt.id == soundId then
            return L[opt.labelKey]
        end
    end
    return L["TOAST_SOUND_NONE"]
end

local function CreateSoundDropdown(dsc, featureId, yOffset)
    local reg = OneWoW.SettingsFeatureRegistry

    local dropBtn = OneWoW_GUI:CreateDropdown(dsc, {
        width = 200,
        text = GetSoundLabel(reg:GetSetting("toastalerts", featureId, "sound")),
    })
    dropBtn:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)

    OneWoW_GUI:AttachFilterMenu(dropBtn, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(SOUND_OPTIONS) do
                table.insert(items, { text = L[opt.labelKey], value = opt.id })
            end
            return items
        end,
        onSelect = function(value, text)
            reg:SetSetting("toastalerts", featureId, "sound", value)
            dropBtn._text:SetText(text)
        end,
        getActiveValue = function() return reg:GetSetting("toastalerts", featureId, "sound") end,
    })

    local playBtn = OneWoW_GUI:CreateFitTextButton(dsc, { text = L["TOAST_SOUND_PLAY_BTN"], height = 26 })
    playBtn:SetPoint("LEFT", dropBtn, "RIGHT", 6, 0)
    playBtn:SetScript("OnClick", function()
        local soundId = reg:GetSetting("toastalerts", featureId, "sound") or 0
        if soundId > 0 then
            PlaySound(soundId, "Master")
        end
    end)

    return yOffset - 30 - 10
end

local function AddGeneralExtras(dsc, yOffset)
    yOffset = OneWoW_GUI:CreateSection(dsc, { title = "Anchor Position", yOffset = yOffset })

    local infoText = OneWoW_GUI:CreateFS(dsc, 12)
    infoText:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    infoText:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    infoText:SetJustifyH("LEFT")
    infoText:SetWordWrap(true)
    infoText:SetText(L["TOAST_ANCHOR_INFO"])
    infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - infoText:GetStringHeight() - 10

    local showAnchorBtn = OneWoW_GUI:CreateFitTextButton(dsc, { text = L["TOAST_ANCHOR_SHOW_BTN"], height = 28 })
    showAnchorBtn:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    showAnchorBtn:SetScript("OnClick", function(self)
        local Toasts = OneWoW.Toasts
        if Toasts.anchorVisible then
            Toasts.HideAnchor()
            self.text:SetText(L["TOAST_ANCHOR_SHOW_BTN"])
        else
            Toasts.ShowAnchor()
            self.text:SetText(L["TOAST_ANCHOR_HIDE_BTN"])
        end
    end)
    yOffset = yOffset - 28 - 10

    return yOffset
end

local function AddDetectionExtras(dsc, yOffset)
    yOffset = OneWoW_GUI:CreateSection(dsc, { title = L["TOAST_LOOT_TYPES_HEADER"], yOffset = yOffset })

    local reg = OneWoW.SettingsFeatureRegistry
    local cfg = reg:GetFeatureSettings("toastalerts", "detectiontypes")

    local types = {
        { key = "mounts",  label = L["TOAST_LOOT_MOUNTS"] },
        { key = "pets",    label = L["TOAST_LOOT_PETS"] },
        { key = "toys",    label = L["TOAST_LOOT_TOYS"] },
        { key = "recipes", label = L["TOAST_LOOT_RECIPES"] },
        { key = "tmogs",   label = L["TOAST_LOOT_TMOGS"] },
    }

    for _, entry in ipairs(types) do
        local capturedKey = entry.key
        local cb = OneWoW_GUI:CreateCheckbox(dsc, { label = entry.label })
        cb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        cb:SetChecked(cfg[capturedKey] ~= false)

        local recipesOnlyCb = nil
        if capturedKey == "recipes" then
            yOffset = yOffset - 32
            recipesOnlyCb = OneWoW_GUI:CreateCheckbox(dsc, {
                label = L["TOAST_LOOT_RECIPES_ONLY_MY_PROFESSIONS"],
            })
            recipesOnlyCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 32, yOffset)
            recipesOnlyCb:SetChecked(cfg.recipesOnlyMyProfessions == true)
            recipesOnlyCb:SetEnabled(cfg.recipes ~= false)
            recipesOnlyCb:SetScript("OnClick", function(self)
                reg:SetSetting("toastalerts", "detectiontypes", "recipesOnlyMyProfessions", self:GetChecked())
            end)
        end

        cb:SetScript("OnClick", function(self)
            reg:SetSetting("toastalerts", "detectiontypes", capturedKey, self:GetChecked())
            if recipesOnlyCb then
                recipesOnlyCb:SetEnabled(self:GetChecked())
            end
        end)

        yOffset = yOffset - 32
    end

    yOffset = yOffset - 8
    yOffset = OneWoW_GUI:CreateSection(dsc, {
        title = L["TOAST_LOOT_SUPPRESS_BLIZZARD_HEADER"],
        yOffset = yOffset,
    })

    local suppressCb = OneWoW_GUI:CreateCheckbox(dsc, {
        label = L["TOAST_LOOT_SUPPRESS_BLIZZARD"],
    })
    suppressCb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    suppressCb:SetChecked(cfg.suppressBlizzardAlerts == true)
    suppressCb:SetScript("OnClick", function(self)
        reg:SetSetting("toastalerts", "detectiontypes", "suppressBlizzardAlerts", self:GetChecked())
        OneWoW.Toasts.ApplyBlizzardSuppression()
    end)
    yOffset = yOffset - 32

    yOffset = yOffset - 8
    yOffset = OneWoW_GUI:CreateSection(dsc, { title = L["TOAST_SOUND_HEADER"], yOffset = yOffset })
    yOffset = CreateSoundDropdown(dsc, "detectiontypes", yOffset)

    return yOffset
end

local function AddInstanceExtras(dsc, yOffset)
    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local infoText = OneWoW_GUI:CreateFS(dsc, 12)
    infoText:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    infoText:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    infoText:SetJustifyH("LEFT")
    infoText:SetWordWrap(true)
    infoText:SetText(L["TOAST_INSTANCE_DELAY_INFO"] or
        "Shown 3 seconds after entering an instance. Requires Catalog data modules for completion data.")
    infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - infoText:GetStringHeight() - 10

    return yOffset
end

local function AddItemAlertsExtras(dsc, yOffset)
    yOffset = OneWoW_GUI:CreateSection(dsc, { title = L["TOAST_NOTES_TYPES_HEADER"], yOffset = yOffset })

    local reg = OneWoW.SettingsFeatureRegistry
    local cfg = reg:GetFeatureSettings("toastalerts", "notealerts")

    local types = {
        { key = "npcs",    label = L["TOAST_NOTES_NPCS"] },
        { key = "players", label = L["TOAST_NOTES_PLAYERS"] },
        { key = "zones",   label = L["TOAST_NOTES_ZONES"] },
        { key = "items",   label = L["TOAST_NOTES_ITEMS"] },
    }

    for _, entry in ipairs(types) do
        local capturedKey = entry.key
        local cb = OneWoW_GUI:CreateCheckbox(dsc, { label = entry.label })
        cb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        cb:SetChecked(cfg[capturedKey] ~= false)
        cb:SetScript("OnClick", function(self)
            reg:SetSetting("toastalerts", "notealerts", capturedKey, self:GetChecked())
        end)
        yOffset = yOffset - 32
    end

    yOffset = yOffset - 8
    yOffset = OneWoW_GUI:CreateSection(dsc, { title = L["TOAST_SOUND_HEADER"], yOffset = yOffset })
    yOffset = CreateSoundDropdown(dsc, "notealerts", yOffset)

    return yOffset
end

local function ShowFeatureDetail(split, feature, tabName, selectedRow)
    local dsc = split.detailScrollChild
    OneWoW_GUI:ClearFrame(dsc)

    local yOffset = -10

    local titleLabel = OneWoW_GUI:CreateFS(dsc, 16)
    titleLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title])
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local statusBlock = OneWoW_GUI:CreateFeatureStatusBlock(dsc, {
        yOffset = yOffset,
        statusLabel = L["FEATURE_STATUS_LABEL"],
        enabledText = L["FEATURE_ENABLED"],
        disabledText = L["FEATURE_DISABLED"],
        enableBtnText = L["FEATURE_ENABLE_BTN"],
        disableBtnText = L["FEATURE_DISABLE_BTN"],
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled(tabName, feature.id, newState)
            if selectedRow and selectedRow.dot then
                selectedRow.dot:SetStatus(newState)
            end
        end,
    })

    yOffset = statusBlock.getBottomY() - 14

    if feature.id == "general" then
        yOffset = AddGeneralExtras(dsc, yOffset)
    elseif feature.id == "detectiontypes" then
        yOffset = AddDetectionExtras(dsc, yOffset)
    elseif feature.id == "instances" then
        yOffset = AddInstanceExtras(dsc, yOffset)
    elseif feature.id == "notealerts" then
        yOffset = AddItemAlertsExtras(dsc, yOffset)
    end

    dsc:SetHeight(math.abs(yOffset) + 40)
    split.UpdateDetailThumb()
    OneWoW_GUI:ApplyFontToFrame(dsc)
end

local function BuildFeatureList(split, tabName)
    local lsc = split.listScrollChild
    local features = OneWoW.SettingsFeatureRegistry:GetByTab(tabName)
    local selectedRow = nil
    local allRows = {}

    local function RenderRows(filterText)
        OneWoW_GUI:ClearFrame(lsc)
        selectedRow = nil
        allRows = {}
        local yOffset = -5
        local filter = (filterText or ""):lower()

        for _, feature in ipairs(features) do
            local displayName = L[feature.title]
            if filter == "" or displayName:lower():find(filter, 1, true) then
                local capturedFeature = feature
                local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, feature.id)

                local row = OneWoW_GUI:CreateListRowBasic(lsc, {
                    height = 30,
                    label = displayName,
                    showDot = true,
                    dotEnabled = isEnabled,
                    onClick = function(self)
                        if selectedRow and selectedRow ~= self then
                            selectedRow:SetActive(false)
                        end
                        selectedRow = self
                        self:SetActive(true)
                        ShowFeatureDetail(split, capturedFeature, tabName, self)
                        if split.rightStatusText then
                            local fe = OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, capturedFeature.id)
                            split.rightStatusText:SetText(displayName .. (fe and " (Enabled)" or " (Disabled)"))
                        end
                    end,
                })
                row:SetPoint("TOPLEFT", lsc, "TOPLEFT", 4, yOffset)
                row:SetPoint("TOPRIGHT", lsc, "TOPRIGHT", -4, yOffset)

                table.insert(allRows, row)
                yOffset = yOffset - 34
            end
        end

        lsc:SetHeight(math.abs(yOffset) + 10)

        if #allRows > 0 and not selectedRow then
            allRows[1]:Click()
        end
    end

    RenderRows("")

    if split.searchBox then
        split.searchBox:SetScript("OnTextChanged", function(self)
            local text = self:GetSearchText()
            RenderRows(text)
        end)
    end

    local enabledCount = 0
    for _, f in ipairs(features) do
        if OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, f.id) then
            enabledCount = enabledCount + 1
        end
    end
    split.leftStatusText:SetText(string.format("Features: %d/%d", enabledCount, #features))
end

function ns.UI.CreateToastAlertsTab(parent)
    local split = OneWoW_GUI:CreateSplitPanel(parent, {
        showSearch = true,
        searchPlaceholder = L["SEARCH_HINT"],
    })
    split.listTitle:SetText(L["TOAST_ALERTS_LIST_TITLE"])
    split.detailTitle:SetText(L["TOAST_ALERTS_DETAIL_TITLE"])

    C_Timer.After(0.1, function()
        BuildFeatureList(split, "toastalerts")
        OneWoW_GUI:ApplyFontToFrame(parent)
    end)
end
