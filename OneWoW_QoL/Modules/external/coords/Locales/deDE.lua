local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["COORDS_TITLE"] = "Koordinatenanzeige",
    ["COORDS_DESC"] = "Zeigt deine aktuellen Kartenkoordinaten in einem kleinen beweglichen Rahmen neben der Minikarte an. Rechtsklick, um die Koordinaten zu kopieren.",
    ["COORDS_TOGGLE_MAPID"] = "Karten-ID anzeigen",
    ["COORDS_TOGGLE_MAPID_DESC"] = "Zeigt die numerische Karten-ID neben deinen Koordinaten an.",
    ["COORDS_TOGGLE_ZONE"] = "Zonennamen anzeigen",
    ["COORDS_TOGGLE_ZONE_DESC"] = "Zeigt den Namen der aktuellen Zone unter den Koordinaten an.",
    ["COORDS_TOGGLE_SUBZONE"] = "Unterzone anzeigen",
    ["COORDS_TOGGLE_SUBZONE_DESC"] = "Zeigt die aktuelle Unterzone oder den Gebietsnamen an.",
    ["COORDS_TOGGLE_FACING"] = "Blickrichtung anzeigen",
    ["COORDS_TOGGLE_FACING_DESC"] = "Zeigt deine aktuelle Ausrichtung in Grad und Himmelsrichtung an.",
    ["COORDS_TOGGLE_SPEED"] = "Tempo anzeigen",
    ["COORDS_TOGGLE_SPEED_DESC"] = "Zeigt dein aktuelles Bewegungstempo in Yard pro Sekunde an.",
    ["COORDS_TOGGLE_HIDE_INSTANCE"] = "In Instanzen ausblenden",
    ["COORDS_TOGGLE_HIDE_INSTANCE_DESC"] = "Blendet die Koordinatenanzeige automatisch aus, wenn du dich in einem Dungeon, Schlachtzug oder einer anderen Instanz befindest.",
    ["COORDS_MAP"] = "Karte: %d",
    ["COORDS_COPIED"] = "Koordinaten kopiert: %s",
    ["COORDS_COPY_TITLE"] = "Koordinaten",
})
