local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["AFKPANEL_TITLE"] = "Panneau AFK",
    ["AFKPANEL_DESC"] = "Superposition AFK plein ecran avec les memes cartes You et Here que le menu ECHAP, alertes de courrier et d'encheres, et notes Daily/Weekly optionnelles si Notes est active.",
    ["AFKPANEL_CAMERA_SPIN"] = "Rotation de la caméra",
    ["AFKPANEL_SHOW_DAILY"] = "Afficher les notes quotidiennes",
    ["AFKPANEL_SHOW_WEEKLY"] = "Afficher les notes hebdomadaires",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - Mode AFK",
    ["AFKPANEL_CHARACTER_INFO"] = "INFOS DU PERSONNAGE",
    ["AFKPANEL_ALERTS"] = "ALERTES",
    ["AFKPANEL_NO_ALERTS"] = "Aucune alerte pour le moment",
    ["AFKPANEL_AFK_TIME"] = "AFK : %s",
    ["AFKPANEL_DAILY_NOTES"] = "NOTES QUOTIDIENNES",
    ["AFKPANEL_WEEKLY_NOTES"] = "NOTES HEBDOMADAIRES",
    ["AFKPANEL_NO_NOTES"] = "Aucune note à afficher",
    ["AFKPANEL_NO_GUILD"] = "Aucune guilde",
})
