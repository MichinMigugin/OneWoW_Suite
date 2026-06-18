local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["LFGPANEL_TITLE"] = "LFG Lockouts",
    ["LFGPANEL_DESC"] = "Shows your current raid and dungeon lockouts in a side panel when the Group Finder is open.",
    ["LFGPANEL_SHOW_PANEL"] = "Show Lockouts Panel",
    ["LFGPANEL_SHOW_PANEL_DESC"] = "Show the lockouts panel when the Group Finder opens.",
    ["LFGPANEL_FILTER_RESULTS"] = "Filter LFG Results",
    ["LFGPANEL_FILTER_RESULTS_DESC"] = "Filter the LFG search results by the selected difficulty.",

    ["LFGPANEL_TT_REFRESH"] = "Refresh Lockouts",
    ["LFGPANEL_TT_REFRESH_DESC"] = "Request the latest lockout data from the server.",
    ["LFGPANEL_TT_TOGGLE"] = "Show Lockouts Panel",
    ["LFGPANEL_TT_TOGGLE_DESC"] = "Click to show the lockouts panel.",

    ["LFGPANEL_FILTER_DIFFICULTY"] = "Difficulty",
    ["LFGPANEL_DIFFICULTY_NORMAL"] = "Normal",
    ["LFGPANEL_DIFFICULTY_HEROIC"] = "Heroic",
    ["LFGPANEL_DIFFICULTY_MYTHIC"] = "Mythic",
    ["LFGPANEL_DIFFICULTY_MYTHICPLUS"] = "Mythic+",
    ["LFGPANEL_DIFFICULTY_LFR"] = "LFR",

    ["LFGPANEL_NO_LOCKOUTS"] = "No active lockouts.",
    ["LFGPANEL_NO_LOCKOUTS_FILTERED"] = "No lockouts match the selected difficulty.",
    ["LFGPANEL_EXPIRED"] = "Expired",
    ["LFGPANEL_EXTENDED"] = "Extended",
    ["LFGPANEL_TT_EXTENDED"] = "Extended Lockout",
    ["LFGPANEL_TT_EXTENDED_DESC"] = "This lockout has been manually extended past its normal reset.",

    ["LFGPANEL_TIME_DAYS"] = "%dd %dh",
    ["LFGPANEL_TIME_HOURS"] = "%dh %dm",
    ["LFGPANEL_TIME_MINUTES"] = "%dm",
    ["LFGPANEL_PROGRESS"] = "%d/%d",

    ["LFGPANEL_TT_LOCKOUT"] = "Instance Lockout",
    ["LFGPANEL_TT_LOCKOUT_PROGRESS"] = "Boss Progress: %d/%d",
    ["LFGPANEL_TT_LOCKOUT_TIME"] = "Resets in: %s",
    ["LFGPANEL_TT_LOCKOUT_DIFFICULTY"] = "Difficulty: %s",

    ["LFGPANEL_OPT_FILTER_LFG"] = "Filter LFG Results",
    ["LFGPANEL_TT_FILTER_LFG"] = "Filter LFG Results",
    ["LFGPANEL_TT_FILTER_LFG_DESC"] = "When enabled, the LFG search results will be filtered to match your selected difficulty.",
})
