local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["PROFPANEL_TITLE"] = "Berufepanel",
    ["PROFPANEL_DESC"] = "Zeigt ein Begleitpanel neben dem Berufefenster mit Erweiterungs-Fertigkeitsaufschlüsselungen, Rezeptzahlen und Erstherstellungs-Verfolgung an.",
    ["PROFPANEL_AUTO_SHOW"] = "Panel automatisch anzeigen",
    ["PROFPANEL_TOGGLE_TIP"] = "Berufsstatistik-Panel",
    ["PROFPANEL_HIDE_TIP"] = "Klicken, um das Panel auszublenden",
    ["PROFPANEL_SHOW_TIP"] = "Klicken, um das Panel anzuzeigen",
    ["PROFPANEL_STATS_TITLE"] = "Berufepanel",
    ["PROFPANEL_NO_EXPANSION_DATA"] = "Keine Erweiterungsdaten verfügbar.\nÖffne einen Beruf, um zu scannen.",
    ["PROFPANEL_NO_ALT_DATA"] = "Keine anderen Twinks mit diesem Beruf gefunden",
    ["PROFPANEL_OTHER_ALTS"] = "Andere Twinks mit diesem Beruf",
    ["PROFPANEL_LAST_SCANNED"] = "Zuletzt gescannt: %s",
})
