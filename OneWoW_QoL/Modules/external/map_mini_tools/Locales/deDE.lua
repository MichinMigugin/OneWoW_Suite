local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["MMSKIN_TITLE"] = "Karte (Mini) Werkzeuge",
    ["MMSKIN_DESC"] = "Passe deinen Minikarten-Bereich an: Form, Rahmen, Zonentext, Uhr, Klickaktionen, Zoomsteuerung, Sichtbarkeit von Elementen und mehr. Themenbewusst und voll konfigurierbar.",

    ["MMSKIN_GROUP_SHAPE"] = "Form & Aussehen",
    ["MMSKIN_GROUP_INFO"] = "Informations-Overlays",
    ["MMSKIN_GROUP_ZOOM"] = "Zoom & Scrollen",
    ["MMSKIN_GROUP_CLICKS"] = "Klickaktionen",
    ["MMSKIN_GROUP_ELEMENTS"] = "Sichtbarkeit von Elementen",
    ["MMSKIN_GROUP_EXTRAS"] = "Extras",
    ["MMSKIN_GROUP_COMPAT"] = "Kompatibilität",

    ["MMSKIN_SQUARE"] = "Quadratische Minikarte",
    ["MMSKIN_SQUARE_DESC"] = "Ändert die Form der Minikarte von rund zu quadratisch. Das Deaktivieren erfordert ein Neuladen der Benutzeroberfläche.",
    ["MMSKIN_BORDER"] = "Rahmen anzeigen",
    ["MMSKIN_BORDER_DESC"] = "Zeigt einen farbigen Rahmen um die Minikarte an.",
    ["MMSKIN_CLASS_BORDER"] = "Klassenfarbener Rahmen",
    ["MMSKIN_CLASS_BORDER_DESC"] = "Verwendet deine Klassenfarbe für den Minikarten-Rahmen anstelle der Themenfarbe.",
    ["MMSKIN_UNLOCK"] = "Minikarte entsperren",
    ["MMSKIN_UNLOCK_DESC"] = "Löst die Minikarte von ihrer Standardposition und macht sie frei verschiebbar.",
    ["MMSKIN_LOCK_POS"] = "Position sperren",
    ["MMSKIN_LOCK_POS_DESC"] = "Verhindert das Verschieben der Minikarte, behält sie aber an ihrer aktuellen Position.",

    ["MMSKIN_ZONE_TEXT"] = "Zonentext",
    ["MMSKIN_ZONE_TEXT_DESC"] = "Zeigt den Namen der aktuellen Zone über der Minikarte mit PvP-Färbung an.",
    ["MMSKIN_CLOCK"] = "Uhr",
    ["MMSKIN_CLOCK_DESC"] = "Zeigt eine Uhr unter der Minikarte an. Der Tooltip zeigt Server-/Ortszeit sowie tägliche/wöchentliche Zurücksetzungs-Timer.",
    ["MMSKIN_CLASS_CLOCK_COLOR"] = "Klassenfarbene Uhr",
    ["MMSKIN_CLASS_CLOCK_COLOR_DESC"] = "Verwendet deine Klassenfarbe für den Uhrentext anstelle der Themenfarbe.",
    ["MMSKIN_ZONE_ALIGN_LABEL"] = "Ausrichtung des Zonennamens",
    ["MMSKIN_CLOCK_ALIGN_LABEL"] = "Ausrichtung der Uhr",
    ["MMSKIN_ALIGN_LEFT"] = "Links",
    ["MMSKIN_ALIGN_CENTER"] = "Zentriert",
    ["MMSKIN_ALIGN_RIGHT"] = "Rechts",

    ["MMSKIN_ZONE_CLOCK_INSIDE"] = "Zone & Uhr innerhalb der Minikarte",
    ["MMSKIN_ZONE_CLOCK_INSIDE_DESC"] = "Verankert Zonennamen und Uhr an den Innenkanten der Minikarte statt darüber und darunter.",

    ["MMSKIN_ZONE_CLOCK_DRAG"] = "Zone & Uhr ziehen (Umschalt halten)",
    ["MMSKIN_ZONE_CLOCK_DRAG_DESC"] = "Du musst die Umschalttaste gedrückt halten, während du den Zonennamen oder die Uhr ziehst, um sie auf dem Bildschirm zu verschieben. Positionen werden gespeichert. Lass die Umschalttaste für normale Klicks los (die Uhr öffnet weiterhin den Zeitmanager).",

    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM"] = "Zone & Uhr an Minikarte verankern",
    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM_DESC"] = "Wenn das Ziehen aktiviert ist, werden Zonenname und Uhr an der Minikarte verankert, sodass sie mitwandern, wenn die Minikarte bewegt wird. Wenn du sie übereinanderlegst, bewegen sie sich als eine Einheit.",

    ["MMSKIN_WHEEL_ZOOM"] = "Mausrad-Zoom",
    ["MMSKIN_WHEEL_ZOOM_DESC"] = "Zoomt die Minikarte mit dem Mausrad heran und heraus.",
    ["MMSKIN_AUTO_ZOOM"] = "Automatisch herauszoomen",
    ["MMSKIN_AUTO_ZOOM_DESC"] = "Zoomt die Minikarte nach dem Heranzoomen automatisch wieder heraus.",

    ["MMSKIN_CLICK_ACTIONS"] = "Klickaktionen",
    ["MMSKIN_CLICK_ACTIONS_DESC"] = "Aktiviert Rechtsklick-, Mittelklick- und Zusatztasten-Aktionen auf der Minikarte.",

    ["MMSKIN_MAIL"] = "Post-Anzeige",
    ["MMSKIN_MAIL_DESC"] = "Zeigt die Post-Anzeige auf der Minikarte an.",
    ["MMSKIN_CRAFTING"] = "Fertigungsaufträge",
    ["MMSKIN_CRAFTING_DESC"] = "Zeigt die Anzeige für Fertigungsaufträge auf der Minikarte an.",
    ["MMSKIN_DIFFICULTY"] = "Schwierigkeitssymbol",
    ["MMSKIN_DIFFICULTY_DESC"] = "Zeigt das Symbol für die Instanzschwierigkeit auf der Minikarte an.",

    ["MMSKIN_TRACKING"] = "Verfolgungsfilter",
    ["MMSKIN_TRACKING_DESC"] = "Zeigt den Verfolgungsfilter der Minikarte an (Dropdown für Ressourcen / Kräuter / Erz / usw.). Beim Deaktivieren wird der kleine Ring/das Steuerelement neben der Minikarte entfernt.",
    ["MMSKIN_MISSIONS"] = "Missionsschaltfläche",
    ["MMSKIN_MISSIONS_DESC"] = "Zeigt die Schaltfläche für die Erweiterungs-Landeseite / Missionen an.",
    ["MMSKIN_GAMETIME"] = "Kalendersymbol",
    ["MMSKIN_GAMETIME_DESC"] = "Zeigt die Kalender-Schaltfläche (GameTime) auf der Minikarte an.",

    ["MMSKIN_PLUMBER_HIDE_BLIZZARD"] = "Doppelte Blizzard-Erweiterungsschaltfläche mit Plumber ausblenden",
    ["MMSKIN_PLUMBER_HIDE_BLIZZARD_DESC"] = "Wenn Plumber geladen ist, bleibt Blizzards Erweiterungs-Minikartenschaltfläche ausgeblendet, sodass nur Plumbers Erweiterungsübersicht angezeigt wird. Deaktivieren, um beide anzuzeigen (nicht empfohlen).",
    ["MMSKIN_PLUMBER_STATUS_ON"] = "Plumber ist geladen – diese Option wird angewendet.",
    ["MMSKIN_PLUMBER_STATUS_OFF"] = "Plumber ist nicht geladen – aktiviere dies vor dem Einloggen oder lade nach der Installation von Plumber neu.",

    ["MMSKIN_HIDE_ADDONS"] = "Addon-Symbole ausblenden",
    ["MMSKIN_HIDE_ADDONS_DESC"] = "Blendet Addon-Schaltflächen der Minikarte aus, bis du mit dem Mauszeiger über den Minikartenbereich fährst.",
    ["MMSKIN_COMBAT_FADE"] = "Kampf-Ausblendung",
    ["MMSKIN_COMBAT_FADE_DESC"] = "Verringert die Deckkraft der Minikarte während des Kampfes.",
    ["MMSKIN_PET_HIDE"] = "Bei Haustierkämpfen ausblenden",
    ["MMSKIN_PET_HIDE_DESC"] = "Blendet die Minikarte während Haustierkämpfen aus.",

    ["MMSKIN_SCALE_LABEL"] = "Skalierung des Minikarten-Bereichs",
    ["MMSKIN_SECTION_BORDER"] = "Rahmeneinstellungen",
    ["MMSKIN_BORDER_SIZE"] = "Rahmengröße",
    ["MMSKIN_BORDER_RED"] = "Rot",
    ["MMSKIN_BORDER_GREEN"] = "Grün",
    ["MMSKIN_BORDER_BLUE"] = "Blau",
    ["MMSKIN_USE_THEME_COLOR"] = "Themenfarbe verwenden",

    ["MMSKIN_ZONE_BG"] = "Zonenhintergrund",
    ["MMSKIN_CLOCK_BG"] = "Uhrenhintergrund",

    ["MMSKIN_AUTO_ZOOM_DELAY"] = "Verzögerung für Auto-Zoom",
    ["MMSKIN_SHOW_ZOOM_BTNS"] = "Zoom-Schaltflächen anzeigen",

    ["MMSKIN_HIDE_WM_BTN"] = "Weltkartenschaltfläche ausblenden",
    ["MMSKIN_HIDE_WM_BTN_DESC"] = "Blendet die kleine Weltkartenschaltfläche auf der Minikarte aus (du kannst die Karte weiterhin mit ihrer Tastenbelegung öffnen).",

    ["MMSKIN_SECTION_COMBAT"] = "Einstellungen für Kampf-Ausblendung",
    ["MMSKIN_COMBAT_ALPHA"] = "Deckkraft im Kampf",

    ["MMSKIN_SECTION_CLICKS"] = "Einstellungen für Klickbelegung",
    ["MMSKIN_CLICK_RIGHT"] = "Rechtsklick",
    ["MMSKIN_CLICK_MIDDLE"] = "Mittelklick",
    ["MMSKIN_CLICK_BTN4"] = "Taste 4",
    ["MMSKIN_CLICK_BTN5"] = "Taste 5",
    ["MMSKIN_ACTION_NONE"] = "Keine",
    ["MMSKIN_ACTION_CALENDAR"] = "Kalender",
    ["MMSKIN_ACTION_TRACKING"] = "Verfolgung",
    ["MMSKIN_ACTION_MISSIONS"] = "Missionen",
    ["MMSKIN_ACTION_MAP"] = "Karte",
    ["MMSKIN_WORLD_MAP_BUTTON"] = "Weltkarte",

    ["MMSKIN_SHOW_COMPARTMENT"] = "Addon-Fach",

    ["MMSKIN_CLOCK_TT_TOGGLE"] = "Klicken, um den Zeitmanager umzuschalten",

    ["MMSKIN_UNCLAMP"] = "Vom Bildschirmrand lösen",

    ["MMSKIN_ZONE_FONT_LABEL"] = "Schriftart",
    ["MMSKIN_CLOCK_FONT_LABEL"] = "Schriftart",
    ["MMSKIN_FONT_GLOBAL"] = "Globale Schriftart",
    ["MMSKIN_FONT_WOW_DEFAULT"] = "WoW-Standard (klein)",

    ["MMSKIN_SECTION_OPACITY"] = "Skalierung & Deckkraft",
    ["MMSKIN_OPACITY"] = "Deckkraft der Minikarte",

    ["MMSKIN_SECTION_DEBUG"] = "Entwicklerwerkzeuge",
    ["MMSKIN_DEBUG_SHOW"] = "Debug-Symbole anzeigen",
    ["MMSKIN_DEBUG_HIDE"] = "Debug-Symbole ausblenden",
    ["MMSKIN_DEBUG_DESC"] = "Erzwingt die Sichtbarkeit aller verfolgten Symbole mit farbigen Beschriftungen. Ziehe eine Beschriftung, um das Symbol auf der Minikarte zu platzieren; Positionen werden gespeichert. Blende das Debugging aus, um die Symbole zum Bereich zurückzubringen (sofern die Minikarte nicht gelöst ist). Nützlich, wenn Symbole nicht aktiv ausgelöst werden (z. B. keine Post im Briefkasten).",
    ["MMSKIN_DEBUG_TT_DRAG_HINT"] = "Linksklick und ziehen, um dieses Symbol auf der Minikarte zu verschieben.",
    ["MMSKIN_DEBUG_TT_POS_FMT"] = "Gespeicherter Versatz: %.0f, %.0f",

    ["MMSKIN_RELOAD_PROMPT"] = "Das Ändern der Minikartenform erfordert ein Neuladen der Benutzeroberfläche.\nJetzt neu laden?",
})
