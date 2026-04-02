local addonName, ns = ...
local NotesData = ns.DataModule:New("notes", "notesCustomCategories", {})
ns.NotesData = NotesData

function NotesData:GetNotesDB(storageType) return self:GetDataDB(storageType) end
function NotesData:GetAllNotes() return self:GetAll() end

function NotesData:MigrateDefaultColors() self:MigrateColors("colorsMigrated") end
function NotesData:MigrateFontFamily() self:MigrateFonts("fontFamilyMigrated") end

function NotesData:GenerateUniqueID()
    return string.format("%08x-%04x-%04x",
        GetServerTime(),
        math.random(0, 65535),
        math.random(0, 65535))
end

function NotesData:AddNote(noteTitle, noteData)
    local addon = _G.OneWoW_Notes
    local noteID = self:GenerateUniqueID()
    local storageType = "account"

    if type(noteData) == "table" then
        noteData.id = noteID
        noteData.title = noteTitle
        noteData.todos = noteData.todos or {}
        noteData.tags = noteData.tags or {}
        noteData.tasksOnTop = noteData.tasksOnTop or false
        noteData.pinEnabled = noteData.pinEnabled == nil and false or noteData.pinEnabled
        noteData.manuallyHidden = noteData.manuallyHidden or false
        noteData.alwaysShowOnLogin = noteData.alwaysShowOnLogin or false
        noteData.storage = noteData.storage or "account"
        noteData.category = noteData.category or "General"
        noteData.type = noteData.type or "Note"
        noteData.pinColor = noteData.pinColor or "sync"
        noteData.fontColor = noteData.fontColor or "match"
        noteData.fontFamily = noteData.fontFamily or nil
        noteData.fontSize = noteData.fontSize or 12
        noteData.opacity = noteData.opacity or 0.9
        noteData.favorite = noteData.favorite or false
        noteData.created = noteData.created or GetServerTime()
        noteData.modified = noteData.modified or GetServerTime()
        noteData.noteType = noteData.noteType or "standard"
        noteData.lastReset = noteData.lastReset or 0
        noteData.sortOrder = noteData.sortOrder or 0
        storageType = noteData.storage
    else
        noteData = {
            id = noteID,
            title = noteTitle or "",
            content = "",
            todos = {},
            tags = {},
            tasksOnTop = false,
            pinEnabled = false,
            manuallyHidden = false,
            alwaysShowOnLogin = false,
            storage = "account",
            category = "General",
            type = "Note",
            pinColor = "sync",
            fontColor = "match",
            fontFamily = nil,
            fontSize = 12,
            opacity = 0.9,
            favorite = false,
            created = GetServerTime(),
            modified = GetServerTime(),
            noteType = "standard",
            lastReset = 0,
            sortOrder = 0
        }
    end

    if addon.mainFrame and addon.mainFrame:IsShown() then
        noteData.isNew = true
        noteData.newTimestamp = GetServerTime()
    end

    local targetDB = self:GetDataDB(storageType)
    if not targetDB then
        self:EnsureDB()
        targetDB = self:GetDataDB(storageType)
    end

    targetDB[noteID] = noteData
    self:InvalidateCache()
    return noteID
end

function NotesData:RemoveNote(noteID)
    self:Remove(noteID)

    local addon = _G.OneWoW_Notes
    if addon.notePins and addon.notePins[noteID] then
        local pinFrame = addon.notePins[noteID]
        if pinFrame and pinFrame.Hide then
            pinFrame:Hide()
        end
        addon.notePins[noteID] = nil
    end
end

function NotesData:UpdateNote(noteID, noteContent)
    local note, targetDB = self:FindNote(noteID)

    if note and targetDB then
        if type(note) == "table" then
            note.content = noteContent
            note.modified = GetServerTime()
        end

        local addon = _G.OneWoW_Notes
        if addon.notePins and addon.notePins[noteID] then
            local pinFrame = addon.notePins[noteID]
            if pinFrame and pinFrame.UpdateContent then
                pinFrame:UpdateContent()
            end
        end
    end
end

function NotesData:UpdateNoteTitle(noteID, newTitle)
    local note, targetDB = self:FindNote(noteID)

    if note and targetDB and type(note) == "table" then
        note.title = newTitle
        note.modified = GetServerTime()

        local addon = _G.OneWoW_Notes
        if addon.notePins and addon.notePins[noteID] then
            local pinFrame = addon.notePins[noteID]
            if pinFrame and pinFrame.UpdateContent then
                pinFrame:UpdateContent()
            end
        end

        return true
    end

    return false
end

function NotesData:ToggleFavorite(noteID)
    local note = self:GetAllNotes()[noteID]

    if not note then
        return false
    end

    note.favorite = not (note.favorite or false)

    local targetDB = self:GetDataDB(note.storage or "account")
    if targetDB then
        targetDB[noteID] = note
    end

    return note.favorite
end

function NotesData:SetPinEnabled(noteID, pinEnabled)
    local note, notesDB = self:FindNote(noteID)
    if not note or not notesDB then return end

    if type(note) == "table" then
        note.pinEnabled = pinEnabled
        note.modified = GetServerTime()
    end
end

function NotesData:FindNote(noteID)
    local addon = _G.OneWoW_Notes
    if addon.db.global.notes and addon.db.global.notes[noteID] then
        return addon.db.global.notes[noteID], addon.db.global.notes
    elseif addon.db.char.notes and addon.db.char.notes[noteID] then
        return addon.db.char.notes[noteID], addon.db.char.notes
    end
    return nil, nil
end
