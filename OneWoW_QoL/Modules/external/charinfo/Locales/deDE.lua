local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["CHARINFO_TITLE"] = "Charakter-Infoblatt",
    ["CHARINFO_DESC"] = "Zeigt neben jedem angelegten Gegenstand auf deinem Charakterbogen ein übersichtliches Infopanel mit Gegenstandsstufe (nach Qualität gefärbt), Verzauberungsstatus, Sockelstatus und Haltbarkeit in Prozent.",
    ["CHARINFO_ENCHANTED"] = "Verzaubert",
    ["CHARINFO_MISSING_ENCHANT"] = "Verzauberung fehlt",
    ["CHARINFO_NO_ENCHANT_NEEDED"] = "Keine Verzauberung nötig",
    ["CHARINFO_ALL_SOCKETS_EMPTY"] = "Alle Sockel leer",
    ["CHARINFO_SOME_SOCKETS_EMPTY"] = "Einige Sockel leer",
    ["CHARINFO_ALL_SOCKETS_FILLED"] = "Alle Sockel gefüllt",
    ["CHARINFO_NO_SOCKETS"] = "Keine Sockel",
    ["CHARINFO_TOGGLE_DURABILITY"] = "Haltbarkeit anzeigen",
    ["CHARINFO_TOGGLE_DURABILITY_DESC"] = "Zeigt die Haltbarkeit in Prozent auf den Gegenstandsschaltflächen an",
    ["CHARINFO_TOGGLE_SOCKETS"] = "Symbol für fehlende Sockel anzeigen",
    ["CHARINFO_TOGGLE_SOCKETS_DESC"] = "Zeigt ein Symbol an, wenn Gegenstände keine Sockel haben",
    ["CHARINFO_ENCHANT_SLOTS_HEADER"] = "Verfolgung von Verzauberungsplätzen",
    ["CHARINFO_ENCHANT_SLOTS_DESC"] = "Wähle, welche Ausrüstungsplätze auf Verzauberungen überprüft werden. Deaktivierte Plätze zeigen keine Verzauberungsstatus-Symbole an.",
    ["CHARINFO_SLOT_HEAD"] = "Kopf",
    ["CHARINFO_SLOT_NECK"] = "Hals",
    ["CHARINFO_SLOT_SHOULDER"] = "Schultern",
    ["CHARINFO_SLOT_CHEST"] = "Brust",
    ["CHARINFO_SLOT_WAIST"] = "Taille",
    ["CHARINFO_SLOT_LEGS"] = "Beine",
    ["CHARINFO_SLOT_FEET"] = "Füße",
    ["CHARINFO_SLOT_WRIST"] = "Handgelenke",
    ["CHARINFO_SLOT_HANDS"] = "Hände",
    ["CHARINFO_SLOT_RING1"] = "Ring 1",
    ["CHARINFO_SLOT_RING2"] = "Ring 2",
    ["CHARINFO_SLOT_BACK"] = "Rücken",
    ["CHARINFO_SLOT_MAINHAND"] = "Waffenhand",
    ["CHARINFO_SLOT_OFFHAND"] = "Schildhand",
    ["FEATURES_ON"] = "An",
    ["FEATURES_OFF"] = "Aus",
})
