local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["COORDS_TITLE"] = "Affichage des coordonnées",
    ["COORDS_DESC"] = "Affiche vos coordonnées de carte actuelles dans un petit cadre déplaçable près de la minicarte. Clic droit pour copier les coordonnées.",
    ["COORDS_TOGGLE_MAPID"] = "Afficher l'ID de carte",
    ["COORDS_TOGGLE_MAPID_DESC"] = "Affiche l'ID numérique de la carte à côté de vos coordonnées.",
    ["COORDS_TOGGLE_ZONE"] = "Afficher le nom de zone",
    ["COORDS_TOGGLE_ZONE_DESC"] = "Affiche le nom de la zone actuelle sous les coordonnées.",
    ["COORDS_TOGGLE_SUBZONE"] = "Afficher la sous-zone",
    ["COORDS_TOGGLE_SUBZONE_DESC"] = "Affiche la sous-zone ou le nom de la zone actuelle.",
    ["COORDS_TOGGLE_FACING"] = "Afficher l'orientation",
    ["COORDS_TOGGLE_FACING_DESC"] = "Affiche votre cap actuel en degrés et direction de boussole.",
    ["COORDS_TOGGLE_SPEED"] = "Afficher la vitesse",
    ["COORDS_TOGGLE_SPEED_DESC"] = "Affiche votre vitesse de déplacement actuelle en mètres par seconde.",
    ["COORDS_TOGGLE_HIDE_INSTANCE"] = "Masquer en instance",
    ["COORDS_TOGGLE_HIDE_INSTANCE_DESC"] = "Masque automatiquement l'affichage des coordonnées dans un donjon, un raid ou une autre instance.",
    ["COORDS_MAP"] = "Carte : %d",
    ["COORDS_COPIED"] = "Coordonnées copiées : %s",
    ["COORDS_COPY_TITLE"] = "Coordonnées",
})
