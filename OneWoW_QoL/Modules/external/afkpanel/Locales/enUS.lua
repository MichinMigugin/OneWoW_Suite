local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["AFKPANEL_TITLE"] = "AFK Panel",
    ["AFKPANEL_DESC"] = "Full-screen AFK overlay with the same You and Here cards as the ESC menu, live mail and auction alerts, and optional Daily/Weekly notes when Notes is enabled.",
    ["AFKPANEL_CAMERA_SPIN"] = "Camera Spin",
    ["AFKPANEL_SHOW_DAILY"] = "Show Daily Notes",
    ["AFKPANEL_SHOW_WEEKLY"] = "Show Weekly Notes",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - AFK Mode",
    ["AFKPANEL_CHARACTER_INFO"] = "CHARACTER INFO",
    ["AFKPANEL_ALERTS"] = "ALERTS",
    ["AFKPANEL_NO_ALERTS"] = "No alerts at this time",
    ["AFKPANEL_AFK_TIME"] = "AFK: %s",
    ["AFKPANEL_DAILY_NOTES"] = "DAILY NOTES",
    ["AFKPANEL_WEEKLY_NOTES"] = "WEEKLY NOTES",
    ["AFKPANEL_NO_NOTES"] = "No notes to display",
    ["AFKPANEL_NO_GUILD"] = "No Guild",
})
