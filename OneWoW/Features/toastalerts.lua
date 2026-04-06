local ADDON_NAME, OneWoW = ...

local reg = OneWoW.SettingsFeatureRegistry

reg:Register("toastalerts", { id = "general",        title = "TOAST_GENERAL_TITLE",        description = "TOAST_GENERAL_DESC" })
reg:Register("toastalerts", { id = "detectiontypes", title = "TOAST_DETECTIONTYPES_TITLE", description = "TOAST_DETECTIONTYPES_DESC" })
reg:Register("toastalerts", { id = "instances",      title = "TOAST_INSTANCES_TITLE",      description = "TOAST_INSTANCES_DESC" })
reg:Register("toastalerts", { id = "notealerts",     title = "TOAST_NOTEALERTS_TITLE",     description = "TOAST_NOTEALERTS_DESC" })
reg:Register("toastalerts", { id = "upgrades",       title = "TOAST_UPGRADES_TITLE",       description = "TOAST_UPGRADES_DESC" })
