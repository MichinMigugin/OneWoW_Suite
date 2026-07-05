local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["INSPECTMOG_TITLE"] = "Ausrüstung untersuchen",
    ["INSPECTMOG_DESC"] = "Fügt dem Untersuchen-Fenster ein Seitenpanel hinzu, das die angelegte Ausrüstung des untersuchten Spielers auflistet. Speichere die ganze Liste in einer OneWoW Notes-Spielernotiz oder Umschalt-klicke einen Gegenstand, um ihn zu deinen Gegenstandsnotizen hinzuzufügen.",

    ["INSPECTMOG_ADD_NOTE"] = "Zur Spielernotiz hinzufügen",
    ["INSPECTMOG_ADD_ALL"] = "Alle hinzufügen",
    ["INSPECTMOG_EMPTY"] = "Noch keine untersuchbare Ausrüstung.",
    ["INSPECTMOG_PANEL_TITLE"] = "Transmog-Untersuchungstool",
    ["INSPECTMOG_NO_DATA"] = "Keine Untersuchungsdaten verfügbar.",
    ["INSPECTMOG_UNKNOWN_PLAYER"] = "Untersuchter Spieler",
    ["INSPECTMOG_NATIVE_APPEARANCE"] = "Ursprüngliches Erscheinungsbild",
    ["INSPECTMOG_SOURCE_FORMAT"] = "Quelle #%d",
    ["INSPECTMOG_APPEARANCE_SOURCE_FORMAT"] = "Erscheinungsbildquelle: %d",

    ["INSPECTMOG_TT_PREVIEW"] = "Strg-Klick für Vorschau in der Anprobe",
    ["INSPECTMOG_TT_NOTES"] = "Umschalt-Klick zum Hinzufügen zu Notes > Gegenstände",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED"] = "Umschalt-Klick, um angelegten Gegenstand zu Notes > Gegenstände hinzuzufügen",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED_COLL"] = "Umschalt-Klick, um das Erscheinungsbild dieses Gegenstands zu Notes > Sammelobjekte hinzuzufügen",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE"] = "Umschalt-Klick, um Transmog-Erscheinungsbild zu Notes > Gegenstände hinzuzufügen",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE_COLL"] = "Umschalt-Klick, um Transmog-Erscheinungsbild zu Notes > Sammelobjekte hinzuzufügen",
    ["INSPECTMOG_ROUTE_COLLECTIBLES"] = "Erscheinungsbilder zu Sammelobjekten hinzufügen",
    ["INSPECTMOG_TT_PREVIEW_EQUIPPED"] = "Strg-Klick für Vorschau des angelegten Gegenstands",
    ["INSPECTMOG_TT_PREVIEW_APPEARANCE"] = "Strg-Klick für Vorschau des Transmog-Erscheinungsbilds",
    ["INSPECTMOG_TT_HIDDEN_APPEARANCE"] = "Verborgene Erscheinungsbilder werden nicht zu Gegenstandsnotizen hinzugefügt",
    ["INSPECTMOG_TT_ADD_ALL_TITLE"] = "Gesamten Transmog hinzufügen",
    ["INSPECTMOG_TT_ADD_ALL_DESC"] = "Fügt alle sichtbaren Transmog-Erscheinungsbild-Gegenstände zu Notes > Gegenstände hinzu.",

    ["INSPECTMOG_TT_ADD_NOTE_TITLE"] = "Ausrüstung in Spielernotiz speichern",
    ["INSPECTMOG_TT_ADD_NOTE_DESC"] = "Schreibt jeden aufgelisteten Slot und Gegenstand in die Notiz dieses Spielers in OneWoW Notes. Erneutes Speichern aktualisiert den Ausrüstungsblock und behält den Rest der Notiz.",

    ["INSPECTMOG_NOTE_HEADER"] = "[OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_FOOTER"] = "[/OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_UPDATED"] = "Untersucht: %s",
    ["INSPECTMOG_NOTE_LINE"] = "%s - %s",

    ["INSPECTMOG_ITEM_STAMP"] = "TMOG untersucht am %s - %s",

    ["INSPECTMOG_STATUS_NOTE_SAVED"] = "Ausrüstung in der Notiz von %s gespeichert.",
    ["INSPECTMOG_STATUS_NOTE_UPDATED"] = "Ausrüstung in der Notiz von %s aktualisiert.",
    ["INSPECTMOG_STATUS_ITEM_ADDED"] = "%s zu Gegenstandsnotizen hinzugefügt.",
    ["INSPECTMOG_STATUS_NOTES_MISSING"] = "OneWoW Notes ist nicht installiert.",
    ["INSPECTMOG_STATUS_NO_DATA"] = "Noch keine Ausrüstungsdaten verfügbar.",
})
