-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/NotesTodos.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local NotesTodos = {}
ns.NotesTodos = NotesTodos

function NotesTodos:AddTodo(noteID, todoText)
    local NotesData = ns.NotesData
    local note, notesDB = NotesData:FindNote(noteID)
    if not note or not notesDB then return end

    if not note.todos then
        note.todos = {}
    end

    local todo = {
        id = math.random(100000, 999999),
        text = todoText,
        completed = false,
        created = GetServerTime()
    }

    table.insert(note.todos, todo)
    note.modified = GetServerTime()

    if note.autoPinEnabled and note.autoUnpinned and not todo.completed then
        note.autoUnpinned = false
        note.pinEnabled = true
        if ns.NotesPins then
            ns.NotesPins:ShowNotePin(noteID)
        end
    end

    local addon = _G.OneWoW_Notes
    if addon.notePins and addon.notePins[noteID] then
        local pinFrame = addon.notePins[noteID]
        if pinFrame and pinFrame.RefreshLayout then
            pinFrame:RefreshLayout()
        end
    end

    return todo
end

function NotesTodos:RemoveTodo(noteID, todoId)
    local NotesData = ns.NotesData
    local note, notesDB = NotesData:FindNote(noteID)
    if not note or not notesDB or type(note) ~= "table" then return end

    for i, todo in ipairs(note.todos) do
        if todo.id == todoId then
            table.remove(note.todos, i)
            note.modified = GetServerTime()

            local addon = _G.OneWoW_Notes
            if addon.notePins and addon.notePins[noteID] then
                local pinFrame = addon.notePins[noteID]
                if pinFrame and pinFrame.RefreshLayout then
                    pinFrame:RefreshLayout()
                end
            end

            return true
        end
    end
    return false
end

function NotesTodos:UpdateTodo(noteID, todoId, newText, completed)
    local NotesData = ns.NotesData
    local note, notesDB = NotesData:FindNote(noteID)
    if not note or not notesDB or type(note) ~= "table" then return end

    for _, todo in ipairs(note.todos) do
        if todo.id == todoId then
            if newText ~= nil then todo.text = newText end
            if completed ~= nil then todo.completed = completed end
            note.modified = GetServerTime()

            local addon = _G.OneWoW_Notes
            if addon.notePins and addon.notePins[noteID] then
                local pinFrame = addon.notePins[noteID]
                if pinFrame and pinFrame.RefreshTodos then
                    pinFrame:RefreshTodos()
                end
            end

            return true
        end
    end
    return false
end

function NotesTodos:AreAllTodosCompleted(noteID)
    local NotesData = ns.NotesData
    local note, notesDB = NotesData:FindNote(noteID)
    if not note or type(note) ~= "table" then return false end

    if not note.todos or type(note.todos) ~= "table" then return false end

    if #note.todos == 0 then return false end

    for _, todo in ipairs(note.todos) do
        if not todo.completed then
            return false
        end
    end

    return true
end

function NotesTodos:CheckAndPerformResets()
    if not ns.NotesData then return end

    local secondsUntilDaily  = GetQuestResetTime()
    local lastDailyResetTime = GetServerTime() + secondsUntilDaily - 86400

    local secondsUntilWeekly  = C_DateAndTime.GetSecondsUntilWeeklyReset()
    local lastWeeklyResetTime = GetServerTime() + secondsUntilWeekly - 604800

    local allNotes  = ns.NotesData:GetAllNotes()
    local addon     = _G.OneWoW_Notes
    local anyReset  = false

    for noteID, note in pairs(allNotes) do
        if type(note) == "table" then
            local noteType  = note.noteType or "standard"
            local lastReset = note.lastReset or 0
            local resetTime = nil

            if noteType == "daily" and lastDailyResetTime > lastReset then
                resetTime = lastDailyResetTime
            elseif noteType == "weekly" and lastWeeklyResetTime > lastReset then
                resetTime = lastWeeklyResetTime
            end

            if resetTime then
                if lastReset == 0 then
                    note.lastReset = resetTime
                else
                    if note.todos and #note.todos > 0 then
                        for _, todo in ipairs(note.todos) do
                            todo.completed = false
                        end
                        anyReset = true
                    end
                    note.lastReset   = GetServerTime()
                    note.autoUnpinned = false

                    if note.pinEnabled and ns.NotesPins then
                        ns.NotesPins:ShowNotePin(noteID)
                    end

                    if addon.notePins and addon.notePins[noteID] then
                        local pinFrame = addon.notePins[noteID]
                        if pinFrame and pinFrame.RefreshTodos then
                            pinFrame:RefreshTodos()
                        end
                    end
                end
            end
        end
    end

    if anyReset then
        if ns.UI and ns.UI.notesFrame and ns.UI.notesFrame.RefreshTodoList then
            ns.UI.notesFrame.RefreshTodoList()
        end
    end
end
