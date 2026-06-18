local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["COORDS_TITLE"] = "Visore coordinate",
    ["COORDS_DESC"] = "Mostra le tue coordinate attuali della mappa in un piccolo riquadro spostabile vicino alla minimappa. Clic destro per copiare le coordinate.",
    ["COORDS_TOGGLE_MAPID"] = "Mostra ID mappa",
    ["COORDS_TOGGLE_MAPID_DESC"] = "Mostra l'ID numerico della mappa accanto alle tue coordinate.",
    ["COORDS_TOGGLE_ZONE"] = "Mostra nome zona",
    ["COORDS_TOGGLE_ZONE_DESC"] = "Mostra il nome della zona attuale sotto le coordinate.",
    ["COORDS_TOGGLE_SUBZONE"] = "Mostra sottozona",
    ["COORDS_TOGGLE_SUBZONE_DESC"] = "Mostra la sottozona o il nome dell'area attuale.",
    ["COORDS_TOGGLE_FACING"] = "Mostra orientamento",
    ["COORDS_TOGGLE_FACING_DESC"] = "Mostra la tua direzione attuale in gradi e punto cardinale.",
    ["COORDS_TOGGLE_SPEED"] = "Mostra velocità",
    ["COORDS_TOGGLE_SPEED_DESC"] = "Mostra la tua velocità di movimento attuale in metri al secondo.",
    ["COORDS_TOGGLE_HIDE_INSTANCE"] = "Nascondi nelle istanze",
    ["COORDS_TOGGLE_HIDE_INSTANCE_DESC"] = "Nasconde automaticamente il visore delle coordinate quando sei in una spedizione, incursione o altra istanza.",
    ["COORDS_MAP"] = "Mappa: %d",
    ["COORDS_COPIED"] = "Coordinate copiate: %s",
    ["COORDS_COPY_TITLE"] = "Coordinate",
})
