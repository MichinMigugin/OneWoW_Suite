local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local UI = ns.UI
local SE = ns.SearchExpand
local PE = ns.PredicateEngine

local ipairs = ipairs
local pairs = pairs
local sort = sort
local tinsert = tinsert
local tconcat = table.concat
local strlower = string.lower
local strtrim = strtrim

local StaticPopupDialogs = StaticPopupDialogs
local StaticPopup_Show = StaticPopup_Show
local GameTooltip = GameTooltip

local aliasRows = {}
local savedRows = {}
local aliasListContent
local savedListContent
local aliasEmptyText
local savedEmptyText
local refreshLayouts
local draftAliasPending = false

local ALIAS_ROW_HEIGHT = 34

local function ShowExprDialog(title, initial, onAccept)
    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_SearchShortcutExpr",
        title = title,
        width = 480,
        height = 260,
        showBrand = false,
    })
    local dialog = result.frame
    local content = result.contentFrame

    local editContainer = OneWoW_GUI:CreateFrame(content, {
        bgColor = "BG_TERTIARY",
        borderColor = "BORDER_SUBTLE",
    })
    editContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -14)
    editContainer:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -14, 48)

    local _, box = OneWoW_GUI:CreateScrollEditBox(editContainer, {
        name = "OneWoW_SearchShortcutExprBox",
        fontSize = 12,
    })
    -- Width must be set before SetText so multi-line layout wraps correctly
    -- (scroll OnSizeChanged may not have fired yet on a freshly shown dialog).
    box:SetWidth(440)
    box:SetText(initial or "")
    box:SetCursorPosition(0)

    local saveBtn = OneWoW_GUI:CreateFitTextButton(content, { text = SAVE, height = 28 })
    saveBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -14, 12)

    local cancelBtn = OneWoW_GUI:CreateFitTextButton(content, { text = CANCEL, height = 28 })
    cancelBtn:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function() dialog:Hide() end)

    saveBtn:SetScript("OnClick", function()
        local text = box:GetText() or ""
        onAccept(text)
        dialog:Hide()
    end)

    OneWoW_GUI:ApplyFontToFrame(dialog)
    dialog:Show()
    box:SetFocus()
end

local function RegisterPopups()
    if StaticPopupDialogs["ONEWOW_SEARCH_SHORTCUT_NAME"] then return end

    local function DialogEditBox(dialog)
        return dialog.editBox or dialog.EditBox
    end

    StaticPopupDialogs["ONEWOW_SEARCH_SHORTCUT_NAME"] = {
        text = "%s",
        hasEditBox = true,
        button1 = SAVE,
        button2 = CANCEL,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(dialog, data)
            data = data or dialog.data
            if not data or not data.onAccept then return end
            local editBox = DialogEditBox(dialog)
            data.onAccept(editBox and editBox:GetText() or "")
        end,
        EditBoxOnEnterPressed = function(editBox)
            local dialog = editBox:GetParent()
            local info = StaticPopupDialogs["ONEWOW_SEARCH_SHORTCUT_NAME"]
            info.OnAccept(dialog, dialog.data)
            dialog:Hide()
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
    }

    StaticPopupDialogs["ONEWOW_SEARCH_SHORTCUT_DELETE"] = {
        text = "%s",
        button1 = DELETE,
        button2 = CANCEL,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(_, data)
            if data and data.onAccept then data.onAccept() end
        end,
    }
end

local function ShowNamePopup(prompt, onAccept, initialText)
    local popup = StaticPopup_Show("ONEWOW_SEARCH_SHORTCUT_NAME", prompt, nil, {
        onAccept = onAccept,
    })
    local editBox = popup and (popup.editBox or popup.EditBox)
    if editBox then
        if initialText then
            editBox:SetText(initialText)
        end
        editBox:SetFocus()
    end
    return popup
end

local function NormalizeAliasInput(text)
    return strlower(strtrim((text or ""):gsub("^#", "")))
end

local function BuildBuiltinKeywordItems()
    local items = {}
    -- GetAllKeywords is built-ins only; user tokens live in the catalog.
    for _, entry in ipairs(PE:GetAllKeywords()) do
        local labels = { "#" .. entry.canonical }
        local filterParts = { entry.canonical }
        for _, aliasName in ipairs(entry.aliases or {}) do
            tinsert(labels, "#" .. aliasName)
            tinsert(filterParts, aliasName)
        end
        tinsert(items, {
            value = entry.canonical,
            text = tconcat(labels, ", "),
            filterKey = tconcat(filterParts, " "),
        })
    end
    sort(items, function(a, b)
        return a.value < b.value
    end)
    return items
end

local function AliasErrorMessage(errKey)
    if not errKey then return nil end
    return L[errKey] or errKey
end

local function HideAliasWarningTip()
    GameTooltip:Hide()
end

local function ShowAliasWarningTip(row)
    if not row._warning or not row._warningMsg then return end
    GameTooltip:SetOwner(row.nameBox, "ANCHOR_TOPRIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(row._warningMsg, 1, 0.35, 0.35, true)
    GameTooltip:Show()
end

local function SetAliasRowWarning(row, isWarning, errKey)
    row._warning = isWarning and true or false
    row._warningMsg = isWarning and AliasErrorMessage(errKey) or nil
    if isWarning then
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
    else
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        HideAliasWarningTip()
    end
end

local function SetTargetDropdown(row, target)
    row._target = target
    row.targetDrop._activeValue = target
    if target and target ~= "" then
        row.targetDrop._text:SetText("#" .. target)
    else
        row.targetDrop._text:SetText(L["SEARCH_SHORTCUTS_ALIAS_TARGET_PLACEHOLDER"])
    end
end

local RefreshAliasRows

local function ApplyAliasNameDisplay(row, name)
    if name == "" then return end
    row.nameBox:SetText("#" .. name)
end

local function TryCommitAliasRow(row)
    local name = NormalizeAliasInput(row.nameBox:GetText())
    local target = row._target
    if name == "" or not target or target == "" then
        SetAliasRowWarning(row, false)
        ApplyAliasNameDisplay(row, name)
        return
    end

    if row._committedKey then
        if name ~= row._committedKey then
            local ok, err = SE:RenameAlias(row._committedKey, name)
            if not ok then
                SetAliasRowWarning(row, true, err)
                ApplyAliasNameDisplay(row, name)
                return
            end
            row._committedKey = name
        end
        local aliases = SE:GetAliases()
        if aliases[row._committedKey] ~= target then
            local ok, err = SE:SetAlias(row._committedKey, target)
            if not ok then
                SetAliasRowWarning(row, true, err)
                ApplyAliasNameDisplay(row, name)
                return
            end
        end
        SetAliasRowWarning(row, false)
        ApplyAliasNameDisplay(row, row._committedKey)
        row.nameBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        return
    end

    draftAliasPending = false
    local ok, err = SE:SetAlias(name, target)
    if not ok then
        draftAliasPending = true
        SetAliasRowWarning(row, true, err)
        ApplyAliasNameDisplay(row, name)
        return
    end
    SetAliasRowWarning(row, false)
    -- FireChanged from SetAlias rebuilds the list.
end

local function AcquireAliasRow(index)
    local row = aliasRows[index]
    if row then return row end

    row = CreateFrame("Frame", nil, aliasListContent, "BackdropTemplate")
    row:SetHeight(ALIAS_ROW_HEIGHT)
    row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)

    local nameBox = OneWoW_GUI:CreateEditBox(row, {
        width = 150,
        height = 24,
        maxLetters = 40,
    })
    nameBox:SetPoint("LEFT", row, "LEFT", 6, 0)
    nameBox:SetTextInsets(8, 8, 0, 0)
    row.nameBox = nameBox

    local deleteBtn = OneWoW_GUI:CreateFitTextButton(row, {
        text = DELETE,
        height = 24,
    })
    deleteBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.deleteBtn = deleteBtn

    local targetDrop = OneWoW_GUI:CreateDropdown(row, {
        width = 200,
        height = 24,
        text = L["SEARCH_SHORTCUTS_ALIAS_TARGET_PLACEHOLDER"],
    })
    targetDrop:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
    targetDrop:SetPoint("RIGHT", deleteBtn, "LEFT", -8, 0)
    row.targetDrop = targetDrop

    OneWoW_GUI:AttachFilterMenu(targetDrop, {
        searchable = true,
        menuHeight = 280,
        getActiveValue = function()
            return row._target
        end,
        buildItems = BuildBuiltinKeywordItems,
        onSelect = function(value)
            SetTargetDropdown(row, value)
            TryCommitAliasRow(row)
        end,
    })

    local function BindWarningTip(frame)
        frame:HookScript("OnEnter", function()
            ShowAliasWarningTip(row)
        end)
        frame:HookScript("OnLeave", HideAliasWarningTip)
    end
    BindWarningTip(row)
    BindWarningTip(nameBox)
    BindWarningTip(targetDrop)
    BindWarningTip(deleteBtn)
    row:EnableMouse(true)

    nameBox:SetScript("OnEnterPressed", function(myself)
        myself:ClearFocus()
    end)
    nameBox:HookScript("OnEditFocusLost", function()
        TryCommitAliasRow(row)
    end)
    nameBox:HookScript("OnTextChanged", function(_, userInput)
        if not userInput then return end
        if row._warning then
            SetAliasRowWarning(row, false)
        end
    end)

    deleteBtn:SetScript("OnClick", function()
        if row._committedKey then
            SE:DeleteAlias(row._committedKey)
            RefreshAliasRows()
        else
            draftAliasPending = false
            RefreshAliasRows()
        end
    end)

    aliasRows[index] = row
    return row
end

RefreshAliasRows = function()
    if not aliasListContent then return end
    local aliases = SE:GetAliases()
    local names = {}
    for name in pairs(aliases) do
        tinsert(names, name)
    end
    sort(names)

    local display = {}
    if draftAliasPending then
        tinsert(display, { draft = true })
    end
    for _, name in ipairs(names) do
        -- A keyword registered after this token was stored shadows it outright,
        -- so the row is flagged rather than rendered as if it still worked.
        -- Renaming is the fix; the body is kept either way.
        tinsert(display, {
            key = name,
            target = aliases[name],
            shadowed = SE:IsTokenShadowed(name),
        })
    end

    if aliasEmptyText then
        aliasEmptyText:SetShown(#display == 0)
    end

    for i, entry in ipairs(display) do
        local row = AcquireAliasRow(i)
        if entry.draft then
            row._committedKey = nil
            row.nameBox:SetText("")
            SetTargetDropdown(row, nil)
            SetAliasRowWarning(row, false)
        else
            row._committedKey = entry.key
            row.nameBox:SetText("#" .. entry.key)
            row.nameBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            SetTargetDropdown(row, entry.target)
            SetAliasRowWarning(row, entry.shadowed, "ALIAS_COLLIDES_BUILTIN")
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", aliasListContent, "TOPLEFT", 0, -((i - 1) * (ALIAS_ROW_HEIGHT + 4)))
        row:SetPoint("TOPRIGHT", aliasListContent, "TOPRIGHT", 0, -((i - 1) * (ALIAS_ROW_HEIGHT + 4)))
        row:Show()
    end
    for i = #display + 1, #aliasRows do
        aliasRows[i]:Hide()
    end
    aliasListContent:SetHeight(math.max(1, #display * (ALIAS_ROW_HEIGHT + 4)))
    if refreshLayouts then refreshLayouts() end
end

local function RefreshSavedRows()
    if not savedListContent then return end
    local names = SE:GetSortedSavedNames()

    if savedEmptyText then
        savedEmptyText:SetShown(#names == 0)
    end

    local rowGap = 4
    local padTop = 6
    local padBottom = 8
    local nameQueryGap = 3
    local yPos = 0

    for i, name in ipairs(names) do
        local row = savedRows[i]
        if not row then
            row = CreateFrame("Button", nil, savedListContent, "BackdropTemplate")
            row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
            row.nameText = OneWoW_GUI:CreateFS(row, 12)
            row.nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -padTop)
            row.nameText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.nameText:SetJustifyH("LEFT")
            row.nameText:SetWordWrap(false)
            row.queryText = OneWoW_GUI:CreateFS(row, 11)
            row.queryText:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -nameQueryGap)
            row.queryText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.queryText:SetJustifyH("LEFT")
            row.queryText:SetJustifyV("TOP")
            row.queryText:SetWordWrap(true)
            row.queryText:SetNonSpaceWrap(true)
            row:SetScript("OnEnter", function(myself)
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            end)
            row:SetScript("OnLeave", function(myself)
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            end)
            row:SetScript("OnMouseDown", function(myself, button)
                if button ~= "RightButton" then return end
                local rowName = myself.savedName
                local rowQuery = myself.savedQuery
                MenuUtil.CreateContextMenu(myself, function(_, root)
                    root:CreateButton(L["SEARCH_SHORTCUT_SAVED_EDIT"], function()
                        ShowExprDialog(L["SEARCH_SHORTCUT_SAVED_EDIT_TITLE"]:format(rowName), rowQuery, function(text)
                            local ok, err = SE:SetSaved(rowName, text)
                            if not ok then print(L[err] or err) end
                            RefreshSavedRows()
                        end)
                    end)
                    root:CreateButton(L["RENAME"], function()
                        ShowNamePopup(L["SEARCH_SHORTCUT_SAVED_RENAME_PROMPT"], function(newName)
                            local ok, err = SE:RenameSaved(rowName, newName)
                            if not ok then print(L[err] or err) end
                            RefreshSavedRows()
                        end, rowName)
                    end)
                    root:CreateButton(DELETE, function()
                        StaticPopup_Show("ONEWOW_SEARCH_SHORTCUT_DELETE",
                            L["SEARCH_SHORTCUT_SAVED_DELETE"]:format(rowName), nil, {
                                onAccept = function()
                                    SE:DeleteSaved(rowName)
                                    RefreshSavedRows()
                                end,
                            })
                    end)
                end)
            end)
            savedRows[i] = row
        end
        local query = select(1, SE:GetSaved(name)) or ""
        row.savedName = name
        row.savedQuery = query
        row.nameText:SetText(name)
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        row.queryText:SetText(query)
        row.queryText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        -- Width must be known before measuring wrapped query height.
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", savedListContent, "TOPLEFT", 0, -yPos)
        row:SetPoint("TOPRIGHT", savedListContent, "TOPRIGHT", 0, -yPos)
        row:SetHeight(80)
        local nameH = math.max(12, row.nameText:GetStringHeight() or 12)
        local queryH = math.max(11, row.queryText:GetStringHeight() or 11)
        local rowHeight = padTop + nameH + nameQueryGap + queryH + padBottom
        row:SetHeight(rowHeight)
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        row:Show()
        yPos = yPos + rowHeight + rowGap
    end
    for i = #names + 1, #savedRows do
        savedRows[i]:Hide()
    end
    savedListContent:SetHeight(math.max(1, yPos))
    if refreshLayouts then refreshLayouts() end
end

function UI:CreateSearchShortcutsTab(parent)
    RegisterPopups()

    local _, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_SearchShortcutsScroll" })
    refreshLayouts = function()
        local savedH = savedListContent and savedListContent:GetHeight() or 0
        content:SetHeight(math.max(800, 220 + (#aliasRows * (ALIAS_ROW_HEIGHT + 4)) + savedH))
    end

    local y = -10

    local title = OneWoW_GUI:CreateFS(content, 16)
    title:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    title:SetText(L["SEARCH_SHORTCUTS_TITLE"])
    title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    y = y - 24

    local desc = OneWoW_GUI:CreateFS(content, 12)
    desc:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    desc:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, y)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText(L["SEARCH_SHORTCUTS_DESC"])
    desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    y = y - 48

    -- Keyword aliases
    y = OneWoW_GUI:CreateSection(content, { title = L["SEARCH_SHORTCUTS_ALIASES_SECTION"], yOffset = y })
    local aliasHelp = OneWoW_GUI:CreateFS(content, 11)
    aliasHelp:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    aliasHelp:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, y)
    aliasHelp:SetJustifyH("LEFT")
    aliasHelp:SetWordWrap(true)
    aliasHelp:SetText(L["SEARCH_SHORTCUTS_ALIASES_HELP"])
    aliasHelp:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    y = y - 36

    local addAlias = OneWoW_GUI:CreateFitTextButton(content, {
        text = L["SEARCH_SHORTCUTS_ADD_ALIAS"],
        height = 26,
    })
    addAlias:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    addAlias:SetScript("OnClick", function()
        if not draftAliasPending then
            draftAliasPending = true
            RefreshAliasRows()
        end
        if aliasRows[1] and aliasRows[1].nameBox then
            aliasRows[1].nameBox:SetFocus()
        end
    end)
    y = y - 34

    local aliasFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    aliasFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    aliasFrame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, y)
    aliasFrame:SetHeight(160)
    aliasFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    aliasFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    aliasFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    local _, aliasContent = OneWoW_GUI:CreateScrollFrame(aliasFrame, {})
    aliasListContent = aliasContent
    aliasEmptyText = OneWoW_GUI:CreateFS(aliasContent, 11)
    aliasEmptyText:SetPoint("TOPLEFT", aliasContent, "TOPLEFT", 8, -8)
    aliasEmptyText:SetText(L["SEARCH_SHORTCUTS_ALIASES_EMPTY"])
    aliasEmptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    y = y - 172

    -- Named expressions
    y = OneWoW_GUI:CreateSection(content, { title = L["SEARCH_SHORTCUTS_SAVED_SECTION"], yOffset = y })
    local savedHelp = OneWoW_GUI:CreateFS(content, 11)
    savedHelp:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    savedHelp:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, y)
    savedHelp:SetJustifyH("LEFT")
    savedHelp:SetWordWrap(true)
    savedHelp:SetText(L["SEARCH_SHORTCUTS_SAVED_HELP"])
    savedHelp:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    y = y - 48

    local addSaved = OneWoW_GUI:CreateFitTextButton(content, {
        text = L["SEARCH_SHORTCUTS_ADD_SAVED"],
        height = 26,
    })
    addSaved:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    addSaved:SetScript("OnClick", function()
        ShowNamePopup(L["SEARCH_SHORTCUTS_SAVED_NAME_PROMPT"], function(nameText)
            ShowExprDialog(L["SEARCH_SHORTCUT_SAVED_EDIT_TITLE"]:format(nameText), "", function(expr)
                local ok, err = SE:SetSaved(nameText, expr)
                if not ok then print(L[err] or err) end
                RefreshSavedRows()
            end)
        end)
    end)
    y = y - 34

    local savedFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    savedFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    savedFrame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, y)
    savedFrame:SetHeight(200)
    savedFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    savedFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    savedFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    local _, savedContent = OneWoW_GUI:CreateScrollFrame(savedFrame, {})
    savedListContent = savedContent
    savedEmptyText = OneWoW_GUI:CreateFS(savedContent, 11)
    savedEmptyText:SetPoint("TOPLEFT", savedContent, "TOPLEFT", 8, -8)
    savedEmptyText:SetText(L["SEARCH_SHORTCUTS_SAVED_EMPTY"])
    savedEmptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    y = y - 220

    local catNote = OneWoW_GUI:CreateFS(content, 11)
    catNote:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    catNote:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, y)
    catNote:SetJustifyH("LEFT")
    catNote:SetWordWrap(true)
    catNote:SetText(L["SEARCH_SHORTCUTS_CATEGORY_NOTE"])
    catNote:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    content:SetHeight(900)

    parent.Activate = function()
        RefreshAliasRows()
        RefreshSavedRows()
    end

    SE:RegisterChangedCallback("SearchShortcutsUI", function()
        -- Keep an in-progress draft row; rebuild committed aliases from store.
        RefreshAliasRows()
        RefreshSavedRows()
    end)

    RefreshAliasRows()
    RefreshSavedRows()
end
