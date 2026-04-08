local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local ipairs, pairs = ipairs, pairs
local abs, floor = math.abs, math.floor

local C_Timer = C_Timer

local L = OneWoW_Bags.L

local BankGUI = OneWoW_Bags.BankGUI
local GuildBankGUI = OneWoW_Bags.GuildBankGUI
local Categories = OneWoW_Bags.Categories
local BagSet = OneWoW_Bags.BagSet
local BankSet = OneWoW_Bags.BankSet
local GuildBankSet = OneWoW_Bags.GuildBankSet
local InfoBar = OneWoW_Bags.InfoBar
local BankInfoBar = OneWoW_Bags.BankInfoBar

OneWoW_Bags.Settings = {}
local Settings = OneWoW_Bags.Settings
local settingsFrame = nil
local isCreated = false
local bagColTimer = nil
local bankColTimer = nil
local catSpaceTimer = nil
local bankCatSpaceTimer = nil
local compactGapTimer = nil
local bankCompactGapTimer = nil
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

local tabContents = {}
local tabBtns = {}

local function SwitchTab(n)
    for i, content in ipairs(tabContents) do
        content:SetShown(i == n)
    end
    for i, btn in ipairs(tabBtns) do
        if i == n then
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            if not btn._activeBar then
                btn._activeBar = btn:CreateTexture(nil, "OVERLAY")
                btn._activeBar:SetHeight(2)
                btn._activeBar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
                btn._activeBar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
            end
            btn._activeBar:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            btn._activeBar:Show()
        else
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            if btn._activeBar then btn._activeBar:Hide() end
        end
    end
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

    local slider = OneWoW_GUI:CreateSlider(container, options)
    slider:SetPoint("TOPLEFT", container, "TOPLEFT", 15, yOffset)
    yOffset = yOffset - 40

    return yOffset
end

local function BuildGeneralTab(sc, L, db, GUI)
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

    if _G.OneWoW then
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

        yOffset = FinalizeContainer(intContainer, intY, yOffset)
    end

    yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SECTION_CAT_PLACEMENT"], yOffset = yOffset })
    local placeContainer = BuildContainer(sc, yOffset)
    local placeY = -10

    placeY, _, _ = OneWoW_GUI:CreateToggleRow(placeContainer, {
        yOffset = placeY,
        label = L["SETTING_MOVE_UPGRADES_TOP"],
        description = L["DESC_MOVE_UPGRADES_TOP"],
        isEnabled = true,
        value = db.global.moveUpgradesToTop,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("moveUpgradesToTop", newVal)
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

    placeY = placeY - 6

    placeY = BuildSliderRow(placeContainer, L["SETTING_RECENT_DURATION"], placeY, {
        minVal = 15, maxVal = 600, step = 15, currentVal = db.global.recentItemDuration or 120,
        onChange = function(val)
            ApplySetting("recentItemDuration", val)
        end,
        width = 240, fmt = "%d",
    })

    yOffset = FinalizeContainer(placeContainer, placeY, yOffset)

    sc:SetHeight(abs(yOffset) + 40)
end

local function BuildBagsTab(sc, L, db, GUI)
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

    if _G.OneWoW then
        local overlayEnabled = false
        if _G.OneWoW.SettingsFeatureRegistry then
            overlayEnabled = _G.OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", "general")
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

    dispY = dispY - 6

    dispY = BuildSliderRow(dispContainer, L["SETTING_BAG_COLUMNS"], dispY, {
        minVal = 10, maxVal = 30, step = 1, currentVal = db.global.bagColumns or 15,
        onChange = function(val)
            ApplySetting("bagColumns", val)
        end,
        width = 240, fmt = "%d",
    })

    dispY = BuildSliderRow(dispContainer, L["SETTING_CATEGORY_SPACING"], dispY, {
        minVal = 0.1, maxVal = 2.0, step = 0.1, currentVal = db.global.categorySpacing or 1.0,
        onChange = function(val)
            ApplySetting("categorySpacing", val)
        end,
        width = 240, fmt = "%.1f",
    })

    do
        local gapLbl = dispContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        gapLbl:SetPoint("TOPLEFT", dispContainer, "TOPLEFT", 15, dispY)
        gapLbl:SetText(L["SETTING_COMPACT_GAP"])
        gapLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        dispY = dispY - gapLbl:GetStringHeight() - 4

        local curIdx = CompactGapToIndex(db.global.compactGap or 1)
        local gapSlider = OneWoW_GUI:CreateSlider(dispContainer, {
            minVal = 1, maxVal = #COMPACT_GAP_STEPS, step = 1, currentVal = curIdx,
            onChange = function(val)
                local idx = floor(val + 0.5)
                local realVal = CompactGapFromIndex(idx)
                ApplySetting("compactGap", realVal)
            end,
            width = 240, fmt = "%d",
        })
        gapSlider:SetPoint("TOPLEFT", dispContainer, "TOPLEFT", 15, dispY)

        local slider = gapSlider:GetChildren()
        if slider then
            slider:HookScript("OnValueChanged", function(self, val)
                local idx = floor(val + 0.5)
                local realVal = CompactGapFromIndex(idx)
                local valLabel = gapSlider:GetRegions()
                if not valLabel then return end
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
        dispY = dispY - 40
    end

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
        label = L["SETTING_COMPACT_CATEGORIES"],
        description = L["DESC_COMPACT_CATEGORIES"],
        isEnabled = true,
        value = db.global.compactCategories,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("compactCategories", newVal)
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

local function BuildBankTab(sc, L, db, GUI)
    local yOffset = -15

    yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SECTION_BANK"], yOffset = yOffset })
    local bankTopContainer = BuildContainer(sc, yOffset)
    local topY = -10

    topY, _, _ = OneWoW_GUI:CreateToggleRow(bankTopContainer, {
        yOffset = topY,
        label = L["SETTING_ENABLE_BANK"],
        description = L["DESC_ENABLE_BANK"],
        isEnabled = true,
        value = db.global.enableBankUI,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("enableBankUI", newVal)
        end,
    })

    yOffset = FinalizeContainer(bankTopContainer, topY, yOffset)

    yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SECTION_DISPLAY"], yOffset = yOffset })
    local dispContainer = BuildContainer(sc, yOffset)
    local dispY = -10

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_RARITY_COLOR"],
        description = L["DESC_BANK_RARITY_COLOR"],
        isEnabled = true,
        value = db.global.bankRarityColor,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("bankRarityColor", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_BANK_OVERLAYS"],
        description = L["DESC_BANK_OVERLAYS"],
        isEnabled = true,
        value = db.global.enableBankOverlays,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("enableBankOverlays", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_SCROLLBAR"],
        description = L["DESC_SHOW_BANK_SCROLLBAR"],
        isEnabled = true,
        value = not db.global.bankHideScrollBar,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showBankScrollBar", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_BANK_BAGS_BAR"],
        description = L["DESC_SHOW_BANK_BAGS_BAR"],
        isEnabled = true,
        value = db.global.showBankBagsBar,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showBankBagsBar", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_HEADER_BAR"],
        description = L["DESC_SHOW_BANK_HEADER_BAR"],
        isEnabled = true,
        value = db.global.showBankHeaderBar,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showBankHeaderBar", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_SEARCH_BAR"],
        description = L["DESC_SHOW_BANK_SEARCH_BAR"],
        isEnabled = true,
        value = db.global.showBankSearchBar,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showBankSearchBar", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_ENABLE_EXPAC_FILTER"],
        description = L["DESC_ENABLE_BANK_EXPAC_FILTER"],
        isEnabled = true,
        value = db.global.enableBankExpansionFilter,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("enableBankExpansionFilter", newVal)
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_CAT_HEADERS"],
        description = L["DESC_SHOW_BANK_CAT_HEADERS"],
        isEnabled = true,
        value = db.global.showBankCategoryHeaders,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("showBankCategoryHeaders", newVal)
        end,
    })

    dispY = dispY - 6

    dispY = BuildSliderRow(dispContainer, L["SETTING_BANK_COLUMNS"], dispY, {
        minVal = 10, maxVal = 30, step = 1, currentVal = db.global.bankColumns or 14,
        onChange = function(val)
            ApplySetting("bankColumns", val)
        end,
        width = 240, fmt = "%d",
    })

    dispY = BuildSliderRow(dispContainer, L["SETTING_CATEGORY_SPACING"], dispY, {
        minVal = 0.1, maxVal = 2.0, step = 0.1, currentVal = db.global.bankCategorySpacing or 1.0,
        onChange = function(val)
            ApplySetting("bankCategorySpacing", val)
        end,
        width = 240, fmt = "%.1f",
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(dispContainer, {
        yOffset = dispY,
        label = L["SETTING_COMPACT_CATEGORIES"],
        description = L["DESC_COMPACT_CATEGORIES"],
        isEnabled = true,
        value = db.global.bankCompactCategories,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            ApplySetting("bankCompactCategories", newVal)
        end,
    })

    do
        local gapLbl = dispContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        gapLbl:SetPoint("TOPLEFT", dispContainer, "TOPLEFT", 15, dispY)
        gapLbl:SetText(L["SETTING_COMPACT_GAP"])
        gapLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        dispY = dispY - gapLbl:GetStringHeight() - 4

        local curIdx = CompactGapToIndex(db.global.bankCompactGap or 1)
        local gapSlider = OneWoW_GUI:CreateSlider(dispContainer, {
            minVal = 1, maxVal = #COMPACT_GAP_STEPS, step = 1, currentVal = curIdx,
            onChange = function(val)
                local idx = floor(val + 0.5)
                local realVal = CompactGapFromIndex(idx)
                ApplySetting("bankCompactGap", realVal)
            end,
            width = 240, fmt = "%d",
        })
        gapSlider:SetPoint("TOPLEFT", dispContainer, "TOPLEFT", 15, dispY)

        local slider = gapSlider:GetChildren()
        if slider then
            slider:HookScript("OnValueChanged", function(self, val)
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
        dispY = dispY - 40
    end

    yOffset = FinalizeContainer(dispContainer, dispY, yOffset)

    yOffset = OneWoW_GUI:CreateSection(sc, { title = L["SECTION_BEHAVIOR"], yOffset = yOffset })
    local behContainer = BuildContainer(sc, yOffset)
    local behY = -10

    behY, _, _ = OneWoW_GUI:CreateToggleRow(behContainer, {
        yOffset = behY,
        label = L["SETTING_BANK_LOCK"],
        description = L["DESC_BANK_LOCK"],
        isEnabled = true,
        value = db.global.bankLocked,
        onLabel = L["TOGGLE_ON"], offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal) ApplySetting("bankLocked", newVal) end,
    })

    yOffset = FinalizeContainer(behContainer, behY, yOffset)

    sc:SetHeight(abs(yOffset) + 40)
end

function Settings:Create()
    if isCreated then return settingsFrame end

    local GUI = OneWoW_Bags.GUI
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

    local tabLabels = { L["TAB_GENERAL"], L["TAB_BAGS"], L["TAB_BANK"] }
    local prevBtn = nil
    for i, label in ipairs(tabLabels) do
        local btn = OneWoW_GUI:CreateFitTextButton(tabRow, { text = label, height = 26, minWidth = 90 })
        if not prevBtn then
            btn:SetPoint("LEFT", tabRow, "LEFT", 6, 0)
        else
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
        end
        local idx = i
        btn:SetScript("OnClick", function() SwitchTab(idx) end)
        tabBtns[i] = btn
        prevBtn = btn
    end

    for i = 1, 3 do
        local sf = CreateFrame("Frame", nil, contentFrame)
        sf:SetPoint("TOPLEFT", tabRow, "BOTTOMLEFT", 0, -2)
        sf:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
        local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(sf, {})
        sf.scrollFrame = scrollFrame
        sf.scrollContent = scrollContent
        tabContents[i] = sf
        sf:Hide()
    end

    BuildGeneralTab(tabContents[1].scrollContent, L, db, GUI)
    BuildBagsTab(tabContents[2].scrollContent, L, db, GUI)
    BuildBankTab(tabContents[3].scrollContent, L, db, GUI)

    SwitchTab(1)

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
        local db = GetDB()
        local sortMode = db.global.itemSort or "default"
        btns.SetActiveByValue(sortMode)
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
    tabBtns = {}
end
