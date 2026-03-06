local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local selectedCharKey = nil
local selectedSpecName = nil
local showAllBars = false

local BAR_NAMES = {
    [1]  = "AB_PAGE_1",
    [2]  = "AB_PAGE_2",
    [3]  = "AB_ACTION_BAR_5",
    [4]  = "AB_ACTION_BAR_4",
    [5]  = "AB_ACTION_BAR_3",
    [6]  = "AB_ACTION_BAR_2",
    [7]  = "AB_STANCE_BAR_1",
    [8]  = "AB_STANCE_BAR_2",
    [9]  = "AB_STANCE_BAR_3",
    [10] = "AB_STANCE_BAR_4",
    [11] = "AB_SKYRIDING_BAR",
    [12] = "AB_BONUS_BAR_6",
    [13] = "AB_ACTION_BAR_6",
    [14] = "AB_ACTION_BAR_7",
    [15] = "AB_ACTION_BAR_8",
}
local BAR_DISPLAY_ORDER = {1, 2, 6, 5, 4, 3, 13, 14, 15, 7, 8, 9, 10, 11, 12}

local function ShowRestoreBarDialog(charKey, sourceBarNumber, specName, parent)
    local dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dialog:SetSize(400, 220)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    dialog:SetBackdropColor(T("BG_PRIMARY"))
    dialog:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    dialog:EnableMouse(true)

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -15)
    local barName = L[BAR_NAMES[sourceBarNumber]] or string.format(L["AB_LABEL_BAR"], sourceBarNumber)
    title:SetText(string.format(L["AB_RESTORE_SINGLE"], barName))
    title:SetTextColor(T("ACCENT_PRIMARY"))

    local instructionText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructionText:SetPoint("TOP", title, "BOTTOM", 0, -15)
    instructionText:SetText(L["AB_SELECT_TARGET_BAR"])
    instructionText:SetTextColor(T("TEXT_PRIMARY"))

    local selectedTargetBar = sourceBarNumber

    local dropdown = CreateFrame("Frame", "OneWoWRestoreBarDropdown", dialog, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOP", instructionText, "BOTTOM", 0, -10)
    UIDropDownMenu_SetWidth(dropdown, 150)
    UIDropDownMenu_SetText(dropdown, string.format(L["AB_LABEL_BAR"], selectedTargetBar))

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, barNumber in ipairs(BAR_DISPLAY_ORDER) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = L[BAR_NAMES[barNumber]] or string.format(L["AB_LABEL_BAR"], barNumber)
            info.value = barNumber
            info.func = function(btn)
                selectedTargetBar = btn.value
                UIDropDownMenu_SetText(dropdown, L[BAR_NAMES[btn.value]] or string.format(L["AB_LABEL_BAR"], btn.value))
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local restoreBtn = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    restoreBtn:SetSize(120, 30)
    restoreBtn:SetPoint("BOTTOM", dialog, "BOTTOM", -65, 15)
    restoreBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    restoreBtn:SetBackdropColor(0.2, 0.6, 0.2, 1.0)
    restoreBtn:SetBackdropBorderColor(0.3, 0.8, 0.3, 1.0)

    local restoreBtnText = restoreBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    restoreBtnText:SetPoint("CENTER")
    restoreBtnText:SetText(L["AB_LABEL_RESTORE"])
    restoreBtnText:SetTextColor(1, 1, 1)

    restoreBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.7, 0.3, 1.0)
    end)
    restoreBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.6, 0.2, 1.0)
    end)
    restoreBtn:SetScript("OnClick", function()
        if ns.ActionBarsModule and ns.ActionBarsModule.RestoreSingleActionBar then
            ns.ActionBarsModule:RestoreSingleActionBar(charKey, sourceBarNumber, selectedTargetBar, specName)
        end
        dialog:Hide()
    end)

    local cancelBtn = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    cancelBtn:SetSize(120, 30)
    cancelBtn:SetPoint("BOTTOM", dialog, "BOTTOM", 65, 15)
    cancelBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    cancelBtn:SetBackdropColor(0.6, 0.2, 0.2, 1.0)
    cancelBtn:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)

    local cancelBtnText = cancelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cancelBtnText:SetPoint("CENTER")
    cancelBtnText:SetText(L["AB_LABEL_CANCEL"])
    cancelBtnText:SetTextColor(1, 1, 1)

    cancelBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.7, 0.3, 0.3, 1.0)
    end)
    cancelBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.6, 0.2, 0.2, 1.0)
    end)
    cancelBtn:SetScript("OnClick", function()
        dialog:Hide()
    end)

    dialog:Show()
end

local function ShowRestoreAllDialog(charKey, specName, charName)
    local dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dialog:SetSize(420, 200)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    dialog:SetBackdropColor(T("BG_PRIMARY"))
    dialog:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    dialog:EnableMouse(true)

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -15)
    title:SetText(L["AB_DIALOG_RESTORE_ALL_TITLE"])
    title:SetTextColor(T("ACCENT_PRIMARY"))

    local warningText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warningText:SetPoint("TOP", title, "BOTTOM", 0, -15)
    warningText:SetWidth(380)
    warningText:SetText(string.format(L["AB_DIALOG_RESTORE_ALL"], charName .. " - " .. specName))
    warningText:SetTextColor(T("TEXT_PRIMARY"))
    warningText:SetJustifyH("CENTER")

    local restoreBtn = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    restoreBtn:SetSize(140, 32)
    restoreBtn:SetPoint("BOTTOM", dialog, "BOTTOM", -75, 15)
    restoreBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    restoreBtn:SetBackdropColor(0.6, 0.2, 0.2, 1.0)
    restoreBtn:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)

    local restoreBtnText = restoreBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    restoreBtnText:SetPoint("CENTER")
    restoreBtnText:SetText(L["AB_BUTTON_RESTORE_ALL"])
    restoreBtnText:SetTextColor(1, 1, 1)

    restoreBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.7, 0.3, 0.3, 1.0)
    end)
    restoreBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.6, 0.2, 0.2, 1.0)
    end)
    restoreBtn:SetScript("OnClick", function()
        if ns.ActionBarsModule and ns.ActionBarsModule.RestoreAllActionBars then
            ns.ActionBarsModule:RestoreAllActionBars(charKey, specName)
        end
        dialog:Hide()
    end)

    local cancelBtn = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    cancelBtn:SetSize(140, 32)
    cancelBtn:SetPoint("BOTTOM", dialog, "BOTTOM", 75, 15)
    cancelBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    cancelBtn:SetBackdropColor(T("BG_TERTIARY"))
    cancelBtn:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local cancelBtnText = cancelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cancelBtnText:SetPoint("CENTER")
    cancelBtnText:SetText(L["AB_LABEL_CANCEL"])
    cancelBtnText:SetTextColor(T("TEXT_PRIMARY"))

    cancelBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
    end)
    cancelBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
    end)
    cancelBtn:SetScript("OnClick", function()
        dialog:Hide()
    end)

    dialog:Show()
end

local function ShowRestoreMacrosDialog(charKey, charName, accountCount, charCount)
    local dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dialog:SetSize(420, 240)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    dialog:SetBackdropColor(T("BG_PRIMARY"))
    dialog:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    dialog:EnableMouse(true)

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -15)
    title:SetText(L["AB_DIALOG_RESTORE_MACROS_TITLE"])
    title:SetTextColor(T("ACCENT_PRIMARY"))

    local infoText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOP", title, "BOTTOM", 0, -15)
    infoText:SetWidth(380)
    infoText:SetText(string.format(L["AB_DIALOG_RESTORE_MACROS"], charName))
    infoText:SetTextColor(T("TEXT_PRIMARY"))
    infoText:SetJustifyH("CENTER")

    local accountBtn = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    accountBtn:SetSize(180, 30)
    accountBtn:SetPoint("TOP", infoText, "BOTTOM", -95, -20)
    accountBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    accountBtn:SetBackdropColor(0.4, 0.2, 0.5, 1.0)
    accountBtn:SetBackdropBorderColor(0.6, 0.4, 0.7, 1.0)

    local accountBtnText = accountBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    accountBtnText:SetPoint("CENTER")
    accountBtnText:SetText(string.format(L["AB_BUTTON_ACCOUNT_ONLY"], accountCount))
    accountBtnText:SetTextColor(1, 1, 1)

    accountBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.5, 0.3, 0.6, 1.0)
    end)
    accountBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.4, 0.2, 0.5, 1.0)
    end)
    accountBtn:SetScript("OnClick", function()
        if ns.ActionBarsModule then
            ns.ActionBarsModule:RestoreMacros(charKey, "account")
        end
        dialog:Hide()
    end)

    local charBtn = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    charBtn:SetSize(180, 30)
    charBtn:SetPoint("TOP", infoText, "BOTTOM", 95, -20)
    charBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    charBtn:SetBackdropColor(0.4, 0.2, 0.5, 1.0)
    charBtn:SetBackdropBorderColor(0.6, 0.4, 0.7, 1.0)

    local charBtnText = charBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    charBtnText:SetPoint("CENTER")
    charBtnText:SetText(string.format(L["AB_BUTTON_CHARACTER_ONLY"], charCount))
    charBtnText:SetTextColor(1, 1, 1)

    charBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.5, 0.3, 0.6, 1.0)
    end)
    charBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.4, 0.2, 0.5, 1.0)
    end)
    charBtn:SetScript("OnClick", function()
        if ns.ActionBarsModule then
            ns.ActionBarsModule:RestoreMacros(charKey, "character")
        end
        dialog:Hide()
    end)

    local bothBtn = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    bothBtn:SetSize(180, 30)
    bothBtn:SetPoint("TOP", accountBtn, "BOTTOM", 0, -8)
    bothBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bothBtn:SetBackdropColor(0.2, 0.6, 0.2, 1.0)
    bothBtn:SetBackdropBorderColor(0.3, 0.8, 0.3, 1.0)

    local bothBtnText = bothBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bothBtnText:SetPoint("CENTER")
    bothBtnText:SetText(L["AB_BUTTON_BOTH"])
    bothBtnText:SetTextColor(1, 1, 1)

    bothBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.7, 0.3, 1.0)
    end)
    bothBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.6, 0.2, 1.0)
    end)
    bothBtn:SetScript("OnClick", function()
        if ns.ActionBarsModule then
            ns.ActionBarsModule:RestoreMacros(charKey, "both")
        end
        dialog:Hide()
    end)

    local cancelBtn = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    cancelBtn:SetSize(180, 30)
    cancelBtn:SetPoint("TOP", charBtn, "BOTTOM", 0, -8)
    cancelBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    cancelBtn:SetBackdropColor(T("BG_TERTIARY"))
    cancelBtn:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local cancelBtnText = cancelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cancelBtnText:SetPoint("CENTER")
    cancelBtnText:SetText(L["AB_LABEL_CANCEL"])
    cancelBtnText:SetTextColor(T("TEXT_PRIMARY"))

    cancelBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
    end)
    cancelBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
    end)
    cancelBtn:SetScript("OnClick", function()
        dialog:Hide()
    end)

    dialog:Show()
end

function ns.UI.CreateActionBarsTab(parent)
    local contentPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    contentPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    contentPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    contentPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    contentPanel:SetBackdropColor(T("BG_PRIMARY"))
    contentPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    parent.contentPanel = contentPanel

    -- ACTION BARS SUB-TAB CONTENT (existing code adapted)
    local controlPanel = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
    controlPanel:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 5, -5)
    controlPanel:SetPoint("TOPRIGHT", contentPanel, "TOPRIGHT", -5, -5)
    controlPanel:SetHeight(85)
    controlPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    controlPanel:SetBackdropColor(T("BG_SECONDARY"))
    controlPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local controlTitle = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    controlTitle:SetPoint("TOP", controlPanel, "TOP", 0, -8)
    local currentSpec = select(2, GetSpecializationInfo(GetSpecialization())) or L["Unknown"]
    controlTitle:SetText(UnitName("player") .. " - " .. currentSpec)
    controlTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local statusActionBars = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusActionBars:SetPoint("BOTTOM", controlPanel, "BOTTOM", -180, 30)
    statusActionBars:SetTextColor(T("TEXT_SECONDARY"))

    local statusKeybinds = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusKeybinds:SetPoint("BOTTOM", controlPanel, "BOTTOM", 0, 30)
    statusKeybinds:SetTextColor(T("TEXT_SECONDARY"))

    local statusMacros = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusMacros:SetPoint("BOTTOM", controlPanel, "BOTTOM", 180, 30)
    statusMacros:SetTextColor(T("TEXT_SECONDARY"))

    local function UpdateControlPanelStatus()
        local playerName = UnitName("player")
        local realmName = GetRealmName()
        local charKey = playerName .. "-" .. realmName
        local charData = ns.ActionBarsModule and ns.ActionBarsModule:GetCharacterData(charKey)
        local currentSpec = select(2, GetSpecializationInfo(GetSpecialization())) or L["Unknown"]

        local hasActionBars = ns.ActionBarsModule and ns.ActionBarsModule:HasActionBarData(charKey, currentSpec) or false

        local hasKeybinds = charData and charData.keybinds and charData.keybinds.bindings and next(charData.keybinds.bindings) ~= nil

        local hasMacros = false
        if charData and charData.macros then
            hasMacros = (charData.macros.account and next(charData.macros.account)) or (charData.macros.character and next(charData.macros.character))
        end

        statusActionBars:SetText(string.format(L["AB_LABEL_ACTION_BARS"], hasActionBars and L["AB_YES"] or L["AB_NO"]))
        statusKeybinds:SetText(string.format(L["AB_LABEL_KEYBINDS"], hasKeybinds and L["AB_YES"] or L["AB_NO"]))
        statusMacros:SetText(string.format(L["AB_LABEL_MACROS"], hasMacros and L["AB_YES"] or L["AB_NO"]))
    end

    local backupButton = CreateFrame("Button", nil, controlPanel, "BackdropTemplate")
    backupButton:SetSize(120, 28)
    backupButton:SetPoint("BOTTOMLEFT", controlPanel, "BOTTOMLEFT", 10, 6)
    backupButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    backupButton:SetBackdropColor(T("BG_TERTIARY"))
    backupButton:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local backupText = backupButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    backupText:SetPoint("CENTER")
    backupText:SetText(string.format(L["AB_LABEL_BACKUP"], currentSpec))
    backupText:SetTextColor(T("TEXT_PRIMARY"))

    backupButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        backupText:SetTextColor(T("TEXT_ACCENT"))
    end)
    backupButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
        backupText:SetTextColor(T("TEXT_PRIMARY"))
    end)
    backupButton:SetScript("OnClick", function()
        if ns.ActionBarsModule and ns.ActionBarsModule.CollectActionBarsData then
            local charData, specName = ns.ActionBarsModule:CollectActionBarsData()
            if charData and specName then
                UpdateControlPanelStatus()
                if ns.UI.RefreshActionBarsListing then
                    ns.UI.RefreshActionBarsListing(parent)
                end
            end
        end
    end)

    local showAllCheckbox = CreateFrame("CheckButton", nil, controlPanel, "UICheckButtonTemplate")
    showAllCheckbox:SetPoint("BOTTOMRIGHT", controlPanel, "BOTTOMRIGHT", -10, 6)
    showAllCheckbox:SetSize(24, 24)
    showAllCheckbox:SetChecked(showAllBars)

    local checkboxLabel = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkboxLabel:SetPoint("RIGHT", showAllCheckbox, "LEFT", -5, 0)
    checkboxLabel:SetText(L["AB_SHOW_ALL_BARS"])
    checkboxLabel:SetTextColor(T("TEXT_PRIMARY"))

    showAllCheckbox:SetScript("OnClick", function(self)
        showAllBars = self:GetChecked()
        if selectedCharKey and selectedSpecName and ns.UI.ShowActionBarDetails then
            ns.UI.ShowActionBarDetails(parent, selectedCharKey, selectedSpecName)
        end
    end)

    local listingPanel = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
    listingPanel:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -8)
    listingPanel:SetPoint("BOTTOMLEFT", contentPanel, "BOTTOMLEFT", 5, 30)
    listingPanel:SetWidth(280)
    listingPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    listingPanel:SetBackdropColor(T("BG_PRIMARY"))
    listingPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local listingTitle = listingPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listingTitle:SetPoint("TOP", listingPanel, "TOP", 0, -8)
    listingTitle:SetText(L["AB_CHARACTER_LIST"])
    listingTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local listingScrollFrame = CreateFrame("ScrollFrame", nil, listingPanel, "UIPanelScrollFrameTemplate")
    listingScrollFrame:SetPoint("TOPLEFT", listingPanel, "TOPLEFT", 8, -32)
    listingScrollFrame:SetPoint("BOTTOMRIGHT", listingPanel, "BOTTOMRIGHT", -8, 8)

    local scrollBar = listingScrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", listingScrollFrame, "TOPRIGHT", -3, 0)
        scrollBar:SetPoint("BOTTOMRIGHT", listingScrollFrame, "BOTTOMRIGHT", -3, 0)
        scrollBar:SetWidth(8)
        if scrollBar.ScrollUpButton then
            scrollBar.ScrollUpButton:Hide()
            scrollBar.ScrollUpButton:SetAlpha(0)
            scrollBar.ScrollUpButton:EnableMouse(false)
        end
        if scrollBar.ScrollDownButton then
            scrollBar.ScrollDownButton:Hide()
            scrollBar.ScrollDownButton:SetAlpha(0)
            scrollBar.ScrollDownButton:EnableMouse(false)
        end
        if scrollBar.Background then scrollBar.Background:SetColorTexture(T("BG_TERTIARY")) end
        if scrollBar.ThumbTexture then
            scrollBar.ThumbTexture:SetWidth(6)
            scrollBar.ThumbTexture:SetColorTexture(T("ACCENT_PRIMARY"))
        end
    end

    local listingScrollChild = CreateFrame("Frame", nil, listingScrollFrame)
    listingScrollChild:SetWidth(listingScrollFrame:GetWidth() - 20)
    listingScrollChild:SetHeight(400)
    listingScrollFrame:SetScrollChild(listingScrollChild)

    listingScrollFrame:HookScript("OnSizeChanged", function(self, width, height)
        listingScrollChild:SetWidth(width - 20)
    end)

    local detailPanel = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
    detailPanel:SetPoint("TOPLEFT", listingPanel, "TOPRIGHT", 8, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", -5, 30)
    detailPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    detailPanel:SetBackdropColor(T("BG_PRIMARY"))
    detailPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local detailTitle = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailTitle:SetPoint("TOP", detailPanel, "TOP", 0, -8)
    detailTitle:SetText(L["AB_ACTION_BAR_DETAILS"])
    detailTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local detailScrollFrame = CreateFrame("ScrollFrame", nil, detailPanel, "UIPanelScrollFrameTemplate")
    detailScrollFrame:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 8, -32)
    detailScrollFrame:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8, 8)

    local detailScrollBar = detailScrollFrame.ScrollBar
    if detailScrollBar then
        detailScrollBar:ClearAllPoints()
        detailScrollBar:SetPoint("TOPRIGHT", detailScrollFrame, "TOPRIGHT", -3, 0)
        detailScrollBar:SetPoint("BOTTOMRIGHT", detailScrollFrame, "BOTTOMRIGHT", -3, 0)
        detailScrollBar:SetWidth(8)
        if detailScrollBar.ScrollUpButton then
            detailScrollBar.ScrollUpButton:Hide()
            detailScrollBar.ScrollUpButton:SetAlpha(0)
            detailScrollBar.ScrollUpButton:EnableMouse(false)
        end
        if detailScrollBar.ScrollDownButton then
            detailScrollBar.ScrollDownButton:Hide()
            detailScrollBar.ScrollDownButton:SetAlpha(0)
            detailScrollBar.ScrollDownButton:EnableMouse(false)
        end
        if detailScrollBar.Background then detailScrollBar.Background:SetColorTexture(T("BG_TERTIARY")) end
        if detailScrollBar.ThumbTexture then
            detailScrollBar.ThumbTexture:SetWidth(6)
            detailScrollBar.ThumbTexture:SetColorTexture(T("ACCENT_PRIMARY"))
        end
    end

    local detailScrollChild = CreateFrame("Frame", nil, detailScrollFrame)
    detailScrollChild:SetWidth(detailScrollFrame:GetWidth() - 20)
    detailScrollChild:SetHeight(400)
    detailScrollFrame:SetScrollChild(detailScrollChild)

    detailScrollFrame:HookScript("OnSizeChanged", function(self, width, height)
        detailScrollChild:SetWidth(width - 20)
    end)

    local leftStatusBar = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
    leftStatusBar:SetPoint("TOPLEFT", listingPanel, "BOTTOMLEFT", 0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listingPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)
    leftStatusBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    leftStatusBar:SetBackdropColor(T("BG_SECONDARY"))
    leftStatusBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local leftStatusText = leftStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetText(string.format(L["AB_CHARACTERS_COUNT"], 0))
    leftStatusText:SetTextColor(T("TEXT_SECONDARY"))

    local rightStatusBar = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
    rightStatusBar:SetPoint("TOPLEFT", detailPanel, "BOTTOMLEFT", 0, -5)
    rightStatusBar:SetPoint("TOPRIGHT", detailPanel, "BOTTOMRIGHT", 0, -5)
    rightStatusBar:SetHeight(25)
    rightStatusBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    rightStatusBar:SetBackdropColor(T("BG_SECONDARY"))
    rightStatusBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local rightStatusText = rightStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
    rightStatusText:SetText("")
    rightStatusText:SetTextColor(T("TEXT_SECONDARY"))

    parent.controlPanel = controlPanel
    parent.controlTitle = controlTitle
    parent.backupButton = backupButton
    parent.statusActionBars = statusActionBars
    parent.statusKeybinds = statusKeybinds
    parent.statusMacros = statusMacros
    parent.showAllCheckbox = showAllCheckbox
    parent.listingPanel = listingPanel
    parent.listingScrollFrame = listingScrollFrame
    parent.listingScrollChild = listingScrollChild
    parent.detailPanel = detailPanel
    parent.detailTitle = detailTitle
    parent.detailScrollFrame = detailScrollFrame
    parent.detailScrollChild = detailScrollChild
    parent.leftStatusBar = leftStatusBar
    parent.leftStatusText = leftStatusText
    parent.rightStatusBar = rightStatusBar
    parent.rightStatusText = rightStatusText
    parent.UpdateControlPanelStatus = UpdateControlPanelStatus

    C_Timer.After(0.3, function()
        UpdateControlPanelStatus()
    end)

    C_Timer.After(0.5, function()
        if ns.UI.RefreshActionBarsListing then
            ns.UI.RefreshActionBarsListing(parent)
        end
    end)
end

function ns.UI.RefreshActionBarsListing(actionBarsTab)
    if not actionBarsTab or not actionBarsTab.listingScrollChild then return end
    if not ns.ActionBarsModule then return end

    for _, child in ipairs({actionBarsTab.listingScrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local allChars = ns.ActionBarsModule:GetAllCharacters()
    local charList = {}

    for charKey, charData in pairs(allChars) do
        local hasData = ns.ActionBarsModule:HasActionBarData(charKey)
        if hasData then
            table.insert(charList, {key = charKey, data = charData})
        end
    end

    local currentChar = UnitName("player")
    local currentRealm = GetRealmName()
    local currentCharKey = currentChar .. "-" .. currentRealm
    table.sort(charList, function(a, b)
        local aIsCurrent = (a.key == currentCharKey)
        local bIsCurrent = (b.key == currentCharKey)
        if aIsCurrent and not bIsCurrent then return true end
        if bIsCurrent and not aIsCurrent then return false end
        return (a.data.name or "") < (b.data.name or "")
    end)

    local yOffset = -5
    local bubbleHeight = 34
    local bubbleGap = 3

    for _, charEntry in ipairs(charList) do
        local charKey = charEntry.key
        local charData = charEntry.data

        local charBubble = CreateFrame("Frame", nil, actionBarsTab.listingScrollChild, "BackdropTemplate")
        charBubble:SetPoint("TOPLEFT", actionBarsTab.listingScrollChild, "TOPLEFT", 8, yOffset)
        charBubble:SetPoint("TOPRIGHT", actionBarsTab.listingScrollChild, "TOPRIGHT", -10, yOffset)
        charBubble:SetHeight(bubbleHeight)
        charBubble:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        charBubble:SetBackdropColor(T("BG_TERTIARY"))
        charBubble:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local indicator = charBubble:CreateTexture(nil, "ARTWORK")
        indicator:SetSize(12, 12)
        indicator:SetPoint("LEFT", charBubble, "LEFT", 4, 0)
        indicator:SetTexture("Interface\\Common\\Indicator-Green")
        if selectedCharKey == charKey then
            indicator:SetAlpha(1.0)
        else
            indicator:SetAlpha(0.3)
        end

        local classIcon = charBubble:CreateTexture(nil, "ARTWORK")
        classIcon:SetSize(20, 20)
        classIcon:SetPoint("LEFT", indicator, "RIGHT", 4, 0)
        local classIconPath = "Interface\\Icons\\ClassIcon_" .. (charData.class or "Warrior")
        classIcon:SetTexture(classIconPath)

        local charName = charBubble:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        charName:SetPoint("LEFT", classIcon, "RIGHT", 6, 0)
        local classColor = RAID_CLASS_COLORS[charData.class]
        if classColor then
            charName:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            charName:SetTextColor(T("TEXT_PRIMARY"))
        end
        charName:SetText(charData.name or charKey)

        local specs = ns.ActionBarsModule:GetCharacterSpecs(charKey)
        local specXOffset = -4
        for i = #specs, 1, -1 do
            local specName = specs[i]
            local specData = ns.ActionBarsModule:GetSpecData(charKey, specName)
            local hasSpecData = ns.ActionBarsModule:HasActionBarData(charKey, specName)

            local specBtn = CreateFrame("Button", nil, charBubble, "BackdropTemplate")
            specBtn:SetSize(24, 24)
            specBtn:SetPoint("RIGHT", charBubble, "RIGHT", specXOffset, 0)
            specBtn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            specBtn:SetBackdropColor(T("BG_SECONDARY"))
            specBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))

            local specIcon = specBtn:CreateTexture(nil, "ARTWORK")
            specIcon:SetSize(20, 20)
            specIcon:SetPoint("CENTER")

            if specData and specData.specID then
                local id, name, description, iconPath = GetSpecializationInfoByID(specData.specID)
                if iconPath then
                    specIcon:SetTexture(iconPath)
                else
                    specIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end
            else
                specIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            if hasSpecData then
                specIcon:SetDesaturated(false)
                specBtn:SetAlpha(1.0)
            else
                specIcon:SetDesaturated(true)
                specBtn:SetAlpha(0.4)
            end

            if selectedCharKey == charKey and selectedSpecName == specName then
                specBtn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
            end

            specBtn:SetScript("OnEnter", function(self)
                if hasSpecData then
                    self:SetBackdropColor(T("BG_HOVER"))
                end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(specName, 1, 1, 1)
                if hasSpecData then
                    GameTooltip:AddLine(L["AB_CLICK_TO_VIEW"], 0.8, 0.8, 0.8)
                else
                    GameTooltip:AddLine(L["AB_NO_DATA_SAVED"], 1, 0, 0)
                end
                GameTooltip:Show()
            end)

            specBtn:SetScript("OnLeave", function(self)
                if selectedCharKey == charKey and selectedSpecName == specName then
                    self:SetBackdropColor(T("BG_SECONDARY"))
                else
                    self:SetBackdropColor(T("BG_SECONDARY"))
                end
                GameTooltip:Hide()
            end)

            if hasSpecData then
                specBtn:SetScript("OnClick", function()
                    selectedCharKey = charKey
                    selectedSpecName = specName
                    if ns.UI.ShowActionBarDetails then
                        ns.UI.ShowActionBarDetails(actionBarsTab, charKey, specName)
                    end
                    if ns.UI.RefreshActionBarsListing then
                        ns.UI.RefreshActionBarsListing(actionBarsTab)
                    end
                end)
            end

            specXOffset = specXOffset - 28
        end

        charBubble:EnableMouse(true)
        charBubble:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
        end)
        charBubble:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BG_TERTIARY"))
        end)
        charBubble:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                selectedCharKey = charKey
                local firstSpec = specs[1]
                if firstSpec and ns.ActionBarsModule:HasActionBarData(charKey, firstSpec) then
                    selectedSpecName = firstSpec
                    if ns.UI.ShowActionBarDetails then
                        ns.UI.ShowActionBarDetails(actionBarsTab, charKey, firstSpec)
                    end
                    if ns.UI.RefreshActionBarsListing then
                        ns.UI.RefreshActionBarsListing(actionBarsTab)
                    end
                end
            end
        end)

        yOffset = yOffset - (bubbleHeight + bubbleGap)
    end

    local newHeight = math.max(400, #charList * (bubbleHeight + bubbleGap) + 10)
    actionBarsTab.listingScrollChild:SetHeight(newHeight)

    if actionBarsTab.leftStatusText then
        actionBarsTab.leftStatusText:SetText(string.format(L["AB_CHARACTERS_COUNT"], #charList))
    end
end

function ns.UI.ShowActionBarDetails(actionBarsTab, charKey, specName)
    if not actionBarsTab or not actionBarsTab.detailScrollChild then return end
    if not ns.ActionBarsModule then return end

    for _, child in ipairs({actionBarsTab.detailScrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
        child:ClearAllPoints()
    end

    for _, child in ipairs({actionBarsTab.detailPanel:GetChildren()}) do
        if child ~= actionBarsTab.detailTitle and child ~= actionBarsTab.detailScrollFrame then
            child:Hide()
            child:SetParent(nil)
            child:ClearAllPoints()
        end
    end

    if not charKey or not specName then
        if actionBarsTab.detailTitle then
            actionBarsTab.detailTitle:SetText(L["AB_ACTION_BAR_DETAILS"])
            actionBarsTab.detailTitle:Show()
        end
        return
    end

    local charData = ns.ActionBarsModule:GetCharacterData(charKey)
    if not charData then
        if actionBarsTab.detailTitle then
            actionBarsTab.detailTitle:SetText(L["AB_NO_DATA_AVAILABLE"])
            actionBarsTab.detailTitle:Show()
        end
        return
    end

    local specData = ns.ActionBarsModule:GetSpecData(charKey, specName)
    if not specData or not specData.bars then
        if actionBarsTab.detailTitle then
            actionBarsTab.detailTitle:SetText(L["AB_NO_DATA_AVAILABLE"])
            actionBarsTab.detailTitle:Show()
        end
        return
    end

    if actionBarsTab.detailTitle then
        actionBarsTab.detailTitle:Hide()
    end

    local headerBox = CreateFrame("Frame", nil, actionBarsTab.detailPanel, "BackdropTemplate")
    headerBox:SetPoint("TOPLEFT", actionBarsTab.detailPanel, "TOPLEFT", 8, -8)
    headerBox:SetPoint("TOPRIGHT", actionBarsTab.detailPanel, "TOPRIGHT", -8, -8)
    headerBox:SetHeight(60)
    headerBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    headerBox:SetBackdropColor(T("BG_SECONDARY"))
    headerBox:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local headerTitle = headerBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTitle:SetPoint("LEFT", headerBox, "LEFT", 10, 14)
    headerTitle:SetText((charData.name or charKey) .. " - " .. specName)
    headerTitle:SetTextColor(T("ACCENT_PRIMARY"))

    local restoreAllBtn = CreateFrame("Button", nil, headerBox, "BackdropTemplate")
    restoreAllBtn:SetSize(110, 24)
    restoreAllBtn:SetPoint("BOTTOMLEFT", headerBox, "BOTTOMLEFT", 10, 6)
    restoreAllBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    restoreAllBtn:SetBackdropColor(0.6, 0.2, 0.2, 1.0)
    restoreAllBtn:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)

    local restoreAllText = restoreAllBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    restoreAllText:SetPoint("CENTER")
    restoreAllText:SetText(L["AB_RESTORE_ALL_BARS"])
    restoreAllText:SetTextColor(1, 1, 1)

    restoreAllBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.7, 0.3, 0.3, 1.0)
        self:SetBackdropBorderColor(0.9, 0.4, 0.4, 1.0)
    end)
    restoreAllBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.6, 0.2, 0.2, 1.0)
        self:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)
    end)
    restoreAllBtn:SetScript("OnClick", function()
        ShowRestoreAllDialog(charKey, specName, charData.name or charKey)
    end)

    local keybindCount = 0
    if charData.keybinds and charData.keybinds.bindings then
        for _ in pairs(charData.keybinds.bindings) do
            keybindCount = keybindCount + 1
        end
    end

    local restoreKeybindsBtn = CreateFrame("Button", nil, headerBox, "BackdropTemplate")
    restoreKeybindsBtn:SetSize(110, 24)
    restoreKeybindsBtn:SetPoint("LEFT", restoreAllBtn, "RIGHT", 8, 0)
    restoreKeybindsBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    local restoreKeybindsText = restoreKeybindsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    restoreKeybindsText:SetPoint("CENTER")
    restoreKeybindsText:SetText(L["AB_RESTORE_KEYBINDS"])

    if keybindCount > 0 then
        restoreKeybindsBtn:SetBackdropColor(0.2, 0.3, 0.5, 1.0)
        restoreKeybindsBtn:SetBackdropBorderColor(0.4, 0.5, 0.7, 1.0)
        restoreKeybindsText:SetTextColor(1, 1, 1)
        restoreKeybindsBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.3, 0.4, 0.6, 1.0)
            self:SetBackdropBorderColor(0.5, 0.6, 0.8, 1.0)
        end)
        restoreKeybindsBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.2, 0.3, 0.5, 1.0)
            self:SetBackdropBorderColor(0.4, 0.5, 0.7, 1.0)
        end)
        restoreKeybindsBtn:SetScript("OnClick", function()
            if ns.ActionBarsModule and ns.ActionBarsModule.RestoreKeybinds then
                ns.ActionBarsModule:RestoreKeybinds(charKey)
            end
        end)
    else
        restoreKeybindsBtn:SetBackdropColor(T("BG_SECONDARY"))
        restoreKeybindsBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        restoreKeybindsBtn:SetAlpha(0.5)
        restoreKeybindsText:SetTextColor(T("TEXT_SECONDARY"))
    end

    local accountMacros = 0
    local charMacros = 0
    if charData.macros then
        if charData.macros.account then
            for _ in pairs(charData.macros.account) do
                accountMacros = accountMacros + 1
            end
        end
        if charData.macros.character then
            for _ in pairs(charData.macros.character) do
                charMacros = charMacros + 1
            end
        end
    end
    local macroCount = accountMacros + charMacros

    local restoreMacrosBtn = CreateFrame("Button", nil, headerBox, "BackdropTemplate")
    restoreMacrosBtn:SetSize(110, 24)
    restoreMacrosBtn:SetPoint("LEFT", restoreKeybindsBtn, "RIGHT", 8, 0)
    restoreMacrosBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    local restoreMacrosText = restoreMacrosBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    restoreMacrosText:SetPoint("CENTER")
    restoreMacrosText:SetText(L["AB_RESTORE_MACROS"])

    if macroCount > 0 then
        restoreMacrosBtn:SetBackdropColor(0.4, 0.2, 0.5, 1.0)
        restoreMacrosBtn:SetBackdropBorderColor(0.6, 0.4, 0.7, 1.0)
        restoreMacrosText:SetTextColor(1, 1, 1)
        restoreMacrosBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.5, 0.3, 0.6, 1.0)
            self:SetBackdropBorderColor(0.7, 0.5, 0.8, 1.0)
        end)
        restoreMacrosBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.4, 0.2, 0.5, 1.0)
            self:SetBackdropBorderColor(0.6, 0.4, 0.7, 1.0)
        end)
        restoreMacrosBtn:SetScript("OnClick", function()
            ShowRestoreMacrosDialog(charKey, charData.name or charKey, accountMacros, charMacros)
        end)
    else
        restoreMacrosBtn:SetBackdropColor(T("BG_SECONDARY"))
        restoreMacrosBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        restoreMacrosBtn:SetAlpha(0.5)
        restoreMacrosText:SetTextColor(T("TEXT_SECONDARY"))
    end

    if actionBarsTab.detailScrollFrame then
        actionBarsTab.detailScrollFrame:ClearAllPoints()
        actionBarsTab.detailScrollFrame:SetPoint("TOPLEFT", headerBox, "BOTTOMLEFT", 0, -5)
        actionBarsTab.detailScrollFrame:SetPoint("BOTTOMRIGHT", actionBarsTab.detailPanel, "BOTTOMRIGHT", -8, 8)
    end

    local yOffset = -10
    local barOrder = BAR_DISPLAY_ORDER

    for _, barNumber in ipairs(barOrder) do
        local barData = specData.bars and specData.bars[barNumber]

        if showAllBars or (barData and barData.slots) then
            local barLabelFrame = CreateFrame("Frame", nil, actionBarsTab.detailScrollChild)
            barLabelFrame:SetPoint("TOPLEFT", actionBarsTab.detailScrollChild, "TOPLEFT", 10, yOffset)
            barLabelFrame:SetSize(70, 20)
            local barLabel = barLabelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            barLabel:SetAllPoints()
            barLabel:SetText(L[BAR_NAMES[barNumber]] or string.format(L["AB_LABEL_BAR"], barNumber))
            barLabel:SetTextColor(T("TEXT_PRIMARY"))

            local slotXStart = 80
            local slotYOffset = yOffset - 20

            for slotIndex = 1, 12 do
                local slotData = barData and barData.slots and barData.slots[slotIndex]
                local xPos = slotXStart + ((slotIndex - 1) * 36)

                local slotFrame = CreateFrame("Button", nil, actionBarsTab.detailScrollChild, "BackdropTemplate")
                slotFrame:SetSize(32, 32)
                slotFrame:SetPoint("TOPLEFT", actionBarsTab.detailScrollChild, "TOPLEFT", xPos, slotYOffset)
                slotFrame:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                })

                if slotData then
                    local r, g, b = unpack(ns.ActionBarsModule:GetActionColor(slotData))
                    slotFrame:SetBackdropColor(r * 0.3, g * 0.3, b * 0.3, 1.0)
                    slotFrame:SetBackdropBorderColor(r, g, b, 1.0)

                    local slotIcon = slotFrame:CreateTexture(nil, "ARTWORK")
                    slotIcon:SetAllPoints()
                    slotIcon:SetTexture(slotData.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
                    slotIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

                    if slotData.actionType == "spell" and slotData.spellID == 1229376 then
                        local assistOverlay = slotFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        assistOverlay:SetAllPoints()
                        assistOverlay:SetText("AC")
                        assistOverlay:SetTextColor(1, 1, 0)
                        assistOverlay:SetJustifyH("CENTER")
                        assistOverlay:SetJustifyV("MIDDLE")
                    end

                    slotFrame:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        local displayName = ns.ActionBarsModule:GetDisplayText(slotData)
                        GameTooltip:SetText(displayName or L["Unknown"], r, g, b, 1)

                        if slotData.actionType == "spell" and slotData.spellID == 1229376 then
                            GameTooltip:AddLine("Assisted Combat", 1, 1, 0)
                        elseif slotData.actionType == "spell" and slotData.spellID then
                            GameTooltip:AddLine(string.format(L["AB_SPELL_ID"], slotData.spellID), 0.6, 0.6, 0.6)
                        elseif slotData.actionType == "item" and slotData.itemID then
                            GameTooltip:AddLine(string.format(L["AB_ITEM_ID"], slotData.itemID), 0.6, 0.6, 0.6)
                        elseif slotData.actionType == "macro" and slotData.macroBody then
                            local firstLine = slotData.macroBody:match("([^\r\n]+)")
                            if firstLine and #firstLine > 0 then
                                if #firstLine > 40 then
                                    firstLine = firstLine:sub(1, 37) .. "..."
                                end
                                GameTooltip:AddLine(firstLine, 0.9, 0.9, 0.9)
                            end
                        end

                        GameTooltip:AddLine((L[BAR_NAMES[barNumber]] or string.format(L["AB_LABEL_BAR"], barNumber)) .. ", " .. string.format(L["AB_LABEL_SLOT"], slotIndex), 0.8, 0.8, 0.8)
                        GameTooltip:Show()
                    end)
                    slotFrame:SetScript("OnLeave", function(self)
                        GameTooltip:Hide()
                    end)
                else
                    slotFrame:SetBackdropColor(T("BG_SECONDARY"))
                    slotFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                end

                slotFrame:Show()
            end

            if barData and barData.slots then
                local restoreBarBtn = CreateFrame("Button", nil, actionBarsTab.detailScrollChild, "BackdropTemplate")
                restoreBarBtn:SetSize(70, 26)
                restoreBarBtn:SetPoint("TOPLEFT", actionBarsTab.detailScrollChild, "TOPLEFT", slotXStart + (12 * 36) + 10, slotYOffset + 3)
                restoreBarBtn:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                })
                restoreBarBtn:SetBackdropColor(0.2, 0.6, 0.2, 1.0)
                restoreBarBtn:SetBackdropBorderColor(0.3, 0.8, 0.3, 1.0)

                local restoreBarText = restoreBarBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                restoreBarText:SetPoint("CENTER")
                restoreBarText:SetText(L["AB_LABEL_RESTORE"])
                restoreBarText:SetTextColor(1, 1, 1)

                restoreBarBtn:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(0.3, 0.7, 0.3, 1.0)
                    self:SetBackdropBorderColor(0.4, 0.9, 0.4, 1.0)
                end)
                restoreBarBtn:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(0.2, 0.6, 0.2, 1.0)
                    self:SetBackdropBorderColor(0.3, 0.8, 0.3, 1.0)
                end)
                restoreBarBtn:SetScript("OnClick", function()
                    ShowRestoreBarDialog(charKey, barNumber, specName, actionBarsTab)
                end)
            end

            yOffset = yOffset - 60
        end
    end

    local newHeight = math.max(400, math.abs(yOffset) + 20)
    actionBarsTab.detailScrollChild:SetHeight(newHeight)
end
