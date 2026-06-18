local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["LFGPANEL_TITLE"] = "LFG-Sperrungen",
    ["LFGPANEL_DESC"] = "Zeigt deine aktuellen Schlachtzugs- und Dungeon-Sperrungen in einem Seitenpanel an, wenn die Gruppensuche geöffnet ist.",
    ["LFGPANEL_SHOW_PANEL"] = "Sperrungspanel anzeigen",
    ["LFGPANEL_SHOW_PANEL_DESC"] = "Zeigt das Sperrungspanel an, wenn die Gruppensuche geöffnet wird.",
    ["LFGPANEL_FILTER_RESULTS"] = "LFG-Ergebnisse filtern",
    ["LFGPANEL_FILTER_RESULTS_DESC"] = "Filtert die LFG-Suchergebnisse nach der gewählten Schwierigkeit.",

    ["LFGPANEL_TT_REFRESH"] = "Sperrungen aktualisieren",
    ["LFGPANEL_TT_REFRESH_DESC"] = "Fordert die neuesten Sperrungsdaten vom Server an.",
    ["LFGPANEL_TT_TOGGLE"] = "Sperrungspanel anzeigen",
    ["LFGPANEL_TT_TOGGLE_DESC"] = "Klicken, um das Sperrungspanel anzuzeigen.",

    ["LFGPANEL_FILTER_DIFFICULTY"] = "Schwierigkeit",
    ["LFGPANEL_DIFFICULTY_NORMAL"] = "Normal",
    ["LFGPANEL_DIFFICULTY_HEROIC"] = "Heroisch",
    ["LFGPANEL_DIFFICULTY_MYTHIC"] = "Mythisch",
    ["LFGPANEL_DIFFICULTY_MYTHICPLUS"] = "Mythisch+",
    ["LFGPANEL_DIFFICULTY_LFR"] = "LFR",

    ["LFGPANEL_NO_LOCKOUTS"] = "Keine aktiven Sperrungen.",
    ["LFGPANEL_NO_LOCKOUTS_FILTERED"] = "Keine Sperrungen entsprechen der gewählten Schwierigkeit.",
    ["LFGPANEL_EXPIRED"] = "Abgelaufen",
    ["LFGPANEL_EXTENDED"] = "Verlängert",
    ["LFGPANEL_TT_EXTENDED"] = "Verlängerte Sperrung",
    ["LFGPANEL_TT_EXTENDED_DESC"] = "Diese Sperrung wurde manuell über ihre normale Zurücksetzung hinaus verlängert.",

    ["LFGPANEL_TIME_DAYS"] = "%dd %dh",
    ["LFGPANEL_TIME_HOURS"] = "%dh %dm",
    ["LFGPANEL_TIME_MINUTES"] = "%dm",
    ["LFGPANEL_PROGRESS"] = "%d/%d",

    ["LFGPANEL_TT_LOCKOUT"] = "Instanzsperrung",
    ["LFGPANEL_TT_LOCKOUT_PROGRESS"] = "Bossfortschritt: %d/%d",
    ["LFGPANEL_TT_LOCKOUT_TIME"] = "Zurücksetzung in: %s",
    ["LFGPANEL_TT_LOCKOUT_DIFFICULTY"] = "Schwierigkeit: %s",

    ["LFGPANEL_OPT_FILTER_LFG"] = "LFG-Ergebnisse filtern",
    ["LFGPANEL_TT_FILTER_LFG"] = "LFG-Ergebnisse filtern",
    ["LFGPANEL_TT_FILTER_LFG_DESC"] = "Wenn aktiviert, werden die LFG-Suchergebnisse passend zu deiner gewählten Schwierigkeit gefiltert.",
})
