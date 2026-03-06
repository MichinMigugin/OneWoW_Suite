-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/Database.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.DatabaseDefaults = {
    global = {
        language             = nil,
        theme                = "green",
        lastTab              = "notes",
        mainFrameSize        = nil,
        mainFramePosition    = nil,
        minimap              = { hide = false, minimapPos = 220, theme = "horde" },
        notes                = {},
        playerNotes          = {},
        npcNotes             = {},
        zoneNotes            = {},
        itemNotes            = {},
        items                = {},
        zones                = {},
        players              = {},
        npcs                 = {},
        notesCustomCategories = {},
        itemCustomCategories  = {},
        zoneCustomCategories  = {},
        playerCustomCategories = {},
        npcCustomCategories   = {},
        notePinPositions      = {},
        zonePinPositions      = {},
        guides                = {},
        guideTrackerPosition  = nil,
        routines              = {},
        sortCompletedTasks    = false,
        zoneAlertsEnabled     = true,
        npcScanEnabled        = true,
        playerScanEnabled     = true,
    },
    char = {
        notes         = {},
        items         = {},
        zones         = {},
        players       = {},
        npcs          = {},
        guideProgress = {},
        routineProgress = {},
        routineLastWeek = 0,
    },
}
