-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/NotesData.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.NotesData = {}
local NotesData = ns.NotesData

function NotesData:GenerateUniqueID()
    return string.format("%08x-%04x-%04x",
        GetServerTime(),
        math.random(0, 65535),
        math.random(0, 65535))
end

function NotesData:GetNotesDB(storageType)
    local addon = _G.OneWoW_Notes
    if storageType == "character" then
        return addon.db.char.notes
    else
        return addon.db.global.notes
    end
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

    local targetDB = self:GetNotesDB(storageType)
    if not targetDB then
        if storageType == "character" then
            addon.db.char.notes = {}
            targetDB = addon.db.char.notes
        else
            addon.db.global.notes = {}
            targetDB = addon.db.global.notes
        end
    end

    targetDB[noteID] = noteData
    return noteID
end

function NotesData:RemoveNote(noteID)
    local addon = _G.OneWoW_Notes
    if addon.db.global.notes then
        addon.db.global.notes[noteID] = nil
    end
    if addon.db.char.notes then
        addon.db.char.notes[noteID] = nil
    end

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

    local targetDB = self:GetNotesDB(note.storage or "account")
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

function NotesData:GetAllNotes()
    local addon = _G.OneWoW_Notes
    local allNotes = {}

    if addon.db.global.notes then
        for noteID, noteData in pairs(addon.db.global.notes) do
            allNotes[noteID] = noteData
        end
    end

    if addon.db.char.notes then
        for noteID, noteData in pairs(addon.db.char.notes) do
            allNotes[noteID] = noteData
        end
    end

    return allNotes
end

-- Legacy GetNotes kept for backward compatibility
function NotesData:GetNotes()
    return self:GetAllNotes()
end

function NotesData:MigrateDefaultColors()
    local addon = _G.OneWoW_Notes
    if not addon.db or not addon.db.global then return end

    if addon.db.global.colorsMigrated then return end

    local migratedCount = 0
    if addon.db.global.notes then
        for noteID, noteData in pairs(addon.db.global.notes) do
            if noteData and type(noteData) == "table" then
                if noteData.pinColor == "hunter" and noteData.fontColor == "match" then
                    noteData.pinColor = "sync"
                    migratedCount = migratedCount + 1
                end
            end
        end
    end

    if addon.db.char and addon.db.char.notes then
        for noteID, noteData in pairs(addon.db.char.notes) do
            if noteData and type(noteData) == "table" then
                if noteData.pinColor == "hunter" and noteData.fontColor == "match" then
                    noteData.pinColor = "sync"
                    migratedCount = migratedCount + 1
                end
            end
        end
    end

    addon.db.global.colorsMigrated = true
    if migratedCount > 0 then
        print("|cFF00FF00OneWoW_Notes|r: Migrated " .. migratedCount .. " note(s) to OneWoW Sync theme")
    end
end

function NotesData:MigrateFontFamily()
    local addon = _G.OneWoW_Notes
    if not addon.db or not addon.db.global then return end
    if addon.db.global.fontFamilyMigrated then return end

    local GUI = LibStub("OneWoW_GUI-1.0", true)
    if not GUI or not GUI.MigrateLSMFontName then
        addon.db.global.fontFamilyMigrated = true
        return
    end

    local migratedCount = 0
    local function migrateDB(notesDB)
        if not notesDB then return end
        for _, noteData in pairs(notesDB) do
            if noteData and type(noteData) == "table" and noteData.fontFamily then
                local newKey = GUI:MigrateLSMFontName(noteData.fontFamily)
                if newKey then
                    noteData.fontFamily = newKey
                    migratedCount = migratedCount + 1
                end
            end
        end
    end

    migrateDB(addon.db.global.notes)
    if addon.db.char then migrateDB(addon.db.char.notes) end

    addon.db.global.fontFamilyMigrated = true
    if migratedCount > 0 then
        print("|cFF00FF00OneWoW_Notes|r: Migrated " .. migratedCount .. " note font(s) to new font system")
    end
end
