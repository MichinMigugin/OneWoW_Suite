local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local ipairs, pairs = ipairs, pairs
local tinsert, wipe = tinsert, wipe
local abs, floor = math.abs, math.floor

local C_Timer = C_Timer

local L = ns.L
local WH = ns.WindowHelpers

ns.Settings = {}
local Settings = ns.Settings
local settingsFrame = nil
local isCreated = false
local COMPACT_GAP_STEPS = { 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.5, 2, 2.5, 3 }

local function GetDB()
    return ns:GetDB()
end

local function ApplySetting(settingKey, value)
    if ns.SettingsController then
        ns.SettingsController:Apply(settingKey, value)
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
local BroadcastSharedEnable

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

local function BuildSliderRow(container, label, yOffset, options)
    local padX = options.padX or 15
    local contentWidth = tonumber(options.contentWidth) or 0

    local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", container, "TOPLEFT", padX, yOffset)
    lbl:SetText(label)
    lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    if contentWidth > 40 then
        lbl:SetWidth(contentWidth - padX * 2)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(true)
    end
    yOffset = yOffset - lbl:GetStringHeight() - 4

    if options.description then
        local desc = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", container, "TOPLEFT", padX, yOffset)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        if contentWidth > 40 then
            desc:SetWidth(contentWidth - padX * 2)
        else
            desc:SetPoint("RIGHT", container, "RIGHT", -padX, 0)
        end
        desc:SetText(options.description)
        desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        yOffset = yOffset - desc:GetStringHeight() - 6
    end

    local sliderOpts = {}
    for k, v in pairs(options) do
        sliderOpts[k] = v
    end
    if contentWidth > 40 and not options.width then
        sliderOpts.width = math.max(140, contentWidth - padX * 2)
    end
    local slider = OneWoW_GUI:CreateSlider(container, sliderOpts)
    slider:SetPoint("TOPLEFT", container, "TOPLEFT", padX, yOffset)
    yOffset = yOffset - 40

    return yOffset, slider, lbl
end

local collapsedSettingsCards = {}

local function BeginSettingsCardStack(sc)
    local cardsHost = CreateFrame("Frame", nil, sc)
    cardsHost:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, -6)
    cardsHost:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, -6)

    local stack = OneWoW_GUI:CreateCardStack(cardsHost, {
        getCollapsed = function(key) return collapsedSettingsCards[key] end,
        setCollapsed = function(key, collapsed) collapsedSettingsCards[key] = collapsed end,
    })
    stack._host = cardsHost
    stack.OnRelayout = function()
        sc:SetHeight((cardsHost:GetHeight() or 0) + 20)
    end
    return stack
end

local function FinishSettingsCardStack(stack, sc)
    stack:Finish()
    sc:SetHeight((stack._host:GetHeight() or 0) + 20)
end

local function PlaceLabeledDropdown(content, y, labelText, dropdownWidth)
    local lbl = OneWoW_GUI:CreateFS(content, 12)
    lbl:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
    lbl:SetText(labelText)
    lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    y = y - 18

    local dd, ddText = OneWoW_GUI:CreateDropdown(content, {
        width = dropdownWidth,
        text = "",
    })
    dd:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
    return y - 34, dd, ddText
end

local function BuildCompactGapSlider(parent, y, contentWidth, currentGap, onChange)
    local padX = 12
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
    lbl:SetText(L["SETTING_COMPACT_GAP"])
    lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    y = y - lbl:GetStringHeight() - 4

    local curIdx = CompactGapToIndex(currentGap)
    local width = math.max(140, (contentWidth or 200) - padX * 2)
    local wrap = OneWoW_GUI:CreateSlider(parent, {
        width = width,
        minVal = 1,
        maxVal = #COMPACT_GAP_STEPS,
        step = 1,
        currentVal = curIdx,
        getLabel = function(pos) return string.format("%.1f", CompactGapFromIndex(pos)) end,
        getValue = function(pos) return CompactGapFromIndex(pos) end,
        onChange = function(value)
            onChange(value)
        end,
    })
    wrap:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, y)
    return y - 40, wrap, lbl
end

local function BuildGeneralTab(sc, db)
    local stack = BeginSettingsCardStack(sc)

    local ICON_SIZE_OPTIONS = {
        { value = 1, text = SMALL },
        { value = 2, text = L["ICON_SIZE_M"] },
        { value = 3, text = LARGE },
        { value = 4, text = L["ICON_SIZE_XL"] },
    }
    local function GetIconSizeLabel(val)
        for _, o in ipairs(ICON_SIZE_OPTIONS) do
            if o.value == val then return o.text end
        end
        return LARGE
    end

    local ITEM_SORT_OPTIONS = {
        { value = "none",    text = OFF },
        { value = "default", text = L["SORT_DEFAULT"] },
        { value = "name",    text = NAME },
        { value = "rarity",  text = RARITY },
        { value = "ilvl",    text = L["SORT_ITEM_LEVEL"] },
        { value = "type",    text = TYPE },
    }
    local function GetItemSortLabel(val)
        for _, o in ipairs(ITEM_SORT_OPTIONS) do
            if o.value == val then return o.text end
        end
        return OFF
    end

    stack:AddCard("bags:general:replacement", L["SECTION_REPLACEMENT_WINDOWS"], function(content, w)
        local y = 0

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_ENABLE_BAGS"],
            description = L["DESC_ENABLE_BAGS"],
            isEnabled = true,
            value = db.global.enableBagsUI,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("enableBagsUI", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
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

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_ENABLE_GUILD_BANK"],
            description = L["DESC_ENABLE_GUILD_BANK"],
            isEnabled = true,
            value = db.global.enableGuildBankUI,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("enableGuildBankUI", newVal)
            end,
        })

        return math.max(1, abs(y))
    end)

    stack:AddCard("bags:general:display", DISPLAY, function(content, w)
        local y = 0
        local controlWidth = math.max(160, (w or 200) - 24)

        local iconY, iconDD, iconDDText = PlaceLabeledDropdown(content, y, L["SETTING_ICON_SIZE"], controlWidth)
        iconDDText:SetText(GetIconSizeLabel(db.global.iconSize))
        OneWoW_GUI:AttachFilterMenu(iconDD, {
            searchable = false,
            buildItems = function() return ICON_SIZE_OPTIONS end,
            onSelect = function(value, text)
                iconDDText:SetText(text)
                ApplySetting("iconSize", value)
            end,
            getActiveValue = function()
                return GetDB().global.iconSize
            end,
        })
        Settings.iconSizeDDText = iconDDText
        y = iconY - 8

        local sortY, sortDD, sortDDText = PlaceLabeledDropdown(content, y, L["SETTING_ITEM_SORT"], controlWidth)
        sortDDText:SetText(GetItemSortLabel(db.global.itemSort))
        OneWoW_GUI:AttachFilterMenu(sortDD, {
            searchable = false,
            buildItems = function() return ITEM_SORT_OPTIONS end,
            onSelect = function(value, text)
                sortDDText:SetText(text)
                ApplySetting("itemSort", value)
            end,
            getActiveValue = function()
                return GetDB().global.itemSort
            end,
        })
        Settings.itemSortDDText = sortDDText
        y = sortY

        return math.max(1, abs(y))
    end)

    stack:AddCard("bags:general:integration", L["SECTION_INTEGRATION"], function(content, w)
        local y = 0

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_ENABLE_JUNK_CAT"],
            description = L["DESC_ENABLE_JUNK_CAT"],
            isEnabled = true,
            value = db.global.enableJunkCategory,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("enableJunkCategory", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_ENABLE_UPGRADE_CAT"],
            description = L["DESC_ENABLE_UPGRADE_CAT"],
            isEnabled = true,
            value = db.global.enableUpgradeCategory,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("enableUpgradeCategory", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_SHOW_KEYWORDS_TOOLTIP"],
            description = L["DESC_SHOW_KEYWORDS_TOOLTIP"],
            isEnabled = true,
            value = db.global.showKeywordsInTooltips,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("showKeywordsInTooltips", newVal)
            end,
        })

        return math.max(1, abs(y))
    end)

    if ns.Masque and ns.Masque.available then
        stack:AddCard("bags:general:masque", L["SECTION_MASQUE"], function(content, w)
            local y = OneWoW_GUI:CreateToggleRow(content, {
                yOffset = 0,
                contentWidth = w,
                label = L["SETTING_USE_MASQUE"],
                description = L["DESC_USE_MASQUE"],
                isEnabled = true,
                value = db.global.useMasque ~= false,
                onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
                onValueChange = function(newVal)
                    ApplySetting("useMasque", newVal)
                end,
            })
            return math.max(1, abs(y))
        end)
    end

    stack:AddCard("bags:general:placement", L["SECTION_CAT_PLACEMENT"], function(content, w)
        local y = 0

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_MOVE_UPGRADES_TOP"],
            description = L["DESC_MOVE_UPGRADES_TOP"],
            isEnabled = true,
            value = db.global.moveRecentToTop,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("moveRecentToTop", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_MOVE_OTHER_BOTTOM"],
            description = L["DESC_MOVE_OTHER_BOTTOM"],
            isEnabled = true,
            value = db.global.moveOtherToBottom,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("moveOtherToBottom", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_PINNED_CATEGORY_SHOWS_WHEN_DISABLED"],
            description = L["DESC_PINNED_CATEGORY_SHOWS_WHEN_DISABLED"],
            isEnabled = true,
            value = db.global.pinnedCategoryShowsWhenDisabled,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("pinnedCategoryShowsWhenDisabled", newVal)
            end,
        })

        y = BuildSliderRow(content, L["SETTING_RECENT_DURATION"], y, {
            padX = 12,
            contentWidth = w,
            minVal = 15, maxVal = 600, step = 15, currentVal = db.global.recentItemDuration,
            onChange = function(val)
                ApplySetting("recentItemDuration", val)
            end,
            fmt = "%d",
        })

        return math.max(1, abs(y))
    end)

    stack:AddCard("bags:general:search", SEARCH, function(content, w)
        local y = BuildSliderRow(content, L["SETTING_SEARCH_HISTORY_LIMIT"], 0, {
            padX = 12,
            contentWidth = w,
            description = L["DESC_SEARCH_HISTORY_LIMIT"],
            minVal = 0, maxVal = 10, step = 1, currentVal = db.global.searchHistoryLimit,
            onChange = function(val)
                ApplySetting("searchHistoryLimit", val)
            end,
            fmt = "%d",
        })

        y = y - 8
        local crumbDesc = OneWoW_GUI:CreateFS(content, 12)
        crumbDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        crumbDesc:SetJustifyH("LEFT")
        crumbDesc:SetWordWrap(true)
        if w and w > 40 then
            crumbDesc:SetWidth(w - 24)
        else
            crumbDesc:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, y)
        end
        crumbDesc:SetText(L["SEARCH_SHORTCUTS_BREADCRUMB_DESC"])
        crumbDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        y = y - (crumbDesc:GetStringHeight() or 14) - 10

        local openLink = OneWoW_GUI:CreateTextLink(content, {
            text = L["SEARCH_SHORTCUTS_OPEN_HUB"],
            fontSize = 12,
            nav = true,
            onClick = function()
                if OneWoW.UI and OneWoW.UI.OpenSearchShortcuts then
                    OneWoW.UI:OpenSearchShortcuts()
                end
            end,
        })
        openLink:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        y = y - (openLink:GetHeight() or 14) - 4

        return math.max(1, abs(y))
    end)

    FinishSettingsCardStack(stack, sc)
end

local function BuildBagsTab(sc, db)
    local stack = BeginSettingsCardStack(sc)

    stack:AddCard("bags:bags:display", DISPLAY, function(content, w)
        local y = 0

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_SHOW_NEW"],
            description = L["DESC_SHOW_NEW"],
            isEnabled = true,
            value = db.global.showNewItems,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("showNewItems", newVal)
            end,
        })

        do
            local overlayEnabled = OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", "general")
            y = OneWoW_GUI:CreateToggleRow(content, {
                yOffset = y,
                contentWidth = w,
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

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_SHOW_SCROLLBAR"],
            description = L["DESC_SHOW_SCROLLBAR"],
            isEnabled = true,
            value = not db.global.hideScrollBar,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("showScrollBar", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_SHOW_BAGS_BAR"],
            description = L["DESC_SHOW_BAGS_BAR"],
            isEnabled = true,
            value = db.global.showBagsBar,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("showBagsBar", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_HIDE_BLIZZARD_BAGS_BAR"],
            description = L["DESC_HIDE_BLIZZARD_BAGS_BAR"],
            isEnabled = true,
            value = db.global.hideBlizzardBagsBar,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("hideBlizzardBagsBar", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_SHOW_MONEY_BAR"],
            description = L["DESC_SHOW_MONEY_BAR"],
            isEnabled = true,
            value = db.global.showMoneyBar,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("showMoneyBar", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_TRACKER_CAP_HIGHLIGHT"],
            description = L["DESC_TRACKER_CAP_HIGHLIGHT"],
            isEnabled = true,
            value = db.global.showCurrencyTrackerCapHighlight,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("showCurrencyTrackerCapHighlight", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_SHOW_HEADER_BAR"],
            description = L["DESC_SHOW_HEADER_BAR"],
            isEnabled = true,
            value = db.global.showHeaderBar,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("showHeaderBar", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_SHOW_SEARCH_BAR"],
            description = L["DESC_SHOW_SEARCH_BAR"],
            isEnabled = true,
            value = db.global.showSearchBar,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("showSearchBar", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_ENABLE_EXPAC_FILTER"],
            description = L["DESC_ENABLE_EXPAC_FILTER"],
            isEnabled = true,
            value = db.global.enableExpansionFilter,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("enableExpansionFilter", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_SHOW_CAT_HEADERS"],
            description = L["DESC_SHOW_CAT_HEADERS"],
            isEnabled = true,
            value = db.global.showCategoryHeaders,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("showCategoryHeaders", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_SHOW_EMPTY_SLOTS"],
            description = L["DESC_SHOW_EMPTY_SLOTS"],
            isEnabled = true,
            value = db.global.showEmptySlots,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("showEmptySlots", newVal)
            end,
        })

        y = y - 6

        y = BuildSliderRow(content, L["SETTING_SCALE"], y, {
            padX = 12,
            contentWidth = w,
            minVal = WH.SCALE_MIN, maxVal = WH.SCALE_MAX, step = WH.SCALE_STEP,
            currentVal = db.global.bagScale,
            onChange = function(val)
                ApplySetting("bagScale", val)
            end,
            fmt = "%d%%",
        })

        y = BuildSliderRow(content, L["SETTING_BAG_COLUMNS"], y, {
            padX = 12,
            contentWidth = w,
            minVal = 10, maxVal = 30, step = 1, currentVal = db.global.bagColumns,
            onChange = function(val)
                ApplySetting("bagColumns", val)
            end,
            fmt = "%d",
        })

        y = BuildSliderRow(content, L["SETTING_CATEGORY_SPACING"], y, {
            padX = 12,
            contentWidth = w,
            minVal = 0.1, maxVal = 2.0, step = 0.1, currentVal = db.global.categorySpacing,
            onChange = function(val)
                ApplySetting("categorySpacing", val)
            end,
            fmt = "%.1f",
        })

        return math.max(1, abs(y))
    end)

    stack:AddCard("bags:bags:categories", CATEGORIES, function(content, w)
        local y = 0

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_INVENTORY_SLOTS"],
            description = L["DESC_INVENTORY_SLOTS"],
            isEnabled = true,
            value = db.global.enableInventorySlots,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("enableInventorySlots", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_STACK_ITEMS"],
            description = L["DESC_STACK_ITEMS"],
            isEnabled = true,
            value = db.global.stackItems,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("stackItems", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_COMPACT_CATEGORIES"],
            description = L["DESC_COMPACT_CATEGORIES"],
            isEnabled = true,
            value = db.global.compactCategories,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("compactCategories", newVal)
            end,
        })

        y = BuildCompactGapSlider(content, y, w, db.global.compactGap, function(realVal)
            ApplySetting("compactGap", realVal)
        end)

        return math.max(1, abs(y))
    end)

    stack:AddCard("bags:bags:itemdisplay", L["SECTION_ITEM_DISPLAY"], function(content, w)
        local y = 0

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_UNUSABLE_OVERLAY"],
            description = L["DESC_UNUSABLE_OVERLAY"],
            isEnabled = true,
            value = db.global.showUnusableOverlay,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("showUnusableOverlay", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_DIM_JUNK"],
            description = L["DESC_DIM_JUNK"],
            isEnabled = true,
            value = db.global.dimJunkItems,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("dimJunkItems", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_STRIP_JUNK_OVERLAYS"],
            description = L["DESC_STRIP_JUNK_OVERLAYS"],
            isEnabled = true,
            value = db.global.stripJunkOverlays,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("stripJunkOverlays", newVal)
            end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_ALT_TO_SHOW"],
            description = L["DESC_ALT_TO_SHOW"],
            isEnabled = true,
            value = db.global.altToShow,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal) ApplySetting("altToShow", newVal) end,
        })

        return math.max(1, abs(y))
    end)

    stack:AddCard("bags:bags:behavior", L["SECTION_BEHAVIOR"], function(content, w)
        local y = 0

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_AUTO_OPEN"],
            description = L["DESC_AUTO_OPEN"],
            isEnabled = true,
            value = db.global.autoOpen,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal) ApplySetting("autoOpen", newVal) end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_AUTO_CLOSE"],
            description = L["DESC_AUTO_CLOSE"],
            isEnabled = true,
            value = db.global.autoClose,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal) ApplySetting("autoClose", newVal) end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_AUTO_OPEN_WITH_BANK"],
            description = L["DESC_AUTO_OPEN_WITH_BANK"],
            isEnabled = true,
            value = db.global.autoOpenWithBank,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal) ApplySetting("autoOpenWithBank", newVal) end,
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_LOCK"],
            description = L["DESC_LOCK"],
            isEnabled = true,
            value = db.global.locked,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal) ApplySetting("locked", newVal) end,
        })

        return math.max(1, abs(y))
    end)

    FinishSettingsCardStack(stack, sc)
end

local MODE_KEYS = {
    personal = {
        sectionTitle = "SECTION_PERSONAL_BANK",
        db = {
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
            scale             = "bankScale",
        },
        applier = {
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
            scale             = "bankScale",
        },
    },
    warband = {
        sectionTitle = ACCOUNT_BANK_PANEL_TITLE,
        db = {
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
            scale             = "warbandBankScale",
        },
        applier = {
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
            scale             = "warbandBankScale",
        },
    },
}

local sharedLockRefreshers = {}
local sharedApplyEnabledFns = {}

BroadcastSharedEnable = function(newVal)
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
    sharedLockRefreshers = {}
    sharedApplyEnabledFns = {}
end

local function BankSectionTitle(keys)
    if keys.sectionTitle == ACCOUNT_BANK_PANEL_TITLE then
        return ACCOUNT_BANK_PANEL_TITLE
    end
    return L[keys.sectionTitle]
end

local function BuildBankTabFor(mode, sc, db)
    local keys = MODE_KEYS[mode]
    local dbKeys = keys.db
    local applierKeys = keys.applier
    local cardPrefix = "bags:bank:" .. mode

    local dependents = {}
    local sharedLockIdx

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

    local stack = BeginSettingsCardStack(sc)
    local prevOnRelayout = stack.OnRelayout
    stack.OnRelayout = function()
        if prevOnRelayout then prevOnRelayout() end
        applyEnabled(GetDB().global.enableBankUI and true or false)
    end

    stack:AddCard(cardPrefix .. ":top", BankSectionTitle(keys), function(content, w)
        wipe(dependents)
        local y = 0

        local lockRefresh
        y, lockRefresh = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_LOCK"],
            description = L["DESC_BANK_LOCK"],
            isEnabled = true,
            value = db.global.bankLocked,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("bankLocked", newVal)
                BroadcastSharedLock(newVal)
            end,
        })
        if sharedLockIdx then
            sharedLockRefreshers[sharedLockIdx] = lockRefresh
        else
            tinsert(sharedLockRefreshers, lockRefresh)
            sharedLockIdx = #sharedLockRefreshers
        end
        addToggle(lockRefresh, function() return db.global.bankLocked end)

        return math.max(1, abs(y))
    end)

    stack:AddCard(cardPrefix .. ":display", DISPLAY, function(content, w)
        local y = 0

        local overlaysRefresh
        y, overlaysRefresh = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
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
        y, scrollbarRefresh = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
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
        y, bagsBarRefresh = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
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
        y, headerBarRefresh = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
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
        y, searchBarRefresh = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
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
        y, expacFilterRefresh = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
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
        y, catHeadersRefresh = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
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
        y, emptySlotsRefresh = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
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

        y = y - 6

        local scaleSliderContainer, scaleSliderLbl
        y, scaleSliderContainer, scaleSliderLbl = BuildSliderRow(content, L["SETTING_SCALE"], y, {
            padX = 12,
            contentWidth = w,
            minVal = WH.SCALE_MIN, maxVal = WH.SCALE_MAX, step = WH.SCALE_STEP,
            currentVal = db.global[dbKeys.scale],
            onChange = function(val)
                ApplySetting(applierKeys.scale, val)
            end,
            fmt = "%d%%",
        })
        addSlider(scaleSliderContainer, scaleSliderLbl)

        local colSliderContainer, colSliderLbl
        y, colSliderContainer, colSliderLbl = BuildSliderRow(content, L["SETTING_BANK_COLUMNS"], y, {
            padX = 12,
            contentWidth = w,
            minVal = 15, maxVal = 30, step = 1, currentVal = db.global[dbKeys.columns],
            onChange = function(val)
                ApplySetting(applierKeys.columns, val)
            end,
            fmt = "%d",
        })
        addSlider(colSliderContainer, colSliderLbl)

        local spaceSliderContainer, spaceSliderLbl
        y, spaceSliderContainer, spaceSliderLbl = BuildSliderRow(content, L["SETTING_CATEGORY_SPACING"], y, {
            padX = 12,
            contentWidth = w,
            minVal = 0.1, maxVal = 2.0, step = 0.1, currentVal = db.global[dbKeys.categorySpacing],
            onChange = function(val)
                ApplySetting(applierKeys.categorySpacing, val)
            end,
            fmt = "%.1f",
        })
        addSlider(spaceSliderContainer, spaceSliderLbl)

        local compactRefresh
        y, compactRefresh = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
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

        local gapSlider, gapLbl
        y, gapSlider, gapLbl = BuildCompactGapSlider(content, y, w, db.global[dbKeys.compactGap], function(realVal)
            ApplySetting(applierKeys.compactGap, realVal)
        end)
        addSlider(gapSlider, gapLbl)

        return math.max(1, abs(y))
    end)

    FinishSettingsCardStack(stack, sc)
    applyEnabled(db.global.enableBankUI)
end

local function BuildGuildBankTab(sc, db)
    local stack = BeginSettingsCardStack(sc)

    stack:AddCard("bags:guild:display", DISPLAY, function(content, w)
        local y = BuildSliderRow(content, L["SETTING_SCALE"], 0, {
            padX = 12,
            contentWidth = w,
            minVal = WH.SCALE_MIN, maxVal = WH.SCALE_MAX, step = WH.SCALE_STEP,
            currentVal = db.global.guildBankScale,
            onChange = function(val)
                ApplySetting("guildBankScale", val)
            end,
            fmt = "%d%%",
        })

        y = OneWoW_GUI:CreateToggleRow(content, {
            yOffset = y,
            contentWidth = w,
            label = L["SETTING_SHOW_EMPTY_SLOTS"],
            description = L["DESC_SHOW_EMPTY_SLOTS"],
            isEnabled = true,
            value = db.global.guildBankShowEmptySlots,
            onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                ApplySetting("showGuildBankEmptySlots", newVal)
            end,
        })
        return math.max(1, abs(y))
    end)

    FinishSettingsCardStack(stack, sc)
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

function Settings:UpdateSizeButtons()
    local db = GetDB()
    if Settings.iconSizeDDText then
        local map = {
            [1] = SMALL,
            [2] = L["ICON_SIZE_M"],
            [3] = LARGE,
            [4] = L["ICON_SIZE_XL"],
        }
        Settings.iconSizeDDText:SetText(map[db.global.iconSize] or LARGE)
    end
end

function Settings:UpdateItemSortButtons()
    if not Settings.itemSortDDText then return end
    local sort = GetDB().global.itemSort
    local map = {
        none = OFF,
        default = L["SORT_DEFAULT"],
        name = NAME,
        rarity = RARITY,
        ilvl = L["SORT_ITEM_LEVEL"],
        type = TYPE,
    }
    Settings.itemSortDDText:SetText(map[sort] or OFF)
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
    settingsSectionDropdownText = nil
    Settings.iconSizeDDText = nil
    Settings.itemSortDDText = nil
    activeSettingsSection = 1
    ResetSharedBankRefreshers()
end
