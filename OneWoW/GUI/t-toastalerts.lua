local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI
local L    = OneWoW.L
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local SOUND_OPTIONS = {
    { labelKey = "TOAST_SOUND_NONE",      id = 0 },
    { labelKey = "TOAST_SOUND_RAIDALERT", id = SOUNDKIT.READY_CHECK },
    { labelKey = "TOAST_SOUND_CHIME",     id = SOUNDKIT.ACHIEVEMENT_MENU_OPEN },
}

local function T(key)
    return OneWoW_GUI:GetThemeColor(key)
end

local function GetToastsDB()
    return OneWoW.db and OneWoW.db.global and OneWoW.db.global.toasts
end

local function GetSoundLabel(soundId)
    for _, opt in ipairs(SOUND_OPTIONS) do
        if opt.id == soundId then
            return L[opt.labelKey] or opt.labelKey
        end
    end
    return L["TOAST_SOUND_NONE"] or "No Sound"
end

local function CreateSoundDropdown(dsc, dbSection, yOffset)
    local db = GetToastsDB()
    if not db then return yOffset end
    local section = db[dbSection]
    if not section then return yOffset end

    local dropBtn, dropText = OneWoW_GUI:CreateDropdown(dsc, {
        width = 200,
        text = GetSoundLabel(section.sound),
    })
    dropBtn:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)

    OneWoW_GUI:AttachFilterMenu(dropBtn, dropText, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(SOUND_OPTIONS) do
                table.insert(items, { text = L[opt.labelKey] or opt.labelKey, value = opt.id })
            end
            return items
        end,
        onSelect = function(value, text)
            section.sound = value
            dropText:SetText(text)
        end,
        getActiveValue = function() return section.sound end,
    })

    local playBtn = OneWoW_GUI:CreateButton(nil, dsc, L["TOAST_SOUND_PLAY_BTN"] or "Play", 48, 26)
    playBtn:SetPoint("LEFT", dropBtn, "RIGHT", 6, 0)
    playBtn:SetScript("OnClick", function()
        local soundId = section.sound or 0
        if soundId > 0 then
            PlaySound(soundId, "Master")
        end
    end)

    return yOffset - 30 - 10
end

local function AddGeneralExtras(dsc, yOffset)
    yOffset = OneWoW_GUI:CreateSection(dsc, "Anchor Position", yOffset)

    local infoText = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    infoText:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    infoText:SetJustifyH("LEFT")
    infoText:SetWordWrap(true)
    infoText:SetText(L["TOAST_ANCHOR_INFO"] or "The anchor is visible on screen. Drag it to reposition where toasts appear.")
    infoText:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - infoText:GetStringHeight() - 10

    local showAnchorBtn = OneWoW_GUI:CreateButton(nil, dsc, L["TOAST_ANCHOR_SHOW_BTN"] or "Show Anchor", 120, 28)
    showAnchorBtn:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    showAnchorBtn:SetScript("OnClick", function(self)
        local Toasts = OneWoW.Toasts
        if not Toasts then return end
        if Toasts.anchorVisible then
            Toasts.HideAnchor()
            self.text:SetText(L["TOAST_ANCHOR_SHOW_BTN"] or "Show Anchor")
        else
            Toasts.ShowAnchor()
            self.text:SetText(L["TOAST_ANCHOR_HIDE_BTN"] or "Hide Anchor")
        end
    end)
    yOffset = yOffset - 28 - 10

    return yOffset
end

local function AddDetectionExtras(dsc, yOffset)
    yOffset = OneWoW_GUI:CreateSection(dsc, L["TOAST_LOOT_TYPES_HEADER"] or "Collection Types", yOffset)

    local db   = GetToastsDB()
    local loot = db and db.loot or {}

    local types = {
        { key = "mounts",  label = L["TOAST_LOOT_MOUNTS"]  or "Mounts" },
        { key = "pets",    label = L["TOAST_LOOT_PETS"]    or "Battle Pets" },
        { key = "toys",    label = L["TOAST_LOOT_TOYS"]    or "Toys" },
        { key = "recipes", label = L["TOAST_LOOT_RECIPES"] or "Recipes" },
        { key = "tmogs",   label = L["TOAST_LOOT_TMOGS"]   or "Transmog" },
    }

    for _, entry in ipairs(types) do
        local capturedKey = entry.key
        local cb = OneWoW_GUI:CreateCheckbox(nil, dsc, entry.label)
        cb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        cb:SetChecked(loot[capturedKey] ~= false)
        cb:SetScript("OnClick", function(self)
            local tdb = GetToastsDB()
            if tdb and tdb.loot then
                tdb.loot[capturedKey] = self:GetChecked()
            end
        end)
        yOffset = yOffset - 32
    end

    yOffset = yOffset - 8
    yOffset = OneWoW_GUI:CreateSection(dsc, L["TOAST_SOUND_HEADER"] or "Alert Sound", yOffset)
    yOffset = CreateSoundDropdown(dsc, "loot", yOffset)

    return yOffset
end

local function AddInstanceExtras(dsc, yOffset)
    local div = dsc:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    div:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    div:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local infoText = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    infoText:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    infoText:SetJustifyH("LEFT")
    infoText:SetWordWrap(true)
    infoText:SetText(L["TOAST_INSTANCE_DELAY_INFO"] or
        "Shown 3 seconds after entering an instance. Requires Catalog data modules for completion data.")
    infoText:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - infoText:GetStringHeight() - 10

    return yOffset
end

local function AddItemAlertsExtras(dsc, yOffset)
    yOffset = OneWoW_GUI:CreateSection(dsc, L["TOAST_NOTES_TYPES_HEADER"] or "Alert Types", yOffset)

    local db    = GetToastsDB()
    local notes = db and db.notes or {}

    local types = {
        { key = "npcs",    label = L["TOAST_NOTES_NPCS"]    or "NPC Alerts" },
        { key = "players", label = L["TOAST_NOTES_PLAYERS"] or "Player Alerts" },
        { key = "zones",   label = L["TOAST_NOTES_ZONES"]   or "Zone Alerts" },
    }

    for _, entry in ipairs(types) do
        local capturedKey = entry.key
        local cb = OneWoW_GUI:CreateCheckbox(nil, dsc, entry.label)
        cb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
        cb:SetChecked(notes[capturedKey] ~= false)
        cb:SetScript("OnClick", function(self)
            local tdb = GetToastsDB()
            if tdb and tdb.notes then
                tdb.notes[capturedKey] = self:GetChecked()
            end
        end)
        yOffset = yOffset - 32
    end

    yOffset = yOffset - 8
    yOffset = OneWoW_GUI:CreateSection(dsc, L["TOAST_SOUND_HEADER"] or "Alert Sound", yOffset)
    yOffset = CreateSoundDropdown(dsc, "notes", yOffset)

    return yOffset
end

local function ShowFeatureDetail(split, feature, tabName, selectedRow)
    local dsc = split.detailScrollChild
    OneWoW_GUI:ClearFrame(dsc)

    local yOffset = -10

    local titleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(T("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    local divider = dsc:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    divider:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    divider:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local descLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(T("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, feature.id)

    local statusPrefix = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusPrefix:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    statusPrefix:SetText(L["FEATURE_STATUS_LABEL"])
    statusPrefix:SetTextColor(T("TEXT_PRIMARY"))

    local statusValue = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusValue:SetPoint("LEFT", statusPrefix, "RIGHT", 4, 0)
    if isEnabled then
        statusValue:SetText(L["FEATURE_ENABLED"])
        statusValue:SetTextColor(T("TEXT_FEATURES_ENABLED"))
    else
        statusValue:SetText(L["FEATURE_DISABLED"])
        statusValue:SetTextColor(T("TEXT_FEATURES_DISABLED"))
    end

    local toggleBtn = OneWoW_GUI:CreateButton(nil, dsc, isEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 24)
    toggleBtn:SetPoint("LEFT", statusValue, "RIGHT", 12, 0)
    toggleBtn:SetScript("OnClick", function(self)
        local nowEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, feature.id)
        OneWoW.SettingsFeatureRegistry:SetEnabled(tabName, feature.id, not nowEnabled)
        nowEnabled = not nowEnabled

        local tdb = GetToastsDB()
        if tdb then
            if feature.id == "general" then
                tdb.enabled = nowEnabled
            elseif feature.id == "detectiontypes" and tdb.loot then
                tdb.loot.enabled = nowEnabled
            elseif feature.id == "notealerts" and tdb.notes then
                tdb.notes.enabled = nowEnabled
            elseif feature.id == "instances" and tdb.instance then
                tdb.instance.enabled = nowEnabled
            end
        end

        if nowEnabled then
            statusValue:SetText(L["FEATURE_ENABLED"])
            statusValue:SetTextColor(T("TEXT_FEATURES_ENABLED"))
        else
            statusValue:SetText(L["FEATURE_DISABLED"])
            statusValue:SetTextColor(T("TEXT_FEATURES_DISABLED"))
        end
        self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
        if selectedRow and selectedRow.dot then
            selectedRow.dot:SetStatus(nowEnabled)
        end
    end)

    yOffset = yOffset - 30 - 14

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
            local displayName = L[feature.title] or feature.title
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

function GUI:CreateToastAlertsTab(parent)
    local split = OneWoW_GUI:CreateSplitPanel(parent, {
        showSearch = true,
        searchPlaceholder = L["SEARCH_PLACEHOLDER"] or "Search...",
    })
    split.listTitle:SetText(L["TOAST_ALERTS_LIST_TITLE"])
    split.detailTitle:SetText(L["TOAST_ALERTS_DETAIL_TITLE"])

    C_Timer.After(0.1, function()
        BuildFeatureList(split, "toastalerts")
    end)
end
