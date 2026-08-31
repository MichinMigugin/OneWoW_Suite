local _, ns = ...

local Search = OneWoW.Search
local SR = OneWoW.SearchRegistry

local function TrackersSettingsPath(leafKey)
    return {
        SR.ModuleLabel("settings"),
        SR.TabLabel("settings", "trackers"),
        function() return ns.L[leafKey] end,
    }
end

local settingsNav = { module = "settings", subtab = "trackers" }

Search:Register({
    id = "trackers:pinned-scale",
    title = "SETTINGS_PINNED_SCALE",
    description = "SETTINGS_PINNED_SCALE_DESC",
    scope = "OneWoW_Trackers",
    tags = { "scale", "pinned", "window" },
    addonKey = "OneWoW_Trackers",
    path = TrackersSettingsPath("SETTINGS_PINNED_SCALE"),
    nav = settingsNav,
})

Search:Register({
    id = "trackers:weekly-reset",
    title = "SETTINGS_RESET_TITLE",
    description = "SETTINGS_RESET_DESC",
    scope = "OneWoW_Trackers",
    tags = { "weekly", "reset", "region" },
    addonKey = "OneWoW_Trackers",
    path = TrackersSettingsPath("SETTINGS_RESET_TITLE"),
    nav = settingsNav,
})
