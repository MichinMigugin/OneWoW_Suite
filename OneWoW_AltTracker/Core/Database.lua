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
            cleanupPerformed = false,
        },

        overrides = {
            progress = {
                trackedCurrencyIDs = {3383, 3341, 3343, 3345, 3347, 3303, 3309, 3378, 3379, 3385, 3316, 3310},
                worldBossQuestIDs = {92123, 92560, 92636, 92034},
            }
        },

        favorites = {},
        favoriteBarSets = {},
        favoriteItems   = {},
        seasonChecklist = {}
    },

}
