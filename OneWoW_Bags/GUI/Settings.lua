local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.Settings = {}
local Settings = OneWoW_Bags.Settings
local settingsFrame = nil
local isCreated = false
local OneWoW_GUI = OneWoW_Bags.GUILib

local function T(key)
    return OneWoW_GUI:GetThemeColor(key)
end

local function S(key)
    return OneWoW_GUI:GetSpacing(key)
end

function Settings:Create()
    if isCreated then return settingsFrame end

    local GUI = OneWoW_Bags.GUI
    local Constants = OneWoW_Bags.Constants
    local L = OneWoW_Bags.L
    local db = OneWoW_Bags.db

    local dialog = OneWoW_GUI:CreateDialog({
        name = "OneWoW_BagsSettingsWindow",
        title = L["SETTINGS_TITLE"],
        width = 520,
        height = 780,
        strata = "DIALOG",
        movable = true,
        escClose = true,
        showScrollFrame = true,
    })

    settingsFrame = dialog.frame
    local scrollContent = dialog.scrollContent

    local yOffset = OneWoW_GUI:CreateSettingsPanel(scrollContent, { yOffset = -15 })

    yOffset = yOffset - 15

    local bagSettingsContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    bagSettingsContainer:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 10, yOffset)
    bagSettingsContainer:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -10, yOffset)
    bagSettingsContainer:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    bagSettingsContainer:SetBackdropColor(T("BG_SECONDARY"))
    bagSettingsContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local bagYOffset = -12

    local cbRarity = OneWoW_GUI:CreateCheckbox(bagSettingsContainer, { label = L["SETTING_RARITY_COLOR"] })
    cbRarity:SetPoint("TOPLEFT", 10, bagYOffset)
    cbRarity:SetChecked(db.global.rarityColor)
    cbRarity:SetScript("OnClick", function(self)
        db.global.rarityColor = self:GetChecked()
        if OneWoW_Bags.BagSet and OneWoW_Bags.BagSet.isBuilt then
            OneWoW_Bags.BagSet:UpdateAllSlots()
        end
        if GUI.RefreshLayout then GUI:RefreshLayout() end
    end)
    bagYOffset = bagYOffset - 28

    local cbNewItems = OneWoW_GUI:CreateCheckbox(bagSettingsContainer, { label = L["SETTING_SHOW_NEW"] })
    cbNewItems:SetPoint("TOPLEFT", 10, bagYOffset)
    cbNewItems:SetChecked(db.global.showNewItems)
    cbNewItems:SetScript("OnClick", function(self)
        db.global.showNewItems = self:GetChecked()
        if OneWoW_Bags.BagSet and OneWoW_Bags.BagSet.isBuilt then
            OneWoW_Bags.BagSet:UpdateAllSlots()
        end
        if GUI.RefreshLayout then GUI:RefreshLayout() end
    end)
    bagYOffset = bagYOffset - 28

    local cbAutoOpen = OneWoW_GUI:CreateCheckbox(bagSettingsContainer, { label = L["SETTING_AUTO_OPEN"] })
    cbAutoOpen:SetPoint("TOPLEFT", 10, bagYOffset)
    cbAutoOpen:SetChecked(db.global.autoOpen)
    cbAutoOpen:SetScript("OnClick", function(self)
        db.global.autoOpen = self:GetChecked()
    end)
    bagYOffset = bagYOffset - 28

    local cbAutoClose = OneWoW_GUI:CreateCheckbox(bagSettingsContainer, { label = L["SETTING_AUTO_CLOSE"] })
    cbAutoClose:SetPoint("TOPLEFT", 10, bagYOffset)
    cbAutoClose:SetChecked(db.global.autoClose)
    cbAutoClose:SetScript("OnClick", function(self)
        db.global.autoClose = self:GetChecked()
    end)
    bagYOffset = bagYOffset - 28

    local cbBagsBar = OneWoW_GUI:CreateCheckbox(bagSettingsContainer, { label = L["SETTING_SHOW_BAGS_BAR"] })
    cbBagsBar:SetPoint("TOPLEFT", 10, bagYOffset)
    cbBagsBar:SetChecked(db.global.showBagsBar)
    cbBagsBar:SetScript("OnClick", function(self)
        db.global.showBagsBar = self:GetChecked()
        if OneWoW_Bags.GUI.UpdateBagsBarVisibility then
            OneWoW_Bags.GUI:UpdateBagsBarVisibility()
        end
    end)
    bagYOffset = bagYOffset - 28

    local cbLock = OneWoW_GUI:CreateCheckbox(bagSettingsContainer, { label = L["SETTING_LOCK"] })
    cbLock:SetPoint("TOPLEFT", 10, bagYOffset)
    cbLock:SetChecked(db.global.locked)
    cbLock:SetScript("OnClick", function(self)
        db.global.locked = self:GetChecked()
    end)
    bagYOffset = bagYOffset - 28

    local cbBank = OneWoW_GUI:CreateCheckbox(bagSettingsContainer, { label = L["SETTING_ENABLE_BANK"] })
    cbBank:SetPoint("TOPLEFT", 10, bagYOffset)
    cbBank:SetChecked(db.global.enableBankUI)
    cbBank:SetScript("OnClick", function(self)
        db.global.enableBankUI = self:GetChecked()
        if not db.global.enableBankUI then
            OneWoW_Bags:RestoreBankFrame()
            OneWoW_Bags:RestoreGuildBankFrame()
            if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI:IsShown() then
                OneWoW_Bags.BankGUI:Hide()
            end
            if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI:IsShown() then
                OneWoW_Bags.GuildBankGUI:Hide()
            end
        end
    end)
    bagYOffset = bagYOffset - 28

    local cbScrollBar = OneWoW_GUI:CreateCheckbox(bagSettingsContainer, { label = L["SETTING_SHOW_SCROLLBAR"] or "Show Scroll Bar" })
    cbScrollBar:SetPoint("TOPLEFT", 10, bagYOffset)
    cbScrollBar:SetChecked(not db.global.hideScrollBar)
    cbScrollBar:SetScript("OnClick", function(self)
        db.global.hideScrollBar = not self:GetChecked()
        local wasShown = OneWoW_Bags.GUI and OneWoW_Bags.GUI:IsShown()
        if OneWoW_Bags.GUI then
            OneWoW_Bags.GUI:FullReset()
            if wasShown then C_Timer.After(0.1, function() OneWoW_Bags.GUI:Show() end) end
        end
    end)
    bagYOffset = bagYOffset - 35

    local sizeLabel = bagSettingsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 15, bagYOffset)
    sizeLabel:SetText(L["SETTING_ICON_SIZE"])
    sizeLabel:SetTextColor(T("ACCENT_PRIMARY"))
    bagYOffset = bagYOffset - 22

    local sizeItems = {
        { text = L["ICON_SIZE_S"], value = 1, isActive = (db.global.iconSize == 1) },
        { text = L["ICON_SIZE_M"], value = 2, isActive = (db.global.iconSize == 2) },
        { text = L["ICON_SIZE_L"], value = 3, isActive = (db.global.iconSize == 3) },
        { text = L["ICON_SIZE_XL"], value = 4, isActive = (db.global.iconSize == 4) },
    }

    local sizeBtns, sizeFinalY = OneWoW_GUI:CreateFitFrameButtons(bagSettingsContainer, {
        yOffset = bagYOffset,
        items = sizeItems,
        height = 24,
        gap = 8,
        marginX = 15,
        width = 500,
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
    bagYOffset = sizeFinalY - 10

    local itemSortLabel = bagSettingsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemSortLabel:SetPoint("TOPLEFT", 15, bagYOffset)
    itemSortLabel:SetText(L["SETTING_ITEM_SORT"] or "Item Sort")
    itemSortLabel:SetTextColor(T("ACCENT_PRIMARY"))
    bagYOffset = bagYOffset - 22

    local itemSortItems = {
        { text = L["SORT_NAME"] or "Name", value = "name", isActive = (db.global.itemSort == "name") },
        { text = L["SORT_RARITY"] or "Rarity", value = "rarity", isActive = (db.global.itemSort == "rarity") },
        { text = L["SORT_ITEM_LEVEL"] or "Item Level", value = "ilvl", isActive = (db.global.itemSort == "ilvl") },
        { text = L["SORT_RECENT"] or "Recent First", value = "recent", isActive = (db.global.itemSort == "recent") },
        { text = L["SORT_TYPE"] or "Type", value = "type", isActive = (db.global.itemSort == "type") },
    }

    local itemSortBtns, itemSortFinalY = OneWoW_GUI:CreateFitFrameButtons(bagSettingsContainer, {
        yOffset = bagYOffset,
        items = itemSortItems,
        height = 24,
        gap = 8,
        marginX = 15,
        width = 500,
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
    bagYOffset = itemSortFinalY - 10

    if _G.OneWoW then
        local overlayLabel = bagSettingsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        overlayLabel:SetPoint("TOPLEFT", 15, bagYOffset)
        overlayLabel:SetText(L["OVERLAY_SECTION"])
        overlayLabel:SetTextColor(T("ACCENT_PRIMARY"))
        bagYOffset = bagYOffset - 22

        local overlayDesc = bagSettingsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        overlayDesc:SetPoint("TOPLEFT", bagSettingsContainer, "TOPLEFT", 15, bagYOffset)
        overlayDesc:SetPoint("TOPRIGHT", bagSettingsContainer, "TOPRIGHT", -10, bagYOffset)
        overlayDesc:SetJustifyH("LEFT")
        overlayDesc:SetWordWrap(true)
        overlayDesc:SetText(L["OVERLAY_SECTION_DESC"])
        overlayDesc:SetTextColor(T("TEXT_SECONDARY"))
        bagYOffset = bagYOffset - overlayDesc:GetStringHeight() - 12

        local function UpdateOverlayButton(btn)
            if not _G.OneWoW or not _G.OneWoW.SettingsFeatureRegistry then return end
            local isEnabled = _G.OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", "general")
            if isEnabled then
                btn.text:SetText(L["OVERLAY_TOGGLE_ON"])
                btn:SetBackdropColor(T("BG_ACTIVE"))
                btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
                btn.text:SetTextColor(T("TEXT_ACCENT"))
            else
                btn.text:SetText(L["OVERLAY_TOGGLE_OFF"])
                btn:SetBackdropColor(T("BTN_NORMAL"))
                btn:SetBackdropBorderColor(T("BTN_BORDER"))
                btn.text:SetTextColor(T("TEXT_PRIMARY"))
            end
            btn:SetFitText(btn.text:GetText())
        end

        local overlayBtn = OneWoW_GUI:CreateFitTextButton(bagSettingsContainer, { text = L["OVERLAY_TOGGLE_ON"], height = 24 })
        overlayBtn:SetPoint("TOPLEFT", 15, bagYOffset)
        overlayBtn:SetScript("OnClick", function(self)
            if not _G.OneWoW or not _G.OneWoW.SettingsFeatureRegistry then return end
            local nowEnabled = _G.OneWoW.SettingsFeatureRegistry:IsEnabled("overlays", "general")
            _G.OneWoW.SettingsFeatureRegistry:SetEnabled("overlays", "general", not nowEnabled)
            _G.OneWoW.OverlayEngine:Refresh()
            UpdateOverlayButton(self)
        end)
        overlayBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["OVERLAY_SECTION"])
            GameTooltip:AddLine(L["OVERLAY_SECTION_DESC"], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        overlayBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        UpdateOverlayButton(overlayBtn)
        bagYOffset = bagYOffset - 35
    end

    bagSettingsContainer:SetHeight(math.abs(bagYOffset) + 12)

    yOffset = yOffset - (math.abs(bagYOffset) + 12) - 15

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
        local sortMode = OneWoW_Bags.db and OneWoW_Bags.db.global.itemSort or "name"
        btns.SetActiveByValue(sortMode)
    end
end

function Settings:Toggle()
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
