local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.Settings = {}
local Settings = OneWoW_Bags.Settings
local settingsFrame = nil
local isCreated = false
local OneWoW_GUI = OneWoW_Bags.GUILib
local bagColTimer = nil
local bankColTimer = nil

local T = OneWoW_Bags.T

function Settings:Create()
    if isCreated then return settingsFrame end

    local GUI = OneWoW_Bags.GUI
    local Constants = OneWoW_Bags.Constants
    local L = OneWoW_Bags.L
    local db = OneWoW_Bags.db

    local dialog = OneWoW_GUI:CreateDialog({
        name = "OneWoW_BagsSettingsWindow",
        title = L["SETTINGS_TITLE"],
        width = 540,
        height = 780,
        strata = "DIALOG",
        movable = true,
        escClose = true,
        showScrollFrame = true,
    })

    settingsFrame = dialog.frame
    local scrollContent = dialog.scrollContent

    local yOffset = OneWoW_GUI:CreateSettingsPanel(scrollContent, { yOffset = -15, addonName = "OneWoW_Bags" })

    yOffset = yOffset - 10

    yOffset = OneWoW_GUI:CreateSection(scrollContent, { title = L["SECTION_BANK"], yOffset = yOffset })

    local bankContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    bankContainer:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 10, yOffset)
    bankContainer:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -10, yOffset)
    bankContainer:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    bankContainer:SetBackdropColor(T("BG_SECONDARY"))
    bankContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local bankY = -10
    bankY, _, _ = OneWoW_GUI:CreateToggleRow(bankContainer, {
        yOffset = bankY,
        label = L["SETTING_ENABLE_BANK"],
        description = L["DESC_ENABLE_BANK"],
        isEnabled = true,
        value = db.global.enableBankUI,
        onLabel = L["TOGGLE_ON"],
        offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            db.global.enableBankUI = newVal
            if not newVal then
                if OneWoW_Bags.RestoreBankFrame then OneWoW_Bags:RestoreBankFrame() end
                if OneWoW_Bags.RestoreGuildBankFrame then OneWoW_Bags:RestoreGuildBankFrame() end
                if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI:IsShown() then
                    OneWoW_Bags.BankGUI:Hide()
                end
                if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI:IsShown() then
                    OneWoW_Bags.GuildBankGUI:Hide()
                end
            end
        end,
    })
    bankY, _, _ = OneWoW_GUI:CreateToggleRow(bankContainer, {
        yOffset = bankY,
        label = L["SETTING_BANK_OVERLAYS"],
        description = L["DESC_BANK_OVERLAYS"],
        isEnabled = true,
        value = db.global.enableBankOverlays,
        onLabel = L["TOGGLE_ON"],
        offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            db.global.enableBankOverlays = newVal
            if newVal then
                if OneWoW_Bags.FireCallbacksOnBankButtons then OneWoW_Bags:FireCallbacksOnBankButtons() end
            else
                if OneWoW_Bags.ClearBankOverlays then OneWoW_Bags:ClearBankOverlays() end
            end
        end,
    })
    bankContainer:SetHeight(math.abs(bankY) + 4)
    yOffset = yOffset - math.abs(bankY) - 4 - 15

    yOffset = OneWoW_GUI:CreateSection(scrollContent, { title = L["SECTION_DISPLAY"], yOffset = yOffset })

    local displayContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    displayContainer:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 10, yOffset)
    displayContainer:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -10, yOffset)
    displayContainer:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    displayContainer:SetBackdropColor(T("BG_SECONDARY"))
    displayContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local dispY = -10
    dispY, _, _ = OneWoW_GUI:CreateToggleRow(displayContainer, {
        yOffset = dispY,
        label = L["SETTING_RARITY_COLOR"],
        description = L["DESC_RARITY_COLOR"],
        isEnabled = true,
        value = db.global.rarityColor,
        onLabel = L["TOGGLE_ON"],
        offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            db.global.rarityColor = newVal
            if OneWoW_Bags.BagSet and OneWoW_Bags.BagSet.isBuilt then
                OneWoW_Bags.BagSet:UpdateAllSlots()
            end
            if OneWoW_Bags.BankSet and OneWoW_Bags.BankSet.isBuilt then
                OneWoW_Bags.BankSet:UpdateAllSlots()
            end
            if OneWoW_Bags.GuildBankSet and OneWoW_Bags.GuildBankSet.isBuilt then
                OneWoW_Bags.GuildBankSet:UpdateAllSlots()
            end
            if GUI.RefreshLayout then GUI:RefreshLayout() end
            if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
                OneWoW_Bags.BankGUI:RefreshLayout()
            end
            if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.RefreshLayout then
                OneWoW_Bags.GuildBankGUI:RefreshLayout()
            end
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(displayContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_NEW"],
        description = L["DESC_SHOW_NEW"],
        isEnabled = true,
        value = db.global.showNewItems,
        onLabel = L["TOGGLE_ON"],
        offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            db.global.showNewItems = newVal
            if OneWoW_Bags.BagSet and OneWoW_Bags.BagSet.isBuilt then
                OneWoW_Bags.BagSet:UpdateAllSlots()
            end
            if GUI.RefreshLayout then GUI:RefreshLayout() end
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(displayContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_SCROLLBAR"],
        description = L["DESC_SHOW_SCROLLBAR"],
        isEnabled = true,
        value = not db.global.hideScrollBar,
        onLabel = L["TOGGLE_ON"],
        offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            db.global.hideScrollBar = not newVal
            local wasShown = OneWoW_Bags.GUI and OneWoW_Bags.GUI:IsShown()
            if OneWoW_Bags.GUI then
                OneWoW_Bags.GUI:FullReset()
                if wasShown then C_Timer.After(0.1, function() OneWoW_Bags.GUI:Show() end) end
            end
            local bankWasShown = OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI:IsShown()
            if OneWoW_Bags.BankGUI then
                OneWoW_Bags.BankGUI:FullReset()
                if bankWasShown and OneWoW_Bags.bankOpen then
                    C_Timer.After(0.1, function() OneWoW_Bags.BankGUI:Show() end)
                end
            end
            local gbWasShown = OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI:IsShown()
            if OneWoW_Bags.GuildBankGUI then
                OneWoW_Bags.GuildBankGUI:FullReset()
                if gbWasShown and OneWoW_Bags.guildBankOpen then
                    C_Timer.After(0.1, function() OneWoW_Bags.GuildBankGUI:Show() end)
                end
            end
        end,
    })

    dispY, _, _ = OneWoW_GUI:CreateToggleRow(displayContainer, {
        yOffset = dispY,
        label = L["SETTING_SHOW_BAGS_BAR"],
        description = L["DESC_SHOW_BAGS_BAR"],
        isEnabled = true,
        value = db.global.showBagsBar,
        onLabel = L["TOGGLE_ON"],
        offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            db.global.showBagsBar = newVal
            if OneWoW_Bags.GUI.UpdateBagsBarVisibility then
                OneWoW_Bags.GUI:UpdateBagsBarVisibility()
            end
        end,
    })
    dispY = dispY - 6
    local bagColLabel = displayContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bagColLabel:SetPoint("TOPLEFT", displayContainer, "TOPLEFT", 15, dispY)
    bagColLabel:SetText(L["SETTING_BAG_COLUMNS"])
    bagColLabel:SetTextColor(T("TEXT_PRIMARY"))
    dispY = dispY - bagColLabel:GetStringHeight() - 4

    local bagColSlider = OneWoW_GUI:CreateSlider(displayContainer, {
        minVal = 2, maxVal = 30, step = 1, currentVal = db.global.bagColumns or 15,
        onChange = function(val)
            db.global.bagColumns = val
            if bagColTimer then bagColTimer:Cancel() end
            bagColTimer = C_Timer.NewTimer(0.15, function()
                bagColTimer = nil
                if GUI.RefreshLayout then GUI:RefreshLayout() end
            end)
        end,
        width = 240, fmt = "%d",
    })
    bagColSlider:SetPoint("TOPLEFT", displayContainer, "TOPLEFT", 15, dispY)
    dispY = dispY - 40

    local bankColLabel = displayContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bankColLabel:SetPoint("TOPLEFT", displayContainer, "TOPLEFT", 15, dispY)
    bankColLabel:SetText(L["SETTING_BANK_COLUMNS"])
    bankColLabel:SetTextColor(T("TEXT_PRIMARY"))
    dispY = dispY - bankColLabel:GetStringHeight() - 4

    local bankColSlider = OneWoW_GUI:CreateSlider(displayContainer, {
        minVal = 2, maxVal = 30, step = 1, currentVal = db.global.bankColumns or 14,
        onChange = function(val)
            db.global.bankColumns = val
            if bankColTimer then bankColTimer:Cancel() end
            bankColTimer = C_Timer.NewTimer(0.15, function()
                bankColTimer = nil
                if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
                    OneWoW_Bags.BankGUI:RefreshLayout()
                end
                if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.RefreshLayout then
                    OneWoW_Bags.GuildBankGUI:RefreshLayout()
                end
            end)
        end,
        width = 240, fmt = "%d",
    })
    bankColSlider:SetPoint("TOPLEFT", displayContainer, "TOPLEFT", 15, dispY)
    dispY = dispY - 40

    displayContainer:SetHeight(math.abs(dispY) + 4)
    yOffset = yOffset - math.abs(dispY) - 4 - 15

    yOffset = OneWoW_GUI:CreateSection(scrollContent, { title = L["SETTING_ICON_SIZE"], yOffset = yOffset })

    local sizeContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    sizeContainer:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 10, yOffset)
    sizeContainer:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -10, yOffset)
    sizeContainer:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    sizeContainer:SetBackdropColor(T("BG_SECONDARY"))
    sizeContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local sizeY = -12
    local sizeItems = {
        { text = L["ICON_SIZE_S"], value = 1, isActive = (db.global.iconSize == 1) },
        { text = L["ICON_SIZE_M"], value = 2, isActive = (db.global.iconSize == 2) },
        { text = L["ICON_SIZE_L"], value = 3, isActive = (db.global.iconSize == 3) },
        { text = L["ICON_SIZE_XL"], value = 4, isActive = (db.global.iconSize == 4) },
    }

    local sizeBtns, sizeFinalY = OneWoW_GUI:CreateFitFrameButtons(sizeContainer, {
        yOffset = sizeY,
        items = sizeItems,
        height = 24,
        gap = 8,
        marginX = 15,
        width = 490,
        onSelect = function(value)
            db.global.iconSize = value
            if GUI.RefreshLayout then GUI:RefreshLayout() end
            if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
                OneWoW_Bags.BankGUI:RefreshLayout()
            end
            if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.RefreshLayout then
                OneWoW_Bags.GuildBankGUI:RefreshLayout()
            end
        end,
    })
    Settings.sizeBtns = sizeBtns
    sizeY = sizeFinalY - 8
    sizeContainer:SetHeight(math.abs(sizeY) + 4)
    yOffset = yOffset - math.abs(sizeY) - 4 - 15

    yOffset = OneWoW_GUI:CreateSection(scrollContent, { title = L["SETTING_ITEM_SORT"], yOffset = yOffset })

    local sortContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    sortContainer:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 10, yOffset)
    sortContainer:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -10, yOffset)
    sortContainer:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    sortContainer:SetBackdropColor(T("BG_SECONDARY"))
    sortContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local sortY = -12
    local itemSortItems = {
        { text = L["SORT_OFF"], value = "none", isActive = (db.global.itemSort == "none") },
        { text = L["SORT_DEFAULT"], value = "default", isActive = (db.global.itemSort == "default") },
        { text = L["SORT_NAME"], value = "name", isActive = (db.global.itemSort == "name") },
        { text = L["SORT_RARITY"], value = "rarity", isActive = (db.global.itemSort == "rarity") },
        { text = L["SORT_ITEM_LEVEL"], value = "ilvl", isActive = (db.global.itemSort == "ilvl") },
        { text = L["SORT_TYPE"], value = "type", isActive = (db.global.itemSort == "type") },
    }

    local itemSortBtns, itemSortFinalY = OneWoW_GUI:CreateFitFrameButtons(sortContainer, {
        yOffset = sortY,
        items = itemSortItems,
        height = 24,
        gap = 8,
        marginX = 15,
        width = 490,
        onSelect = function(value)
            db.global.itemSort = value
            if GUI.RefreshLayout then GUI:RefreshLayout() end
            if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
                OneWoW_Bags.BankGUI:RefreshLayout()
            end
            if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.RefreshLayout then
                OneWoW_Bags.GuildBankGUI:RefreshLayout()
            end
        end,
    })
    Settings.itemSortBtns = itemSortBtns
    sortY = itemSortFinalY - 8
    sortContainer:SetHeight(math.abs(sortY) + 4)
    yOffset = yOffset - math.abs(sortY) - 4 - 15

    yOffset = OneWoW_GUI:CreateSection(scrollContent, { title = L["SECTION_CATEGORIES"] or "Categories", yOffset = yOffset })

    local catContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    catContainer:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 10, yOffset)
    catContainer:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -10, yOffset)
    catContainer:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    catContainer:SetBackdropColor(T("BG_SECONDARY"))
    catContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local catY = -10
    catY, _, _ = OneWoW_GUI:CreateToggleRow(catContainer, {
        yOffset = catY,
        label = L["SETTING_INVENTORY_SLOTS"] or "Split by Equipment Slot",
        description = L["DESC_INVENTORY_SLOTS"] or "Split Weapons and Armor into individual equipment slots (Head, Chest, Hands, etc.)",
        isEnabled = true,
        value = db.global.enableInventorySlots,
        onLabel = L["TOGGLE_ON"],
        offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            db.global.enableInventorySlots = newVal
            if OneWoW_Bags.Categories then OneWoW_Bags.Categories:InvalidateCache() end
            if GUI.RefreshLayout then GUI:RefreshLayout() end
        end,
    })

    catY, _, _ = OneWoW_GUI:CreateToggleRow(catContainer, {
        yOffset = catY,
        label = L["SETTING_COMPACT_CATEGORIES"] or "Compact Categories",
        description = L["DESC_COMPACT_CATEGORIES"] or "Place small categories side by side to save vertical space.",
        isEnabled = true,
        value = db.global.compactCategories,
        onLabel = L["TOGGLE_ON"],
        offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            db.global.compactCategories = newVal
            if GUI.RefreshLayout then GUI:RefreshLayout() end
        end,
    })
    catContainer:SetHeight(math.abs(catY) + 4)
    yOffset = yOffset - math.abs(catY) - 4 - 15

    yOffset = OneWoW_GUI:CreateSection(scrollContent, { title = L["SECTION_BEHAVIOR"], yOffset = yOffset })

    local behaviorContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    behaviorContainer:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 10, yOffset)
    behaviorContainer:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -10, yOffset)
    behaviorContainer:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    behaviorContainer:SetBackdropColor(T("BG_SECONDARY"))
    behaviorContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local behY = -10
    behY, _, _ = OneWoW_GUI:CreateToggleRow(behaviorContainer, {
        yOffset = behY,
        label = L["SETTING_AUTO_OPEN"],
        description = L["DESC_AUTO_OPEN"],
        isEnabled = true,
        value = db.global.autoOpen,
        onLabel = L["TOGGLE_ON"],
        offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            db.global.autoOpen = newVal
        end,
    })

    behY, _, _ = OneWoW_GUI:CreateToggleRow(behaviorContainer, {
        yOffset = behY,
        label = L["SETTING_AUTO_CLOSE"],
        description = L["DESC_AUTO_CLOSE"],
        isEnabled = true,
        value = db.global.autoClose,
        onLabel = L["TOGGLE_ON"],
        offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            db.global.autoClose = newVal
        end,
    })

    behY, _, _ = OneWoW_GUI:CreateToggleRow(behaviorContainer, {
        yOffset = behY,
        label = L["SETTING_AUTO_OPEN_WITH_BANK"],
        description = L["DESC_AUTO_OPEN_WITH_BANK"],
        isEnabled = true,
        value = db.global.autoOpenWithBank,
        onLabel = L["TOGGLE_ON"],
        offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            db.global.autoOpenWithBank = newVal
        end,
    })

    behY, _, _ = OneWoW_GUI:CreateToggleRow(behaviorContainer, {
        yOffset = behY,
        label = L["SETTING_LOCK"],
        description = L["DESC_LOCK"],
        isEnabled = true,
        value = db.global.locked,
        onLabel = L["TOGGLE_ON"],
        offLabel = L["TOGGLE_OFF"],
        onValueChange = function(newVal)
            db.global.locked = newVal
        end,
    })
    behaviorContainer:SetHeight(math.abs(behY) + 4)
    yOffset = yOffset - math.abs(behY) - 4 - 15

    if _G.OneWoW then
        yOffset = OneWoW_GUI:CreateSection(scrollContent, { title = L["SECTION_INTEGRATION"], yOffset = yOffset })

        local intContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        intContainer:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 10, yOffset)
        intContainer:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -10, yOffset)
        intContainer:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
        intContainer:SetBackdropColor(T("BG_SECONDARY"))
        intContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local intY = -10
        local overlayEnabled = false
        if _G.OneWoW.SettingsFeatureRegistry then
            overlayEnabled = _G.OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", "general")
        end

        intY, _, _ = OneWoW_GUI:CreateToggleRow(intContainer, {
            yOffset = intY,
            label = L["OVERLAY_SECTION"],
            description = L["DESC_OVERLAY"],
            isEnabled = true,
            value = overlayEnabled,
            onLabel = L["TOGGLE_ON"],
            offLabel = L["TOGGLE_OFF"],
            onValueChange = function(newVal)
                if not _G.OneWoW or not _G.OneWoW.SettingsFeatureRegistry then return end
                _G.OneWoW.SettingsFeatureRegistry:SetEnabled("overlays", "general", newVal)
                _G.OneWoW.OverlayEngine:Refresh()
            end,
        })
        intContainer:SetHeight(math.abs(intY) + 4)
        yOffset = yOffset - math.abs(intY) - 4 - 15
    end

    scrollContent:SetHeight(math.abs(yOffset) + 40)

    isCreated = true
    return settingsFrame
end

function Settings:UpdateSizeButtons(btns)
    if not btns then btns = Settings.sizeBtns end
    if not btns then return end
    if btns.SetActiveByValue then
        local size = OneWoW_Bags.db and OneWoW_Bags.db.global.iconSize or 3
        btns.SetActiveByValue(size)
    end
end

function Settings:UpdateItemSortButtons(btns)
    if not btns then btns = Settings.itemSortBtns end
    if not btns then return end
    if btns.SetActiveByValue then
        local sortMode = OneWoW_Bags.db and OneWoW_Bags.db.global.itemSort or "default"
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
end
