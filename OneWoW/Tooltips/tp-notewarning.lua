local ADDON_NAME, OneWoW = ...

local function GetNotesAddon()
    return _G.OneWoW_Notes
end

local function IsNoteWarningEnabled()
    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local cn = db and db.tooltips and db.tooltips.customnotes
    if not cn then return true end
    if cn.showNoteWarning == nil then return true end
    return cn.showNoteWarning == true
end

local function HasNoteContent(noteData)
    if not noteData or type(noteData) ~= "table" then return false end
    return noteData.content and noteData.content ~= ""
end

local function CheckItemNote(itemID)
    local notesAddon = GetNotesAddon()
    if not notesAddon or not notesAddon.db then return false end

    local charItems = notesAddon.db.char and notesAddon.db.char.items
    if charItems and charItems[itemID] and HasNoteContent(charItems[itemID]) then
        return true
    end

    local globalItems = notesAddon.db.global and notesAddon.db.global.items
    if globalItems and globalItems[itemID] and HasNoteContent(globalItems[itemID]) then
        return true
    end

    return false
end

local function CheckPlayerNote(unit)
    if not unit then return false end
    local notesAddon = GetNotesAddon()
    if not notesAddon or not notesAddon.db then return false end

    local name, realm = UnitName(unit)
    if not name then return false end
    if not realm or realm == "" then realm = GetRealmName() or "Unknown" end
    local fullName = name .. "-" .. realm

    local charPlayers = notesAddon.db.char and notesAddon.db.char.players
    if charPlayers and charPlayers[fullName] and HasNoteContent(charPlayers[fullName]) then
        return true
    end

    local globalPlayers = notesAddon.db.global and notesAddon.db.global.players
    if globalPlayers and globalPlayers[fullName] and HasNoteContent(globalPlayers[fullName]) then
        return true
    end

    return false
end

local function CheckNPCNote(npcID)
    local notesAddon = GetNotesAddon()
    if not notesAddon or not notesAddon.db then return false end

    local charNPCs = notesAddon.db.char and notesAddon.db.char.npcs
    if charNPCs and charNPCs[npcID] and HasNoteContent(charNPCs[npcID]) then
        return true
    end

    local globalNPCs = notesAddon.db.global and notesAddon.db.global.npcs
    if globalNPCs and globalNPCs[npcID] and HasNoteContent(globalNPCs[npcID]) then
        return true
    end

    return false
end

local function NoteWarningProvider(tooltip, context)
    if not GetNotesAddon() then return nil end
    if not IsNoteWarningEnabled() then return nil end

    local hasNote = false

    if context.type == "item" and context.itemID then
        hasNote = CheckItemNote(context.itemID)
    elseif context.type == "unit" then
        if context.isPlayer and context.unit then
            hasNote = CheckPlayerNote(context.unit)
        elseif context.npcID then
            hasNote = CheckNPCNote(context.npcID)
        end
    end

    if not hasNote then return nil end

    local config = OneWoW.TooltipEngine.TOOLTIP_CONFIG
    local L = OneWoW.L

    return {
        {type = "text", text = L["TIPS_NOTEWARNING_LINE"], r = config.noteWarningColor[1], g = config.noteWarningColor[2], b = config.noteWarningColor[3]}
    }
end

OneWoW.TooltipEngine:RegisterProvider({
    id = "notewarning",
    order = 9999,
    featureId = "customnotes",
    callback = NoteWarningProvider,
})
