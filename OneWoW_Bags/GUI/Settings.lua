local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.Settings = {}
local Settings = OneWoW_Bags.Settings
local settingsFrame = nil
local isCreated = false
local OneWoW_GUI = OneWoW_Bags.GUILib

local function T(key)
    if OneWoW_GUI then
        return OneWoW_GUI:GetThemeColor(key)
    end
    if OneWoW_Bags.Constants and OneWoW_Bags.Constants.THEME and OneWoW_Bags.Constants.THEME[key] then
        return unpack(OneWoW_Bags.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if OneWoW_GUI then
        return OneWoW_GUI:GetSpacing(key)
    end
    if OneWoW_Bags.Constants and OneWoW_Bags.Constants.SPACING then
        return OneWoW_Bags.Constants.SPACING[key] or 8
    end
    return 8
end

function Settings:Create()
    if isCreated then return settingsFrame end

    local GUI = OneWoW_Bags.GUI
    local Constants = OneWoW_Bags.Constants
    local L = OneWoW_Bags.L
    local db = OneWoW_Bags.db

    if OneWoW_GUI then
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
            end,
        })
        Settings.sizeBtns = sizeBtns
        bagYOffset = sizeFinalY - 10

        local sortLabel = bagSettingsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sortLabel:SetPoint("TOPLEFT", 15, bagYOffset)
        sortLabel:SetText(L["SETTING_CATEGORY_SORT"])
        sortLabel:SetTextColor(T("ACCENT_PRIMARY"))
        bagYOffset = bagYOffset - 22

        local sortItems = {
            { text = L["SORT_PRIORITY"], value = "priority", isActive = (db.global.categorySort == "priority") },
            { text = L["SORT_ALPHABETICAL"], value = "alphabetical", isActive = (db.global.categorySort == "alphabetical") },
        }

        local sortBtns, sortFinalY = OneWoW_GUI:CreateFitFrameButtons(bagSettingsContainer, {
            yOffset = bagYOffset,
            items = sortItems,
            height = 24,
            gap = 8,
            marginX = 15,
            width = 500,
            onSelect = function(value)
                db.global.categorySort = value
                if GUI.RefreshLayout then GUI:RefreshLayout() end
            end,
        })
        Settings.sortBtns = sortBtns
        bagYOffset = sortFinalY - 10

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
    else
        settingsFrame = CreateFrame("Frame", "OneWoW_BagsSettingsWindow", UIParent, "BackdropTemplate")
        settingsFrame:SetSize(520, 680)
        settingsFrame:SetPoint("CENTER")
        settingsFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        settingsFrame:SetBackdropColor(T("BG_PRIMARY"))
        settingsFrame:SetBackdropBorderColor(T("BORDER_DEFAULT"))
        settingsFrame:SetFrameStrata("DIALOG")
        settingsFrame:SetMovable(true)
        settingsFrame:EnableMouse(true)
        settingsFrame:RegisterForDrag("LeftButton")
        settingsFrame:SetScript("OnDragStart", settingsFrame.StartMoving)
        settingsFrame:SetScript("OnDragStop", settingsFrame.StopMovingOrSizing)
        settingsFrame:SetClampedToScreen(true)
        settingsFrame:Hide()
        tinsert(UISpecialFrames, "OneWoW_BagsSettingsWindow")

        local titleBar = CreateFrame("Frame", nil, settingsFrame, "BackdropTemplate")
        titleBar:SetHeight(S("LG") + S("XS"))
        titleBar:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", S("XS"), -S("XS"))
        titleBar:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -S("XS"), -S("XS"))
        titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        titleBar:SetBackdropColor(T("TITLEBAR_BG"))

        local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
        titleText:SetText(L["SETTINGS_TITLE"])
        titleText:SetTextColor(T("TEXT_PRIMARY"))

        local closeBtn = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
        closeBtn:SetSize(20, 20)
        closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -S("XS") / 2, 0)
        closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        closeBtn.text:SetPoint("CENTER")
        closeBtn.text:SetText("X")
        closeBtn:SetScript("OnClick", function() settingsFrame:Hide() end)

        local infoText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        infoText:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", S("SM"), -(S("XS") + S("LG") + S("XS") + S("XS")))
        infoText:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -S("SM"), 0)
        infoText:SetJustifyH("LEFT")
        infoText:SetWordWrap(true)
        infoText:SetText(L["GUI_NOT_INSTALLED"])
        infoText:SetTextColor(T("TEXT_SECONDARY"))
    end

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

function Settings:UpdateSortButtons(btns)
    if not btns then btns = Settings.sortBtns end
    if not btns then return end
    if btns.SetActiveByValue then
        local sortMode = OneWoW_Bags.db and OneWoW_Bags.db.global.categorySort or "priority"
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
