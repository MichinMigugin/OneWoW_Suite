local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["FRAMEMOVER_TITLE"] = "Fenster-Mover",
    ["FRAMEMOVER_DESC"] = "Ziehe Blizzard-Benutzeroberflächenfenster, um sie neu zu positionieren. Verwende Strg+Scrollen zum Skalieren. Halte Alt beim Ziehen, um Fenster teilweise aus dem Bildschirm zu bewegen, wenn „Am Bildschirm festhalten“ aktiv ist. Positionen und Skalierungen können sitzungsübergreifend erhalten bleiben.",

    ["FRAMEMOVER_TOGGLE_REQUIRE_SHIFT"] = "Umschalt zum Ziehen erforderlich",
    ["FRAMEMOVER_TOGGLE_ENABLE_SCALING"] = "Strg+Scrollen-Skalierung",
    ["FRAMEMOVER_TOGGLE_SAVE_POSITIONS"] = "Positionen merken",
    ["FRAMEMOVER_TOGGLE_SAVE_SCALES"] = "Skalierungen merken",
    ["FRAMEMOVER_TOGGLE_CLAMP_SCREEN"] = "Am Bildschirm festhalten",
    ["FRAMEMOVER_TOGGLE_MODIFY_HUD"] = "Skalierungs-Popup anzeigen",

    ["FRAMEMOVER_GROUP_BEHAVIOR"] = "Verhalten",
    ["FRAMEMOVER_GROUP_SAVING"] = "Beständigkeit",

    ["FRAMEMOVER_CAT_CORE"] = "Kern-UI",
    ["FRAMEMOVER_CAT_COLLECTIONS"] = "Sammlungen & Journale",
    ["FRAMEMOVER_CAT_PROFESSIONS"] = "Berufe & Wirtschaft",
    ["FRAMEMOVER_CAT_GROUP"] = "Gruppeninhalte",
    ["FRAMEMOVER_CAT_CHARACTER"] = "Charakter & Talente",
    ["FRAMEMOVER_CAT_SOCIAL"] = "Soziales & Gilden",
    ["FRAMEMOVER_CAT_MISC"] = "Verschiedenes",
    ["FRAMEMOVER_CAT_HOUSING"] = "Wohnraum",

    ["FRAMEMOVER_FRAMES_HEADER"] = "Bewegliche Fenster",
    ["FRAMEMOVER_FILTER_EMPTY"] = "Keine Fenster entsprechen deiner Suche.",
    ["FRAMEMOVER_RESET_POSITIONS"] = "Alle Positionen zurücksetzen",
    ["FRAMEMOVER_RESET_SCALES"] = "Alle Skalierungen zurücksetzen",
    ["FRAMEMOVER_RESET_POS_DONE"] = "Positionen zurückgesetzt. Öffne die Fenster erneut, um die Standardwerte zu sehen.",
    ["FRAMEMOVER_RESET_SCALE_DONE"] = "Skalierungen zurückgesetzt. Öffne die Fenster erneut, um die Standardwerte zu sehen.",
    ["FRAMEMOVER_ENABLED_TOOLTIP"] = "Linksklick zum Umschalten. Strg+Scrollen über ein Fenster, um es zu skalieren. Halte Alt beim Ziehen, um die Bildschirmbegrenzung zu umgehen.",
    ["FEATURES_ON"] = "An",
    ["FEATURES_OFF"] = "Aus",
})
