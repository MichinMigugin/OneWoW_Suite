local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local PinSupport = ns.PinSupport

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
    if not ns.notePins then
        ns.notePins = {}
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
    if not ns.notePins or not ns.notePins[noteID] then return end

    local pinFrame = ns.notePins[noteID]
    if pinFrame then
        pinFrame:Hide()
        ns.notePins[noteID] = nil

        if ns.UI and ns.UI.notesFrame and ns.UI.notesFrame.RefreshNotesList then
            ns.UI.notesFrame.RefreshNotesList()
        end
    end
end

function NotesPins:HideAllNotePins()
    if not ns.notePins then return end

    for _, pinFrame in pairs(ns.notePins) do
        if pinFrame then
            pinFrame:Hide()
        end
    end

    ns.notePins = {}
end

function NotesPins:SavePinPosition(noteID, point, relativePoint, x, y, width, height, meta)
    if not noteID then return end

    meta = meta or {}
    ns.db.global.notePinPositions[noteID] = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
        width = width,
        height = height,
        collapsed = meta.collapsed and true or false,
        expandedWidth = meta.expandedWidth or width,
        expandedHeight = meta.expandedHeight or height,
    }
end

function NotesPins:GetPinPosition(noteID)
    if not noteID then return nil end
    return ns.db.global.notePinPositions[noteID]
end

function NotesPins:CreateNotePin(noteID, note)
    local addon = ns
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

    local function SavePinGeometry(pinFrame)
        if PinSupport.IsLayoutBlocked() then
            PinSupport.DeferGeometrySave(pinFrame, function()
                SavePinGeometry(pinFrame)
            end)
            return
        end
        PinSupport.CachePinSize(pinFrame)
        local point, _, relativePoint, x, y = pinFrame:GetPoint()
        local w = PinSupport.GetPinWidth(pinFrame, 300)
        local h = PinSupport.GetPinHeight(pinFrame, 400)
        local collapsed = pinFrame.collapsed and true or false
        local ew, eh = w, h
        if collapsed then
            ew = pinFrame._savedWidth or w
            eh = pinFrame._savedHeight or h
        end
        NotesPins:SavePinPosition(noteID, point, relativePoint, x, y, w, h, {
            collapsed = collapsed,
            expandedWidth = ew,
            expandedHeight = eh,
        })
    end

    local pinColor = note.pinColor or "hunter"
    local colorConfig = ns.Config:GetResolvedColorConfig(pinColor)
    local bgColor = colorConfig.background
    local borderColor = colorConfig.border

    local pin = CreateFrame("Frame", "OneWoW_NotesPin_" .. noteID, UIParent, "BackdropTemplate")
    pin:SetSize(300, 400)
    pin._cachedWidth = 300
    pin._cachedHeight = 400
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
    pin:SetScript("OnDragStop", function(myself)
        myself:StopMovingOrSizing()
        SavePinGeometry(myself)
    end)

    pin:SetScript("OnMouseDown", function(myself)
        if myself.windowInfo and addon.BringWindowToFront then
            addon:BringWindowToFront(myself)
        end
    end)

    local pinAlpha = note.opacity or 0.9
    PinSupport.ApplyOpacityBackdrop(pin, bgColor, pinAlpha, borderColor)
    pin:SetAlpha(1.0)
    pin.noteID = noteID
    pin.collapsed = false
    pin._titleBarLastClick = 0
    pin._savedWidth = 300
    pin._savedHeight = 400
    pin._tasksHoverShown = false

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

    -- Grow the title bar to fit a wrapped (multi-line) title instead of clipping.
    pin.UpdateTitleHeight = function(myself)
        if not myself.titleText or not myself.titleBar then return end
        local th = myself.titleText:GetStringHeight() or 0
        myself.titleBar:SetHeight(math.max(20, math.ceil(th) + 8))
    end

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
    scrollFrame:SetScript("OnMouseWheel", function(myself, delta)
        local current = myself:GetVerticalScroll()
        local maxScroll = myself:GetVerticalScrollRange()
        if delta > 0 then
            myself:SetVerticalScroll(math.max(0, current - 30))
        else
            myself:SetVerticalScroll(math.min(maxScroll, current + 30))
        end
    end)

    local contentText = CreateFrame("EditBox", nil, scrollFrame)
    contentText:SetMultiLine(true)
    contentText:SetAutoFocus(false)
    contentText:EnableMouse(false)
    contentText:EnableKeyboard(false)
    contentText:SetHyperlinksEnabled(true)
    contentText:SetWidth(PinSupport.GetScrollWidth(scrollFrame, 280, "_cachedScrollWidth"))
    contentText:SetHeight(1)
    scrollFrame:SetScrollChild(contentText)

    scrollFrame:HookScript("OnSizeChanged", function(myself, width)
        if PinSupport.IsLayoutBlocked() then
            width = myself._cachedScrollWidth or 280
        elseif width then
            myself._cachedScrollWidth = width
        end
        contentText:SetWidth(math.max(1, width or 280))
    end)

    contentText:SetScript("OnHyperlinkClick", function(_, linkData, link, button)
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

    pin.UpdateContent = function(myself)
        local allNotes = ns.NotesData:GetAllNotes()
        local currentNote = allNotes[noteID]
        if not currentNote then return end

        if myself.titleText then
            myself.titleText:SetText(L["CORE_PIN_NOTE_PREFIX"] .. " " .. (currentNote.title or L["CORE_PIN_UNTITLED"]))
            myself:UpdateTitleHeight()
        end
        if myself.contentText then
            myself.contentText:SetText(currentNote.content or "")
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
    todoScrollFrame:SetScript("OnMouseWheel", function(myself, delta)
        local current = myself:GetVerticalScroll()
        local maxScroll = myself:GetVerticalScrollRange()
        if delta > 0 then
            myself:SetVerticalScroll(math.max(0, current - 30))
        else
            myself:SetVerticalScroll(math.min(maxScroll, current + 30))
        end
    end)
    pin.todoScrollFrame = todoScrollFrame

    local todoContainer = CreateFrame("Frame", nil, todoScrollFrame)
    todoContainer:SetPoint("TOPLEFT", todoScrollFrame, "TOPLEFT", 0, 0)
    todoContainer:SetPoint("TOPRIGHT", todoScrollFrame, "TOPRIGHT", 0, 0)
    todoScrollFrame:SetScrollChild(todoContainer)
    pin.todoContainer = todoContainer
    pin.todoItems = {}

    -- Hover-hide task height management.
    --
    -- Model: the window has a single "full height" = its height with tasks
    -- visible (content + tasks). When "hide tasks until hover" is on and the
    -- pin is not hovered, the task block is subtracted so the window shrinks to
    -- exactly the content; hovering (or turning the feature off) adds it back.
    --
    -- myself._tasksShownState tracks whether tasks were visible in the layout
    -- the *current* window height reflects. We derive full height from the
    -- current height using that flag, so toggling the feature and hovering are
    -- clean +/- taskBlock transitions with no leftover empty space.
    local function ApplyTaskHoverHeight(myself, currentNote, todoCount, hasContent)
        if not currentNote or myself.collapsed or todoCount == 0 then
            return
        end

        -- Measured height of the full (all todos) task list, plus padding.
        local todoH = 0
        if myself.todoContainer then
            todoH = math.max(PinSupport.GetFrameHeight(myself.todoContainer, myself._cachedTodoHeight or 0), 1)
        end
        if todoH < 20 then
            todoH = math.max(48, todoCount * 25 + 16)
        end
        local taskBlock = todoH + 10

        local titleBarH  = PinSupport.GetFrameHeight(myself.titleBar, 20) + 10
        local margins    = 35
        local contentMin = hasContent and 40 or 14
        local restMin    = titleBarH + margins + contentMin
        local fullMin    = restMin + 40

        local hideUntilHover = currentNote.pinHideTasksUntilHover == true
        local nowVisible = (not hideUntilHover) or (myself._tasksHoverShown and true or false)

        -- What the current window height reflects. First run: assume it already
        -- matches the current visibility so we don't jump on load.
        local wasVisible = myself._tasksShownState
        if wasVisible == nil then wasVisible = nowVisible end

        local curH = PinSupport.GetPinHeight(myself, myself._cachedHeight or 400)

        local fullH = wasVisible and curH or (curH + taskBlock)
        fullH = math.max(fullH, fullMin)
        myself._pinFullHeight = fullH

        local target = nowVisible and fullH or math.max(restMin, fullH - taskBlock)
        if math.abs(curH - target) > 1 then
            myself:SetHeight(target)
            myself._cachedHeight = target
        end

        myself._tasksShownState = nowVisible
    end

    pin.RefreshLayout = function(myself, skipTodoRefresh)
        if not myself.contentFrame or not myself.todoMainFrame then return end

        local allNotes = ns.NotesData:GetAllNotes()
        local currentNote = allNotes[myself.noteID]
        if not currentNote then return end

        myself:UpdateTitleHeight()

        if myself.collapsed then
            local sw = GetScreenWidth()
            local sh = GetScreenHeight()
            local ch = PinSupport.GetFrameHeight(myself.titleBar, 20) + 14
            myself:SetResizeBounds(200, ch, sw, sh)
            myself.contentFrame:Hide()
            myself.todoMainFrame:Hide()
            myself.resizeBtn:Hide()
            return
        end

        local todoCount = 0
        if currentNote.todos then todoCount = #currentNote.todos end

        local layoutTodoCount = todoCount
        if currentNote.pinHideTasksUntilHover and todoCount > 0 and not myself._tasksHoverShown then
            layoutTodoCount = 0
        end

        local taskHeight = 0
        if layoutTodoCount > 0 then
            taskHeight = PinSupport.GetFrameHeight(myself.todoContainer, myself._cachedTodoHeight or 40)
            if taskHeight <= 10 then
                taskHeight = math.max(40, layoutTodoCount * 25 + 20)
            end
            myself._cachedTodoHeight = taskHeight
        end

        local hasContent = currentNote.content and currentNote.content ~= ""
        local contentMinHeight = hasContent and 40 or 0
        local taskMinHeight = (layoutTodoCount > 0) and 40 or 0
        local titleBarHeight = PinSupport.GetFrameHeight(myself.titleBar, 20) + 10
        local margins = 35
        local minWindowHeight = titleBarHeight + contentMinHeight + taskMinHeight + margins

        local sw = GetScreenWidth()
        local sh = GetScreenHeight()
        myself:SetResizeBounds(200, minWindowHeight, sw, sh)

        myself.contentFrame:ClearAllPoints()
        myself.todoMainFrame:ClearAllPoints()

        local tasksOnTop = currentNote.tasksOnTop == true

        if layoutTodoCount == 0 then
            myself.todoMainFrame:Hide()
            if hasContent then
                myself.contentFrame:SetPoint("TOPLEFT", myself.titleBar, "BOTTOMLEFT", 5, -5)
                myself.contentFrame:SetPoint("BOTTOMRIGHT", myself, "BOTTOMRIGHT", -5, 15)
                myself.contentFrame:Show()
            else
                myself.contentFrame:Hide()
            end
        elseif hasContent then
            myself.todoMainFrame:Show()
            if tasksOnTop then
                myself.todoMainFrame:SetPoint("TOPLEFT", myself.titleBar, "BOTTOMLEFT", 5, -5)
                myself.todoMainFrame:SetPoint("TOPRIGHT", myself, "TOPRIGHT", -5, -5)
                myself.todoMainFrame:SetHeight(taskHeight)
                myself.contentFrame:SetPoint("TOPLEFT", myself.todoMainFrame, "BOTTOMLEFT", 0, -5)
                myself.contentFrame:SetPoint("BOTTOMRIGHT", myself, "BOTTOMRIGHT", -5, 15)
            else
                myself.todoMainFrame:SetPoint("BOTTOMLEFT", myself, "BOTTOMLEFT", 5, 15)
                myself.todoMainFrame:SetPoint("BOTTOMRIGHT", myself, "BOTTOMRIGHT", -5, 15)
                myself.todoMainFrame:SetHeight(taskHeight)
                myself.contentFrame:SetPoint("TOPLEFT", myself.titleBar, "BOTTOMLEFT", 5, -5)
                myself.contentFrame:SetPoint("TOPRIGHT", myself, "TOPRIGHT", -5, -5)
                myself.contentFrame:SetPoint("BOTTOMRIGHT", myself.todoMainFrame, "TOPRIGHT", 0, -5)
            end
            myself.contentFrame:Show()
        else
            myself.todoMainFrame:Show()
            myself.todoMainFrame:SetPoint("TOPLEFT", myself.titleBar, "BOTTOMLEFT", 5, -5)
            myself.todoMainFrame:SetPoint("BOTTOMRIGHT", myself, "BOTTOMRIGHT", -5, 15)
            myself.todoMainFrame:SetHeight(taskHeight)
            myself.contentFrame:Hide()
        end

        if myself.todoContainer then
            myself.todoContainer:SetWidth(PinSupport.GetPinWidth(myself, 300) - 10)
        end

        if not skipTodoRefresh and myself.RefreshTodos then
            myself:RefreshTodos()
        end

        if not skipTodoRefresh then
            ApplyTaskHoverHeight(myself, currentNote, todoCount, hasContent)
        end

        if PinSupport.IsLayoutBlocked() then
            PinSupport.RegisterDeferredPin(myself)
        else
            PinSupport.CachePinSize(myself)
        end
    end

    pin.RefreshTodos = function(myself)
        if not myself.todoContainer or not noteID then return end

        for i = #myself.todoItems, 1, -1 do
            ReleaseTodoFrame(table.remove(myself.todoItems, i))
        end

        local allNotes = ns.NotesData:GetAllNotes()
        local currentNote = allNotes[noteID]
        if not currentNote or not currentNote.todos or #currentNote.todos == 0 then
            myself.todoContainer:SetHeight(0)
            myself:RefreshLayout(true)
            return
        end

        local sortedTodos = {}
        for _, todo in ipairs(currentNote.todos) do
            table.insert(sortedTodos, todo)
        end

        if ns.db.global.sortCompletedTasks == true then
            table.sort(sortedTodos, function(a, b)
                if a.completed ~= b.completed then return not a.completed end
                return (a.created or 0) < (b.created or 0)
            end)
        else
            table.sort(sortedTodos, function(a, b)
                return (a.created or 0) < (b.created or 0)
            end)
        end

        local containerWidth = PinSupport.GetPinWidth(myself, 300) - 10
        if containerWidth < 50 then containerWidth = 280 end

        local yOffset = 0
        for _, todo in ipairs(sortedTodos) do
            local todoFrame = AcquireTodoFrame(myself.todoContainer)
            todoFrame:SetPoint("TOPLEFT", myself.todoContainer, "TOPLEFT", 0, yOffset)
            todoFrame:SetPoint("RIGHT", myself.todoContainer, "RIGHT", 0, 0)

            todoFrame._checkbox:SetChecked(todo.completed)
            todoFrame._checkbox:SetScript("OnClick", function(checkSelf)
                todo.completed = checkSelf:GetChecked()
                if currentNote then currentNote.modified = GetServerTime() end
                myself:RefreshTodos()

                if currentNote and currentNote.autoPinEnabled and
                   (currentNote.noteType == "daily" or currentNote.noteType == "weekly") then
                    local allCompleted = ns.NotesTodos and ns.NotesTodos:AreAllTodosCompleted(noteID)
                    if allCompleted and myself:IsShown() then
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
                todoFrame._text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
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

            table.insert(myself.todoItems, todoFrame)
            yOffset = yOffset - (rowHeight + 3)
        end

        local totalHeight = math.abs(yOffset) + 10
        myself.todoContainer:SetHeight(totalHeight)
        myself._cachedTodoHeight = totalHeight
    end

    -- Resize handle
    local resizeBtn = CreateFrame("Button", nil, pin)
    resizeBtn:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeBtn:SetSize(12, 12)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetScript("OnMouseDown", function()
        pin:StartSizing("BOTTOMRIGHT")
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        pin:StopMovingOrSizing()
        SavePinGeometry(pin)
        if pin.RefreshLayout then pin:RefreshLayout() end
    end)
    pin.resizeBtn = resizeBtn

    local function TogglePinCollapsed()
        if pin.collapsed then
            pin.collapsed = false
            local ew = pin._savedWidth or 300
            local eh = pin._savedHeight or 400
            pin:SetSize(ew, eh)
            pin._cachedWidth = ew
            pin._cachedHeight = eh
            -- The restored height is the full (tasks-visible) height; tell the
            -- height manager so it can shrink back to resting if hover-hide is on.
            pin._tasksShownState = true
            if note.lockResize then
                pin.resizeBtn:Hide()
                pin.resizeBtn:Disable()
                pin:SetResizable(false)
            else
                pin.resizeBtn:Show()
                pin.resizeBtn:Enable()
                pin:SetResizable(true)
            end
            pin:RefreshLayout()
        else
            pin._savedWidth = PinSupport.GetPinWidth(pin, 300)
            -- Persist the full (tasks-visible) height so an uncollapse restores
            -- the expanded size, letting the manager derive resting height.
            pin._savedHeight = pin._pinFullHeight or PinSupport.GetPinHeight(pin, 400)
            pin.collapsed = true
            pin._tasksHoverShown = false
            if pin.hoverControlsPanel then pin.hoverControlsPanel:Hide() end
            if pin.timerText then pin.timerText:Hide() end
            pin.contentFrame:Hide()
            pin.todoMainFrame:Hide()
            pin.resizeBtn:Hide()
            pin:SetResizable(false)
            local ch = PinSupport.GetFrameHeight(pin.titleBar, 20) + 14
            pin:SetHeight(ch)
            pin._cachedHeight = ch
            local sw, sh = GetScreenWidth(), GetScreenHeight()
            pin:SetResizeBounds(200, ch, sw, sh)
        end
        SavePinGeometry(pin)
    end

    titleBar:EnableMouse(true)
    titleBar:SetScript("OnEnter", function()
        PinSupport.ShowTooltip(titleBar, "ANCHOR_BOTTOM", L["DOUBLE_CLICK_OR_SHIFT_CLICK_TO_COLLAPSE_OR_EXPAND"])
    end)
    titleBar:SetScript("OnLeave", function()
        PinSupport.HideTooltip()
    end)
    titleBar:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        if IsShiftKeyDown() then
            TogglePinCollapsed()
            pin._titleBarLastClick = 0
            return
        end
        local now = GetTime()
        if pin._titleBarLastClick and (now - pin._titleBarLastClick) < 0.4 then
            TogglePinCollapsed()
            pin._titleBarLastClick = 0
        else
            pin._titleBarLastClick = now
        end
    end)

    local function SyncPinnedTitleBarDrag()
        if note.lockMove then
            titleBar:RegisterForDrag()
        else
            titleBar:RegisterForDrag("LeftButton")
        end
    end

    titleBar:SetScript("OnDragStart", function()
        if not note.lockMove then
            pin:StartMoving()
        end
    end)
    titleBar:SetScript("OnDragStop", function()
        pin:StopMovingOrSizing()
        SavePinGeometry(pin)
    end)
    SyncPinnedTitleBarDrag()

    -- Hover controls panel
    local hoverControlsPanel = CreateFrame("Frame", nil, pin, "BackdropTemplate")
    hoverControlsPanel:SetPoint("TOPLEFT", pin, "BOTTOMLEFT", 0, 0)
    hoverControlsPanel:SetPoint("TOPRIGHT", pin, "BOTTOMRIGHT", 0, 0)
    hoverControlsPanel:SetHeight(72)
    local listItemColor = colorConfig.listItem
    PinSupport.ApplyOpacityBackdrop(hoverControlsPanel, listItemColor, pinAlpha, borderColor)
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
            PinSupport.ApplyOpacityBackdrop(pin, bgColor, val, borderColor)
            PinSupport.ApplyOpacityBackdrop(hoverControlsPanel, listItemColor, val, borderColor)
        end,
    })
    pin.alphaSlider = alphaSlider

    local lockMoveCB = OneWoW_GUI:CreateCheckbox(hoverControlsPanel, {
        label = L["LOCK_MOVE"],
        checked = note.lockMove,
        onClick = function(myself)
            note.lockMove = myself:GetChecked()
            if note.lockMove then
                pin:SetMovable(false)
                pin:RegisterForDrag()
            else
                pin:SetMovable(true)
                pin:RegisterForDrag("LeftButton")
            end
            SyncPinnedTitleBarDrag()
        end,
    })
    if note.lockMove then
        pin:SetMovable(false)
        pin:RegisterForDrag()
    end
    pin.lockMoveCB = lockMoveCB

    local hoverTasksCB = OneWoW_GUI:CreateCheckbox(hoverControlsPanel, {
        label = L["CORE_PIN_HOVER_TASKS"],
        checked = note.pinHideTasksUntilHover == true,
        onClick = function(myself)
            note.pinHideTasksUntilHover = myself:GetChecked()
            note.modified = GetServerTime()
            pin._tasksHoverShown = false
            if pin.RefreshLayout then pin:RefreshLayout() end
        end,
    })
    local function HoverTasksTooltip(myself)
        PinSupport.ShowTooltip(myself, "ANCHOR_RIGHT", L["CORE_PIN_HOVER_TASKS"], L["NOTE_PIN_HIDE_TASKS_UNTIL_HOVER_DESC"])
    end
    hoverTasksCB:SetScript("OnEnter", HoverTasksTooltip)
    hoverTasksCB:SetScript("OnLeave", PinSupport.HideTooltip)
    if hoverTasksCB.label then
        hoverTasksCB.label:SetScript("OnEnter", HoverTasksTooltip)
        hoverTasksCB.label:SetScript("OnLeave", PinSupport.HideTooltip)
    end
    pin.hoverTasksCB = hoverTasksCB

    local lockResizeCB = OneWoW_GUI:CreateCheckbox(hoverControlsPanel, {
        label = L["LOCK_RESIZE"],
        checked = note.lockResize,
        onClick = function(myself)
            note.lockResize = myself:GetChecked()
            if note.lockResize then
                resizeBtn:Hide()
                resizeBtn:Disable()
                pin:SetResizable(false)
            else
                pin:SetResizable(true)
                if not pin.collapsed then
                    resizeBtn:Show()
                    resizeBtn:Enable()
                end
            end
        end,
    })
    if note.lockResize then
        resizeBtn:Hide()
        resizeBtn:Disable()
        pin:SetResizable(false)
    end
    pin.lockResizeCB = lockResizeCB

    local resetTodosBtn = CreateFrame("Button", nil, hoverControlsPanel)
    resetTodosBtn:SetSize(24, 24)
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
    resetTodosBtn:SetScript("OnEnter", function(myself)
        PinSupport.ShowTooltip(myself, "ANCHOR_TOP", L["NOTE_RESET_TODOS"], L["NOTE_RESET_TODOS_DESC"])
    end)
    resetTodosBtn:SetScript("OnLeave", PinSupport.HideTooltip)
    pin.resetTodosBtn = resetTodosBtn

    local function HideHoverControls()
        hoverControlsPanel:Hide()
        if pin.timerText then pin.timerText:Hide() end
    end

    local function ShowHoverControls()
        if pin.collapsed then return end

        local rows = {
            { control = alphaSlider, fill = true },
            { control = lockMoveCB },
            { control = lockResizeCB },
            { control = hoverTasksCB },
        }
        local n = ns.NotesData:GetAllNotes()[noteID]
        if n and n.todos and #n.todos > 0 then
            resetTodosBtn:Show()
            table.insert(rows, { control = resetTodosBtn })
        else
            resetTodosBtn:Hide()
        end
        PinSupport.LayoutHoverPanel(hoverControlsPanel, rows)

        hoverControlsPanel:Show()
        if pin.timerText and note.noteType and (note.noteType == "daily" or note.noteType == "weekly") then
            pin.timerText:Show()
        end
    end

    HideHoverControls()

    local function ShowHoverControlsMerged()
        if pin.collapsed then return end
        ShowHoverControls()
        local n = ns.NotesData:GetAllNotes()[noteID]
        if n and n.pinHideTasksUntilHover and not pin.collapsed then
            pin._tasksHoverShown = true
            if pin.RefreshLayout then pin:RefreshLayout() end
        end
    end

    local function PinLeaveMouseCheck()
        C_Timer.After(0.05, function()
            local overAny = pin:IsMouseOver() or hoverControlsPanel:IsMouseOver()
            if not overAny then
                HideHoverControls()
                if pin.collapsed then return end
                local n = ns.NotesData:GetAllNotes()[noteID]
                if n and n.pinHideTasksUntilHover then
                    pin._tasksHoverShown = false
                    if pin.RefreshLayout then pin:RefreshLayout() end
                end
            end
        end)
    end

    pin:SetScript("OnEnter", ShowHoverControlsMerged)
    pin:SetScript("OnLeave", PinLeaveMouseCheck)

    -- Restore saved position
    local savedPos = self:GetPinPosition(noteID)
    if savedPos then
        pin:ClearAllPoints()
        pin:SetPoint(savedPos.point or "CENTER", UIParent, savedPos.relativePoint or "CENTER", savedPos.x or 0, savedPos.y or 0)
        if savedPos.collapsed and savedPos.expandedWidth and savedPos.expandedHeight then
            pin.collapsed = true
            pin._savedWidth = savedPos.expandedWidth
            pin._savedHeight = savedPos.expandedHeight
            local collapsedH = savedPos.height or (PinSupport.GetFrameHeight(pin.titleBar, 20) + 14)
            pin:SetSize(savedPos.width or 300, collapsedH)
            pin._cachedWidth = savedPos.width or 300
            pin._cachedHeight = collapsedH
        elseif savedPos.width and savedPos.height then
            pin:SetSize(savedPos.width, savedPos.height)
            pin.collapsed = false
            pin._savedWidth = savedPos.width
            pin._savedHeight = savedPos.height
            pin._cachedWidth = savedPos.width
            pin._cachedHeight = savedPos.height
        end
    end

    addon.notePins[noteID] = pin

    if addon.RegisterWindow then
        pin.windowInfo = addon:RegisterWindow(pin, "pinned", function()
            pin:Hide()
        end)
    end

    pin:SetScript("OnHide", function(myself)
        if myself.windowInfo then
            addon:UnregisterWindow(myself)
        end
    end)

    pin:SetScript("OnShow", function(myself)
        if not myself.windowInfo then
            myself.windowInfo = addon:RegisterWindow(myself, "pinned", function()
                myself:Hide()
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
    if not ns.notePins or not ns.notePins[noteID] then return end

    local pinFrame = ns.notePins[noteID]
    if not pinFrame or not pinFrame:IsShown() then return end

    local note = ns.NotesData:GetAllNotes()[noteID]
    if not note then return end

    local pinColorKey = note.pinColor or "hunter"
    local colorConfig = ns.Config.PIN_COLORS[pinColorKey] or ns.Config.PIN_COLORS["hunter"]
    local bgColor = colorConfig.background
    local borderColor = colorConfig.border
    local pinAlpha = note.opacity or 0.9

    PinSupport.ApplyOpacityBackdrop(pinFrame, bgColor, pinAlpha, borderColor)
    if pinFrame.hoverControlsPanel and colorConfig.listItem then
        PinSupport.ApplyOpacityBackdrop(pinFrame.hoverControlsPanel, colorConfig.listItem, pinAlpha, borderColor)
    end

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
    if pinFrame.hoverTasksCB then
        pinFrame.hoverTasksCB:SetChecked(note.pinHideTasksUntilHover == true)
    end
    if pinFrame.RefreshTodos then
        pinFrame:RefreshTodos()
    end
end

function NotesPins:RefreshAllPinFonts()
    if not ns.notePins then return end
    for noteID, pinFrame in pairs(ns.notePins) do
        if pinFrame and pinFrame:IsShown() then
            self:RefreshNotePinColors(noteID)
        end
    end
end

function NotesPins:RefreshSyncPins()
    if not ns.notePins then return end

    for noteID, pinFrame in pairs(ns.notePins) do
        if pinFrame and pinFrame:IsShown() then
            local note = ns.NotesData:GetAllNotes()[noteID]
            if note and note.pinColor == "sync" then
                local colorConfig = ns.Config:GetResolvedColorConfig("sync")
                local bgColor = colorConfig.background
                local borderColor = colorConfig.border
                local titleBarColor = colorConfig.titleBar

                local opacity = note.opacity or 0.9
                PinSupport.ApplyOpacityBackdrop(pinFrame, bgColor, opacity, borderColor)
                if pinFrame.hoverControlsPanel and colorConfig.listItem then
                    PinSupport.ApplyOpacityBackdrop(pinFrame.hoverControlsPanel, colorConfig.listItem, opacity, borderColor)
                end

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
