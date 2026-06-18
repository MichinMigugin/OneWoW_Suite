local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["MAPWORLD_TITLE"] = "Karte (Welt) Werkzeuge",
    ["MAPWORLD_DESC"] = "Weltkarte: unerkundetes Gelände aus Client-Daten aufdecken, optionale Färbungen, Anpassungen der Schlachtfeldkarte, Koordinaten und kleine Komfort-/Aufräumoptionen.",

    ["MAPWORLD_GROUP_EXPLORE"] = "Erkundung (Kartengrafik)",
    ["MAPWORLD_GROUP_FOGOVERLAY"] = "Nebel-Overlay (dunkle Schicht)",
    ["MAPWORLD_GROUP_FRAME"] = "Kartenfenster",
    ["MAPWORLD_GROUP_COMFORT"] = "Komfort",
    ["MAPWORLD_GROUP_CLEANUP"] = "Aufräumen",
    ["MAPWORLD_GROUP_COORDS"] = "Koordinaten",
    ["MAPWORLD_GROUP_POI"] = "Sehenswürdigkeiten",
    ["MAPWORLD_GROUP_BATTLE"] = "Schlachtfeldkarte",
    ["MAPWORLD_GROUP_POLISH"] = "Feinschliff",
    ["MAPWORLD_GROUP_CANVAS"] = "Gesamtkarten-Overlay",
    ["MAPWORLD_GROUP_MAP"] = "Weltkartenfenster",

    ["MAPWORLD_REVEAL_MAP"] = "Unerkundete Gebiete anzeigen",
    ["MAPWORLD_REVEAL_MAP_DESC"] = "Zeichnet fehlende Erkundungskacheln anhand mitgelieferter Kartengrafikdaten (vergleichbar mit dem Aufdecken der Papierkarte). Funktioniert auf Welt- und Schlachtfeldkarten.",

    ["MAPWORLD_TINT_UNEXPLORED"] = "Unerkundete Gebiete einfärben",
    ["MAPWORLD_TINT_UNEXPLORED_DESC"] = "Wendet eine Farbtönung auf die durch die obige Option aufgedeckten Kacheln an (nur Zonenkarten).",

    ["MAPWORLD_UNEX_R"] = "Unerkundet Rot",
    ["MAPWORLD_UNEX_G"] = "Unerkundet Grün",
    ["MAPWORLD_UNEX_B"] = "Unerkundet Blau",
    ["MAPWORLD_UNEX_A"] = "Unerkundet Deckkraft",

    ["MAPWORLD_REMOVE_FOG"] = "Dunkle Nebelschicht ausblenden",
    ["MAPWORLD_REMOVE_FOG_DESC"] = "Blendet Blizzards Nebel-des-Krieges-Frame über der Karte aus (getrennt vom Zeichnen fehlender Erkundungsgrafik).",

    ["MAPWORLD_FOG_TINT"] = "Nebelschicht einfärben (NdK)",
    ["MAPWORLD_FOG_TINT_DESC"] = "Multipliziert die Farbe der dunklen Nebelschicht, wenn sie sichtbar ist.",

    ["MAPWORLD_CLEAR_BLACKOUT"] = "Welt hinter der Karte anklickbar",
    ["MAPWORLD_CLEAR_BLACKOUT_DESC"] = "Macht die abgedunkelte „Verdunkelung“ hinter der Karte transparent und nicht klickblockierend, sodass du die Welt klar siehst.",

    ["MAPWORLD_NO_MAP_FADE"] = "Kartenausblendung bei Bewegung deaktivieren",
    ["MAPWORLD_NO_MAP_FADE_DESC"] = "Setzt mapFade, damit die Karte nicht halbtransparent wird, wenn sich dein Charakter bewegt.",

    ["MAPWORLD_NO_MAP_EMOTE"] = "Lese-Emote deaktivieren",
    ["MAPWORLD_NO_MAP_EMOTE_DESC"] = "Bricht die Lese-Emote beim Öffnen der Karte ab.",

    ["MAPWORLD_HIDE_FILTER_RESET"] = "Filter-Zurücksetzen-UI ausblenden",
    ["MAPWORLD_HIDE_FILTER_RESET_DESC"] = "Blendet das Steuerelement zum Zurücksetzen des Weltkartenfilters und zugehörige Zählerbanner aus.",

    ["MAPWORLD_HIDE_MAP_TUTORIAL"] = "Karten-Tutorial unterdrücken",
    ["MAPWORLD_HIDE_MAP_TUTORIAL_DESC"] = "Blendet das Tutorial-Frame der Weltkarte aus und markiert es in den Info-Frames als geschlossen.",

    ["MAPWORLD_SHOW_COORDS"] = "Koordinaten anzeigen",
    ["MAPWORLD_SHOW_COORDS_DESC"] = "Zeigt die Cursor- und Spielerposition im Kartenfenster an.",

    ["MAPWORLD_COORDS_LARGE"] = "Große Koordinatenschrift",
    ["MAPWORLD_COORDS_LARGE_DESC"] = "Verwendet eine größere Schrift für die Koordinatenanzeige.",

    ["MAPWORLD_COORDS_BG"] = "Hintergrund der Koordinatenleiste",
    ["MAPWORLD_COORDS_BG_DESC"] = "Zeigt einen dunklen Streifen hinter dem Koordinatentext an.",

    ["MAPWORLD_HIDE_CONTINENT_POI"] = "Stadt-Sehenswürdigkeiten auf Kontinenten ausblenden",
    ["MAPWORLD_HIDE_CONTINENT_POI_DESC"] = "Blendet bestimmte Heimat-, Fraktions- und Stadtmarkierungen in Kontinent- und Weltkartenansichten aus.",

    ["MAPWORLD_ENHANCE_BATTLE_MAP"] = "Schlachtfeldkarte verbessern",
    ["MAPWORLD_ENHANCE_BATTLE_MAP_DESC"] = "Zeigt die Gruppe auf der Schlachtfeldkarte an und aktiviert die Optionen unten.",

    ["MAPWORLD_UNLOCK_BATTLEFIELD"] = "Ziehen, um die Schlachtfeldkarte zu bewegen",
    ["MAPWORLD_UNLOCK_BATTLEFIELD_DESC"] = "Ziehe die Schlachtfeldkarte an ihrer Innenfläche.",

    ["MAPWORLD_BATTLE_CENTER"] = "Schlachtfeldkarte auf Spieler zentriert halten",
    ["MAPWORLD_BATTLE_CENTER_DESC"] = "Zentriert die Schlachtfeldkarte erneut auf deine Position. Halte Umschalt beim Ziehen, um zu pausieren.",

    ["MAPWORLD_BATTLE_OPACITY"] = "Sichtbarkeit der Schlachtfeldkarte",
    ["MAPWORLD_BATTLE_GROUP"] = "Größe der Gruppensymbole",
    ["MAPWORLD_BATTLE_PLAYER"] = "Größe des Spielerpfeils",

    ["MAPWORLD_TINT_MENU"] = "Weltkartenmenü: Färbungs-Umschalter",
    ["MAPWORLD_TINT_MENU_DESC"] = "Fügt dem Kartenverfolgungsmenü ein Kontrollkästchen „Unerkundete einfärben“ hinzu (lädt möglicherweise nicht, wenn sich die Menü-API ändert).",

    ["MAPWORLD_CANVAS_TINT"] = "Gesamtkarten-Farbüberlagerung",
    ["MAPWORLD_CANVAS_TINT_DESC"] = "Färbt die gesamte Kartenfläche mit einer durchscheinenden Farbe (getrennt von der Erkundungsfärbung).",

    ["MAPWORLD_MAP_ALPHA"] = "Deckkraft der Weltkarte",
    ["MAPWORLD_MAP_ALPHA_DESC"] = "Verringert die Deckkraft des gesamten Weltkartenfensters (Frame-Alpha).",

    ["MAPWORLD_MAP_ALPHA_SLIDER"] = "Deckkraft des Kartenfensters",
    ["MAPWORLD_RED"] = "Rot",
    ["MAPWORLD_GREEN"] = "Grün",
    ["MAPWORLD_BLUE"] = "Blau",

    ["MAPWORLD_CURSOR"] = "Cursor",
})
