-- OneWoW_Notes Addon File
-- OneWoW_Notes/UI/t-notes.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

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
local notesFrame = nil
local editorPanel = nil
local contentEditBox = nil
local todoContainer = nil
local emptyMessage = nil
local leftStatusText = nil
local rightStatusText = nil
local scrollChild = nil
local scrollFrame = nil

local MEDIA = "Interface\\AddOns\\OneWoW_Notes\\Media\\"

local BACKDROP_STANDARD = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = true, tileSize = 16, edgeSize = 1,
}

local function CreateThemedPanel(name, parentFrame)
    local f = CreateFrame("Frame", name, parentFrame, "BackdropTemplate")
    f:SetBackdrop(BACKDROP_STANDARD)
    f:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    f:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    return f
end

local function CreateThemedBar(name, parentFrame)
    local f = CreateFrame("Frame", name, parentFrame, "BackdropTemplate")
    f:SetBackdrop(BACKDROP_STANDARD)
    f:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    f:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    return f
end

local function GetFontColorFromKey(fontColorKey, pinColorKey)
    return ns.Config:GetResolvedFontColor(fontColorKey, pinColorKey)
end

function ns.UI.CreateNotesTab(parent)
    notesFrame = parent
    ns.UI.notesFrame = parent

    local controlPanel = CreateThemedBar(nil, parent)
    controlPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(75)

    local controlTitle = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    controlTitle:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -8)
    controlTitle:SetText(L["NOTES_CONTROLS"])
    controlTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local addNoteBtn = ns.UI.CreateButton(nil, controlPanel, L["BUTTON_ADD_NOTE"], 100, 25)
    ns.UI.AutoResizeButton(addNoteBtn, 80, 200)
    addNoteBtn:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -28)
    addNoteBtn:SetScript("OnClick", function()
        if ns.UI.ShowAddNoteDialog then
            ns.UI.ShowAddNoteDialog()
        end
    end)
    addNoteBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TOOLTIP_BUTTON_ADD_NOTE"], 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_BUTTON_ADD_NOTE_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addNoteBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    local categoryDropdown = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_CATEGORY"], 140, 25)
    categoryDropdown:SetPoint("LEFT", addNoteBtn, "RIGHT", 8, 0)
    local function RefreshCatOpts()
        local catOpts = {{text = L["UI_ALL"], value = "All"}}
        if ns.NotesCategories then
            for _, category in ipairs(ns.NotesCategories:GetCategories()) do
                catOpts[#catOpts + 1] = {text = category, value = category}
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

    local manageCategoriesBtn = CreateFrame("Button", nil, controlPanel)
    manageCategoriesBtn:SetSize(20, 20)
    manageCategoriesBtn:SetPoint("LEFT", categoryDropdown, "RIGHT", 4, 0)
    manageCategoriesBtn:SetNormalTexture(MEDIA .. "icon-gears.png")
    manageCategoriesBtn:GetNormalTexture():SetTexCoord(0.1, 0.9, 0.1, 0.9)
    manageCategoriesBtn:SetHighlightTexture(MEDIA .. "icon-gears.png")
    manageCategoriesBtn:GetHighlightTexture():SetTexCoord(0.1, 0.9, 0.1, 0.9)
    manageCategoriesBtn:GetHighlightTexture():SetAlpha(0.5)
    manageCategoriesBtn:SetScript("OnClick", function()
        if ns.UI and ns.UI.ShowCategoryManager then
            ns.UI.ShowCategoryManager("notes")
        end
    end)
    manageCategoriesBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["UI_MANAGE_CATEGORIES"], 1, 1, 1)
        GameTooltip:AddLine(L["UI_MANAGE_CATEGORIES_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    manageCategoriesBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    local storageDropdown = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_STORAGE"], 130, 25)
    storageDropdown:SetPoint("LEFT", manageCategoriesBtn, "RIGHT", 4, 0)
    storageDropdown:SetOptions({
        {text = L["UI_ALL"],               value = "All"},
        {text = L["UI_STORAGE_ACCOUNT"],   value = "account"},
        {text = L["UI_STORAGE_CHARACTER"], value = "character"},
    })
    storageDropdown:SetSelected("All")
    storageDropdown.onSelect = function(value)
        currentFilters.storage = value
        if parent.RefreshNotesList then parent.RefreshNotesList() end
    end

    local sortDropdown = ns.UI.CreateThemedDropdown(controlPanel, L["NOTE_SORT_BY"] and "Sort" or "Sort", 120, 25)
    sortDropdown:SetPoint("LEFT", storageDropdown, "RIGHT", 6, 0)
    sortDropdown:SetOptions({
        {text = L["NOTE_SORT_TITLE"],    value = "title"},
        {text = L["NOTE_SORT_CREATED"],  value = "created"},
        {text = L["NOTE_SORT_MODIFIED"], value = "modified"},
    })
    sortDropdown:SetSelected("modified")
    sortDropdown.onSelect = function(value)
        currentSort.by = value
        if parent.RefreshNotesList then parent.RefreshNotesList() end
    end

    local sortDirectionBtn = CreateFrame("Button", nil, controlPanel)
    sortDirectionBtn:SetSize(24, 24)
    sortDirectionBtn:SetPoint("LEFT", sortDropdown, "RIGHT", 4, 0)
    sortDirectionBtn:SetNormalAtlas(currentSort.ascending and "common-button-collapseExpand-up" or "common-button-collapseExpand-down")
    sortDirectionBtn:SetPushedAtlas(currentSort.ascending and "common-button-collapseExpand-up" or "common-button-collapseExpand-down")
    sortDirectionBtn:SetHighlightAtlas(currentSort.ascending and "common-button-collapseExpand-up" or "common-button-collapseExpand-down")
    sortDirectionBtn:GetHighlightTexture():SetAlpha(0.5)
    sortDirectionBtn:SetScript("OnClick", function(self)
        currentSort.ascending = not currentSort.ascending
        local atlas = currentSort.ascending and "common-button-collapseExpand-up" or "common-button-collapseExpand-down"
        self:SetNormalAtlas(atlas)
        self:SetPushedAtlas(atlas)
        self:SetHighlightAtlas(atlas)
        if parent.RefreshNotesList then parent.RefreshNotesList() end
    end)

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
        GameTooltip:SetText(L["UI_NOTES_HYPERLINK_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["UI_NOTES_HYPERLINK_HINT"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    helpButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local listingPanel = CreateThemedPanel(nil, parent)
    listingPanel:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -10)
    listingPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 35)
    listingPanel:SetWidth(258)

    local listingTitle = listingPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    listingTitle:SetPoint("TOP", listingPanel, "TOP", 0, -10)
    listingTitle:SetText(L["NOTES_LIST"])
    listingTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local listScroll = ns.UI.CreateCustomScroll(listingPanel)
    scrollFrame = listScroll.scrollFrame
    scrollChild = listScroll.scrollChild
    listScroll.container:SetPoint("TOPLEFT",     listingPanel, "TOPLEFT",     10, -40)
    listScroll.container:SetPoint("BOTTOMRIGHT", listingPanel, "BOTTOMRIGHT", -10, 10)

    local detailPanel = CreateThemedPanel(nil, parent)
    detailPanel:SetPoint("TOPLEFT", listingPanel, "TOPRIGHT", 10, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 35)

    editorPanel = detailPanel
    ns.UI.notesDetailPanel = detailPanel

    emptyMessage = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    emptyMessage:SetPoint("CENTER", detailPanel, "CENTER")
    emptyMessage:SetText(L["MESSAGE_SELECT_NOTE"])
    emptyMessage:SetTextColor(0.6, 0.6, 0.7, 1)

    local leftStatusBar = CreateThemedBar(nil, parent)
    leftStatusBar:SetPoint("TOPLEFT", listingPanel, "BOTTOMLEFT", 0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listingPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)

    leftStatusText = leftStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_NOTES"], 0))

    local rightStatusBar = CreateThemedBar(nil, parent)
    rightStatusBar:SetPoint("TOPLEFT", detailPanel, "BOTTOMLEFT", 0, -5)
    rightStatusBar:SetPoint("TOPRIGHT", detailPanel, "BOTTOMRIGHT", 0, -5)
    rightStatusBar:SetHeight(25)

    rightStatusText = rightStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
    rightStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rightStatusText:SetText(L["STATUS_READY"])

    local function ShowEditor()
        emptyMessage:Hide()

        for _, child in ipairs({detailPanel:GetChildren()}) do
            if child ~= emptyMessage then
                child:Hide()
            end
        end

        if not detailPanel.editorContent then
            local editorHeader = CreateThemedBar(nil, detailPanel)
            editorHeader:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 10, -10)
            editorHeader:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -10, -10)
            editorHeader:SetHeight(85)

            local titleEditBox = CreateFrame("EditBox", nil, editorHeader, "InputBoxTemplate")
            titleEditBox:SetPoint("TOPLEFT", editorHeader, "TOPLEFT", 12, -8)
            titleEditBox:SetPoint("TOPRIGHT", editorHeader, "TOPRIGHT", -110, -8)
            titleEditBox:SetHeight(30)
            titleEditBox:SetFontObject("GameFontNormalLarge")
            titleEditBox:SetAutoFocus(false)
            titleEditBox:SetScript("OnEnterPressed", function(self)
                if selectedNote and ns.NotesData then
                    ns.NotesData:UpdateNoteTitle(selectedNote, self:GetText())
                    parent.RefreshNotesList()
                end
                self:ClearFocus()
            end)
            titleEditBox:SetScript("OnEditFocusLost", function(self)
                if selectedNote and ns.NotesData then
                    ns.NotesData:UpdateNoteTitle(selectedNote, self:GetText())
                    parent.RefreshNotesList()
                end
            end)
            editorHeader.titleEditBox = titleEditBox

            local deleteBtn = CreateFrame("Button", nil, editorHeader)
            deleteBtn:SetSize(22, 22)
            deleteBtn:SetPoint("TOPRIGHT", editorHeader, "TOPRIGHT", -12, -12)
            deleteBtn:SetNormalTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetPushedTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetHighlightTexture(MEDIA .. "icon-trash.png")
            deleteBtn:GetHighlightTexture():SetAlpha(0.5)
            deleteBtn:SetScript("OnClick", function()
                if selectedNote then
                    StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE"] = {
                        text = string.format(L["POPUP_DELETE_NOTE"], selectedNote),
                        button1 = L["BUTTON_DELETE"],
                        button2 = L["BUTTON_CANCEL"],
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
            end)
            deleteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NOTE_DELETE"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NOTE_DELETE_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            deleteBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
            editorHeader.deleteBtn = deleteBtn

            local propertiesBtn = CreateFrame("Button", nil, editorHeader)
            propertiesBtn:SetSize(22, 22)
            propertiesBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -2, 0)
            propertiesBtn:SetNormalTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:SetPushedTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:SetHighlightTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:GetHighlightTexture():SetAlpha(0.5)
            propertiesBtn:SetScript("OnClick", function()
                if selectedNote and ns.UI and ns.UI.ShowNotePropertiesDialog then
                    ns.UI.ShowNotePropertiesDialog(selectedNote)
                end
            end)
            propertiesBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NOTE_PROPERTIES"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NOTE_PROPERTIES_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            propertiesBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
            editorHeader.propertiesBtn = propertiesBtn

            local pinBtn = CreateFrame("CheckButton", nil, editorHeader)
            pinBtn:SetSize(22, 22)
            pinBtn:SetPoint("RIGHT", propertiesBtn, "LEFT", -2, 0)

            local pinNormalTex = pinBtn:CreateTexture(nil, "BACKGROUND")
            pinNormalTex:SetAllPoints()
            pinNormalTex:SetTexture(MEDIA .. "icon-pin.png")
            pinNormalTex:SetDesaturated(true)
            pinNormalTex:SetAlpha(0.3)
            pinBtn:SetNormalTexture(pinNormalTex)

            local pinHighlightTex = pinBtn:CreateTexture(nil, "HIGHLIGHT")
            pinHighlightTex:SetAllPoints()
            pinHighlightTex:SetTexture(MEDIA .. "icon-pin.png")
            pinHighlightTex:SetAlpha(0.5)
            pinBtn:SetHighlightTexture(pinHighlightTex)

            pinBtn:SetScript("OnClick", function(self)
                if selectedNote and ns.NotesPins and ns.NotesData then
                    local allNotes = ns.NotesData:GetAllNotes()
                    local noteData = allNotes[selectedNote]
                    local addon = _G.OneWoW_Notes
                    if noteData then
                        if noteData.pinEnabled and addon.notePins and addon.notePins[selectedNote] then
                            ns.NotesPins:HideNotePin(selectedNote)
                            noteData.pinEnabled = false
                            self:GetNormalTexture():SetDesaturated(true)
                            self:GetNormalTexture():SetAlpha(0.3)
                            self:SetChecked(false)
                        else
                            noteData.pinEnabled = true
                            ns.NotesPins:ShowNotePin(selectedNote)
                            self:GetNormalTexture():SetDesaturated(false)
                            self:GetNormalTexture():SetAlpha(1.0)
                            self:SetChecked(true)
                        end
                        parent.RefreshNotesList()
                    end
                end
            end)
            pinBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NOTE_PIN"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NOTE_PIN_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            pinBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
            editorHeader.pinBtn = pinBtn

            local favoriteBtn = CreateFrame("CheckButton", nil, editorHeader)
            favoriteBtn:SetSize(22, 22)
            favoriteBtn:SetPoint("RIGHT", pinBtn, "LEFT", -2, 0)

            local favNormalTex = favoriteBtn:CreateTexture(nil, "BACKGROUND")
            favNormalTex:SetAllPoints()
            favNormalTex:SetTexture(MEDIA .. "icon-fav.png")
            favNormalTex:SetDesaturated(true)
            favNormalTex:SetAlpha(0.3)
            favoriteBtn:SetNormalTexture(favNormalTex)

            local favCheckedTex = favoriteBtn:CreateTexture(nil, "BACKGROUND")
            favCheckedTex:SetAllPoints()
            favCheckedTex:SetTexture(MEDIA .. "icon-fav.png")
            favoriteBtn:SetCheckedTexture(favCheckedTex)

            local favHighlightTex = favoriteBtn:CreateTexture(nil, "HIGHLIGHT")
            favHighlightTex:SetAllPoints()
            favHighlightTex:SetTexture(MEDIA .. "icon-fav.png")
            favHighlightTex:SetAlpha(0.5)
            favoriteBtn:SetHighlightTexture(favHighlightTex)

            favoriteBtn:SetScript("OnClick", function(self)
                if selectedNote and ns.NotesData then
                    local isFav = ns.NotesData:ToggleFavorite(selectedNote)
                    if isFav then
                        self:GetNormalTexture():SetDesaturated(false)
                        self:GetNormalTexture():SetAlpha(1.0)
                        self:SetChecked(true)
                    else
                        self:GetNormalTexture():SetDesaturated(true)
                        self:GetNormalTexture():SetAlpha(0.3)
                        self:SetChecked(false)
                    end
                    parent.RefreshNotesList()
                end
            end)
            favoriteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NOTE_FAVORITE"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NOTE_FAVORITE_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            favoriteBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
            editorHeader.favoriteBtn = favoriteBtn

            local noteTypeLine = editorHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            noteTypeLine:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -12, 24)
            noteTypeLine:SetText(string.format(L["UI_TYPE_FORMAT"], L["NOTE_TYPE_STANDARD"]))
            noteTypeLine:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            noteTypeLine:SetJustifyH("RIGHT")
            editorHeader.noteTypeLine = noteTypeLine

            local categoryLine = editorHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            categoryLine:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -12, 8)
            categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], L["UI_GENERAL"]))
            categoryLine:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            categoryLine:SetJustifyH("RIGHT")
            editorHeader.categoryLine = categoryLine

            local autoPinCheckbox = CreateFrame("CheckButton", nil, editorHeader, "UICheckButtonTemplate")
            autoPinCheckbox:SetSize(20, 20)
            autoPinCheckbox:SetPoint("BOTTOMLEFT", editorHeader, "BOTTOMLEFT", 8, 4)
            autoPinCheckbox.Text:SetText(L["NOTE_AUTOPIN_WHEN_COMPLETE"] or "Auto-hide when tasks complete")
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

            local contentBg = CreateThemedBar(nil, detailPanel)
            contentBg:SetPoint("TOPLEFT", editorHeader, "BOTTOMLEFT", 0, -10)
            contentBg:SetPoint("TOPRIGHT", editorHeader, "BOTTOMRIGHT", 0, -10)
            contentBg:SetHeight(190)
            contentBg:EnableMouse(true)

            local contentScroll = CreateFrame("ScrollFrame", nil, contentBg, "UIPanelScrollFrameTemplate")
            contentScroll:SetPoint("TOPLEFT", contentBg, "TOPLEFT", 4, -4)
            contentScroll:SetPoint("BOTTOMRIGHT", contentBg, "BOTTOMRIGHT", -26, 4)
            contentBg:SetFrameLevel(contentScroll:GetFrameLevel() - 1)

            contentEditBox = CreateFrame("EditBox", nil, contentScroll)
            contentEditBox:SetMultiLine(true)
            contentEditBox:SetFontObject("ChatFontNormal")
            contentEditBox:SetWidth(contentScroll:GetWidth() - 20)
            contentEditBox:SetAutoFocus(false)
            contentEditBox:SetMaxLetters(0)
            contentEditBox:SetHyperlinksEnabled(true)
            contentEditBox:SetScript("OnHyperlinkClick", function(self, link, text, button)
                SetItemRef(link, text, button)
            end)
            contentEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            contentEditBox:SetScript("OnTextChanged", function(self, userInput)
                if userInput and selectedNote and ns.NotesData then
                    ns.NotesData:UpdateNote(selectedNote, self:GetText())

                    if contentUpdateTimer then contentUpdateTimer:Cancel() end

                    contentUpdateTimer = C_Timer.NewTimer(2, function()
                        local addon = _G.OneWoW_Notes
                        if selectedNote and addon.notePins and addon.notePins[selectedNote] then
                            local pinFrame = addon.notePins[selectedNote]
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
            end)
            contentEditBox:SetScript("OnReceiveDrag", function(self)
                local cursorType, itemID, itemLink = GetCursorInfo()
                if cursorType == "item" and itemLink then
                    self:Insert(itemLink)
                    ClearCursor()
                elseif cursorType == "spell" then
                    local spellID = select(2, GetCursorInfo())
                    if spellID then
                        local spellLink = nil
                        if C_Spell and C_Spell.GetSpellLink then
                            spellLink = C_Spell.GetSpellLink(spellID)
                        elseif GetSpellLink then
                            spellLink = GetSpellLink(spellID)
                        end
                        if spellLink then self:Insert(spellLink) end
                    end
                    ClearCursor()
                end
            end)
            contentEditBox:SetScript("OnMouseDown", function(self, button)
                if button == "LeftButton" then
                    local cursorType = GetCursorInfo()
                    if cursorType == "item" or cursorType == "spell" then
                        local ct, itemID, itemLink = GetCursorInfo()
                        if ct == "item" and itemLink then
                            self:Insert(itemLink)
                            ClearCursor()
                        elseif ct == "spell" then
                            local spellID = select(2, GetCursorInfo())
                            if spellID then
                                local spellLink = nil
                                if C_Spell and C_Spell.GetSpellLink then
                                    spellLink = C_Spell.GetSpellLink(spellID)
                                elseif GetSpellLink then
                                    spellLink = GetSpellLink(spellID)
                                end
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
            contentScroll:SetScrollChild(contentEditBox)
            detailPanel.contentEditBox = contentEditBox

            contentBg:SetScript("OnMouseDown", function(self, button)
                if detailPanel.contentEditBox then
                    detailPanel.contentEditBox:SetFocus()
                    if button == "LeftButton" then
                        local cursorType, itemID, itemLink = GetCursorInfo()
                        if cursorType == "item" and itemLink then
                            detailPanel.contentEditBox:Insert(itemLink)
                            ClearCursor()
                        elseif cursorType == "spell" then
                            local spellID = select(2, GetCursorInfo())
                            if spellID then
                                local spellLink = nil
                                if C_Spell and C_Spell.GetSpellLink then
                                    spellLink = C_Spell.GetSpellLink(spellID)
                                elseif GetSpellLink then
                                    spellLink = GetSpellLink(spellID)
                                end
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
            todoSection:SetPoint("TOPLEFT", contentBg, "BOTTOMLEFT", 0, -10)
            todoSection:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -8, 10)
            todoSection:SetClipsChildren(true)

            local todoHeader = CreateFrame("Frame", nil, todoSection)
            todoHeader:SetPoint("TOPLEFT", todoSection, "TOPLEFT", 0, 0)
            todoHeader:SetPoint("TOPRIGHT", todoSection, "TOPRIGHT", -22, 0)
            todoHeader:SetHeight(30)

            local todoLabel = todoHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            todoLabel:SetPoint("LEFT", todoHeader, "LEFT", 5, 0)
            todoLabel:SetText(L["UI_TASKS"])
            todoLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local resetTasksBtn = CreateFrame("Button", nil, todoHeader)
            resetTasksBtn:SetSize(20, 20)
            resetTasksBtn:SetPoint("LEFT", todoLabel, "RIGHT", 5, 0)
            resetTasksBtn:SetNormalAtlas("talents-button-undo")
            resetTasksBtn:SetPushedAtlas("talents-button-undo")
            resetTasksBtn:SetHighlightAtlas("talents-button-undo")
            resetTasksBtn:GetHighlightTexture():SetAlpha(0.5)
            resetTasksBtn:SetScript("OnClick", function()
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
            end)
            resetTasksBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L["NOTE_RESET_TODOS"], 1, 1, 1)
                GameTooltip:AddLine(L["NOTE_RESET_TODOS_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            resetTasksBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

            local addTaskBtn = CreateFrame("Button", nil, todoHeader)
            addTaskBtn:SetSize(24, 24)
            addTaskBtn:SetPoint("RIGHT", todoHeader, "RIGHT", 0, 0)

            local taskInputBox = CreateFrame("EditBox", nil, todoHeader, "InputBoxTemplate")
            taskInputBox:SetPoint("LEFT", resetTasksBtn, "RIGHT", 5, 0)
            taskInputBox:SetPoint("RIGHT", addTaskBtn, "LEFT", -5, 0)
            taskInputBox:SetHeight(25)
            taskInputBox:SetAutoFocus(false)
            taskInputBox:SetScript("OnEnterPressed", function(self)
                local text = self:GetText()
                if text and text ~= "" and selectedNote and ns.NotesTodos then
                    ns.NotesTodos:AddTodo(selectedNote, text)
                    self:SetText("")
                    if parent.RefreshTodoList then parent.RefreshTodoList() end
                end
                self:ClearFocus()
            end)
            addTaskBtn:SetNormalTexture(MEDIA .. "icon-add.png")
            addTaskBtn:SetHighlightTexture(MEDIA .. "icon-add.png")
            addTaskBtn:SetPushedTexture(MEDIA .. "icon-add.png")
            addTaskBtn:GetHighlightTexture():SetAlpha(0.5)
            addTaskBtn:SetScript("OnClick", function()
                local text = taskInputBox:GetText()
                if text and text ~= "" and selectedNote and ns.NotesTodos then
                    ns.NotesTodos:AddTodo(selectedNote, text)
                    taskInputBox:SetText("")
                    if parent.RefreshTodoList then parent.RefreshTodoList() end
                end
            end)

            local todoScroll = CreateFrame("ScrollFrame", nil, todoSection, "UIPanelScrollFrameTemplate")
            todoScroll:SetPoint("TOPLEFT", todoHeader, "BOTTOMLEFT", 0, -5)
            todoScroll:SetPoint("BOTTOMRIGHT", todoSection, "BOTTOMRIGHT", -22, 0)

            todoContainer = CreateFrame("Frame", nil, todoScroll)
            todoContainer:SetSize(todoScroll:GetWidth() - 20, 1)
            todoScroll:SetScrollChild(todoContainer)
            detailPanel.todoContainer = todoContainer

            todoScroll:SetScript("OnSizeChanged", function(self, width)
                if todoContainer then todoContainer:SetWidth(width - 20) end
            end)

            local separatorLine = OneWoW_GUI:CreateDivider(detailPanel, 0)
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

        if selectedNote and ns.NotesData then
            local allNotes = ns.NotesData:GetAllNotes()
            local note = allNotes[selectedNote]
            if note and type(note) == "table" then
                if detailPanel.editorContent.header.titleEditBox then
                    detailPanel.editorContent.header.titleEditBox:SetText(note.title or "")
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

                    if header.titleEditBox then
                        header.titleEditBox:SetTextColor(textColor[1], textColor[2], textColor[3])
                    end
                    if header.categoryLine then
                        header.categoryLine:SetTextColor(textColor[1], textColor[2], textColor[3])
                        header.categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], note.category or L["UI_GENERAL"]))
                    end
                    if header.noteTypeLine then
                        local noteType = note.noteType or "standard"
                        local noteTypeText = noteType == "daily" and L["NOTE_TYPE_DAILY"] or noteType == "weekly" and L["NOTE_TYPE_WEEKLY"] or noteType == "escpanel" and L["NOTE_TYPE_ESCPANEL"] or L["NOTE_TYPE_STANDARD"]
                        header.noteTypeLine:SetText(string.format(L["UI_TYPE_FORMAT"], noteTypeText))
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
                        if note.favorite then
                            header.favoriteBtn:GetNormalTexture():SetDesaturated(false)
                            header.favoriteBtn:GetNormalTexture():SetAlpha(1.0)
                            header.favoriteBtn:SetChecked(true)
                        else
                            header.favoriteBtn:GetNormalTexture():SetDesaturated(true)
                            header.favoriteBtn:GetNormalTexture():SetAlpha(0.3)
                            header.favoriteBtn:SetChecked(false)
                        end
                    end
                    if header.pinBtn then
                        local addon = _G.OneWoW_Notes
                        local pinEnabled = note.pinEnabled and addon.notePins and addon.notePins[selectedNote]
                        header.pinBtn:GetNormalTexture():SetDesaturated(not pinEnabled)
                        header.pinBtn:GetNormalTexture():SetAlpha(pinEnabled and 1.0 or 0.3)
                        header.pinBtn:SetChecked(pinEnabled and true or false)
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
            if note.favorite then
                header.favoriteBtn:GetNormalTexture():SetDesaturated(false)
                header.favoriteBtn:GetNormalTexture():SetAlpha(1.0)
                header.favoriteBtn:SetChecked(true)
            else
                header.favoriteBtn:GetNormalTexture():SetDesaturated(true)
                header.favoriteBtn:GetNormalTexture():SetAlpha(0.3)
                header.favoriteBtn:SetChecked(false)
            end
        end
        if header.pinBtn then
            local addon = _G.OneWoW_Notes
            local pinEnabled = note.pinEnabled and addon.notePins and addon.notePins[selectedNote]
            header.pinBtn:GetNormalTexture():SetDesaturated(not pinEnabled)
            header.pinBtn:GetNormalTexture():SetAlpha(pinEnabled and 1.0 or 0.3)
            header.pinBtn:SetChecked(pinEnabled and true or false)
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
            if detailPanel.editorContent.header.titleEditBox then
                detailPanel.editorContent.header.titleEditBox:SetTextColor(textColor[1], textColor[2], textColor[3])
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
            child:SetParent(nil)
        end

        if not ns.NotesData then return end
        local allNotes = ns.NotesData:GetAllNotes()
        local note = allNotes[selectedNote]
        if not note or type(note) ~= "table" or not note.todos then return end

        local yOffset = 0
        for i, todo in ipairs(note.todos) do
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
                todoEditBox:SetTextColor(0.5, 0.5, 0.5)
            else
                todoEditBox:SetTextColor(1, 1, 1)
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

            local deleteTodoBtn = CreateFrame("Button", nil, todoFrame)
            deleteTodoBtn:SetSize(16, 16)
            deleteTodoBtn:SetPoint("RIGHT", todoFrame, "RIGHT", -5, 0)
            deleteTodoBtn:SetNormalTexture(MEDIA .. "icon-minus.png")
            deleteTodoBtn:SetPushedTexture(MEDIA .. "icon-minus.png")
            deleteTodoBtn:SetHighlightTexture(MEDIA .. "icon-minus.png")
            deleteTodoBtn:GetHighlightTexture():SetAlpha(0.5)
            deleteTodoBtn:SetScript("OnClick", function()
                if ns.NotesTodos then
                    ns.NotesTodos:RemoveTodo(selectedNote, todo.id)
                    parent.RefreshTodoList()
                end
            end)

            yOffset = yOffset - 30
        end

        todoContainer:SetHeight(math.abs(yOffset) + 50)
    end

    function parent.RefreshNotesList()
        for _, item in pairs(noteListItems) do
            item:Hide()
            item:SetParent(nil)
        end
        noteListItems = {}

        local NotesData = ns.NotesData
        if not NotesData then return end

        local allNotes = NotesData:GetAllNotes()
        local notesList = {}
        local currentTime = GetServerTime()

        for noteID, noteData in pairs(allNotes) do
            if type(noteData) == "table" then
                if noteData.isNew and noteData.newTimestamp then
                    local elapsed = currentTime - noteData.newTimestamp
                    if elapsed > 3600 then
                        noteData.isNew = false
                        noteData.newTimestamp = nil
                    end
                end

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

        local newNotes = {}
        local favorites = {}
        local regular = {}

        for _, note in ipairs(notesList) do
            if note.data.isNew then
                table.insert(newNotes, note)
            elseif note.data.favorite then
                table.insert(favorites, note)
            else
                table.insert(regular, note)
            end
        end

        local function sortNotes(a, b)
            if currentSort.by == "title" then
                local titleA = a.data.title or ""
                local titleB = b.data.title or ""
                if currentSort.ascending then return titleA < titleB
                else return titleA > titleB end
            elseif currentSort.by == "created" then
                if currentSort.ascending then return (a.data.created or 0) < (b.data.created or 0)
                else return (a.data.created or 0) > (b.data.created or 0) end
            else
                if currentSort.ascending then return (a.data.modified or 0) < (b.data.modified or 0)
                else return (a.data.modified or 0) > (b.data.modified or 0) end
            end
        end

        table.sort(newNotes, sortNotes)
        table.sort(favorites, sortNotes)
        table.sort(regular, sortNotes)

        local function CreateSectionHeader(text, yPos)
            local section = lib:CreateSectionHeader(scrollChild, text, yPos)
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yPos)
            section:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yPos)
            table.insert(noteListItems, section)
            return section
        end

        local addon = _G.OneWoW_Notes
        local function BuildNoteRow(note, yOffset)
            local noteFrame = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
            noteFrame:SetSize(scrollChild:GetWidth(), 50)
            noteFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)

            noteFrame:SetBackdrop(BACKDROP_STANDARD)

            local pinColor = note.data.pinColor or "hunter"
            local fontColor = note.data.fontColor or "match"
            local colorConfig = ns.Config:GetResolvedColorConfig(pinColor)
            local listItemColor = colorConfig.listItem
            local borderColor = colorConfig.border

            noteFrame:SetBackdropColor(listItemColor[1], listItemColor[2], listItemColor[3], listItemColor[4])
            noteFrame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)

            local deleteBtn = CreateFrame("Button", nil, noteFrame)
            deleteBtn:SetSize(22, 22)
            deleteBtn:SetPoint("BOTTOMRIGHT", noteFrame, "BOTTOMRIGHT", -5, 5)
            deleteBtn:SetNormalTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetPushedTexture(MEDIA .. "icon-trash.png")
            deleteBtn:SetHighlightTexture(MEDIA .. "icon-trash.png")
            deleteBtn:GetHighlightTexture():SetAlpha(0.5)
            deleteBtn:SetScript("OnClick", function()
                StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE"] = {
                    text = string.format(L["POPUP_DELETE_NOTE"], note.data.title or "Untitled"),
                    button1 = L["BUTTON_DELETE"],
                    button2 = L["BUTTON_CANCEL"],
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
            end)
            deleteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NOTE_DELETE"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NOTE_DELETE_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            deleteBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

            local propertiesBtn = CreateFrame("Button", nil, noteFrame)
            propertiesBtn:SetSize(22, 22)
            propertiesBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -1, 0)
            propertiesBtn:SetNormalTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:SetPushedTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:SetHighlightTexture(MEDIA .. "icon-gears.png")
            propertiesBtn:GetHighlightTexture():SetAlpha(0.5)
            propertiesBtn:SetScript("OnClick", function()
                if ns.UI.ShowNotePropertiesDialog then
                    ns.UI.ShowNotePropertiesDialog(note.id)
                end
            end)
            propertiesBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NOTE_PROPERTIES"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NOTE_PROPERTIES_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            propertiesBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

            local pinBtn = CreateFrame("CheckButton", nil, noteFrame)
            pinBtn:SetSize(22, 22)
            pinBtn:SetPoint("RIGHT", propertiesBtn, "LEFT", -1, 0)

            local normalTex = pinBtn:CreateTexture(nil, "BACKGROUND")
            normalTex:SetAllPoints()
            normalTex:SetTexture(MEDIA .. "icon-pin.png")
            local pinActive = note.data.pinEnabled and addon.notePins and addon.notePins[note.id]
            if pinActive then
                normalTex:SetDesaturated(false)
                normalTex:SetAlpha(1.0)
                pinBtn:SetChecked(true)
            else
                normalTex:SetDesaturated(true)
                normalTex:SetAlpha(0.3)
                pinBtn:SetChecked(false)
            end
            pinBtn:SetNormalTexture(normalTex)

            local checkedTex = pinBtn:CreateTexture(nil, "BACKGROUND")
            checkedTex:SetAllPoints()
            checkedTex:SetTexture(MEDIA .. "icon-pin.png")
            pinBtn:SetCheckedTexture(checkedTex)

            local highlightTex = pinBtn:CreateTexture(nil, "HIGHLIGHT")
            highlightTex:SetAllPoints()
            highlightTex:SetTexture(MEDIA .. "icon-pin.png")
            highlightTex:SetAlpha(0.5)
            pinBtn:SetHighlightTexture(highlightTex)

            pinBtn:SetScript("OnClick", function(self)
                if ns.NotesPins then
                    local noteData2 = NotesData:GetAllNotes()[note.id]
                    if noteData2 then
                        if noteData2.pinEnabled and addon.notePins and addon.notePins[note.id] then
                            ns.NotesPins:HideNotePin(note.id)
                            noteData2.pinEnabled = false
                            self:GetNormalTexture():SetDesaturated(true)
                            self:GetNormalTexture():SetAlpha(0.3)
                            self:SetChecked(false)
                        else
                            noteData2.pinEnabled = true
                            ns.NotesPins:ShowNotePin(note.id)
                            self:GetNormalTexture():SetDesaturated(false)
                            self:GetNormalTexture():SetAlpha(1.0)
                            self:SetChecked(true)
                        end
                        if parent.UpdateEditorButtons then parent.UpdateEditorButtons() end
                    end
                end
            end)
            pinBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NOTE_PIN"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NOTE_PIN_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            pinBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

            local favoriteBtn = CreateFrame("CheckButton", nil, noteFrame)
            favoriteBtn:SetSize(22, 22)
            favoriteBtn:SetPoint("RIGHT", pinBtn, "LEFT", -1, 0)

            local favNormalTex = favoriteBtn:CreateTexture(nil, "BACKGROUND")
            favNormalTex:SetAllPoints()
            favNormalTex:SetTexture(MEDIA .. "icon-fav.png")
            if note.data.favorite then
                favNormalTex:SetDesaturated(false)
                favNormalTex:SetAlpha(1.0)
                favoriteBtn:SetChecked(true)
            else
                favNormalTex:SetDesaturated(true)
                favNormalTex:SetAlpha(0.3)
                favoriteBtn:SetChecked(false)
            end
            favoriteBtn:SetNormalTexture(favNormalTex)

            local favCheckedTex2 = favoriteBtn:CreateTexture(nil, "BACKGROUND")
            favCheckedTex2:SetAllPoints()
            favCheckedTex2:SetTexture(MEDIA .. "icon-fav.png")
            favoriteBtn:SetCheckedTexture(favCheckedTex2)

            local favHighlightTex2 = favoriteBtn:CreateTexture(nil, "HIGHLIGHT")
            favHighlightTex2:SetAllPoints()
            favHighlightTex2:SetTexture(MEDIA .. "icon-fav.png")
            favHighlightTex2:SetAlpha(0.5)
            favoriteBtn:SetHighlightTexture(favHighlightTex2)

            favoriteBtn:SetScript("OnClick", function(self)
                if ns.NotesData then
                    local isFav = ns.NotesData:ToggleFavorite(note.id)
                    if isFav then
                        self:GetNormalTexture():SetDesaturated(false)
                        self:GetNormalTexture():SetAlpha(1.0)
                        self:SetChecked(true)
                    else
                        self:GetNormalTexture():SetDesaturated(true)
                        self:GetNormalTexture():SetAlpha(0.3)
                        self:SetChecked(false)
                    end
                    parent.RefreshNotesList()
                    if parent.UpdateEditorButtons then parent.UpdateEditorButtons() end
                end
            end)
            favoriteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_NOTE_FAVORITE"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_NOTE_FAVORITE_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            favoriteBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

            if note.data.isNew then
                local newFlagBtn = CreateFrame("Button", nil, noteFrame)
                newFlagBtn:SetSize(22, 22)
                newFlagBtn:SetPoint("RIGHT", favoriteBtn, "LEFT", -1, 0)
                newFlagBtn:SetNormalTexture(MEDIA .. "icon-flag.png")
                newFlagBtn:SetPushedTexture(MEDIA .. "icon-flag.png")
                newFlagBtn:SetHighlightTexture(MEDIA .. "icon-flag.png")
                newFlagBtn:GetHighlightTexture():SetAlpha(0.5)
                newFlagBtn:SetScript("OnClick", function()
                    if ns.NotesData then
                        local noteData2 = ns.NotesData:FindNote(note.id)
                        if noteData2 then
                            noteData2.isNew = false
                            noteData2.newTimestamp = nil
                            parent.RefreshNotesList()
                        end
                    end
                end)
                newFlagBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(L["TOOLTIP_NOTE_NEW"], 1, 1, 1)
                    GameTooltip:AddLine(L["UI_NOTE_REMOVE_FLAG_HINT"], 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                end)
                newFlagBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
            end

            local titleText = noteFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            titleText:SetPoint("TOPLEFT", noteFrame, "TOPLEFT", 10, -10)
            titleText:SetPoint("TOPRIGHT", noteFrame, "TOPRIGHT", -10, -10)
            titleText:SetJustifyH("LEFT")
            titleText:SetText(note.data.title or L["NOTE_UNTITLED"])
            local titleTextColor = GetFontColorFromKey(fontColor, pinColor)
            titleText:SetTextColor(titleTextColor[1], titleTextColor[2], titleTextColor[3])

            noteFrame:EnableMouse(true)
            noteFrame:SetScript("OnMouseDown", function(self)
                selectedNote = note.id
                ShowEditor()
                parent.RefreshNotesList()
            end)
            noteFrame:SetScript("OnEnter", function(self)
                if selectedNote ~= note.id then
                    self:SetBackdropColor(listItemColor[1] * 1.2, listItemColor[2] * 1.2, listItemColor[3] * 1.2, listItemColor[4] + 0.1)
                end
            end)
            noteFrame:SetScript("OnLeave", function(self)
                if selectedNote ~= note.id then
                    self:SetBackdropColor(listItemColor[1], listItemColor[2], listItemColor[3], listItemColor[4])
                end
            end)

            if selectedNote == note.id then
                noteFrame:SetBackdropColor(listItemColor[1] + 0.15, listItemColor[2] + 0.15, listItemColor[3] + 0.15, 0.9)
                noteFrame:SetBackdropBorderColor(1, 0.82, 0, 1)
            end

            table.insert(noteListItems, noteFrame)
        end

        local yOffset = 0

        if #newNotes > 0 then
            CreateSectionHeader(L["NOTES_SECTION_NEW"] or "New", yOffset)
            yOffset = yOffset - 35
        end
        for _, note in ipairs(newNotes) do
            BuildNoteRow(note, yOffset)
            yOffset = yOffset - 55
        end

        if #favorites > 0 then
            CreateSectionHeader(L["NOTES_SECTION_FAVORITES"] or "Favorites", yOffset)
            yOffset = yOffset - 35
        end
        for _, note in ipairs(favorites) do
            BuildNoteRow(note, yOffset)
            yOffset = yOffset - 55
        end

        if #regular > 0 then
            CreateSectionHeader(L["TAB_NOTES"], yOffset)
            yOffset = yOffset - 35
        end
        for _, note in ipairs(regular) do
            BuildNoteRow(note, yOffset)
            yOffset = yOffset - 55
        end

        scrollChild:SetHeight(math.abs(yOffset) + 50)
        if leftStatusText then
            leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_NOTES"], #newNotes + #favorites + #regular))
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
end
