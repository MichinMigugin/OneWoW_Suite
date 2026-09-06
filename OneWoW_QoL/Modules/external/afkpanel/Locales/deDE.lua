local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["AFKPANEL_TITLE"] = "AFK-Panel",
    ["AFKPANEL_DESC"] = "Vollbild-AFK-Overlay mit denselben You- und Here-Karten wie das ESC-Menü, Live-Post- und Auktionswarnungen und optionalen täglichen/wöchentlichen Notizen, wenn Notes aktiv ist.",
    ["AFKPANEL_CAMERA_SPIN"] = "Kameradrehung",
    ["AFKPANEL_SHOW_DAILY"] = "Tägliche Notizen anzeigen",
    ["AFKPANEL_SHOW_WEEKLY"] = "Wöchentliche Notizen anzeigen",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - AFK-Modus",
    ["AFKPANEL_CHARACTER_INFO"] = "CHARAKTERINFO",
    ["AFKPANEL_ALERTS"] = "WARNUNGEN",
    ["AFKPANEL_NO_ALERTS"] = "Derzeit keine Warnungen",
    ["AFKPANEL_AFK_TIME"] = "AFK: %s",
    ["AFKPANEL_DAILY_NOTES"] = "TÄGLICHE NOTIZEN",
    ["AFKPANEL_WEEKLY_NOTES"] = "WÖCHENTLICHE NOTIZEN",
    ["AFKPANEL_NO_NOTES"] = "Keine Notizen anzuzeigen",
    ["AFKPANEL_NO_GUILD"] = "Keine Gilde",
})
