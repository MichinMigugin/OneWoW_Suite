local ADDON_NAME, OneWoW = ...

local function GetNotesAddon()
    return _G.OneWoW_Notes
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
    local notesAddon = GetNotesAddon()
    if not notesAddon or not notesAddon.db then return nil end

    local charItems = notesAddon.db.char and notesAddon.db.char.items
    if charItems and charItems[itemID] and type(charItems[itemID]) == "table" then
        local lines = GetTooltipLines(charItems[itemID])
        if lines then return lines end
    end

    local globalItems = notesAddon.db.global and notesAddon.db.global.items
    if globalItems and globalItems[itemID] and type(globalItems[itemID]) == "table" then
        local lines = GetTooltipLines(globalItems[itemID])
        if lines then return lines end
    end

    return nil
end

local function LookupPlayerNote(unit)
    if not unit then return nil end
    local notesAddon = GetNotesAddon()
    if not notesAddon or not notesAddon.db then return nil end

    local name, realm = UnitName(unit)
    if not name then return nil end
    if not realm or realm == "" then realm = GetRealmName() or "Unknown" end
    local fullName = name .. "-" .. realm

    local charPlayers = notesAddon.db.char and notesAddon.db.char.players
    if charPlayers and charPlayers[fullName] and type(charPlayers[fullName]) == "table" then
        local lines = GetTooltipLines(charPlayers[fullName])
        if lines then return lines end
    end

    local globalPlayers = notesAddon.db.global and notesAddon.db.global.players
    if globalPlayers and globalPlayers[fullName] and type(globalPlayers[fullName]) == "table" then
        local lines = GetTooltipLines(globalPlayers[fullName])
        if lines then return lines end
    end

    return nil
end

local function LookupNPCNote(npcID)
    local notesAddon = GetNotesAddon()
    if not notesAddon or not notesAddon.db then return nil end

    local charNPCs = notesAddon.db.char and notesAddon.db.char.npcs
    if charNPCs and charNPCs[npcID] and type(charNPCs[npcID]) == "table" then
        local lines = GetTooltipLines(charNPCs[npcID])
        if lines then return lines end
    end

    local globalNPCs = notesAddon.db.global and notesAddon.db.global.npcs
    if globalNPCs and globalNPCs[npcID] and type(globalNPCs[npcID]) == "table" then
        local lines = GetTooltipLines(globalNPCs[npcID])
        if lines then return lines end
    end

    return nil
end

local function CustomNotesProvider(tooltip, context)
    if not GetNotesAddon() then return nil end

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
