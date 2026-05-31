-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/lfgpanel/Locales/enUS.lua
local addonName, ns = ...
if not ns.L_enUS then ns.L_enUS = {} end
local L = ns.L_enUS

L["LFGPANEL_TITLE"] = "LFG Lockouts"
L["LFGPANEL_DESC"] = "Shows your current raid and dungeon lockouts in a side panel when the Group Finder is open."
L["LFGPANEL_SHOW_PANEL"] = "Show Lockouts Panel"
L["LFGPANEL_SHOW_PANEL_DESC"] = "Show the lockouts panel when the Group Finder opens."
L["LFGPANEL_FILTER_RESULTS"] = "Filter LFG Results"
L["LFGPANEL_FILTER_RESULTS_DESC"] = "Filter the LFG search results by the selected difficulty."

L["LFGPANEL_DIALOG_TITLE"] = "Lockouts"
L["LFGPANEL_REFRESH"] = "Refresh"
L["LFGPANEL_TT_REFRESH"] = "Refresh Lockouts"
L["LFGPANEL_TT_REFRESH_DESC"] = "Request the latest lockout data from the server."
L["LFGPANEL_TT_TOGGLE"] = "Show Lockouts Panel"
L["LFGPANEL_TT_TOGGLE_DESC"] = "Click to show the lockouts panel."

L["LFGPANEL_FILTER_DIFFICULTY"] = "Difficulty"
L["LFGPANEL_DIFFICULTY_ALL"] = "All Difficulties"
L["LFGPANEL_DIFFICULTY_NORMAL"] = "Normal"
L["LFGPANEL_DIFFICULTY_HEROIC"] = "Heroic"
L["LFGPANEL_DIFFICULTY_MYTHIC"] = "Mythic"
L["LFGPANEL_DIFFICULTY_MYTHICPLUS"] = "Mythic+"
L["LFGPANEL_DIFFICULTY_LFR"] = "LFR"

L["LFGPANEL_CATEGORY_RAIDS"] = "Raids"
L["LFGPANEL_CATEGORY_DUNGEONS"] = "Dungeons"

L["LFGPANEL_NO_LOCKOUTS"] = "No active lockouts."
L["LFGPANEL_NO_LOCKOUTS_FILTERED"] = "No lockouts match the selected difficulty."
L["LFGPANEL_EXPIRED"] = "Expired"
L["LFGPANEL_EXTENDED"] = "Extended"
L["LFGPANEL_TT_EXTENDED"] = "Extended Lockout"
L["LFGPANEL_TT_EXTENDED_DESC"] = "This lockout has been manually extended past its normal reset."

L["LFGPANEL_TIME_DAYS"] = "%dd %dh"
L["LFGPANEL_TIME_HOURS"] = "%dh %dm"
L["LFGPANEL_TIME_MINUTES"] = "%dm"
L["LFGPANEL_PROGRESS"] = "%d/%d"

L["LFGPANEL_TT_LOCKOUT"] = "Instance Lockout"
L["LFGPANEL_TT_LOCKOUT_PROGRESS"] = "Boss Progress: %d/%d"
L["LFGPANEL_TT_LOCKOUT_TIME"] = "Resets in: %s"
L["LFGPANEL_TT_LOCKOUT_DIFFICULTY"] = "Difficulty: %s"

L["LFGPANEL_OPT_FILTER_LFG"] = "Filter LFG Results"
L["LFGPANEL_TT_FILTER_LFG"] = "Filter LFG Results"
L["LFGPANEL_TT_FILTER_LFG_DESC"] = "When enabled, the LFG search results will be filtered to match your selected difficulty."
