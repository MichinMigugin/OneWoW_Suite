-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/NotesPins.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local NotesPins = {}
ns.NotesPins = NotesPins

local todoFramePool = {}

local function AcquireTodoFrame(parent)
    local f = table.remove(todoFramePool)
    if f then
        f:SetParent(parent)
        f:ClearAllPoints()
        f:Show()
        return f
    end
    f = CreateFrame("Frame", nil, parent)
    f:SetHeight(22)
    f._checkbox = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f._checkbox:SetSize(16, 16)
    f._checkbox:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -3)
    f._text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f._text:SetPoint("TOPLEFT", f._checkbox, "TOPRIGHT", 5, 0)
    f._text:SetJustifyH("LEFT")
    return f
end

local function ReleaseTodoFrame(f)
    f:Hide()
    f._checkbox:SetScript("OnClick", nil)
    f._checkbox:SetChecked(false)
    table.insert(todoFramePool, f)
end

function NotesPins:Initialize()
    local addon = _G.OneWoW_Notes
    if not addon.notePins then
        addon.notePins = {}
    end

    if not addon.db.global.notePinPositions then
        addon.db.global.notePinPositions = {}
    end

    if ns.NotesData then
        C_Timer.After(0.5, function()
            local allNotes = ns.NotesData:GetAllNotes()
            if allNotes then
                for noteID, note in pairs(allNotes) do
                    if note and type(note) == "table" then
                        local shouldShow = false

                        if note.pinEnabled and not note.manuallyHidden and not note.autoUnpinned then
                            shouldShow = true
                        end

                        if (note.noteType == "daily" or note.noteType == "weekly") and note.alwaysShowOnLogin and not note.manuallyHidden then
                            local hasIncompleteTasks = false
                            if note.todos and #note.todos > 0 then
                                for _, todo in ipairs(note.todos) do
                                    if not todo.completed then
                                        hasIncompleteTasks = true
                                        break
                                    end
                                end
                            end
                            if hasIncompleteTasks then
                                shouldShow = true
                                note.pinEnabled = true
                            end
                        end

                        if shouldShow then
                            self:ShowNotePin(noteID)
                        end
                    end
                end
            end
        end)
    end
end

function NotesPins:ShowNotePin(noteID)
    local NotesData = ns.NotesData
    local note = NotesData:GetAllNotes()[noteID]
    if not note then return end

    return self:CreateNotePin(noteID, note)
end

function NotesPins:HideNotePin(noteID)
    local addon = _G.OneWoW_Notes
    if not addon.notePins or not addon.notePins[noteID] then return end

    local pinFrame = addon.notePins[noteID]
    if pinFrame then
        pinFrame:Hide()
        addon.notePins[noteID] = nil

        if ns.UI and ns.UI.notesFrame and ns.UI.notesFrame.RefreshNotesList then
            ns.UI.notesFrame.RefreshNotesList()
        end
    end
end

function NotesPins:HideAllNotePins()
    local addon = _G.OneWoW_Notes
    if not addon.notePins then return end

    for noteID, pinFrame in pairs(addon.notePins) do
        if pinFrame then
            pinFrame:Hide()
        end
    end

    addon.notePins = {}
end

function NotesPins:SavePinPosition(noteID, point, relativePoint, x, y, width, height)
    if not noteID then return end

    local addon = _G.OneWoW_Notes
    if not addon.db.global.notePinPositions then
        addon.db.global.notePinPositions = {}
    end

    addon.db.global.notePinPositions[noteID] = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
        width = width,
        height = height
    }
end

function NotesPins:GetPinPosition(noteID)
    local addon = _G.OneWoW_Notes
    if not noteID or not addon.db.global.notePinPositions then
        return nil
    end

    return addon.db.global.notePinPositions[noteID]
end

function NotesPins:CreateNotePin(noteID, note)
    local addon = _G.OneWoW_Notes
    if not noteID or not note then return end

    if not addon.notePins then
        addon.notePins = {}
    end

    if addon.notePins[noteID] then
        addon.notePins[noteID]:Show()
        if addon.BringWindowToFront then
            addon:BringWindowToFront(addon.notePins[noteID])
        end
        return addon.notePins[noteID]
    end

    local pinColor = note.pinColor or "hunter"
    local colorConfig = ns.Config:GetResolvedColorConfig(pinColor)
    local bgColor = colorConfig.background
    local borderColor = colorConfig.border

    local pin = CreateFrame("Frame", "OneWoW_NotesPin_" .. noteID, UIParent, "BackdropTemplate")
    pin:SetSize(300, 400)
    pin:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -50)
    pin:SetMovable(true)
    pin:SetResizable(true)
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    pin:SetResizeBounds(200, 150, screenWidth, screenHeight)
    pin:EnableMouse(true)
    pin:SetClampedToScreen(true)
    pin:RegisterForDrag("LeftButton")
    pin:SetScript("OnDragStart", pin.StartMoving)
    pin:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, relativeTo, relativePoint, x, y = self:GetPoint()
        NotesPins:SavePinPosition(noteID, point, relativePoint, x, y, self:GetWidth(), self:GetHeight())
    end)

    pin:SetScript("OnMouseDown", function(self)
        if self.windowInfo and addon.BringWindowToFront then
            addon:BringWindowToFront(self)
        end
    end)

    local pinAlpha = note.opacity or 0.9

    if pinAlpha >= 1.0 then
        pin:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        pin:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], 1.0)
    else
        pin:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        pin:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], pinAlpha)
    end

    pin:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
    pin:SetAlpha(1.0)
    pin.noteID = noteID

    local titleBar = CreateFrame("Frame", nil, pin, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", pin, "TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", pin, "TOPRIGHT", -4, -4)
    titleBar:SetHeight(20)
    titleBar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    local titleBarColor = colorConfig.titleBar
    titleBar:SetBackdropColor(titleBarColor[1], titleBarColor[2], titleBarColor[3], 0.8)

    local noteFontColor = note.fontColor or "match"
    local titleColor
    if noteFontColor == "match" then
        titleColor = borderColor
    elseif noteFontColor == "white" then
        titleColor = {1, 1, 1}
    elseif noteFontColor == "black" then
        titleColor = {0, 0, 0}
    else
        local fontConfig = ns.Config.PIN_COLORS[noteFontColor]
        titleColor = fontConfig and fontConfig.border or borderColor
    end

    local titleText = OneWoW_GUI:CreateFS(titleBar, 10)
    titleText:SetPoint("LEFT", titleBar, "LEFT", 5, 0)
    titleText:SetPoint("RIGHT", titleBar, "RIGHT", -25, 0)
    titleText:SetText(L["CORE_PIN_NOTE_PREFIX"] .. " " .. (note.title or L["CORE_PIN_UNTITLED"]))
    titleText:SetJustifyH("LEFT")
    titleText:SetTextColor(titleColor[1], titleColor[2], titleColor[3], 1)
    pin.titleText = titleText
    pin.titleBar = titleBar

    local timerText = OneWoW_GUI:CreateFS(titleBar, 10)
    timerText:SetPoint("RIGHT", titleBar, "RIGHT", -25, 0)
    timerText:SetTextColor(titleColor[1], titleColor[2], titleColor[3], 0.8)
    timerText:Hide()
    pin.timerText = timerText

    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetScript("OnClick", function()
        note.pinEnabled = false
        note.manuallyHidden = true
        pin:Hide()
        if addon.notePins then
            addon.notePins[noteID] = nil
        end
        if ns.UI and ns.UI.notesFrame and ns.UI.notesFrame.RefreshNotesList then
            ns.UI.notesFrame.RefreshNotesList()
        end
    end)
    pin.closeBtn = closeBtn

    -- Content area (scrollable text display)
    local contentFrame = CreateFrame("Frame", nil, pin)
    contentFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 5, -5)
    contentFrame:SetPoint("TOPRIGHT", pin, "TOPRIGHT", -5, -5)
    contentFrame:SetHeight(120)

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentFrame)
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    scrollFrame:SetClipsChildren(true)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - 30))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + 30))
        end
    end)

    local contentText = CreateFrame("EditBox", nil, scrollFrame)
    contentText:SetMultiLine(true)
    contentText:SetAutoFocus(false)
    contentText:EnableMouse(false)
    contentText:EnableKeyboard(false)
    contentText:SetHyperlinksEnabled(true)
    contentText:SetWidth(scrollFrame:GetWidth() or 280)
    contentText:SetHeight(1)
    scrollFrame:SetScrollChild(contentText)

    scrollFrame:HookScript("OnSizeChanged", function(self, width)
        contentText:SetWidth(math.max(1, width))
    end)

    contentText:SetScript("OnHyperlinkClick", function(self, linkData, link, button)
        if button == "LeftButton" then
            SetItemRef(linkData, link, button)
        end
    end)

    local fontSize = note.fontSize or 12
    local fontPath = ns.Config:ResolveFontPath(note.fontFamily)
    contentText:SetFont(fontPath, fontSize, note.fontOutline or "")

    local contentTextColor
    if noteFontColor == "match" then
        contentTextColor = borderColor
    elseif noteFontColor == "white" then
        contentTextColor = {1, 1, 1}
    elseif noteFontColor == "black" then
        contentTextColor = {0, 0, 0}
    else
        local fontConfig = ns.Config.PIN_COLORS[noteFontColor]
        contentTextColor = fontConfig and fontConfig.border or borderColor
    end
    contentText:SetTextColor(contentTextColor[1], contentTextColor[2], contentTextColor[3], 1)

    local noteContent = note.content or ""
    contentText:SetText(noteContent)

    pin.contentText = contentText
    pin.contentFrame = contentFrame
    pin.scrollFrame = scrollFrame

    pin.UpdateContent = function(self)
        local allNotes = ns.NotesData:GetAllNotes()
        local currentNote = allNotes[noteID]
        if not currentNote then return end

        if self.titleText then
            self.titleText:SetText(L["CORE_PIN_NOTE_PREFIX"] .. " " .. (currentNote.title or L["CORE_PIN_UNTITLED"]))
        end
        if self.contentText then
            self.contentText:SetText(currentNote.content or "")
        end
    end

    -- Todo section
    local todoMainFrame = CreateFrame("Frame", nil, pin)
    todoMainFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 5, -5)
    todoMainFrame:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", -5, 15)
    pin.todoMainFrame = todoMainFrame

    local todoScrollFrame = CreateFrame("ScrollFrame", nil, todoMainFrame)
    todoScrollFrame:SetPoint("TOPLEFT", todoMainFrame, "TOPLEFT", 0, 0)
    todoScrollFrame:SetPoint("BOTTOMRIGHT", todoMainFrame, "BOTTOMRIGHT", 0, 0)
    todoScrollFrame:SetClipsChildren(true)
    todoScrollFrame:EnableMouseWheel(true)
    todoScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - 30))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + 30))
        end
    end)
    pin.todoScrollFrame = todoScrollFrame

    local todoContainer = CreateFrame("Frame", nil, todoScrollFrame)
    todoContainer:SetPoint("TOPLEFT", todoScrollFrame, "TOPLEFT", 0, 0)
    todoContainer:SetPoint("TOPRIGHT", todoScrollFrame, "TOPRIGHT", 0, 0)
    todoScrollFrame:SetScrollChild(todoContainer)
    pin.todoContainer = todoContainer
    pin.todoItems = {}

    pin.RefreshLayout = function(self, skipTodoRefresh)
        if not self.contentFrame or not self.todoMainFrame then return end

        local allNotes = ns.NotesData:GetAllNotes()
        local currentNote = allNotes[self.noteID]
        if not currentNote then return end

        local todoCount = 0
        if currentNote.todos then todoCount = #currentNote.todos end
        local taskHeight = 0
        if todoCount > 0 then
            taskHeight = self.todoContainer:GetHeight() or 40
            if taskHeight <= 10 then
                taskHeight = math.max(40, todoCount * 25 + 20)
            end
        end

        local hasContent = currentNote.content and currentNote.content ~= ""
        local contentMinHeight = hasContent and 40 or 0
        local taskMinHeight = todoCount > 0 and 40 or 0
        local titleBarHeight = 30
        local margins = 35
        local minWindowHeight = titleBarHeight + contentMinHeight + taskMinHeight + margins

        local sw = GetScreenWidth()
        local sh = GetScreenHeight()
        self:SetResizeBounds(200, minWindowHeight, sw, sh)

        self.contentFrame:ClearAllPoints()
        self.todoMainFrame:ClearAllPoints()

        local tasksOnTop = currentNote.tasksOnTop == true

        if todoCount == 0 then
            self.todoMainFrame:Hide()
            if hasContent then
                self.contentFrame:SetPoint("TOPLEFT", self.titleBar, "BOTTOMLEFT", 5, -5)
                self.contentFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -5, 15)
                self.contentFrame:Show()
            else
                self.contentFrame:Hide()
            end
        elseif hasContent then
            self.todoMainFrame:Show()
            if tasksOnTop then
                self.todoMainFrame:SetPoint("TOPLEFT", self.titleBar, "BOTTOMLEFT", 5, -5)
                self.todoMainFrame:SetPoint("TOPRIGHT", self, "TOPRIGHT", -5, -5)
                self.todoMainFrame:SetHeight(taskHeight)
                self.contentFrame:SetPoint("TOPLEFT", self.todoMainFrame, "BOTTOMLEFT", 0, -5)
                self.contentFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -5, 15)
            else
                self.todoMainFrame:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 5, 15)
                self.todoMainFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -5, 15)
                self.todoMainFrame:SetHeight(taskHeight)
                self.contentFrame:SetPoint("TOPLEFT", self.titleBar, "BOTTOMLEFT", 5, -5)
                self.contentFrame:SetPoint("TOPRIGHT", self, "TOPRIGHT", -5, -5)
                self.contentFrame:SetPoint("BOTTOMRIGHT", self.todoMainFrame, "TOPRIGHT", 0, -5)
            end
            self.contentFrame:Show()
        else
            self.todoMainFrame:Show()
            self.todoMainFrame:SetPoint("TOPLEFT", self.titleBar, "BOTTOMLEFT", 5, -5)
            self.todoMainFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -5, 15)
            self.todoMainFrame:SetHeight(taskHeight)
            self.contentFrame:Hide()
        end

        if self.todoContainer then
            self.todoContainer:SetWidth(self:GetWidth() - 10)
        end

        if not skipTodoRefresh and self.RefreshTodos then
            self:RefreshTodos()
        end
    end

    pin.RefreshTodos = function(self)
        if not self.todoContainer or not noteID then return end

        for i = #self.todoItems, 1, -1 do
            ReleaseTodoFrame(table.remove(self.todoItems, i))
        end

        local allNotes = ns.NotesData:GetAllNotes()
        local currentNote = allNotes[noteID]
        if not currentNote or not currentNote.todos or #currentNote.todos == 0 then
            self.todoContainer:SetHeight(0)
            self:RefreshLayout(true)
            return
        end

        local sortedTodos = {}
        for _, todo in ipairs(currentNote.todos) do
            table.insert(sortedTodos, todo)
        end

        local addonDB = _G.OneWoW_Notes
        if addonDB.db.global.sortCompletedTasks == true then
            table.sort(sortedTodos, function(a, b)
                if a.completed ~= b.completed then return not a.completed end
                return (a.created or 0) < (b.created or 0)
            end)
        else
            table.sort(sortedTodos, function(a, b)
                return (a.created or 0) < (b.created or 0)
            end)
        end

        local containerWidth = self:GetWidth() - 10
        if containerWidth < 50 then containerWidth = 280 end

        local yOffset = 0
        for _, todo in ipairs(sortedTodos) do
            local todoFrame = AcquireTodoFrame(self.todoContainer)
            todoFrame:SetPoint("TOPLEFT", self.todoContainer, "TOPLEFT", 0, yOffset)
            todoFrame:SetPoint("RIGHT", self.todoContainer, "RIGHT", 0, 0)

            todoFrame._checkbox:SetChecked(todo.completed)
            todoFrame._checkbox:SetScript("OnClick", function(checkSelf)
                todo.completed = checkSelf:GetChecked()
                if currentNote then currentNote.modified = GetServerTime() end
                self:RefreshTodos()

                if currentNote and currentNote.autoPinEnabled and
                   (currentNote.noteType == "daily" or currentNote.noteType == "weekly") then
                    local allCompleted = ns.NotesTodos and ns.NotesTodos:AreAllTodosCompleted(noteID)
                    if allCompleted and self:IsShown() then
                        currentNote.autoUnpinned = true
                        NotesPins:HideNotePin(noteID)
                    elseif not allCompleted and currentNote.autoUnpinned then
                        currentNote.autoUnpinned = false
                        NotesPins:ShowNotePin(noteID)
                    end
                end
            end)

            local fs = currentNote.fontSize or 12
            local todoFontPath = ns.Config:ResolveFontPath(currentNote.fontFamily)
            todoFrame._text:SetFont(todoFontPath, fs, currentNote.fontOutline or "")
            local textWidth = math.max(50, containerWidth - 28)
            todoFrame._text:SetWidth(textWidth)
            todoFrame._text:SetText(todo.text or "")

            if todo.completed then
                todoFrame._text:SetTextColor(0.5, 0.5, 0.5)
            else
                local fc = currentNote.fontColor or "match"
                local todoColor
                if fc == "match" then
                    todoColor = borderColor
                elseif fc == "white" then
                    todoColor = {1, 1, 1}
                elseif fc == "black" then
                    todoColor = {0, 0, 0}
                else
                    local fontConfig = ns.Config.PIN_COLORS[fc]
                    todoColor = fontConfig and fontConfig.border or borderColor
                end
                todoFrame._text:SetTextColor(todoColor[1], todoColor[2], todoColor[3], 1)
            end

            local rowHeight = math.max(22, todoFrame._text:GetStringHeight() + 6)
            todoFrame:SetHeight(rowHeight)

            table.insert(self.todoItems, todoFrame)
            yOffset = yOffset - (rowHeight + 3)
        end

        local totalHeight = math.abs(yOffset) + 10
        self.todoContainer:SetHeight(totalHeight)
    end

    -- Resize handle
    local resizeBtn = CreateFrame("Button", nil, pin)
    resizeBtn:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeBtn:SetSize(12, 12)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetScript("OnMouseDown", function(self)
        pin:StartSizing("BOTTOMRIGHT")
    end)
    resizeBtn:SetScript("OnMouseUp", function(self)
        pin:StopMovingOrSizing()
        local point, relativeTo, relativePoint, x, y = pin:GetPoint()
        NotesPins:SavePinPosition(noteID, point, relativePoint, x, y, pin:GetWidth(), pin:GetHeight())
        if pin.RefreshLayout then pin:RefreshLayout() end
    end)
    pin.resizeBtn = resizeBtn

    -- Hover controls panel
    local hoverControlsPanel = CreateFrame("Frame", nil, pin, "BackdropTemplate")
    hoverControlsPanel:SetPoint("TOPLEFT", pin, "BOTTOMLEFT", 0, 0)
    hoverControlsPanel:SetPoint("TOPRIGHT", pin, "BOTTOMRIGHT", 0, 0)
    hoverControlsPanel:SetHeight(50)
    hoverControlsPanel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    local listItemColor = colorConfig.listItem
    hoverControlsPanel:SetBackdropColor(listItemColor[1], listItemColor[2], listItemColor[3], 0.9)
    hoverControlsPanel:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
    hoverControlsPanel:SetFrameLevel(pin:GetFrameLevel() + 10)
    hoverControlsPanel:Hide()
    pin.hoverControlsPanel = hoverControlsPanel

    local alphaSlider = OneWoW_GUI:CreateSlider(hoverControlsPanel, {
        minVal = 0.1,
        maxVal = 1.0,
        step = 0.05,
        currentVal = pinAlpha,
        onChange = function(val)
            note.opacity = val
            if val >= 1.0 then
                pin:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = false, tileSize = 16, edgeSize = 16,
                    insets = { left = 4, right = 4, top = 4, bottom = 4 }
                })
                pin:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], 1.0)
            else
                pin:SetBackdrop({
                    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 16,
                    insets = { left = 4, right = 4, top = 4, bottom = 4 }
                })
                pin:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], val)
            end
            pin:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
        end,
    })
    alphaSlider:SetPoint("TOPLEFT", hoverControlsPanel, "TOPLEFT", 10, -5)
    alphaSlider:SetPoint("TOPRIGHT", hoverControlsPanel, "TOPRIGHT", -10, -5)
    pin.alphaSlider = alphaSlider

    local lockMoveCB = OneWoW_GUI:CreateCheckbox(hoverControlsPanel, {
        label = L["CORE_PIN_LOCK_MOVE"],
        checked = note.lockMove,
        onClick = function(self)
            note.lockMove = self:GetChecked()
            if note.lockMove then
                pin:SetMovable(false)
                pin:RegisterForDrag()
            else
                pin:SetMovable(true)
                pin:RegisterForDrag("LeftButton")
            end
        end,
    })
    lockMoveCB:SetPoint("BOTTOMLEFT", hoverControlsPanel, "BOTTOMLEFT", 10, 5)
    if note.lockMove then
        pin:SetMovable(false)
        pin:RegisterForDrag()
    end
    pin.lockMoveCB = lockMoveCB

    local lockResizeCB = OneWoW_GUI:CreateCheckbox(hoverControlsPanel, {
        label = L["CORE_PIN_LOCK_RESIZE"],
        checked = note.lockResize,
        onClick = function(self)
            note.lockResize = self:GetChecked()
            if note.lockResize then
                resizeBtn:Hide()
                resizeBtn:Disable()
                pin:SetResizable(false)
            else
                resizeBtn:Show()
                resizeBtn:Enable()
                pin:SetResizable(true)
            end
        end,
    })
    lockResizeCB:SetPoint("LEFT", lockMoveCB, "RIGHT", 80, 0)
    if note.lockResize then
        resizeBtn:Hide()
        resizeBtn:Disable()
        pin:SetResizable(false)
    end
    pin.lockResizeCB = lockResizeCB

    local resetTodosBtn = CreateFrame("Button", nil, hoverControlsPanel)
    resetTodosBtn:SetSize(24, 24)
    resetTodosBtn:SetPoint("BOTTOMRIGHT", hoverControlsPanel, "BOTTOMRIGHT", -10, 5)
    resetTodosBtn:SetNormalAtlas("talents-button-undo")
    resetTodosBtn:SetPushedAtlas("talents-button-undo")
    resetTodosBtn:SetHighlightAtlas("talents-button-undo")
    resetTodosBtn:GetHighlightTexture():SetAlpha(0.5)
    resetTodosBtn:SetScript("OnClick", function()
        if note.todos then
            for _, todo in ipairs(note.todos) do
                todo.completed = false
            end
            if pin.RefreshTodos then pin:RefreshTodos() end
        end
    end)
    resetTodosBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["CORE_PIN_RESET_TODOS"], 1, 1, 1)
        GameTooltip:AddLine(L["CORE_PIN_RESET_TODOS_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    resetTodosBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    pin.resetTodosBtn = resetTodosBtn

    local function HideHoverControls()
        hoverControlsPanel:Hide()
        if pin.timerText then pin.timerText:Hide() end
    end

    local function ShowHoverControls()
        hoverControlsPanel:Show()
        if pin.timerText and note.noteType and (note.noteType == "daily" or note.noteType == "weekly") then
            pin.timerText:Show()
        end
    end

    HideHoverControls()

    pin:SetScript("OnEnter", ShowHoverControls)
    pin:SetScript("OnLeave", function()
        C_Timer.After(0.05, function()
            local overAny = pin:IsMouseOver() or hoverControlsPanel:IsMouseOver()
            if not overAny then HideHoverControls() end
        end)
    end)

    -- Restore saved position
    local savedPos = self:GetPinPosition(noteID)
    if savedPos then
        pin:ClearAllPoints()
        pin:SetPoint(savedPos.point or "CENTER", UIParent, savedPos.relativePoint or "CENTER", savedPos.x or 0, savedPos.y or 0)
        if savedPos.width and savedPos.height then
            pin:SetSize(savedPos.width, savedPos.height)
        end
    end

    addon.notePins[noteID] = pin

    if addon.RegisterWindow then
        pin.windowInfo = addon:RegisterWindow(pin, "pinned", function()
            pin:Hide()
        end)
    end

    pin:SetScript("OnHide", function(self)
        if self.windowInfo and addon.UnregisterWindow then
            addon:UnregisterWindow(self)
        end
    end)

    pin:SetScript("OnShow", function(self)
        if not self.windowInfo and addon.RegisterWindow then
            self.windowInfo = addon:RegisterWindow(self, "pinned", function()
                self:Hide()
            end)
        end
    end)

    pin:RefreshLayout()
    pin:RefreshTodos()

    if note.noteType and (note.noteType == "daily" or note.noteType == "weekly") and pin.timerText then
        if note.noteType == "daily" then
            local secondsUntilReset = GetQuestResetTime()
            if addon.FormatResetTimer then
                pin.timerText:SetText(addon:FormatResetTimer(secondsUntilReset))
            end
        elseif note.noteType == "weekly" then
            local secondsUntilReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
            if addon.FormatResetTimer then
                pin.timerText:SetText(addon:FormatResetTimer(secondsUntilReset))
            end
        end
    end

    pin:Show()

    if addon.BringWindowToFront then
        addon:BringWindowToFront(pin)
    end

    return pin
end

function NotesPins:RefreshNotePinColors(noteID)
    local addon = _G.OneWoW_Notes
    if not addon.notePins or not addon.notePins[noteID] then return end

    local pinFrame = addon.notePins[noteID]
    if not pinFrame or not pinFrame:IsShown() then return end

    local note = ns.NotesData:GetAllNotes()[noteID]
    if not note then return end

    local pinColorKey = note.pinColor or "hunter"
    local colorConfig = ns.Config.PIN_COLORS[pinColorKey] or ns.Config.PIN_COLORS["hunter"]
    local bgColor = colorConfig.background
    local borderColor = colorConfig.border
    local pinAlpha = note.opacity or 0.9

    pinFrame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], pinAlpha)
    pinFrame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)

    if pinFrame.titleBar then
        local titleColor = colorConfig.titleBar
        pinFrame.titleBar:SetBackdropColor(titleColor[1], titleColor[2], titleColor[3], 0.8)
    end

    local noteFontColor = note.fontColor or "match"
    local fontSize = note.fontSize or 12
    local textColor

    if noteFontColor == "match" then
        textColor = borderColor
    elseif noteFontColor == "white" then
        textColor = {1, 1, 1}
    elseif noteFontColor == "black" then
        textColor = {0, 0, 0}
    else
        local fontConfig = ns.Config.PIN_COLORS[noteFontColor]
        textColor = fontConfig and fontConfig.border or borderColor
    end

    if pinFrame.titleText then
        pinFrame.titleText:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
    end
    if pinFrame.contentText then
        pinFrame.contentText:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
        local fontPath = ns.Config:ResolveFontPath(note.fontFamily)
        pinFrame.contentText:SetFont(fontPath, fontSize, note.fontOutline or "")
    end
    if pinFrame.RefreshTodos then
        pinFrame:RefreshTodos()
    end
end

function NotesPins:RefreshAllPinFonts()
    local addon = _G.OneWoW_Notes
    if not addon.notePins then return end
    for noteID, pinFrame in pairs(addon.notePins) do
        if pinFrame and pinFrame:IsShown() then
            self:RefreshNotePinColors(noteID)
        end
    end
end

function NotesPins:RefreshSyncPins()
    local addon = _G.OneWoW_Notes
    if not addon.notePins then return end

    for noteID, pinFrame in pairs(addon.notePins) do
        if pinFrame and pinFrame:IsShown() then
            local note = ns.NotesData:GetAllNotes()[noteID]
            if note and note.pinColor == "sync" then
                local colorConfig = ns.Config:GetResolvedColorConfig("sync")
                local bgColor = colorConfig.background
                local borderColor = colorConfig.border
                local titleBarColor = colorConfig.titleBar

                if pinFrame:GetBackdropColor() then
                    local opacity = note.opacity or 0.9
                    if opacity >= 1.0 then
                        pinFrame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], 1.0)
                    else
                        pinFrame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], opacity)
                    end
                end
                pinFrame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)

                if pinFrame.titleBar then
                    pinFrame.titleBar:SetBackdropColor(titleBarColor[1], titleBarColor[2], titleBarColor[3], 0.8)
                end

                if pinFrame.titleText then
                    local fontColor = note.fontColor or "match"
                    local titleColor = ns.Config:GetResolvedFontColor(fontColor, "sync")
                    pinFrame.titleText:SetTextColor(titleColor[1], titleColor[2], titleColor[3], 1)
                end
            end
        end
    end
end
