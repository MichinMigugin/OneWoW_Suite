local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["CHARINFO_TITLE"] = "Fiche d'infos du personnage",
    ["CHARINFO_DESC"] = "Affiche un panneau d'infos clair à côté de chaque objet équipé sur votre fiche de personnage, indiquant le niveau d'objet (coloré par qualité), l'état d'enchantement, l'état des châsses et le pourcentage de durabilité.",
    ["CHARINFO_ENCHANTED"] = "Enchanté",
    ["CHARINFO_MISSING_ENCHANT"] = "Enchantement manquant",
    ["CHARINFO_NO_ENCHANT_NEEDED"] = "Aucun enchantement requis",
    ["CHARINFO_ALL_SOCKETS_EMPTY"] = "Toutes les châsses vides",
    ["CHARINFO_SOME_SOCKETS_EMPTY"] = "Certaines châsses vides",
    ["CHARINFO_ALL_SOCKETS_FILLED"] = "Toutes les châsses remplies",
    ["CHARINFO_NO_SOCKETS"] = "Aucune châsse",
    ["CHARINFO_TOGGLE_DURABILITY"] = "Afficher la durabilité",
    ["CHARINFO_TOGGLE_DURABILITY_DESC"] = "Affiche le pourcentage de durabilité sur les boutons d'objet",
    ["CHARINFO_TOGGLE_SOCKETS"] = "Afficher l'icône sans châsse",
    ["CHARINFO_TOGGLE_SOCKETS_DESC"] = "Affiche une icône lorsque les objets n'ont pas de châsses",
    ["CHARINFO_ENCHANT_SLOTS_HEADER"] = "Suivi des emplacements d'enchantement",
    ["CHARINFO_ENCHANT_SLOTS_DESC"] = "Choisissez quels emplacements d'équipement suivre pour les enchantements. Les emplacements désactivés n'afficheront pas d'icônes d'état d'enchantement.",
    ["CHARINFO_SLOT_HEAD"] = "Tête",
    ["CHARINFO_SLOT_NECK"] = "Cou",
    ["CHARINFO_SLOT_SHOULDER"] = "Épaules",
    ["CHARINFO_SLOT_CHEST"] = "Torse",
    ["CHARINFO_SLOT_WAIST"] = "Taille",
    ["CHARINFO_SLOT_LEGS"] = "Jambes",
    ["CHARINFO_SLOT_FEET"] = "Pieds",
    ["CHARINFO_SLOT_WRIST"] = "Poignets",
    ["CHARINFO_SLOT_HANDS"] = "Mains",
    ["CHARINFO_SLOT_RING1"] = "Anneau 1",
    ["CHARINFO_SLOT_RING2"] = "Anneau 2",
    ["CHARINFO_SLOT_BACK"] = "Dos",
    ["CHARINFO_SLOT_MAINHAND"] = "Main droite",
    ["CHARINFO_SLOT_OFFHAND"] = "Main gauche",
    ["FEATURES_ON"] = "Activé",
    ["FEATURES_OFF"] = "Désactivé",
})
