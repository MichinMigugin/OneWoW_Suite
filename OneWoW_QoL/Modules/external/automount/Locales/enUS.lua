-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/automount/Locales/enUS.lua
local addonName, ns = ...
if not ns.L_enUS then ns.L_enUS = {} end
local L = ns.L_enUS

L["AUTOMOUNT_TITLE"]               = "Auto Mount"
L["AUTOMOUNT_DESC"]                = "Automatically mounts with the fastest available mount when you stop moving in a mountable area. Re-mounts after gathering."
L["AUTOMOUNT_MOUNT_PREFS"]         = "Mount Preferences"
L["AUTOMOUNT_GROUND_LABEL"]        = "Ground Mount:"
L["AUTOMOUNT_FLYING_LABEL"]        = "Flying Mount:"
L["AUTOMOUNT_AQUATIC_LABEL"]       = "Aquatic Mount:"
L["AUTOMOUNT_CAT_ON"]              = "On"
L["AUTOMOUNT_CAT_OFF"]             = "Off"
L["AUTOMOUNT_RANDOM_FAVORITE"]     = "Random Favorite"
L["AUTOMOUNT_SELECT_TITLE"]        = "Select %s Mount"
L["AUTOMOUNT_SEARCH"]              = "Search..."
L["AUTOMOUNT_SELECT_TOOLTIP"]      = "Click to select a mount"
L["AUTOMOUNT_SELECT_TOOLTIP_DESC"] = "Choose a specific mount or let auto-select pick the fastest available."
L["AUTOMOUNT_CLOSE"]               = "Close"
L["AUTOMOUNT_DRUID_SECTION"]       = "Druid"
L["AUTOMOUNT_DRUID_MODE_LABEL"]    = "Druid Mode:"
L["AUTOMOUNT_DRUID_MODE_DESC"]     = "When enabled, auto-mounting is skipped so you can shift into Travel Form manually after gathering."
L["AUTOMOUNT_DRUID_CANCEL_LABEL"]  = "Auto-cancel Travel Form:"
L["AUTOMOUNT_DRUID_CANCEL_DESC"]   = "Automatically cancels Travel Form when you enter a flyable area, allowing you to mount a flying mount instead."
