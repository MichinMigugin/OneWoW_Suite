local _, ns = ...

-- Static baseline for the progress "override" lists. SavedVariables stores only
-- user customizations; when absent, accessors fall back to these values. Bump
-- these each season instead of seeding SavedVariables.
ns.OverrideDefaults = {
    progress = {
        trackedCurrencyIDs = {3383, 3341, 3343, 3345, 3347, 3303, 3309, 3378, 3379, 3385, 3316, 3310, 3405},
        worldBossQuestIDs = {92123, 92560, 92636, 92034, 96472, 96473},
        weeklyActivityQuests = {
            {questID = 95842, key = "voidAssaults", name = "Void Assaults"},
            {questID = 95843, key = "ritualSites",  name = "Ritual Sites"},
        },
    },
}
