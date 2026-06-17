local _, ns = ...

local OneWoW = OneWoW

local function IsNoteWarningEnabled()
    -- showNoteWarning is a dynamic key (not in the defaults table); absent means on.
    local cn = OneWoW.SettingsFeatureRegistry:GetFeatureSettings("tooltips", "customnotes")
    if cn.showNoteWarning == nil then return true end
    return cn.showNoteWarning == true
end

local function HasNoteContent(noteData)
    if not noteData or type(noteData) ~= "table" then return false end
    return noteData.content and noteData.content ~= ""
end

local function CheckItemNote(itemID)
    local noteData = ns.NoteLookup.FindNoteData("items", itemID)
    return noteData and HasNoteContent(noteData) or false
end

local function CheckPlayerNote(unit)
    local fullName = ns.NoteLookup.GetPlayerFullName(unit)
    if not fullName then return false end
    local noteData = ns.NoteLookup.FindNoteData("players", fullName)
    return noteData and HasNoteContent(noteData) or false
end

local function CheckNPCNote(npcID)
    local noteData = ns.NoteLookup.FindNoteData("npcs", npcID)
    return noteData and HasNoteContent(noteData) or false
end

local function NoteWarningProvider(_, context)
    if not ns.NoteLookup.GetNotesAddon() then return nil end
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
    local L = ns.L

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
