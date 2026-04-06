local ADDON_NAME, OneWoW = ...

local Toasts = OneWoW.Toasts

local COLOR_NPC    = {0.40, 0.70, 1.00, 1.0}
local COLOR_PLAYER = {0.40, 0.70, 1.00, 1.0}
local COLOR_ZONE   = {0.40, 1.00, 0.50, 1.0}

local function GetDB()
    return OneWoW.db and OneWoW.db.global and OneWoW.db.global.toasts
end

local function NotesEnabled()
    local db = GetDB()
    return db and db.notes and db.notes.enabled ~= false
end

local function CategoryEnabled(category)
    local db = GetDB()
    return db and db.notes and db.notes[category] ~= false
end

function OneWoW.Toasts.FireNPCAlert(npcName, npcTexture, location)
    if not NotesEnabled() or not CategoryEnabled("npcs") then return end
    if not npcName or npcName == "" then return end
    Toasts.FireToast({
        toastType = "notes",
        category  = "npc",
        title     = npcName,
        subtitle  = location or nil,
        icon      = npcTexture or "Interface\\Icons\\INV_Misc_QuestionMark",
        color     = COLOR_NPC,
    })
end

function OneWoW.Toasts.FirePlayerAlert(playerName, playerClass, location)
    if not NotesEnabled() or not CategoryEnabled("players") then return end
    if not playerName or playerName == "" then return end
    local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
    if playerClass then
        icon = "Interface\\Icons\\ClassIcon_" .. playerClass
    end
    Toasts.FireToast({
        toastType = "notes",
        category  = "player",
        title     = playerName,
        subtitle  = location or nil,
        icon      = icon,
        color     = COLOR_PLAYER,
    })
end

function OneWoW.Toasts.FireZoneAlert(zoneName, notePreview)
    if not NotesEnabled() or not CategoryEnabled("zones") then return end
    if not zoneName or zoneName == "" then return end
    Toasts.FireToast({
        toastType = "notes",
        category  = "zone",
        title     = zoneName,
        subtitle  = notePreview or nil,
        icon      = "Interface\\Icons\\INV_Misc_Map_01",
        color     = COLOR_ZONE,
    })
end
