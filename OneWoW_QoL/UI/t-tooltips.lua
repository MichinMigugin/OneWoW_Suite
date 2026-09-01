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

-- Session-only collapse memory for Tooltips settings cards (cleared on /reload).
local collapsedTooltipCards = {}

local function PlaceCardSectionDesc(content, text, yOffset, contentWidth)
    local fs = OneWoW_GUI:CreateFS(content, 10)
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetSpacing(2)
    local w = tonumber(contentWidth) or 0
    if w < 1 then
        w = content:GetWidth() or 0
    end
    if w >= 1 then
        fs:SetWidth(w)
    else
        fs:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, yOffset)
    end
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    return yOffset - (fs:GetStringHeight() or 14) - 10
end

--- Card stack under feature chrome. Returns stack, finishFn (Finish + height + fonts).
local function BeginDetailCardStack(split, dsc, headerBottom)
    local cardsHost = CreateFrame("Frame", nil, dsc)
    cardsHost:SetPoint("TOPLEFT", dsc, "TOPLEFT", 0, headerBottom)
    cardsHost:SetPoint("TOPRIGHT", dsc, "TOPRIGHT", 0, headerBottom)

    local stack = OneWoW_GUI:CreateCardStack(cardsHost, {
        getCollapsed = function(key) return collapsedTooltipCards[key] end,
        setCollapsed = function(key, collapsed) collapsedTooltipCards[key] = collapsed end,
    })

    local function updateDetailHeight()
        dsc:SetHeight(math.abs(headerBottom) + cardsHost:GetHeight() + 20)
        split.UpdateDetailThumb()
    end
    stack.OnRelayout = updateDetailHeight

    local function finish()
        stack:Finish()
        updateDetailHeight()
        OneWoW_GUI:ApplyFontToFrame(dsc)
    end

    return stack, finish
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

local function CreateSettingToggleRows(parent, toggleList, toggleBtnSets, isEnabled, settingsTable, dbPath, yOffset, contentWidth)
    for _, toggle in ipairs(toggleList) do
        local capturedKey = toggle.key
        local currentVal = settingsTable[capturedKey] ~= false

        local rowRefresh, refs
        yOffset, rowRefresh, refs = OneWoW_GUI:CreateToggleRow(parent, {
            yOffset = yOffset,
            contentWidth = contentWidth,
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

    local cnSettings = Registry:GetFeatureSettings("tooltips", "customnotes")
    local stack, finish = BeginDetailCardStack(split, dsc, yOffset)

    stack:AddCard("tips:cn:requires", L["TIPS_ITEMTRACKER_REQUIRES_SECTION"], function(content, _)
        local rowY = 0
        local reqLabel = OneWoW_GUI:CreateFS(content, 12)
        reqLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 12, rowY)
        reqLabel:SetText(L["TIPS_CUSTOMNOTES_REQUIRES"])
        reqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local notesLoaded = (OneWoW_Notes ~= nil)
        local detectedValue = OneWoW_GUI:CreateFS(content, 12)
        detectedValue:SetPoint("LEFT", reqLabel, "RIGHT", 8, 0)
        if notesLoaded then
            detectedValue:SetText(L["TIPS_CUSTOMNOTES_DETECTED"])
            detectedValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            detectedValue:SetText(L["TIPS_CUSTOMNOTES_NOT_DETECTED"])
            detectedValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end
        return math.max(1, math.max(24, reqLabel:GetStringHeight() + 8))
    end)

    stack:AddCard("tips:cn:lines", L["TIPS_CUSTOMNOTES_SECTION_LINES"], function(content, contentWidth)
        local rowY = PlaceCardSectionDesc(content, L["TIPS_CUSTOMNOTES_SECTION_LINES_DESC"], 0, contentWidth)
        rowY = CreateSettingToggleRows(content, CUSTOMNOTES_LINE_TOGGLES, toggleBtnSets, isEnabled, cnSettings, "customnotes", rowY, contentWidth)
        return math.max(1, math.abs(rowY))
    end)

    stack:AddCard("tips:cn:warning", L["TIPS_CUSTOMNOTES_SECTION_WARNING"], function(content, contentWidth)
        local rowY = PlaceCardSectionDesc(content, L["TIPS_CUSTOMNOTES_SECTION_WARNING_DESC"], 0, contentWidth)
        rowY = CreateSettingToggleRows(content, CUSTOMNOTES_WARNING_TOGGLES, toggleBtnSets, isEnabled, cnSettings, "customnotes", rowY, contentWidth)
        return math.max(1, math.abs(rowY))
    end)

    finish()
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

    local tidSettings = Registry:GetFeatureSettings("tooltips", "technicalids")
    local stack, finish = BeginDetailCardStack(split, dsc, yOffset)

    stack:AddCard("tips:tid:toggles", L["TIPS_MODULE_TOGGLES"], function(content, contentWidth)
        local rowY = CreateSettingToggleRows(content, TECHID_TOGGLES, toggleBtnSets, isEnabled, tidSettings, "technicalids", 0, contentWidth)
        return math.max(1, math.abs(rowY))
    end)

    finish()
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
    { key = "showQuests",      localeKey = "TIPS_ITEMTRACKER_SHOW_QUESTS" },
    { key = "showCrafted",     localeKey = "TIPS_ITEMTRACKER_SHOW_CRAFTED" },
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

    local itSettings = Registry:GetFeatureSettings("tooltips", "itemtracker")
    local stack, finish = BeginDetailCardStack(split, dsc, yOffset)

    stack:AddCard("tips:it:requires", L["TIPS_ITEMTRACKER_REQUIRES_SECTION"], function(content, _)
        local rowY = 0
        local function addRequireRow(labelKey, loaded)
            local reqLabel = OneWoW_GUI:CreateFS(content, 12)
            reqLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 12, rowY)
            reqLabel:SetText(L[labelKey])
            reqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local detVal = OneWoW_GUI:CreateFS(content, 12)
            detVal:SetPoint("LEFT", reqLabel, "RIGHT", 8, 0)
            if loaded then
                detVal:SetText(L["TIPS_ITEMTRACKER_VENDORS_DETECTED"])
                detVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            else
                detVal:SetText(L["TIPS_ITEMTRACKER_VENDORS_NOT_DETECTED"])
                detVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            end
            rowY = rowY - math.max(24, reqLabel:GetStringHeight() + 8)
        end

        addRequireRow("TIPS_ITEMTRACKER_VENDORS_REQUIRES", OneWoW:IsCatalogPackAvailable("vendors"))
        addRequireRow("TIPS_ITEMTRACKER_INSTANCES_REQUIRES", OneWoW:IsCatalogPackAvailable("journal"))
        addRequireRow("TIPS_ITEMTRACKER_QUESTS_REQUIRES", OneWoW:IsCatalogPackAvailable("quests"))
        addRequireRow("TIPS_ITEMTRACKER_CRAFT_REQUIRES", OneWoW:IsCatalogPackAvailable("tradeskills"))
        return math.max(1, math.abs(rowY))
    end)

    stack:AddCard("tips:it:track", L["TIPS_ITEMTRACKER_TRACK_SECTION"], function(content, contentWidth)
        local rowY = PlaceCardSectionDesc(content, L["TIPS_ITEMTRACKER_TRACK_SECTION_DESC"], 0, contentWidth)
        rowY = CreateSettingToggleRows(content, ITEMTRACKER_TOGGLES, toggleBtnSets, isEnabled, itSettings, "itemtracker", rowY, contentWidth)
        return math.max(1, math.abs(rowY))
    end)

    stack:AddCard("tips:it:scope", L["TIPS_SCOPE_HEADER"], function(content, contentWidth)
        local rowY = ns.UI.BuildAltScopeSection(content, {
            yOffset = 0,
            x = 0,
            omitHeader = true,
            contentWidth = contentWidth,
            getScope = function()
                local s = Registry:GetFeatureSettings("tooltips", "itemtracker").altScope
                if type(s) ~= "table" then s = { mode = "all", chars = {}, roles = {} } end
                return s
            end,
            saveScope = function(s)
                Registry:SetSetting("tooltips", "itemtracker", "altScope", s)
            end,
        })
        return math.max(1, math.abs(rowY))
    end)

    finish()
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

    local stack, finish = BeginDetailCardStack(split, dsc, yOffset)

    stack:AddCard("tips:pm:requires", L["TIPS_ITEMTRACKER_REQUIRES_SECTION"], function(content, contentWidth)
        local rowY = 0
        local reqLabel = OneWoW_GUI:CreateFS(content, 12)
        reqLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 12, rowY)
        reqLabel:SetText(L["TIPS_PLAYERMOUNTS_REQUIRES"])
        reqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local qolLoaded = (OneWoW_QoL ~= nil)
        local detectedValue = OneWoW_GUI:CreateFS(content, 12)
        detectedValue:SetPoint("LEFT", reqLabel, "RIGHT", 8, 0)
        if qolLoaded then
            detectedValue:SetText(L["TIPS_PLAYERMOUNTS_DETECTED"])
            detectedValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            detectedValue:SetText(L["TIPS_PLAYERMOUNTS_NOT_DETECTED"])
            detectedValue:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end
        rowY = rowY - math.max(24, reqLabel:GetStringHeight() + 8)

        local noteLabel = OneWoW_GUI:CreateFS(content, 10)
        noteLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 12, rowY)
        local w = tonumber(contentWidth) or 0
        if w >= 1 then
            noteLabel:SetWidth(math.max(1, w - 24))
        else
            noteLabel:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, rowY)
        end
        noteLabel:SetJustifyH("LEFT")
        noteLabel:SetWordWrap(true)
        noteLabel:SetSpacing(2)
        noteLabel:SetText(L["TIPS_PLAYERMOUNTS_SETTINGS_NOTE"])
        noteLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        rowY = rowY - (noteLabel:GetStringHeight() or 14) - 8

        local viewLink = OneWoW_GUI:CreateTextLink(content, {
            text = L["TIPS_PLAYERMOUNTS_VIEW_BTN"],
            fontSize = 11,
            nav = true,
            onClick = function()
                ns.UI.SelectFeature("playmounts")
            end,
        })
        viewLink:SetPoint("TOPLEFT", content, "TOPLEFT", 12, rowY)
        viewLink:SetEnabled(qolLoaded)
        rowY = rowY - (viewLink:GetHeight() or 14) - 4
        return math.max(1, math.abs(rowY))
    end)

    finish()
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

    local tmSettings = Registry:GetFeatureSettings("tooltips", "talentmods")
    local stack, finish = BeginDetailCardStack(split, dsc, yOffset)

    stack:AddCard("tips:talentmods:settings", L["TIPS_TALENTMODS_SECTION_SETTINGS"], function(content, contentWidth)
        local rowY = PlaceCardSectionDesc(content, L["TIPS_TALENTMODS_SECTION_SETTINGS_DESC"], 0, contentWidth)

        local newY1, refresh1 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
            label = L["TIPS_TALENTMODS_INCLUDE_ACTIVE"],
            description = L["TIPS_TALENTMODS_INCLUDE_ACTIVE_DESC"],
            value = tmSettings.includeActive == true,
            isEnabled = isEnabled,
            onValueChange = function(newVal)
                Registry:SetSetting("tooltips", "talentmods", "includeActive", newVal)
            end,
        })
        rowY = newY1
        tinsert(allRefreshFuncs, function(enabled) refresh1(enabled, tmSettings.includeActive == true) end)

        local newY2, refresh2 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
            label = L["TIPS_TALENTMODS_HIDE_COMBAT"],
            description = L["TIPS_TALENTMODS_HIDE_COMBAT_DESC"],
            value = tmSettings.hideInCombat == true,
            isEnabled = isEnabled,
            onValueChange = function(newVal)
                Registry:SetSetting("tooltips", "talentmods", "hideInCombat", newVal)
            end,
        })
        rowY = newY2
        tinsert(allRefreshFuncs, function(enabled) refresh2(enabled, tmSettings.hideInCombat == true) end)

        return math.max(1, math.abs(rowY))
    end)

    finish()
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

    local enhSettings = Registry:GetFeatureSettings("tooltips", "enhancements")
    local stack, finish = BeginDetailCardStack(split, dsc, yOffset)

    stack:AddCard("tips:enh:items", L["TIPS_ENHANCEMENTS_SECTION_ITEMS"], function(content, contentWidth)
        local rowY = PlaceCardSectionDesc(content, L["TIPS_ENHANCEMENTS_SECTION_ITEMS_DESC"], 0, contentWidth)
        local newY0, refresh0 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
            label = L["TIPS_ENHANCEMENTS_REMOVE_BLIZZ_VENDOR"],
            description = L["TIPS_ENHANCEMENTS_REMOVE_BLIZZ_VENDOR_DESC"],
            value = enhSettings.removeBlizzardVendorValue ~= false,
            isEnabled = isEnabled,
            onValueChange = function(newVal)
                Registry:SetSetting("tooltips", "enhancements", "removeBlizzardVendorValue", newVal)
            end,
        })
        tinsert(allRefreshFuncs, function(enabled) refresh0(enabled, enhSettings.removeBlizzardVendorValue ~= false) end)
        return math.max(1, math.abs(newY0))
    end)

    stack:AddCard("tips:enh:appearance", L["TIPS_ENHANCEMENTS_SECTION_APPEARANCE"], function(content, contentWidth)
        local rowY = PlaceCardSectionDesc(content, L["TIPS_ENHANCEMENTS_SECTION_APPEARANCE_DESC"], 0, contentWidth)

        local newY1, refresh1 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
            label = L["TIPS_ENHANCEMENTS_HIDE_HEALTHBAR"],
            description = L["TIPS_ENHANCEMENTS_HIDE_HEALTHBAR_DESC"],
            value = enhSettings.hideHealthbar == true,
            isEnabled = isEnabled,
            onValueChange = function(newVal)
                Registry:SetSetting("tooltips", "enhancements", "hideHealthbar", newVal)
            end,
        })
        rowY = newY1
        tinsert(allRefreshFuncs, function(enabled) refresh1(enabled, enhSettings.hideHealthbar == true) end)

        local newY2, refresh2 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
            label = L["TIPS_ENHANCEMENTS_HIDE_COMBAT"],
            description = L["TIPS_ENHANCEMENTS_HIDE_COMBAT_DESC"],
            value = enhSettings.hideInCombat == true,
            isEnabled = isEnabled,
            onValueChange = function(newVal)
                Registry:SetSetting("tooltips", "enhancements", "hideInCombat", newVal)
            end,
        })
        rowY = newY2
        tinsert(allRefreshFuncs, function(enabled) refresh2(enabled, enhSettings.hideInCombat == true) end)

        local newY3, refresh3 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
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
        rowY = newY3
        tinsert(allRefreshFuncs, function(enabled) refresh3(enabled, enhSettings.scaleEnabled == true) end)

        local newY4, refresh4 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
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
        rowY = newY4
        tinsert(allRefreshFuncs, function(enabled) refresh4(enabled, enhSettings.anchorEnabled == true) end)

        return math.max(1, math.abs(rowY))
    end)

    stack:AddCard("tips:enh:playerinfo", L["TIPS_ENHANCEMENTS_SECTION_PLAYERINFO"], function(content, contentWidth)
        local rowY = PlaceCardSectionDesc(content, L["TIPS_ENHANCEMENTS_SECTION_PLAYERINFO_DESC"], 0, contentWidth)

        local defs = {
            { label = "TIPS_ENHANCEMENTS_CLASS_COLORS", desc = "TIPS_ENHANCEMENTS_CLASS_COLORS_DESC", key = "classColorNames" },
            { label = "TIPS_ENHANCEMENTS_GUILD_RANK", desc = "TIPS_ENHANCEMENTS_GUILD_RANK_DESC", key = "guildRank" },
            { label = "TIPS_ENHANCEMENTS_PLAYER_TARGET", desc = "TIPS_ENHANCEMENTS_PLAYER_TARGET_DESC", key = "playerTarget" },
            { label = "TIPS_ENHANCEMENTS_MYTHIC_SCORE", desc = "TIPS_ENHANCEMENTS_MYTHIC_SCORE_DESC", key = "mythicScore" },
            { label = "TIPS_ENHANCEMENTS_HIDE_SERVER", desc = "TIPS_ENHANCEMENTS_HIDE_SERVER_DESC", key = "hideServerName" },
            { label = "TIPS_ENHANCEMENTS_HIDE_TITLES", desc = "TIPS_ENHANCEMENTS_HIDE_TITLES_DESC", key = "hideTitles" },
            { label = "TIPS_ENHANCEMENTS_REMOVE_PVP_TAG", desc = "TIPS_ENHANCEMENTS_REMOVE_PVP_TAG_DESC", key = "removePvpTag" },
        }
        for _, def in ipairs(defs) do
            local key = def.key
            local newY, refresh = OneWoW_GUI:CreateToggleRow(content, {
                contentWidth = contentWidth,
                yOffset = rowY,
                label = L[def.label],
                description = L[def.desc],
                value = enhSettings[key] == true,
                isEnabled = isEnabled,
                onValueChange = function(newVal)
                    Registry:SetSetting("tooltips", "enhancements", key, newVal)
                end,
            })
            rowY = newY
            tinsert(allRefreshFuncs, function(enabled) refresh(enabled, enhSettings[key] == true) end)
        end

        return math.max(1, math.abs(rowY))
    end)

    stack:AddCard("tips:enh:opacity", L["TIPS_ENHANCEMENTS_SECTION_OPACITY"], function(content, contentWidth)
        local rowY = PlaceCardSectionDesc(content, L["TIPS_ENHANCEMENTS_SECTION_OPACITY_DESC"], 0, contentWidth)

        local newY12, refresh12 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
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
        rowY = newY12
        tinsert(allRefreshFuncs, function(enabled) refresh12(enabled, enhSettings.borderOpacityEnabled == true) end)

        local newY13, refresh13 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
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
        rowY = newY13
        tinsert(allRefreshFuncs, function(enabled) refresh13(enabled, enhSettings.bgOpacityEnabled == true) end)

        return math.max(1, math.abs(rowY))
    end)

    stack:AddCard("tips:enh:unitcolors", L["TIPS_ENHANCEMENTS_SECTION_UNITCOLORS"], function(content, contentWidth)
        local rowY = PlaceCardSectionDesc(content, L["TIPS_ENHANCEMENTS_SECTION_UNITCOLORS_DESC"], 0, contentWidth)

        local function ensureColor(colorKey, defaultR, defaultG, defaultB)
            if not enhSettings[colorKey] then
                enhSettings[colorKey] = { r = defaultR, g = defaultG, b = defaultB }
            end
        end
        ensureColor("partyColor", 0.5, 0.2, 0.65)
        ensureColor("guildColor", 0.2, 0.6, 0.6)
        ensureColor("factionFriendlyColor", 0.15, 0.15, 0.5)
        ensureColor("factionEnemyColor", 0.5, 0.15, 0.12)

        local newY14, refresh14 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
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
        rowY = newY14
        tinsert(allRefreshFuncs, function(enabled) refresh14(enabled, enhSettings.colorParty == true) end)

        local newY15, refresh15 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
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
        rowY = newY15
        tinsert(allRefreshFuncs, function(enabled) refresh15(enabled, enhSettings.colorGuild == true) end)

        local newY16, refresh16 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
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
        rowY = newY16
        tinsert(allRefreshFuncs, function(enabled) refresh16(enabled, enhSettings.colorFaction == true) end)

        return math.max(1, math.abs(rowY))
    end)

    finish()
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

    local valSettings = Registry:GetFeatureSettings("tooltips", "value")
    local fontOffset = math.max(0, OneWoW_GUI:GetFontSizeOffset() or 0)
    local stack, finish = BeginDetailCardStack(split, dsc, yOffset)

    stack:AddCard("tips:value:requires", L["TIPS_VALUE_REQUIRES_SECTION"], function(content, _)
        local rowY = 0
        local auctionsReqLabel = OneWoW_GUI:CreateFS(content, 12)
        auctionsReqLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 12, rowY)
        auctionsReqLabel:SetText(L["TIPS_VALUE_AUCTIONS_REQUIRES"])
        auctionsReqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local auctionsDetVal = OneWoW_GUI:CreateFS(content, 12)
        auctionsDetVal:SetPoint("LEFT", auctionsReqLabel, "RIGHT", 8, 0)
        auctionsDetValRef = auctionsDetVal
        ApplyAuctionsDetectedLabel()
        if not auctionsDataReadyWatchRegistered then
            auctionsDataReadyWatchRegistered = true
            OneWoW:RegisterDataReadyWatcher("OneWoW_AltTracker_Auctions", ApplyAuctionsDetectedLabel)
        end
        rowY = rowY - math.max(24, auctionsReqLabel:GetStringHeight() + 8)
        return math.max(1, math.abs(rowY))
    end)

    stack:AddCard("tips:value:display", L["TIPS_VALUE_SECTION_DISPLAY"], function(content, contentWidth)
        local rowY = PlaceCardSectionDesc(content, L["TIPS_VALUE_SECTION_DISPLAY_DESC"], 0, contentWidth)

        local newY1, refresh1 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
            label = L["TIPS_VALUE_SHOW_VENDOR_PRICE"],
            description = L["TIPS_VALUE_SHOW_VENDOR_PRICE_DESC"],
            value = valSettings.showVendorPrice ~= false,
            isEnabled = isEnabled,
            onValueChange = function(newVal)
                Registry:SetSetting("tooltips", "value", "showVendorPrice", newVal)
            end,
        })
        rowY = newY1
        tinsert(allRefreshFuncs, function(enabled) refresh1(enabled, valSettings.showVendorPrice ~= false) end)

        local newY2, refresh2 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
            label = L["TIPS_VALUE_SHOW_AH_VALUE"],
            description = L["TIPS_VALUE_SHOW_AH_VALUE_DESC"],
            value = valSettings.showAHValue ~= false,
            isEnabled = isEnabled,
            onValueChange = function(newVal)
                Registry:SetSetting("tooltips", "value", "showAHValue", newVal)
            end,
        })
        rowY = newY2
        tinsert(allRefreshFuncs, function(enabled) refresh2(enabled, valSettings.showAHValue ~= false) end)

        return math.max(1, math.abs(rowY))
    end)

    stack:AddCard("tips:value:ah", L["TIPS_VALUE_SECTION_AH"], function(content, contentWidth)
        local rowY = PlaceCardSectionDesc(content, L["TIPS_VALUE_SECTION_AH_DESC"], 0, contentWidth)

        local ahSourceWidgets = OneWoW.ItemPrices:AttachAHSourceControl(content, { yOffset = rowY, width = 220 })
        rowY = ahSourceWidgets.bottomY

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
        tinsert(allRefreshFuncs, function(enabled) refreshAhSourceRow(enabled, valSettings.showAHValue ~= false) end)
        refreshAhSourceRow(isEnabled, valSettings.showAHValue ~= false)

        return math.max(1, math.abs(rowY))
    end)

    stack:AddCard("tips:value:tsm", L["TIPS_VALUE_SECTION_TSM"], function(content, contentWidth)
        local rowY = PlaceCardSectionDesc(content, L["TIPS_VALUE_SECTION_TSM_DESC"], 0, contentWidth)

        local newY3, refresh3 = OneWoW_GUI:CreateToggleRow(content, {
            contentWidth = contentWidth,
            yOffset = rowY,
            label = L["TIPS_VALUE_SHOW_TSM"],
            description = L["TIPS_VALUE_SHOW_TSM_DESC"],
            value = valSettings.showTSMValue == true,
            isEnabled = isEnabled,
            onValueChange = function(newVal)
                Registry:SetSetting("tooltips", "value", "showTSMValue", newVal)
            end,
        })
        rowY = newY3
        tinsert(allRefreshFuncs, function(enabled) refresh3(enabled, valSettings.showTSMValue == true) end)

        local tsmStrLabel = OneWoW_GUI:CreateFS(content, 12)
        tsmStrLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 12, rowY)
        tsmStrLabel:SetJustifyH("LEFT")
        tsmStrLabel:SetText(L["TIPS_VALUE_TSM_STRING_LABEL"])
        tsmStrLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        rowY = rowY - tsmStrLabel:GetStringHeight() - 4

        local tsmStrEb = OneWoW_GUI:CreateEditBox(content, {
            width = 240,
            height = 26,
            placeholderText = "",
        })
        tsmStrEb:SetPoint("TOPLEFT", content, "TOPLEFT", 12, rowY)
        tsmStrEb:SetText(valSettings.tsmPriceString or "dbmarket")
        tsmStrEb:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        tsmStrEb:HookScript("OnEditFocusLost", function(self)
            local t = self:GetText()
            Registry:SetSetting("tooltips", "value", "tsmPriceString", (t and t ~= "") and t or "dbmarket")
        end)
        tsmStrEb:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
        rowY = rowY - (32 + fontOffset)

        local tsmStrDesc = OneWoW_GUI:CreateFS(content, 10)
        tsmStrDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 12, rowY)
        tsmStrDesc:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, rowY)
        tsmStrDesc:SetJustifyH("LEFT")
        tsmStrDesc:SetWordWrap(true)
        tsmStrDesc:SetSpacing(2)
        tsmStrDesc:SetText(L["TIPS_VALUE_TSM_STRING_DESC"])
        tsmStrDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        rowY = rowY - tsmStrDesc:GetStringHeight() - 10

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
        tinsert(allRefreshFuncs, function(enabled) refreshTsmStrRow(enabled, valSettings.showTSMValue == true) end)
        refreshTsmStrRow(isEnabled, valSettings.showTSMValue == true)

        return math.max(1, math.abs(rowY))
    end)

    finish()
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

    local petsSettings = Registry:GetFeatureSettings("tooltips", "pets")
    local stack, finish = BeginDetailCardStack(split, dsc, yOffset)

    stack:AddCard("tips:pets:toggles", L["TIPS_MODULE_TOGGLES"], function(content, contentWidth)
        local rowY = CreateSettingToggleRows(content, PETS_TOGGLES, toggleBtnSets, isEnabled, petsSettings, "pets", 0, contentWidth)
        return math.max(1, math.abs(rowY))
    end)

    finish()
end

local function ShowCollectionsDetail(split, dsc, feature, selectedRow)
    local yOffset = -10
    local isEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id)
    local toggleBtnSets = {}

    yOffset = PlaceFeatureHeader(dsc, yOffset, L[feature.title], {
        selectedRow = selectedRow,
        isEnabled = function() return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", feature.id) end,
        onToggle = function(newState)
            OneWoW.SettingsFeatureRegistry:SetEnabled("tooltips", feature.id, newState)
            for _, tbs in ipairs(toggleBtnSets) do
                local val = Registry:GetFeatureSettings("tooltips", "collections").showNonCollectable == true
                tbs.refresh(newState, val)
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

    local stack, finish = BeginDetailCardStack(split, dsc, yOffset)

    stack:AddCard("tips:col:noncollectable", L["TIPS_COLLECTIONS_SHOW_NONCOLLECTABLE"], function(content, contentWidth)
        local rowY = PlaceCardSectionDesc(content, L["TIPS_COLLECTIONS_SHOW_NONCOLLECTABLE_DESC"], 0, contentWidth)
        local colSettings = Registry:GetFeatureSettings("tooltips", "collections")
        local _, rowRefresh, refs
        rowY, rowRefresh, refs = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = rowY,
            contentWidth = contentWidth,
            label = L["TIPS_COLLECTIONS_SHOW_NONCOLLECTABLE"],
            value = colSettings.showNonCollectable == true,
            isEnabled = isEnabled,
            onLabel = L["TIPS_TOGGLE_ON"],
            offLabel = L["TIPS_TOGGLE_OFF"],
            buttonWidth = 50,
            onValueChange = function(newVal)
                Registry:SetSetting("tooltips", "collections", "showNonCollectable", newVal == true)
            end,
        })
        tinsert(toggleBtnSets, { label = refs.label, refresh = rowRefresh })
        return math.max(1, math.abs(rowY))
    end)

    stack:AddCard("tips:col:recipe_alt", L["TIPS_COLLECTIONS_RECIPE_ALT_DISPLAY"], function(content, contentWidth)
        local rowY = PlaceCardSectionDesc(content, L["TIPS_COLLECTIONS_RECIPE_ALT_DISPLAY_DESC"], 0, contentWidth)

        local DISPLAY_MODE_KEYS = {
            differentiated = "TIPS_COLLECTIONS_RECIPE_ALT_DIFFERENTIATED",
            combined = "TIPS_COLLECTIONS_RECIPE_ALT_COMBINED",
            self_only = "TIPS_COLLECTIONS_RECIPE_ALT_SELF_ONLY",
        }

        local currentMode = Registry:GetFeatureSettings("tooltips", "collections").recipeAltDisplay or "differentiated"
        local currentKey = DISPLAY_MODE_KEYS[currentMode] or DISPLAY_MODE_KEYS.differentiated

        local dropdown, dropdownText = OneWoW_GUI:CreateDropdown(content, {
            width = 220,
            height = 26,
            text = L[currentKey],
        })
        dropdown:SetPoint("TOPLEFT", content, "TOPLEFT", 12, rowY)
        rowY = rowY - 34

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

        return math.max(1, math.abs(rowY))
    end)

    finish()
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

    local stack, finish = BeginDetailCardStack(split, dsc, yOffset)

    stack:AddCard("tips:rk:scope", L["TIPS_SCOPE_HEADER"], function(content, contentWidth)
        local rowY = ns.UI.BuildAltScopeSection(content, {
            yOffset = 0,
            x = 0,
            omitHeader = true,
            contentWidth = contentWidth,
            getScope = function()
                local s = Registry:GetFeatureSettings("tooltips", "recipeknowledge").altScope
                if type(s) ~= "table" then s = { mode = "all", chars = {}, roles = {} } end
                return s
            end,
            saveScope = function(s)
                Registry:SetSetting("tooltips", "recipeknowledge", "altScope", s)
            end,
        })
        return math.max(1, math.abs(rowY))
    end)

    finish()
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
        split.featureRows = {}
        local rowToSelect = nil
        local yOffset = -5
        local filter = (filterText or ""):lower()
        local preferredId = selectedFeatureId
        if ns.UI._pendingTooltipFeatureId then
            preferredId = ns.UI._pendingTooltipFeatureId
            selectedFeatureId = preferredId
            ns.UI._pendingTooltipFeatureId = nil
        end

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
                split.featureRows[capturedFeature.id] = row
                if capturedFeature.id == preferredId then
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

--- Jump to QoL → Tooltips and select a feature row (e.g. playermounts).
function ns.UI.SelectTooltipFeature(featureId)
    if not featureId then return end

    ns.UI._pendingTooltipFeatureId = featureId
    OneWoW.UI:Show("qol")
    OneWoW.UI:SelectSubTab("qol", "tooltips")

    local attempts = 0
    local function trySelect()
        attempts = attempts + 1
        local split = ns.UI._tooltipsSplit
        if not split then
            if attempts < 20 then C_Timer.After(0.05, trySelect) end
            return
        end
        if split.featureRows and split.featureRows[featureId] then
            split.featureRows[featureId]:Click()
        elseif split.RefreshList then
            split.RefreshList()
            if split.featureRows and split.featureRows[featureId] then
                split.featureRows[featureId]:Click()
            elseif attempts < 20 then
                C_Timer.After(0.05, trySelect)
            end
        elseif attempts < 20 then
            C_Timer.After(0.05, trySelect)
        end
    end
    C_Timer.After(0.05, trySelect)
end

function ns.UI.CreateTooltipsTab(parent)
    local split = OneWoW_GUI:CreateSplitPanel(parent, {
        showSearch = true,
        searchPlaceholder = L["SEARCH_HINT"],
        hideTitles = true,
    })
    ns.UI._tooltipsSplit = split

    C_Timer.After(0.1, function()
        BuildFeatureList(split, "tooltips")
        OneWoW_GUI:ApplyFontToFrame(parent)
    end)

    -- nil until the deferred BuildFeatureList above has run once.
    parent.Activate = function()
        if split.RefreshList then split.RefreshList() end
    end
end
