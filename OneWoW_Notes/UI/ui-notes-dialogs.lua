local addonName, ns = ...
local L = ns.L
local T = ns.T

ns.UI = ns.UI or {}

local lib = LibStub("OneWoW_GUI-1.0", true)

local function GetFontColorFromKey(fontColorKey, pinColorKey)
    return ns.Config:GetResolvedFontColor(fontColorKey, pinColorKey)
end

local function MakeLabel(parent, text, x, y)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(text)
    lbl:SetTextColor(T("TEXT_SECONDARY"))
    return lbl
end

function ns.UI.ShowAddNoteDialog()
    local dialog = ns.UI.CreateThemedDialog({
        name            = "OneWoW_NotesAddNoteDialog",
        title           = L["DIALOG_ADD_NOTE_TITLE"],
        width           = 580,
        height          = 580,
        destroyOnClose  = true,
        buttons = {
            {
                text = L["BUTTON_ADD_NOTE"],
                onClick = function(dlg)
                    local noteTitle = dlg.titleInput and dlg.titleInput:GetText() or ""
                    if noteTitle == "" then
                        print("|cFFFFD100OneWoW - Notes:|r " .. L["ERROR_ENTER_NOTE_TITLE"])
                        return
                    end

                    local selectedCategory = dlg.catDD and dlg.catDD:GetValue() or "General"
                    local selectedStorage  = dlg.storeDD and dlg.storeDD:GetValue() or "account"
                    local selectedColor    = dlg.colorDD and dlg.colorDD:GetValue() or "hunter"
                    local selectedFontColor = dlg.fontColorDD and dlg.fontColorDD:GetValue() or "match"
                    local selectedFontFamily = dlg.fontFamilyDD and dlg.fontFamilyDD:GetValue() or nil
                    local selectedFontOutline = dlg.selectedFontOutline or ""
                    local selectedFontSize  = dlg.selectedFontSize or 12
                    local selectedOpacity   = dlg.selectedOpacity  or 0.9
                    local selectedNoteType  = dlg.noteTypeDD and dlg.noteTypeDD:GetValue() or "standard"
                    local noteContent = dlg.contentEditBox and dlg.contentEditBox:GetText() or ""

                    local noteData = {
                        content       = noteContent,
                        category      = selectedCategory,
                        storage       = selectedStorage,
                        pinColor      = selectedColor,
                        fontColor     = selectedFontColor,
                        fontFamily    = selectedFontFamily,
                        fontOutline   = selectedFontOutline,
                        fontSize      = selectedFontSize,
                        opacity       = selectedOpacity,
                        type          = "Note",
                        pinEnabled    = false,
                        todos         = {},
                        tags          = {},
                        tasksOnTop    = false,
                        favorite      = false,
                        created       = GetServerTime(),
                        modified      = GetServerTime(),
                        noteType      = selectedNoteType,
                        lastReset     = 0,
                        autoPinEnabled = dlg.autoPinCheckbox and dlg.autoPinCheckbox:GetChecked() or false,
                        autoUnpinned  = false
                    }

                    if ns.NotesData then
                        local noteID = ns.NotesData:AddNote(noteTitle, noteData)
                        if noteID then
                            print("|cFFFFD100OneWoW - Notes:|r " .. string.format(L["SUCCESS_NOTE_ADDED"], noteTitle))
                            dlg:Hide()
                            if ns.UI.notesFrame and ns.UI.notesFrame.RefreshNotesList then
                                ns.UI.notesFrame.RefreshNotesList()
                                C_Timer.After(0.1, function()
                                    if ns.UI.notesFrame.setSelectedNote then
                                        ns.UI.notesFrame.setSelectedNote(noteID)
                                    end
                                end)
                            end
                        end
                    end
                end,
            },
            { text = L["BUTTON_CANCEL"], onClick = function(dlg) dlg:Hide() end },
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local COL1_X  = 10
    local COL2_X  = 300
    local COL_W   = 260
    local yPos    = -10
    local ROW_H   = 50
    local LBL_GAP = 18

    MakeLabel(content, L["LABEL_NOTE_TITLE"], COL1_X, yPos)
    local titleInput = lib:CreateEditBox(nil, content, { height = 26 })
    titleInput:SetPoint("TOPLEFT",  content, "TOPLEFT",  COL1_X,  yPos - LBL_GAP)
    titleInput:SetPoint("TOPRIGHT", content, "TOPRIGHT", -COL1_X, yPos - LBL_GAP)
    titleInput:SetAutoFocus(true)
    titleInput:SetTextColor(T("TEXT_PRIMARY"))
    titleInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    dialog.titleInput = titleInput
    yPos = yPos - ROW_H - 4

    MakeLabel(content, L["LABEL_CATEGORY"], COL1_X, yPos)
    local catDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local catOpts = {{text = L["CATEGORY_GENERAL"], value = "General"}}
    if ns.NotesCategories then
        for _, c in ipairs(ns.NotesCategories:GetCategories()) do
            catOpts[#catOpts + 1] = {text = c, value = c}
        end
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected("General")
    dialog.catDD = catDD

    MakeLabel(content, L["LABEL_STORAGE"], COL2_X, yPos)
    local storeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    storeDD:SetOptions({
        {text = L["STORAGE_ACCOUNT_WIDE"],   value = "account"},
        {text = L["STORAGE_TYPE_CHARACTER"], value = "character"},
    })
    storeDD:SetSelected("account")
    dialog.storeDD = storeDD
    yPos = yPos - ROW_H

    local currentPinColor   = "hunter"
    local currentFontColor  = "match"
    local contentBg         = nil

    local function UpdatePreview()
        if not contentBg then return end
        local colorConfig = ns.Config:GetResolvedColorConfig(currentPinColor)
        local bgColor     = colorConfig.background
        local borderColor = colorConfig.border
        local opacity     = dialog.selectedOpacity or 0.9
        contentBg:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], opacity)
        contentBg:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 0.8)
        if dialog.contentEditBox then
            local fc = GetFontColorFromKey(currentFontColor, currentPinColor)
            dialog.contentEditBox:SetTextColor(fc[1], fc[2], fc[3], 1)
            local fontSize = dialog.selectedFontSize or 12
            local fontPath = "Fonts\\FRIZQT__.TTF"
            local fontName = dialog.selectedFontFamily
            if fontName then
                local LSM = LibStub("LibSharedMedia-3.0", true)
                if LSM then
                    local path = LSM:Fetch("font", fontName)
                    if path then
                        fontPath = path
                    end
                end
            end
            dialog.contentEditBox:SetFont(fontPath, fontSize, dialog.selectedFontOutline or "")
        end
    end

    MakeLabel(content, L["LABEL_NOTE_COLOR"], COL1_X, yPos)
    local colorDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    colorDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local colorOpts = {}
    for key, colorData in pairs(ns.Config.PIN_COLORS) do
        colorOpts[#colorOpts + 1] = {text = colorData.name, value = key}
    end
    table.sort(colorOpts, function(a, b) return a.text < b.text end)
    colorDD:SetOptions(colorOpts)
    colorDD:SetSelected("hunter")
    colorDD.onSelect = function(value)
        currentPinColor = value
        UpdatePreview()
    end
    dialog.colorDD = colorDD

    MakeLabel(content, L["LABEL_FONT_COLOR"], COL2_X, yPos)
    local fontColorDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    fontColorDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    fontColorDD:SetOptions({
        {text = "OneWoW Sync",                value = "sync"},
        {text = L["FONT_COLOR_MATCHING"],    value = "match"},
        {text = L["FONT_COLOR_WHITE"],      value = "white"},
        {text = L["FONT_COLOR_BLACK"],      value = "black"},
    })
    fontColorDD:SetSelected("match")
    fontColorDD.onSelect = function(value)
        currentFontColor = value
        UpdatePreview()
    end
    dialog.fontColorDD = fontColorDD
    yPos = yPos - ROW_H

    MakeLabel(content, L["LABEL_FONT_SIZE"], COL1_X, yPos)
    dialog.selectedFontSize = 12
    local fontSizeContainer = lib:CreateSlider(content, 10, 20, 1, 12, function(val)
        dialog.selectedFontSize = val
        UpdatePreview()
    end, COL_W, "%d")
    fontSizeContainer:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)

    MakeLabel(content, L["LABEL_NOTE_FONT"], COL2_X, yPos)
    local LSM = LibStub("LibSharedMedia-3.0", true)
    local fontList = {}
    if LSM then
        fontList = LSM:List("font") or {}
    end
    table.sort(fontList)
    local fontOpts = {}
    for _, fontName in ipairs(fontList) do
        fontOpts[#fontOpts + 1] = {text = fontName, value = fontName}
    end
    fontOpts[#fontOpts + 1] = {text = L["FONT_DEFAULT"], value = "default"}
    local fontFamilyDD = ns.UI.CreateFontDropdown(content, COL_W, 26)
    fontFamilyDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    fontFamilyDD:SetOptions(fontOpts)
    fontFamilyDD:SetSelected("default")
    fontFamilyDD.onSelect = function(value)
        dialog.selectedFontFamily = (value == "default") and nil or value
        UpdatePreview()
    end
    dialog.fontFamilyDD = fontFamilyDD
    yPos = yPos - ROW_H

    MakeLabel(content, L["LABEL_OPACITY"], COL1_X, yPos)
    dialog.selectedOpacity = 0.9
    local opacityContainer = lib:CreateSlider(content, 50, 100, 5, 90, function(val)
        dialog.selectedOpacity = val / 100
        UpdatePreview()
    end, COL_W, "%d%%")
    opacityContainer:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)

    MakeLabel(content, "Font Outline", COL2_X, yPos)
    local outlineDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    outlineDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    outlineDD:SetOptions({
        {text = "None", value = ""},
        {text = "Outline", value = "OUTLINE"},
        {text = "Thick Outline", value = "THICKOUTLINE"},
    })
    outlineDD:SetSelected("")
    outlineDD.onSelect = function(value)
        dialog.selectedFontOutline = value
        UpdatePreview()
    end
    dialog.selectedFontOutline = ""
    dialog.outlineDD = outlineDD
    yPos = yPos - ROW_H

    MakeLabel(content, L["LABEL_NOTE_TYPE"], COL1_X, yPos)
    local noteTypeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    noteTypeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    noteTypeDD:SetOptions({
        {text = L["NOTE_TYPE_STANDARD"], value = "standard"},
        {text = L["NOTE_TYPE_DAILY"],    value = "daily"},
        {text = L["NOTE_TYPE_WEEKLY"],   value = "weekly"},
        {text = L["NOTE_TYPE_ESCPANEL"], value = "escpanel"},
    })
    noteTypeDD:SetSelected("standard")
    dialog.noteTypeDD = noteTypeDD

    local autoPinSection = CreateFrame("Frame", nil, content)
    autoPinSection:SetPoint("TOPLEFT",  content, "TOPLEFT",  COL2_X, yPos - 4)
    autoPinSection:SetSize(COL_W, 35)
    autoPinSection:Hide()

    local autoPinCheckbox = lib:CreateCheckbox(nil, autoPinSection, L["NOTE_AUTOPIN_WHEN_COMPLETE"] or "Auto-hide when tasks complete")
    autoPinCheckbox:SetPoint("LEFT", autoPinSection, "LEFT", 5, 0)
    dialog.autoPinCheckbox = autoPinCheckbox
    dialog.autoPinSection  = autoPinSection

    noteTypeDD.onSelect = function(value)
        if value == "daily" or value == "weekly" then
            autoPinSection:Show()
        else
            autoPinSection:Hide()
            autoPinCheckbox:SetChecked(false)
        end
    end
    yPos = yPos - ROW_H + 4

    local previewLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewLabel:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos)
    previewLabel:SetText(L["LABEL_NOTE_CONTENT"])
    previewLabel:SetTextColor(T("TEXT_SECONDARY"))
    yPos = yPos - 18

    contentBg = lib:CreateFrame(nil, content, 100, 100)
    contentBg:ClearAllPoints()
    contentBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X,  yPos)
    contentBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)
    local initCC = ns.Config.PIN_COLORS["hunter"]
    contentBg:SetBackdropColor(initCC.background[1], initCC.background[2], initCC.background[3], 0.9)
    contentBg:SetBackdropBorderColor(initCC.border[1], initCC.border[2], initCC.border[3], 0.8)

    local contentScroll = CreateFrame("ScrollFrame", nil, contentBg, "UIPanelScrollFrameTemplate")
    contentScroll:SetPoint("TOPLEFT",     contentBg, "TOPLEFT",     4, -4)
    contentScroll:SetPoint("BOTTOMRIGHT", contentBg, "BOTTOMRIGHT", -26, 4)

    local contentEditBox = CreateFrame("EditBox", nil, contentScroll)
    contentEditBox:SetMultiLine(true)
    contentEditBox:SetFontObject("ChatFontNormal")
    contentEditBox:SetAutoFocus(false)
    contentEditBox:SetMaxLetters(0)
    contentEditBox:SetHyperlinksEnabled(true)
    contentEditBox:SetScript("OnHyperlinkClick", function(self, link, text, button)
        SetItemRef(link, text, button)
    end)
    contentEditBox:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and ns.NotesContextMenu then
            ns.NotesContextMenu:ShowEditBoxContextMenu(self)
        end
    end)
    if ns.NotesHyperlinks then ns.NotesHyperlinks:EnhanceEditBox(contentEditBox) end
    contentScroll:SetScrollChild(contentEditBox)
    contentScroll:HookScript("OnSizeChanged", function(self, w)
        contentEditBox:SetWidth(math.max(1, w))
    end)
    dialog.contentEditBox = contentEditBox

    UpdatePreview()
    dialog:Show()
end

function ns.UI.ShowNotePropertiesDialog(noteID)
    if not noteID or not ns.NotesData then return end

    local allNotes = ns.NotesData:GetAllNotes()
    local noteData = allNotes[noteID]
    if not noteData or type(noteData) ~= "table" then return end

    local addon = _G.OneWoW_Notes
    local pinWasAlreadyVisible = addon.notePins and addon.notePins[noteID] and addon.notePins[noteID]:IsShown()

    local pinOpenedByDialog = false
    if not pinWasAlreadyVisible and ns.NotesPins then
        ns.NotesPins:ShowNotePin(noteID)
        pinOpenedByDialog = true
    end

    local dialog = ns.UI.CreateThemedDialog({
        name            = "OneWoW_NotesNotePropertiesDialog",
        title           = string.format(L["DIALOG_NOTE_PROPERTIES_TITLE"], noteData.title or L["NOTE_UNTITLED"]),
        width           = 580,
        height          = 600,
        destroyOnClose  = true,
        buttons = {
            {
                text = L["BUTTON_CLOSE"],
                onClick = function(dlg)
                    if pinOpenedByDialog and ns.NotesPins then
                        ns.NotesPins:HideNotePin(noteID)
                    end
                    dlg:Hide()
                    _G["OneWoW_NotesNotePropertiesDialog"] = nil
                end
            }
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local COL1_X  = 10
    local COL2_X  = 300
    local COL_W   = 260
    local yPos    = -10
    local ROW_H   = 50
    local LBL_GAP = 18

    MakeLabel(content, L["LABEL_NOTE_TITLE"], COL1_X, yPos)
    local titleInput = lib:CreateEditBox(nil, content, { height = 26 })
    titleInput:SetPoint("TOPLEFT",  content, "TOPLEFT",  COL1_X,  yPos - LBL_GAP)
    titleInput:SetPoint("TOPRIGHT", content, "TOPRIGHT", -COL1_X, yPos - LBL_GAP)
    titleInput:SetAutoFocus(false)
    titleInput:SetTextColor(T("TEXT_PRIMARY"))
    titleInput:SetText(noteData.title or "")
    titleInput:SetScript("OnEnterPressed", function(self)
        local newTitle = self:GetText()
        if newTitle ~= "" and ns.NotesData then
            ns.NotesData:UpdateNoteTitle(noteID, newTitle)
            if ns.UI.notesFrame and ns.UI.notesFrame.RefreshNotesList then
                ns.UI.notesFrame.RefreshNotesList()
            end
        end
        self:ClearFocus()
    end)
    yPos = yPos - ROW_H - 4

    MakeLabel(content, L["LABEL_CATEGORY"], COL1_X, yPos)
    local catDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local catOpts = {}
    if ns.NotesCategories then
        for _, c in ipairs(ns.NotesCategories:GetCategories()) do
            catOpts[#catOpts + 1] = {text = c, value = c}
        end
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected(noteData.category or "General")
    catDD.onSelect = function(value)
        local notesDB = ns.NotesData:GetNotesDB(noteData.storage or "account")
        if notesDB and notesDB[noteID] then
            notesDB[noteID].category = value
            notesDB[noteID].modified = GetServerTime()
        end
        if ns.UI.notesFrame and ns.UI.notesFrame.RefreshNotesList then
            ns.UI.notesFrame.RefreshNotesList()
        end
    end

    MakeLabel(content, L["LABEL_STORAGE"], COL2_X, yPos)
    local storeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    storeDD:SetOptions({
        {text = L["STORAGE_ACCOUNT_WIDE"],   value = "account"},
        {text = L["STORAGE_TYPE_CHARACTER"], value = "character"},
    })
    storeDD:SetSelected(noteData.storage or "account")
    storeDD.onSelect = function(value)
        local currentDB = ns.NotesData:GetNotesDB(noteData.storage or "account")
        if currentDB then currentDB[noteID] = nil end
        noteData.storage = value
        noteData.modified = GetServerTime()
        local newDB = ns.NotesData:GetNotesDB(value)
        if newDB then newDB[noteID] = noteData end
        if ns.UI.notesFrame and ns.UI.notesFrame.RefreshNotesList then
            ns.UI.notesFrame.RefreshNotesList()
        end
    end
    yPos = yPos - ROW_H

    local currentPinColor    = noteData.pinColor   or "hunter"
    local currentFontColor   = noteData.fontColor  or "match"
    local currentFontFamily  = noteData.fontFamily or nil
    local currentFontOutline = noteData.fontOutline or ""
    local contentBg          = nil

    local function UpdatePreview()
        if not contentBg then return end
        local colorConfig = ns.Config:GetResolvedColorConfig(currentPinColor)
        local bgColor     = colorConfig.background
        local borderColor = colorConfig.border
        local opacity     = noteData.opacity or 0.9
        contentBg:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], opacity)
        contentBg:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 0.8)
        if dialog.contentEditBox then
            local fc = GetFontColorFromKey(currentFontColor, currentPinColor)
            dialog.contentEditBox:SetTextColor(fc[1], fc[2], fc[3], 1)
            local notesDB = ns.NotesData:GetNotesDB(noteData.storage or "account")
            local fontSize = 12
            if notesDB and notesDB[noteID] then fontSize = notesDB[noteID].fontSize or 12 end
            local fontPath = "Fonts\\FRIZQT__.TTF"
            if currentFontFamily then
                local LSM = LibStub("LibSharedMedia-3.0", true)
                if LSM then
                    local path = LSM:Fetch("font", currentFontFamily)
                    if path then
                        fontPath = path
                    end
                end
            end
            dialog.contentEditBox:SetFont(fontPath, fontSize, currentFontOutline or "")
        end
        if ns.UI.notesFrame and ns.UI.notesFrame.UpdateEditorColors then
            ns.UI.notesFrame.UpdateEditorColors(noteID)
        end
        if ns.NotesPins and ns.NotesPins.RefreshNotePinColors then
            ns.NotesPins:RefreshNotePinColors(noteID)
        end
    end

    MakeLabel(content, L["LABEL_NOTE_COLOR"], COL1_X, yPos)
    local colorDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    colorDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    local colorOpts = {}
    for key, colorData in pairs(ns.Config.PIN_COLORS) do
        colorOpts[#colorOpts + 1] = {text = colorData.name, value = key}
    end
    table.sort(colorOpts, function(a, b) return a.text < b.text end)
    colorDD:SetOptions(colorOpts)
    colorDD:SetSelected(currentPinColor)
    colorDD.onSelect = function(value)
        local notesDB = ns.NotesData:GetNotesDB(noteData.storage or "account")
        if notesDB and notesDB[noteID] then
            notesDB[noteID].pinColor = value
            notesDB[noteID].modified = GetServerTime()
        end
        currentPinColor = value
        UpdatePreview()
        if ns.UI.notesFrame and ns.UI.notesFrame.RefreshNotesList then
            ns.UI.notesFrame.RefreshNotesList()
        end
    end

    MakeLabel(content, L["LABEL_FONT_COLOR"], COL2_X, yPos)
    local fontColorDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    fontColorDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    fontColorDD:SetOptions({
        {text = "OneWoW Sync",                value = "sync"},
        {text = L["FONT_COLOR_MATCHING"],    value = "match"},
        {text = L["FONT_COLOR_WHITE"],      value = "white"},
        {text = L["FONT_COLOR_BLACK"],      value = "black"},
    })
    fontColorDD:SetSelected(currentFontColor)
    fontColorDD.onSelect = function(value)
        local notesDB = ns.NotesData:GetNotesDB(noteData.storage or "account")
        if notesDB and notesDB[noteID] then
            notesDB[noteID].fontColor = value
            notesDB[noteID].modified  = GetServerTime()
        end
        currentFontColor = value
        UpdatePreview()
    end
    yPos = yPos - ROW_H

    MakeLabel(content, L["LABEL_FONT_SIZE"], COL1_X, yPos)
    local fontSizeContainer = lib:CreateSlider(content, 10, 20, 1, noteData.fontSize or 12, function(val)
        local notesDB = ns.NotesData:GetNotesDB(noteData.storage or "account")
        if notesDB and notesDB[noteID] then
            notesDB[noteID].fontSize = val
            notesDB[noteID].modified = GetServerTime()
        end
        UpdatePreview()
        if ns.UI.notesFrame and ns.UI.notesFrame.UpdateEditorColors then
            ns.UI.notesFrame.UpdateEditorColors(noteID)
        end
        if ns.NotesPins and ns.NotesPins.RefreshNotePinColors then
            ns.NotesPins:RefreshNotePinColors(noteID)
        end
    end, COL_W, "%d")
    fontSizeContainer:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)

    MakeLabel(content, L["LABEL_NOTE_FONT"], COL2_X, yPos)
    local LSM2 = LibStub("LibSharedMedia-3.0", true)
    local fontList2 = {}
    if LSM2 then
        fontList2 = LSM2:List("font") or {}
    end
    table.sort(fontList2)
    local fontOpts2 = {}
    for _, fontName in ipairs(fontList2) do
        fontOpts2[#fontOpts2 + 1] = {text = fontName, value = fontName}
    end
    fontOpts2[#fontOpts2 + 1] = {text = L["FONT_DEFAULT"], value = "default"}
    local fontFamilyDD = ns.UI.CreateFontDropdown(content, COL_W, 26)
    fontFamilyDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    fontFamilyDD:SetOptions(fontOpts2)
    fontFamilyDD:SetSelected(currentFontFamily or "default")
    fontFamilyDD.onSelect = function(value)
        local fontValue = (value == "default") and nil or value
        local notesDB = ns.NotesData:GetNotesDB(noteData.storage or "account")
        if notesDB and notesDB[noteID] then
            notesDB[noteID].fontFamily = fontValue
            notesDB[noteID].modified  = GetServerTime()
        end
        currentFontFamily = fontValue
        UpdatePreview()
        if ns.NotesPins and ns.NotesPins.RefreshNotePinColors then
            ns.NotesPins:RefreshNotePinColors(noteID)
        end
    end
    yPos = yPos - ROW_H

    MakeLabel(content, L["LABEL_OPACITY"], COL1_X, yPos)
    local opacityContainer = lib:CreateSlider(content, 50, 100, 5, math.floor((noteData.opacity or 0.9) * 100 + 0.5), function(val)
        local notesDB = ns.NotesData:GetNotesDB(noteData.storage or "account")
        if notesDB and notesDB[noteID] then
            notesDB[noteID].opacity = val / 100
            notesDB[noteID].modified = GetServerTime()
        end
        noteData.opacity = val / 100
        UpdatePreview()
    end, COL_W, "%d%%")
    opacityContainer:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)

    MakeLabel(content, "Font Outline", COL2_X, yPos)
    local outlinePropDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    outlinePropDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - LBL_GAP)
    outlinePropDD:SetOptions({
        {text = "None", value = ""},
        {text = "Outline", value = "OUTLINE"},
        {text = "Thick Outline", value = "THICKOUTLINE"},
    })
    outlinePropDD:SetSelected(currentFontOutline)
    outlinePropDD.onSelect = function(value)
        local notesDB = ns.NotesData:GetNotesDB(noteData.storage or "account")
        if notesDB and notesDB[noteID] then
            notesDB[noteID].fontOutline = value
            notesDB[noteID].modified = GetServerTime()
        end
        currentFontOutline = value
        UpdatePreview()
        if ns.NotesPins and ns.NotesPins.RefreshNotePinColors then
            ns.NotesPins:RefreshNotePinColors(noteID)
        end
    end
    yPos = yPos - ROW_H

    MakeLabel(content, L["LABEL_NOTE_TYPE"], COL1_X, yPos)
    local noteTypeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    noteTypeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - LBL_GAP)
    noteTypeDD:SetOptions({
        {text = L["NOTE_TYPE_STANDARD"], value = "standard"},
        {text = L["NOTE_TYPE_DAILY"],    value = "daily"},
        {text = L["NOTE_TYPE_WEEKLY"],   value = "weekly"},
        {text = L["NOTE_TYPE_ESCPANEL"], value = "escpanel"},
    })
    noteTypeDD:SetSelected(noteData.noteType or "standard")

    local propAutoPinSection = CreateFrame("Frame", nil, content)
    propAutoPinSection:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - 4)
    propAutoPinSection:SetSize(COL_W, 35)

    local propAutoPinCheckbox = lib:CreateCheckbox(nil, propAutoPinSection, L["NOTE_AUTOPIN_WHEN_COMPLETE"] or "Auto-hide when tasks complete")
    propAutoPinCheckbox:SetPoint("LEFT", propAutoPinSection, "LEFT", 5, 0)
    propAutoPinCheckbox:SetChecked(noteData.autoPinEnabled == true)
    propAutoPinCheckbox:SetScript("OnClick", function(self)
        local notesDB = ns.NotesData:GetNotesDB(noteData.storage or "account")
        if notesDB and notesDB[noteID] then
            notesDB[noteID].autoPinEnabled = self:GetChecked()
            notesDB[noteID].modified = GetServerTime()
        end
    end)

    local currentNoteType = noteData.noteType or "standard"
    if currentNoteType == "daily" or currentNoteType == "weekly" then
        propAutoPinSection:Show()
    else
        propAutoPinSection:Hide()
    end

    noteTypeDD.onSelect = function(value)
        local notesDB = ns.NotesData:GetNotesDB(noteData.storage or "account")
        if notesDB and notesDB[noteID] then
            notesDB[noteID].noteType = value
            notesDB[noteID].modified = GetServerTime()
        end
        if value == "daily" or value == "weekly" then
            propAutoPinSection:Show()
        else
            propAutoPinSection:Hide()
            propAutoPinCheckbox:SetChecked(false)
            if notesDB and notesDB[noteID] then
                notesDB[noteID].autoPinEnabled = false
            end
        end
        if ns.UI.notesFrame and ns.UI.notesFrame.RefreshNotesList then
            ns.UI.notesFrame.RefreshNotesList()
        end
    end
    yPos = yPos - ROW_H + 4

    local previewLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewLabel:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos)
    previewLabel:SetText(L["LABEL_NOTE_PREVIEW"])
    previewLabel:SetTextColor(T("TEXT_SECONDARY"))
    yPos = yPos - 18

    contentBg = lib:CreateFrame(nil, content, 100, 100)
    contentBg:ClearAllPoints()
    contentBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X,  yPos)
    contentBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)

    local contentScroll = CreateFrame("ScrollFrame", nil, contentBg, "UIPanelScrollFrameTemplate")
    contentScroll:SetPoint("TOPLEFT",     contentBg, "TOPLEFT",     4, -4)
    contentScroll:SetPoint("BOTTOMRIGHT", contentBg, "BOTTOMRIGHT", -26, 4)

    local contentEditBox = CreateFrame("EditBox", nil, contentScroll)
    contentEditBox:SetMultiLine(true)
    local initFontPath = "Fonts\\FRIZQT__.TTF"
    if noteData.fontFamily then
        local LSM = LibStub("LibSharedMedia-3.0", true)
        if LSM then
            local path = LSM:Fetch("font", noteData.fontFamily)
            if path then
                initFontPath = path
            end
        end
    end
    contentEditBox:SetFont(initFontPath, noteData.fontSize or 12, "")
    contentEditBox:SetAutoFocus(false)
    contentEditBox:SetMaxLetters(0)
    contentEditBox:SetHyperlinksEnabled(true)
    contentEditBox:SetText(noteData.content or "")
    contentEditBox:SetScript("OnHyperlinkClick", function(self, link, text, button)
        SetItemRef(link, text, button)
    end)
    contentEditBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput and ns.NotesData then
            ns.NotesData:UpdateNote(noteID, self:GetText())
        end
    end)
    contentEditBox:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and ns.NotesContextMenu then
            ns.NotesContextMenu:ShowEditBoxContextMenu(self)
        end
    end)
    if ns.NotesHyperlinks then ns.NotesHyperlinks:EnhanceEditBox(contentEditBox) end
    contentScroll:SetScrollChild(contentEditBox)
    contentScroll:HookScript("OnSizeChanged", function(self, w)
        contentEditBox:SetWidth(math.max(1, w))
    end)
    dialog.contentEditBox = contentEditBox

    UpdatePreview()
    dialog:Show()
end
