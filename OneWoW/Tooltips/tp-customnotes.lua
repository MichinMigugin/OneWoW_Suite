local ADDON_NAME, OneWoW = ...

OneWoW.NoteLookup = {}

function OneWoW.NoteLookup.GetNotesAddon()
    return _G.OneWoW_Notes
end

function OneWoW.NoteLookup.GetPlayerFullName(unit)
    if not unit then return nil end
    local name, realm = UnitName(unit)
    if not name then return nil end
    if not realm or realm == "" then realm = GetRealmName() or "Unknown" end
    return name .. "-" .. realm
end

function OneWoW.NoteLookup.FindNoteData(category, key)
    local notesAddon = OneWoW.NoteLookup.GetNotesAddon()
    if not notesAddon or not notesAddon.db then return nil end

    local charData = notesAddon.db.char and notesAddon.db.char[category]
    if charData and charData[key] and type(charData[key]) == "table" then
        return charData[key]
    end

    local globalData = notesAddon.db.global and notesAddon.db.global[category]
    if globalData and globalData[key] and type(globalData[key]) == "table" then
        return globalData[key]
    end

    return nil
end

local function IsSubToggleEnabled(key)
    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local cn = db and db.tooltips and db.tooltips.customnotes
    if not cn then return true end
    if cn[key] == nil then return true end
    return cn[key] == true
end

local function GetTooltipLines(noteData)
    if not noteData or type(noteData) ~= "table" then return nil end
    local tl = noteData.tooltipLines
    if not tl then return nil end

    local lines = {}
    for i = 1, 4 do
        if tl[i] and tl[i] ~= "" then
            table.insert(lines, tl[i])
        end
    end

    if #lines == 0 then return nil end
    return lines
end

local function LookupItemNote(itemID)
    local noteData = OneWoW.NoteLookup.FindNoteData("items", itemID)
    return noteData and GetTooltipLines(noteData) or nil
end

local function LookupPlayerNote(unit)
    local fullName = OneWoW.NoteLookup.GetPlayerFullName(unit)
    if not fullName then return nil end
    local noteData = OneWoW.NoteLookup.FindNoteData("players", fullName)
    return noteData and GetTooltipLines(noteData) or nil
end

local function LookupNPCNote(npcID)
    local noteData = OneWoW.NoteLookup.FindNoteData("npcs", npcID)
    return noteData and GetTooltipLines(noteData) or nil
end

local function CustomNotesProvider(tooltip, context)
    if not OneWoW.NoteLookup.GetNotesAddon() then return nil end

    local config = OneWoW.TooltipEngine.TOOLTIP_CONFIG
    local noteLines = nil

    if context.type == "item" and context.itemID then
        if not IsSubToggleEnabled("showItemNotes") then return nil end
        noteLines = LookupItemNote(context.itemID)

    elseif context.type == "unit" then
        if context.isPlayer and context.unit then
            if not IsSubToggleEnabled("showPlayerNotes") then return nil end
            noteLines = LookupPlayerNote(context.unit)
        elseif context.npcID then
            if not IsSubToggleEnabled("showNpcNotes") then return nil end
            noteLines = LookupNPCNote(context.npcID)
        end
    end

    if not noteLines then return nil end

    local results = {}
    for _, line in ipairs(noteLines) do
        table.insert(results, {
            type = "text",
            text = "  " .. line,
            r = config.noteWarningColor[1],
            g = config.noteWarningColor[2],
            b = config.noteWarningColor[3],
        })
    end

    return results
end

OneWoW.TooltipEngine:RegisterProvider({
    id = "customnotes",
    order = 9998,
    featureId = "customnotes",
    callback = CustomNotesProvider,
})
