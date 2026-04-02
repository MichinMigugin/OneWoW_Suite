local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI
local L    = OneWoW.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local activePlayermountsRow = nil

function GUI:RefreshTooltipsFeatureDot(featureId, value)
    if featureId == "playermounts" and activePlayermountsRow and activePlayermountsRow.dot then
        activePlayermountsRow.dot:SetStatus(value)
    end
end

local function ShowGeneralDetail(split, dsc, selectedRow)
    local yOffset = -10

    local titleLabel = OneWoW_GUI:CreateFS(dsc, 16)
    titleLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L["TIPS_GENERAL_TITLE"])
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
    descLabel:SetText(L["TIPS_GENERAL_DESC"])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local statusBlock = OneWoW_GUI:CreateFeatureStatusBlock(dsc, {
        yOffset = yOffset,
        statusLabel = L["FEATURE_STATUS_LABEL"],
        enabledText = L["FEATURE_ENABLED"],
        disabledText = L["FEATURE_DISABLED"],
        enableBtnText = L["FEATURE_ENABLE_BTN"],
        disableBtnText = L["FEATURE_DISABLE_BTN"],
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", "general") end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", "general", newState)
            if selectedRow and selectedRow.dot then
                selectedRow.dot:SetStatus(newState)
            end
        end,
    })

    yOffset = statusBlock.getBottomY() - 20

    local noteLabel = OneWoW_GUI:CreateFS(dsc, 12)
    noteLabel:SetPoint("TOPLEFT",  dsc, "TOPLEFT",  12, yOffset)
    noteLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    noteLabel:SetJustifyH("LEFT")
    noteLabel:SetWordWrap(true)
    noteLabel:SetSpacing(3)
    noteLabel:SetText(L["TIPS_GENERAL_NOTE"])
    noteLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - noteLabel:GetStringHeight() - 10

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
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

local function CreateSettingToggleRows(dsc, toggleList, toggleBtnSets, isEnabled, settingsTable, dbPath, yOffset)
    for _, toggle in ipairs(toggleList) do
        local capturedKey = toggle.key
        local currentVal = settingsTable[capturedKey] ~= false

        local onBtn, offBtn, refresh, statusPfx, statusVal = OneWoW_GUI:CreateOnOffToggleButtons(dsc, {
            yOffset = yOffset,
            onLabel = L["TIPS_TOGGLE_ON"],
            offLabel = L["TIPS_TOGGLE_OFF"],
            width = 50,
            height = 22,
            isEnabled = isEnabled,
            value = currentVal,
            onValueChange = function(newVal)
                if not OneWoW.db.global.settings.tooltips[dbPath] then
                    OneWoW.db.global.settings.tooltips[dbPath] = {}
                end
                OneWoW.db.global.settings.tooltips[dbPath][capturedKey] = newVal
            end,
        })

        offBtn:ClearAllPoints()
        offBtn:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
        onBtn:ClearAllPoints()
        onBtn:SetPoint("RIGHT", offBtn, "LEFT", -4, 0)
        statusVal:ClearAllPoints()
        statusVal:SetPoint("RIGHT", onBtn, "LEFT", -6, 0)
        statusPfx:ClearAllPoints()
        statusPfx:SetPoint("RIGHT", statusVal, "LEFT", -2, 0)

        local toggleLabel = OneWoW_GUI:CreateFS(dsc, 12)
        toggleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset - 3)
        toggleLabel:SetPoint("RIGHT", statusPfx, "LEFT", -8, 0)
        toggleLabel:SetJustifyH("LEFT")
        toggleLabel:SetText(L[toggle.localeKey] or toggle.localeKey)

        if isEnabled then
            toggleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            toggleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end

        tinsert(toggleBtnSets, { onBtn = onBtn, offBtn = offBtn, label = toggleLabel, statusPrefix = statusPfx, statusVal = statusVal, key = capturedKey, refresh = refresh })

        yOffset = yOffset - 22 - 10
    end

    return yOffset
end

local function ShowCustomNotesDetail(split, dsc, feature, selectedRow)
    local yOffset = -10

    local titleLabel = OneWoW_GUI:CreateFS(dsc, 16)
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local toggleBtnSets = {}

    local statusBlock = OneWoW_GUI:CreateFeatureStatusBlock(dsc, {
        yOffset = yOffset,
        statusLabel = L["FEATURE_STATUS_LABEL"],
        enabledText = L["FEATURE_ENABLED"],
        disabledText = L["FEATURE_DISABLED"],
        enableBtnText = L["FEATURE_ENABLE_BTN"],
        disableBtnText = L["FEATURE_DISABLE_BTN"],
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            if selectedRow and selectedRow.dot then
                selectedRow.dot:SetStatus(newState)
            end
            for _, tbs in ipairs(toggleBtnSets) do
                local val = OneWoW.db.global.settings.tooltips.customnotes[tbs.key]
                tbs.refresh(newState, val ~= false)
                tbs.label:SetTextColor(newState and OneWoW_GUI:GetThemeColor("TEXT_PRIMARY") or OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        end,
    })

    yOffset = statusBlock.getBottomY() - 14

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local reqLabel = OneWoW_GUI:CreateFS(dsc, 12)
    reqLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    reqLabel:SetText(L["TIPS_CUSTOMNOTES_REQUIRES"])
    reqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local notesLoaded = (_G.OneWoW_Notes ~= nil)
    local detectedValue = OneWoW_GUI:CreateFS(dsc, 12)
    detectedValue:SetPoint("LEFT", reqLabel, "RIGHT", 8, 0)
    if notesLoaded then
        detectedValue:SetText(L["TIPS_CUSTOMNOTES_DETECTED"])
        detectedValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        detectedValue:SetText(L["TIPS_CUSTOMNOTES_NOT_DETECTED"])
        detectedValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
    end

    yOffset = yOffset - 24

    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local cnSettings = db and db.tooltips and db.tooltips.customnotes or {}

    local linesHeader = OneWoW_GUI:CreateFS(dsc, 12)
    linesHeader:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    linesHeader:SetText(L["TIPS_CUSTOMNOTES_SECTION_LINES"])
    linesHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - linesHeader:GetStringHeight() - 4

    local linesDesc = OneWoW_GUI:CreateFS(dsc, 10)
    linesDesc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    linesDesc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    linesDesc:SetJustifyH("LEFT")
    linesDesc:SetWordWrap(true)
    linesDesc:SetSpacing(2)
    linesDesc:SetText(L["TIPS_CUSTOMNOTES_SECTION_LINES_DESC"])
    linesDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - linesDesc:GetStringHeight() - 6

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 10

    yOffset = CreateSettingToggleRows(dsc, CUSTOMNOTES_LINE_TOGGLES, toggleBtnSets, isEnabled, cnSettings, "customnotes", yOffset)

    yOffset = yOffset - 6

    local warnHeader = OneWoW_GUI:CreateFS(dsc, 12)
    warnHeader:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    warnHeader:SetText(L["TIPS_CUSTOMNOTES_SECTION_WARNING"])
    warnHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - warnHeader:GetStringHeight() - 4

    local warnDesc = OneWoW_GUI:CreateFS(dsc, 10)
    warnDesc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    warnDesc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    warnDesc:SetJustifyH("LEFT")
    warnDesc:SetWordWrap(true)
    warnDesc:SetSpacing(2)
    warnDesc:SetText(L["TIPS_CUSTOMNOTES_SECTION_WARNING_DESC"])
    warnDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - warnDesc:GetStringHeight() - 6

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 10

    yOffset = CreateSettingToggleRows(dsc, CUSTOMNOTES_WARNING_TOGGLES, toggleBtnSets, isEnabled, cnSettings, "customnotes", yOffset)

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
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

    local titleLabel = OneWoW_GUI:CreateFS(dsc, 16)
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local toggleBtnSets = {}

    local statusBlock = OneWoW_GUI:CreateFeatureStatusBlock(dsc, {
        yOffset = yOffset,
        statusLabel = L["FEATURE_STATUS_LABEL"],
        enabledText = L["FEATURE_ENABLED"],
        disabledText = L["FEATURE_DISABLED"],
        enableBtnText = L["FEATURE_ENABLE_BTN"],
        disableBtnText = L["FEATURE_DISABLE_BTN"],
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            if selectedRow and selectedRow.dot then
                selectedRow.dot:SetStatus(newState)
            end
            for _, tbs in ipairs(toggleBtnSets) do
                local val = OneWoW.db.global.settings.tooltips.technicalids[tbs.key]
                tbs.refresh(newState, val ~= false)
                tbs.label:SetTextColor(newState and OneWoW_GUI:GetThemeColor("TEXT_PRIMARY") or OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        end,
    })

    yOffset = statusBlock.getBottomY() - 14

    local toggleHeader = OneWoW_GUI:CreateFS(dsc, 12)
    toggleHeader:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    toggleHeader:SetText(L["TIPS_MODULE_TOGGLES"])
    toggleHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - toggleHeader:GetStringHeight() - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 10

    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local tidSettings = db and db.tooltips and db.tooltips.technicalids or {}

    yOffset = CreateSettingToggleRows(dsc, TECHID_TOGGLES, toggleBtnSets, isEnabled, tidSettings, "technicalids", yOffset)

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
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

    local titleLabel = OneWoW_GUI:CreateFS(dsc, 16)
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local toggleBtnSets = {}

    local statusBlock = OneWoW_GUI:CreateFeatureStatusBlock(dsc, {
        yOffset = yOffset,
        statusLabel = L["FEATURE_STATUS_LABEL"],
        enabledText = L["FEATURE_ENABLED"],
        disabledText = L["FEATURE_DISABLED"],
        enableBtnText = L["FEATURE_ENABLE_BTN"],
        disableBtnText = L["FEATURE_DISABLE_BTN"],
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            if selectedRow and selectedRow.dot then
                selectedRow.dot:SetStatus(newState)
            end
            for _, tbs in ipairs(toggleBtnSets) do
                local val = OneWoW.db.global.settings.tooltips.itemtracker[tbs.key]
                tbs.refresh(newState, val ~= false)
                tbs.label:SetTextColor(newState and OneWoW_GUI:GetThemeColor("TEXT_PRIMARY") or OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        end,
    })

    yOffset = statusBlock.getBottomY() - 14

    local toggleHeader = OneWoW_GUI:CreateFS(dsc, 12)
    toggleHeader:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    toggleHeader:SetText(L["TIPS_ITEMTRACKER_TRACK_SECTION"])
    toggleHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - toggleHeader:GetStringHeight() - 4

    local trackDesc = OneWoW_GUI:CreateFS(dsc, 10)
    trackDesc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    trackDesc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    trackDesc:SetJustifyH("LEFT")
    trackDesc:SetWordWrap(true)
    trackDesc:SetSpacing(2)
    trackDesc:SetText(L["TIPS_ITEMTRACKER_TRACK_SECTION_DESC"])
    trackDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - trackDesc:GetStringHeight() - 6

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 10

    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local itSettings = db and db.tooltips and db.tooltips.itemtracker or {}

    yOffset = CreateSettingToggleRows(dsc, ITEMTRACKER_TOGGLES, toggleBtnSets, isEnabled, itSettings, "itemtracker", yOffset)

    yOffset = yOffset - 6

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local reqHeader = OneWoW_GUI:CreateFS(dsc, 12)
    reqHeader:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    reqHeader:SetText(L["TIPS_ITEMTRACKER_REQUIRES_SECTION"])
    reqHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - reqHeader:GetStringHeight() - 8

    local vendorReqLabel = OneWoW_GUI:CreateFS(dsc, 12)
    vendorReqLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    vendorReqLabel:SetText(L["TIPS_ITEMTRACKER_VENDORS_REQUIRES"])
    vendorReqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local vendorDetected = (_G.OneWoW_CatalogData_Vendors_API ~= nil)
    local vendorDetVal = OneWoW_GUI:CreateFS(dsc, 12)
    vendorDetVal:SetPoint("LEFT", vendorReqLabel, "RIGHT", 8, 0)
    if vendorDetected then
        vendorDetVal:SetText(L["TIPS_ITEMTRACKER_VENDORS_DETECTED"])
        vendorDetVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        vendorDetVal:SetText(L["TIPS_ITEMTRACKER_VENDORS_NOT_DETECTED"])
        vendorDetVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
    end
    yOffset = yOffset - 24

    local instReqLabel = OneWoW_GUI:CreateFS(dsc, 12)
    instReqLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    instReqLabel:SetText(L["TIPS_ITEMTRACKER_INSTANCES_REQUIRES"])
    instReqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local instDetected = (_G.OneWoW_CatalogData_Journal ~= nil)
    local instDetVal = OneWoW_GUI:CreateFS(dsc, 12)
    instDetVal:SetPoint("LEFT", instReqLabel, "RIGHT", 8, 0)
    if instDetected then
        instDetVal:SetText(L["TIPS_ITEMTRACKER_INSTANCES_DETECTED"])
        instDetVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        instDetVal:SetText(L["TIPS_ITEMTRACKER_INSTANCES_NOT_DETECTED"])
        instDetVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
    end
    yOffset = yOffset - 24

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local function ShowPlayerMountsDetail(split, dsc, feature, selectedRow)
    local yOffset = -10

    local titleLabel = OneWoW_GUI:CreateFS(dsc, 16)
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local statusBlock = OneWoW_GUI:CreateFeatureStatusBlock(dsc, {
        yOffset = yOffset,
        statusLabel = L["FEATURE_STATUS_LABEL"],
        enabledText = L["FEATURE_ENABLED"],
        disabledText = L["FEATURE_DISABLED"],
        enableBtnText = L["FEATURE_ENABLE_BTN"],
        disableBtnText = L["FEATURE_DISABLE_BTN"],
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            if feature.id == "playermounts" and _G.OneWoW_QoL and _G.OneWoW_QoL.ModuleRegistry then
                _G.OneWoW_QoL.ModuleRegistry:SetEnabled("playmounts", newState)
                if _G.OneWoW_QoL.UI and _G.OneWoW_QoL.UI.RefreshModuleDot then
                    _G.OneWoW_QoL.UI.RefreshModuleDot("playmounts", newState)
                end
            end
            if selectedRow and selectedRow.dot then
                selectedRow.dot:SetStatus(newState)
            end
        end,
    })

    yOffset = statusBlock.getBottomY() - 14

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local reqLabel = OneWoW_GUI:CreateFS(dsc, 12)
    reqLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    reqLabel:SetText(L["TIPS_PLAYERMOUNTS_REQUIRES"])
    reqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local qolLoaded = (_G.OneWoW_QoL ~= nil)
    local detectedValue = OneWoW_GUI:CreateFS(dsc, 12)
    detectedValue:SetPoint("LEFT", reqLabel, "RIGHT", 8, 0)
    if qolLoaded then
        detectedValue:SetText(L["TIPS_PLAYERMOUNTS_DETECTED"])
        detectedValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        detectedValue:SetText(L["TIPS_PLAYERMOUNTS_NOT_DETECTED"])
        detectedValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
    end
    yOffset = yOffset - 24

    local noteLabel = OneWoW_GUI:CreateFS(dsc, 10)
    noteLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    noteLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    noteLabel:SetJustifyH("LEFT")
    noteLabel:SetWordWrap(true)
    noteLabel:SetSpacing(2)
    noteLabel:SetText(L["TIPS_PLAYERMOUNTS_SETTINGS_NOTE"])
    noteLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - noteLabel:GetStringHeight() - 10

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local function ShowTalentModsDetail(split, dsc, feature, selectedRow)
    local yOffset = -10

    local titleLabel = OneWoW_GUI:CreateFS(dsc, 16)
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local allRefreshFuncs = {}

    local statusBlock = OneWoW_GUI:CreateFeatureStatusBlock(dsc, {
        yOffset = yOffset,
        statusLabel = L["FEATURE_STATUS_LABEL"],
        enabledText = L["FEATURE_ENABLED"],
        disabledText = L["FEATURE_DISABLED"],
        enableBtnText = L["FEATURE_ENABLE_BTN"],
        disableBtnText = L["FEATURE_DISABLE_BTN"],
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            if selectedRow and selectedRow.dot then
                selectedRow.dot:SetStatus(newState)
            end
            for _, refreshFn in ipairs(allRefreshFuncs) do
                refreshFn(newState)
            end
        end,
    })

    yOffset = statusBlock.getBottomY() - 14

    local tmSettings = OneWoW.db.global.settings.tooltips.talentmods

    local section1 = OneWoW_GUI:CreateSectionHeader(dsc, {
        title = L["TIPS_TALENTMODS_SECTION_SETTINGS"],
        yOffset = yOffset,
    })
    yOffset = section1.bottomY - 6

    local sec1Desc = OneWoW_GUI:CreateFS(dsc, 10)
    sec1Desc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    sec1Desc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    sec1Desc:SetJustifyH("LEFT")
    sec1Desc:SetWordWrap(true)
    sec1Desc:SetSpacing(2)
    sec1Desc:SetText(L["TIPS_TALENTMODS_SECTION_SETTINGS_DESC"])
    sec1Desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - sec1Desc:GetStringHeight() - 10

    local newY1, refresh1 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_TALENTMODS_INCLUDE_ACTIVE"],
        description = L["TIPS_TALENTMODS_INCLUDE_ACTIVE_DESC"],
        value = tmSettings.includeActive == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            tmSettings.includeActive = newVal
        end,
    })
    yOffset = newY1
    table.insert(allRefreshFuncs, function(enabled) refresh1(enabled, tmSettings.includeActive == true) end)

    local newY2, refresh2 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_TALENTMODS_HIDE_COMBAT"],
        description = L["TIPS_TALENTMODS_HIDE_COMBAT_DESC"],
        value = tmSettings.hideInCombat == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            tmSettings.hideInCombat = newVal
        end,
    })
    yOffset = newY2
    table.insert(allRefreshFuncs, function(enabled) refresh2(enabled, tmSettings.hideInCombat == true) end)

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local function ShowEnhancementsDetail(split, dsc, feature, selectedRow)
    local yOffset = -10

    local titleLabel = OneWoW_GUI:CreateFS(dsc, 16)
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local allRefreshFuncs = {}

    local statusBlock = OneWoW_GUI:CreateFeatureStatusBlock(dsc, {
        yOffset = yOffset,
        statusLabel = L["FEATURE_STATUS_LABEL"],
        enabledText = L["FEATURE_ENABLED"],
        disabledText = L["FEATURE_DISABLED"],
        enableBtnText = L["FEATURE_ENABLE_BTN"],
        disableBtnText = L["FEATURE_DISABLE_BTN"],
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            if selectedRow and selectedRow.dot then
                selectedRow.dot:SetStatus(newState)
            end
            for _, refreshFn in ipairs(allRefreshFuncs) do
                refreshFn(newState)
            end
        end,
    })

    yOffset = statusBlock.getBottomY() - 14

    local enhSettings = OneWoW.db.global.settings.tooltips.enhancements

    local section1 = OneWoW_GUI:CreateSectionHeader(dsc, {
        title = L["TIPS_ENHANCEMENTS_SECTION_APPEARANCE"],
        yOffset = yOffset,
    })
    yOffset = section1.bottomY - 6

    local sec1Desc = OneWoW_GUI:CreateFS(dsc, 10)
    sec1Desc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    sec1Desc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    sec1Desc:SetJustifyH("LEFT")
    sec1Desc:SetWordWrap(true)
    sec1Desc:SetSpacing(2)
    sec1Desc:SetText(L["TIPS_ENHANCEMENTS_SECTION_APPEARANCE_DESC"])
    sec1Desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - sec1Desc:GetStringHeight() - 10

    local newY1, refresh1 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_HIDE_HEALTHBAR"],
        description = L["TIPS_ENHANCEMENTS_HIDE_HEALTHBAR_DESC"],
        value = enhSettings.hideHealthbar == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.hideHealthbar = newVal
        end,
    })
    yOffset = newY1
    table.insert(allRefreshFuncs, function(enabled) refresh1(enabled, enhSettings.hideHealthbar == true) end)

    local newY2, refresh2 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_HIDE_COMBAT"],
        description = L["TIPS_ENHANCEMENTS_HIDE_COMBAT_DESC"],
        value = enhSettings.hideInCombat == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.hideInCombat = newVal
        end,
    })
    yOffset = newY2
    table.insert(allRefreshFuncs, function(enabled) refresh2(enabled, enhSettings.hideInCombat == true) end)

    local newY3, refresh3 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_SCALE"],
        createContent = function(container)
            local currentScale = enhSettings.tooltipScale or 100
            local slider = OneWoW_GUI:CreateSlider(container, {
                minVal = 50,
                maxVal = 250,
                step = 5,
                currentVal = currentScale,
                width = 280,
                fmt = "%d%%",
                onChange = function(val)
                    enhSettings.tooltipScale = val
                end,
            })
            slider:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            return slider, 36
        end,
        value = enhSettings.scaleEnabled == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.scaleEnabled = newVal
        end,
    })
    yOffset = newY3
    table.insert(allRefreshFuncs, function(enabled) refresh3(enabled, enhSettings.scaleEnabled == true) end)

    local newY4, refresh4 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_ANCHOR"],
        createContent = function(container)
            local currentAnchor = enhSettings.anchorPosition or "ANCHOR_CURSOR_RIGHT"
            local displayText = L["TIPS_ENHANCEMENTS_ANCHOR_RIGHT"]
            if currentAnchor == "ANCHOR_CURSOR_LEFT" then displayText = L["TIPS_ENHANCEMENTS_ANCHOR_LEFT"]
            elseif currentAnchor == "ANCHOR_CURSOR" then displayText = L["TIPS_ENHANCEMENTS_ANCHOR_CENTER"] end

            local dropdown, dropdownText = OneWoW_GUI:CreateDropdown(container, {
                width = 160,
                height = 26,
                text = displayText,
            })
            dropdown:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)

            OneWoW_GUI:AttachFilterMenu(dropdown, {
                searchable = false,
                buildItems = function()
                    return {
                        { value = "ANCHOR_CURSOR_LEFT", text = L["TIPS_ENHANCEMENTS_ANCHOR_LEFT"] },
                        { value = "ANCHOR_CURSOR", text = L["TIPS_ENHANCEMENTS_ANCHOR_CENTER"] },
                        { value = "ANCHOR_CURSOR_RIGHT", text = L["TIPS_ENHANCEMENTS_ANCHOR_RIGHT"] },
                    }
                end,
                onSelect = function(value, text)
                    enhSettings.anchorPosition = value
                    dropdownText:SetText(text)
                end,
                getActiveValue = function() return enhSettings.anchorPosition or "ANCHOR_CURSOR_RIGHT" end,
            })
            return dropdown, 26
        end,
        value = enhSettings.anchorEnabled == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.anchorEnabled = newVal
        end,
    })
    yOffset = newY4
    table.insert(allRefreshFuncs, function(enabled) refresh4(enabled, enhSettings.anchorEnabled == true) end)

    local section2 = OneWoW_GUI:CreateSectionHeader(dsc, {
        title = L["TIPS_ENHANCEMENTS_SECTION_PLAYERINFO"],
        yOffset = yOffset,
    })
    yOffset = section2.bottomY - 6

    local sec2Desc = OneWoW_GUI:CreateFS(dsc, 10)
    sec2Desc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    sec2Desc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    sec2Desc:SetJustifyH("LEFT")
    sec2Desc:SetWordWrap(true)
    sec2Desc:SetSpacing(2)
    sec2Desc:SetText(L["TIPS_ENHANCEMENTS_SECTION_PLAYERINFO_DESC"])
    sec2Desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - sec2Desc:GetStringHeight() - 10

    local newY5, refresh5 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_CLASS_COLORS"],
        description = L["TIPS_ENHANCEMENTS_CLASS_COLORS_DESC"],
        value = enhSettings.classColorNames == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.classColorNames = newVal
        end,
    })
    yOffset = newY5
    table.insert(allRefreshFuncs, function(enabled) refresh5(enabled, enhSettings.classColorNames == true) end)

    local newY6, refresh6 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_GUILD_RANK"],
        description = L["TIPS_ENHANCEMENTS_GUILD_RANK_DESC"],
        value = enhSettings.guildRank == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.guildRank = newVal
        end,
    })
    yOffset = newY6
    table.insert(allRefreshFuncs, function(enabled) refresh6(enabled, enhSettings.guildRank == true) end)

    local newY7, refresh7 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_PLAYER_TARGET"],
        description = L["TIPS_ENHANCEMENTS_PLAYER_TARGET_DESC"],
        value = enhSettings.playerTarget == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.playerTarget = newVal
        end,
    })
    yOffset = newY7
    table.insert(allRefreshFuncs, function(enabled) refresh7(enabled, enhSettings.playerTarget == true) end)

    local newY8, refresh8 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_MYTHIC_SCORE"],
        description = L["TIPS_ENHANCEMENTS_MYTHIC_SCORE_DESC"],
        value = enhSettings.mythicScore == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.mythicScore = newVal
        end,
    })
    yOffset = newY8
    table.insert(allRefreshFuncs, function(enabled) refresh8(enabled, enhSettings.mythicScore == true) end)

    local newY9, refresh9 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_HIDE_SERVER"],
        description = L["TIPS_ENHANCEMENTS_HIDE_SERVER_DESC"],
        value = enhSettings.hideServerName == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.hideServerName = newVal
        end,
    })
    yOffset = newY9
    table.insert(allRefreshFuncs, function(enabled) refresh9(enabled, enhSettings.hideServerName == true) end)

    local newY10, refresh10 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_HIDE_TITLES"],
        description = L["TIPS_ENHANCEMENTS_HIDE_TITLES_DESC"],
        value = enhSettings.hideTitles == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.hideTitles = newVal
        end,
    })
    yOffset = newY10
    table.insert(allRefreshFuncs, function(enabled) refresh10(enabled, enhSettings.hideTitles == true) end)

    local newY11, refresh11 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_REMOVE_PVP_TAG"],
        description = L["TIPS_ENHANCEMENTS_REMOVE_PVP_TAG_DESC"],
        value = enhSettings.removePvpTag == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.removePvpTag = newVal
        end,
    })
    yOffset = newY11
    table.insert(allRefreshFuncs, function(enabled) refresh11(enabled, enhSettings.removePvpTag == true) end)

    local section3 = OneWoW_GUI:CreateSectionHeader(dsc, {
        title = L["TIPS_ENHANCEMENTS_SECTION_OPACITY"],
        yOffset = yOffset,
    })
    yOffset = section3.bottomY - 6

    local sec3Desc = OneWoW_GUI:CreateFS(dsc, 10)
    sec3Desc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    sec3Desc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    sec3Desc:SetJustifyH("LEFT")
    sec3Desc:SetWordWrap(true)
    sec3Desc:SetSpacing(2)
    sec3Desc:SetText(L["TIPS_ENHANCEMENTS_SECTION_OPACITY_DESC"])
    sec3Desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - sec3Desc:GetStringHeight() - 10

    local newY12, refresh12 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_BORDER_OPACITY"],
        createContent = function(container)
            local currentVal = enhSettings.borderOpacity or 100
            local slider = OneWoW_GUI:CreateSlider(container, {
                minVal = 0,
                maxVal = 100,
                step = 5,
                currentVal = currentVal,
                width = 280,
                fmt = "%d%%",
                onChange = function(val)
                    enhSettings.borderOpacity = val
                end,
            })
            slider:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            return slider, 36
        end,
        value = enhSettings.borderOpacityEnabled == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.borderOpacityEnabled = newVal
        end,
    })
    yOffset = newY12
    table.insert(allRefreshFuncs, function(enabled) refresh12(enabled, enhSettings.borderOpacityEnabled == true) end)

    local newY13, refresh13 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_BG_OPACITY"],
        createContent = function(container)
            local currentVal = enhSettings.bgOpacity or 100
            local slider = OneWoW_GUI:CreateSlider(container, {
                minVal = 0,
                maxVal = 100,
                step = 5,
                currentVal = currentVal,
                width = 280,
                fmt = "%d%%",
                onChange = function(val)
                    enhSettings.bgOpacity = val
                end,
            })
            slider:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            return slider, 36
        end,
        value = enhSettings.bgOpacityEnabled == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.bgOpacityEnabled = newVal
        end,
    })
    yOffset = newY13
    table.insert(allRefreshFuncs, function(enabled) refresh13(enabled, enhSettings.bgOpacityEnabled == true) end)

    local section4 = OneWoW_GUI:CreateSectionHeader(dsc, {
        title = L["TIPS_ENHANCEMENTS_SECTION_UNITCOLORS"],
        yOffset = yOffset,
    })
    yOffset = section4.bottomY - 6

    local sec4Desc = OneWoW_GUI:CreateFS(dsc, 10)
    sec4Desc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    sec4Desc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    sec4Desc:SetJustifyH("LEFT")
    sec4Desc:SetWordWrap(true)
    sec4Desc:SetSpacing(2)
    sec4Desc:SetText(L["TIPS_ENHANCEMENTS_SECTION_UNITCOLORS_DESC"])
    sec4Desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - sec4Desc:GetStringHeight() - 10

    local function ensureColor(colorKey, defaultR, defaultG, defaultB)
        if not enhSettings[colorKey] then
            enhSettings[colorKey] = { r = defaultR, g = defaultG, b = defaultB }
        end
    end

    ensureColor("partyColor", 0.5, 0.2, 0.65)
    ensureColor("guildColor", 0.2, 0.6, 0.6)
    ensureColor("factionFriendlyColor", 0.15, 0.15, 0.5)
    ensureColor("factionEnemyColor", 0.5, 0.15, 0.12)

    local newY14, refresh14 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_COLOR_PARTY"],
        createContent = function(container)
            local descFs = OneWoW_GUI:CreateFS(container, 10)
            descFs:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            descFs:SetPoint("RIGHT", container, "RIGHT", -34, 0)
            descFs:SetJustifyH("LEFT")
            descFs:SetWordWrap(true)
            descFs:SetText(L["TIPS_ENHANCEMENTS_COLOR_PARTY_DESC"])
            descFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            local swatch = OneWoW_GUI:CreateColorSwatch(container, {
                getColor = function() return enhSettings.partyColor.r, enhSettings.partyColor.g, enhSettings.partyColor.b end,
                onColorChanged = function(r, g, b) enhSettings.partyColor.r, enhSettings.partyColor.g, enhSettings.partyColor.b = r, g, b end,
            })
            swatch:SetPoint("RIGHT", container, "RIGHT", 0, 0)
            local h = math.max(descFs:GetStringHeight(), 24)
            return descFs, h
        end,
        value = enhSettings.colorParty == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.colorParty = newVal
        end,
    })
    yOffset = newY14
    table.insert(allRefreshFuncs, function(enabled) refresh14(enabled, enhSettings.colorParty == true) end)

    local newY15, refresh15 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_COLOR_GUILD"],
        createContent = function(container)
            local descFs = OneWoW_GUI:CreateFS(container, 10)
            descFs:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            descFs:SetPoint("RIGHT", container, "RIGHT", -34, 0)
            descFs:SetJustifyH("LEFT")
            descFs:SetWordWrap(true)
            descFs:SetText(L["TIPS_ENHANCEMENTS_COLOR_GUILD_DESC"])
            descFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            local swatch = OneWoW_GUI:CreateColorSwatch(container, {
                getColor = function() return enhSettings.guildColor.r, enhSettings.guildColor.g, enhSettings.guildColor.b end,
                onColorChanged = function(r, g, b) enhSettings.guildColor.r, enhSettings.guildColor.g, enhSettings.guildColor.b = r, g, b end,
            })
            swatch:SetPoint("RIGHT", container, "RIGHT", 0, 0)
            local h = math.max(descFs:GetStringHeight(), 24)
            return descFs, h
        end,
        value = enhSettings.colorGuild == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.colorGuild = newVal
        end,
    })
    yOffset = newY15
    table.insert(allRefreshFuncs, function(enabled) refresh15(enabled, enhSettings.colorGuild == true) end)

    local newY16, refresh16 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_COLOR_FACTION"],
        createContent = function(container)
            local descFs = OneWoW_GUI:CreateFS(container, 10)
            descFs:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            descFs:SetPoint("RIGHT", container, "RIGHT", -60, 0)
            descFs:SetJustifyH("LEFT")
            descFs:SetWordWrap(true)
            descFs:SetText(L["TIPS_ENHANCEMENTS_COLOR_FACTION_DESC"])
            descFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            local friendSwatch = OneWoW_GUI:CreateColorSwatch(container, {
                getColor = function() return enhSettings.factionFriendlyColor.r, enhSettings.factionFriendlyColor.g, enhSettings.factionFriendlyColor.b end,
                onColorChanged = function(r, g, b) enhSettings.factionFriendlyColor.r, enhSettings.factionFriendlyColor.g, enhSettings.factionFriendlyColor.b = r, g, b end,
            })
            friendSwatch:SetPoint("RIGHT", container, "RIGHT", -30, 0)
            local enemySwatch = OneWoW_GUI:CreateColorSwatch(container, {
                getColor = function() return enhSettings.factionEnemyColor.r, enhSettings.factionEnemyColor.g, enhSettings.factionEnemyColor.b end,
                onColorChanged = function(r, g, b) enhSettings.factionEnemyColor.r, enhSettings.factionEnemyColor.g, enhSettings.factionEnemyColor.b = r, g, b end,
            })
            enemySwatch:SetPoint("RIGHT", container, "RIGHT", 0, 0)
            local h = math.max(descFs:GetStringHeight(), 24)
            return descFs, h
        end,
        value = enhSettings.colorFaction == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            enhSettings.colorFaction = newVal
        end,
    })
    yOffset = newY16
    table.insert(allRefreshFuncs, function(enabled) refresh16(enabled, enhSettings.colorFaction == true) end)

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local function ShowValueDetail(split, dsc, feature, selectedRow)
    local yOffset = -10

    local titleLabel = OneWoW_GUI:CreateFS(dsc, 16)
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local allRefreshFuncs = {}

    local statusBlock = OneWoW_GUI:CreateFeatureStatusBlock(dsc, {
        yOffset = yOffset,
        statusLabel = L["FEATURE_STATUS_LABEL"],
        enabledText = L["FEATURE_ENABLED"],
        disabledText = L["FEATURE_DISABLED"],
        enableBtnText = L["FEATURE_ENABLE_BTN"],
        disableBtnText = L["FEATURE_DISABLE_BTN"],
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            if selectedRow and selectedRow.dot then
                selectedRow.dot:SetStatus(newState)
            end
            for _, refreshFn in ipairs(allRefreshFuncs) do
                refreshFn(newState)
            end
        end,
    })

    yOffset = statusBlock.getBottomY() - 14

    local valSettings = OneWoW.db.global.settings.tooltips.value

    local section1 = OneWoW_GUI:CreateSectionHeader(dsc, {
        title = L["TIPS_VALUE_OPTIONS_SECTION"],
        yOffset = yOffset,
    })
    yOffset = section1.bottomY - 6

    local sec1Desc = OneWoW_GUI:CreateFS(dsc, 10)
    sec1Desc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    sec1Desc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    sec1Desc:SetJustifyH("LEFT")
    sec1Desc:SetWordWrap(true)
    sec1Desc:SetSpacing(2)
    sec1Desc:SetText(L["TIPS_VALUE_OPTIONS_DESC"])
    sec1Desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - sec1Desc:GetStringHeight() - 6

    local newY1, refresh1 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_VALUE_SHOW_VENDOR_PRICE"],
        description = L["TIPS_VALUE_SHOW_VENDOR_PRICE_DESC"],
        value = valSettings.showVendorPrice ~= false,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            valSettings.showVendorPrice = newVal
        end,
    })
    yOffset = newY1
    table.insert(allRefreshFuncs, function(enabled) refresh1(enabled, valSettings.showVendorPrice ~= false) end)

    local newY2, refresh2 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_VALUE_SHOW_AH_VALUE"],
        description = L["TIPS_VALUE_SHOW_AH_VALUE_DESC"],
        value = valSettings.showAHValue ~= false,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            valSettings.showAHValue = newVal
        end,
    })
    yOffset = newY2
    table.insert(allRefreshFuncs, function(enabled) refresh2(enabled, valSettings.showAHValue ~= false) end)

    local reqSection = OneWoW_GUI:CreateSectionHeader(dsc, {
        title = L["TIPS_VALUE_REQUIRES_SECTION"],
        yOffset = yOffset,
    })
    yOffset = reqSection.bottomY - 12

    local auctionsReqLabel = OneWoW_GUI:CreateFS(dsc, 12)
    auctionsReqLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    auctionsReqLabel:SetText(L["TIPS_VALUE_AUCTIONS_REQUIRES"])
    auctionsReqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local auctionsDetected = C_AddOns.IsAddOnLoaded("OneWoW_AltTracker_Auctions")
    local auctionsDetVal = OneWoW_GUI:CreateFS(dsc, 12)
    auctionsDetVal:SetPoint("LEFT", auctionsReqLabel, "RIGHT", 8, 0)
    if auctionsDetected then
        auctionsDetVal:SetText(L["TIPS_VALUE_AUCTIONS_DETECTED"])
        auctionsDetVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        auctionsDetVal:SetText(L["TIPS_VALUE_AUCTIONS_NOT_DETECTED"])
        auctionsDetVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
    end
    yOffset = yOffset - 24

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
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

    if feature.id == "enhancements" then
        ShowEnhancementsDetail(split, dsc, feature, selectedRow)
        return
    end

    if feature.id == "talentmods" then
        ShowTalentModsDetail(split, dsc, feature, selectedRow)
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

    if feature.id == "value" then
        ShowValueDetail(split, dsc, feature, selectedRow)
        return
    end

    local yOffset = -10

    local titleLabel = OneWoW_GUI:CreateFS(dsc, 16)
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetText(L[feature.title] or feature.title)
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOffset = yOffset - titleLabel:GetStringHeight() - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description] or feature.description)
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

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
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
                        if capturedFeature.id == "playermounts" then
                            activePlayermountsRow = self
                        end
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
        OneWoW_GUI:ApplyFontToFrame(parent)
    end)
end
