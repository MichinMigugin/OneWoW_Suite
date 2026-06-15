local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["PROFPANEL_TITLE"] = "Professions Panel",
    ["PROFPANEL_DESC"] = "Shows a companion panel alongside the profession window with expansion skill breakdowns, recipe counts, and first craft tracking.",
    ["PROFPANEL_AUTO_SHOW"] = "Auto-Show Panel",
    ["PROFPANEL_TOGGLE_TIP"] = "Profession Stats Panel",
    ["PROFPANEL_HIDE_TIP"] = "Click to hide the panel",
    ["PROFPANEL_SHOW_TIP"] = "Click to show the panel",
    ["PROFPANEL_STATS_TITLE"] = "Professions Panel",
    ["PROFPANEL_NO_EXPANSION_DATA"] = "No expansion data available.\nOpen a profession to scan.",
    ["PROFPANEL_NO_ALT_DATA"] = "No other alts found with this profession",
    ["PROFPANEL_OTHER_ALTS"] = "Other Alts with this Profession",
    ["PROFPANEL_LAST_SCANNED"] = "Last scanned: %s",
})
