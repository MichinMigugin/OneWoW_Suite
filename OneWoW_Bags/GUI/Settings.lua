local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local ipairs, pairs = ipairs, pairs
local tinsert = tinsert
local abs, floor = math.abs, math.floor
local strgsub = string.gsub

local C_Timer = C_Timer

local L = OneWoW_Bags.L

OneWoW_Bags.Settings = {}
local Settings = OneWoW_Bags.Settings
local settingsFrame = nil
local isCreated = false
local savedSearchRows = {}
local savedSearchListContent = nil
local savedSearchEmptyText = nil
local COMPACT_GAP_STEPS = { 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.5, 2, 2.5, 3 }

local function GetDB()
    return OneWoW_Bags:GetDB()
end

local function ApplySetting(settingKey, value)
    if OneWoW_Bags.SettingsController then
        OneWoW_Bags.SettingsController:Apply(settingKey, value)
    end
end

local function CompactGapToIndex(val)
    for i, v in ipairs(COMPACT_GAP_STEPS) do
        if abs(v - val) < 0.01 then return i end
    end
    return 10
end

local function CompactGapFromIndex(idx)
    return COMPACT_GAP_STEPS[idx] or 1
end

local SETTINGS_SECTION_KEYS = { "TAB_GENERAL", "TAB_BAGS", "TAB_PERSONAL_BANK", "TAB_WARBAND_BANK", "TAB_GUILD_BANK" }
local activeSettingsSection = 1
local settingsSectionDropdownText = nil

local tabContents = {}

local function SyncTabScrollWidths()
    for _, sf in ipairs(tabContents) do
        local scrollFrame = sf.scrollFrame
        local scrollContent = sf.scrollContent
        if scrollFrame and scrollContent then
            local w = scrollFrame:GetWidth()
            if w and w > 0 then
                scrollContent:SetWidth(w)
                scrollFrame:UpdateScrollChildRect()
            end
        end
    end
end

local function ReflowWrappedFontStrings(frame)
    if not frame then return end
    local regions = { frame:GetRegions() }
    for ri = 1, #regions do
        local r = regions[ri]
        if r:IsObjectType("FontString") and r.GetWordWrap and r:GetWordWrap() then
            local txt = r:GetText()
            if txt and txt ~= "" then
                r:SetText(txt)
            end
        end
    end
    local children = { frame:GetChildren() }
    for ci = 1, #children do
        ReflowWrappedFontStrings(children[ci])
    end
end

local function NudgeVerticalScroll(scrollFrame)
    if not scrollFrame or not scrollFrame.GetVerticalScrollRange then return end
    local maxScroll = scrollFrame:GetVerticalScrollRange()
    if not maxScroll or maxScroll <= 0 then return end
    local v = scrollFrame:GetVerticalScroll()
    local bump = (v < maxScroll) and 1 or -1
    scrollFrame:SetVerticalScroll(v + bump)
    scrollFrame:SetVerticalScroll(v)
end

local function RefreshSettingsScrollLayouts()
    SyncTabScrollWidths()
    for _, sf in ipairs(tabContents) do
        if sf.scrollContent then
            ReflowWrappedFontStrings(sf.scrollContent)
        end
        if sf.scrollFrame then
            NudgeVerticalScroll(sf.scrollFrame)
        end
    end
end

local function SwitchTab(n)
    for i, content in ipairs(tabContents) do
        content:SetShown(i == n)
    end
    activeSettingsSection = n
    if settingsSectionDropdownText then
        settingsSectionDropdownText:SetText(L[SETTINGS_SECTION_KEYS[n]])
    end
    RefreshSettingsScrollLayouts()
    C_Timer.After(0, RefreshSettingsScrollLayouts)
end

local function BuildContainer(parent, yOffset)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    container:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    container:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    container:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    container:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    return container
end

local function FinalizeContainer(container, innerY, yOffset)
    container:SetHeight(abs(innerY) + 4)
    return yOffset - abs(innerY) - 4 - 15
end

local function BuildSliderRow(container, label, yOffset, options)
    local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 15, yOffset)
    lbl:SetText(label)
    lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - lbl:GetStringHeight() - 4

    if options.description then
        local desc = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", container, "TOPLEFT", 15, yOffset)
        desc:SetPoint("RIGHT", container, "RIGHT", -15, 0)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetText(options.description)
        desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        yOffset = yOffset - desc:GetStringHeight() - 6
    end

    local slider = OneWoW_GUI:CreateSlider(container, options)
    slider:SetPoint("TOPLEFT", container, "TOPLEFT", 15, yOffset)
    yOffset = yOffset - 40

    return yOffset, slider, lbl
end

local function ApplySingleLineText(fontString)
    fontString:SetWordWrap(false)
    if fontString.SetNonSpaceWrap then
        fontString:SetNonSpaceWrap(false)
    end
    if fontString.SetMaxLines then
        fontString:SetMaxLines(1)
    end
end

local function SingleLinePreview(text)
    return strgsub(text or "", "[\r\n]+", " ")
end

local function ShowSavedSearchPredicate(name, query)
    local LibCopyPaste = LibStub and LibStub("LibCopyPaste-1.0", true)
    if not LibCopyPaste then return end

    local title = L["SAVED_SEARCH_COPY_TITLE"]
    if name and name ~= "" then
        title = title .. ": " .. name
    end
    LibCopyPaste:Copy(title, query or "", { readOnly = true, frameStrata = "FULLSCREEN_DIALOG" })
end

local function SetMainSearchText(text)
    local infoBar = OneWoW_Bags.InfoBar
    local frame = infoBar and infoBar.GetFrame and infoBar:GetFrame()
    local searchBox = frame and frame.searchBox
    if not searchBox then return end

    searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    searchBox:SetText(text)
    searchBox:SetFocus()
end

local function RegisterSavedSearchSettingsPopups()
    if StaticPopupDialogs["ONEWOW_BAGS_RENAME_SAVED_SEARCH"] then return end

    StaticPopupDialogs["ONEWOW_BAGS_RENAME_SAVED_SEARCH"] = {
        text = L["SAVED_SEARCH_RENAME_PROMPT"],
        hasEditBox = true,
        button1 = L["POPUP_RENAME"],
        button2 = L["POPUP_CANCEL"],
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(self, oldName)
            local SS = OneWoW_Bags.SavedSearches
            if not SS or not oldName then return end

            local newName = self.EditBox:GetText()
            local ok, err = SS:Rename(oldName, newName)
            if not ok and err and L[err] then
                print(L[err])
                C_Timer.After(0, function()
                    local reopened = StaticPopup_Show("ONEWOW_BAGS_RENAME_SAVED_SEARCH", nil, nil, oldName)
                    if reopened and reopened.EditBox then
                        reopened.EditBox:SetText(newName or "")
                        reopened.EditBox:SetFocus()
                    end
                end)
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            StaticPopupDialogs["ONEWOW_BAGS_RENAME_SAVED_SEARCH"].OnAccept(parent, parent.data)
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
    }

    StaticPopupDialogs["ONEWOW_BAGS_DELETE_SAVED_SEARCH"] = {
        text = L["SAVED_SEARCH_DELETE_CONFIRM"],
        button1 = L["POPUP_DELETE"],
        button2 = L["POPUP_CANCEL"],
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(_, name)
            if OneWoW_Bags.SavedSearches and name then
                OneWoW_Bags.SavedSearches:Delete(name)
            end
        end,
    }
end

function Settings:RefreshSavedSearchRows()
    if not savedSearchListContent then return end

    local SS = OneWoW_Bags.SavedSearches
    if not SS then return end

    local names = SS:GetSortedNames()
    local rowHeight = 38

    if savedSearchEmptyText then
        savedSearchEmptyText:SetShown(#names == 0)
    end

    for i, name in ipairs(names) do
        local row = savedSearchRows[i]
        if not row then
            row = CreateFrame("Button", nil, savedSearchListContent, "BackdropTemplate")
            row:SetHeight(rowHeight)
            row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)

            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -5)
            row.nameText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.nameText:SetJustifyH("LEFT")
            row.nameText:SetHeight(14)
            ApplySingleLineText(row.nameText)

            row.queryText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.queryText:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -2)
            row.queryText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.queryText:SetJustifyH("LEFT")
            row.queryText:SetHeight(14)
            ApplySingleLineText(row.queryText)

            row:SetScript("OnEnter", function(myself)
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            end)
            row:SetScript("OnLeave", function(myself)
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end)
            row:SetScript("OnMouseDown", function(myself, button)
                if button ~= "RightButton" then return end
                local rowName = myself.savedSearchName
                local rowQuery = myself.savedSearchQuery
                MenuUtil.CreateContextMenu(myself, function(_, rootDescription)
                    rootDescription:CreateButton(L["SAVED_SEARCH_MENU_USE"], function()
                        SetMainSearchText("SAVED(" .. rowName .. ")")
                    end)
                    rootDescription:CreateButton(L["SAVED_SEARCH_MENU_SHOW"], function()
                        ShowSavedSearchPredicate(rowName, rowQuery)
                    end)
                    rootDescription:CreateButton(L["SAVED_SEARCH_MENU_RENAME"], function()
                        local popup = StaticPopup_Show("ONEWOW_BAGS_RENAME_SAVED_SEARCH", nil, nil, rowName)
                        if popup and popup.EditBox then
                            popup.EditBox:SetText(rowName)
                            popup.EditBox:SetFocus()
                        end
                    end)
                    rootDescription:CreateButton(L["SAVED_SEARCH_MENU_DELETE"], function()
                        StaticPopup_Show("ONEWOW_BAGS_DELETE_SAVED_SEARCH", rowName, nil, rowName)
                    end)
                end)
            end)

            savedSearchRows[i] = row
        end

        local query = SS:Get(name) or ""
        row.savedSearchName = name
        row.savedSearchQuery = query
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", savedSearchListContent, "TOPLEFT", 0, -((i - 1) * rowHeight))
        row:SetPoint("TOPRIGHT", savedSearchListContent, "TOPRIGHT", 0, -((i - 1) * rowHeight))
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        row.nameText:SetText(SingleLinePreview(name))
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        row.queryText:SetText(SingleLinePreview(query))
        row.queryText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row:Show()
    end

    for i = #names + 1, #savedSearchRows do
        savedSearchRows[i]:Hide()
    end

    savedSearchListContent:SetHeight(math.max(1, #names * rowHeight))
    RefreshSettingsScrollLayouts()
end

local function BuildSavedSearchList(container, yOffset)
    RegisterSavedSearchSettingsPopups()

    local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 15, yOffset)
    lbl:SetText(L["SECTION_SAVED_SEARCHES"])
    lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - lbl:GetStringHeight() - 6

    local listFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 15, yOffset)
    listFrame:SetPoint("TOPRIGHT", container, "TOPRIGHT", -15, yOffset)
    listFrame:SetHeight(170)
    listFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    listFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    listFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(listFrame, {})
    savedSearchListContent = scrollContent

    savedSearchEmptyText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    savedSearchEmptyText:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 8, -8)
    savedSearchEmptyText:SetText(L["SAVED_SEARCHES_EMPTY"])
    savedSearchEmptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    scrollFrame:HookScript("OnShow", function()
        Settings:RefreshSavedSearchRows()
    end)

    Settings:RefreshSavedSearchRows()

    return yOffset - 176
end

local function BuildSearchSettingsSection(sc, db, yOffset)
    yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SECTION_SEARCH"], yOffset = yOffset })
    local searchContainer = BuildContainer(sc, yOffset)
    local searchY = -10

    searchY = BuildSliderRow(searchContainer, L["SETTING_SEARCH_HISTORY_LIMIT"], searchY, {
        description = L["DESC_SEARCH_HISTORY_LIMIT"],
        minVal = 0, maxVal = 10, step = 1, currentVal = db.global.searchHistoryLimit,
        onChange = function(val)
            ApplySetting("searchHistoryLimit", val)
        end,
        width = 240, fmt = "%d",
    })

    searchY = searchY - 6
    searchY = BuildSavedSearchList(searchContainer, searchY)

    return FinalizeContainer(searchContainer, searchY, yOffset)
end

local function BuildGeneralTab(sc, db)
    local yOffset = OneWoW_GUI:CreateSettingsPanel(sc, { yOffset = -15, addonName = "OneWoW_Bags" })
    yOffset = yOffset - 10

    yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SETTING_ICON_SIZE"], yOffset = yOffset })
    local sizeContainer = BuildContainer(sc, yOffset)
    local sizeY = -12
    local sizeItems = {
        { text = L["ICON_SIZE_S"],  value = 1, isActive = (db.global.iconSize == 1) },
        { text = L["ICON_SIZE_M"],  value = 2, isActive = (db.global.iconSize == 2) },
        { text = L["ICON_SIZE_L"],  value = 3, isActive = (db.global.iconSize == 3) },
        { text = L["ICON_SIZE_XL"], value = 4, isActive = (db.global.iconSize == 4) },
    }
    local sizeBtns, sizeFinalY = OneWoW_GUI:CreateFitFrameButtons(sizeContainer, {
        yOffset = sizeY,
        items = sizeItems,
        height = 24, gap = 8, marginX = 15, width = 510,
        onSelect = function(value)
            ApplySetting("iconSize", value)
        end,
    })
    Settings.sizeBtns = sizeBtns
    sizeY = sizeFinalY - 8
    yOffset = FinalizeContainer(sizeContainer, sizeY, yOffset)

    yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SETTING_ITEM_SORT"], yOffset = yOffset })
    local sortContainer = BuildContainer(sc, yOffset)
    local sortY = -12
    local itemSortItems = {
        { text = L["SORT_OFF"],        value = "none",    isActive = (db.global.itemSort == "none") },
        { text = L["SORT_DEFAULT"],    value = "default", isActive = (db.global.itemSort == "default") },
        { text = L["SORT_NAME"],       value = "name",    isActive = (db.global.itemSort == "name") },
        { text = L["SORT_RARITY"],     value = "rarity",  isActive = (db.global.itemSort == "rarity") },
        { text = L["SORT_ITEM_LEVEL"], value = "ilvl",    isActive = (db.global.itemSort == "ilvl") },
        { text = L["SORT_TYPE"],       value = "type",    isActive = (db.global.itemSort == "type") },
    }
    local itemSortBtns, itemSortFinalY = OneWoW_GUI:CreateFitFrameButtons(sortContainer, {
        yOffset = sortY,
        items = itemSortItems,
        height = 24, gap = 8, marginX = 15, width = 510,
        onSelect = function(value)
            ApplySetting("itemSort", value)
        end,
    })
    Settings.itemSortBtns = itemSortBtns
    sortY = itemSortFinalY - 8
    yOffset = FinalizeContainer(sortContainer, sortY, yOffset)

    if OneWoW then
        yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SECTION_INTEGRATION"], yOffset = yOffset })
        local intContainer = BuildContainer(sc, yOffset)
        local intY = -10

        intY, _, _ = OneWoW_GUI:CreateToggleRow(intContainer, {
            yOffset = intY,
            label = L["SETTING_ENABLE_JUNK_CAT"],
            description = L["DESC_ENABLE_JUNK_CAT"],
            isEnabled = true,
            value = db.global.enableJunkCategory,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("enableJunkCategory", newVal)
            end,
        })

        intY, _, _ = OneWoW_GUI:CreateToggleRow(intContainer, {
            yOffset = intY,
            label = L["SETTING_ENABLE_UPGRADE_CAT"],
            description = L["DESC_ENABLE_UPGRADE_CAT"],
            isEnabled = true,
            value = db.global.enableUpgradeCategory,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("enableUpgradeCategory", newVal)
            end,
        })

        intY, _, _ = OneWoW_GUI:CreateToggleRow(intContainer, {
            yOffset = intY,
            label = L["SETTING_SHOW_KEYWORDS_TOOLTIP"],
            description = L["DESC_SHOW_KEYWORDS_TOOLTIP"],
            isEnabled = true,
            value = db.global.showKeywordsInTooltips,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("showKeywordsInTooltips", newVal)
            end,
        })

        yOffset = FinalizeContainer(intContainer, intY, yOffset)
    end

    if OneWoW_Bags.Masque and OneWoW_Bags.Masque.available then
        yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SECTION_MASQUE"], yOffset = yOffset })
        local masqueContainer = BuildContainer(sc, yOffset)
        local masqueY = -10

        masqueY, _, _ = OneWoW_GUI:CreateToggleRow(masqueContainer, {
            yOffset = masqueY,
            label = L["SETTING_USE_MASQUE"],
            description = L["DESC_USE_MASQUE"],
            isEnabled = true,
            value = db.global.useMasque ~= false,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("useMasque", newVal)
            end,
        })

        yOffset = FinalizeContainer(masqueContainer, masqueY, yOffset)
    end

    yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SECTION_CAT_PLACEMENT"], yOffset = yOffset })
    local placeContainer = BuildContainer(sc, yOffset)
    local placeY = -10

    placeY, _, _ = OneWoW_GUI:CreateToggleRow(placeContainer, {
        yOffset = placeY,
        label = L["SETTING_MOVE_UPGRADES_TOP"],
        description = L["DESC_MOVE_UPGRADES_TOP"],
        isEnabled = true,
        value = db.global.moveRecentToTop,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("moveRecentToTop", newVal)
        end,
    })

    placeY, _, _ = OneWoW_GUI:CreateToggleRow(placeContainer, {
        yOffset = placeY,
        label = L["SETTING_MOVE_OTHER_BOTTOM"],
        description = L["DESC_MOVE_OTHER_BOTTOM"],
        isEnabled = true,
        value = db.global.moveOtherToBottom,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("moveOtherToBottom", newVal)
        end,
    })

    placeY, _, _ = OneWoW_GUI:CreateToggleRow(placeContainer, {
        yOffset = placeY,
        label = L["SETTING_PINNED_CATEGORY_SHOWS_WHEN_DISABLED"],
        description = L["DESC_PINNED_CATEGORY_SHOWS_WHEN_DISABLED"],
        isEnabled = true,
        value = db.global.pinnedCategoryShowsWhenDisabled,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("pinnedCategoryShowsWhenDisabled", newVal)
        end,
    })

    placeY = BuildSliderRow(placeContainer, L["SETTING_RECENT_DURATION"], placeY, {
        minVal = 15, maxVal = 600, step = 15, currentVal = db.global.recentItemDuration,
        onChange = function(val)
            ApplySetting("recentItemDuration", val)
        end,
        width = 240, fmt = "%d",
    })

    yOffset = FinalizeContainer(placeContainer, placeY, yOffset)

    yOffset = BuildSearchSettingsSection(sc, db, yOffset)

    sc:SetHeight(abs(yOffset) + 40)
end

local function BuildBagsTab(sc, db)
    local yOffset = -15

    yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SECTION_DISPLAY"], yOffset = yOffset })
    local dispContainer = BuildContainer(sc, yOffset)
    local dispY = -10

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_RARITY_COLOR"],
        description = L["DESC_RARITY_COLOR"],
        isEnabled = true,
        value = db.global.rarityColor,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("rarityColor", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_NEW"],
        description = L["DESC_SHOW_NEW"],
        isEnabled = true,
        value = db.global.showNewItems,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showNewItems", newVal)
        end,
    })

    if OneWoW then
        local overlayEnabled = false
        if OneWoW.SettingsFeatureRegistry then
            overlayEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", "general")
        end
        dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
            yOffset = dispY,
            label = L["OVERLAY_SECTION"],
            description = L["DESC_OVERLAY"],
            isEnabled = true,
            value = overlayEnabled,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("overlaysEnabled", newVal)
            end,
        })
    end

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_SCROLLBAR"],
        description = L["DESC_SHOW_SCROLLBAR"],
        isEnabled = true,
        value = not db.global.hideScrollBar,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showScrollBar", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_BAGS_BAR"],
        description = L["DESC_SHOW_BAGS_BAR"],
        isEnabled = true,
        value = db.global.showBagsBar,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showBagsBar", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_MONEY_BAR"],
        description = L["DESC_SHOW_MONEY_BAR"],
        isEnabled = true,
        value = db.global.showMoneyBar,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showMoneyBar", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_TRACKER_CAP_HIGHLIGHT"],
        description = L["DESC_TRACKER_CAP_HIGHLIGHT"],
        isEnabled = true,
        value = db.global.showCurrencyTrackerCapHighlight,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showCurrencyTrackerCapHighlight", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_HEADER_BAR"],
        description = L["DESC_SHOW_HEADER_BAR"],
        isEnabled = true,
        value = db.global.showHeaderBar,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showHeaderBar", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_SEARCH_BAR"],
        description = L["DESC_SHOW_SEARCH_BAR"],
        isEnabled = true,
        value = db.global.showSearchBar,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showSearchBar", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_ENABLE_EXPAC_FILTER"],
        description = L["DESC_ENABLE_EXPAC_FILTER"],
        isEnabled = true,
        value = db.global.enableExpansionFilter,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("enableExpansionFilter", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_CAT_HEADERS"],
        description = L["DESC_SHOW_CAT_HEADERS"],
        isEnabled = true,
        value = db.global.showCategoryHeaders,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showCategoryHeaders", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_EMPTY_SLOTS"],
        description = L["DESC_SHOW_EMPTY_SLOTS"],
        isEnabled = true,
        value = db.global.showEmptySlots,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showEmptySlots", newVal)
        end,
    })

    dispY = dispY - 6

    dispY = BuildSliderRow(dispContainer, L["SETTING_BAG_COLUMNS"], dispY, {
        minVal = 10, maxVal = 30, step = 1, currentVal = db.global.bagColumns,
        onChange = function(val)
            ApplySetting("bagColumns", val)
        end,
        width = 240, fmt = "%d",
    })

    dispY = BuildSliderRow(dispContainer, L["SETTING_CATEGORY_SPACING"], dispY, {
        minVal = 0.1, maxVal = 2.0, step = 0.1, currentVal = db.global.categorySpacing,
        onChange = function(val)
            ApplySetting("categorySpacing", val)
        end,
        width = 240, fmt = "%.1f",
    })

    yOffset = FinalizeContainer(dispContainer, dispY, yOffset)

    yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SECTION_CATEGORIES"], yOffset = yOffset })
    local catContainer = BuildContainer(sc, yOffset)
    local catY = -10

    catY, _, _ = OneWoW_GUI:CreateToggleRow(catContainer, {
        yOffset = catY,
        label = L["SETTING_INVENTORY_SLOTS"],
        description = L["DESC_INVENTORY_SLOTS"],
        isEnabled = true,
        value = db.global.enableInventorySlots,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("enableInventorySlots", newVal)
        end,
    })

    catY, _, _ = OneWoW_GUI:CreateToggleRow(catContainer, {
        yOffset = catY,
        label = L["SETTING_STACK_ITEMS"],
        description = L["DESC_STACK_ITEMS"],
        isEnabled = true,
        value = db.global.stackItems,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("stackItems", newVal)
        end,
    })

    catY, _, _ = OneWoW_GUI:CreateToggleRow(catContainer, {
        yOffset = catY,
        label = L["SETTING_COMPACT_CATEGORIES"],
        description = L["DESC_COMPACT_CATEGORIES"],
        isEnabled = true,
        value = db.global.compactCategories,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("compactCategories", newVal)
        end,
    })

    do
        local gapLbl = catContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        gapLbl:SetPoint("TOPLEFT", catContainer, "TOPLEFT", 15, catY)
        gapLbl:SetText(L["SETTING_COMPACT_GAP"])
        gapLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        catY = catY - gapLbl:GetStringHeight() - 4

        local curIdx = CompactGapToIndex(db.global.compactGap)
        local gapSlider = OneWoW_GUI:CreateSlider(catContainer, {
            minVal = 1, maxVal = #COMPACT_GAP_STEPS, step = 1, currentVal = curIdx,
            onChange = function(val)
                local idx = floor(val + 0.5)
                local realVal = CompactGapFromIndex(idx)
                ApplySetting("compactGap", realVal)
            end,
            width = 240, fmt = "%d",
        })
        gapSlider:SetPoint("TOPLEFT", catContainer, "TOPLEFT", 15, catY)

        local slider = gapSlider:GetChildren()
        if slider then
            slider:HookScript("OnValueChanged", function(_, val)
                local idx = floor(val + 0.5)
                local realVal = CompactGapFromIndex(idx)
                for _, region in pairs({gapSlider:GetRegions()}) do
                    if region:IsObjectType("FontString") and region:GetText() then
                        region:SetText(string.format("%.1f", realVal))
                        break
                    end
                end
            end)
            local idx = floor(curIdx + 0.5)
            C_Timer.After(0, function()
                for _, region in pairs({gapSlider:GetRegions()}) do
                    if region:IsObjectType("FontString") and region:GetText() then
                        region:SetText(string.format("%.1f", CompactGapFromIndex(idx)))
                        break
                    end
                end
            end)
        end
        catY = catY - 40
    end

    yOffset = FinalizeContainer(catContainer, catY, yOffset)

    yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SECTION_ITEM_DISPLAY"], yOffset = yOffset })
    local itemDispContainer = BuildContainer(sc, yOffset)
    local itemDispY = -10

    itemDispY, _, _ = OneWoW_GUI:CreateToggleRow(itemDispContainer, {
        yOffset = itemDispY,
        label = L["SETTING_UNUSABLE_OVERLAY"],
        description = L["DESC_UNUSABLE_OVERLAY"],
        isEnabled = true,
        value = db.global.showUnusableOverlay,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showUnusableOverlay", newVal)
        end,
    })

    itemDispY, _, _ = OneWoW_GUI:CreateToggleRow(itemDispContainer, {
        yOffset = itemDispY,
        label = L["SETTING_DIM_JUNK"],
        description = L["DESC_DIM_JUNK"],
        isEnabled = true,
        value = db.global.dimJunkItems,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("dimJunkItems", newVal)
        end,
    })

    itemDispY, _, _ = OneWoW_GUI:CreateToggleRow(itemDispContainer, {
        yOffset = itemDispY,
        label = L["SETTING_STRIP_JUNK_OVERLAYS"],
        description = L["DESC_STRIP_JUNK_OVERLAYS"],
        isEnabled = true,
        value = db.global.stripJunkOverlays,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("stripJunkOverlays", newVal)
        end,
    })

    itemDispY, _, _ = OneWoW_GUI:CreateToggleRow(itemDispContainer, {
        yOffset = itemDispY,
        label = L["SETTING_ALT_TO_SHOW"],
        description = L["DESC_ALT_TO_SHOW"],
        isEnabled = true,
        value = db.global.altToShow,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal) ApplySetting("altToShow", newVal) end,
    })

    yOffset = FinalizeContainer(itemDispContainer, itemDispY, yOffset)

    yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SECTION_BEHAVIOR"], yOffset = yOffset })
    local behContainer = BuildContainer(sc, yOffset)
    local behY = -10

    behY, _, _ = OneWoW_GUI:CreateToggleRow(behContainer, {
        yOffset = behY,
        label = L["SETTING_AUTO_OPEN"],
        description = L["DESC_AUTO_OPEN"],
        isEnabled = true,
        value = db.global.autoOpen,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal) ApplySetting("autoOpen", newVal) end,
    })

    behY, _, _ = OneWoW_GUI:CreateToggleRow(behContainer, {
        yOffset = behY,
        label = L["SETTING_AUTO_CLOSE"],
        description = L["DESC_AUTO_CLOSE"],
        isEnabled = true,
        value = db.global.autoClose,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal) ApplySetting("autoClose", newVal) end,
    })

    behY, _, _ = OneWoW_GUI:CreateToggleRow(behContainer, {
        yOffset = behY,
        label = L["SETTING_AUTO_OPEN_WITH_BANK"],
        description = L["DESC_AUTO_OPEN_WITH_BANK"],
        isEnabled = true,
        value = db.global.autoOpenWithBank,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal) ApplySetting("autoOpenWithBank", newVal) end,
    })

    behY, _, _ = OneWoW_GUI:CreateToggleRow(behContainer, {
        yOffset = behY,
        label = L["SETTING_LOCK"],
        description = L["DESC_LOCK"],
        isEnabled = true,
        value = db.global.locked,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal) ApplySetting("locked", newVal) end,
    })

    yOffset = FinalizeContainer(behContainer, behY, yOffset)

    sc:SetHeight(abs(yOffset) + 40)
end

local MODE_KEYS = {
    personal = {
        sectionTitle = "SECTION_PERSONAL_BANK",
        db = {
            rarityColor       = "bankRarityColor",
            overlays          = "enableBankOverlays",
            hideScrollBar     = "bankHideScrollBar",
            showBagsBar       = "showBankBagsBar",
            showHeaderBar     = "showBankHeaderBar",
            showSearchBar     = "showBankSearchBar",
            expacFilter       = "enableBankExpansionFilter",
            showCatHeaders    = "showBankCategoryHeaders",
            columns           = "bankColumns",
            categorySpacing   = "bankCategorySpacing",
            compactCategories = "bankCompactCategories",
            compactGap        = "bankCompactGap",
            showEmptySlots    = "bankShowEmptySlots",
        },
        applier = {
            rarityColor       = "bankRarityColor",
            overlays          = "enableBankOverlays",
            showScrollBar     = "showBankScrollBar",
            showBagsBar       = "showBankBagsBar",
            showHeaderBar     = "showBankHeaderBar",
            showSearchBar     = "showBankSearchBar",
            expacFilter       = "enableBankExpansionFilter",
            showCatHeaders    = "showBankCategoryHeaders",
            columns           = "bankColumns",
            categorySpacing   = "bankCategorySpacing",
            compactCategories = "bankCompactCategories",
            compactGap        = "bankCompactGap",
            showEmptySlots    = "showBankEmptySlots",
        },
    },
    warband = {
        sectionTitle = ACCOUNT_BANK_PANEL_TITLE,
        db = {
            rarityColor       = "warbandBankRarityColor",
            overlays          = "enableWarbandBankOverlays",
            hideScrollBar     = "warbandBankHideScrollBar",
            showBagsBar       = "showWarbandBankBagsBar",
            showHeaderBar     = "showWarbandBankHeaderBar",
            showSearchBar     = "showWarbandBankSearchBar",
            expacFilter       = "enableWarbandBankExpansionFilter",
            showCatHeaders    = "showWarbandBankCategoryHeaders",
            columns           = "warbandBankColumns",
            categorySpacing   = "warbandBankCategorySpacing",
            compactCategories = "warbandBankCompactCategories",
            compactGap        = "warbandBankCompactGap",
            showEmptySlots    = "warbandBankShowEmptySlots",
        },
        applier = {
            rarityColor       = "warbandBankRarityColor",
            overlays          = "enableWarbandBankOverlays",
            showScrollBar     = "showWarbandBankScrollBar",
            showBagsBar       = "showWarbandBankBagsBar",
            showHeaderBar     = "showWarbandBankHeaderBar",
            showSearchBar     = "showWarbandBankSearchBar",
            expacFilter       = "enableWarbandBankExpansionFilter",
            showCatHeaders    = "showWarbandBankCategoryHeaders",
            columns           = "warbandBankColumns",
            categorySpacing   = "warbandBankCategorySpacing",
            compactCategories = "warbandBankCompactCategories",
            compactGap        = "warbandBankCompactGap",
            showEmptySlots    = "showWarbandBankEmptySlots",
        },
    },
}

local sharedEnableRefreshers = {}
local sharedLockRefreshers = {}
local sharedApplyEnabledFns = {}

local function BroadcastSharedEnable(newVal)
    for i = 1, #sharedEnableRefreshers do
        sharedEnableRefreshers[i](true, newVal)
    end
    for i = 1, #sharedApplyEnabledFns do
        sharedApplyEnabledFns[i](newVal)
    end
end

local function BroadcastSharedLock(newVal)
    local enabled = GetDB().global.enableBankUI and true or false
    for i = 1, #sharedLockRefreshers do
        sharedLockRefreshers[i](enabled, newVal)
    end
end

local function ResetSharedBankRefreshers()
    sharedEnableRefreshers = {}
    sharedLockRefreshers = {}
    sharedApplyEnabledFns = {}
end

local function BuildBankTabFor(mode, sc, db)
    local keys = MODE_KEYS[mode]
    local dbKeys = keys.db
    local applierKeys = keys.applier

    local yOffset = -15
    local dependents = {}

    local function addToggle(refresh, getValue)
        tinsert(dependents, function(enabled)
            refresh(enabled, getValue())
        end)
    end

    local function addSlider(sliderContainer, extraLabel)
        tinsert(dependents, function(enabled)
            local inner = sliderContainer:GetChildren()
            if inner then
                if enabled then inner:Enable() else inner:Disable() end
            end
            local r, g, b = OneWoW_GUI:GetThemeColor(enabled and "TEXT_PRIMARY" or "TEXT_MUTED")
            if extraLabel then
                extraLabel:SetTextColor(r, g, b)
            end
            for _, region in pairs({ sliderContainer:GetRegions() }) do
                if region:IsObjectType("FontString") then
                    region:SetTextColor(r, g, b)
                end
            end
        end)
    end

    local function applyEnabled(enabled)
        for i = 1, #dependents do
            dependents[i](enabled)
        end
    end
    tinsert(sharedApplyEnabledFns, applyEnabled)

    yOffset = OneWoW_GUI:CreateSection(sc, { title = L[keys.sectionTitle], yOffset = yOffset })
    local bankTopContainer = BuildContainer(sc, yOffset)
    local topY = -10

    local enableRefresh
    topY, enableRefresh = OneWoW_GUI:CreateToggleRow(bankTopContainer, {
        yOffset = topY,
        label = L["SETTING_ENABLE_BANK"],
        description = L["DESC_ENABLE_BANK"],
        isEnabled = true,
        value = db.global.enableBankUI,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("enableBankUI", newVal)
            BroadcastSharedEnable(newVal)
        end,
    })
    tinsert(sharedEnableRefreshers, enableRefresh)

    local lockRefresh
    topY, lockRefresh = OneWoW_GUI:CreateToggleRow(bankTopContainer, {
        yOffset = topY,
        label = L["SETTING_BANK_LOCK"],
        description = L["DESC_BANK_LOCK"],
        isEnabled = true,
        value = db.global.bankLocked,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("bankLocked", newVal)
            BroadcastSharedLock(newVal)
        end,
    })
    tinsert(sharedLockRefreshers, lockRefresh)
    addToggle(lockRefresh, function() return db.global.bankLocked end)

    yOffset = FinalizeContainer(bankTopContainer, topY, yOffset)

    yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SECTION_DISPLAY"], yOffset = yOffset })
    local dispContainer = BuildContainer(sc, yOffset)
    local dispY = -10

    local rarityRefresh
    dispY, rarityRefresh = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_RARITY_COLOR"],
        description = L["DESC_BANK_RARITY_COLOR"],
        isEnabled = true,
        value = db.global[dbKeys.rarityColor],
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting(applierKeys.rarityColor, newVal)
        end,
    })
    addToggle(rarityRefresh, function() return db.global[dbKeys.rarityColor] end)

    local overlaysRefresh
    dispY, overlaysRefresh = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_BANK_OVERLAYS"],
        description = L["DESC_BANK_OVERLAYS"],
        isEnabled = true,
        value = db.global[dbKeys.overlays],
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting(applierKeys.overlays, newVal)
        end,
    })
    addToggle(overlaysRefresh, function() return db.global[dbKeys.overlays] end)

    local scrollbarRefresh
    dispY, scrollbarRefresh = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_SCROLLBAR"],
        description = L["DESC_SHOW_BANK_SCROLLBAR"],
        isEnabled = true,
        value = not db.global[dbKeys.hideScrollBar],
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting(applierKeys.showScrollBar, newVal)
        end,
    })
    addToggle(scrollbarRefresh, function() return not db.global[dbKeys.hideScrollBar] end)

    local bagsBarRefresh
    dispY, bagsBarRefresh = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_BANK_BAGS_BAR"],
        description = L["DESC_SHOW_BANK_BAGS_BAR"],
        isEnabled = true,
        value = db.global[dbKeys.showBagsBar],
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting(applierKeys.showBagsBar, newVal)
        end,
    })
    addToggle(bagsBarRefresh, function() return db.global[dbKeys.showBagsBar] end)

    local headerBarRefresh
    dispY, headerBarRefresh = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_HEADER_BAR"],
        description = L["DESC_SHOW_BANK_HEADER_BAR"],
        isEnabled = true,
        value = db.global[dbKeys.showHeaderBar],
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting(applierKeys.showHeaderBar, newVal)
        end,
    })
    addToggle(headerBarRefresh, function() return db.global[dbKeys.showHeaderBar] end)

    local searchBarRefresh
    dispY, searchBarRefresh = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_SEARCH_BAR"],
        description = L["DESC_SHOW_BANK_SEARCH_BAR"],
        isEnabled = true,
        value = db.global[dbKeys.showSearchBar],
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting(applierKeys.showSearchBar, newVal)
        end,
    })
    addToggle(searchBarRefresh, function() return db.global[dbKeys.showSearchBar] end)

    local expacFilterRefresh
    dispY, expacFilterRefresh = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_ENABLE_EXPAC_FILTER"],
        description = L["DESC_ENABLE_BANK_EXPAC_FILTER"],
        isEnabled = true,
        value = db.global[dbKeys.expacFilter],
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting(applierKeys.expacFilter, newVal)
        end,
    })
    addToggle(expacFilterRefresh, function() return db.global[dbKeys.expacFilter] end)

    local catHeadersRefresh
    dispY, catHeadersRefresh = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_CAT_HEADERS"],
        description = L["DESC_SHOW_BANK_CAT_HEADERS"],
        isEnabled = true,
        value = db.global[dbKeys.showCatHeaders],
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting(applierKeys.showCatHeaders, newVal)
        end,
    })
    addToggle(catHeadersRefresh, function() return db.global[dbKeys.showCatHeaders] end)

    local emptySlotsRefresh
    dispY, emptySlotsRefresh = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_EMPTY_SLOTS"],
        description = L["DESC_SHOW_EMPTY_SLOTS"],
        isEnabled = true,
        value = db.global[dbKeys.showEmptySlots],
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting(applierKeys.showEmptySlots, newVal)
        end,
    })
    addToggle(emptySlotsRefresh, function() return db.global[dbKeys.showEmptySlots] end)

    dispY = dispY - 6

    local colSliderContainer, colSliderLbl
    dispY, colSliderContainer, colSliderLbl = BuildSliderRow(dispContainer, L["SETTING_BANK_COLUMNS"], dispY, {
        minVal = 15, maxVal = 30, step = 1, currentVal = db.global[dbKeys.columns],
        onChange = function(val)
            ApplySetting(applierKeys.columns, val)
        end,
        width = 240, fmt = "%d",
    })
    addSlider(colSliderContainer, colSliderLbl)

    local spaceSliderContainer, spaceSliderLbl
    dispY, spaceSliderContainer, spaceSliderLbl = BuildSliderRow(dispContainer, L["SETTING_CATEGORY_SPACING"], dispY, {
        minVal = 0.1, maxVal = 2.0, step = 0.1, currentVal = db.global[dbKeys.categorySpacing],
        onChange = function(val)
            ApplySetting(applierKeys.categorySpacing, val)
        end,
        width = 240, fmt = "%.1f",
    })
    addSlider(spaceSliderContainer, spaceSliderLbl)

    local compactRefresh
    dispY, compactRefresh = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_COMPACT_CATEGORIES"],
        description = L["DESC_COMPACT_CATEGORIES"],
        isEnabled = true,
        value = db.global[dbKeys.compactCategories],
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting(applierKeys.compactCategories, newVal)
        end,
    })
    addToggle(compactRefresh, function() return db.global[dbKeys.compactCategories] end)

    do
        local gapLbl = dispContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        gapLbl:SetPoint("TOPLEFT", dispContainer, "TOPLEFT", 15, dispY)
        gapLbl:SetText(L["SETTING_COMPACT_GAP"])
        gapLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        dispY = dispY - gapLbl:GetStringHeight() - 4

        local curIdx = CompactGapToIndex(db.global[dbKeys.compactGap])
        local gapSlider = OneWoW_GUI:CreateSlider(dispContainer, {
            minVal = 1, maxVal = #COMPACT_GAP_STEPS, step = 1, currentVal = curIdx,
            onChange = function(val)
                local idx = floor(val + 0.5)
                local realVal = CompactGapFromIndex(idx)
                ApplySetting(applierKeys.compactGap, realVal)
            end,
            width = 240, fmt = "%d",
        })
        gapSlider:SetPoint("TOPLEFT", dispContainer, "TOPLEFT", 15, dispY)

        local slider = gapSlider:GetChildren()
        if slider then
            slider:HookScript("OnValueChanged", function(_, val)
                local idx = floor(val + 0.5)
                local realVal = CompactGapFromIndex(idx)
                for _, region in pairs({gapSlider:GetRegions()}) do
                    if region:IsObjectType("FontString") and region:GetText() then
                        region:SetText(string.format("%.1f", realVal))
                        break
                    end
                end
            end)
            C_Timer.After(0, function()
                for _, region in pairs({gapSlider:GetRegions()}) do
                    if region:IsObjectType("FontString") and region:GetText() then
                        region:SetText(string.format("%.1f", CompactGapFromIndex(curIdx)))
                        break
                    end
                end
            end)
        end
        addSlider(gapSlider, gapLbl)
        dispY = dispY - 40
    end

    yOffset = FinalizeContainer(dispContainer, dispY, yOffset)

    applyEnabled(db.global.enableBankUI)

    sc:SetHeight(abs(yOffset) + 40)
end

local function BuildGuildBankTab(sc, db)
    local yOffset = -15

    yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SECTION_GUILD_BANK"], yOffset = yOffset })
    local dispContainer = BuildContainer(sc, yOffset)
    local dispY = -10

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_EMPTY_SLOTS"],
        description = L["DESC_SHOW_EMPTY_SLOTS"],
        isEnabled = true,
        value = db.global.guildBankShowEmptySlots,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showGuildBankEmptySlots", newVal)
        end,
    })

    yOffset = FinalizeContainer(dispContainer, dispY, yOffset)

    sc:SetHeight(abs(yOffset) + 40)
end

function Settings:Create()
    if isCreated then return settingsFrame end

    local db = GetDB()

    local dialog = OneWoW_GUI:CreateDialog({
        name = "OneWoW_BagsSettingsWindow",
        title = L["SETTINGS_TITLE"],
        width = 560,
        height = 820,
        strata = "DIALOG",
        movable = true,
        escClose = true,
    })

    settingsFrame = dialog.frame
    local contentFrame = dialog.contentFrame

    local tabRow = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
    tabRow:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    tabRow:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, 0)
    tabRow:SetHeight(34)
    tabRow:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    tabRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    tabRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local sectionDropH = 22
    local sectionDropY = -floor((34 - sectionDropH) / 2)
    local sectionDropdown, sectionDropdownText = OneWoW_GUI:CreateDropdown(tabRow, {
        width = 200,
        height = sectionDropH,
        text = L["TAB_GENERAL"],
    })
    sectionDropdown:SetPoint("TOPLEFT", tabRow, "TOPLEFT", 6, sectionDropY)
    settingsSectionDropdownText = sectionDropdownText
    OneWoW_GUI:AttachFilterMenu(sectionDropdown, {
        searchable = false,
        buildItems = function()
            local items = {}
            for i = 1, #SETTINGS_SECTION_KEYS do
                local key = SETTINGS_SECTION_KEYS[i]
                tinsert(items, { text = L[key], value = i })
            end
            return items
        end,
        getActiveValue = function()
            return activeSettingsSection
        end,
        onSelect = function(value)
            SwitchTab(value)
        end,
    })

    ResetSharedBankRefreshers()

    for i = 1, #SETTINGS_SECTION_KEYS do
        local sf = CreateFrame("Frame", nil, contentFrame)
        sf:SetPoint("TOPLEFT", tabRow, "BOTTOMLEFT", 0, -2)
        sf:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
        local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(sf, {})
        sf.scrollFrame = scrollFrame
        sf.scrollContent = scrollContent
        tabContents[i] = sf
        scrollFrame:HookScript("OnSizeChanged", function(myself)
            local w = myself:GetWidth()
            if w and w > 0 then
                scrollContent:SetWidth(w)
                myself:UpdateScrollChildRect()
                ReflowWrappedFontStrings(scrollContent)
            end
        end)
        local tabPanel = sf
        tabPanel:HookScript("OnShow", function()
            C_Timer.After(0, function()
                if not tabPanel.scrollFrame or not tabPanel.scrollContent then return end
                local w = tabPanel.scrollFrame:GetWidth()
                if w and w > 0 then
                    tabPanel.scrollContent:SetWidth(w)
                    tabPanel.scrollFrame:UpdateScrollChildRect()
                    ReflowWrappedFontStrings(tabPanel.scrollContent)
                    NudgeVerticalScroll(tabPanel.scrollFrame)
                end
            end)
        end)
        sf:Hide()
    end

    BuildGeneralTab(tabContents[1].scrollContent, db)
    BuildBagsTab(tabContents[2].scrollContent, db)
    BuildBankTabFor("personal", tabContents[3].scrollContent, db)
    BuildBankTabFor("warband", tabContents[4].scrollContent, db)
    BuildGuildBankTab(tabContents[5].scrollContent, db)

    SwitchTab(1)

    if settingsFrame then
        settingsFrame:HookScript("OnShow", function()
            RefreshSettingsScrollLayouts()
            C_Timer.After(0, RefreshSettingsScrollLayouts)
        end)
    end

    isCreated = true
    return settingsFrame
end

function Settings:UpdateSizeButtons(btns)
    if not btns then btns = Settings.sizeBtns end
    if not btns then return end
    if btns.SetActiveByValue then
        local db = GetDB()
        btns.SetActiveByValue(db.global.iconSize)
    end
end

function Settings:UpdateItemSortButtons(btns)
    if not btns then btns = Settings.itemSortBtns end
    if not btns then return end
    if btns.SetActiveByValue then
        btns.SetActiveByValue(GetDB().global.itemSort)
    end
end

function Settings:Toggle()
    if not settingsFrame then self:Create() end
    if not settingsFrame then return end
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
    end
end

function Settings:Hide()
    if settingsFrame then settingsFrame:Hide() end
end

function Settings:IsShown()
    return settingsFrame and settingsFrame:IsShown()
end

function Settings:Reset()
    if settingsFrame then
        settingsFrame:Hide()
    end
    settingsFrame = nil
    isCreated = false
    tabContents = {}
    savedSearchRows = {}
    savedSearchListContent = nil
    savedSearchEmptyText = nil
    settingsSectionDropdownText = nil
    activeSettingsSection = 1
    ResetSharedBankRefreshers()
end
