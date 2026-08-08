local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["AUTOMOUNT_TITLE"] = "Auto-Reittier",
    ["AUTOMOUNT_DESC"] = "Ruft automatisch das schnellste verfügbare Reittier, wenn du dich in einem berittenen Gebiet nicht mehr bewegst. Steigt nach dem Sammeln erneut auf.",
    ["AUTOMOUNT_MOUNT_PREFS"] = "Reittier-Einstellungen",
    ["AUTOMOUNT_GROUND_LABEL"] = "Bodenreittier",
    ["AUTOMOUNT_FLYING_LABEL"] = "Flugreittier",
    ["AUTOMOUNT_AQUATIC_LABEL"] = "Wasserreittier",
    ["AUTOMOUNT_CAT_ON"] = "An",
    ["AUTOMOUNT_CAT_OFF"] = "Aus",
    ["AUTOMOUNT_RANDOM_FAVORITE"] = "Zufälliger Favorit",
    ["AUTOMOUNT_SELECT_TITLE"] = "%s-Reittier wählen",
    ["AUTOMOUNT_SELECT_TOOLTIP"] = "Klicken, um ein Reittier zu wählen",
    ["AUTOMOUNT_SELECT_TOOLTIP_DESC"] = "Wähle ein bestimmtes Reittier oder lass die Auto-Auswahl das schnellste verfügbare wählen.",
    ["AUTOMOUNT_DRUID_SECTION"] = "Druide",
    ["AUTOMOUNT_DRUID_MODE_LABEL"] = "Druidenmodus",
    ["AUTOMOUNT_DRUID_MODE_DESC"] = "Wenn aktiviert, wird das Auto-Aufsteigen übersprungen, damit du nach dem Sammeln manuell in die Reisegestalt wechseln kannst.",
    ["AUTOMOUNT_STATUS_LABEL"] = "Reittierstatus",
    ["AUTOMOUNT_STATUS_READY"] = "Bereit zum Aufsteigen",
    ["AUTOMOUNT_STATUS_MOUNTED"] = "Derzeit aufgestiegen",
    ["AUTOMOUNT_STATUS_DISABLED"] = "Auto-Reittier ist deaktiviert",
    ["AUTOMOUNT_TIMING_SECTION"] = "Zeitsteuerung",
    ["AUTOMOUNT_DISMOUNT_DELAY"] = "Verzögerung beim Absteigen",
    ["AUTOMOUNT_DISMOUNT_DELAY_DESC"] = "Wie lange nach dem Absteigen, bis das Auto-Aufsteigen fortgesetzt wird.",
    ["AUTOMOUNT_FISHING_DELAY"] = "Angelverzögerung",
    ["AUTOMOUNT_FISHING_DELAY_DESC"] = "Wie lange nach dem Angeln, bis das Auto-Aufsteigen fortgesetzt wird.",
    ["AUTOMOUNT_GATHER_DELAY"] = "Verzögerung für Wiederaufsteigen beim Sammeln",
    ["AUTOMOUNT_GATHER_DELAY_DESC"] = "Wie schnell nach dem Sammeln wieder aufgestiegen wird.",
    ["AUTOMOUNT_DRUID_CANCEL_LABEL"] = "Reisegestalt automatisch abbrechen",
    ["AUTOMOUNT_DRUID_CANCEL_DESC"] = "Bricht die Reisegestalt automatisch ab, wenn du ein flugfähiges Gebiet betrittst, sodass du stattdessen ein Flugreittier rufen kannst.",
})
