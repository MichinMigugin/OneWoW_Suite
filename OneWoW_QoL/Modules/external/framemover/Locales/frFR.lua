local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["FRAMEMOVER_TITLE"] = "Déplaceur de cadres",
    ["FRAMEMOVER_DESC"] = "Glissez les cadres de l'interface Blizzard pour les repositionner. Utilisez Ctrl+Molette pour les redimensionner. Maintenez Alt en glissant pour déplacer les cadres partiellement hors de l'écran lorsque « Confiner à l'écran » est activé. Les positions et les échelles peuvent persister d'une session à l'autre.",

    ["FRAMEMOVER_TOGGLE_REQUIRE_SHIFT"] = "Maj requise pour glisser",
    ["FRAMEMOVER_TOGGLE_ENABLE_SCALING"] = "Redimensionnement Ctrl+Molette",
    ["FRAMEMOVER_TOGGLE_SAVE_POSITIONS"] = "Mémoriser les positions",
    ["FRAMEMOVER_TOGGLE_SAVE_SCALES"] = "Mémoriser les échelles",
    ["FRAMEMOVER_TOGGLE_CLAMP_SCREEN"] = "Confiner à l'écran",
    ["FRAMEMOVER_TOGGLE_MODIFY_HUD"] = "Afficher le popup d'échelle",

    ["FRAMEMOVER_GROUP_BEHAVIOR"] = "Comportement",
    ["FRAMEMOVER_GROUP_SAVING"] = "Persistance",

    ["FRAMEMOVER_CAT_CORE"] = "Interface principale",
    ["FRAMEMOVER_CAT_COLLECTIONS"] = "Collections & journaux",
    ["FRAMEMOVER_CAT_PROFESSIONS"] = "Métiers & économie",
    ["FRAMEMOVER_CAT_GROUP"] = "Contenu de groupe",
    ["FRAMEMOVER_CAT_CHARACTER"] = "Personnage & talents",
    ["FRAMEMOVER_CAT_SOCIAL"] = "Social & guildes",
    ["FRAMEMOVER_CAT_MISC"] = "Divers",
    ["FRAMEMOVER_CAT_HOUSING"] = "Logement",

    ["FRAMEMOVER_FRAMES_HEADER"] = "Cadres déplaçables",
    ["FRAMEMOVER_FILTER_EMPTY"] = "Aucun cadre ne correspond à votre recherche.",
    ["FRAMEMOVER_RESET_POSITIONS"] = "Réinitialiser toutes les positions",
    ["FRAMEMOVER_RESET_SCALES"] = "Réinitialiser toutes les échelles",
    ["FRAMEMOVER_RESET_POS_DONE"] = "Positions réinitialisées. Rouvrez les cadres pour voir les valeurs par défaut.",
    ["FRAMEMOVER_RESET_SCALE_DONE"] = "Échelles réinitialisées. Rouvrez les cadres pour voir les valeurs par défaut.",
    ["FRAMEMOVER_ENABLED_TOOLTIP"] = "Clic gauche pour activer/désactiver. Ctrl+Molette sur un cadre pour le redimensionner. Maintenez Alt en glissant pour ignorer le confinement.",
    ["FEATURES_ON"] = "Activé",
    ["FEATURES_OFF"] = "Désactivé",
})
