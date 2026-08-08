local _, ns = ...

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI

local L = ns.L

local Registry = OneWoW.SettingsFeatureRegistry

local activePlayermountsRow = nil
local auctionsDetValRef = nil
local auctionsDataReadyWatchRegistered = false

local function ApplyAuctionsDetectedLabel()
    if not auctionsDetValRef then return end
    local detected = OneWoW_AltTracker_Auctions_API ~= nil
        or OneWoW:IsDataReady("OneWoW_AltTracker_Auctions")
    if detected then
        auctionsDetValRef:SetText(L["TIPS_VALUE_AUCTIONS_DETECTED"])
        auctionsDetValRef:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        auctionsDetValRef:SetText(L["TIPS_VALUE_AUCTIONS_NOT_DETECTED"])
        auctionsDetValRef:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
    end
end

function ns.UI.RefreshTooltipsFeatureDot(featureId, value)
    if featureId == "playermounts" and activePlayermountsRow and activePlayermountsRow.dot then
        activePlayermountsRow.dot:SetStatus(value)
    end
end

--- Title (left) + Enabled/Disabled header toggle (right). Returns new yOffset.
local function PlaceFeatureHeader(dsc, yOffset, titleText, headerOpts)
    local enableBtn = OneWoW_GUI:CreateFeatureHeaderToggle(dsc, headerOpts)
    enableBtn:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)

    local titleLabel = OneWoW_GUI:CreateFS(dsc, 16)
    titleLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    titleLabel:SetPoint("TOPRIGHT", enableBtn, "TOPLEFT", -8, 0)
    titleLabel:SetJustifyH("LEFT")
    titleLabel:SetWordWrap(false)
    titleLabel:SetText(titleText)
    titleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local headerHeight = math.max(titleLabel:GetStringHeight(), enableBtn:GetHeight())
    return yOffset - headerHeight - 8
end


local function ShowGeneralDetail(split, dsc, selectedRow)
    local yOffset = -10

    yOffset = PlaceFeatureHeader(dsc, yOffset, L["TIPS_GENERAL_TITLE"], {
        selectedRow = selectedRow,
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", "general") end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", "general", newState)
        end,
    })

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

        local rowRefresh, refs
        yOffset, rowRefresh, refs = OneWoW_GUI:CreateToggleRow(dsc, {
            yOffset = yOffset,
            label = L[toggle.localeKey],
            value = currentVal,
            isEnabled = isEnabled,
            onLabel = L["TIPS_TOGGLE_ON"],
            offLabel = L["TIPS_TOGGLE_OFF"],
            buttonWidth = 50,
            onValueChange = function(newVal)
                Registry:SetSetting("tooltips", dbPath, capturedKey, newVal)
            end,
        })

        tinsert(toggleBtnSets, { label = refs.label, key = capturedKey, refresh = rowRefresh })
    end

    return yOffset
end

local function ShowCustomNotesDetail(split, dsc, feature, selectedRow)
    local yOffset = -10
    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local toggleBtnSets = {}

    yOffset = PlaceFeatureHeader(dsc, yOffset, L[feature.title], {
        selectedRow = selectedRow,
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            for _, tbs in ipairs(toggleBtnSets) do
                local val = Registry:GetFeatureSettings("tooltips", "customnotes")[tbs.key]
                tbs.refresh(newState, val ~= false)
                tbs.label:SetTextColor(OneWoW_GUI:GetThemeColor(newState and "TEXT_PRIMARY" or "TEXT_MUTED"))
            end
        end,
    })

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local reqLabel = OneWoW_GUI:CreateFS(dsc, 12)
    reqLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    reqLabel:SetText(L["TIPS_CUSTOMNOTES_REQUIRES"])
    reqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local notesLoaded = (OneWoW_Notes ~= nil)
    local detectedValue = OneWoW_GUI:CreateFS(dsc, 12)
    detectedValue:SetPoint("LEFT", reqLabel, "RIGHT", 8, 0)
    if notesLoaded then
        detectedValue:SetText(L["TIPS_CUSTOMNOTES_DETECTED"])
        detectedValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        detectedValue:SetText(L["TIPS_CUSTOMNOTES_NOT_DETECTED"])
        detectedValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
    end

    yOffset = yOffset - math.max(24, reqLabel:GetStringHeight() + 8)

    local cnSettings = Registry:GetFeatureSettings("tooltips", "customnotes")

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
    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local toggleBtnSets = {}

    yOffset = PlaceFeatureHeader(dsc, yOffset, L[feature.title], {
        selectedRow = selectedRow,
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            for _, tbs in ipairs(toggleBtnSets) do
                local val = Registry:GetFeatureSettings("tooltips", "technicalids")[tbs.key]
                tbs.refresh(newState, val ~= false)
                tbs.label:SetTextColor(OneWoW_GUI:GetThemeColor(newState and "TEXT_PRIMARY" or "TEXT_MUTED"))
            end
        end,
    })

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local toggleHeader = OneWoW_GUI:CreateFS(dsc, 12)
    toggleHeader:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    toggleHeader:SetText(L["TIPS_MODULE_TOGGLES"])
    toggleHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - toggleHeader:GetStringHeight() - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 10

    local tidSettings = Registry:GetFeatureSettings("tooltips", "technicalids")

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
    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local toggleBtnSets = {}

    yOffset = PlaceFeatureHeader(dsc, yOffset, L[feature.title], {
        selectedRow = selectedRow,
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            for _, tbs in ipairs(toggleBtnSets) do
                local val = Registry:GetFeatureSettings("tooltips", "itemtracker")[tbs.key]
                tbs.refresh(newState, val ~= false)
                tbs.label:SetTextColor(OneWoW_GUI:GetThemeColor(newState and "TEXT_PRIMARY" or "TEXT_MUTED"))
            end
        end,
    })

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

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

    local itSettings = Registry:GetFeatureSettings("tooltips", "itemtracker")

    yOffset = CreateSettingToggleRows(dsc, ITEMTRACKER_TOGGLES, toggleBtnSets, isEnabled, itSettings, "itemtracker", yOffset)

    yOffset = yOffset - 6

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    yOffset = ns.UI.BuildAltScopeSection(dsc, {
        yOffset = yOffset,
        x = 12,
        getScope = function()
            local s = Registry:GetFeatureSettings("tooltips", "itemtracker").altScope
            if type(s) ~= "table" then s = { mode = "all", chars = {}, roles = {} } end
            return s
        end,
        saveScope = function(s)
            Registry:SetSetting("tooltips", "itemtracker", "altScope", s)
        end,
    })

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

    local vendorDetected = (OneWoW_CatalogData_Vendors_API ~= nil)
    local vendorDetVal = OneWoW_GUI:CreateFS(dsc, 12)
    vendorDetVal:SetPoint("LEFT", vendorReqLabel, "RIGHT", 8, 0)
    if vendorDetected then
        vendorDetVal:SetText(L["TIPS_ITEMTRACKER_VENDORS_DETECTED"])
        vendorDetVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        vendorDetVal:SetText(L["TIPS_ITEMTRACKER_VENDORS_NOT_DETECTED"])
        vendorDetVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
    end
    yOffset = yOffset - math.max(24, vendorReqLabel:GetStringHeight() + 8)

    local instReqLabel = OneWoW_GUI:CreateFS(dsc, 12)
    instReqLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    instReqLabel:SetText(L["TIPS_ITEMTRACKER_INSTANCES_REQUIRES"])
    instReqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local instDetected = (OneWoW_CatalogData_Journal ~= nil)
    local instDetVal = OneWoW_GUI:CreateFS(dsc, 12)
    instDetVal:SetPoint("LEFT", instReqLabel, "RIGHT", 8, 0)
    if instDetected then
        instDetVal:SetText(L["TIPS_ITEMTRACKER_INSTANCES_DETECTED"])
        instDetVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        instDetVal:SetText(L["TIPS_ITEMTRACKER_INSTANCES_NOT_DETECTED"])
        instDetVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
    end
    yOffset = yOffset - math.max(24, instReqLabel:GetStringHeight() + 8)

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local function ShowPlayerMountsDetail(split, dsc, feature, selectedRow)
    local yOffset = -10

    yOffset = PlaceFeatureHeader(dsc, yOffset, L[feature.title], {
        selectedRow = selectedRow,
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            if feature.id == "playermounts" then
                ns.ModuleRegistry:SetEnabled("playmounts", newState)
                ns.UI.RefreshModuleDot("playmounts", newState)
            end
        end,
    })

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16


    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local reqLabel = OneWoW_GUI:CreateFS(dsc, 12)
    reqLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    reqLabel:SetText(L["TIPS_PLAYERMOUNTS_REQUIRES"])
    reqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local qolLoaded = (OneWoW_QoL ~= nil)
    local detectedValue = OneWoW_GUI:CreateFS(dsc, 12)
    detectedValue:SetPoint("LEFT", reqLabel, "RIGHT", 8, 0)
    if qolLoaded then
        detectedValue:SetText(L["TIPS_PLAYERMOUNTS_DETECTED"])
        detectedValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
    else
        detectedValue:SetText(L["TIPS_PLAYERMOUNTS_NOT_DETECTED"])
        detectedValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
    end
    yOffset = yOffset - math.max(24, reqLabel:GetStringHeight() + 8)

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
    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local allRefreshFuncs = {}

    yOffset = PlaceFeatureHeader(dsc, yOffset, L[feature.title], {
        selectedRow = selectedRow,
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            for _, refreshFn in ipairs(allRefreshFuncs) do
                refreshFn(newState)
            end
        end,
    })

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    -- Live block, read-only; all writes go through Registry:SetSetting.
    local tmSettings = Registry:GetFeatureSettings("tooltips", "talentmods")

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
            Registry:SetSetting("tooltips", "talentmods", "includeActive", newVal)
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
            Registry:SetSetting("tooltips", "talentmods", "hideInCombat", newVal)
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
    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local allRefreshFuncs = {}

    yOffset = PlaceFeatureHeader(dsc, yOffset, L[feature.title], {
        selectedRow = selectedRow,
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            for _, refreshFn in ipairs(allRefreshFuncs) do
                refreshFn(newState)
            end
        end,
    })

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    -- Live block, read-only; all writes go through Registry:SetSetting.
    local enhSettings = Registry:GetFeatureSettings("tooltips", "enhancements")

    local sectionItems = OneWoW_GUI:CreateSectionHeader(dsc, {
        title = L["TIPS_ENHANCEMENTS_SECTION_ITEMS"],
        yOffset = yOffset,
    })
    yOffset = sectionItems.bottomY - 6

    local secItemsDesc = OneWoW_GUI:CreateFS(dsc, 10)
    secItemsDesc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    secItemsDesc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    secItemsDesc:SetJustifyH("LEFT")
    secItemsDesc:SetWordWrap(true)
    secItemsDesc:SetSpacing(2)
    secItemsDesc:SetText(L["TIPS_ENHANCEMENTS_SECTION_ITEMS_DESC"])
    secItemsDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - secItemsDesc:GetStringHeight() - 10

    local newY0, refresh0 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_ENHANCEMENTS_REMOVE_BLIZZ_VENDOR"],
        description = L["TIPS_ENHANCEMENTS_REMOVE_BLIZZ_VENDOR_DESC"],
        value = enhSettings.removeBlizzardVendorValue ~= false,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            Registry:SetSetting("tooltips", "enhancements", "removeBlizzardVendorValue", newVal)
        end,
    })
    yOffset = newY0
    table.insert(allRefreshFuncs, function(enabled) refresh0(enabled, enhSettings.removeBlizzardVendorValue ~= false) end)

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
            Registry:SetSetting("tooltips", "enhancements", "hideHealthbar", newVal)
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
            Registry:SetSetting("tooltips", "enhancements", "hideInCombat", newVal)
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
                    Registry:SetSetting("tooltips", "enhancements", "tooltipScale", val)
                end,
            })
            slider:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            return slider, 36
        end,
        value = enhSettings.scaleEnabled == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            Registry:SetSetting("tooltips", "enhancements", "scaleEnabled", newVal)
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
                    Registry:SetSetting("tooltips", "enhancements", "anchorPosition", value)
                    dropdownText:SetText(text)
                end,
                getActiveValue = function() return enhSettings.anchorPosition or "ANCHOR_CURSOR_RIGHT" end,
            })
            return dropdown, 26
        end,
        value = enhSettings.anchorEnabled == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            Registry:SetSetting("tooltips", "enhancements", "anchorEnabled", newVal)
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
            Registry:SetSetting("tooltips", "enhancements", "classColorNames", newVal)
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
            Registry:SetSetting("tooltips", "enhancements", "guildRank", newVal)
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
            Registry:SetSetting("tooltips", "enhancements", "playerTarget", newVal)
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
            Registry:SetSetting("tooltips", "enhancements", "mythicScore", newVal)
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
            Registry:SetSetting("tooltips", "enhancements", "hideServerName", newVal)
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
            Registry:SetSetting("tooltips", "enhancements", "hideTitles", newVal)
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
            Registry:SetSetting("tooltips", "enhancements", "removePvpTag", newVal)
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
                    Registry:SetSetting("tooltips", "enhancements", "borderOpacity", val)
                end,
            })
            slider:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            return slider, 36
        end,
        value = enhSettings.borderOpacityEnabled == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            Registry:SetSetting("tooltips", "enhancements", "borderOpacityEnabled", newVal)
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
                    Registry:SetSetting("tooltips", "enhancements", "bgOpacity", val)
                end,
            })
            slider:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            return slider, 36
        end,
        value = enhSettings.bgOpacityEnabled == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            Registry:SetSetting("tooltips", "enhancements", "bgOpacityEnabled", newVal)
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
            Registry:SetSetting("tooltips", "enhancements", "colorParty", newVal)
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
            Registry:SetSetting("tooltips", "enhancements", "colorGuild", newVal)
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
            Registry:SetSetting("tooltips", "enhancements", "colorFaction", newVal)
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
    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local allRefreshFuncs = {}

    yOffset = PlaceFeatureHeader(dsc, yOffset, L[feature.title], {
        selectedRow = selectedRow,
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            for _, refreshFn in ipairs(allRefreshFuncs) do
                refreshFn(newState)
            end
        end,
    })

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    -- Live block, read-only; all writes go through Registry:SetSetting, which
    -- also drives ExternalTooltipSync via its registered listener.
    local valSettings = Registry:GetFeatureSettings("tooltips", "value")
    local fontOffset = math.max(0, OneWoW_GUI:GetFontSizeOffset() or 0)

    local secDisplay = OneWoW_GUI:CreateSectionHeader(dsc, {
        title = L["TIPS_VALUE_SECTION_DISPLAY"],
        yOffset = yOffset,
    })
    yOffset = secDisplay.bottomY - 12

    local dispDesc = OneWoW_GUI:CreateFS(dsc, 10)
    dispDesc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    dispDesc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    dispDesc:SetJustifyH("LEFT")
    dispDesc:SetWordWrap(true)
    dispDesc:SetSpacing(2)
    dispDesc:SetText(L["TIPS_VALUE_SECTION_DISPLAY_DESC"])
    dispDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - dispDesc:GetStringHeight() - 10

    local newY1, refresh1 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_VALUE_SHOW_VENDOR_PRICE"],
        description = L["TIPS_VALUE_SHOW_VENDOR_PRICE_DESC"],
        value = valSettings.showVendorPrice ~= false,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            Registry:SetSetting("tooltips", "value", "showVendorPrice", newVal)
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
            Registry:SetSetting("tooltips", "value", "showAHValue", newVal)
        end,
    })
    yOffset = newY2
    table.insert(allRefreshFuncs, function(enabled) refresh2(enabled, valSettings.showAHValue ~= false) end)

    yOffset = yOffset - 16

    local secAH = OneWoW_GUI:CreateSectionHeader(dsc, {
        title = L["TIPS_VALUE_SECTION_AH"],
        yOffset = yOffset,
    })
    yOffset = secAH.bottomY - 12

    local ahIntro = OneWoW_GUI:CreateFS(dsc, 10)
    ahIntro:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    ahIntro:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    ahIntro:SetJustifyH("LEFT")
    ahIntro:SetWordWrap(true)
    ahIntro:SetSpacing(2)
    ahIntro:SetText(L["TIPS_VALUE_SECTION_AH_DESC"])
    ahIntro:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - ahIntro:GetStringHeight() - 8

    local ahSourceWidgets = OneWoW.ItemPrices:AttachAHSourceControl(dsc, { yOffset = yOffset, width = 220 })
    yOffset = ahSourceWidgets.bottomY

    local function refreshAhSourceRow(enabled, ahOn)
        local on = enabled and ahOn
        if on then
            ahSourceWidgets.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            ahSourceWidgets.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
        ahSourceWidgets.desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        ahSourceWidgets.dropdown:SetAlpha(on and 1 or 0.45)
    end
    table.insert(allRefreshFuncs, function(enabled) refreshAhSourceRow(enabled, valSettings.showAHValue ~= false) end)
    refreshAhSourceRow(isEnabled, valSettings.showAHValue ~= false)

    yOffset = yOffset - 14

    local secTSM = OneWoW_GUI:CreateSectionHeader(dsc, {
        title = L["TIPS_VALUE_SECTION_TSM"],
        yOffset = yOffset,
    })
    yOffset = secTSM.bottomY - 12

    local tsmIntro = OneWoW_GUI:CreateFS(dsc, 10)
    tsmIntro:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    tsmIntro:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    tsmIntro:SetJustifyH("LEFT")
    tsmIntro:SetWordWrap(true)
    tsmIntro:SetSpacing(2)
    tsmIntro:SetText(L["TIPS_VALUE_SECTION_TSM_DESC"])
    tsmIntro:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - tsmIntro:GetStringHeight() - 8

    local newY3, refresh3 = OneWoW_GUI:CreateToggleRow(dsc, {
        yOffset = yOffset,
        label = L["TIPS_VALUE_SHOW_TSM"],
        description = L["TIPS_VALUE_SHOW_TSM_DESC"],
        value = valSettings.showTSMValue == true,
        isEnabled = isEnabled,
        onValueChange = function(newVal)
            Registry:SetSetting("tooltips", "value", "showTSMValue", newVal)
        end,
    })
    yOffset = newY3
    table.insert(allRefreshFuncs, function(enabled) refresh3(enabled, valSettings.showTSMValue == true) end)

    local tsmStrLabel = OneWoW_GUI:CreateFS(dsc, 12)
    tsmStrLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    tsmStrLabel:SetJustifyH("LEFT")
    tsmStrLabel:SetText(L["TIPS_VALUE_TSM_STRING_LABEL"])
    tsmStrLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - tsmStrLabel:GetStringHeight() - 4

    local tsmStrEb = OneWoW_GUI:CreateEditBox(dsc, {
        width = 240,
        height = 26,
        placeholderText = "",
    })
    tsmStrEb:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    tsmStrEb:SetText(valSettings.tsmPriceString or "dbmarket")
    tsmStrEb:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    tsmStrEb:HookScript("OnEditFocusLost", function(self)
        local t = self:GetText()
        Registry:SetSetting("tooltips", "value", "tsmPriceString", (t and t ~= "") and t or "dbmarket")
    end)
    tsmStrEb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    yOffset = yOffset - (32 + fontOffset)

    local tsmStrDesc = OneWoW_GUI:CreateFS(dsc, 10)
    tsmStrDesc:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    tsmStrDesc:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    tsmStrDesc:SetJustifyH("LEFT")
    tsmStrDesc:SetWordWrap(true)
    tsmStrDesc:SetSpacing(2)
    tsmStrDesc:SetText(L["TIPS_VALUE_TSM_STRING_DESC"])
    tsmStrDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    yOffset = yOffset - tsmStrDesc:GetStringHeight() - 10

    local function refreshTsmStrRow(enabled, tsmOn)
        local on = enabled and tsmOn
        if on then
            tsmStrLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            tsmStrLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
        tsmStrDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        tsmStrEb:SetAlpha(on and 1 or 0.45)
    end
    table.insert(allRefreshFuncs, function(enabled) refreshTsmStrRow(enabled, valSettings.showTSMValue == true) end)
    refreshTsmStrRow(isEnabled, valSettings.showTSMValue == true)

    local reqSection = OneWoW_GUI:CreateSectionHeader(dsc, {
        title = L["TIPS_VALUE_REQUIRES_SECTION"],
        yOffset = yOffset,
    })
    yOffset = reqSection.bottomY - 12

    local auctionsReqLabel = OneWoW_GUI:CreateFS(dsc, 12)
    auctionsReqLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    auctionsReqLabel:SetText(L["TIPS_VALUE_AUCTIONS_REQUIRES"])
    auctionsReqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local auctionsDetVal = OneWoW_GUI:CreateFS(dsc, 12)
    auctionsDetVal:SetPoint("LEFT", auctionsReqLabel, "RIGHT", 8, 0)
    auctionsDetValRef = auctionsDetVal
    ApplyAuctionsDetectedLabel()
    if not auctionsDataReadyWatchRegistered then
        auctionsDataReadyWatchRegistered = true
        OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Auctions", ApplyAuctionsDetectedLabel)
    end
    yOffset = yOffset - math.max(24, auctionsReqLabel:GetStringHeight() + 8)

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local PETS_TOGGLES = {
    { key = "showCollectionStatus", localeKey = "TIPS_PETS_SHOW_COLLECTION" },
    { key = "showPetInfo",          localeKey = "TIPS_PETS_SHOW_PETINFO" },
    { key = "showSource",           localeKey = "TIPS_PETS_SHOW_SOURCE" },
    { key = "showDescription",      localeKey = "TIPS_PETS_SHOW_DESCRIPTION" },
    { key = "showValue",            localeKey = "TIPS_PETS_SHOW_VALUE" },
    { key = "showAHValue",          localeKey = "TIPS_PETS_SHOW_AH_VALUE" },
    { key = "showItemStatus",       localeKey = "TIPS_PETS_SHOW_ITEMSTATUS" },
    { key = "showTechnicalIDs",     localeKey = "TIPS_PETS_SHOW_TECHIDS" },
}

local function ShowPetsDetail(split, dsc, feature, selectedRow)
    local yOffset = -10
    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local toggleBtnSets = {}

    yOffset = PlaceFeatureHeader(dsc, yOffset, L[feature.title], {
        selectedRow = selectedRow,
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            for _, tbs in ipairs(toggleBtnSets) do
                local val = Registry:GetFeatureSettings("tooltips", "pets")[tbs.key]
                tbs.refresh(newState, val ~= false)
                tbs.label:SetTextColor(OneWoW_GUI:GetThemeColor(newState and "TEXT_PRIMARY" or "TEXT_MUTED"))
            end
        end,
    })

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16

    local toggleHeader = OneWoW_GUI:CreateFS(dsc, 12)
    toggleHeader:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    toggleHeader:SetText(L["TIPS_MODULE_TOGGLES"])
    toggleHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - toggleHeader:GetStringHeight() - 8

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 10

    local petsSettings = Registry:GetFeatureSettings("tooltips", "pets")

    yOffset = CreateSettingToggleRows(dsc, PETS_TOGGLES, toggleBtnSets, isEnabled, petsSettings, "pets", yOffset)

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local function ShowCollectionsDetail(split, dsc, feature, selectedRow)
    local yOffset = -10

    yOffset = PlaceFeatureHeader(dsc, yOffset, L[feature.title], {
        selectedRow = selectedRow,
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
        end,
    })

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16


    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local settingsLabel = OneWoW_GUI:CreateFS(dsc, 12)
    settingsLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    settingsLabel:SetText(L["TIPS_COLLECTIONS_RECIPE_ALT_DISPLAY"])
    settingsLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - settingsLabel:GetStringHeight() - 6

    local hintLabel = OneWoW_GUI:CreateFS(dsc, 11)
    hintLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    hintLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    hintLabel:SetJustifyH("LEFT")
    hintLabel:SetWordWrap(true)
    hintLabel:SetSpacing(2)
    hintLabel:SetText(L["TIPS_COLLECTIONS_RECIPE_ALT_DISPLAY_DESC"])
    hintLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    yOffset = yOffset - hintLabel:GetStringHeight() - 10

    local DISPLAY_MODE_KEYS = {
        differentiated = "TIPS_COLLECTIONS_RECIPE_ALT_DIFFERENTIATED",
        combined = "TIPS_COLLECTIONS_RECIPE_ALT_COMBINED",
        self_only = "TIPS_COLLECTIONS_RECIPE_ALT_SELF_ONLY",
    }

    local currentMode = Registry:GetFeatureSettings("tooltips", "collections").recipeAltDisplay or "differentiated"
    local currentKey = DISPLAY_MODE_KEYS[currentMode] or DISPLAY_MODE_KEYS.differentiated

    local dropdown, dropdownText = OneWoW_GUI:CreateDropdown(dsc, {
        width = 220,
        height = 26,
        text = L[currentKey],
    })
    dropdown:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    yOffset = yOffset - 34

    OneWoW_GUI:AttachFilterMenu(dropdown, {
        searchable = false,
        buildItems = function()
            return {
                { value = "differentiated", text = L["TIPS_COLLECTIONS_RECIPE_ALT_DIFFERENTIATED"] },
                { value = "combined", text = L["TIPS_COLLECTIONS_RECIPE_ALT_COMBINED"] },
                { value = "self_only", text = L["TIPS_COLLECTIONS_RECIPE_ALT_SELF_ONLY"] },
            }
        end,
        onSelect = function(value, text)
            Registry:SetSetting("tooltips", "collections", "recipeAltDisplay", value)
            dropdownText:SetText(text)
        end,
    })

    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local function ShowRecipeKnowledgeDetail(split, dsc, feature, selectedRow)
    local yOffset = -10

    yOffset = PlaceFeatureHeader(dsc, yOffset, L[feature.title], {
        selectedRow = selectedRow,
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
        end,
    })

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16


    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    yOffset = ns.UI.BuildAltScopeSection(dsc, {
        yOffset = yOffset,
        x = 12,
        getScope = function()
            local s = Registry:GetFeatureSettings("tooltips", "recipeknowledge").altScope
            if type(s) ~= "table" then s = { mode = "all", chars = {}, roles = {} } end
            return s
        end,
        saveScope = function(s)
            Registry:SetSetting("tooltips", "recipeknowledge", "altScope", s)
        end,
    })

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

    if feature.id == "collections" then
        ShowCollectionsDetail(split, dsc, feature, selectedRow)
        return
    end

    if feature.id == "recipeknowledge" then
        ShowRecipeKnowledgeDetail(split, dsc, feature, selectedRow)
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

    if feature.id == "pets" then
        ShowPetsDetail(split, dsc, feature, selectedRow)
        return
    end

    if feature.id == "gearupgrades" then
        -- 1:1 mirror of Overlays > Gear Upgrade Overlay. We hand the overlay
        -- detail builder a feature whose id points at the overlays-side key
        -- ("upgrade") so enable state + every setting reads/writes the same
        -- storage used by the Overlays tab. Only the displayed title/desc
        -- are overridden with the Tooltips-flavored locale keys.
        local overlayFeature = {
            id          = "upgrade",
            title       = feature.title,
            description = feature.description,
        }
        ns.UI.ShowOverlayFeatureDetail(split, overlayFeature, selectedRow)
        return
    end

    local yOffset = -10

    yOffset = PlaceFeatureHeader(dsc, yOffset, L[feature.title], {
        selectedRow = selectedRow,
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled(tabName, feature.id, newState)
        end,
    })

    OneWoW_GUI:CreateDivider(dsc, { yOffset = yOffset })
    yOffset = yOffset - 12

    local descLabel = OneWoW_GUI:CreateFS(dsc, 12)
    descLabel:SetPoint("TOPLEFT", dsc, "TOPLEFT", 12, yOffset)
    descLabel:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", -12, yOffset)
    descLabel:SetJustifyH("LEFT")
    descLabel:SetWordWrap(true)
    descLabel:SetSpacing(3)
    descLabel:SetText(L[feature.description])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - descLabel:GetStringHeight() - 16


    dsc:SetHeight(math.abs(yOffset) + 20)
    OneWoW_GUI:ApplyFontToFrame(dsc)
    split.UpdateDetailThumb()
end

local function BuildFeatureList(split, tabName)
    local lsc = split.listScrollChild
    local features = OneWoW.SettingsFeatureRegistry:GetByTab(tabName)
    local selectedRow = nil
    local selectedFeatureId = nil
    local allRows = {}

    local function UpdateEnabledCount()
        local enabledCount = 0
        for _, f in ipairs(features) do
            if OneWoW.SettingsFeatureRegistry:IsEnabled(tabName, f.id) then
                enabledCount = enabledCount + 1
            end
        end
        split.leftStatusText:SetText(string.format("Features: %d/%d", enabledCount, #features))
    end

    local function RenderRows(filterText)
        OneWoW_GUI:ClearFrame(lsc)
        selectedRow = nil
        allRows = {}
        local rowToSelect = nil
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
                        selectedFeatureId = capturedFeature.id
                        if capturedFeature.id == "playermounts" then
                            activePlayermountsRow = self
                        end
                        self:SetActive(true)
                        ShowFeatureDetail(split, capturedFeature, tabName, self)
                    end,
                })
                row:SetPoint("TOPLEFT", lsc, "TOPLEFT", 4, yOffset)
                row:SetPoint("TOPRIGHT", lsc, "TOPRIGHT", -4, yOffset)
                if capturedFeature.id == selectedFeatureId then
                    rowToSelect = row
                end
                table.insert(allRows, row)
                yOffset = yOffset - 34
            end
        end

        lsc:SetHeight(math.abs(yOffset) + 10)
        if #allRows > 0 and not selectedRow then
            (rowToSelect or allRows[1]):Click()
        end
        UpdateEnabledCount()
    end

    RenderRows("")

    if split.searchBox then
        split.searchBox:SetScript("OnTextChanged", function(self)
            local text = self:GetSearchText()
            RenderRows(text)
        end)
    end

    -- Re-render on tab activation: the selected feature's detail pane is
    -- rebuilt with fresh registry reads, so state changed elsewhere (e.g.
    -- Overlays > Upgrade, mirrored by Gear Upgrades here) shows correctly.
    split.RefreshList = function()
        local text = split.searchBox and split.searchBox:GetSearchText() or ""
        RenderRows(text)
    end
end

function ns.UI.CreateTooltipsTab(parent)
    local split = OneWoW_GUI:CreateSplitPanel(parent, { showSearch = true, searchPlaceholder = L["SEARCH_HINT"] })
    split.listTitle:SetText(L["TOOLTIPS_LIST_TITLE"])
    split.detailTitle:SetText(L["TOOLTIPS_DETAIL_TITLE"])

    C_Timer.After(0.1, function()
        BuildFeatureList(split, "tooltips")
        OneWoW_GUI:ApplyFontToFrame(parent)
    end)

    -- nil until the deferred BuildFeatureList above has run once.
    parent.Activate = function()
        if split.RefreshList then split.RefreshList() end
    end
end
