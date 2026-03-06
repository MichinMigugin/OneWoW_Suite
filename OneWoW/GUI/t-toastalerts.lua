local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI
local L    = OneWoW.L

local SOUND_OPTIONS = {
    { labelKey = "TOAST_SOUND_NONE",      id = 0 },
    { labelKey = "TOAST_SOUND_RAIDALERT", id = SOUNDKIT.READY_CHECK },
    { labelKey = "TOAST_SOUND_CHIME",     id = SOUNDKIT.ACHIEVEMENT_MENU_OPEN },
}

local function T(key)
    if OneWoW.Constants and OneWoW.Constants.THEME and OneWoW.Constants.THEME[key] then
        return unpack(OneWoW.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function ClearPanel(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        region:Hide()
    end
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

local function AddSectionDivider(dsc, yOffset)
    local div = dsc:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    div:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    div:SetColorTexture(T("BORDER_SUBTLE"))
    return yOffset - 12
end

local function AddSectionHeader(dsc, yOffset, text)
    local header = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    header:SetText(text)
    header:SetTextColor(T("ACCENT_PRIMARY"))
    return header, yOffset - header:GetStringHeight() - 8
end

local function CreateSoundDropdown(dsc, dbSection, yOffset)
    local db = GetToastsDB()
    if not db then return yOffset end
    local section = db[dbSection]
    if not section then return yOffset end

    local dropBtn = CreateFrame("Button", nil, dsc, "BackdropTemplate")
    dropBtn:SetSize(200, 30)
    dropBtn:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    dropBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = false,
        tileSize = 16,
        edgeSize = 14,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    dropBtn:SetBackdropColor(T("BG_TERTIARY"))
    dropBtn:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local dropText = dropBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dropText:SetPoint("LEFT",  dropBtn, "LEFT",  8,   0)
    dropText:SetPoint("RIGHT", dropBtn, "RIGHT", -20, 0)
    dropText:SetJustifyH("LEFT")
    dropText:SetText(GetSoundLabel(section.sound))
    dropText:SetTextColor(T("TEXT_PRIMARY"))

    local arrowTex = dropBtn:CreateTexture(nil, "OVERLAY")
    arrowTex:SetSize(12, 8)
    arrowTex:SetPoint("RIGHT", dropBtn, "RIGHT", -6, 0)
    arrowTex:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    local playBtn = GUI:CreateButton(nil, dsc, L["TOAST_SOUND_PLAY_BTN"] or "Play", 48, 30)
    playBtn:SetPoint("LEFT", dropBtn, "RIGHT", 6, 0)
    playBtn:SetScript("OnClick", function()
        local soundId = section.sound or 0
        if soundId > 0 then
            PlaySound(soundId, "Master")
        end
    end)

    local menuH    = (#SOUND_OPTIONS * 27) + 10
    local menuFrame = CreateFrame("Frame", nil, dsc, "BackdropTemplate")
    menuFrame:SetSize(200, menuH)
    menuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    menuFrame:SetPoint("TOPLEFT", dropBtn, "BOTTOMLEFT", 0, -2)
    menuFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = false,
        tileSize = 16,
        edgeSize = 14,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    menuFrame:SetBackdropColor(T("BG_SECONDARY"))
    menuFrame:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    menuFrame:Hide()
    menuFrame:EnableMouse(true)

    local menuTimer = nil

    menuFrame:SetScript("OnLeave", function()
        menuTimer = C_Timer.NewTimer(0.5, function()
            menuFrame:Hide()
        end)
    end)
    menuFrame:SetScript("OnEnter", function()
        if menuTimer then menuTimer:Cancel(); menuTimer = nil end
    end)

    local itemY = -5
    for _, opt in ipairs(SOUND_OPTIONS) do
        local capturedOpt = opt
        local item = CreateFrame("Button", nil, menuFrame, "BackdropTemplate")
        item:SetSize(188, 25)
        item:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 6, itemY)
        item:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        item:SetBackdropColor(T("BG_SECONDARY"))

        local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        itemText:SetPoint("LEFT", item, "LEFT", 6, 0)
        itemText:SetText(L[capturedOpt.labelKey] or capturedOpt.labelKey)
        if section.sound == capturedOpt.id then
            itemText:SetTextColor(T("ACCENT_PRIMARY"))
        else
            itemText:SetTextColor(T("TEXT_PRIMARY"))
        end
        item._text = itemText

        item:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
            self._text:SetTextColor(T("TEXT_ACCENT"))
            if menuTimer then menuTimer:Cancel(); menuTimer = nil end
        end)
        item:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_SECONDARY"))
            if section.sound == capturedOpt.id then
                self._text:SetTextColor(T("ACCENT_PRIMARY"))
            else
                self._text:SetTextColor(T("TEXT_PRIMARY"))
            end
            menuTimer = C_Timer.NewTimer(0.5, function()
                menuFrame:Hide()
            end)
        end)
        item:SetScript("OnClick", function()
            section.sound = capturedOpt.id
            dropText:SetText(L[capturedOpt.labelKey] or capturedOpt.labelKey)
            menuFrame:Hide()
            for _, child in ipairs({ menuFrame:GetChildren() }) do
                if child._text then
                    if section.sound == capturedOpt.id then
                        child._text:SetTextColor(T("ACCENT_PRIMARY"))
                    else
                        child._text:SetTextColor(T("TEXT_PRIMARY"))
                    end
                end
            end
        end)

        itemY = itemY - 27
    end

    dropBtn:SetScript("OnClick", function()
        if menuFrame:IsShown() then
            menuFrame:Hide()
        else
            menuFrame:Show()
            menuFrame:SetFrameLevel(dropBtn:GetFrameLevel() + 10)
        end
    end)

    return yOffset - 30 - 10
end

local function AddGeneralExtras(dsc, yOffset)
    yOffset = AddSectionDivider(dsc, yOffset)
    local _, newY = AddSectionHeader(dsc, yOffset, "Anchor Position")
    yOffset = newY

    local infoText = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    infoText:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    infoText:SetJustifyH("LEFT")
    infoText:SetWordWrap(true)
    infoText:SetText(L["TOAST_ANCHOR_INFO"] or "The anchor is visible on screen. Drag it to reposition where toasts appear.")
    infoText:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - infoText:GetStringHeight() - 10

    local showAnchorBtn = GUI:CreateButton(nil, dsc, L["TOAST_ANCHOR_SHOW_BTN"] or "Show Anchor", 120, 28)
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
    yOffset = AddSectionDivider(dsc, yOffset)
    local headerRef, newY = AddSectionHeader(dsc, yOffset, L["TOAST_LOOT_TYPES_HEADER"] or "Collection Types")
    yOffset = newY

    local db   = GetToastsDB()
    local loot = db and db.loot or {}

    local types = {
        { key = "mounts",  label = L["TOAST_LOOT_MOUNTS"]  or "Mounts" },
        { key = "pets",    label = L["TOAST_LOOT_PETS"]    or "Battle Pets" },
        { key = "toys",    label = L["TOAST_LOOT_TOYS"]    or "Toys" },
        { key = "recipes", label = L["TOAST_LOOT_RECIPES"] or "Recipes" },
        { key = "tmogs",   label = L["TOAST_LOOT_TMOGS"]   or "Transmog" },
    }

    local prevRef = headerRef
    for _, entry in ipairs(types) do
        local capturedKey = entry.key
        local cb = GUI:CreateCheckbox(nil, dsc, entry.label)
        cb:SetPoint("TOPLEFT", prevRef, "BOTTOMLEFT", 0, -8)
        cb:SetChecked(loot[capturedKey] ~= false)
        cb:SetScript("OnClick", function(self)
            local tdb = GetToastsDB()
            if tdb and tdb.loot then
                tdb.loot[capturedKey] = self:GetChecked()
            end
        end)
        prevRef  = cb
        yOffset  = yOffset - 32
    end

    yOffset = yOffset - 8
    yOffset = AddSectionDivider(dsc, yOffset)
    _, yOffset = AddSectionHeader(dsc, yOffset, L["TOAST_SOUND_HEADER"] or "Alert Sound")
    yOffset = CreateSoundDropdown(dsc, "loot", yOffset)

    return yOffset
end

local function AddInstanceExtras(dsc, yOffset)
    yOffset = AddSectionDivider(dsc, yOffset)

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
    yOffset = AddSectionDivider(dsc, yOffset)
    local headerRef, newY = AddSectionHeader(dsc, yOffset, L["TOAST_NOTES_TYPES_HEADER"] or "Alert Types")
    yOffset = newY

    local db    = GetToastsDB()
    local notes = db and db.notes or {}

    local types = {
        { key = "npcs",    label = L["TOAST_NOTES_NPCS"]    or "NPC Alerts" },
        { key = "players", label = L["TOAST_NOTES_PLAYERS"] or "Player Alerts" },
        { key = "zones",   label = L["TOAST_NOTES_ZONES"]   or "Zone Alerts" },
    }

    local prevRef = headerRef
    for _, entry in ipairs(types) do
        local capturedKey = entry.key
        local cb = GUI:CreateCheckbox(nil, dsc, entry.label)
        cb:SetPoint("TOPLEFT", prevRef, "BOTTOMLEFT", 0, -8)
        cb:SetChecked(notes[capturedKey] ~= false)
        cb:SetScript("OnClick", function(self)
            local tdb = GetToastsDB()
            if tdb and tdb.notes then
                tdb.notes[capturedKey] = self:GetChecked()
            end
        end)
        prevRef = cb
        yOffset = yOffset - 32
    end

    yOffset = yOffset - 8
    yOffset = AddSectionDivider(dsc, yOffset)
    _, yOffset = AddSectionHeader(dsc, yOffset, L["TOAST_SOUND_HEADER"] or "Alert Sound")
    yOffset = CreateSoundDropdown(dsc, "notes", yOffset)

    return yOffset
end

local function ShowFeatureDetail(split, feature, tabName, selectedRow)
    local dsc = split.detailScrollChild
    ClearPanel(dsc)

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
        statusValue:SetTextColor(0.2, 1.0, 0.2)
    else
        statusValue:SetText(L["FEATURE_DISABLED"])
        statusValue:SetTextColor(1.0, 0.2, 0.2)
    end

    local toggleBtn = GUI:CreateButton(nil, dsc, isEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"], 90, 24)
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
            statusValue:SetTextColor(0.2, 1.0, 0.2)
        else
            statusValue:SetText(L["FEATURE_DISABLED"])
            statusValue:SetTextColor(1.0, 0.2, 0.2)
        end
        self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
        if selectedRow and selectedRow.enabledDot then
            if nowEnabled then
                selectedRow.enabledDot:SetVertexColor(0.35, 0.70, 0.35, 1.0)
            else
                selectedRow.enabledDot:SetVertexColor(0.70, 0.30, 0.30, 1.0)
            end
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
    ClearPanel(lsc)

    local features = OneWoW.SettingsFeatureRegistry:GetByTab(tabName)
    local selectedRow = nil
    local yOffset = -5

    for _, feature in ipairs(features) do
        local capturedFeature = feature
        local row = CreateFrame("Button", nil, lsc, "BackdropTemplate")
        row:SetPoint("TOPLEFT", lsc, "TOPLEFT", 4, yOffset)
        row:SetPoint("TOPRIGHT", lsc, "TOPRIGHT", -4, yOffset)
        row:SetHeight(32)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        row:SetBackdropColor(T("BG_SECONDARY"))
        row:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rowLabel:SetPoint("LEFT",  row, "LEFT",  10, 0)
        rowLabel:SetPoint("RIGHT", row, "RIGHT", -22, 0)
        rowLabel:SetJustifyH("LEFT")
        rowLabel:SetText(L[feature.title] or feature.title)
        rowLabel:SetTextColor(T("TEXT_PRIMARY"))
        row.rowLabel = rowLabel

        local dot = row:CreateTexture(nil, "OVERLAY")
        dot:SetSize(8, 8)
        dot:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        dot:SetTexture("Interface\\Buttons\\WHITE8x8")
        if OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, feature.id) then
            dot:SetVertexColor(0.35, 0.70, 0.35, 1.0)
        else
            dot:SetVertexColor(0.70, 0.30, 0.30, 1.0)
        end
        row.enabledDot = dot

        row:SetScript("OnClick", function(self)
            if selectedRow and selectedRow ~= self then
                selectedRow:SetBackdropColor(T("BG_SECONDARY"))
                selectedRow:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                if selectedRow.rowLabel then
                    selectedRow.rowLabel:SetTextColor(T("TEXT_PRIMARY"))
                end
            end
            selectedRow = self
            self:SetBackdropColor(T("BG_ACTIVE"))
            self:SetBackdropBorderColor(T("BORDER_ACCENT"))
            rowLabel:SetTextColor(T("TEXT_ACCENT"))
            ShowFeatureDetail(split, capturedFeature, tabName, self)
            if split.rightStatusText then
                local featureName    = L[capturedFeature.title] or capturedFeature.title
                local featureEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, capturedFeature.id)
                split.rightStatusText:SetText(featureName .. (featureEnabled and " (Enabled)" or " (Disabled)"))
            end
        end)
        row:SetScript("OnEnter", function(self)
            if selectedRow ~= self then
                self:SetBackdropColor(T("BG_HOVER"))
                rowLabel:SetTextColor(T("TEXT_ACCENT"))
            end
        end)
        row:SetScript("OnLeave", function(self)
            if selectedRow ~= self then
                self:SetBackdropColor(T("BG_SECONDARY"))
                rowLabel:SetTextColor(T("TEXT_PRIMARY"))
            end
        end)

        yOffset = yOffset - 36
    end

    lsc:SetHeight(math.abs(yOffset) + 10)
    split.UpdateListThumb()

    if #features > 0 then
        local firstRow = lsc:GetChildren()
        if firstRow then firstRow:Click() end
    end
end

function GUI:CreateToastAlertsTab(parent)
    local split = GUI:CreateSplitPanel(parent)
    split.listTitle:SetText(L["TOAST_ALERTS_LIST_TITLE"])
    split.detailTitle:SetText(L["TOAST_ALERTS_DETAIL_TITLE"])

    C_Timer.After(0.1, function()
        BuildFeatureList(split, "toastalerts")
        local features = OneWoW.SettingsFeatureRegistry:GetByTab("toastalerts")
        local enabledCount = 0
        for _, f in ipairs(features) do
            if OneWoW.SettingsFeatureRegistry:IsEnabled("toastalerts", f.id) then
                enabledCount = enabledCount + 1
            end
        end
        split.leftStatusText:SetText(string.format("Features: %d/%d", enabledCount, #features))
    end)
end
