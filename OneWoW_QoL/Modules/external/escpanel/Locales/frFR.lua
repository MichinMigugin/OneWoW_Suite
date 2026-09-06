local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["ESCPANEL_TITLE"] = "Panneau du menu ÉCHAP",
    ["ESCPANEL_DESC"] = "Affiche une fiche personnage, les collections et notes de ce lieu, et une bande de portails a cote du menu ECHAP. La fiche montre le courrier, la Durabilite, La grande chambre forte et le Comptoir, avec les Initiatives en option. La carte du lieu a des icones Alerte objet pour Shopping List, les notes, Trackers et Farming. Survolez une icone pour les details ; cliquez une icone allumee pour l'ouvrir. Cliquez-la pour ouvrir l'ecran du personnage, ou la carte du lieu pour ouvrir cette zone dans le Catalogue. Choisissez ci-dessous quel cote chacun utilise.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Afficher les infos du personnage",
    ["ESCPANEL_TOGGLE_ENDEAVORS"] = "Afficher les Initiatives",
    ["ESCPANEL_TOGGLE_ALERTS"] = "Afficher les alertes",
    ["ESCPANEL_TOGGLE_ZONE_NOTES"] = "Afficher les notes de zone",
    ["ESCPANEL_TOGGLE_HIDE_ZONE_EMPTY"] = "Masquer les notes de zone si vides",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "Afficher les portails",
    ["ESCPANEL_LAYOUT_HEADER"] = "Disposition",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "Côté des panneaux d'infos",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "Côté des portails",
    ["ESCPANEL_SIDE_LEFT"] = "À gauche du menu",
    ["ESCPANEL_SIDE_RIGHT"] = "À droite du menu",
    ["ESCPANEL_LAYOUT_DESC"] = "Lorsque les deux sont du même côté, les portails se placent à l'extérieur (plus loin du menu) et les panneaux à côté du menu.",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "Taille des icônes de portail",
})
