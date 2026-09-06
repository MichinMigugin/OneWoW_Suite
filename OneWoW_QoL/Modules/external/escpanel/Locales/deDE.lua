local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["ESCPANEL_TITLE"] = "ESC-Menüpanel",
    ["ESCPANEL_DESC"] = "Zeigt eine Charakterkarte, Sammlungen und Notizen dieses Orts sowie eine Portalleiste neben dem ESC-Menü. Die Charakterkarte zeigt Post, Haltbarkeit, Große Schatzkammer und Handelsposten, optional mit Unterfangen. Die Ortskarte hat Gegenstandsalarm-Symbole für Shopping List, Notizen, Trackers und Farming. Treffer stehen links von |, der Rest rechts. Zeige auf ein Symbol für Details; klicke einen Treffer, um ihn zu öffnen. Klicke sie, um den Charakterbildschirm zu öffnen, oder die Ortskarte, um die Zone im Katalog zu öffnen. Wähle unten, welche Seite jedes verwendet.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Charakterinfos anzeigen",
    ["ESCPANEL_TOGGLE_ENDEAVORS"] = "Unterfangen anzeigen",
    ["ESCPANEL_TOGGLE_ALERTS"] = "Warnungen anzeigen",
    ["ESCPANEL_TOGGLE_ZONE_NOTES"] = "Zonennotizen anzeigen",
    ["ESCPANEL_TOGGLE_HIDE_ZONE_EMPTY"] = "Zonennotizen ausblenden, wenn leer",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "Portale anzeigen",
    ["ESCPANEL_LAYOUT_HEADER"] = "Anordnung",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "Seite der Infopanels",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "Seite der Portale",
    ["ESCPANEL_SIDE_LEFT"] = "Links vom Menü",
    ["ESCPANEL_SIDE_RIGHT"] = "Rechts vom Menü",
    ["ESCPANEL_LAYOUT_DESC"] = "Wenn beide auf derselben Seite sind, sitzen die Portale außen (weiter vom Menü entfernt) und die Panels direkt neben dem Menü.",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "Größe der Portalsymbole",
})
