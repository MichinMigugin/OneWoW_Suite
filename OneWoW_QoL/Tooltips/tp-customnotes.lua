local _, ns = ...

local OneWoW = OneWoW

ns.NoteLookup = {}

function ns.NoteLookup.GetNotesAddon()
    return OneWoW_Notes_API
end

function ns.NoteLookup.GetPlayerFullName(unit)
    if not unit then return nil end
    local name, realm = UnitName(unit)
    if not name then return nil end
    if not realm or realm == "" then realm = GetRealmName() or "Unknown" end
    return name .. "-" .. realm
end

-- Notes keeps its SavedVariables on a private namespace (ns.db), not on the
-- OneWoW_Notes lifecycle hub object, so read through the public Notes API. The
-- API getters already resolve the char/global scopes internally.
function ns.NoteLookup.FindNoteData(category, key)
    local api = OneWoW_Notes_API
    if not api then return nil end

    local noteData
    if category == "items" then
        noteData = api.GetItem(key)
    elseif category == "players" then
        noteData = api.GetPlayer(key)
    elseif category == "npcs" then
        noteData = api.GetNPC(key)
    end

    if type(noteData) == "table" then return noteData end
    return nil
end

local function IsSubToggleEnabled(key)
    -- Sub-toggles are dynamic keys (not in the defaults table); absent means on.
    local cn = OneWoW.SettingsFeatureRegistry:GetFeatureSettings("tooltips", "customnotes")
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
    local noteData = ns.NoteLookup.FindNoteData("items", itemID)
    return noteData and GetTooltipLines(noteData) or nil
end

local function LookupPlayerNote(unit)
    local fullName = ns.NoteLookup.GetPlayerFullName(unit)
    if not fullName then return nil end
    local noteData = ns.NoteLookup.FindNoteData("players", fullName)
    return noteData and GetTooltipLines(noteData) or nil
end

local function LookupNPCNote(npcID)
    local noteData = ns.NoteLookup.FindNoteData("npcs", npcID)
    return noteData and GetTooltipLines(noteData) or nil
end

local function CustomNotesProvider(_, context)
    if not ns.NoteLookup.GetNotesAddon() then return nil end

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
