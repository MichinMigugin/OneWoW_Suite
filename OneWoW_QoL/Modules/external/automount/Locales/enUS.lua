local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["AUTOMOUNT_TITLE"] = "Auto Mount",
    ["AUTOMOUNT_DESC"] = "Automatically mounts with the fastest available mount when you stop moving in a mountable area. Re-mounts after gathering.",
    ["AUTOMOUNT_MOUNT_PREFS"] = "Mount Preferences",
    ["AUTOMOUNT_GROUND_LABEL"] = "Ground Mount",
    ["AUTOMOUNT_FLYING_LABEL"] = "Flying Mount",
    ["AUTOMOUNT_AQUATIC_LABEL"] = "Aquatic Mount",
    ["AUTOMOUNT_CAT_ON"] = "On",
    ["AUTOMOUNT_CAT_OFF"] = "Off",
    ["AUTOMOUNT_RANDOM_FAVORITE"] = "Random Favorite",
    ["AUTOMOUNT_SELECT_TITLE"] = "Select %s Mount",
    ["AUTOMOUNT_SELECT_TOOLTIP"] = "Click to select a mount",
    ["AUTOMOUNT_SELECT_TOOLTIP_DESC"] = "Choose a specific mount or let auto-select pick the fastest available.",
    ["AUTOMOUNT_DRUID_SECTION"] = "Druid",
    ["AUTOMOUNT_DRUID_MODE_LABEL"] = "Druid Mode",
    ["AUTOMOUNT_DRUID_MODE_DESC"] = "When enabled, auto-mounting is skipped so you can shift into Travel Form manually after gathering.",
    ["AUTOMOUNT_STATUS_LABEL"] = "Mount Status",
    ["AUTOMOUNT_STATUS_READY"] = "Ready to mount",
    ["AUTOMOUNT_STATUS_MOUNTED"] = "Currently mounted",
    ["AUTOMOUNT_STATUS_DISABLED"] = "Auto Mount is disabled",
    ["AUTOMOUNT_TIMING_SECTION"] = "Timing",
    ["AUTOMOUNT_DISMOUNT_DELAY"] = "Dismount Delay",
    ["AUTOMOUNT_DISMOUNT_DELAY_DESC"] = "How long after dismounting before auto-mount resumes.",
    ["AUTOMOUNT_FISHING_DELAY"] = "Fishing Delay",
    ["AUTOMOUNT_FISHING_DELAY_DESC"] = "How long after fishing before auto-mount resumes.",
    ["AUTOMOUNT_GATHER_DELAY"] = "Gather Remount Delay",
    ["AUTOMOUNT_GATHER_DELAY_DESC"] = "How quickly to remount after gathering.",
    ["AUTOMOUNT_DRUID_CANCEL_LABEL"] = "Auto-cancel Travel Form",
    ["AUTOMOUNT_DRUID_CANCEL_DESC"] = "Automatically cancels Travel Form when you enter a flyable area, allowing you to mount a flying mount instead.",
})
