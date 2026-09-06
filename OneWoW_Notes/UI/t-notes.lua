local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

ns.UI = ns.UI or {}

local selectedNote = nil
local noteListItems = {}
local currentFilters = {
    category = "All",
    storage = "All",
    search = ""
}
local currentSort = {
    by = "modified",
    ascending = false
}

local contentUpdateTimer = nil
local contentEditBox = nil
local todoContainer = nil
local emptyMessage = nil
local leftStatusText = nil
local rightStatusText = nil
local scrollChild = nil

local MEDIA = OneWoW_GUI.Constants.MEDIA_BASE
local Detail = ns.Constants.Detail

local function GetFontColorFromKey(fontColorKey, pinColorKey)
    return ns.Config:GetResolvedFontColor(fontColorKey, pinColorKey)
end

function ns.UI.CreateNotesTab(parent)
    ns.UI.notesFrame = parent

    do
        local p = ns.db.global.tabSortPrefs.notes
        currentSort.by        = ns.UI.NormalizeSortBy(p.by) or "modified"
        currentSort.ascending = p.ascending ~= false
        if p.by == "manual" then
            ns.db.global.tabSortPrefs.notes = { by = "custom", ascending = p.ascending ~= false }
        end
    end

    local controlPanel = ns.UI.CreateThemedBar(nil, parent)
    controlPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(45)

    local addNoteBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["BUTTON_ADD_NOTE"], height = 25, minWidth = 80 })
    addNoteBtn:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -10)
    addNoteBtn:SetScript("OnClick", function()
        ns.UI.ShowAddNoteDialog()
    end)
    addNoteBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TOOLTIP_BUTTON_ADD_NOTE"], 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_BUTTON_ADD_NOTE_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addNoteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local categoryDropdown = ns.UI.CreateThemedDropdown(controlPanel, CATEGORY, 140, 25)
    categoryDropdown:SetPoint("LEFT", addNoteBtn, "RIGHT", 8, 0)
    local storageDropdown
    local function CountNotesForFilters(ignoreDim)
        local counts = { all = 0, byCategory = {}, byStorage = { All = 0, account = 0, character = 0 } }
        local NotesData = ns.NotesData
        if not NotesData then return counts end
        local searchLower = (currentFilters.search or ""):lower()
        for _, noteData in pairs(NotesData:GetAllNotes()) do
            if type(noteData) == "table" then
                local ok = true
                if ignoreDim ~= "category" and currentFilters.category ~= "All"
                    and noteData.category ~= currentFilters.category then
                    ok = false
                end
                if ignoreDim ~= "storage" and currentFilters.storage ~= "All"
                    and noteData.storage ~= currentFilters.storage then
                    ok = false
                end
                if searchLower ~= "" then
                    local titleLower = (noteData.title or ""):lower()
                    if not titleLower:find(searchLower, 1, true) then
                        ok = false
                    end
                end
                if ok then
                    counts.all = counts.all + 1
                    local cat = noteData.category or "General"
                    counts.byCategory[cat] = (counts.byCategory[cat] or 0) + 1
                    local stor = noteData.storage == "character" and "character" or "account"
                    counts.byStorage[stor] = (counts.byStorage[stor] or 0) + 1
                    counts.byStorage.All = counts.byStorage.All + 1
                end
            end
        end
        return counts
    end
    local function RefreshCatOpts()
        local catCounts = CountNotesForFilters("category")
        local catOpts = {{
            text = ALL,
            value = "All",
            rightText = ns.UI.FormatSectionCount(catCounts.all),
        }}
        if ns.NotesCategories then
            for _, category in ipairs(ns.NotesCategories:GetCategories()) do
                catOpts[#catOpts + 1] = {
                    text = category,
                    value = category,
                    rightText = ns.UI.FormatSectionCount(catCounts.byCategory[category] or 0),
                }
            end
        end
        categoryDropdown:SetOptions(catOpts)
        categoryDropdown:SetSelected(currentFilters.category)
    end
    RefreshCatOpts()
    categoryDropdown.onSelect = function(value)
        currentFilters.category = value
        if parent.RefreshNotesList then parent.RefreshNotesList() end
    end

    local manageCategoriesBtn = OneWoW_GUI:CreateIconButton(controlPanel, {
        iconTexture = MEDIA .. "icon-gears.png",
        size = 20,
        texCoord = { 0.1, 0.9, 0.1, 0.9 },
        tooltipTitle = L["CATMGR_TITLE"],
        tooltipText = L["UI_MANAGE_CATEGORIES_DESC"],
        onClick = function()
            ns.UI.ShowCategoryManager("notes")
        end,
    })
    manageCategoriesBtn:SetPoint("LEFT", categoryDropdown, "RIGHT", 4, 0)

    storageDropdown = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_STORAGE"], 130, 25)
    storageDropdown:SetPoint("LEFT", manageCategoriesBtn, "RIGHT", 4, 0)
    local function RefreshStorageOpts()
        local storCounts = CountNotesForFilters("storage")
        storageDropdown:SetOptions({
            {text = ALL, value = "All",
                rightText = ns.UI.FormatSectionCount(storCounts.byStorage.All)},
            {text = L["UI_STORAGE_ACCOUNT"], value = "account",
                rightText = ns.UI.FormatSectionCount(storCounts.byStorage.account)},
            {text = CHARACTER, value = "character",
                rightText = ns.UI.FormatSectionCount(storCounts.byStorage.character)},
        })
        storageDropdown:SetSelected(currentFilters.storage)
    end
    RefreshStorageOpts()
    storageDropdown.onSelect = function(value)
        currentFilters.storage = value
        if parent.RefreshNotesList then parent.RefreshNotesList() end
    end

    local sortHandle = OneWoW_GUI:CreateSortControls(controlPanel, {
        sortFields = {
            {key = "title",    label = L["NOTE_SORT_TITLE"]},
            {key = "created",  label = L["NOTE_SORT_CREATED"]},
            {key = "modified", label = L["NOTE_SORT_MODIFIED"]},
            {key = "category", label = CATEGORY},
            {key = "color",    label = COLOR},
            {key = "type",     label = TYPE},
            {key = "custom",   label = CUSTOM},
        },
        defaultField  = currentSort.by,
        defaultAsc    = currentSort.ascending,
        dropdownWidth = 110,
        onChange = function(field, ascending)
            currentSort.by        = field
            currentSort.ascending = ascending
            ns.db.global.tabSortPrefs.notes = { by = field, ascending = ascending }
            if parent.RefreshNotesList then parent.RefreshNotesList() end
        end,
    })
    sortHandle.dropdown:SetPoint("LEFT", storageDropdown, "RIGHT", 6, 0)
    sortHandle.dirBtn:SetPoint("LEFT", sortHandle.dropdown, "RIGHT", 4, 0)

    local helpButton = CreateFrame("Button", nil, controlPanel)
    helpButton:SetSize(28, 28)
    helpButton:SetPoint("TOPRIGHT", controlPanel, "TOPRIGHT", -10, -10)
    local helpIcon = helpButton:CreateTexture(nil, "ARTWORK")
    helpIcon:SetSize(24, 24)
    helpIcon:SetPoint("CENTER", helpButton, "CENTER", 0, 0)
    helpIcon:SetAtlas("CampaignActiveQuestIcon")
    helpButton:SetScript("OnClick", function()
        if not ns.UI.notesHelpPanel and ns.UI.CreateNotesHelpPanel then
            ns.UI.notesHelpPanel = ns.UI.CreateNotesHelpPanel()
        end
        if ns.UI.notesHelpPanel then
            if ns.UI.notesHelpPanel:IsShown() then
                ns.UI.notesHelpPanel:Hide()
            else
                ns.UI.notesHelpPanel:Show()
            end
        end
    end)
    helpButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["UI_HELP_PANEL_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["UI_NOTES_HYPERLINK_HINT"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    helpButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local listingPanel = ns.UI.CreateThemedPanel(nil, parent)
    listingPanel:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -10)
    listingPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 35)
    listingPanel:SetWidth(OneWoW_GUI.Constants.GUI.LEFT_PANEL_WIDTH)

    local listingTitle = OneWoW_GUI:CreateFS(listingPanel, 16)
    listingTitle:SetPoint("TOP", listingPanel, "TOP", 0, -10)
    listingTitle:SetText(L["NOTES_LIST"])
    listingTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local searchBox = OneWoW_GUI:CreateEditBox(listingPanel, {
        placeholderText = L["SEARCH"],
        onTextChanged = function(text)
            currentFilters.search = text
            if parent.RefreshNotesList then parent.RefreshNotesList() end
        end,
    })
    searchBox:SetPoint("TOPLEFT",  listingPanel, "TOPLEFT",  8, -30)
    searchBox:SetPoint("TOPRIGHT", listingPanel, "TOPRIGHT", -8, -30)

    local listScroll = ns.UI.CreateCustomScroll(listingPanel)
    scrollChild = listScroll.scrollChild
    listScroll.container:SetPoint("TOPLEFT",     listingPanel, "TOPLEFT",     10, -62)
    listScroll.container:SetPoint("BOTTOMRIGHT", listingPanel, "BOTTOMRIGHT", -10, 10)

    local sectionRowFrames = {}
    local sectionDataBags = {}
    local sectionReorders = {}
    local function GetOrCreateSectionReorder(sectionKey)
        if sectionReorders[sectionKey] then
            return sectionReorders[sectionKey]
        end
        local ctrl = ns.UI.CreateNotesListReorderDrag({
            getItems = function()
                return sectionRowFrames[sectionKey]
            end,
            getScrollFrame = function()
                return listScroll.scrollFrame
            end,
            onReorder = function(fromIdx, toIdx, insertBefore)
                local bag = sectionDataBags[sectionKey]
                if ns.UI.ApplySectionReorder(bag, fromIdx, toIdx, insertBefore) then
                    ns.UI.EnsureCustomSort(sortHandle, currentSort, "notes")
                    parent.RefreshNotesList()
                end
            end,
        })
        sectionReorders[sectionKey] = ctrl
        return ctrl
    end
    local function IsAnyNotesReorderActive()
        for _, ctrl in pairs(sectionReorders) do
            if ctrl:IsActive() or ctrl:ShouldSuppressClick() then
                return true
            end
        end
        return false
    end

    local detailPanel = ns.UI.CreateThemedPanel(nil, parent)
    detailPanel:SetPoint("TOPLEFT", listingPanel, "TOPRIGHT", 10, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 35)

    ns.UI.notesDetailPanel = detailPanel

    emptyMessage = OneWoW_GUI:CreateFS(detailPanel, 16)
    emptyMessage:SetPoint("CENTER", detailPanel, "CENTER")
    emptyMessage:SetText(L["MESSAGE_SELECT_NOTE"])
    emptyMessage:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local leftStatusBar = ns.UI.CreateThemedBar(nil, parent)
    leftStatusBar:SetPoint("TOPLEFT", listingPanel, "BOTTOMLEFT", 0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listingPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)

    leftStatusText = OneWoW_GUI:CreateFS(leftStatusBar, 10)
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_NOTES"], 0))

    local rightStatusBar = ns.UI.CreateThemedBar(nil, parent)
    rightStatusBar:SetPoint("TOPLEFT", detailPanel, "BOTTOMLEFT", 0, -5)
    rightStatusBar:SetPoint("TOPRIGHT", detailPanel, "BOTTOMRIGHT", 0, -5)
    rightStatusBar:SetHeight(25)

    rightStatusText = OneWoW_GUI:CreateFS(rightStatusBar, 10)
    rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
    rightStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rightStatusText:SetText(READY)

    local function ShowEditor()
        emptyMessage:Hide()

        for _, child in ipairs({detailPanel:GetChildren()}) do
            if child ~= emptyMessage then
                child:Hide()
            end
        end

        if not detailPanel.editorContent then
            local editorHeader = ns.UI.CreateDetailHeader(detailPanel)

            -- Title is display-only here so long titles can wrap; edit via note settings.
            local titleFS = OneWoW_GUI:CreateFS(editorHeader, 16)
            titleFS:SetPoint("TOPLEFT", editorHeader, "TOPLEFT", 12, -8)
            titleFS:SetPoint("TOPRIGHT", editorHeader, "TOPRIGHT", -110, -8)
            titleFS:SetHeight(44)
            titleFS:SetJustifyH("LEFT")
            titleFS:SetJustifyV("TOP")
            titleFS:SetWordWrap(true)
            titleFS:SetNonSpaceWrap(true)
            titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            editorHeader.titleFS = titleFS

            local deleteBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-trash.png",
                tooltipTitle = L["TOOLTIP_NOTE_DELETE"],
                tooltipDesc = L["TOOLTIP_NOTE_DELETE_DESC"],
                onClick = function()
                    if selectedNote then
                        StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE"] = {
                            text = string.format(L["POPUP_DELETE_NOTE"], selectedNote),
                            button1 = DELETE,
                            button2 = CANCEL,
                            OnAccept = function()
                                if ns.NotesData then
                                    ns.NotesData:RemoveNote(selectedNote)
                                    selectedNote = nil
                                    if detailPanel.editorContent then
                                        for _, frame in pairs(detailPanel.editorContent) do
                                            if frame and frame.Hide then frame:Hide() end
                                        end
                                    end
                                    parent.RefreshNotesList()
                                    emptyMessage:Show()
                                end
                            end,
                            timeout = 0, whileDead = true, hideOnEscape = true
                        }
                        StaticPopup_Show("ONEWOW_NOTES_CONFIRM_DELETE")
                    end
                end,
            })
            editorHeader.deleteBtn = deleteBtn

            local propertiesBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-gears.png",
                relativeTo = deleteBtn,
                tooltipTitle = L["TOOLTIP_NOTE_PROPERTIES"],
                tooltipDesc = L["TOOLTIP_NOTE_PROPERTIES_DESC"],
                onClick = function()
                    if selectedNote and ns.UI.ShowNotePropertiesDialog then
                        ns.UI.ShowNotePropertiesDialog(selectedNote)
                    end
                end,
            })
            editorHeader.propertiesBtn = propertiesBtn

            local pinBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-pin.png",
                check = true,
                relativeTo = propertiesBtn,
                tooltipTitle = L["TOOLTIP_NOTE_PIN"],
                tooltipDesc = L["TOOLTIP_NOTE_PIN_DESC"],
                onClick = function(self)
                    if selectedNote and ns.NotesPins and ns.NotesData then
                        local allNotes = ns.NotesData:GetAllNotes()
                        local noteData = allNotes[selectedNote]
                        if noteData then
                            if noteData.pinEnabled and ns.notePins and ns.notePins[selectedNote] then
                                ns.NotesPins:HideNotePin(selectedNote)
                                noteData.pinEnabled = false
                                self:SetActiveVisual(false)
                            else
                                noteData.pinEnabled = true
                                ns.NotesPins:ShowNotePin(selectedNote)
                                self:SetActiveVisual(true)
                            end
                            parent.RefreshNotesList()
                        end
                    end
                end,
            })
            editorHeader.pinBtn = pinBtn

            local favoriteBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-fav.png",
                check = true,
                relativeTo = pinBtn,
                tooltipTitle = L["TOOLTIP_NOTE_FAVORITE"],
                tooltipDesc = L["TOOLTIP_NOTE_FAVORITE_DESC"],
                onClick = function(self)
                    if selectedNote and ns.NotesData then
                        local isFav = ns.NotesData:ToggleFavorite(selectedNote)
                        self:SetActiveVisual(isFav)
                        parent.RefreshNotesList()
                    end
                end,
            })
            editorHeader.favoriteBtn = favoriteBtn

            local noteTypeLine = OneWoW_GUI:CreateFS(editorHeader, 10)
            noteTypeLine:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -12, Detail.META_LINE_Y_UPPER)
            noteTypeLine:SetText(string.format(L["TYPE_S"], L["NOTE_TYPE_STANDARD"]))
            noteTypeLine:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            noteTypeLine:SetJustifyH("RIGHT")
            editorHeader.noteTypeLine = noteTypeLine

            local categoryLine = OneWoW_GUI:CreateFS(editorHeader, 10)
            categoryLine:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -12, Detail.META_LINE_Y_LOWER)
            categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], GENERAL))
            categoryLine:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            categoryLine:SetJustifyH("RIGHT")
            editorHeader.categoryLine = categoryLine

            local autoPinCheckbox = CreateFrame("CheckButton", nil, editorHeader, "UICheckButtonTemplate")
            autoPinCheckbox:SetSize(20, 20)
            autoPinCheckbox:SetPoint("BOTTOMLEFT", editorHeader, "BOTTOMLEFT", 8, 4)
            autoPinCheckbox.Text:SetText(L["NOTE_AUTOPIN_WHEN_COMPLETE"])
            autoPinCheckbox.Text:SetFontObject("GameFontNormalSmall")
            autoPinCheckbox:Hide()
            autoPinCheckbox:SetScript("OnClick", function(self)
                if selectedNote and ns.NotesData then
                    local allNotes2 = ns.NotesData:GetAllNotes()
                    local note2 = allNotes2[selectedNote]
                    if note2 then
                        local notesDB = ns.NotesData:GetNotesDB(note2.storage or "account")
                        if notesDB and notesDB[selectedNote] then
                            notesDB[selectedNote].autoPinEnabled = self:GetChecked()
                            notesDB[selectedNote].modified = GetServerTime()
                        end
                    end
                end
            end)
            editorHeader.autoPinCheckbox = autoPinCheckbox

            local body = ns.UI.CreateDetailBody(detailPanel, editorHeader, {
                onTextChanged = function(self, userInput)
                    if userInput and selectedNote and ns.NotesData then
                        ns.NotesData:UpdateNote(selectedNote, self:GetText())

                        if contentUpdateTimer then contentUpdateTimer:Cancel() end

                        contentUpdateTimer = C_Timer.NewTimer(2, function()
                            if selectedNote and ns.notePins and ns.notePins[selectedNote] then
                                local pinFrame = ns.notePins[selectedNote]
                                if pinFrame and pinFrame.contentText then
                                    local allNotes = ns.NotesData:GetAllNotes()
                                    local note = allNotes[selectedNote]
                                    if note then
                                        pinFrame.contentText:SetText(note.content or "")
                                    end
                                end
                            end
                            contentUpdateTimer = nil
                        end)
                    end
                end,
            })
            local contentBg = body.contentBg
            local contentScroll = body.contentScroll
            contentEditBox = body.contentEditBox
            contentEditBox:SetHyperlinksEnabled(true)
            contentEditBox:SetScript("OnHyperlinkClick", function(_, link, text, button)
                SetItemRef(link, text, button)
            end)
            contentEditBox:SetScript("OnReceiveDrag", function(self)
                local cursorType, _, itemLink = GetCursorInfo()
                if cursorType == "item" and itemLink then
                    self:Insert(itemLink)
                    ClearCursor()
                elseif cursorType == "spell" then
                    local spellID = select(2, GetCursorInfo())
                    if spellID then
                        local spellLink = C_Spell.GetSpellLink(spellID)
                        if spellLink then self:Insert(spellLink) end
                    end
                    ClearCursor()
                end
            end)
            contentEditBox:HookScript("OnMouseDown", function(self, button)
                if button == "LeftButton" then
                    local cursorType = GetCursorInfo()
                    if cursorType == "item" or cursorType == "spell" then
                        local ct, _, itemLink = GetCursorInfo()
                        if ct == "item" and itemLink then
                            self:Insert(itemLink)
                            ClearCursor()
                        elseif ct == "spell" then
                            local spellID = select(2, GetCursorInfo())
                            if spellID then
                                local spellLink = C_Spell.GetSpellLink(spellID)
                                if spellLink then self:Insert(spellLink) end
                            end
                            ClearCursor()
                        end
                        return
                    end
                end
            end)
            contentEditBox:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" and ns.NotesContextMenu then
                    ns.NotesContextMenu:ShowEditBoxContextMenu(self)
                end
            end)
            if ns.NotesHyperlinks then
                ns.NotesHyperlinks:EnhanceEditBox(contentEditBox)
            end
            contentEditBox._skipGlobalFont = true
            detailPanel.contentEditBox = contentEditBox

            contentBg:SetScript("OnMouseDown", function(_, button)
                if detailPanel.contentEditBox then
                    detailPanel.contentEditBox:SetFocus()
                    if button == "LeftButton" then
                        local cursorType, _, itemLink = GetCursorInfo()
                        if cursorType == "item" and itemLink then
                            detailPanel.contentEditBox:Insert(itemLink)
                            ClearCursor()
                        elseif cursorType == "spell" then
                            local spellID = select(2, GetCursorInfo())
                            if spellID then
                                local spellLink = C_Spell.GetSpellLink(spellID)
                                if spellLink then detailPanel.contentEditBox:Insert(spellLink) end
                            end
                            ClearCursor()
                        end
                    elseif button == "RightButton" and ns.NotesContextMenu then
                        ns.NotesContextMenu:ShowEditBoxContextMenu(detailPanel.contentEditBox)
                    end
                end
            end)

            local todoSection = CreateFrame("Frame", nil, detailPanel)
            todoSection:SetPoint("TOPLEFT", contentBg, "BOTTOMLEFT", 0, -Detail.SECTION_GAP)
            todoSection:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8, 10)
            todoSection:SetClipsChildren(true)

            local todoHeader = CreateFrame("Frame", nil, todoSection)
            todoHeader:SetPoint("TOPLEFT", todoSection, "TOPLEFT", 0, 0)
            todoHeader:SetPoint("TOPRIGHT", todoSection, "TOPRIGHT", -22, 0)
            todoHeader:SetHeight(30)

            local todoLabel = OneWoW_GUI:CreateFS(todoHeader, 12)
            todoLabel:SetPoint("LEFT", todoHeader, "LEFT", 5, 0)
            todoLabel:SetText(L["UI_TASKS"])
            todoLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local resetTasksBtn = OneWoW_GUI:CreateIconButton(todoHeader, {
                atlas = "talents-button-undo",
                size = 20,
                tooltipTitle = L["NOTE_RESET_TODOS"],
                tooltipText = L["NOTE_RESET_TODOS_DESC"],
                onClick = function()
                    if selectedNote and ns.NotesData then
                        local allNotes = ns.NotesData:GetAllNotes()
                        local note = allNotes[selectedNote]
                        if note and note.todos then
                            for _, todo in ipairs(note.todos) do
                                todo.completed = false
                            end
                            if parent.RefreshTodoList then parent.RefreshTodoList() end
                        end
                    end
                end,
            })
            resetTasksBtn:SetPoint("LEFT", todoLabel, "RIGHT", 5, 0)

            local addTaskBtn = OneWoW_GUI:CreateIconButton(todoHeader, {
                iconTexture = MEDIA .. "icon-add.png",
                size = 24,
            })
            addTaskBtn:SetPoint("RIGHT", todoHeader, "RIGHT", 0, 0)

            local taskInputBox = OneWoW_GUI:CreateEditBox(todoHeader, {
                height = 25,
                placeholderText = "",
            })
            taskInputBox:SetPoint("LEFT", resetTasksBtn, "RIGHT", 5, 0)
            taskInputBox:SetPoint("RIGHT", addTaskBtn, "LEFT", -5, 0)
            taskInputBox:SetScript("OnEnterPressed", function(self)
                local text = self:GetText()
                if text and text ~= "" and selectedNote and ns.NotesTodos then
                    ns.NotesTodos:AddTodo(selectedNote, text)
                    self:SetText("")
                    if parent.RefreshTodoList then parent.RefreshTodoList() end
                end
                self:ClearFocus()
            end)
            addTaskBtn:SetScript("OnClick", function()
                local text = taskInputBox:GetText()
                if text and text ~= "" and selectedNote and ns.NotesTodos then
                    ns.NotesTodos:AddTodo(selectedNote, text)
                    taskInputBox:SetText("")
                    if parent.RefreshTodoList then parent.RefreshTodoList() end
                end
            end)

            local todoScroll, todoScrollChild = OneWoW_GUI:CreateScrollFrame(todoSection, {})
            todoScroll:SetPoint("TOPLEFT", todoHeader, "BOTTOMLEFT", 0, -5)
            todoScroll:SetPoint("BOTTOMRIGHT", todoSection, "BOTTOMRIGHT", -22, 0)

            todoContainer = todoScrollChild
            detailPanel.todoContainer = todoContainer

            todoScroll:SetScript("OnSizeChanged", function(_, width)
                if todoContainer then todoContainer:SetWidth(width - 20) end
            end)

            local separatorLine = OneWoW_GUI:CreateDivider(detailPanel, { yOffset = 0 })
            separatorLine:ClearAllPoints()
            separatorLine:SetPoint("TOPLEFT", contentBg, "BOTTOMLEFT", 0, -5)
            separatorLine:SetPoint("TOPRIGHT", contentBg, "BOTTOMRIGHT", 0, -5)

            detailPanel.editorContent = {
                header = editorHeader,
                contentScroll = contentScroll,
                contentBg = contentBg,
                todoSection = todoSection,
                separatorLine = separatorLine
            }
        end

        for _, frame in pairs(detailPanel.editorContent) do
            if frame and frame.Show then frame:Show() end
        end
        ns.UI.activeContentEditBox = detailPanel.contentEditBox

        if selectedNote and ns.NotesData then
            local allNotes = ns.NotesData:GetAllNotes()
            local note = allNotes[selectedNote]
            if note and type(note) == "table" then
                if detailPanel.editorContent.header.titleFS then
                    detailPanel.editorContent.header.titleFS:SetText(note.title or "")
                end
                if detailPanel.contentEditBox then
                    detailPanel.contentEditBox:SetText(note.content or "")
                end

                local pinColor = note.pinColor or "hunter"
                local fontColor = note.fontColor or "match"
                local fontSize = note.fontSize or 12
                local opacity = note.opacity or 0.9

                local colorConfig = ns.Config:GetResolvedColorConfig(pinColor)
                local bgColor = colorConfig.background
                local listItemColor = colorConfig.listItem
                local borderColor = colorConfig.border

                if detailPanel.editorContent.contentBg then
                    detailPanel.editorContent.contentBg:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], opacity)
                    detailPanel.editorContent.contentBg:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
                end

                if detailPanel.contentEditBox then
                    local textColor = GetFontColorFromKey(fontColor, pinColor)
                    detailPanel.contentEditBox:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
                    local detailFontPath = ns.Config:ResolveFontPath(note.fontFamily)
                    detailPanel.contentEditBox:SetFont(detailFontPath, fontSize, note.fontOutline or "")
                end

                if detailPanel.editorContent.header then
                    local header = detailPanel.editorContent.header
                    local textColor = GetFontColorFromKey(fontColor, pinColor)

                    header:SetBackdropColor(listItemColor[1], listItemColor[2], listItemColor[3], listItemColor[4] or 0.9)
                    header:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)

                    if header.titleFS then
                        header.titleFS:SetTextColor(textColor[1], textColor[2], textColor[3])
                    end
                    if header.categoryLine then
                        header.categoryLine:SetTextColor(textColor[1], textColor[2], textColor[3])
                        header.categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], note.category or GENERAL))
                    end
                    if header.noteTypeLine then
                        local noteType = note.noteType or "standard"
                        local noteTypeText = noteType == "daily" and DAILY or noteType == "weekly" and WEEKLY or L["NOTE_TYPE_STANDARD"]
                        header.noteTypeLine:SetText(string.format(L["TYPE_S"], noteTypeText))
                    end
                    if header.autoPinCheckbox then
                        local noteType = note.noteType or "standard"
                        if noteType == "daily" or noteType == "weekly" then
                            header.autoPinCheckbox:Show()
                            header.autoPinCheckbox:SetChecked(note.autoPinEnabled == true)
                        else
                            header.autoPinCheckbox:Hide()
                        end
                    end
                    if header.favoriteBtn then
                        header.favoriteBtn:SetActiveVisual(note.favorite)
                    end
                    if header.pinBtn then
                        local pinEnabled = note.pinEnabled and ns.notePins and ns.notePins[selectedNote]
                        header.pinBtn:SetActiveVisual(pinEnabled)
                    end
                end

                if parent.RefreshTodoList then parent.RefreshTodoList() end
            end
        end
    end

    function parent.UpdateEditorButtons()
        if not selectedNote or not ns.NotesData or not detailPanel or not detailPanel.editorContent then return end
        local allNotes = ns.NotesData:GetAllNotes()
        local note = allNotes[selectedNote]
        if not note or type(note) ~= "table" then return end

        local header = detailPanel.editorContent.header
        if not header then return end

        if header.favoriteBtn then
            header.favoriteBtn:SetActiveVisual(note.favorite)
        end
        if header.pinBtn then
            local pinEnabled = note.pinEnabled and ns.notePins and ns.notePins[selectedNote]
            header.pinBtn:SetActiveVisual(pinEnabled)
        end
        if header.autoPinCheckbox then
            local noteType = note.noteType or "standard"
            if noteType == "daily" or noteType == "weekly" then
                header.autoPinCheckbox:Show()
                header.autoPinCheckbox:SetChecked(note.autoPinEnabled == true)
            else
                header.autoPinCheckbox:Hide()
            end
        end
    end

    function parent.UpdateEditorColors(noteID)
        if not noteID or not ns.NotesData or not detailPanel then return end
        local allNotes = ns.NotesData:GetAllNotes()
        local note = allNotes[noteID]
        if not note or type(note) ~= "table" then return end

        local pinColor = note.pinColor or "hunter"
        local fontColor = note.fontColor or "match"
        local fontSize = note.fontSize or 12
        local opacity = note.opacity or 0.9

        local colorConfig = ns.Config:GetResolvedColorConfig(pinColor)
        local bgColor = colorConfig.background
        local borderColor = colorConfig.border

        if detailPanel.editorContent and detailPanel.editorContent.header then
            local textColor = GetFontColorFromKey(fontColor, pinColor)
            detailPanel.editorContent.header:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], opacity)
            detailPanel.editorContent.header:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
            if detailPanel.editorContent.header.titleFS then
                detailPanel.editorContent.header.titleFS:SetTextColor(textColor[1], textColor[2], textColor[3])
            end
            if detailPanel.editorContent.header.categoryLine then
                detailPanel.editorContent.header.categoryLine:SetTextColor(textColor[1], textColor[2], textColor[3])
            end
        end

        if detailPanel.editorContent and detailPanel.editorContent.contentBg then
            detailPanel.editorContent.contentBg:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], opacity)
            detailPanel.editorContent.contentBg:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
        end

        if detailPanel.contentEditBox then
            local textColor = GetFontColorFromKey(fontColor, pinColor)
            detailPanel.contentEditBox:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
            local detailFontPath = ns.Config:ResolveFontPath(note.fontFamily)
            detailPanel.contentEditBox:SetFont(detailFontPath, fontSize, note.fontOutline or "")
        end
    end

    function parent.RefreshTodoList()
        if not todoContainer or not selectedNote then return end

        for _, child in ipairs({todoContainer:GetChildren()}) do
            child:Hide()
        end

        if not ns.NotesData then return end
        local allNotes = ns.NotesData:GetAllNotes()
        local note = allNotes[selectedNote]
        if not note or type(note) ~= "table" or not note.todos then return end

        local yOffset = 0
        for _, todo in ipairs(note.todos) do
            local todoFrame = CreateFrame("Frame", nil, todoContainer)
            todoFrame:SetPoint("TOPLEFT", todoContainer, "TOPLEFT", 0, yOffset)
            todoFrame:SetPoint("RIGHT", todoContainer, "RIGHT", 0, 0)
            todoFrame:SetHeight(25)

            local checkbox = CreateFrame("CheckButton", nil, todoFrame, "UICheckButtonTemplate")
            checkbox:SetSize(20, 20)
            checkbox:SetPoint("LEFT", todoFrame, "LEFT", 5, 0)
            checkbox:SetChecked(todo.completed)
            checkbox:SetScript("OnClick", function(self)
                if ns.NotesTodos then
                    ns.NotesTodos:UpdateTodo(selectedNote, todo.id, nil, self:GetChecked())
                    parent.RefreshTodoList()
                    if note.autoPinEnabled and
                       (note.noteType == "daily" or note.noteType == "weekly") then
                        local allCompleted = ns.NotesTodos:AreAllTodosCompleted(selectedNote)
                        if allCompleted then
                            note.autoUnpinned = true
                            if ns.NotesPins then ns.NotesPins:HideNotePin(selectedNote) end
                        elseif note.autoUnpinned then
                            note.autoUnpinned = false
                            if ns.NotesPins then ns.NotesPins:ShowNotePin(selectedNote) end
                        end
                    end
                end
            end)

            local todoEditBox = CreateFrame("EditBox", nil, todoFrame, "InputBoxTemplate")
            todoEditBox:SetPoint("LEFT", checkbox, "RIGHT", 10, 0)
            todoEditBox:SetPoint("RIGHT", todoFrame, "RIGHT", -35, 0)
            todoEditBox:SetHeight(20)
            todoEditBox:SetAutoFocus(false)
            todoEditBox:SetText(todo.text or "")
            if todo.completed then
                todoEditBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            else
                todoEditBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
            todoEditBox:SetScript("OnEnterPressed", function(self)
                if ns.NotesTodos then
                    ns.NotesTodos:UpdateTodo(selectedNote, todo.id, self:GetText(), todo.completed)
                    parent.RefreshTodoList()
                end
                self:ClearFocus()
            end)
            todoEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            todoEditBox:SetScript("OnEditFocusLost", function(self)
                if ns.NotesTodos then
                    ns.NotesTodos:UpdateTodo(selectedNote, todo.id, self:GetText(), todo.completed)
                end
            end)
            todoEditBox:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" and ns.NotesContextMenu then
                    ns.NotesContextMenu:ShowEditBoxContextMenu(self)
                end
            end)
            if ns.NotesHyperlinks then
                ns.NotesHyperlinks:EnhanceEditBox(todoEditBox)
            end

            local deleteTodoBtn = OneWoW_GUI:CreateIconButton(todoFrame, {
                iconTexture = MEDIA .. "icon-minus.png",
                size = 16,
                onClick = function()
                    ns.NotesTodos:RemoveTodo(selectedNote, todo.id)
                    parent.RefreshTodoList()
                end,
            })
            deleteTodoBtn:SetPoint("RIGHT", todoFrame, "RIGHT", -5, 0)

            yOffset = yOffset - 30
        end

        todoContainer:SetHeight(math.abs(yOffset) + 50)
    end

    function parent.RefreshNotesList()
        if scrollChild then
            scrollChild._onewowZebraSeq = nil
        end
        for _, ctrl in pairs(sectionReorders) do
            ctrl:Cancel()
        end
        for _, item in pairs(noteListItems) do
            item:Hide()
        end
        noteListItems = {}
        wipe(sectionRowFrames)
        wipe(sectionDataBags)

        RefreshCatOpts()
        RefreshStorageOpts()

        local NotesData = ns.NotesData
        if not NotesData then return end

        local allNotes = NotesData:GetAllNotes()
        local notesList = {}

        for noteID, noteData in pairs(allNotes) do
            if type(noteData) == "table" then
                local matches = true

                if currentFilters.category ~= "All" and noteData.category ~= currentFilters.category then
                    matches = false
                end
                if currentFilters.storage ~= "All" and noteData.storage ~= currentFilters.storage then
                    matches = false
                end
                if currentFilters.search ~= "" then
                    local searchLower = currentFilters.search:lower()
                    local titleLower = (noteData.title or ""):lower()
                    if not titleLower:find(searchLower, 1, true) then
                        matches = false
                    end
                end

                if matches then
                    table.insert(notesList, {id = noteID, data = noteData})
                end
            end
        end

        local dailies = {}
        local weeklies = {}
        local favorites = {}
        local regular = {}

        for _, note in ipairs(notesList) do
            local nt = note.data.noteType
            if nt == "daily" then
                table.insert(dailies, note)
            elseif nt == "weekly" then
                table.insert(weeklies, note)
            elseif note.data.favorite then
                table.insert(favorites, note)
            else
                table.insert(regular, note)
            end
        end

        local function sortNotes(a, b)
            if currentSort.by == "title" then
                local ta = a.data.title or ""
                local tb = b.data.title or ""
                if currentSort.ascending then return ta < tb else return ta > tb end
            elseif currentSort.by == "created" then
                if currentSort.ascending then return (a.data.created or 0) < (b.data.created or 0)
                else return (a.data.created or 0) > (b.data.created or 0) end
            elseif currentSort.by == "modified" then
                if currentSort.ascending then return (a.data.modified or 0) < (b.data.modified or 0)
                else return (a.data.modified or 0) > (b.data.modified or 0) end
            elseif currentSort.by == "category" then
                local ca = a.data.category or ""
                local cb = b.data.category or ""
                if ca == cb then return (a.data.title or "") < (b.data.title or "") end
                if currentSort.ascending then return ca < cb else return ca > cb end
            elseif currentSort.by == "color" then
                local ca = a.data.pinColor or ""
                local cb = b.data.pinColor or ""
                if ca == cb then return (a.data.title or "") < (b.data.title or "") end
                if currentSort.ascending then return ca < cb else return ca > cb end
            elseif currentSort.by == "type" then
                local ta = a.data.noteType or "standard"
                local tb = b.data.noteType or "standard"
                if ta == tb then return (a.data.title or "") < (b.data.title or "") end
                if currentSort.ascending then return ta < tb else return ta > tb end
            elseif currentSort.by == "custom" then
                local sa = a.data.sortOrder or 0
                local sb = b.data.sortOrder or 0
                if sa == sb then return (a.data.title or "") < (b.data.title or "") end
                if currentSort.ascending then return sa < sb else return sa > sb end
            else
                if currentSort.ascending then return (a.data.modified or 0) < (b.data.modified or 0)
                else return (a.data.modified or 0) > (b.data.modified or 0) end
            end
        end

        table.sort(dailies, sortNotes)
        table.sort(weeklies, sortNotes)
        table.sort(favorites, sortNotes)
        table.sort(regular, sortNotes)

        local function CreateSectionHeader(text, yPos, count)
            local section = OneWoW_GUI:CreateSectionHeader(scrollChild, {
                title = text,
                yOffset = yPos,
                rightText = ns.UI.FormatSectionCount(count),
            })
            table.insert(noteListItems, section)
            return section
        end

        local function BuildNoteRow(note, yOffset, sectionKey)
            local colorConfig = ns.Config:GetResolvedColorConfig(note.data.pinColor or "hunter")
            local bg = colorConfig.background

            local iconAtlas
            if note.data.noteType == "daily" then
                iconAtlas = "questlog-questtypeicon-Daily"
            elseif note.data.noteType == "weekly" then
                iconAtlas = "questlog-questtypeicon-Weekly"
            end

            local rowOpts = {
                yOffset     = yOffset,
                barColor    = { bg[1], bg[2], bg[3] },
                icon        = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up",
                iconAtlas   = iconAtlas,
                title       = note.data.title or L["NOTE_UNTITLED"],
                storageText = note.data.storage == "character" and CHARACTER or L["UI_STORAGE_ACCOUNT"],
                selected    = (selectedNote == note.id),
                shouldSuppressSelect = IsAnyNotesReorderActive,
                onSelect    = function()
                    selectedNote = note.id
                    ShowEditor()
                    parent.RefreshNotesList()
                end,
                pin = {
                    active  = (note.data.pinEnabled and ns.notePins and ns.notePins[note.id]) and true or false,
                    tooltip = { title = L["TOOLTIP_NOTE_PIN"], desc = L["TOOLTIP_NOTE_PIN_DESC"] },
                    onToggle = function(state)
                        if not ns.NotesPins then return end
                        local noteData2 = NotesData:GetAllNotes()[note.id]
                        if not noteData2 then return end
                        if state then
                            noteData2.pinEnabled = true
                            ns.NotesPins:ShowNotePin(note.id)
                        else
                            ns.NotesPins:HideNotePin(note.id)
                            noteData2.pinEnabled = false
                        end
                        if parent.UpdateEditorButtons then parent.UpdateEditorButtons() end
                    end,
                },
                fav = {
                    active  = note.data.favorite and true or false,
                    tooltip = { title = L["TOOLTIP_NOTE_FAVORITE"], desc = L["TOOLTIP_NOTE_FAVORITE_DESC"] },
                    onToggle = function()
                        if ns.NotesData then
                            ns.NotesData:ToggleFavorite(note.id)
                            parent.RefreshNotesList()
                            if parent.UpdateEditorButtons then parent.UpdateEditorButtons() end
                        end
                    end,
                },
                props = {
                    tooltip = { title = L["TOOLTIP_NOTE_PROPERTIES"], desc = L["TOOLTIP_NOTE_PROPERTIES_DESC"] },
                    onClick = function()
                        if ns.UI.ShowNotePropertiesDialog then ns.UI.ShowNotePropertiesDialog(note.id) end
                    end,
                },
                delete = {
                    tooltip = { title = L["TOOLTIP_NOTE_DELETE"], desc = L["TOOLTIP_NOTE_DELETE_DESC"] },
                    onClick = function()
                        StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE"] = {
                            text = string.format(L["POPUP_DELETE_NOTE"], note.data.title or L["NOTE_UNTITLED"]),
                            button1 = DELETE,
                            button2 = CANCEL,
                            OnAccept = function()
                                NotesData:RemoveNote(note.id)
                                if selectedNote == note.id then
                                    selectedNote = nil
                                    if emptyMessage then emptyMessage:Show() end
                                    if detailPanel.editorContent then
                                        for _, frame in pairs(detailPanel.editorContent) do
                                            if frame and frame.Hide then frame:Hide() end
                                        end
                                    end
                                end
                                parent.RefreshNotesList()
                            end,
                            timeout = 0, whileDead = true, hideOnEscape = true,
                        }
                        StaticPopup_Show("ONEWOW_NOTES_CONFIRM_DELETE")
                    end,
                },
            }

            local row = ns.UI.CreateNotesListRow(scrollChild, rowOpts)
            table.insert(noteListItems, row)
            local frames = sectionRowFrames[sectionKey]
            frames[#frames + 1] = row
            GetOrCreateSectionReorder(sectionKey):Attach(row, #frames)
        end

        local function PaintSection(sectionKey, title, bag, yOffset)
            if #bag == 0 then
                return yOffset
            end
            sectionDataBags[sectionKey] = bag
            sectionRowFrames[sectionKey] = {}
            CreateSectionHeader(title, yOffset, #bag)
            yOffset = yOffset - 30
            for _, note in ipairs(bag) do
                BuildNoteRow(note, yOffset, sectionKey)
                yOffset = yOffset - ns.UI.LIST_ROW_SPACING
            end
            return yOffset
        end

        local yOffset = 0
        yOffset = PaintSection("daily", DAILY, dailies, yOffset)
        yOffset = PaintSection("weekly", WEEKLY, weeklies, yOffset)
        yOffset = PaintSection("favorites", FAVORITES, favorites, yOffset)
        yOffset = PaintSection("regular", L["TAB_NOTES"], regular, yOffset)

        scrollChild:SetHeight(math.abs(yOffset) + 50)
        if leftStatusText then
            leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_NOTES"],
                #dailies + #weeklies + #favorites + #regular))
        end
    end

    parent.RefreshNotesList()

    parent.selectedNote = function() return selectedNote end
    parent.setSelectedNote = function(noteID)
        selectedNote = noteID
        if noteID then
            ShowEditor()
        end
    end
    parent.controlPanel = controlPanel
    parent.listingPanel = listingPanel
    parent.detailPanel = detailPanel

    parent:HookScript("OnShow", function()
        if ns.pendingJournalSelect then
            local noteID = ns.pendingJournalSelect
            ns.pendingJournalSelect = nil
            parent.setSelectedNote(noteID)
        end
    end)
end
