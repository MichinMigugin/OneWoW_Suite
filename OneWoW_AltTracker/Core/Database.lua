local addonName, ns = ...

ns.DatabaseDefaults = {
    global = {
        language = GetLocale(),
        theme = "green",

        mainFrameSize = {
            width = 1400,
            height = 900
        },

        mainFramePosition = nil,

        altTrackerSettings = {
            enablePlaytimeTracking = true,
            enableDataCollection = true,
        },

        minimap = {
            hide = false,
            minimapPos = 220,
            theme = "horde",
        },

        migrationStatus = {
            checkedForWoWNotesData = false,
            lastMigrationCheck = 0,
            migratedCharacterCount = 0,
            migrationComplete = false,
            cleanupPerformed = false,
            migratedToDistributed = false,
            subAddonsAvailable = {}
        },

        overrides = {
            progress = {
                trackedCurrencyIDs = {3383, 3341, 3343, 3345, 3347, 3303, 3309, 3378, 3379, 3385, 3316},
                worldBossQuestIDs = {},
            }
        },

        favorites = {},
        seasonChecklist = {}
    },

}
