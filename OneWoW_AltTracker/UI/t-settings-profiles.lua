local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

-- All backend logic lives in OneWoW_AltTracker_Character.SettingsProfiles
-- Accessed via ns.SettingsProfilesModule (wired in actionbars-compat.lua)

-- ============================================================
-- Restore Dialog (UI only — calls ns.SettingsProfilesModule)
-- ============================================================

function ns.UI.ShowSettingsRestoreDialog(parent, profileName, profile)
    local dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dialog:SetSize(480, 360)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetToplevel(true)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    dialog:SetBackdropColor(T("BG_PRIMARY"))
    dialog:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local titleBar = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    titleBar:SetBackdropColor(T("TITLEBAR_BG"))

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleText:SetText(L["SP_RESTORE_PROFILE"] .. ": |cFFFFD100" .. profileName .. "|r")
    titleText:SetTextColor(T("TEXT_PRIMARY"))

    local savedDate = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    savedDate:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 10, -10)
    savedDate:SetText("Saved: " .. date("%Y-%m-%d %H:%M", profile.timestamp or 0))
    savedDate:SetTextColor(T("TEXT_SECONDARY"))

    local lastAnchor = savedDate
    if profile.savedBy then
        local savedByFS = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        savedByFS:SetPoint("TOPLEFT", savedDate, "BOTTOMLEFT", 0, -4)
        savedByFS:SetText(L["SP_SAVED_BY"] .. ": |cFFFFD100" .. profile.savedBy .. "|r")
        savedByFS:SetTextColor(T("TEXT_SECONDARY"))
        lastAnchor = savedByFS
    end

    local selectLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selectLabel:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -10)
    selectLabel:SetText("Select what to restore:")
    selectLabel:SetTextColor(T("TEXT_PRIMARY"))

    local yOff = profile.savedBy and -93 or -75
    local restoreChecks = {}

    local function AddRestoreRow(key, labelText, count, available)
        if not available then return end
        local cb = ns.UI.CreateCheckbox(nil, dialog, "")
        cb:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, yOff)
        cb:SetChecked(true)
        local display = count and count > 0
            and (labelText .. " |cFF888888(" .. count .. ")|r")
            or labelText
        if cb.label then cb.label:SetText(display) end
        restoreChecks[key] = cb
        yOff = yOff - 30
    end

    AddRestoreRow("keybinds",
        L["SP_KEYBINDS"],
        type(profile.keybinds) == "table" and profile.keybinds.count or 0,
        type(profile.keybinds) == "table")

    AddRestoreRow("accountMacros",
        L["SP_ACCOUNT_MACROS"],
        type(profile.accountMacros) == "table" and profile.accountMacros.count or 0,
        type(profile.accountMacros) == "table")

    AddRestoreRow("characterMacros",
        L["SP_CHARACTER_MACROS"],
        type(profile.characterMacros) == "table" and profile.characterMacros.count or 0,
        type(profile.characterMacros) == "table")

    AddRestoreRow("gameSettings",
        L["SP_GAME_SETTINGS"],
        type(profile.gameSettings) == "table" and profile.gameSettings.count or 0,
        type(profile.gameSettings) == "table")

    AddRestoreRow("addonSet",
        L["SP_ADDON_SET"],
        type(profile.addonSet) == "table" and profile.addonSet.count or 0,
        type(profile.addonSet) == "table")

    AddRestoreRow("addonSettings",
        L["SP_ADDON_SETTINGS"],
        type(profile.addonSettings) == "table" and profile.addonSettings.count or 0,
        type(profile.addonSettings) == "table")

    local restoreBtn = ns.UI.CreateButton(nil, dialog, L["SP_RESTORE_PROFILE"], 140, 30)
    restoreBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -10, 10)
    restoreBtn:SetScript("OnClick", function()
        if not ns.SettingsProfilesModule then
            print("|cFFFFD100OneWoW - AltTracker:|r Character addon not loaded.")
            dialog:Hide()
            return
        end

        local M = ns.SettingsProfilesModule
        local results = {}
        local reloadNeeded = false

        if restoreChecks.keybinds and restoreChecks.keybinds:GetChecked() then
            local n = M:RestoreKeybinds(profile.keybinds)
            table.insert(results, string.format("%d %s", n, L["SP_KEYBINDS"]))
        end

        if restoreChecks.accountMacros and restoreChecks.accountMacros:GetChecked() then
            local n = M:RestoreMacros(
                { account = type(profile.accountMacros) == "table" and profile.accountMacros.data or {} },
                true, false)
            table.insert(results, string.format("%d %s", n, L["SP_ACCOUNT_MACROS"]))
        end

        if restoreChecks.characterMacros and restoreChecks.characterMacros:GetChecked() then
            local n = M:RestoreMacros(
                { character = type(profile.characterMacros) == "table" and profile.characterMacros.data or {} },
                false, true)
            table.insert(results, string.format("%d %s", n, L["SP_CHARACTER_MACROS"]))
        end

        if restoreChecks.gameSettings and restoreChecks.gameSettings:GetChecked() then
            local n = M:RestoreGameSettings(profile.gameSettings)
            table.insert(results, string.format("%d %s", n, L["SP_GAME_SETTINGS"]))
            reloadNeeded = true
        end

        if restoreChecks.addonSet and restoreChecks.addonSet:GetChecked() then
            local n = M:RestoreAddonSet(profile.addonSet)
            table.insert(results, string.format("%d changes to %s", n, L["SP_ADDON_SET"]))
            reloadNeeded = true
        end

        if restoreChecks.addonSettings and restoreChecks.addonSettings:GetChecked() then
            local n = M:RestoreAddonSettings(profile.addonSettings)
            table.insert(results, string.format("%d %s", n, L["SP_ADDON_SETTINGS"]))
            reloadNeeded = true
        end

        dialog:Hide()

        print(string.format(L["SP_PROFILE_RESTORED"], profileName))
        for _, line in ipairs(results) do
            print("  |cFFFFD100-|r " .. line)
        end

        if reloadNeeded then
            print("|cFFFFD100OneWoW - AltTracker:|r A UI reload is required to apply changes.")
            C_Timer.After(1.5, function()
                StaticPopupDialogs["WNAT_SP_RELOAD"] = {
                    text = "A UI reload is required to apply restored settings. Reload now?",
                    button1 = "Reload",
                    button2 = "Later",
                    OnAccept = function() ReloadUI() end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show("WNAT_SP_RELOAD")
            end)
        end
    end)

    local cancelBtn = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    cancelBtn:SetSize(100, 30)
    cancelBtn:SetPoint("BOTTOMRIGHT", restoreBtn, "BOTTOMLEFT", -8, 0)
    cancelBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    cancelBtn:SetBackdropColor(T("BG_SECONDARY"))
    cancelBtn:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local cancelText = cancelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cancelText:SetPoint("CENTER")
    cancelText:SetText("Cancel")
    cancelText:SetTextColor(T("TEXT_PRIMARY"))

    cancelBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        cancelText:SetTextColor(T("TEXT_ACCENT"))
    end)
    cancelBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_SECONDARY"))
        cancelText:SetTextColor(T("TEXT_PRIMARY"))
    end)
    cancelBtn:SetScript("OnClick", function() dialog:Hide() end)

    dialog:SetHeight(math.abs(yOff) + 60)
    dialog:Show()
end

-- ============================================================
-- Export Dialog
-- ============================================================

function ns.UI.ShowExportDialog(profileName, serializedStr)
    local dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dialog:SetSize(620, 500)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetToplevel(true)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    dialog:SetBackdropColor(T("BG_PRIMARY"))
    dialog:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local titleBar = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    titleBar:SetBackdropColor(T("TITLEBAR_BG"))

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleText:SetText(L["SP_EXPORT_PROFILE"] .. ": |cFFFFD100" .. profileName .. "|r")
    titleText:SetTextColor(T("TEXT_PRIMARY"))

    local hint = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -38)
    hint:SetText(L["SP_EXPORT_COPY_HINT"])
    hint:SetTextColor(T("TEXT_SECONDARY"))

    local textBG = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    textBG:SetPoint("TOPLEFT", dialog, "TOPLEFT", 10, -58)
    textBG:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -10, 46)
    textBG:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    textBG:SetBackdropColor(0.06, 0.06, 0.06)
    textBG:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    textBG:SetClipsChildren(true)

    local eb = CreateFrame("EditBox", nil, textBG)
    eb:SetPoint("TOPLEFT", textBG, "TOPLEFT", 4, -4)
    eb:SetPoint("BOTTOMRIGHT", textBG, "BOTTOMRIGHT", -4, 4)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(true)
    eb:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    eb:SetTextColor(1, 1, 1)
    eb:SetMaxLetters(0)
    eb:SetScript("OnEscapePressed", function() dialog:Hide() end)

    local closeBtn = ns.UI.CreateButton(nil, dialog, "Close", 100, 28)
    closeBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -10, 10)
    closeBtn:SetScript("OnClick", function() dialog:Hide() end)

    local selectAllBtn = ns.UI.CreateButton(nil, dialog, L["SP_SELECT_ALL"], 110, 28)
    selectAllBtn:SetPoint("BOTTOMRIGHT", closeBtn, "BOTTOMLEFT", -8, 0)
    selectAllBtn:SetScript("OnClick", function()
        eb:SetFocus()
        eb:HighlightText()
    end)

    dialog:Show()
    C_Timer.After(0, function()
        eb:SetText(serializedStr or "")
        eb:SetCursorPosition(0)
    end)
end

-- ============================================================
-- Import Dialog
-- ============================================================

function ns.UI.ShowImportDialog(parent)
    local dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dialog:SetSize(620, 460)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetToplevel(true)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    dialog:SetBackdropColor(T("BG_PRIMARY"))
    dialog:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local titleBar = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    titleBar:SetBackdropColor(T("TITLEBAR_BG"))

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleText:SetText(L["SP_IMPORT_PROFILE"])
    titleText:SetTextColor(T("TEXT_PRIMARY"))

    local hint = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -38)
    hint:SetText(L["SP_IMPORT_PASTE_HINT"])
    hint:SetTextColor(T("TEXT_SECONDARY"))

    local textBG = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    textBG:SetPoint("TOPLEFT", dialog, "TOPLEFT", 10, -58)
    textBG:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -10, 46)
    textBG:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    textBG:SetBackdropColor(0.06, 0.06, 0.06)
    textBG:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local eb = CreateFrame("EditBox", nil, dialog)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(true)
    eb:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    eb:SetTextColor(1, 1, 1)
    eb:SetMaxLetters(0)
    eb:SetSize(588, 340)
    eb:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -64)
    eb:SetScript("OnEscapePressed", function() dialog:Hide() end)

    local importBtn = ns.UI.CreateButton(nil, dialog, L["SP_IMPORT_BTN"], 120, 28)
    importBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -10, 10)
    importBtn:SetScript("OnClick", function()
        local text = eb:GetText()
        if not ns.SettingsProfilesModule then
            print("|cFFFFD100OneWoW - AltTracker:|r Character addon not loaded.")
            return
        end
        local ok, result = ns.SettingsProfilesModule:ImportProfile(text)
        if ok then
            print(string.format(L["SP_IMPORT_SUCCESS"], result))
            dialog:Hide()
            ns.UI.RefreshSettingsListing(parent)
        else
            print(string.format(L["SP_IMPORT_FAILED"], result or "unknown error"))
        end
    end)

    local cancelBtn = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    cancelBtn:SetSize(100, 28)
    cancelBtn:SetPoint("BOTTOMRIGHT", importBtn, "BOTTOMLEFT", -8, 0)
    cancelBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    cancelBtn:SetBackdropColor(T("BG_SECONDARY"))
    cancelBtn:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local cancelText = cancelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cancelText:SetPoint("CENTER")
    cancelText:SetText("Cancel")
    cancelText:SetTextColor(T("TEXT_PRIMARY"))
    cancelBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        cancelText:SetTextColor(T("TEXT_ACCENT"))
    end)
    cancelBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_SECONDARY"))
        cancelText:SetTextColor(T("TEXT_PRIMARY"))
    end)
    cancelBtn:SetScript("OnClick", function() dialog:Hide() end)

    dialog:Show()
end

-- ============================================================
-- Main UI
-- ============================================================

function ns.UI.CreateSettingsUI(parent)
    if not ns.SettingsProfilesModule then
        local contentPanel = parent.contentPanel or parent
        local msg = contentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        msg:SetPoint("CENTER")
        msg:SetText("|cFFFF4444OneWoW_AltTracker_Character addon not loaded.|r")
        return
    end

    local M = ns.SettingsProfilesModule
    local contentPanel = parent.contentPanel or parent
    local scrollFrame, scrollContent = ns.UI.CreateScrollFrame(nil, contentPanel,
        contentPanel:GetWidth() - 20, contentPanel:GetHeight())

    local yOffset = -10
    local counts = M:GetCurrentCounts()

    local createHeader = ns.UI.CreateSectionHeader(scrollContent, L["SP_NEW_PROFILE"], yOffset)
    yOffset = createHeader.bottomY - 12

    local nameLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", 15, yOffset)
    nameLabel:SetText(L["SP_PROFILE_NAME"] .. ":")
    nameLabel:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - 18

    local nameEdit = ns.UI.CreateEditBox(nil, scrollContent, 380, 28)
    nameEdit:SetPoint("TOPLEFT", 15, yOffset)
    nameEdit:SetMaxLetters(64)

    local saveBtn = ns.UI.CreateButton(nil, scrollContent, L["SP_SAVE_PROFILE"], 160, 28)
    saveBtn:SetPoint("TOPLEFT", nameEdit, "TOPRIGHT", 12, 0)

    yOffset = yOffset - 38

    local contentsLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    contentsLabel:SetPoint("TOPLEFT", 15, yOffset)
    contentsLabel:SetText("Profile Contents:")
    contentsLabel:SetTextColor(T("TEXT_SECONDARY"))
    yOffset = yOffset - 22

    local COL1_X = 20
    local COL2_X = 380
    local COL3_X = 700

    local function MakeCheckbox(labelText, count, xPos, yPos)
        local cb = ns.UI.CreateCheckbox(nil, scrollContent, "")
        cb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", xPos, yPos)
        cb:SetChecked(false)
        local display = (count and count > 0) and (labelText .. " (" .. count .. ")") or labelText
        if cb.label then cb.label:SetText(display) end
        return cb
    end

    local cbKeybinds  = MakeCheckbox(L["SP_KEYBINDS"],          counts.keybinds,        COL1_X, yOffset)
    local cbAccMacros = MakeCheckbox(L["SP_ACCOUNT_MACROS"],    counts.accountMacros,   COL2_X, yOffset)
    local cbAddonSet  = MakeCheckbox(L["SP_ADDON_SET"],          counts.addonSet,        COL3_X, yOffset)
    yOffset = yOffset - 28

    local cbGameSet      = MakeCheckbox(L["SP_GAME_SETTINGS"],     nil,                    COL1_X, yOffset)
    local cbCharMacro    = MakeCheckbox(L["SP_CHARACTER_MACROS"],  counts.characterMacros, COL2_X, yOffset)
    local cbAddonSettings = MakeCheckbox(L["SP_ADDON_SETTINGS"],   nil,                    COL3_X, yOffset)
    yOffset = yOffset - 36

    saveBtn:SetScript("OnClick", function()
        local name = nameEdit:GetText()
        local opts = {
            keybinds        = cbKeybinds:GetChecked()  and true or false,
            accountMacros   = cbAccMacros:GetChecked() and true or false,
            characterMacros = cbCharMacro:GetChecked() and true or false,
            gameSettings    = cbGameSet:GetChecked()   and true or false,
            addonSet        = cbAddonSet:GetChecked()  and true or false,
            addonSettings   = cbAddonSettings:GetChecked() and true or false,
        }
        if M:SaveProfile(name, opts) then
            nameEdit:SetText("")
            cbKeybinds:SetChecked(false)
            cbAccMacros:SetChecked(false)
            cbCharMacro:SetChecked(false)
            cbGameSet:SetChecked(false)
            cbAddonSet:SetChecked(false)
            cbAddonSettings:SetChecked(false)
            ns.UI.RefreshSettingsListing(parent)
        end
    end)

    local listHeader = ns.UI.CreateSectionHeader(scrollContent, "Saved Profiles", yOffset)
    local importHeaderBtn = ns.UI.CreateButton(nil, listHeader, L["SP_IMPORT_PROFILE"], 130, 22)
    importHeaderBtn:SetPoint("RIGHT", listHeader, "RIGHT", -6, 0)
    importHeaderBtn:SetScript("OnClick", function()
        ns.UI.ShowImportDialog(parent)
    end)
    yOffset = listHeader.bottomY - 8

    local listContainer = CreateFrame("Frame", nil, scrollContent)
    listContainer:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
    listContainer:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
    listContainer:SetHeight(20)

    scrollContent:SetHeight(math.abs(yOffset) + 20)

    parent.settingsScrollFrame   = scrollFrame
    parent.settingsScrollContent = scrollContent
    parent.settingsListContainer = listContainer
    parent.settingsListStartY    = yOffset
end

function ns.UI.RefreshSettingsListing(parent)
    if not parent or not parent.settingsListContainer then return end
    if not ns.SettingsProfilesModule then return end

    local M = ns.SettingsProfilesModule
    local listContainer = parent.settingsListContainer

    for _, child in ipairs({ listContainer:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    local profilesList = M:GetProfilesList()

    if #profilesList == 0 then
        local empty = listContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        empty:SetPoint("TOPLEFT", 15, -14)
        empty:SetText(L["SP_NO_PROFILES"] or "No profiles saved")
        empty:SetTextColor(T("TEXT_SECONDARY"))
        listContainer:SetHeight(40)
        parent.settingsScrollContent:SetHeight(math.abs(parent.settingsListStartY) + 40)
        return
    end

    local CARD_H = 68
    local CARD_GAP = 6
    local yOff = 0

    for _, entry in ipairs(profilesList) do
        local name = entry.name
        local data = entry.data

        local card = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
        card:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 8, yOff)
        card:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", -8, yOff)
        card:SetHeight(CARD_H)
        card:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        card:SetBackdropColor(T("BG_TERTIARY"))
        card:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
        nameText:SetText(name)
        nameText:SetTextColor(T("TEXT_PRIMARY"))

        local dateText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dateText:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -26)
        local dateStr = "Saved: " .. date("%Y-%m-%d %H:%M", data.timestamp or 0)
        if data.savedBy then
            dateStr = dateStr .. "  |cFF888888" .. L["SP_SAVED_BY"] .. ": " .. data.savedBy .. "|r"
        end
        dateText:SetText(dateStr)
        dateText:SetTextColor(T("TEXT_SECONDARY"))

        local tags = {}
        if type(data.keybinds) == "table" then
            table.insert(tags, string.format("%s (%d)", L["SP_KEYBINDS"], data.keybinds.count or 0))
        end
        if type(data.accountMacros) == "table" then
            table.insert(tags, string.format("%s (%d)", L["SP_ACCOUNT_MACROS"], data.accountMacros.count or 0))
        end
        if type(data.characterMacros) == "table" then
            table.insert(tags, string.format("%s (%d)", L["SP_CHARACTER_MACROS"], data.characterMacros.count or 0))
        end
        if type(data.gameSettings) == "table" then
            table.insert(tags, string.format("%s (%d CVars)", L["SP_GAME_SETTINGS"], data.gameSettings.count or 0))
        end
        if type(data.addonSet) == "table" then
            table.insert(tags, string.format("%s (%d)", L["SP_ADDON_SET"], data.addonSet.count or 0))
        end
        if type(data.addonSettings) == "table" then
            table.insert(tags, string.format("%s (%d)", L["SP_ADDON_SETTINGS"], data.addonSettings.count or 0))
        end

        local tagsText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tagsText:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -44)
        tagsText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -278, -44)
        tagsText:SetText(#tags > 0 and table.concat(tags, "  |cFF444444/|r  ") or "")
        tagsText:SetTextColor(T("TEXT_SECONDARY"))
        tagsText:SetJustifyH("LEFT")

        local exportBtn = ns.UI.CreateButton(nil, card, L["SP_EXPORT_PROFILE"], 80, 26)
        exportBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -192, 6)
        exportBtn:SetScript("OnClick", function()
            if not ns.SettingsProfilesModule then return end
            local exportData = {}
            for k, v in pairs(data) do
                if k ~= "gameSettings" and k ~= "addonSettings" then
                    exportData[k] = v
                end
            end
            local serialized = ns.SettingsProfilesModule:SerializeProfile(exportData)
            if serialized then
                ns.UI.ShowExportDialog(name, serialized)
            end
        end)

        local restoreBtn = ns.UI.CreateButton(nil, card, L["SP_RESTORE_PROFILE"], 90, 26)
        restoreBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -96, 6)
        restoreBtn:SetScript("OnClick", function()
            ns.UI.ShowSettingsRestoreDialog(parent, name, data)
        end)

        local deleteBtn = CreateFrame("Button", nil, card, "BackdropTemplate")
        deleteBtn:SetSize(82, 26)
        deleteBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, 6)
        deleteBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        deleteBtn:SetBackdropColor(0.45, 0.12, 0.12)
        deleteBtn:SetBackdropBorderColor(0.65, 0.25, 0.25)

        local delText = deleteBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        delText:SetPoint("CENTER")
        delText:SetText("Delete")
        delText:SetTextColor(1, 1, 1)

        deleteBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.65, 0.18, 0.18) end)
        deleteBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.45, 0.12, 0.12) end)
        deleteBtn:SetScript("OnClick", function()
            StaticPopupDialogs["WNAT_DELETE_SP"] = {
                text = "Delete profile: |cFFFFD100" .. name .. "|r?",
                button1 = "Delete",
                button2 = "Cancel",
                OnAccept = function()
                    M:DeleteProfile(name)
                    ns.UI.RefreshSettingsListing(parent)
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("WNAT_DELETE_SP")
        end)

        yOff = yOff - (CARD_H + CARD_GAP)
    end

    local listHeight = math.abs(yOff) + CARD_GAP
    listContainer:SetHeight(listHeight)
    parent.settingsScrollContent:SetHeight(math.abs(parent.settingsListStartY) + listHeight + 20)
end
