local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.UI = ns.UI or {}

local selectedSetName = nil
local selectedRow = nil
local showAllBars = false
local activeFilterClass = nil

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

local CLASS_DISPLAY_NAMES = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter",
    ROGUE = "Rogue", PRIEST = "Priest", DEATHKNIGHT = "Death Knight",
    SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock",
    MONK = "Monk", DRUID = "Druid", DEMONHUNTER = "Demon Hunter",
    EVOKER = "Evoker",
}

local function ShowRestoreBarDialog(setName, sourceBarNumber, parent)
    local barName = L[BAR_NAMES[sourceBarNumber]] or string.format(L["AB_LABEL_BAR"], sourceBarNumber)
    local selectedTargetBar = sourceBarNumber

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_AT_RestoreBarDialog",
        title = string.format(L["AB_RESTORE_SINGLE"], barName),
        width = 400,
        height = 220,
        movable = false,
        buttons = {
            { text = L["AB_LABEL_RESTORE"], color = {0.2, 0.6, 0.2}, onClick = function(dialog)
                if ns.ActionBarsModule and ns.ActionBarsModule.RestoreSingleBarFromSet then
                    ns.ActionBarsModule:RestoreSingleBarFromSet(setName, sourceBarNumber, selectedTargetBar)
                end
                dialog:Hide()
            end },
            { text = L["AB_LABEL_CANCEL"], onClick = function(dialog) dialog:Hide() end },
        },
    })

    local cf = result.contentFrame
    local instructionText = cf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructionText:SetPoint("TOP", cf, "TOP", 0, -10)
    instructionText:SetText(L["AB_SELECT_TARGET_BAR"])
    instructionText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local dropdown, dropdownText = OneWoW_GUI:CreateDropdown(cf, {
        width = 200,
        height = 28,
        text = L[BAR_NAMES[sourceBarNumber]] or string.format(L["AB_LABEL_BAR"], sourceBarNumber),
    })
    dropdown:SetPoint("TOP", instructionText, "BOTTOM", 0, -10)

    OneWoW_GUI:AttachFilterMenu(dropdown, dropdownText, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, barNumber in ipairs(BAR_DISPLAY_ORDER) do
                table.insert(items, {
                    value = barNumber,
                    text = L[BAR_NAMES[barNumber]] or string.format(L["AB_LABEL_BAR"], barNumber),
                })
            end
            return items
        end,
        onSelect = function(value, displayText)
            selectedTargetBar = value
            dropdownText:SetText(displayText)
        end,
        getActiveValue = function() return selectedTargetBar end,
    })

    result.frame:Show()
end

local function ShowRestoreAllDialog(setName)
    local result = OneWoW_GUI:CreateConfirmDialog({
        name = "OneWoW_AT_RestoreAllDialog",
        title = L["AB_DIALOG_RESTORE_ALL_TITLE"],
        message = string.format(L["AB_DIALOG_RESTORE_ALL"], setName),
        buttons = {
            { text = L["AB_BUTTON_RESTORE_ALL"], color = {0.6, 0.2, 0.2}, onClick = function(dialog)
                if ns.ActionBarsModule and ns.ActionBarsModule.RestoreAllBarsFromSet then
                    ns.ActionBarsModule:RestoreAllBarsFromSet(setName)
                end
                dialog:Hide()
            end },
            { text = L["AB_LABEL_CANCEL"], onClick = function(dialog) dialog:Hide() end },
        },
    })
    result.frame:Show()
end

local function ShowRestoreMacrosDialog(setName, setData)
    local accountCount = 0
    local charCount = 0
    if setData.macros then
        if setData.macros.account then
            for _ in pairs(setData.macros.account) do accountCount = accountCount + 1 end
        end
        if setData.macros.character then
            for _ in pairs(setData.macros.character) do charCount = charCount + 1 end
        end
    end

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_AT_RestoreMacrosDialog",
        title = L["AB_DIALOG_RESTORE_MACROS_TITLE"],
        width = 420,
        height = 240,
        movable = false,
        buttons = {},
    })

    local cf = result.contentFrame
    local infoText = cf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoText:SetPoint("TOP", cf, "TOP", 0, -10)
    infoText:SetWidth(380)
    infoText:SetText(string.format(L["AB_DIALOG_RESTORE_MACROS"], setName))
    infoText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    infoText:SetJustifyH("CENTER")

    local accountBtn = OneWoW_GUI:CreateButton(nil, cf, string.format(L["AB_BUTTON_ACCOUNT_ONLY"], accountCount), 180, 30)
    accountBtn:SetPoint("TOP", infoText, "BOTTOM", -95, -20)
    accountBtn:SetBackdropColor(0.4, 0.2, 0.5, 1.0)
    accountBtn:SetBackdropBorderColor(0.6, 0.4, 0.7, 1.0)
    accountBtn.text:SetTextColor(1, 1, 1)
    accountBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.5, 0.3, 0.6, 1.0) end)
    accountBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.4, 0.2, 0.5, 1.0) end)
    accountBtn:SetScript("OnClick", function()
        if ns.ActionBarsModule then ns.ActionBarsModule:RestoreMacrosFromSet(setName, "account") end
        result.frame:Hide()
    end)

    local charBtn = OneWoW_GUI:CreateButton(nil, cf, string.format(L["AB_BUTTON_CHARACTER_ONLY"], charCount), 180, 30)
    charBtn:SetPoint("TOP", infoText, "BOTTOM", 95, -20)
    charBtn:SetBackdropColor(0.4, 0.2, 0.5, 1.0)
    charBtn:SetBackdropBorderColor(0.6, 0.4, 0.7, 1.0)
    charBtn.text:SetTextColor(1, 1, 1)
    charBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.5, 0.3, 0.6, 1.0) end)
    charBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.4, 0.2, 0.5, 1.0) end)
    charBtn:SetScript("OnClick", function()
        if ns.ActionBarsModule then ns.ActionBarsModule:RestoreMacrosFromSet(setName, "character") end
        result.frame:Hide()
    end)

    local bothBtn = OneWoW_GUI:CreateButton(nil, cf, L["AB_BUTTON_BOTH"], 180, 30)
    bothBtn:SetPoint("TOP", accountBtn, "BOTTOM", 0, -8)
    bothBtn:SetBackdropColor(0.2, 0.6, 0.2, 1.0)
    bothBtn:SetBackdropBorderColor(0.3, 0.8, 0.3, 1.0)
    bothBtn.text:SetTextColor(1, 1, 1)
    bothBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.3, 0.7, 0.3, 1.0) end)
    bothBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.2, 0.6, 0.2, 1.0) end)
    bothBtn:SetScript("OnClick", function()
        if ns.ActionBarsModule then ns.ActionBarsModule:RestoreMacrosFromSet(setName, "both") end
        result.frame:Hide()
    end)

    local cancelBtn = OneWoW_GUI:CreateButton(nil, cf, L["AB_LABEL_CANCEL"], 180, 30)
    cancelBtn:SetPoint("TOP", charBtn, "BOTTOM", 0, -8)
    cancelBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    cancelBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    cancelBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    cancelBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) end)
    cancelBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY")) end)
    cancelBtn:SetScript("OnClick", function() result.frame:Hide() end)

    result.frame:Show()
end

local function ShowBackupDialog(split)
    local playerName = UnitName("player")
    local specIndex = GetSpecialization()
    local specName = specIndex and select(2, GetSpecializationInfo(specIndex)) or ""
    local defaultName = playerName .. " " .. specName

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_AT_BackupDialog",
        title = L["AB_BACKUP_SET_TITLE"],
        width = 420,
        height = 200,
        movable = false,
        buttons = {
            { text = L["AB_BACKUP_SET_SAVE"], color = {0.2, 0.6, 0.2}, onClick = function(dialog)
                local nameBox = dialog.nameEditBox
                if nameBox then
                    local setName = strtrim(nameBox:GetText())
                    if setName == "" then
                        print("|cFFFFD100OneWoW|r AltTracker: " .. L["AB_SET_NAME_EMPTY"])
                        return
                    end
                    if ns.ActionBarsModule then
                        local saved = ns.ActionBarsModule:SaveActionBarSet(setName)
                        if saved then
                            selectedSetName = setName
                            if split then
                                ns.UI.BuildActionBarSetsList(split, "")
                                ns.UI.ShowSetDetails(split, setName)
                            end
                        end
                    end
                end
                dialog:Hide()
            end },
            { text = L["AB_LABEL_CANCEL"], onClick = function(dialog) dialog:Hide() end },
        },
    })

    local cf = result.contentFrame
    local msgText = cf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msgText:SetPoint("TOP", cf, "TOP", 0, -10)
    msgText:SetWidth(380)
    msgText:SetText(L["AB_BACKUP_SET_MESSAGE"])
    msgText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    msgText:SetJustifyH("CENTER")

    local nameBox = OneWoW_GUI:CreateEditBox(nil, cf, {
        width = 300,
        height = 28,
        placeholder = "",
    })
    nameBox:SetPoint("TOP", msgText, "BOTTOM", 0, -12)
    nameBox:SetText(defaultName)
    nameBox:HighlightText()
    nameBox:SetFocus()

    result.frame.nameEditBox = nameBox

    result.frame:Show()
end

local function ShowRenameDialog(split, oldName)
    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_AT_RenameDialog",
        title = L["AB_RENAME_SET_TITLE"],
        width = 420,
        height = 200,
        movable = false,
        buttons = {
            { text = L["AB_RENAME_SET_CONFIRM"], color = {0.2, 0.6, 0.2}, onClick = function(dialog)
                local nameBox = dialog.nameEditBox
                if nameBox then
                    local newName = strtrim(nameBox:GetText())
                    if newName == "" then
                        print("|cFFFFD100OneWoW|r AltTracker: " .. L["AB_SET_NAME_EMPTY"])
                        return
                    end
                    if newName == oldName then
                        dialog:Hide()
                        return
                    end
                    local sets = ns.ActionBarsModule and ns.ActionBarsModule:GetActionBarSets()
                    if sets and sets[newName] then
                        print("|cFFFFD100OneWoW|r AltTracker: " .. L["AB_SET_NAME_EXISTS"])
                        return
                    end
                    if ns.ActionBarsModule then
                        local success = ns.ActionBarsModule:RenameActionBarSet(oldName, newName)
                        if success then
                            selectedSetName = newName
                            if split then
                                ns.UI.BuildActionBarSetsList(split, "")
                                ns.UI.ShowSetDetails(split, newName)
                            end
                        end
                    end
                end
                dialog:Hide()
            end },
            { text = L["AB_LABEL_CANCEL"], onClick = function(dialog) dialog:Hide() end },
        },
    })

    local cf = result.contentFrame
    local msgText = cf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msgText:SetPoint("TOP", cf, "TOP", 0, -10)
    msgText:SetWidth(380)
    msgText:SetText(string.format(L["AB_RENAME_SET_MESSAGE"], oldName))
    msgText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    msgText:SetJustifyH("CENTER")

    local nameBox = OneWoW_GUI:CreateEditBox(nil, cf, {
        width = 300,
        height = 28,
        placeholder = "",
    })
    nameBox:SetPoint("TOP", msgText, "BOTTOM", 0, -12)
    nameBox:SetText(oldName)
    nameBox:HighlightText()
    nameBox:SetFocus()

    result.frame.nameEditBox = nameBox

    result.frame:Show()
end

local function ShowDeleteDialog(split, setName)
    local result = OneWoW_GUI:CreateConfirmDialog({
        name = "OneWoW_AT_DeleteSetDialog",
        title = L["AB_DELETE_SET_TITLE"],
        message = string.format(L["AB_DELETE_SET_MESSAGE"], setName),
        buttons = {
            { text = L["AB_DELETE_SET_CONFIRM"], color = {0.6, 0.2, 0.2}, onClick = function(dialog)
                if ns.ActionBarsModule then
                    ns.ActionBarsModule:DeleteActionBarSet(setName)
                    selectedSetName = nil
                    selectedRow = nil
                    if split then
                        ns.UI.BuildActionBarSetsList(split, "")
                        OneWoW_GUI:ClearFrame(split.detailScrollChild)
                        split.detailTitle:SetText(L["AB_SET_DETAILS"])
                        split.detailTitle:Show()
                        if split.rightStatusText then
                            split.rightStatusText:SetText("")
                        end
                    end
                end
                dialog:Hide()
            end },
            { text = L["AB_LABEL_CANCEL"], onClick = function(dialog) dialog:Hide() end },
        },
    })
    result.frame:Show()
end

local function ShowDetailPlaceholder(detailScrollChild, message)
    OneWoW_GUI:ClearFrame(detailScrollChild)
    local placeholder = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    placeholder:SetPoint("TOP", detailScrollChild, "TOP", 0, -40)
    placeholder:SetWidth(detailScrollChild:GetWidth() - 20)
    placeholder:SetText(message)
    placeholder:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    placeholder:SetJustifyH("CENTER")
    detailScrollChild:SetHeight(math.max(100, placeholder:GetStringHeight() + 60))
end

function ns.UI.ShowSetDetails(split, setName)
    local detailScrollChild = split.detailScrollChild
    local fw = split.detailScrollFrame:GetWidth()
    if fw > 0 then
        detailScrollChild:SetWidth(fw)
    end
    OneWoW_GUI:ClearFrame(detailScrollChild)

    if not setName then
        split.detailTitle:SetText(L["AB_SET_DETAILS"])
        split.detailTitle:Show()
        ShowDetailPlaceholder(detailScrollChild, L["AB_SET_NO_SELECTION"])
        return
    end

    if not ns.ActionBarsModule then
        split.detailTitle:SetText(L["AB_NO_DATA_AVAILABLE"])
        split.detailTitle:Show()
        return
    end

    local setData = ns.ActionBarsModule:GetActionBarSet(setName)
    if not setData or not setData.bars then
        split.detailTitle:SetText(L["AB_NO_DATA_AVAILABLE"])
        split.detailTitle:Show()
        return
    end

    split.detailTitle:Hide()

    local yOffset = -10

    local headerBox = CreateFrame("Frame", nil, detailScrollChild, "BackdropTemplate")
    headerBox:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
    headerBox:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)
    headerBox:SetHeight(80)
    headerBox:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    headerBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    headerBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local headerTitle = headerBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerTitle:SetPoint("TOPLEFT", headerBox, "TOPLEFT", 10, -8)
    headerTitle:SetText(setName)
    headerTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local sourceText = headerBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sourceText:SetPoint("TOPLEFT", headerTitle, "BOTTOMLEFT", 0, -4)
    local charName = setData.sourceChar and setData.sourceChar:match("^([^%-]+)") or "?"
    sourceText:SetText(string.format(L["AB_SET_SOURCE"], charName, setData.sourceSpec or "?"))
    sourceText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    if setData.lastUpdate then
        local updatedText = headerBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        updatedText:SetPoint("TOPLEFT", sourceText, "BOTTOMLEFT", 0, -2)
        updatedText:SetText(string.format(L["AB_SET_UPDATED"], date("%Y-%m-%d %H:%M", setData.lastUpdate)))
        updatedText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    end

    local renameBtn = OneWoW_GUI:CreateFitTextButton(headerBox, L["AB_RENAME_SET"], { height = 24 })
    renameBtn:SetPoint("TOPRIGHT", headerBox, "TOPRIGHT", -10, -8)
    renameBtn:SetScript("OnClick", function()
        ShowRenameDialog(split, setName)
    end)

    local deleteBtn = OneWoW_GUI:CreateFitTextButton(headerBox, L["AB_DELETE_SET"], { height = 24 })
    deleteBtn:SetPoint("RIGHT", renameBtn, "LEFT", -6, 0)
    deleteBtn:SetBackdropColor(0.6, 0.2, 0.2, 1.0)
    deleteBtn:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)
    deleteBtn.text:SetTextColor(1, 1, 1)
    deleteBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.7, 0.3, 0.3, 1.0)
    end)
    deleteBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.6, 0.2, 0.2, 1.0)
    end)
    deleteBtn:SetScript("OnClick", function()
        ShowDeleteDialog(split, setName)
    end)

    local restoreAllBtn = OneWoW_GUI:CreateButton(nil, headerBox, L["AB_RESTORE_ALL_BARS"], 110, 24)
    restoreAllBtn:SetPoint("BOTTOMLEFT", headerBox, "BOTTOMLEFT", 10, 6)
    restoreAllBtn:SetBackdropColor(0.6, 0.2, 0.2, 1.0)
    restoreAllBtn:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)
    restoreAllBtn.text:SetFontObject("GameFontNormalSmall")
    restoreAllBtn.text:SetTextColor(1, 1, 1)
    restoreAllBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.7, 0.3, 0.3, 1.0)
        self:SetBackdropBorderColor(0.9, 0.4, 0.4, 1.0)
    end)
    restoreAllBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.6, 0.2, 0.2, 1.0)
        self:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)
    end)
    restoreAllBtn:SetScript("OnClick", function()
        ShowRestoreAllDialog(setName)
    end)

    local keybindCount = 0
    if setData.keybinds and setData.keybinds.bindings then
        for _ in pairs(setData.keybinds.bindings) do
            keybindCount = keybindCount + 1
        end
    end

    local restoreKeybindsBtn = OneWoW_GUI:CreateButton(nil, headerBox, L["AB_RESTORE_KEYBINDS"], 110, 24)
    restoreKeybindsBtn:SetPoint("LEFT", restoreAllBtn, "RIGHT", 8, 0)
    restoreKeybindsBtn.text:SetFontObject("GameFontNormalSmall")

    if keybindCount > 0 then
        restoreKeybindsBtn:SetBackdropColor(0.2, 0.3, 0.5, 1.0)
        restoreKeybindsBtn:SetBackdropBorderColor(0.4, 0.5, 0.7, 1.0)
        restoreKeybindsBtn.text:SetTextColor(1, 1, 1)
        restoreKeybindsBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.3, 0.4, 0.6, 1.0)
            self:SetBackdropBorderColor(0.5, 0.6, 0.8, 1.0)
        end)
        restoreKeybindsBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.2, 0.3, 0.5, 1.0)
            self:SetBackdropBorderColor(0.4, 0.5, 0.7, 1.0)
        end)
        restoreKeybindsBtn:SetScript("OnClick", function()
            if ns.ActionBarsModule then
                ns.ActionBarsModule:RestoreKeybindsFromSet(setName)
            end
        end)
    else
        restoreKeybindsBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        restoreKeybindsBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        restoreKeybindsBtn:SetAlpha(0.5)
        restoreKeybindsBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    end

    local accountMacros = 0
    local charMacros = 0
    if setData.macros then
        if setData.macros.account then
            for _ in pairs(setData.macros.account) do accountMacros = accountMacros + 1 end
        end
        if setData.macros.character then
            for _ in pairs(setData.macros.character) do charMacros = charMacros + 1 end
        end
    end
    local macroCount = accountMacros + charMacros

    local restoreMacrosBtn = OneWoW_GUI:CreateButton(nil, headerBox, L["AB_RESTORE_MACROS"], 110, 24)
    restoreMacrosBtn:SetPoint("LEFT", restoreKeybindsBtn, "RIGHT", 8, 0)
    restoreMacrosBtn.text:SetFontObject("GameFontNormalSmall")

    if macroCount > 0 then
        restoreMacrosBtn:SetBackdropColor(0.4, 0.2, 0.5, 1.0)
        restoreMacrosBtn:SetBackdropBorderColor(0.6, 0.4, 0.7, 1.0)
        restoreMacrosBtn.text:SetTextColor(1, 1, 1)
        restoreMacrosBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.5, 0.3, 0.6, 1.0)
            self:SetBackdropBorderColor(0.7, 0.5, 0.8, 1.0)
        end)
        restoreMacrosBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.4, 0.2, 0.5, 1.0)
            self:SetBackdropBorderColor(0.6, 0.4, 0.7, 1.0)
        end)
        restoreMacrosBtn:SetScript("OnClick", function()
            ShowRestoreMacrosDialog(setName, setData)
        end)
    else
        restoreMacrosBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        restoreMacrosBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        restoreMacrosBtn:SetAlpha(0.5)
        restoreMacrosBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    end

    yOffset = yOffset - 80 - 10

    local showAllCheckbox = OneWoW_GUI:CreateCheckbox(nil, detailScrollChild, L["AB_SHOW_ALL_BARS"])
    showAllCheckbox:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 10, yOffset)
    showAllCheckbox:SetChecked(showAllBars)
    showAllCheckbox:SetScript("OnClick", function(self)
        showAllBars = self:GetChecked()
        if selectedSetName then
            ns.UI.ShowSetDetails(split, selectedSetName)
        end
    end)
    yOffset = yOffset - 28

    local barOrder = BAR_DISPLAY_ORDER

    for _, barNumber in ipairs(barOrder) do
        local barData = setData.bars and setData.bars[barNumber]

        if showAllBars or (barData and barData.slots) then
            local barLabelFrame = CreateFrame("Frame", nil, detailScrollChild)
            barLabelFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 10, yOffset)
            barLabelFrame:SetSize(70, 20)
            local barLabel = barLabelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            barLabel:SetAllPoints()
            barLabel:SetText(L[BAR_NAMES[barNumber]] or string.format(L["AB_LABEL_BAR"], barNumber))
            barLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local slotXStart = 80
            local slotYOffset = yOffset - 20

            for slotIndex = 1, 12 do
                local slotData = barData and barData.slots and barData.slots[slotIndex]
                local xPos = slotXStart + ((slotIndex - 1) * 36)

                local slotFrame = CreateFrame("Button", nil, detailScrollChild, "BackdropTemplate")
                slotFrame:SetSize(32, 32)
                slotFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", xPos, slotYOffset)
                slotFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)

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
                    slotFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                    slotFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                end

                slotFrame:Show()
            end

            if barData and barData.slots then
                local restoreBarBtn = OneWoW_GUI:CreateButton(nil, detailScrollChild, L["AB_LABEL_RESTORE"], 70, 26)
                restoreBarBtn:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", slotXStart + (12 * 36) + 10, slotYOffset + 3)
                restoreBarBtn:SetBackdropColor(0.2, 0.6, 0.2, 1.0)
                restoreBarBtn:SetBackdropBorderColor(0.3, 0.8, 0.3, 1.0)
                restoreBarBtn.text:SetFontObject("GameFontNormalSmall")
                restoreBarBtn.text:SetTextColor(1, 1, 1)

                restoreBarBtn:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(0.3, 0.7, 0.3, 1.0)
                    self:SetBackdropBorderColor(0.4, 0.9, 0.4, 1.0)
                end)
                restoreBarBtn:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(0.2, 0.6, 0.2, 1.0)
                    self:SetBackdropBorderColor(0.3, 0.8, 0.3, 1.0)
                end)
                local capturedBarNumber = barNumber
                restoreBarBtn:SetScript("OnClick", function()
                    ShowRestoreBarDialog(setName, capturedBarNumber, split)
                end)
            end

            yOffset = yOffset - 60
        end
    end

    local newHeight = math.max(400, math.abs(yOffset) + 20)
    detailScrollChild:SetHeight(newHeight)
    split.UpdateDetailThumb()

    if split.rightStatusText then
        split.rightStatusText:SetText(setName)
    end

    ns.UI.ApplyFontToFrame(split.detailScrollChild)
end

function ns.UI.BuildActionBarSetsList(split, filterText)
    local listScrollChild = split.listScrollChild
    OneWoW_GUI:ClearFrame(listScrollChild)
    selectedRow = nil

    if not ns.ActionBarsModule then
        ShowDetailPlaceholder(listScrollChild, L["AB_SET_EMPTY"])
        if split.leftStatusText then split.leftStatusText:SetText("") end
        return
    end

    local sets = ns.ActionBarsModule:GetActionBarSets()
    local setNames = {}
    for name, data in pairs(sets) do
        table.insert(setNames, { name = name, data = data })
    end

    table.sort(setNames, function(a, b)
        return (a.name or "") < (b.name or "")
    end)

    local filter = (filterText and #filterText > 0) and filterText:lower() or nil
    local shownCount = 0
    local totalCount = #setNames

    local yOffset = -5
    local rowHeight = 32

    local classBuckets = {}
    local classOrder = {}

    for _, entry in ipairs(setNames) do
        local className = entry.data.sourceClass or "UNKNOWN"
        if not classBuckets[className] then
            classBuckets[className] = {}
            table.insert(classOrder, className)
        end
        table.insert(classBuckets[className], entry)
    end

    table.sort(classOrder, function(a, b)
        return (CLASS_DISPLAY_NAMES[a] or a) < (CLASS_DISPLAY_NAMES[b] or b)
    end)

    for _, className in ipairs(classOrder) do
        if not activeFilterClass or activeFilterClass == className then
            local entries = classBuckets[className]
            local filteredEntries = {}

            for _, entry in ipairs(entries) do
                if not filter or entry.name:lower():find(filter, 1, true) then
                    table.insert(filteredEntries, entry)
                end
            end

            if #filteredEntries > 0 then
                local classColor = RAID_CLASS_COLORS[className]
                local catLabel = listScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                catLabel:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 8, yOffset)
                catLabel:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", -8, yOffset)
                catLabel:SetJustifyH("LEFT")
                catLabel:SetText(CLASS_DISPLAY_NAMES[className] or className)
                if classColor then
                    catLabel:SetTextColor(classColor.r, classColor.g, classColor.b)
                else
                    catLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
                end
                yOffset = yOffset - catLabel:GetStringHeight() - 4

                for _, entry in ipairs(filteredEntries) do
                    local capturedName = entry.name
                    shownCount = shownCount + 1

                    local hasBarData = ns.ActionBarsModule:HasSetBarData(capturedName)

                    local row = OneWoW_GUI:CreateListRowBasic(listScrollChild, {
                        height = rowHeight,
                        label = capturedName,
                        showDot = true,
                        dotEnabled = hasBarData,
                        onClick = function(self)
                            if selectedRow and selectedRow ~= self then
                                selectedRow:SetActive(false)
                            end
                            selectedSetName = capturedName
                            selectedRow = self
                            self:SetActive(true)
                            ns.UI.ShowSetDetails(split, capturedName)
                        end,
                    })
                    row:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 4, yOffset)
                    row:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", -4, yOffset)

                    if selectedSetName == capturedName then
                        row:SetActive(true)
                        selectedRow = row
                    end

                    yOffset = yOffset - rowHeight - 4
                end

                yOffset = yOffset - 8
            end
        end
    end

    if shownCount == 0 then
        ShowDetailPlaceholder(listScrollChild, L["AB_SET_EMPTY"])
    end

    listScrollChild:SetHeight(math.max(400, math.abs(yOffset) + 10))
    split.UpdateListThumb()

    if split.leftStatusText then
        if filter or activeFilterClass then
            split.leftStatusText:SetText(string.format(L["AB_SETS_FILTERED"], shownCount, totalCount))
        else
            split.leftStatusText:SetText(string.format(L["AB_SETS_COUNT"], totalCount))
        end
    end

    ns.UI.ApplyFontToFrame(listScrollChild)
end

function ns.UI.CreateActionBarsTab(parent)
    local contentPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    contentPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    contentPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    contentPanel:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    contentPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    contentPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    parent.contentPanel = contentPanel

    local controlPanel = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
    controlPanel:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 5, -5)
    controlPanel:SetPoint("TOPRIGHT", contentPanel, "TOPRIGHT", -5, -5)
    controlPanel:SetHeight(50)
    controlPanel:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    controlPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    controlPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local controlTitle = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    controlTitle:SetPoint("LEFT", controlPanel, "LEFT", 10, 0)
    local currentSpec = select(2, GetSpecializationInfo(GetSpecialization())) or L["AB_UNKNOWN_SPEC"]
    controlTitle:SetText(UnitName("player") .. " - " .. currentSpec)
    controlTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local splitContainer = CreateFrame("Frame", nil, contentPanel)
    splitContainer:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -5)
    splitContainer:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", -5, 5)

    local split = OneWoW_GUI:CreateSplitPanel(splitContainer, {
        showSearch = true,
        searchPlaceholder = L["AB_SEARCH_HINT"],
    })

    split.listTitle:SetText(L["AB_SETS_LIST"])
    split.detailTitle:SetText(L["AB_SET_DETAILS"])

    local backupBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, L["AB_BACKUP_SET"], { height = 28 })
    backupBtn:SetPoint("RIGHT", controlPanel, "RIGHT", -10, 0)
    backupBtn:SetBackdropColor(0.2, 0.6, 0.2, 1.0)
    backupBtn:SetBackdropBorderColor(0.3, 0.8, 0.3, 1.0)
    backupBtn.text:SetTextColor(1, 1, 1)
    backupBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.7, 0.3, 1.0)
    end)
    backupBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.6, 0.2, 1.0)
    end)
    backupBtn:SetScript("OnClick", function()
        ShowBackupDialog(split)
    end)

    local filterDropdown, filterDropdownText = OneWoW_GUI:CreateDropdown(controlPanel, {
        width = 160,
        height = 28,
        text = L["AB_FILTER_ALL"],
    })
    filterDropdown:SetPoint("RIGHT", backupBtn, "LEFT", -10, 0)

    OneWoW_GUI:AttachFilterMenu(filterDropdown, filterDropdownText, {
        searchable = false,
        buildItems = function()
            local items = {{ value = nil, text = L["AB_FILTER_ALL"] }}
            local sets = ns.ActionBarsModule and ns.ActionBarsModule:GetActionBarSets() or {}
            local classesFound = {}
            for _, data in pairs(sets) do
                local cls = data.sourceClass
                if cls and not classesFound[cls] then
                    classesFound[cls] = true
                    table.insert(items, {
                        value = cls,
                        text = CLASS_DISPLAY_NAMES[cls] or cls,
                    })
                end
            end
            table.sort(items, function(a, b)
                if a.value == nil then return true end
                if b.value == nil then return false end
                return (a.text or "") < (b.text or "")
            end)
            return items
        end,
        onSelect = function(value, displayText)
            activeFilterClass = value
            filterDropdownText:SetText(displayText)
            local searchText = split.searchBox and split.searchBox:GetSearchText() or ""
            ns.UI.BuildActionBarSetsList(split, searchText)
        end,
        getActiveValue = function() return activeFilterClass end,
    })

    if split.searchBox then
        split.searchBox:SetScript("OnTextChanged", function(self)
            ns.UI.BuildActionBarSetsList(split, self:GetSearchText())
        end)
    end

    parent.split = split
    parent.controlPanel = controlPanel
    parent.controlTitle = controlTitle

    ns.UI.ApplyFontToFrame(parent)

    C_Timer.After(0.5, function()
        ns.UI.BuildActionBarSetsList(split, "")
    end)
end

function ns.UI.RefreshActionBarsListing(actionBarsTab)
    if actionBarsTab and actionBarsTab.split then
        local searchText = actionBarsTab.split.searchBox and actionBarsTab.split.searchBox:GetSearchText() or ""
        ns.UI.BuildActionBarSetsList(actionBarsTab.split, searchText)
    end
end

function ns.UI.ShowActionBarDetails(actionBarsTab, charKey, specName)
    if actionBarsTab and actionBarsTab.split then
        ns.UI.ShowSetDetails(actionBarsTab.split, selectedSetName)
    end
end
