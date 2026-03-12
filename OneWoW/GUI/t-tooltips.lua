local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI
local L    = OneWoW.L
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local function T(key) return OneWoW_GUI:GetThemeColor(key) end

local function ShowGeneralDetail(split, dsc, selectedRow)
    local yOffset = -10

    local titleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L["TIPS_GENERAL_TITLE"])
    titleLabel:SetTextColor(T("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    local div = dsc:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    div:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    div:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local descLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L["TIPS_GENERAL_DESC"])
    descLabel:SetTextColor(T("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", "general")

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
        local nowEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", "general")
        OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", "general", not nowEnabled)
        nowEnabled = not nowEnabled
        if nowEnabled then
            statusValue:SetText(L["FEATURE_ENABLED"])
            statusValue:SetTextColor(T("TEXT_FEATURES_ENABLED"))
        else
            statusValue:SetText(L["FEATURE_DISABLED"])
            statusValue:SetTextColor(T("TEXT_FEATURES_DISABLED"))
        end
        self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
        if selectedRow and selectedRow.dot then
            if nowEnabled then
                selectedRow.dot:SetStatus(true)
            else
                selectedRow.dot:SetStatus(false)
            end
        end
    end)

    yOffset = yOffset - 30 - 20

    local noteLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    noteLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    noteLabel:SetJustifyH("LEFT")
    noteLabel:SetWordWrap(true)
    noteLabel:SetSpacing(3)
    noteLabel:SetText(L["TIPS_GENERAL_NOTE"])
    noteLabel:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - noteLabel:GetStringHeight() - 10

    dsc:SetHeight(math.abs(yOffset) + 20)
    GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local CUSTOMNOTES_LINE_TOGGLES = {
    { key = "showPlayerNotes", localeKey = "TIPS_CUSTOMNOTES_SHOW_PLAYERS" },
    { key = "showNpcNotes",    localeKey = "TIPS_CUSTOMNOTES_SHOW_NPCS" },
    { key = "showItemNotes",   localeKey = "TIPS_CUSTOMNOTES_SHOW_ITEMS" },
}

local CUSTOMNOTES_WARNING_TOGGLES = {
    { key = "showNoteWarning", localeKey = "TIPS_CUSTOMNOTES_SHOW_NOTEWARNING" },
}

local function CreateNoteToggleRows(dsc, toggleList, toggleBtnSets, isEnabled, cnSettings, yOffset)
    for _, toggle in ipairs(toggleList) do
        local capturedKey = toggle.key
        local currentVal = cnSettings[capturedKey] ~= false

        local onBtn = OneWoW_GUI:CreateButton(nil, dsc, L["TIPS_TOGGLE_ON"], 50, 22)
        onBtn:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)

        local offBtn = OneWoW_GUI:CreateButton(nil, dsc, L["TIPS_TOGGLE_OFF"], 50, 22)
        offBtn:SetPoint("RIGHT", onBtn, "LEFT", -4, 0)

        local rowStatusVal = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rowStatusVal:SetPoint("RIGHT", offBtn, "LEFT", -6, 0)

        local rowStatusPfx = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rowStatusPfx:SetPoint("RIGHT", rowStatusVal, "LEFT", -2, 0)
        rowStatusPfx:SetText(L["FEATURE_STATUS_LABEL"])

        local toggleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        toggleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset - 3)
        toggleLabel:SetPoint("RIGHT", rowStatusPfx, "LEFT", -8, 0)
        toggleLabel:SetJustifyH("LEFT")
        toggleLabel:SetText(L[toggle.localeKey] or toggle.localeKey)

        if isEnabled then
            toggleLabel:SetTextColor(T("TEXT_PRIMARY"))
            rowStatusPfx:SetTextColor(T("TEXT_PRIMARY"))
            if currentVal then
                onBtn.isActive = true
                offBtn.isActive = false
                onBtn:SetBackdropColor(T("BG_ACTIVE"))
                onBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                onBtn.text:SetTextColor(T("TEXT_ACCENT"))
                offBtn:SetBackdropColor(T("BTN_NORMAL"))
                offBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                offBtn.text:SetTextColor(T("TEXT_MUTED"))
                rowStatusVal:SetText(L["FEATURE_ENABLED"])
                rowStatusVal:SetTextColor(T("TEXT_FEATURES_ENABLED"))
            else
                offBtn.isActive = true
                onBtn.isActive = false
                offBtn:SetBackdropColor(T("BG_ACTIVE"))
                offBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                offBtn.text:SetTextColor(T("TEXT_ACCENT"))
                onBtn:SetBackdropColor(T("BTN_NORMAL"))
                onBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                onBtn.text:SetTextColor(T("TEXT_MUTED"))
                rowStatusVal:SetText(L["FEATURE_DISABLED"])
                rowStatusVal:SetTextColor(T("TEXT_FEATURES_DISABLED"))
            end
        else
            onBtn.isActive = false
            offBtn.isActive = false
            toggleLabel:SetTextColor(T("TEXT_MUTED"))
            rowStatusPfx:SetTextColor(T("TEXT_MUTED"))
            rowStatusVal:SetText(L["FEATURE_DISABLED"])
            rowStatusVal:SetTextColor(T("TEXT_MUTED"))
            onBtn:EnableMouse(false)
            offBtn:EnableMouse(false)
            onBtn:SetBackdropColor(T("BG_SECONDARY"))
            onBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            onBtn.text:SetTextColor(T("TEXT_MUTED"))
            offBtn:SetBackdropColor(T("BG_SECONDARY"))
            offBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            offBtn.text:SetTextColor(T("TEXT_MUTED"))
        end

        local function applyToggleHover(btn)
            if btn.isActive then
                btn:SetBackdropBorderColor(T("BORDER_FOCUS"))
            else
                btn:SetBackdropColor(T("BTN_HOVER"))
                btn:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
                btn.text:SetTextColor(T("TEXT_SECONDARY"))
            end
        end
        local function applyToggleNormal(btn)
            if btn.isActive then
                btn:SetBackdropColor(T("BG_ACTIVE"))
                btn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                btn.text:SetTextColor(T("TEXT_ACCENT"))
            else
                btn:SetBackdropColor(T("BTN_NORMAL"))
                btn:SetBackdropBorderColor(T("BTN_BORDER"))
                btn.text:SetTextColor(T("TEXT_MUTED"))
            end
        end
        onBtn:HookScript("OnEnter",   function(self) applyToggleHover(self)  end)
        onBtn:HookScript("OnLeave",   function(self) applyToggleNormal(self) end)
        onBtn:HookScript("OnMouseUp", function(self) applyToggleNormal(self) end)
        offBtn:HookScript("OnEnter",   function(self) applyToggleHover(self)  end)
        offBtn:HookScript("OnLeave",   function(self) applyToggleNormal(self) end)
        offBtn:HookScript("OnMouseUp", function(self) applyToggleNormal(self) end)

        tinsert(toggleBtnSets, { onBtn = onBtn, offBtn = offBtn, label = toggleLabel, statusPrefix = rowStatusPfx, statusVal = rowStatusVal, key = capturedKey })

        onBtn:SetScript("OnClick", function(self)
            if not OneWoW.db.global.settings.tooltips.customnotes then
                OneWoW.db.global.settings.tooltips.customnotes = {}
            end
            OneWoW.db.global.settings.tooltips.customnotes[capturedKey] = true
            onBtn.isActive = true
            offBtn.isActive = false
            self:SetBackdropColor(T("BG_ACTIVE"))
            self:SetBackdropBorderColor(T("BORDER_ACCENT"))
            self.text:SetTextColor(T("TEXT_ACCENT"))
            offBtn:SetBackdropColor(T("BTN_NORMAL"))
            offBtn:SetBackdropBorderColor(T("BTN_BORDER"))
            offBtn.text:SetTextColor(T("TEXT_MUTED"))
            rowStatusVal:SetText(L["FEATURE_ENABLED"])
            rowStatusVal:SetTextColor(T("TEXT_FEATURES_ENABLED"))
        end)
        offBtn:SetScript("OnClick", function(self)
            if not OneWoW.db.global.settings.tooltips.customnotes then
                OneWoW.db.global.settings.tooltips.customnotes = {}
            end
            OneWoW.db.global.settings.tooltips.customnotes[capturedKey] = false
            offBtn.isActive = true
            onBtn.isActive = false
            self:SetBackdropColor(T("BG_ACTIVE"))
            self:SetBackdropBorderColor(T("BORDER_ACCENT"))
            self.text:SetTextColor(T("TEXT_ACCENT"))
            onBtn:SetBackdropColor(T("BTN_NORMAL"))
            onBtn:SetBackdropBorderColor(T("BTN_BORDER"))
            onBtn.text:SetTextColor(T("TEXT_MUTED"))
            rowStatusVal:SetText(L["FEATURE_DISABLED"])
            rowStatusVal:SetTextColor(T("TEXT_FEATURES_DISABLED"))
        end)

        yOffset = yOffset - 22 - 10
    end

    return yOffset
end

local function ShowCustomNotesDetail(split, dsc, feature, selectedRow)
    local yOffset = -10

    local titleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(T("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    local div = dsc:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    div:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    div:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local descLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(T("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local toggleBtnSets = {}

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
        local nowEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
        OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, not nowEnabled)
        nowEnabled = not nowEnabled
        if nowEnabled then
            statusValue:SetText(L["FEATURE_ENABLED"])
            statusValue:SetTextColor(T("TEXT_FEATURES_ENABLED"))
        else
            statusValue:SetText(L["FEATURE_DISABLED"])
            statusValue:SetTextColor(T("TEXT_FEATURES_DISABLED"))
        end
        self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
        if selectedRow and selectedRow.dot then
            if nowEnabled then
                selectedRow.dot:SetStatus(true)
            else
                selectedRow.dot:SetStatus(false)
            end
        end
        for _, tbs in ipairs(toggleBtnSets) do
            if nowEnabled then
                tbs.onBtn:EnableMouse(true)
                tbs.offBtn:EnableMouse(true)
                tbs.label:SetTextColor(T("TEXT_PRIMARY"))
                tbs.statusPrefix:SetTextColor(T("TEXT_PRIMARY"))
                local val = OneWoW.db.global.settings.tooltips.customnotes[tbs.key]
                if val ~= false then
                    tbs.onBtn.isActive = true
                    tbs.offBtn.isActive = false
                    tbs.onBtn:SetBackdropColor(T("BG_ACTIVE"))
                    tbs.onBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                    tbs.onBtn.text:SetTextColor(T("TEXT_ACCENT"))
                    tbs.offBtn:SetBackdropColor(T("BTN_NORMAL"))
                    tbs.offBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                    tbs.offBtn.text:SetTextColor(T("TEXT_MUTED"))
                    tbs.statusVal:SetText(L["FEATURE_ENABLED"])
                    tbs.statusVal:SetTextColor(T("TEXT_FEATURES_ENABLED"))
                else
                    tbs.offBtn.isActive = true
                    tbs.onBtn.isActive = false
                    tbs.offBtn:SetBackdropColor(T("BG_ACTIVE"))
                    tbs.offBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                    tbs.offBtn.text:SetTextColor(T("TEXT_ACCENT"))
                    tbs.onBtn:SetBackdropColor(T("BTN_NORMAL"))
                    tbs.onBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                    tbs.onBtn.text:SetTextColor(T("TEXT_MUTED"))
                    tbs.statusVal:SetText(L["FEATURE_DISABLED"])
                    tbs.statusVal:SetTextColor(T("TEXT_FEATURES_DISABLED"))
                end
            else
                tbs.onBtn.isActive = false
                tbs.offBtn.isActive = false
                tbs.onBtn:EnableMouse(false)
                tbs.offBtn:EnableMouse(false)
                tbs.label:SetTextColor(T("TEXT_MUTED"))
                tbs.statusPrefix:SetTextColor(T("TEXT_MUTED"))
                tbs.statusVal:SetText(L["FEATURE_DISABLED"])
                tbs.statusVal:SetTextColor(T("TEXT_MUTED"))
                tbs.onBtn:SetBackdropColor(T("BG_SECONDARY"))
                tbs.onBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                tbs.onBtn.text:SetTextColor(T("TEXT_MUTED"))
                tbs.offBtn:SetBackdropColor(T("BG_SECONDARY"))
                tbs.offBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                tbs.offBtn.text:SetTextColor(T("TEXT_MUTED"))
            end
        end
    end)

    yOffset = yOffset - 30 - 14

    local reqDiv = dsc:CreateTexture(nil, "ARTWORK")
    reqDiv:SetHeight(1)
    reqDiv:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    reqDiv:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    reqDiv:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local reqLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reqLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    reqLabel:SetText(L["TIPS_CUSTOMNOTES_REQUIRES"])
    reqLabel:SetTextColor(T("TEXT_PRIMARY"))

    local notesLoaded = (_G.OneWoW_Notes ~= nil)
    local detectedValue = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detectedValue:SetPoint("LEFT", reqLabel, "RIGHT", 8, 0)
    if notesLoaded then
        detectedValue:SetText(L["TIPS_CUSTOMNOTES_DETECTED"])
        detectedValue:SetTextColor(T("TEXT_FEATURES_ENABLED"))
    else
        detectedValue:SetText(L["TIPS_CUSTOMNOTES_NOT_DETECTED"])
        detectedValue:SetTextColor(T("TEXT_FEATURES_DISABLED"))
    end

    yOffset = yOffset - 24

    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local cnSettings = db and db.tooltips and db.tooltips.customnotes or {}

    local linesHeader = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    linesHeader:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    linesHeader:SetText(L["TIPS_CUSTOMNOTES_SECTION_LINES"])
    linesHeader:SetTextColor(T("ACCENT_SECONDARY"))
    yOffset = yOffset - linesHeader:GetStringHeight() - 4

    local linesDesc = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    linesDesc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    linesDesc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    linesDesc:SetJustifyH("LEFT")
    linesDesc:SetWordWrap(true)
    linesDesc:SetSpacing(2)
    linesDesc:SetText(L["TIPS_CUSTOMNOTES_SECTION_LINES_DESC"])
    linesDesc:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - linesDesc:GetStringHeight() - 6

    local linesDivider = dsc:CreateTexture(nil, "ARTWORK")
    linesDivider:SetHeight(1)
    linesDivider:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    linesDivider:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    linesDivider:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    yOffset = CreateNoteToggleRows(dsc, CUSTOMNOTES_LINE_TOGGLES, toggleBtnSets, isEnabled, cnSettings, yOffset)

    yOffset = yOffset - 6

    local warnHeader = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warnHeader:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    warnHeader:SetText(L["TIPS_CUSTOMNOTES_SECTION_WARNING"])
    warnHeader:SetTextColor(T("ACCENT_SECONDARY"))
    yOffset = yOffset - warnHeader:GetStringHeight() - 4

    local warnDesc = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    warnDesc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    warnDesc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    warnDesc:SetJustifyH("LEFT")
    warnDesc:SetWordWrap(true)
    warnDesc:SetSpacing(2)
    warnDesc:SetText(L["TIPS_CUSTOMNOTES_SECTION_WARNING_DESC"])
    warnDesc:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - warnDesc:GetStringHeight() - 6

    local warnDivider = dsc:CreateTexture(nil, "ARTWORK")
    warnDivider:SetHeight(1)
    warnDivider:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    warnDivider:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    warnDivider:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    yOffset = CreateNoteToggleRows(dsc, CUSTOMNOTES_WARNING_TOGGLES, toggleBtnSets, isEnabled, cnSettings, yOffset)

    dsc:SetHeight(math.abs(yOffset) + 20)
    GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local TECHID_TOGGLES = {
    { key = "showItemID",           localeKey = "TIPS_TECHID_SHOW_ITEMID" },
    { key = "showSpellID",          localeKey = "TIPS_TECHID_SHOW_SPELLID" },
    { key = "showNpcID",            localeKey = "TIPS_TECHID_SHOW_NPCID" },
    { key = "showAchievementID",    localeKey = "TIPS_TECHID_SHOW_ACHIEVEMENTID" },
    { key = "showQuestID",          localeKey = "TIPS_TECHID_SHOW_QUESTID" },
    { key = "showCurrencyID",       localeKey = "TIPS_TECHID_SHOW_CURRENCYID" },
    { key = "showMountID",          localeKey = "TIPS_TECHID_SHOW_MOUNTID" },
    { key = "showPetID",            localeKey = "TIPS_TECHID_SHOW_PETID" },
    { key = "showEnchantID",        localeKey = "TIPS_TECHID_SHOW_ENCHANTID" },
    { key = "showIconID",           localeKey = "TIPS_TECHID_SHOW_ICONID" },
    { key = "showExpansionID",      localeKey = "TIPS_TECHID_SHOW_EXPANSIONID" },
    { key = "showSetID",            localeKey = "TIPS_TECHID_SHOW_SETID" },
    { key = "showDecorEntryID",     localeKey = "TIPS_TECHID_SHOW_DECORENTRYID" },
    { key = "showRecipeID",         localeKey = "TIPS_TECHID_SHOW_RECIPEID" },
    { key = "showEquipmentSetID",   localeKey = "TIPS_TECHID_SHOW_EQUIPMENTSETID" },
    { key = "showEssenceID",        localeKey = "TIPS_TECHID_SHOW_ESSENCEID" },
    { key = "showConduitID",        localeKey = "TIPS_TECHID_SHOW_CONDUITID" },
    { key = "showOutfitID",         localeKey = "TIPS_TECHID_SHOW_OUTFITID" },
    { key = "showMacroID",          localeKey = "TIPS_TECHID_SHOW_MACROID" },
    { key = "showObjectID",         localeKey = "TIPS_TECHID_SHOW_OBJECTID" },
    { key = "showAbilityID",        localeKey = "TIPS_TECHID_SHOW_ABILITYID" },
    { key = "showAreaPoiID",        localeKey = "TIPS_TECHID_SHOW_AREAPOIID" },
    { key = "showArtifactPowerID",  localeKey = "TIPS_TECHID_SHOW_ARTIFACTPOWERID" },
    { key = "showBonusID",          localeKey = "TIPS_TECHID_SHOW_BONUSID" },
    { key = "showCompanionID",      localeKey = "TIPS_TECHID_SHOW_COMPANIONID" },
    { key = "showCriteriaID",       localeKey = "TIPS_TECHID_SHOW_CRITERIAID" },
    { key = "showGemID",            localeKey = "TIPS_TECHID_SHOW_GEMID" },
    { key = "showSourceID",         localeKey = "TIPS_TECHID_SHOW_SOURCEID" },
    { key = "showTalentID",         localeKey = "TIPS_TECHID_SHOW_TALENTID" },
    { key = "showTraitDefinitionID", localeKey = "TIPS_TECHID_SHOW_TRAITDEFINITIONID" },
    { key = "showTraitEntryID",     localeKey = "TIPS_TECHID_SHOW_TRAITENTRYID" },
    { key = "showTraitNodeID",      localeKey = "TIPS_TECHID_SHOW_TRAITNODEID" },
    { key = "showVignetteID",       localeKey = "TIPS_TECHID_SHOW_VIGNETTEID" },
    { key = "showVisualID",         localeKey = "TIPS_TECHID_SHOW_VISUALID" },
}

local function ShowTechnicalIDsDetail(split, dsc, feature, selectedRow)
    local yOffset = -10

    local titleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(T("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    local div = dsc:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    div:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    div:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local descLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(T("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local toggleBtnSets = {}

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
        local nowEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
        OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, not nowEnabled)
        nowEnabled = not nowEnabled
        if nowEnabled then
            statusValue:SetText(L["FEATURE_ENABLED"])
            statusValue:SetTextColor(T("TEXT_FEATURES_ENABLED"))
        else
            statusValue:SetText(L["FEATURE_DISABLED"])
            statusValue:SetTextColor(T("TEXT_FEATURES_DISABLED"))
        end
        self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
        if selectedRow and selectedRow.dot then
            if nowEnabled then
                selectedRow.dot:SetStatus(true)
            else
                selectedRow.dot:SetStatus(false)
            end
        end
        for _, tbs in ipairs(toggleBtnSets) do
            if nowEnabled then
                tbs.onBtn:EnableMouse(true)
                tbs.offBtn:EnableMouse(true)
                tbs.label:SetTextColor(T("TEXT_PRIMARY"))
                tbs.statusPrefix:SetTextColor(T("TEXT_PRIMARY"))
                local val = OneWoW.db.global.settings.tooltips.technicalids[tbs.key]
                if val ~= false then
                    tbs.onBtn.isActive = true
                    tbs.offBtn.isActive = false
                    tbs.onBtn:SetBackdropColor(T("BG_ACTIVE"))
                    tbs.onBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                    tbs.onBtn.text:SetTextColor(T("TEXT_ACCENT"))
                    tbs.offBtn:SetBackdropColor(T("BTN_NORMAL"))
                    tbs.offBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                    tbs.offBtn.text:SetTextColor(T("TEXT_MUTED"))
                    tbs.statusVal:SetText(L["FEATURE_ENABLED"])
                    tbs.statusVal:SetTextColor(T("TEXT_FEATURES_ENABLED"))
                else
                    tbs.offBtn.isActive = true
                    tbs.onBtn.isActive = false
                    tbs.offBtn:SetBackdropColor(T("BG_ACTIVE"))
                    tbs.offBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                    tbs.offBtn.text:SetTextColor(T("TEXT_ACCENT"))
                    tbs.onBtn:SetBackdropColor(T("BTN_NORMAL"))
                    tbs.onBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                    tbs.onBtn.text:SetTextColor(T("TEXT_MUTED"))
                    tbs.statusVal:SetText(L["FEATURE_DISABLED"])
                    tbs.statusVal:SetTextColor(T("TEXT_FEATURES_DISABLED"))
                end
            else
                tbs.onBtn.isActive = false
                tbs.offBtn.isActive = false
                tbs.onBtn:EnableMouse(false)
                tbs.offBtn:EnableMouse(false)
                tbs.label:SetTextColor(T("TEXT_MUTED"))
                tbs.statusPrefix:SetTextColor(T("TEXT_MUTED"))
                tbs.statusVal:SetText(L["FEATURE_DISABLED"])
                tbs.statusVal:SetTextColor(T("TEXT_MUTED"))
                tbs.onBtn:SetBackdropColor(T("BG_SECONDARY"))
                tbs.onBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                tbs.onBtn.text:SetTextColor(T("TEXT_MUTED"))
                tbs.offBtn:SetBackdropColor(T("BG_SECONDARY"))
                tbs.offBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                tbs.offBtn.text:SetTextColor(T("TEXT_MUTED"))
            end
        end
    end)

    yOffset = yOffset - 30 - 14

    local toggleHeader = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toggleHeader:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    toggleHeader:SetText(L["TIPS_MODULE_TOGGLES"])
    toggleHeader:SetTextColor(T("ACCENT_SECONDARY"))
    yOffset = yOffset - toggleHeader:GetStringHeight() - 8

    local toggleDivider = dsc:CreateTexture(nil, "ARTWORK")
    toggleDivider:SetHeight(1)
    toggleDivider:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    toggleDivider:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    toggleDivider:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local tidSettings = db and db.tooltips and db.tooltips.technicalids or {}

    for _, toggle in ipairs(TECHID_TOGGLES) do
        local capturedKey = toggle.key
        local currentVal = tidSettings[capturedKey] ~= false

        local onBtn = OneWoW_GUI:CreateButton(nil, dsc, L["TIPS_TOGGLE_ON"], 50, 22)
        onBtn:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)

        local offBtn = OneWoW_GUI:CreateButton(nil, dsc, L["TIPS_TOGGLE_OFF"], 50, 22)
        offBtn:SetPoint("RIGHT", onBtn, "LEFT", -4, 0)

        local rowStatusVal = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rowStatusVal:SetPoint("RIGHT", offBtn, "LEFT", -6, 0)

        local rowStatusPfx = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rowStatusPfx:SetPoint("RIGHT", rowStatusVal, "LEFT", -2, 0)
        rowStatusPfx:SetText(L["FEATURE_STATUS_LABEL"])

        local toggleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        toggleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset - 3)
        toggleLabel:SetPoint("RIGHT", rowStatusPfx, "LEFT", -8, 0)
        toggleLabel:SetJustifyH("LEFT")
        toggleLabel:SetText(L[toggle.localeKey] or toggle.localeKey)

        if isEnabled then
            toggleLabel:SetTextColor(T("TEXT_PRIMARY"))
            rowStatusPfx:SetTextColor(T("TEXT_PRIMARY"))
            if currentVal then
                onBtn.isActive = true
                offBtn.isActive = false
                onBtn:SetBackdropColor(T("BG_ACTIVE"))
                onBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                onBtn.text:SetTextColor(T("TEXT_ACCENT"))
                offBtn:SetBackdropColor(T("BTN_NORMAL"))
                offBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                offBtn.text:SetTextColor(T("TEXT_MUTED"))
                rowStatusVal:SetText(L["FEATURE_ENABLED"])
                rowStatusVal:SetTextColor(T("TEXT_FEATURES_ENABLED"))
            else
                offBtn.isActive = true
                onBtn.isActive = false
                offBtn:SetBackdropColor(T("BG_ACTIVE"))
                offBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                offBtn.text:SetTextColor(T("TEXT_ACCENT"))
                onBtn:SetBackdropColor(T("BTN_NORMAL"))
                onBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                onBtn.text:SetTextColor(T("TEXT_MUTED"))
                rowStatusVal:SetText(L["FEATURE_DISABLED"])
                rowStatusVal:SetTextColor(T("TEXT_FEATURES_DISABLED"))
            end
        else
            onBtn.isActive = false
            offBtn.isActive = false
            toggleLabel:SetTextColor(T("TEXT_MUTED"))
            rowStatusPfx:SetTextColor(T("TEXT_MUTED"))
            rowStatusVal:SetText(L["FEATURE_DISABLED"])
            rowStatusVal:SetTextColor(T("TEXT_MUTED"))
            onBtn:EnableMouse(false)
            offBtn:EnableMouse(false)
            onBtn:SetBackdropColor(T("BG_SECONDARY"))
            onBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            onBtn.text:SetTextColor(T("TEXT_MUTED"))
            offBtn:SetBackdropColor(T("BG_SECONDARY"))
            offBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            offBtn.text:SetTextColor(T("TEXT_MUTED"))
        end

        local function applyToggleHover(btn)
            if btn.isActive then
                btn:SetBackdropBorderColor(T("BORDER_FOCUS"))
            else
                btn:SetBackdropColor(T("BTN_HOVER"))
                btn:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
                btn.text:SetTextColor(T("TEXT_SECONDARY"))
            end
        end
        local function applyToggleNormal(btn)
            if btn.isActive then
                btn:SetBackdropColor(T("BG_ACTIVE"))
                btn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                btn.text:SetTextColor(T("TEXT_ACCENT"))
            else
                btn:SetBackdropColor(T("BTN_NORMAL"))
                btn:SetBackdropBorderColor(T("BTN_BORDER"))
                btn.text:SetTextColor(T("TEXT_MUTED"))
            end
        end
        onBtn:HookScript("OnEnter",   function(self) applyToggleHover(self)  end)
        onBtn:HookScript("OnLeave",   function(self) applyToggleNormal(self) end)
        onBtn:HookScript("OnMouseUp", function(self) applyToggleNormal(self) end)
        offBtn:HookScript("OnEnter",   function(self) applyToggleHover(self)  end)
        offBtn:HookScript("OnLeave",   function(self) applyToggleNormal(self) end)
        offBtn:HookScript("OnMouseUp", function(self) applyToggleNormal(self) end)

        tinsert(toggleBtnSets, { onBtn = onBtn, offBtn = offBtn, label = toggleLabel, statusPrefix = rowStatusPfx, statusVal = rowStatusVal, key = capturedKey })

        onBtn:SetScript("OnClick", function(self)
            OneWoW.db.global.settings.tooltips.technicalids[capturedKey] = true
            onBtn.isActive = true
            offBtn.isActive = false
            self:SetBackdropColor(T("BG_ACTIVE"))
            self:SetBackdropBorderColor(T("BORDER_ACCENT"))
            self.text:SetTextColor(T("TEXT_ACCENT"))
            offBtn:SetBackdropColor(T("BTN_NORMAL"))
            offBtn:SetBackdropBorderColor(T("BTN_BORDER"))
            offBtn.text:SetTextColor(T("TEXT_MUTED"))
            rowStatusVal:SetText(L["FEATURE_ENABLED"])
            rowStatusVal:SetTextColor(T("TEXT_FEATURES_ENABLED"))
        end)
        offBtn:SetScript("OnClick", function(self)
            OneWoW.db.global.settings.tooltips.technicalids[capturedKey] = false
            offBtn.isActive = true
            onBtn.isActive = false
            self:SetBackdropColor(T("BG_ACTIVE"))
            self:SetBackdropBorderColor(T("BORDER_ACCENT"))
            self.text:SetTextColor(T("TEXT_ACCENT"))
            onBtn:SetBackdropColor(T("BTN_NORMAL"))
            onBtn:SetBackdropBorderColor(T("BTN_BORDER"))
            onBtn.text:SetTextColor(T("TEXT_MUTED"))
            rowStatusVal:SetText(L["FEATURE_DISABLED"])
            rowStatusVal:SetTextColor(T("TEXT_FEATURES_DISABLED"))
        end)

        yOffset = yOffset - 22 - 10
    end

    dsc:SetHeight(math.abs(yOffset) + 20)
    GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local ITEMTRACKER_TOGGLES = {
    { key = "showAlts",        localeKey = "TIPS_ITEMTRACKER_SHOW_ALTS" },
    { key = "showBags",        localeKey = "TIPS_ITEMTRACKER_SHOW_BAGS" },
    { key = "showBank",        localeKey = "TIPS_ITEMTRACKER_SHOW_BANK" },
    { key = "showEquipped",    localeKey = "TIPS_ITEMTRACKER_SHOW_EQUIPPED" },
    { key = "showAuctions",    localeKey = "TIPS_ITEMTRACKER_SHOW_AUCTIONS" },
    { key = "showWarbandBank", localeKey = "TIPS_ITEMTRACKER_SHOW_WARBAND" },
    { key = "showGuildBanks",  localeKey = "TIPS_ITEMTRACKER_SHOW_GUILDS" },
    { key = "showVendors",     localeKey = "TIPS_ITEMTRACKER_SHOW_VENDORS" },
    { key = "showInstances",   localeKey = "TIPS_ITEMTRACKER_SHOW_INSTANCES" },
}

local function ShowItemTrackerDetail(split, dsc, feature, selectedRow)
    local yOffset = -10

    local titleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(T("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    local div = dsc:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    div:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    div:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local descLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(T("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local toggleBtnSets = {}

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
        local nowEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
        OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, not nowEnabled)
        nowEnabled = not nowEnabled
        if nowEnabled then
            statusValue:SetText(L["FEATURE_ENABLED"])
            statusValue:SetTextColor(T("TEXT_FEATURES_ENABLED"))
        else
            statusValue:SetText(L["FEATURE_DISABLED"])
            statusValue:SetTextColor(T("TEXT_FEATURES_DISABLED"))
        end
        self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
        if selectedRow and selectedRow.dot then
            if nowEnabled then
                selectedRow.dot:SetStatus(true)
            else
                selectedRow.dot:SetStatus(false)
            end
        end
        for _, tbs in ipairs(toggleBtnSets) do
            if nowEnabled then
                tbs.onBtn:EnableMouse(true)
                tbs.offBtn:EnableMouse(true)
                tbs.label:SetTextColor(T("TEXT_PRIMARY"))
                tbs.statusPrefix:SetTextColor(T("TEXT_PRIMARY"))
                local val = OneWoW.db.global.settings.tooltips.itemtracker[tbs.key]
                if val ~= false then
                    tbs.onBtn.isActive = true
                    tbs.offBtn.isActive = false
                    tbs.onBtn:SetBackdropColor(T("BG_ACTIVE"))
                    tbs.onBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                    tbs.onBtn.text:SetTextColor(T("TEXT_ACCENT"))
                    tbs.offBtn:SetBackdropColor(T("BTN_NORMAL"))
                    tbs.offBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                    tbs.offBtn.text:SetTextColor(T("TEXT_MUTED"))
                    tbs.statusVal:SetText(L["FEATURE_ENABLED"])
                    tbs.statusVal:SetTextColor(T("TEXT_FEATURES_ENABLED"))
                else
                    tbs.offBtn.isActive = true
                    tbs.onBtn.isActive = false
                    tbs.offBtn:SetBackdropColor(T("BG_ACTIVE"))
                    tbs.offBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                    tbs.offBtn.text:SetTextColor(T("TEXT_ACCENT"))
                    tbs.onBtn:SetBackdropColor(T("BTN_NORMAL"))
                    tbs.onBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                    tbs.onBtn.text:SetTextColor(T("TEXT_MUTED"))
                    tbs.statusVal:SetText(L["FEATURE_DISABLED"])
                    tbs.statusVal:SetTextColor(T("TEXT_FEATURES_DISABLED"))
                end
            else
                tbs.onBtn.isActive = false
                tbs.offBtn.isActive = false
                tbs.onBtn:EnableMouse(false)
                tbs.offBtn:EnableMouse(false)
                tbs.label:SetTextColor(T("TEXT_MUTED"))
                tbs.statusPrefix:SetTextColor(T("TEXT_MUTED"))
                tbs.statusVal:SetText(L["FEATURE_DISABLED"])
                tbs.statusVal:SetTextColor(T("TEXT_MUTED"))
                tbs.onBtn:SetBackdropColor(T("BG_SECONDARY"))
                tbs.onBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                tbs.onBtn.text:SetTextColor(T("TEXT_MUTED"))
                tbs.offBtn:SetBackdropColor(T("BG_SECONDARY"))
                tbs.offBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                tbs.offBtn.text:SetTextColor(T("TEXT_MUTED"))
            end
        end
    end)

    yOffset = yOffset - 30 - 14

    local toggleHeader = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toggleHeader:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    toggleHeader:SetText(L["TIPS_ITEMTRACKER_TRACK_SECTION"])
    toggleHeader:SetTextColor(T("ACCENT_SECONDARY"))
    yOffset = yOffset - toggleHeader:GetStringHeight() - 4

    local trackDesc = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    trackDesc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    trackDesc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    trackDesc:SetJustifyH("LEFT")
    trackDesc:SetWordWrap(true)
    trackDesc:SetSpacing(2)
    trackDesc:SetText(L["TIPS_ITEMTRACKER_TRACK_SECTION_DESC"])
    trackDesc:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - trackDesc:GetStringHeight() - 6

    local toggleDivider = dsc:CreateTexture(nil, "ARTWORK")
    toggleDivider:SetHeight(1)
    toggleDivider:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    toggleDivider:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    toggleDivider:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local itSettings = db and db.tooltips and db.tooltips.itemtracker or {}

    for _, toggle in ipairs(ITEMTRACKER_TOGGLES) do
        local capturedKey = toggle.key
        local currentVal = itSettings[capturedKey] ~= false

        local onBtn = OneWoW_GUI:CreateButton(nil, dsc, L["TIPS_TOGGLE_ON"], 50, 22)
        onBtn:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)

        local offBtn = OneWoW_GUI:CreateButton(nil, dsc, L["TIPS_TOGGLE_OFF"], 50, 22)
        offBtn:SetPoint("RIGHT", onBtn, "LEFT", -4, 0)

        local rowStatusVal = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rowStatusVal:SetPoint("RIGHT", offBtn, "LEFT", -6, 0)

        local rowStatusPfx = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rowStatusPfx:SetPoint("RIGHT", rowStatusVal, "LEFT", -2, 0)
        rowStatusPfx:SetText(L["FEATURE_STATUS_LABEL"])

        local toggleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        toggleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset - 3)
        toggleLabel:SetPoint("RIGHT", rowStatusPfx, "LEFT", -8, 0)
        toggleLabel:SetJustifyH("LEFT")
        toggleLabel:SetText(L[toggle.localeKey] or toggle.localeKey)

        if isEnabled then
            toggleLabel:SetTextColor(T("TEXT_PRIMARY"))
            rowStatusPfx:SetTextColor(T("TEXT_PRIMARY"))
            if currentVal then
                onBtn.isActive = true
                offBtn.isActive = false
                onBtn:SetBackdropColor(T("BG_ACTIVE"))
                onBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                onBtn.text:SetTextColor(T("TEXT_ACCENT"))
                offBtn:SetBackdropColor(T("BTN_NORMAL"))
                offBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                offBtn.text:SetTextColor(T("TEXT_MUTED"))
                rowStatusVal:SetText(L["FEATURE_ENABLED"])
                rowStatusVal:SetTextColor(T("TEXT_FEATURES_ENABLED"))
            else
                offBtn.isActive = true
                onBtn.isActive = false
                offBtn:SetBackdropColor(T("BG_ACTIVE"))
                offBtn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                offBtn.text:SetTextColor(T("TEXT_ACCENT"))
                onBtn:SetBackdropColor(T("BTN_NORMAL"))
                onBtn:SetBackdropBorderColor(T("BTN_BORDER"))
                onBtn.text:SetTextColor(T("TEXT_MUTED"))
                rowStatusVal:SetText(L["FEATURE_DISABLED"])
                rowStatusVal:SetTextColor(T("TEXT_FEATURES_DISABLED"))
            end
        else
            onBtn.isActive = false
            offBtn.isActive = false
            toggleLabel:SetTextColor(T("TEXT_MUTED"))
            rowStatusPfx:SetTextColor(T("TEXT_MUTED"))
            rowStatusVal:SetText(L["FEATURE_DISABLED"])
            rowStatusVal:SetTextColor(T("TEXT_MUTED"))
            onBtn:EnableMouse(false)
            offBtn:EnableMouse(false)
            onBtn:SetBackdropColor(T("BG_SECONDARY"))
            onBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            onBtn.text:SetTextColor(T("TEXT_MUTED"))
            offBtn:SetBackdropColor(T("BG_SECONDARY"))
            offBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            offBtn.text:SetTextColor(T("TEXT_MUTED"))
        end

        local function applyToggleHover(btn)
            if btn.isActive then
                btn:SetBackdropBorderColor(T("BORDER_FOCUS"))
            else
                btn:SetBackdropColor(T("BTN_HOVER"))
                btn:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
                btn.text:SetTextColor(T("TEXT_SECONDARY"))
            end
        end
        local function applyToggleNormal(btn)
            if btn.isActive then
                btn:SetBackdropColor(T("BG_ACTIVE"))
                btn:SetBackdropBorderColor(T("BORDER_ACCENT"))
                btn.text:SetTextColor(T("TEXT_ACCENT"))
            else
                btn:SetBackdropColor(T("BTN_NORMAL"))
                btn:SetBackdropBorderColor(T("BTN_BORDER"))
                btn.text:SetTextColor(T("TEXT_MUTED"))
            end
        end
        onBtn:HookScript("OnEnter",   function(self) applyToggleHover(self)  end)
        onBtn:HookScript("OnLeave",   function(self) applyToggleNormal(self) end)
        onBtn:HookScript("OnMouseUp", function(self) applyToggleNormal(self) end)
        offBtn:HookScript("OnEnter",   function(self) applyToggleHover(self)  end)
        offBtn:HookScript("OnLeave",   function(self) applyToggleNormal(self) end)
        offBtn:HookScript("OnMouseUp", function(self) applyToggleNormal(self) end)

        tinsert(toggleBtnSets, { onBtn = onBtn, offBtn = offBtn, label = toggleLabel, statusPrefix = rowStatusPfx, statusVal = rowStatusVal, key = capturedKey })

        onBtn:SetScript("OnClick", function(self)
            if not OneWoW.db.global.settings.tooltips.itemtracker then
                OneWoW.db.global.settings.tooltips.itemtracker = {}
            end
            OneWoW.db.global.settings.tooltips.itemtracker[capturedKey] = true
            onBtn.isActive = true
            offBtn.isActive = false
            self:SetBackdropColor(T("BG_ACTIVE"))
            self:SetBackdropBorderColor(T("BORDER_ACCENT"))
            self.text:SetTextColor(T("TEXT_ACCENT"))
            offBtn:SetBackdropColor(T("BTN_NORMAL"))
            offBtn:SetBackdropBorderColor(T("BTN_BORDER"))
            offBtn.text:SetTextColor(T("TEXT_MUTED"))
            rowStatusVal:SetText(L["FEATURE_ENABLED"])
            rowStatusVal:SetTextColor(T("TEXT_FEATURES_ENABLED"))
        end)
        offBtn:SetScript("OnClick", function(self)
            if not OneWoW.db.global.settings.tooltips.itemtracker then
                OneWoW.db.global.settings.tooltips.itemtracker = {}
            end
            OneWoW.db.global.settings.tooltips.itemtracker[capturedKey] = false
            offBtn.isActive = true
            onBtn.isActive = false
            self:SetBackdropColor(T("BG_ACTIVE"))
            self:SetBackdropBorderColor(T("BORDER_ACCENT"))
            self.text:SetTextColor(T("TEXT_ACCENT"))
            onBtn:SetBackdropColor(T("BTN_NORMAL"))
            onBtn:SetBackdropBorderColor(T("BTN_BORDER"))
            onBtn.text:SetTextColor(T("TEXT_MUTED"))
            rowStatusVal:SetText(L["FEATURE_DISABLED"])
            rowStatusVal:SetTextColor(T("TEXT_FEATURES_DISABLED"))
        end)

        yOffset = yOffset - 22 - 10
    end

    yOffset = yOffset - 6

    local reqDiv = dsc:CreateTexture(nil, "ARTWORK")
    reqDiv:SetHeight(1)
    reqDiv:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    reqDiv:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    reqDiv:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local reqHeader = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reqHeader:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    reqHeader:SetText(L["TIPS_ITEMTRACKER_REQUIRES_SECTION"])
    reqHeader:SetTextColor(T("ACCENT_SECONDARY"))
    yOffset = yOffset - reqHeader:GetStringHeight() - 8

    local vendorReqLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    vendorReqLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    vendorReqLabel:SetText(L["TIPS_ITEMTRACKER_VENDORS_REQUIRES"])
    vendorReqLabel:SetTextColor(T("TEXT_PRIMARY"))

    local vendorDetected = (_G.OneWoW_CatalogData_Vendors_API ~= nil)
    local vendorDetVal = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    vendorDetVal:SetPoint("LEFT", vendorReqLabel, "RIGHT", 8, 0)
    if vendorDetected then
        vendorDetVal:SetText(L["TIPS_ITEMTRACKER_VENDORS_DETECTED"])
        vendorDetVal:SetTextColor(T("TEXT_FEATURES_ENABLED"))
    else
        vendorDetVal:SetText(L["TIPS_ITEMTRACKER_VENDORS_NOT_DETECTED"])
        vendorDetVal:SetTextColor(T("TEXT_FEATURES_DISABLED"))
    end
    yOffset = yOffset - 24

    local instReqLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instReqLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    instReqLabel:SetText(L["TIPS_ITEMTRACKER_INSTANCES_REQUIRES"])
    instReqLabel:SetTextColor(T("TEXT_PRIMARY"))

    local instDetected = (_G.OneWoW_CatalogData_Journal ~= nil)
    local instDetVal = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instDetVal:SetPoint("LEFT", instReqLabel, "RIGHT", 8, 0)
    if instDetected then
        instDetVal:SetText(L["TIPS_ITEMTRACKER_INSTANCES_DETECTED"])
        instDetVal:SetTextColor(T("TEXT_FEATURES_ENABLED"))
    else
        instDetVal:SetText(L["TIPS_ITEMTRACKER_INSTANCES_NOT_DETECTED"])
        instDetVal:SetTextColor(T("TEXT_FEATURES_DISABLED"))
    end
    yOffset = yOffset - 24

    dsc:SetHeight(math.abs(yOffset) + 20)
    GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local function ShowPlayerMountsDetail(split, dsc, feature, selectedRow)
    local yOffset = -10

    local titleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(T("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    local div = dsc:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    div:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    div:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local descLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(T("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)

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
        local nowEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
        OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, not nowEnabled)
        nowEnabled = not nowEnabled
        if nowEnabled then
            statusValue:SetText(L["FEATURE_ENABLED"])
            statusValue:SetTextColor(T("TEXT_FEATURES_ENABLED"))
        else
            statusValue:SetText(L["FEATURE_DISABLED"])
            statusValue:SetTextColor(T("TEXT_FEATURES_DISABLED"))
        end
        self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
        if selectedRow and selectedRow.dot then
            if nowEnabled then
                selectedRow.dot:SetStatus(true)
            else
                selectedRow.dot:SetStatus(false)
            end
        end
    end)

    yOffset = yOffset - 30 - 14

    local reqDiv = dsc:CreateTexture(nil, "ARTWORK")
    reqDiv:SetHeight(1)
    reqDiv:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    reqDiv:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    reqDiv:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local reqLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reqLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    reqLabel:SetText(L["TIPS_PLAYERMOUNTS_REQUIRES"])
    reqLabel:SetTextColor(T("TEXT_PRIMARY"))

    local qolLoaded = (_G.OneWoW_QoL ~= nil)
    local detectedValue = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detectedValue:SetPoint("LEFT", reqLabel, "RIGHT", 8, 0)
    if qolLoaded then
        detectedValue:SetText(L["TIPS_PLAYERMOUNTS_DETECTED"])
        detectedValue:SetTextColor(T("TEXT_FEATURES_ENABLED"))
    else
        detectedValue:SetText(L["TIPS_PLAYERMOUNTS_NOT_DETECTED"])
        detectedValue:SetTextColor(T("TEXT_FEATURES_DISABLED"))
    end
    yOffset = yOffset - 24

    local noteLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noteLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    noteLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    noteLabel:SetJustifyH("LEFT")
    noteLabel:SetWordWrap(true)
    noteLabel:SetSpacing(2)
    noteLabel:SetText(L["TIPS_PLAYERMOUNTS_SETTINGS_NOTE"])
    noteLabel:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - noteLabel:GetStringHeight() - 10

    dsc:SetHeight(math.abs(yOffset) + 20)
    GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local function ShowFeatureDetail(split, feature, tabName, selectedRow)
    local dsc = split.detailScrollChild
    OneWoW_GUI:ClearFrame(dsc)

    if feature.id == "general" then
        ShowGeneralDetail(split, dsc, selectedRow)
        return
    end

    if feature.id == "customnotes" then
        ShowCustomNotesDetail(split, dsc, feature, selectedRow)
        return
    end

    if feature.id == "technicalids" then
        ShowTechnicalIDsDetail(split, dsc, feature, selectedRow)
        return
    end

    if feature.id == "itemtracker" then
        ShowItemTrackerDetail(split, dsc, feature, selectedRow)
        return
    end

    if feature.id == "playermounts" then
        ShowPlayerMountsDetail(split, dsc, feature, selectedRow)
        return
    end

    local yOffset = -10

    local titleLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(T("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    local divider = dsc:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    divider:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    divider:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local descLabel = dsc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
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
        if nowEnabled then
            statusValue:SetText(L["FEATURE_ENABLED"])
            statusValue:SetTextColor(T("TEXT_FEATURES_ENABLED"))
        else
            statusValue:SetText(L["FEATURE_DISABLED"])
            statusValue:SetTextColor(T("TEXT_FEATURES_DISABLED"))
        end
        self.text:SetText(nowEnabled and L["FEATURE_DISABLE_BTN"] or L["FEATURE_ENABLE_BTN"])
        if selectedRow and selectedRow.dot then
            if nowEnabled then
                selectedRow.dot:SetStatus(true)
            else
                selectedRow.dot:SetStatus(false)
            end
        end
    end)

    yOffset = yOffset - 30 - 14

    dsc:SetHeight(math.abs(yOffset) + 20)
    GUI:ApplyFontToFrame(dsc)
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

function GUI:CreateTooltipsTab(parent)
    local split = OneWoW_GUI:CreateSplitPanel(parent, { showSearch = true, searchPlaceholder = L["SEARCH_PLACEHOLDER"] or "Search..." })
    split.listTitle:SetText(L["TOOLTIPS_LIST_TITLE"])
    split.detailTitle:SetText(L["TOOLTIPS_DETAIL_TITLE"])

    C_Timer.After(0.1, function()
        BuildFeatureList(split, "tooltips")
        GUI:ApplyFontToFrame(parent)
    end)
end
