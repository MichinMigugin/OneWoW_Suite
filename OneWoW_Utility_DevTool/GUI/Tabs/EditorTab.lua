local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local L = Addon.L or {}
local format = string.format
local max = math.max
local tinsert, wipe = tinsert, wipe
local strsub = string.sub
local GetTime = GetTime

local function noop()
end

function Addon.UI:CreateEditorTab(parent)
    local DU = Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
    local ES = Addon.EditorSyntax
    local EE = Addon.EditorEngine
    local D = Addon.EditorSyntaxData

    local LEFT_DEFAULT = DU.EDITOR_LEFT_PANE_DEFAULT_WIDTH or 220
    local LEFT_MIN = DU.EDITOR_LEFT_PANE_MIN_WIDTH or 160
    local RIGHT_MIN = DU.EDITOR_RIGHT_PANE_MIN_WIDTH or 400
    local DIVIDER_W = DU.EDITOR_DIVIDER_WIDTH or 6
    local OUTPUT_DEFAULT_H = DU.EDITOR_OUTPUT_DEFAULT_HEIGHT or 120
    local OUTPUT_MIN_H = DU.EDITOR_OUTPUT_MIN_HEIGHT or 60
    local EDITOR_MIN_H = DU.EDITOR_EDITOR_MIN_HEIGHT or 100
    local GUTTER_MIN_W = DU.EDITOR_GUTTER_MIN_WIDTH or 36
    local DEFAULT_FONT_SIZE = DU.EDITOR_DEFAULT_FONT_SIZE or 12
    local DEFAULT_INDENT = DU.EDITOR_DEFAULT_INDENT or 3
    local SNIPPET_ROW_H = DU.EDITOR_SNIPPET_ROW_HEIGHT or 20
    local CATEGORY_ROW_H = DU.EDITOR_CATEGORY_ROW_HEIGHT or 22
    local COLORIZE_DEBOUNCE = DU.EDITOR_COLORIZE_DEBOUNCE or 0.2
    local UNDO_DEBOUNCE = DU.EDITOR_UNDO_DEBOUNCE or 0.5
    local STATUS_BAR_H = DU.EDITOR_STATUS_BAR_HEIGHT or 18
    local SYNTAX_CHECK_DEBOUNCE = DU.EDITOR_SYNTAX_CHECK_DEBOUNCE or 5
    local STATUS_CLEAR_DELAY = DU.EDITOR_STATUS_CLEAR_DELAY or 5

    local MONOKAI_BG = D and D.MONOKAI and D.MONOKAI.BACKGROUND or {39/255, 40/255, 34/255, 1}
    local GUTTER_BG = D and D.MONOKAI and D.MONOKAI.GUTTER_BG or {30/255, 31/255, 27/255, 1}

    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local activeSnippetId = nil
    local activeDialog = nil
    local snippetRows = {}
    local categoryHeaders = {}
    local activeSnippetRowCount = 0
    local activeCategoryHeaderCount = 0
    local findBarVisible = false
    local lastUndoTime = 0
    local apiDocLoaded = false
    local statusClearTimer = nil
    local syntaxCheckTimer = nil
    local syntaxCheckDirty = false
    local lastCheckedText = nil
    local refreshListTimer = nil
    local pendingUndoTimer = nil
    local pendingUndoText = nil

    local function getDB()
        return Addon.db and Addon.db.editor
    end

    local function getFont()
        return OneWoW_GUI:GetFont() or "Fonts\\FRIZQT__.TTF"
    end

    local function getFontSize()
        local db = getDB()
        return db and db.fontSize or DEFAULT_FONT_SIZE
    end

    local function getIndentSize()
        local db = getDB()
        return db and db.indentSize or DEFAULT_INDENT
    end

    local function getDefaultCategoryName()
        if EE and EE.GetDefaultCategory then
            return EE:GetDefaultCategory()
        end
        return L["EDITOR_CATEGORY_DEFAULT"]
    end

    local function createDialogErrorLabel(dialog, anchor)
        local errorLabel = dialog.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        errorLabel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
        errorLabel:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -6)
        errorLabel:SetJustifyH("LEFT")
        errorLabel:SetWordWrap(true)
        errorLabel:SetTextColor(1, 0.3, 0.3, 1)
        errorLabel:SetText("")
        dialog.errorLabel = errorLabel
        return errorLabel
    end

    local function setDialogError(dialog, message)
        if dialog and dialog.errorLabel then
            dialog.errorLabel:SetText(message or "")
        end
    end

    local function getSnippetRenameError(snippetId, newName)
        local snippet = EE:GetSnippet(snippetId)
        newName = strtrim(newName or "")
        if not snippet or newName == "" then
            return L["EDITOR_MSG_NAME_REQUIRED"]
        end
        if EE:IsSnippetNameTakenInCategory(snippet.category, newName, snippetId) then
            return L["EDITOR_ERROR_SNIPPET_NAME_EXISTS"]
        end
        return nil, newName
    end

    local function getCategoryNameError(oldName, newName)
        newName = strtrim(newName or "")
        if newName == "" then
            return L["EDITOR_ERROR_CATEGORY_NAME_REQUIRED"]
        end
        if oldName and oldName == getDefaultCategoryName() and newName ~= oldName then
            return L["EDITOR_ERROR_CATEGORY_DEFAULT_RENAME"]
        end
        for _, cat in ipairs(EE:GetCategories()) do
            if cat == newName and cat ~= oldName then
                return L["EDITOR_ERROR_CATEGORY_NAME_EXISTS"]
            end
        end
        return nil, newName
    end

    local function clearPendingUndo()
        if pendingUndoTimer then
            pendingUndoTimer:Cancel()
            pendingUndoTimer = nil
        end
        pendingUndoText = nil
    end

    local function loadAPIDocs()
        if apiDocLoaded then return end
        apiDocLoaded = true
        if D and D.LoadAPIDocumentation then
            D:LoadAPIDocumentation()
        end
    end

    local updateGutter
    local updateFontSize
    local updateStatusMessage
    local updateLnCol
    local refreshSnippetList
    local autoSaveTicker = nil

    local btnHeight = 22
    local btnGap = 4
    local sectionGap = 14

    local newBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["EDITOR_BTN_NEW"], height = btnHeight })
    newBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)

    local renameBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["EDITOR_BTN_RENAME"], height = btnHeight })
    renameBtn:SetPoint("LEFT", newBtn, "RIGHT", btnGap, 0)

    local dupBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["EDITOR_BTN_DUPLICATE"], height = btnHeight })
    dupBtn:SetPoint("LEFT", renameBtn, "RIGHT", btnGap, 0)

    local saveBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["EDITOR_BTN_SAVE"], height = btnHeight })
    saveBtn:SetPoint("LEFT", dupBtn, "RIGHT", btnGap, 0)

    local deleteBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["EDITOR_BTN_DELETE"], height = btnHeight })
    deleteBtn:SetPoint("LEFT", saveBtn, "RIGHT", btnGap, 0)


    local runBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["EDITOR_BTN_RUN"], height = btnHeight })
    runBtn:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -5, -5)

    local autoSaveBox = OneWoW_GUI:CreateEditBox(tab, { width = 30, height = btnHeight })
    autoSaveBox:SetNumeric(true)
    autoSaveBox:SetMaxLetters(2)
    autoSaveBox:Hide()

    local autoSaveBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["EDITOR_BTN_AUTOSAVE"], height = btnHeight })
    autoSaveBtn:SetPoint("RIGHT", runBtn, "LEFT", -sectionGap, 0)

    local function refreshAutoSaveLayout()
        local edb = getDB()
        local interval = edb and edb.autoSaveInterval
        autoSaveBtn:ClearAllPoints()
        if interval then
            autoSaveBox:ClearAllPoints()
            autoSaveBox:SetPoint("RIGHT", runBtn, "LEFT", -sectionGap, 0)
            autoSaveBox:SetText(tostring(interval))
            autoSaveBox:Show()
            autoSaveBtn:SetPoint("RIGHT", autoSaveBox, "LEFT", -2, 0)
            autoSaveBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            autoSaveBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            autoSaveBtn.text:SetTextColor(1, 1, 1)
        else
            autoSaveBox:Hide()
            autoSaveBtn:SetPoint("RIGHT", runBtn, "LEFT", -sectionGap, 0)
            autoSaveBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            autoSaveBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            autoSaveBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end

    local function startAutoSaveTicker()
        if autoSaveTicker then autoSaveTicker:Cancel(); autoSaveTicker = nil end
        local edb = getDB()
        local interval = edb and edb.autoSaveInterval
        if not interval then return end
        autoSaveTicker = C_Timer.NewTicker(interval * 60, function()
            if activeSnippetId and tab.editBox then
                local snippet = EE:GetSnippet(activeSnippetId)
                if snippet and not snippet.untitled and EE:IsModified(activeSnippetId, tab.editBox:GetText()) then
                    tab:SaveCurrentSnippet()
                end
            end
        end)
    end

    local function stopAutoSaveTicker()
        if autoSaveTicker then autoSaveTicker:Cancel(); autoSaveTicker = nil end
    end

    autoSaveBtn:SetScript("OnClick", function()
        local edb = getDB()
        if not edb then return end
        if edb.autoSaveInterval then
            edb.autoSaveInterval = nil
            stopAutoSaveTicker()
        else
            edb.autoSaveInterval = 5
            startAutoSaveTicker()
        end
        refreshAutoSaveLayout()
    end)
    autoSaveBtn:HookScript("OnLeave", function() refreshAutoSaveLayout() end)
    autoSaveBtn:HookScript("OnEnter", function(self)
        local edb = getDB()
        if edb and edb.autoSaveInterval then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            self.text:SetTextColor(1, 1, 1)
        end
    end)

    local function clampAutoSaveInterval()
        local edb = getDB()
        if not edb or not edb.autoSaveInterval then return end
        local val = tonumber(autoSaveBox:GetText()) or 5
        if val < 1 then val = 1 end
        if val > 60 then val = 60 end
        edb.autoSaveInterval = val
        autoSaveBox:SetText(tostring(val))
        stopAutoSaveTicker()
        startAutoSaveTicker()
    end

    autoSaveBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); clampAutoSaveInterval() end)
    autoSaveBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    autoSaveBox:HookScript("OnEditFocusLost", clampAutoSaveInterval)

    local codeOptsBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["EDITOR_BTN_CODE_OPTIONS"], height = btnHeight })
    codeOptsBtn:SetPoint("RIGHT", autoSaveBtn, "LEFT", -sectionGap, 0)
    codeOptsBtn:SetScript("OnClick", function(self, button)
        if button ~= "LeftButton" then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            local indentSub = root:CreateButton(L["EDITOR_LABEL_INDENT"], noop)
            for _, size in ipairs({2, 3, 4}) do
                indentSub:CreateRadio(tostring(size),
                    function() return getIndentSize() == size end,
                    function()
                        local edb = getDB()
                        if edb then edb.indentSize = size end
                        if ES and tab.editBox then
                            ES.setTabWidth(tab.editBox, size)
                            if activeSnippetId then
                                local code = tab.editBox:GetText()
                                if code and code ~= "" then
                                    local reformatted = ES.indentCode(code, size)
                                    tab.editBox:SetText(reformatted)
                                    if ES then ES.forceDirty(tab.editBox) end
                                    updateGutter()
                                end
                                EE:SetSnippetIndent(activeSnippetId, size)
                            end
                        end
                    end)
            end
            local sizeSub = root:CreateButton(L["EDITOR_LABEL_FONT_SIZE"], noop)
            for _, sz in ipairs({10, 12, 14, 16, 18}) do
                sizeSub:CreateRadio(tostring(sz),
                    function() return getFontSize() == sz end,
                    function()
                        local edb = getDB()
                        if edb then edb.fontSize = sz end
                        if updateFontSize then updateFontSize(sz) end
                    end)
            end
        end)
    end)

    local statusBar = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    statusBar:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    statusBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    statusBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    statusBar:SetHeight(STATUS_BAR_H)
    statusBar:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 5, 5)
    statusBar:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)

    local statusMsgFS = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusMsgFS:SetPoint("LEFT", statusBar, "LEFT", 6, 0)
    statusMsgFS:SetJustifyH("LEFT")
    statusMsgFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local lnColFS = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lnColFS:SetPoint("RIGHT", statusBar, "RIGHT", -6, 0)
    lnColFS:SetJustifyH("RIGHT")
    lnColFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local syntaxErrFS = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    syntaxErrFS:SetPoint("LEFT", statusMsgFS, "RIGHT", 12, 0)
    syntaxErrFS:SetPoint("RIGHT", lnColFS, "LEFT", -12, 0)
    syntaxErrFS:SetJustifyH("LEFT")
    syntaxErrFS:SetWordWrap(false)
    syntaxErrFS:SetTextColor(1, 0.3, 0.3, 1)

    local leftPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = LEFT_DEFAULT, height = 100 })
    leftPanel:ClearAllPoints()
    leftPanel:SetPoint("TOPLEFT", newBtn, "BOTTOMLEFT", 0, -4)
    leftPanel:SetPoint("BOTTOM", statusBar, "TOP", 0, 0)
    local db = getDB()
    leftPanel:SetWidth(db and db.leftPaneWidth or LEFT_DEFAULT)
    self:StyleContentPanel(leftPanel)

    local newCatBtn = OneWoW_GUI:CreateFitTextButton(leftPanel, { text = L["EDITOR_BTN_NEW_CATEGORY"], height = 18 })
    newCatBtn:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 4, -3)

    local helpBtn = OneWoW_GUI:CreateFitTextButton(leftPanel, { text = "?", height = 18, minWidth = 24 })
    helpBtn:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -22, -3)
    helpBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["EDITOR_SHORTCUTS_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["EDITOR_SHORTCUT_SAVE"], nil, nil, nil, true)
        GameTooltip:AddLine(L["EDITOR_SHORTCUT_UNDO"], nil, nil, nil, true)
        GameTooltip:AddLine(L["EDITOR_SHORTCUT_REDO"], nil, nil, nil, true)
        GameTooltip:AddLine(L["EDITOR_SHORTCUT_FIND"], nil, nil, nil, true)
        GameTooltip:AddLine(L["EDITOR_SHORTCUT_RUN"], nil, nil, nil, true)
        GameTooltip:AddLine(L["EDITOR_SHORTCUT_INDENT"], nil, nil, nil, true)
        GameTooltip:AddLine(L["EDITOR_SHORTCUT_CLOSE_FIND"], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    helpBtn:SetScript("OnLeave", GameTooltip_Hide)

    local leftScroll, leftContent = OneWoW_GUI:CreateScrollFrame(leftPanel, {})
    leftScroll:ClearAllPoints()
    leftScroll:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 4, -24)
    leftScroll:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -20, 4)
    leftScroll:HookScript("OnSizeChanged", function(self, w) leftContent:SetWidth(w) end)

    local rightPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    self:StyleContentPanel(rightPanel)

    OneWoW_GUI:CreateVerticalPaneResizer({
        parent = tab,
        leftPanel = leftPanel,
        rightPanel = rightPanel,
        dividerWidth = DIVIDER_W,
        leftMinWidth = LEFT_MIN,
        rightMinWidth = RIGHT_MIN,
        bottomOuterInset = STATUS_BAR_H + 5,
        rightOuterInset = 5,
        onWidthChanged = function(w)
            local edb = getDB()
            if edb then edb.leftPaneWidth = w end
        end,
    })

    local editorPanel = CreateFrame("Frame", nil, rightPanel)
    editorPanel:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 0, 0)
    editorPanel:SetPoint("RIGHT", rightPanel, "RIGHT", 0, 0)
    local savedOutputH = db and db.outputHeight
    editorPanel:SetHeight(EDITOR_MIN_H)

    local initialLayoutDone = false
    rightPanel:HookScript("OnSizeChanged", function(self, w, h)
        if initialLayoutDone or not h or h < 1 then return end
        initialLayoutDone = true
        local outputH = savedOutputH or OUTPUT_DEFAULT_H
        if outputH < OUTPUT_MIN_H then outputH = OUTPUT_MIN_H end
        local topH = max(EDITOR_MIN_H, h - outputH - 6)
        editorPanel:SetHeight(topH)
    end)

    local outputPanel = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    outputPanel:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    outputPanel:SetBackdropColor(unpack(MONOKAI_BG))
    outputPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    OneWoW_GUI:CreateHorizontalPaneResizer({
        parent = rightPanel,
        topPanel = editorPanel,
        bottomPanel = outputPanel,
        dividerHeight = 6,
        topMinHeight = EDITOR_MIN_H,
        bottomMinHeight = OUTPUT_MIN_H,
        onHeightChanged = function(h)
            local edb = getDB()
            if edb then edb.outputHeight = h end
        end,
    })

    local findBar = CreateFrame("Frame", nil, editorPanel, "BackdropTemplate")
    findBar:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    findBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    findBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    findBar:SetHeight(28)
    findBar:SetPoint("TOPLEFT", editorPanel, "TOPLEFT", 0, 0)
    findBar:SetPoint("RIGHT", editorPanel, "RIGHT", 0, 0)
    findBar:Hide()

    local findBox = OneWoW_GUI:CreateEditBox(findBar, { width = 150, height = 22, placeholderText = L["EDITOR_FIND_PLACEHOLDER"] })
    findBox:SetPoint("LEFT", findBar, "LEFT", 4, 0)

    local findNextBtn = OneWoW_GUI:CreateFitTextButton(findBar, { text = L["EDITOR_BTN_NEXT"], height = 22 })
    findNextBtn:SetPoint("LEFT", findBox, "RIGHT", 2, 0)

    local findPrevBtn = OneWoW_GUI:CreateFitTextButton(findBar, { text = L["EDITOR_BTN_PREV"], height = 22 })
    findPrevBtn:SetPoint("LEFT", findNextBtn, "RIGHT", 2, 0)

    local replaceBox = OneWoW_GUI:CreateEditBox(findBar, { width = 120, height = 22, placeholderText = L["EDITOR_REPLACE_PLACEHOLDER"] })
    replaceBox:SetPoint("LEFT", findPrevBtn, "RIGHT", 6, 0)

    local replaceBtn = OneWoW_GUI:CreateFitTextButton(findBar, { text = L["EDITOR_BTN_REPLACE"], height = 22 })
    replaceBtn:SetPoint("LEFT", replaceBox, "RIGHT", 2, 0)

    local replaceAllBtn = OneWoW_GUI:CreateFitTextButton(findBar, { text = L["EDITOR_BTN_REPLACE_ALL"], height = 22 })
    replaceAllBtn:SetPoint("LEFT", replaceBtn, "RIGHT", 2, 0)

    local findCloseBtn = OneWoW_GUI:CreateFitTextButton(findBar, { text = "X", height = 22, minWidth = 22 })
    findCloseBtn:SetPoint("RIGHT", findBar, "RIGHT", -2, 0)

    local gutterFrame = CreateFrame("Frame", nil, editorPanel, "BackdropTemplate")
    gutterFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    gutterFrame:SetBackdropColor(unpack(GUTTER_BG))
    gutterFrame:SetBackdropBorderColor(unpack(GUTTER_BG))
    gutterFrame:SetClipsChildren(true)
    gutterFrame:SetWidth(GUTTER_MIN_W)
    gutterFrame:SetPoint("TOPLEFT", editorPanel, "TOPLEFT", 0, 0)
    gutterFrame:SetPoint("BOTTOM", editorPanel, "BOTTOM", 0, 0)

    local gutterFS = gutterFrame:CreateFontString(nil, "OVERLAY")
    local monoFont = getFont()
    local fontSize = getFontSize()
    gutterFS:SetFont(monoFont, fontSize, "")
    gutterFS:SetJustifyH("LEFT")
    gutterFS:SetJustifyV("TOP")
    gutterFS:SetTextColor(0.52, 0.52, 0.46, 1)
    gutterFS:SetPoint("TOPRIGHT", gutterFrame, "TOPRIGHT", -4, -8)
    gutterFS:SetPoint("BOTTOMLEFT", gutterFrame, "BOTTOMLEFT", 2, 4)

    local editorBg = CreateFrame("Frame", nil, editorPanel, "BackdropTemplate")
    editorBg:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    editorBg:SetBackdropColor(unpack(MONOKAI_BG))
    editorBg:SetBackdropBorderColor(unpack(MONOKAI_BG))
    editorBg:SetPoint("TOPLEFT", gutterFrame, "TOPRIGHT", 0, 0)
    editorBg:SetPoint("BOTTOMRIGHT", editorPanel, "BOTTOMRIGHT", 0, 0)

    local scrollFrame = CreateFrame("ScrollFrame", nil, editorBg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", editorBg, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", editorBg, "BOTTOMRIGHT", -22, 4)
    scrollFrame:EnableMouse(true)
    scrollFrame:EnableMouseWheel(true)
    OneWoW_GUI:ApplyScrollBarStyle(scrollFrame.ScrollBar, editorBg, -2)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:SetHeight(1)
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:SetFont(monoFont, fontSize, "")
    editBox:SetTextColor(0.97, 0.97, 0.95, 1)
    scrollFrame:SetScrollChild(editBox)
    tab.editBox = editBox

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        editBox:SetWidth(max(1, w))
    end)
    scrollFrame:HookScript("OnMouseDown", function()
        editBox:SetFocus()
    end)

    local function updateFindBarLayout()
        gutterFrame:ClearAllPoints()
        gutterFrame:SetPoint("BOTTOM", editorPanel, "BOTTOM", 0, 0)
        if findBarVisible then
            findBar:Show()
            gutterFrame:SetPoint("TOPLEFT", findBar, "BOTTOMLEFT", 0, 0)
        else
            findBar:Hide()
            gutterFrame:SetPoint("TOPLEFT", editorPanel, "TOPLEFT", 0, 0)
        end
        editorBg:ClearAllPoints()
        editorBg:SetPoint("TOPLEFT", gutterFrame, "TOPRIGHT", 0, 0)
        editorBg:SetPoint("BOTTOMRIGHT", editorPanel, "BOTTOMRIGHT", 0, 0)
    end

    local noSnippetMsg = editorPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noSnippetMsg:SetPoint("CENTER", editorBg, "CENTER", 0, 0)
    noSnippetMsg:SetText(L["EDITOR_MSG_NO_SNIPPET"])
    noSnippetMsg:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local clearOutputBtn = OneWoW_GUI:CreateFitTextButton(outputPanel, { text = L["EDITOR_BTN_CLEAR_OUTPUT"], height = 18 })
    clearOutputBtn:SetPoint("TOPRIGHT", outputPanel, "TOPRIGHT", -4, -2)

    local copyOutputBtn = OneWoW_GUI:CreateFitTextButton(outputPanel, { text = L["EDITOR_BTN_COPY_OUTPUT"], height = 18 })
    copyOutputBtn:SetPoint("RIGHT", clearOutputBtn, "LEFT", -4, 0)

    local outputLabel = outputPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    outputLabel:SetPoint("TOPLEFT", outputPanel, "TOPLEFT", 6, -4)
    outputLabel:SetText(L["EDITOR_LABEL_OUTPUT"])
    outputLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local outputScroll = CreateFrame("ScrollingMessageFrame", nil, outputPanel)
    outputScroll:SetPoint("TOPLEFT", outputPanel, "TOPLEFT", 6, -22)
    outputScroll:SetPoint("BOTTOMRIGHT", outputPanel, "BOTTOMRIGHT", -6, 24)
    outputScroll:SetFont(monoFont, fontSize, "")
    outputScroll:SetTextColor(0.6, 0.6, 0.6, 1)
    outputScroll:SetJustifyH("LEFT")
    outputScroll:SetMaxLines(500)
    outputScroll:SetFading(false)
    outputScroll:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM)
    outputScroll:EnableMouseWheel(true)
    outputScroll:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp()
        else self:ScrollDown() end
    end)

    local commandBox = OneWoW_GUI:CreateEditBox(outputPanel, {
        width = 100,
        height = 20,
        placeholderText = L["EDITOR_PROMPT_COMMAND"],
    })
    commandBox:SetPoint("BOTTOMLEFT", outputPanel, "BOTTOMLEFT", 4, 2)
    commandBox:SetPoint("BOTTOMRIGHT", outputPanel, "BOTTOMRIGHT", -4, 2)

    local outputBuffer = {}

    clearOutputBtn:SetScript("OnClick", function()
        outputScroll:Clear()
        wipe(outputBuffer)
    end)

    copyOutputBtn:SetScript("OnClick", function()
        if #outputBuffer == 0 then return end
        Addon:CopyToClipboard(table.concat(outputBuffer, "\n"), L["EDITOR_LABEL_OUTPUT"])
    end)

    local function addOutput(msg, msgType)
        if not msg then return end
        tinsert(outputBuffer, tostring(msg))
        local color
        if msgType == "error" then
            color = "|cFFFF0000"
        elseif msgType == "success" then
            color = "|cFF00FF00"
        else
            color = "|cFF999999"
        end
        outputScroll:AddMessage(color .. tostring(msg) .. "|r")
    end

    EE:SetOutputHandler(addOutput)

    updateFontSize = function(sz)
        local font = getFont()
        editBox:SetFont(font, sz, "")
        gutterFS:SetFont(font, sz, "")
        outputScroll:SetFont(font, sz, "")
    end

    updateStatusMessage = function(msg)
        if statusClearTimer then
            statusClearTimer:Cancel()
            statusClearTimer = nil
        end
        statusMsgFS:SetText(msg or "")
        if msg and msg ~= "" then
            statusClearTimer = C_Timer.NewTimer(STATUS_CLEAR_DELAY, function()
                statusMsgFS:SetText("")
                statusClearTimer = nil
            end)
        end
    end

    local function restorePlainCursor(plainCursor)
        if plainCursor < 0 then
            plainCursor = 0
        end
        local rawCursor = plainCursor
        if ES and ES.plainRangeToRaw then
            local _, mappedCursor = ES.plainRangeToRaw(editBox, plainCursor, plainCursor)
            rawCursor = mappedCursor
        end
        editBox:SetCursorPosition(rawCursor)
        updateLnCol()
    end

    local function highlightPlainRange(plainStart, plainEnd)
        editBox:SetFocus()
        if plainEnd < plainStart then
            local plainCursor = plainStart - 1
            if plainCursor < 0 then
                plainCursor = 0
            end
            restorePlainCursor(plainCursor)
            editBox:HighlightText(editBox:GetCursorPosition(), editBox:GetCursorPosition())
            return
        end
        local rawStart, rawEnd
        if ES then
            rawStart, rawEnd = ES.plainRangeToRaw(editBox, plainStart - 1, plainEnd)
        else
            rawStart, rawEnd = plainStart - 1, plainEnd
        end
        editBox:SetCursorPosition(rawEnd)
        editBox:HighlightText(rawStart, rawEnd)
    end

    local function queueUndoSnapshot(snippetId, text)
        if not snippetId or not text then return end

        local now = GetTime()
        if now - lastUndoTime >= UNDO_DEBOUNCE then
            EE:QueueUndo(snippetId, text)
            lastUndoTime = now
            clearPendingUndo()
            return
        end

        pendingUndoText = text
        if pendingUndoTimer then
            pendingUndoTimer:Cancel()
        end

        pendingUndoTimer = C_Timer.NewTimer(UNDO_DEBOUNCE, function()
            pendingUndoTimer = nil
            if activeSnippetId ~= snippetId or not pendingUndoText then
                pendingUndoText = nil
                return
            end
            EE:QueueUndo(snippetId, pendingUndoText)
            pendingUndoText = nil
            lastUndoTime = GetTime()
        end)
    end

    updateLnCol = function()
        if not activeSnippetId then
            lnColFS:SetText("")
            return
        end
        local plainPos = ES and ES.getPlainCursorPos(editBox) or editBox:GetCursorPosition()
        local text = editBox:GetText()
        local line = 1
        local col = plainPos + 1
        local pos = 0
        for lineText in text:gmatch("([^\n]*)\n") do
            local lineEnd = pos + #lineText + 1
            if plainPos < lineEnd then
                col = plainPos - pos + 1
                break
            end
            pos = lineEnd
            line = line + 1
        end
        if pos <= plainPos then
            col = plainPos - pos + 1
        end
        lnColFS:SetText(format(L["EDITOR_STATUS_LN_COL"], line, col))
    end

    local function doSyntaxCheck()
        if not activeSnippetId then
            syntaxErrFS:SetText("")
            return
        end
        local text = editBox:GetText()
        if text == lastCheckedText then return end
        lastCheckedText = text
        local fn, err = loadstring(text, "syntax_check")
        if fn then
            syntaxErrFS:SetText("")
            if errorLine then
                errorLine = nil
                updateGutter()
            end
        else
            local msg = err or ""
            msg = msg:gsub("^%[string \"syntax_check\"%]:", "")
            syntaxErrFS:SetText(msg)
        end
    end

    local function resetSyntaxCheck()
        syntaxErrFS:SetText("")
        lastCheckedText = nil
        syntaxCheckDirty = false
        if syntaxCheckTimer then
            syntaxCheckTimer:Cancel()
            syntaxCheckTimer = nil
        end
    end

    local function scheduleSyntaxCheck()
        syntaxCheckDirty = true
        if syntaxCheckTimer then
            syntaxCheckTimer:Cancel()
        end
        syntaxCheckTimer = C_Timer.NewTimer(SYNTAX_CHECK_DEBOUNCE, function()
            syntaxCheckTimer = nil
            if syntaxCheckDirty then
                syntaxCheckDirty = false
                doSyntaxCheck()
            end
        end)
    end

    local errorLine = nil

    updateGutter = function()
        if not tab.editBox then return end
        local text = ES and ES.getPlainTextForSearch(editBox) or editBox:GetText()
        local lines = {}
        local count = 1
        local gutterColor = D and D.MONOKAI and D.MONOKAI.GUTTER_TEXT or "858575"
        local errColor = D and D.MONOKAI and D.MONOKAI.ERROR_LINE or "FF1111"

        for line in text:gmatch("([^\n]*)\n") do
            if count == errorLine then
                tinsert(lines, "|cFF" .. errColor .. count .. "|r")
            else
                tinsert(lines, "|cFF" .. gutterColor .. count .. "|r")
            end
            count = count + 1
        end

        if count == errorLine then
            tinsert(lines, "|cFF" .. errColor .. count .. "|r")
        else
            tinsert(lines, "|cFF" .. gutterColor .. count .. "|r")
        end

        gutterFS:SetText(table.concat(lines, "\n"))

        local numDigits = max(2, #tostring(count))
        local gutterW = max(GUTTER_MIN_W, numDigits * 8 + 12)
        gutterFrame:SetWidth(gutterW)
    end

    local function syncGutterScroll()
        local offset = scrollFrame:GetVerticalScroll()
        gutterFS:ClearAllPoints()
        gutterFS:SetPoint("TOPRIGHT", gutterFrame, "TOPRIGHT", -4, -8 + offset)
        gutterFS:SetPoint("LEFT", gutterFrame, "LEFT", 2, 0)
    end

    scrollFrame:HookScript("OnVerticalScroll", function()
        syncGutterScroll()
    end)

    editBox:SetScript("OnCursorChanged", function(self, x, y, w, h)
        ScrollingEdit_OnCursorChanged(self, x, y, w, h)
        updateGutter()
        updateLnCol()
    end)

    editBox:HookScript("OnUpdate", function(self, elapsed)
        ScrollingEdit_OnUpdate(self, elapsed, scrollFrame)
    end)

    editBox:SetScript("OnTextSet", function()
        updateGutter()
    end)

    local function acquireCategoryHeader()
        activeCategoryHeaderCount = activeCategoryHeaderCount + 1
        local header = categoryHeaders[activeCategoryHeaderCount]
        if header then
            header:Show()
            return header
        end

        header = CreateFrame("Button", nil, leftContent, "BackdropTemplate")
        header:SetHeight(CATEGORY_ROW_H)
        header:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        header:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        header:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        header.arrow = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header.arrow:SetPoint("LEFT", header, "LEFT", 4, 0)
        header.arrow:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        header.catLabel = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header.catLabel:SetPoint("LEFT", header.arrow, "RIGHT", 4, 0)
        header.catLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        header.snippetCount = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header.snippetCount:SetPoint("RIGHT", header, "RIGHT", -6, 0)
        header.snippetCount:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        header:SetScript("OnClick", function(self)
            local edb = getDB()
            if not edb then return end
            edb.categoryCollapsed[self.catName] = not edb.categoryCollapsed[self.catName]
            refreshSnippetList()
        end)

        header:SetScript("OnMouseDown", function(self, button)
            if button ~= "RightButton" or self.catName == getDefaultCategoryName() then return end
            MenuUtil.CreateContextMenu(self, function(_, root)
                root:CreateButton(L["EDITOR_CTX_RENAME_CATEGORY"], function()
                    tab:ShowCategoryRenameDialog(self.catName)
                end)
                root:CreateButton(L["EDITOR_CTX_DELETE_CATEGORY"], function()
                    tab:ShowCategoryDeleteConfirm(self.catName)
                end)
            end)
        end)

        categoryHeaders[activeCategoryHeaderCount] = header
        return header
    end

    local function acquireSnippetRow()
        activeSnippetRowCount = activeSnippetRowCount + 1
        local row = snippetRows[activeSnippetRowCount]
        if row then
            row:Show()
            return row
        end

        row = CreateFrame("Button", nil, leftContent, "BackdropTemplate")
        row:SetHeight(SNIPPET_ROW_H)
        row:SetBackdrop(BACKDROP_INNER_NO_INSETS)

        row.indicator = row:CreateTexture(nil, "ARTWORK")
        row.indicator:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.indicator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row.indicator:SetWidth(12)

        row.rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.rowLabel:SetPoint("LEFT", row, "LEFT", 18, 0)
        row.rowLabel:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.rowLabel:SetJustifyH("LEFT")
        row.rowLabel:SetWordWrap(false)

        row:SetScript("OnClick", function(self)
            tab:SwitchToSnippet(self.snippetId)
        end)

        row:SetScript("OnMouseDown", function(self, button)
            if button ~= "RightButton" then return end
            local snippet = EE:GetSnippet(self.snippetId)
            if not snippet then return end
            MenuUtil.CreateContextMenu(self, function(_, root)
                root:CreateButton(L["EDITOR_CTX_RENAME"], function()
                    tab:ShowRenameDialog(self.snippetId)
                end)
                root:CreateButton(L["EDITOR_CTX_DUPLICATE"], function()
                    local newId = EE:DuplicateSnippet(self.snippetId)
                    if newId then
                        local duplicatedSnippet = EE:GetSnippet(newId)
                        updateStatusMessage(format(L["EDITOR_STATUS_SNIPPET_DUPLICATED"], duplicatedSnippet and duplicatedSnippet.name or ""))
                        refreshSnippetList()
                        tab:SwitchToSnippet(newId, true)
                    end
                end)
                local moveSub = root:CreateButton(L["EDITOR_CTX_MOVE_TO"], noop)
                for _, cat in ipairs(EE:GetCategories()) do
                    if cat ~= snippet.category then
                        moveSub:CreateButton(cat, function()
                            if EE:MoveSnippet(self.snippetId, cat) then
                                refreshSnippetList()
                            else
                                updateStatusMessage(format(L["EDITOR_ERROR_SNIPPET_MOVE_EXISTS"], cat))
                            end
                        end)
                    end
                end
                root:CreateButton(L["EDITOR_CTX_DELETE"], function()
                    tab:ShowDeleteConfirm(self.snippetId)
                end)
            end)
        end)

        row:SetScript("OnEnter", function(self)
            if self.snippetId ~= activeSnippetId then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            end
        end)
        row:SetScript("OnLeave", function(self)
            if self.snippetId ~= activeSnippetId then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            end
        end)

        snippetRows[activeSnippetRowCount] = row
        return row
    end

    refreshSnippetList = function()
        for i = 1, activeSnippetRowCount do
            snippetRows[i]:Hide()
        end
        for i = 1, activeCategoryHeaderCount do
            categoryHeaders[i]:Hide()
        end
        activeSnippetRowCount = 0
        activeCategoryHeaderCount = 0

        local edb = getDB()
        if not edb then return end
        local categories = EE:GetCategories()
        local yOff = 0

        for _, catName in ipairs(categories) do
            local collapsed = edb.categoryCollapsed[catName]
            local header = acquireCategoryHeader()
            header:SetPoint("TOPLEFT", leftContent, "TOPLEFT", 0, -yOff)
            header:SetPoint("RIGHT", leftContent, "RIGHT", 0, 0)
            header.catName = catName
            header.arrow:SetText(collapsed and "+" or "-")
            header.catLabel:SetText(catName)

            local snippets = EE:GetSnippetsByCategory(catName)
            header.snippetCount:SetText("(" .. #snippets .. ")")
            yOff = yOff + CATEGORY_ROW_H

            if not collapsed then
                for _, snippet in ipairs(snippets) do
                    local row = acquireSnippetRow()
                    row:SetPoint("TOPLEFT", leftContent, "TOPLEFT", 0, -yOff)
                    row:SetPoint("RIGHT", leftContent, "RIGHT", 0, 0)

                    local isActive = snippet.id == activeSnippetId
                    local isModified = EE:IsModified(snippet.id, snippet.id == activeSnippetId and editBox:GetText() or snippet.code)
                    if isActive then
                        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    else
                        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                    end

                    if isModified then
                        row.indicator:SetColorTexture(0.8, 0.2, 0.2, 0.9)
                    else
                        local r, g, b, a = OneWoW_GUI:GetThemeColor(isActive and "ACCENT_PRIMARY" or "BG_SECONDARY")
                        row.indicator:SetColorTexture(r, g, b, a)
                    end

                    row.snippetId = snippet.id
                    row.rowLabel:SetText(snippet.name or "?")

                    if isActive then
                        row.rowLabel:SetTextColor(1, 1, 1, 1)
                    else
                        row.rowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                    end
                    yOff = yOff + SNIPPET_ROW_H
                end
            end
        end

        leftContent:SetHeight(max(1, yOff))
    end

    local function loadSnippetIntoEditor(id)
        local snippet = EE:GetSnippet(id)
        if not snippet then return end

        activeSnippetId = id
        EE:InitSavedSnapshot(id)

        local code = snippet.code or ""
        local currentIndent = getIndentSize()

        clearPendingUndo()
        editBox:SetText(code)
        EE:ClearUndo(id)
        EE:QueueUndo(id, code)
        lastUndoTime = GetTime()
        errorLine = nil
        resetSyntaxCheck()

        noSnippetMsg:Hide()
        editBox:Show()
        scrollFrame:Show()
        gutterFrame:Show()

        if ES and ES.isEnabled and not ES.isEnabled(editBox) then
            ES.enable(editBox, currentIndent)
        end
        if ES then
            ES.setTabWidth(editBox, currentIndent)
            ES.forceDirty(editBox)
        end

        updateGutter()
        refreshSnippetList()
        scrollFrame:SetVerticalScroll(0)
        editBox:SetCursorPosition(0)
        editBox:HighlightText(0, 0)
        editBox:SetFocus()

        local edb = getDB()
        if edb then edb.lastOpenSnippet = id end
    end

    function tab:SwitchToSnippet(id, skipUnsavedCheck)
        if id == activeSnippetId then return end

        if not skipUnsavedCheck and activeSnippetId then
            local currentText = editBox:GetText()
            if EE:IsModified(activeSnippetId, currentText) then
                self:ShowUnsavedDialog(function()
                    EE:SaveSnippet(activeSnippetId, currentText)
                    loadSnippetIntoEditor(id)
                end, function()
                    loadSnippetIntoEditor(id)
                end)
                return
            end
        end

        loadSnippetIntoEditor(id)
    end

    function tab:SaveCurrentSnippet()
        if not activeSnippetId then return end
        local snippet = EE:GetSnippet(activeSnippetId)
        if not snippet then return end

        if snippet.untitled then
            self:ShowRenameDialog(activeSnippetId, function()
                local s = EE:GetSnippet(activeSnippetId)
                local text = editBox:GetText()
                local trimmed = (text or ""):gsub("\n+$", "\n")
                if text ~= trimmed then
                    editBox:SetText(trimmed)
                    if ES then ES.forceDirty(editBox) end
                    updateGutter()
                end
                EE:SaveSnippet(activeSnippetId, trimmed)
                doSyntaxCheck()
                updateStatusMessage(format(L["EDITOR_STATUS_SAVED"], s and s.name or ""))
                refreshSnippetList()
            end)
            return
        end

        local text = editBox:GetText()
        local trimmed = (text or ""):gsub("\n+$", "\n")
        if text ~= trimmed then
            editBox:SetText(trimmed)
            if ES then ES.forceDirty(editBox) end
            updateGutter()
        end
        EE:SaveSnippet(activeSnippetId, trimmed)
        doSyntaxCheck()
        updateStatusMessage(format(L["EDITOR_STATUS_SAVED"], snippet.name))
        refreshSnippetList()
    end

    function tab:RunCurrentSnippet()
        if not activeSnippetId then return end
        errorLine = nil
        local text = editBox:GetText()
        local snippet = EE:GetSnippet(activeSnippetId)
        local name = snippet and snippet.name or "editor"
        local ok, _, errLineNum = EE:RunSnippet(text, name)
        if ok then
            updateStatusMessage(format(L["EDITOR_STATUS_RUN_COMPLETED"], name))
        else
            errorLine = errLineNum
        end
        updateGutter()
    end

    local function trackDialog(dialog)
        activeDialog = dialog.frame
        dialog.frame:HookScript("OnHide", function()
            if activeDialog == dialog.frame then activeDialog = nil end
        end)
    end

    local function dismissActiveDialog()
        if activeDialog then activeDialog:Hide(); activeDialog = nil end
    end

    function tab:ShowUnsavedDialog(onSave, onDiscard)
        local dialog = OneWoW_GUI:CreateConfirmDialog({
            title = L["EDITOR_UNSAVED_TITLE"],
            message = L["EDITOR_UNSAVED_MESSAGE"],
            buttons = {
                { text = L["EDITOR_BTN_SAVE_CHANGES"], onClick = function(d) d:Hide(); if onSave then onSave() end end },
                { text = L["EDITOR_BTN_DISCARD"], onClick = function(d) d:Hide(); if onDiscard then onDiscard() end end },
                { text = L["EDITOR_BTN_CANCEL"], onClick = function(d) d:Hide() end },
            },
        })
        trackDialog(dialog)
        dialog.frame:Show()
    end

    function tab:ShowRenameDialog(snippetId, afterRename)
        local snippet = EE:GetSnippet(snippetId)
        if not snippet then return end

        local dialog
        dialog = OneWoW_GUI:CreateConfirmDialog({
            title = L["EDITOR_RENAME_TITLE"],
            message = "",
            buttons = {
                { text = L["EDITOR_BTN_SAVE"], onClick = function(d)
                    local box = dialog and dialog.renameBox
                    local err, newName = getSnippetRenameError(snippetId, box and box:GetText())
                    if not err and newName ~= (box and box.placeholderText or "") then
                        setDialogError(dialog, "")
                        d:Hide()
                        EE:RenameSnippet(snippetId, newName)
                        updateStatusMessage(format(L["EDITOR_STATUS_RENAMED"], newName))
                        refreshSnippetList()
                        if afterRename then afterRename() end
                    elseif box then
                        setDialogError(dialog, err)
                        box:SetFocus()
                    end
                end },
                { text = L["EDITOR_BTN_CANCEL"], onClick = function(d) d:Hide() end },
            },
        })

        local renameBox = OneWoW_GUI:CreateEditBox(dialog.contentFrame, {
            width = 250,
            height = 24,
            placeholderText = L["EDITOR_RENAME_PLACEHOLDER"],
        })
        renameBox:SetPoint("TOP", dialog.titleLabel, "BOTTOM", 0, -16)
        renameBox:SetText(snippet.name or "")
        renameBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        renameBox:SetFocus()
        dialog.renameBox = renameBox
        createDialogErrorLabel(dialog, renameBox)

        renameBox:SetScript("OnTextChanged", function()
            setDialogError(dialog, "")
        end)

        renameBox:SetScript("OnEnterPressed", function(self)
            local err, newName = getSnippetRenameError(snippetId, self:GetText())
            if not err and newName ~= (self.placeholderText or "") then
                setDialogError(dialog, "")
                EE:RenameSnippet(snippetId, newName)
                updateStatusMessage(format(L["EDITOR_STATUS_RENAMED"], newName))
                refreshSnippetList()
                if afterRename then afterRename() end
                dialog.frame:Hide()
            else
                setDialogError(dialog, err)
                self:SetFocus()
            end
        end)

        trackDialog(dialog)
        dialog.frame:Show()
    end

    function tab:ShowCategoryRenameDialog(catName)
        local dialog
        dialog = OneWoW_GUI:CreateConfirmDialog({
            title = L["EDITOR_CATEGORY_RENAME_TITLE"],
            message = "",
            buttons = {
                { text = L["EDITOR_BTN_SAVE"], onClick = function(d)
                    local box = dialog and dialog.renameBox
                    local err, newName = getCategoryNameError(catName, box and box:GetText())
                    if not err and newName ~= (box and box.placeholderText or "") and EE:RenameCategory(catName, newName) then
                        setDialogError(dialog, "")
                        d:Hide()
                        updateStatusMessage(format(L["EDITOR_STATUS_CATEGORY_RENAMED"], newName))
                        refreshSnippetList()
                    elseif box then
                        setDialogError(dialog, err or (L["EDITOR_ERROR_CATEGORY_NAME_EXISTS"]))
                        box:SetFocus()
                    end
                end },
                { text = L["EDITOR_BTN_CANCEL"], onClick = function(d) d:Hide() end },
            },
        })

        local renameBox = OneWoW_GUI:CreateEditBox(dialog.contentFrame, {
            width = 250,
            height = 24,
            placeholderText = L["EDITOR_CATEGORY_RENAME_PLACEHOLDER"],
        })
        renameBox:SetPoint("TOP", dialog.titleLabel, "BOTTOM", 0, -16)
        renameBox:SetText(catName or "")
        renameBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        renameBox:SetFocus()
        createDialogErrorLabel(dialog, renameBox)
        renameBox:SetScript("OnTextChanged", function()
            setDialogError(dialog, "")
        end)
        renameBox:SetScript("OnEnterPressed", function(self)
            local err, newName = getCategoryNameError(catName, self:GetText())
            if not err and newName ~= (self.placeholderText or "") and EE:RenameCategory(catName, newName) then
                setDialogError(dialog, "")
                updateStatusMessage(format(L["EDITOR_STATUS_CATEGORY_RENAMED"], newName))
                refreshSnippetList()
                dialog.frame:Hide()
            else
                setDialogError(dialog, err or (L["EDITOR_ERROR_CATEGORY_NAME_EXISTS"]))
                self:SetFocus()
            end
        end)
        dialog.renameBox = renameBox
        trackDialog(dialog)
        dialog.frame:Show()
    end

    function tab:ShowNewCategoryDialog()
        local dialog
        dialog = OneWoW_GUI:CreateConfirmDialog({
            title = L["EDITOR_NEW_CATEGORY_TITLE"],
            message = "",
            buttons = {
                { text = L["EDITOR_BTN_SAVE"], onClick = function(d)
                    local box = dialog and dialog.renameBox
                    local err, newName = getCategoryNameError(nil, box and box:GetText())
                    if not err and newName ~= (box and box.placeholderText or "") and EE:CreateCategory(newName) then
                        setDialogError(dialog, "")
                        d:Hide()
                        updateStatusMessage(format(L["EDITOR_STATUS_CATEGORY_CREATED"], newName))
                        refreshSnippetList()
                    elseif box then
                        setDialogError(dialog, err or (L["EDITOR_ERROR_CATEGORY_NAME_EXISTS"]))
                        box:SetFocus()
                    end
                end },
                { text = L["EDITOR_BTN_CANCEL"], onClick = function(d) d:Hide() end },
            },
        })

        local renameBox = OneWoW_GUI:CreateEditBox(dialog.contentFrame, {
            width = 250,
            height = 24,
            placeholderText = L["EDITOR_NEW_CATEGORY_PLACEHOLDER"],
        })
        renameBox:SetPoint("TOP", dialog.titleLabel, "BOTTOM", 0, -16)
        renameBox:SetFocus()
        createDialogErrorLabel(dialog, renameBox)
        renameBox:SetScript("OnTextChanged", function()
            setDialogError(dialog, "")
        end)
        renameBox:SetScript("OnEnterPressed", function(self)
            local err, newName = getCategoryNameError(nil, self:GetText())
            if not err and newName ~= (self.placeholderText or "") and EE:CreateCategory(newName) then
                setDialogError(dialog, "")
                updateStatusMessage(format(L["EDITOR_STATUS_CATEGORY_CREATED"], newName))
                refreshSnippetList()
                dialog.frame:Hide()
            else
                setDialogError(dialog, err or (L["EDITOR_ERROR_CATEGORY_NAME_EXISTS"]))
                self:SetFocus()
            end
        end)
        dialog.renameBox = renameBox
        trackDialog(dialog)
        dialog.frame:Show()
    end

    function tab:ShowDeleteConfirm(snippetId)
        local snippet = EE:GetSnippet(snippetId)
        if not snippet then return end
        local deleteName = snippet.name
        local dialog = OneWoW_GUI:CreateConfirmDialog({
            title = L["EDITOR_BTN_DELETE"],
            message = format(L["EDITOR_SNIPPET_DELETE_CONFIRM"], deleteName),
            buttons = {
                { text = L["EDITOR_BTN_DELETE"], onClick = function(d)
                    d:Hide()
                    EE:DeleteSnippet(snippetId)
                    if activeSnippetId == snippetId then
                        clearPendingUndo()
                        activeSnippetId = nil
                        editBox:SetText("")
                        editBox:Hide()
                        scrollFrame:Hide()
                        gutterFrame:Hide()
                        noSnippetMsg:Show()
                        resetSyntaxCheck()
                        lnColFS:SetText("")
                        local edb = getDB()
                        if edb then edb.lastOpenSnippet = nil end
                    end
                    updateStatusMessage(format(L["EDITOR_STATUS_DELETED"], deleteName))
                    refreshSnippetList()
                end },
                { text = L["EDITOR_BTN_CANCEL"], onClick = function(d) d:Hide() end },
            },
        })
        trackDialog(dialog)
        dialog.frame:Show()
    end

    function tab:ShowCategoryDeleteConfirm(catName)
        local dialog = OneWoW_GUI:CreateConfirmDialog({
            title = L["EDITOR_CTX_DELETE_CATEGORY"],
            message = format(L["EDITOR_CATEGORY_DELETE_CONFIRM"], catName),
            buttons = {
                { text = L["EDITOR_BTN_DELETE"], onClick = function(d)
                    d:Hide()
                    EE:DeleteCategory(catName)
                    updateStatusMessage(format(L["EDITOR_STATUS_CATEGORY_DELETED"], catName))
                    refreshSnippetList()
                end },
                { text = L["EDITOR_BTN_CANCEL"], onClick = function(d) d:Hide() end },
            },
        })
        trackDialog(dialog)
        dialog.frame:Show()
    end

    runBtn:SetScript("OnClick", function() tab:RunCurrentSnippet() end)

    saveBtn:SetScript("OnClick", function() tab:SaveCurrentSnippet() end)

    newBtn:SetScript("OnClick", function()
        local id = EE:CreateSnippet()
        if id then
            updateStatusMessage(L["EDITOR_STATUS_SNIPPET_CREATED"])
            refreshSnippetList()
            tab:SwitchToSnippet(id, true)
        end
    end)

    deleteBtn:SetScript("OnClick", function()
        if activeSnippetId then tab:ShowDeleteConfirm(activeSnippetId) end
    end)

    dupBtn:SetScript("OnClick", function()
        if not activeSnippetId then return end
        local newId = EE:DuplicateSnippet(activeSnippetId)
        if newId then
            local s = EE:GetSnippet(newId)
            updateStatusMessage(format(L["EDITOR_STATUS_SNIPPET_DUPLICATED"], s and s.name or ""))
            refreshSnippetList()
            tab:SwitchToSnippet(newId, true)
        end
    end)

    renameBtn:SetScript("OnClick", function()
        if activeSnippetId then tab:ShowRenameDialog(activeSnippetId) end
    end)

    findCloseBtn:SetScript("OnClick", function()
        findBarVisible = false
        updateFindBarLayout()
        editBox:SetFocus()
    end)

    findBox:SetScript("OnEscapePressed", function()
        findBarVisible = false
        updateFindBarLayout()
        editBox:SetFocus()
    end)
    replaceBox:SetScript("OnEscapePressed", function()
        findBarVisible = false
        updateFindBarLayout()
        editBox:SetFocus()
    end)

    local function getFindPattern()
        return findBox:GetSearchText()
    end

    local function getReplacePattern()
        return replaceBox:GetSearchText()
    end

    local function doFindNext()
        local pattern = getFindPattern()
        if not pattern or pattern == "" then return end
        local text = ES and ES.getPlainTextForSearch(editBox) or editBox:GetText()
        local cursorPos = ES and ES.getPlainCursorPos(editBox) or editBox:GetCursorPosition()
        local s, e = EE:FindNext(text, pattern, cursorPos + 1, true)
        if s then
            highlightPlainRange(s, e)
        else
            updateStatusMessage(L["EDITOR_NO_MATCH"])
        end
    end

    local function doFindPrev()
        local pattern = getFindPattern()
        if not pattern or pattern == "" then return end
        local text = ES and ES.getPlainTextForSearch(editBox) or editBox:GetText()
        local cursorPos = (ES and ES.getPlainCursorPos(editBox) or editBox:GetCursorPosition()) + 1
        local searchFrom = cursorPos
        local selectedStart = cursorPos - #pattern
        if selectedStart >= 1 and strsub(text, selectedStart, cursorPos - 1) == pattern then
            searchFrom = selectedStart
        end
        local s, e = EE:FindPrevious(text, pattern, searchFrom, true)
        if s then
            highlightPlainRange(s, e)
        else
            updateStatusMessage(L["EDITOR_NO_MATCH"])
        end
    end

    findNextBtn:SetScript("OnClick", doFindNext)
    findPrevBtn:SetScript("OnClick", doFindPrev)
    findBox:SetScript("OnEnterPressed", function() doFindNext() end)

    replaceBtn:SetScript("OnClick", function()
        if not activeSnippetId then return end
        local pattern = getFindPattern()
        local replacement = getReplacePattern()
        if not pattern or pattern == "" then return end
        local text = ES and ES.getPlainTextForSearch(editBox) or editBox:GetText()
        local cursorPos = (ES and ES.getPlainCursorPos(editBox) or editBox:GetCursorPosition()) + 1
        local searchFrom = cursorPos
        local selectedStart = cursorPos - #pattern
        if selectedStart >= 1 and strsub(text, selectedStart, cursorPos - 1) == pattern then
            searchFrom = selectedStart
        end
        local newText, replaced, replacedStart, replacedEnd = EE:ReplaceNext(text, pattern, replacement or "", searchFrom)
        if replaced then
            editBox:SetText(newText)
            if ES then ES.forceDirty(editBox) end
            updateGutter()
            updateLnCol()
            scheduleSyntaxCheck()
            highlightPlainRange(replacedStart, replacedEnd)
            local nextS, nextE = EE:FindNext(newText, pattern, replacedEnd + 1, true)
            if nextS then
                highlightPlainRange(nextS, nextE)
            else
                updateStatusMessage(L["EDITOR_NO_MATCH"])
            end
        else
            updateStatusMessage(L["EDITOR_NO_MATCH"])
        end
    end)

    replaceAllBtn:SetScript("OnClick", function()
        if not activeSnippetId then return end
        local pattern = getFindPattern()
        local replacement = getReplacePattern()
        if not pattern or pattern == "" then return end
        local text = ES and ES.getPlainTextForSearch(editBox) or editBox:GetText()
        local newText, count = EE:ReplaceAll(text, pattern, replacement or "")
        editBox:SetText(newText)
        if ES then ES.forceDirty(editBox) end
        updateGutter()
        updateLnCol()
        scheduleSyntaxCheck()
        refreshSnippetList()
        addOutput(format(L["EDITOR_REPLACE_COUNT"], count), "print")
    end)

    newCatBtn:SetScript("OnClick", function()
        tab:ShowNewCategoryDialog()
    end)

    commandBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetSearchText()
        if not text or text == "" then self:ClearFocus(); return end
        addOutput("> " .. text, "print")
        EE:RunCommand(text)
        self:SetText("")
        self:ClearFocus()
    end)

    editBox:HookScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        updateGutter()
        updateLnCol()
        scheduleSyntaxCheck()
        if activeSnippetId then
            queueUndoSnapshot(activeSnippetId, self:GetText())
            if refreshListTimer then refreshListTimer:Cancel() end
            refreshListTimer = C_Timer.NewTimer(COLORIZE_DEBOUNCE, function()
                refreshListTimer = nil
                if refreshSnippetList then refreshSnippetList() end
            end)
        end
    end)

    editBox:SetScript("OnKeyDown", function(self, key)
        if IsControlKeyDown() then
            if key == "S" then
                self:SetPropagateKeyboardInput(false)
                tab:SaveCurrentSnippet()
                return
            elseif key == "Z" then
                self:SetPropagateKeyboardInput(false)
                if activeSnippetId then
                    clearPendingUndo()
                    local plainCursor = ES and ES.getPlainCursorPos(self) or 0
                    local text = EE:Undo(activeSnippetId, self:GetText())
                    if text then
                        self:SetText(text)
                        if plainCursor > #text then plainCursor = #text end
                        restorePlainCursor(plainCursor)
                        if ES then ES.forceDirty(self) end
                        updateGutter()
                        scheduleSyntaxCheck()
                        refreshSnippetList()
                    end
                end
                return
            elseif key == "Y" then
                self:SetPropagateKeyboardInput(false)
                if activeSnippetId then
                    clearPendingUndo()
                    local plainCursor = ES and ES.getPlainCursorPos(self) or 0
                    local text = EE:Redo(activeSnippetId)
                    if text then
                        self:SetText(text)
                        if plainCursor > #text then plainCursor = #text end
                        restorePlainCursor(plainCursor)
                        if ES then ES.forceDirty(self) end
                        updateGutter()
                        scheduleSyntaxCheck()
                        refreshSnippetList()
                    end
                end
                return
            elseif key == "F" then
                self:SetPropagateKeyboardInput(false)
                if not findBarVisible then
                    findBarVisible = true
                    updateFindBarLayout()
                end
                findBox:SetFocus()
                return
            elseif key == "ENTER" then
                self:SetPropagateKeyboardInput(false)
                local savedText = self:GetText()
                local savedPos = self:GetCursorPosition()
                C_Timer.After(0, function()
                    editBox:SetText(savedText)
                    editBox:SetCursorPosition(savedPos)
                    if ES then ES.forceDirty(editBox) end
                    updateGutter()
                end)
                tab:RunCurrentSnippet()
                return
            end
        end
    end)

    editBox:HookScript("OnEscapePressed", function()
        if findBarVisible then
            findBarVisible = false
            updateFindBarLayout()
        end
    end)

    tab:SetScript("OnShow", function()
        loadAPIDocs()
        refreshAutoSaveLayout()
        local edb = getDB()
        if edb and edb.autoSaveInterval then startAutoSaveTicker() end
        refreshSnippetList()

        if not activeSnippetId then
            local lastId = edb and edb.lastOpenSnippet
            if lastId and EE:GetSnippet(lastId) then
                loadSnippetIntoEditor(lastId)
            else
                noSnippetMsg:Show()
                editBox:Hide()
                scrollFrame:Hide()
                gutterFrame:Hide()
                lnColFS:SetText("")
                syntaxErrFS:SetText("")
            end
        end
    end)

    local function cleanupTab()
        dismissActiveDialog()
        clearPendingUndo()
        if statusClearTimer then
            statusClearTimer:Cancel()
            statusClearTimer = nil
        end
        if syntaxCheckTimer then
            syntaxCheckTimer:Cancel()
            syntaxCheckTimer = nil
        end
        if refreshListTimer then
            refreshListTimer:Cancel()
            refreshListTimer = nil
        end
        stopAutoSaveTicker()
    end

    function tab:Teardown()
        cleanupTab()
    end

    tab:SetScript("OnHide", function()
        cleanupTab()
    end)

    return tab
end
