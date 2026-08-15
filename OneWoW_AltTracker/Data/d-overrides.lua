local _, ns = ...

-- Static baseline for the progress "override" lists. SavedVariables stores only
-- user customizations; when absent, accessors fall back to these values. Bump
-- these each season instead of seeding SavedVariables.
ns.OverrideDefaults = {
    progress = {
        trackedCurrencyIDs = {3442, 3443, 3444, 3440, 3446, 3303, 3309, 3378, 3379, 3385, 3316, 3310, 3405},
        worldBossQuestIDs = {92123, 92560, 92636, 92034, 96472, 96473, 97128},
        -- Zone weeklies (any-of), not season metas 95842/95843: those stay
        -- IsQuestFlaggedCompleted after the intro and are not a weekly signal.
        -- Void Assaults: 94385 Eversong / 94386 Zul'Aman (one active per week).
        -- Ritual Sites: meta 95843 only known ID; collector prefers objectives.
        weeklyActivityQuests = {
            {
                key = "voidAssaults",
                localeKey = "PROGRESS_VOID_ASSAULTS",
                questIDs = {94385, 94386},
                mode = "any",
            },
            {
                key = "ritualSites",
                localeKey = "PROGRESS_RITUAL_SITES",
                questIDs = {95843},
                mode = "any",
            },
        },
    },
}
