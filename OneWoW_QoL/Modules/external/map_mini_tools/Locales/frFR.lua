local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["MMSKIN_TITLE"] = "Outils de carte (mini)",
    ["MMSKIN_DESC"] = "Personnalisez votre groupe de minicarte : forme, bordure, texte de zone, horloge, actions de clic, contrôles de zoom, visibilité des éléments, et plus encore. Compatible avec les thèmes et entièrement configurable.",

    ["MMSKIN_GROUP_SHAPE"] = "Forme et apparence",
    ["MMSKIN_GROUP_INFO"] = "Superpositions d'informations",
    ["MMSKIN_GROUP_ZOOM"] = "Zoom et défilement",
    ["MMSKIN_GROUP_CLICKS"] = "Actions de clic",
    ["MMSKIN_GROUP_ELEMENTS"] = "Visibilité des éléments",
    ["MMSKIN_GROUP_EXTRAS"] = "Extras",
    ["MMSKIN_GROUP_COMPAT"] = "Compatibilité",

    ["MMSKIN_SQUARE"] = "Minicarte carrée",
    ["MMSKIN_SQUARE_DESC"] = "Change la forme de la minicarte de ronde à carrée. La désactivation nécessite un rechargement de l'interface.",
    ["MMSKIN_BORDER"] = "Afficher la bordure",
    ["MMSKIN_BORDER_DESC"] = "Affiche une bordure colorée autour de la minicarte.",
    ["MMSKIN_CLASS_BORDER"] = "Bordure couleur de classe",
    ["MMSKIN_CLASS_BORDER_DESC"] = "Utilise la couleur de votre classe pour la bordure de la minicarte au lieu de la couleur du thème.",
    ["MMSKIN_UNLOCK"] = "Déverrouiller la minicarte",
    ["MMSKIN_UNLOCK_DESC"] = "Détache la minicarte de sa position par défaut et la rend librement déplaçable.",
    ["MMSKIN_LOCK_POS"] = "Verrouiller la position",
    ["MMSKIN_LOCK_POS_DESC"] = "Empêche le déplacement de la minicarte tout en la maintenant à sa position actuelle.",

    ["MMSKIN_ZONE_TEXT"] = "Texte de zone",
    ["MMSKIN_ZONE_TEXT_DESC"] = "Affiche le nom de la zone actuelle au-dessus de la minicarte avec une coloration de type JcJ.",
    ["MMSKIN_CLOCK"] = "Horloge",
    ["MMSKIN_CLOCK_DESC"] = "Affiche une horloge sous la minicarte. L'infobulle indique l'heure du royaume/locale et les minuteurs de réinitialisation quotidienne/hebdomadaire.",
    ["MMSKIN_CLASS_CLOCK_COLOR"] = "Horloge couleur de classe",
    ["MMSKIN_CLASS_CLOCK_COLOR_DESC"] = "Utilise la couleur de votre classe pour le texte de l'horloge au lieu de la couleur du thème.",
    ["MMSKIN_ZONE_ALIGN_LABEL"] = "Alignement du nom de zone",
    ["MMSKIN_CLOCK_ALIGN_LABEL"] = "Alignement de l'horloge",
    ["MMSKIN_ALIGN_LEFT"] = "Gauche",
    ["MMSKIN_ALIGN_CENTER"] = "Centre",
    ["MMSKIN_ALIGN_RIGHT"] = "Droite",

    ["MMSKIN_ZONE_CLOCK_INSIDE"] = "Zone et horloge à l'intérieur de la minicarte",
    ["MMSKIN_ZONE_CLOCK_INSIDE_DESC"] = "Ancre le nom de zone et l'horloge sur les bords intérieurs de la minicarte au lieu de les placer au-dessus et en dessous.",

    ["MMSKIN_ZONE_CLOCK_DRAG"] = "Déplacer zone et horloge (maintenir Maj)",
    ["MMSKIN_ZONE_CLOCK_DRAG_DESC"] = "Vous devez maintenir la touche Maj enfoncée pendant que vous déplacez le nom de zone ou l'horloge pour les déplacer à l'écran. Les positions sont enregistrées. Relâchez Maj pour les clics normaux (l'horloge ouvre toujours le gestionnaire de temps).",

    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM"] = "Ancrer zone et horloge à la minicarte",
    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM_DESC"] = "Lorsque le déplacement est activé, ancre le nom de zone et l'horloge à la minicarte afin qu'ils suivent son déplacement. Si vous les empilez l'un sur l'autre, ils se déplacent comme un seul ensemble.",

    ["MMSKIN_WHEEL_ZOOM"] = "Zoom à la molette",
    ["MMSKIN_WHEEL_ZOOM_DESC"] = "Zoome la minicarte en avant et en arrière à l'aide de la molette de la souris.",
    ["MMSKIN_AUTO_ZOOM"] = "Dézoom automatique",
    ["MMSKIN_AUTO_ZOOM_DESC"] = "Dézoome automatiquement la minicarte après un zoom avant.",

    ["MMSKIN_CLICK_ACTIONS"] = "Actions de clic",
    ["MMSKIN_CLICK_ACTIONS_DESC"] = "Active les actions de clic droit, clic central et boutons de souris supplémentaires sur la minicarte.",

    ["MMSKIN_MAIL"] = "Indicateur de courrier",
    ["MMSKIN_MAIL_DESC"] = "Affiche l'indicateur de courrier sur la minicarte.",
    ["MMSKIN_CRAFTING"] = "Commandes d'artisanat",
    ["MMSKIN_CRAFTING_DESC"] = "Affiche l'indicateur de commandes d'artisanat sur la minicarte.",
    ["MMSKIN_DIFFICULTY"] = "Icône de difficulté",
    ["MMSKIN_DIFFICULTY_DESC"] = "Affiche l'icône de difficulté de l'instance sur la minicarte.",

    ["MMSKIN_TRACKING"] = "Filtre de pistage",
    ["MMSKIN_TRACKING_DESC"] = "Affiche le filtre de pistage de la minicarte (menu déroulant ressources / herbes / minerai / etc.). Le désactiver supprime le petit anneau/contrôle à côté de la minicarte.",
    ["MMSKIN_MISSIONS"] = "Bouton des missions",
    ["MMSKIN_MISSIONS_DESC"] = "Affiche le bouton de la page d'accueil d'extension / des missions.",
    ["MMSKIN_GAMETIME"] = "Icône du calendrier",
    ["MMSKIN_GAMETIME_DESC"] = "Affiche le bouton du calendrier (GameTime) sur la minicarte.",

    ["MMSKIN_PLUMBER_HIDE_BLIZZARD"] = "Masquer le bouton d'extension Blizzard en double avec Plumber",
    ["MMSKIN_PLUMBER_HIDE_BLIZZARD_DESC"] = "Lorsque Plumber est chargé, garde le bouton d'extension de la minicarte de Blizzard masqué afin que seul le contrôle Résumé d'extension de Plumber soit affiché. Désactivez pour afficher les deux (non recommandé).",
    ["MMSKIN_PLUMBER_STATUS_ON"] = "Plumber est chargé — cette option s'applique.",
    ["MMSKIN_PLUMBER_STATUS_OFF"] = "Plumber n'est pas chargé — activez ceci avant de vous connecter, ou rechargez après avoir installé Plumber.",

    ["MMSKIN_HIDE_ADDONS"] = "Masquer les icônes d'addons",
    ["MMSKIN_HIDE_ADDONS_DESC"] = "Masque les boutons d'addons de la minicarte jusqu'à ce que vous survoliez la zone de la minicarte.",
    ["MMSKIN_COMBAT_FADE"] = "Estompage en combat",
    ["MMSKIN_COMBAT_FADE_DESC"] = "Réduit l'opacité de la minicarte pendant le combat.",
    ["MMSKIN_PET_HIDE"] = "Masquer pendant les combats de mascottes",
    ["MMSKIN_PET_HIDE_DESC"] = "Masque la minicarte pendant les combats de mascottes.",

    ["MMSKIN_SCALE_LABEL"] = "Échelle du groupe de minicarte",
    ["MMSKIN_SECTION_BORDER"] = "Paramètres de bordure",
    ["MMSKIN_BORDER_SIZE"] = "Taille de la bordure",
    ["MMSKIN_BORDER_RED"] = "Rouge",
    ["MMSKIN_BORDER_GREEN"] = "Vert",
    ["MMSKIN_BORDER_BLUE"] = "Bleu",
    ["MMSKIN_USE_THEME_COLOR"] = "Utiliser la couleur du thème",

    ["MMSKIN_ZONE_BG"] = "Arrière-plan de zone",
    ["MMSKIN_CLOCK_BG"] = "Arrière-plan de l'horloge",

    ["MMSKIN_AUTO_ZOOM_DELAY"] = "Délai de dézoom automatique",
    ["MMSKIN_SHOW_ZOOM_BTNS"] = "Afficher les boutons de zoom",

    ["MMSKIN_HIDE_WM_BTN"] = "Masquer le bouton de carte du monde",
    ["MMSKIN_HIDE_WM_BTN_DESC"] = "Masque le petit bouton de carte du monde sur la minicarte (vous pouvez toujours ouvrir la carte avec son raccourci).",

    ["MMSKIN_SECTION_COMBAT"] = "Paramètres d'estompage en combat",
    ["MMSKIN_COMBAT_ALPHA"] = "Opacité en combat",

    ["MMSKIN_SECTION_CLICKS"] = "Paramètres d'assignation des clics",
    ["MMSKIN_CLICK_RIGHT"] = "Clic droit",
    ["MMSKIN_CLICK_MIDDLE"] = "Clic central",
    ["MMSKIN_CLICK_BTN4"] = "Bouton 4",
    ["MMSKIN_CLICK_BTN5"] = "Bouton 5",
    ["MMSKIN_ACTION_NONE"] = "Aucune",
    ["MMSKIN_ACTION_CALENDAR"] = "Calendrier",
    ["MMSKIN_ACTION_TRACKING"] = "Pistage",
    ["MMSKIN_ACTION_MISSIONS"] = "Missions",
    ["MMSKIN_ACTION_MAP"] = "Carte",
    ["MMSKIN_WORLD_MAP_BUTTON"] = "Carte du monde",

    ["MMSKIN_SHOW_COMPARTMENT"] = "Compartiment d'addons",

    ["MMSKIN_CLOCK_TT_TOGGLE"] = "Cliquez pour afficher/masquer le gestionnaire de temps",

    ["MMSKIN_UNCLAMP"] = "Détacher du bord de l'écran",

    ["MMSKIN_ZONE_FONT_LABEL"] = "Police",
    ["MMSKIN_CLOCK_FONT_LABEL"] = "Police",
    ["MMSKIN_FONT_GLOBAL"] = "Police globale",
    ["MMSKIN_FONT_WOW_DEFAULT"] = "Défaut WoW (petite)",

    ["MMSKIN_SECTION_OPACITY"] = "Échelle et opacité",
    ["MMSKIN_OPACITY"] = "Opacité de la minicarte",

    ["MMSKIN_SECTION_DEBUG"] = "Outils de développement",
    ["MMSKIN_DEBUG_SHOW"] = "Afficher les icônes de débogage",
    ["MMSKIN_DEBUG_HIDE"] = "Masquer les icônes de débogage",
    ["MMSKIN_DEBUG_DESC"] = "Force l'affichage de toutes les icônes suivies avec des étiquettes colorées. Déplacez une étiquette pour placer cette icône sur la minicarte ; les positions sont enregistrées. Masquez le débogage pour ramener les icônes dans le groupe (sauf si la minicarte est détachée). Utile lorsque les icônes ne se déclenchent pas activement (par ex. aucun courrier dans votre boîte aux lettres).",
    ["MMSKIN_DEBUG_TT_DRAG_HINT"] = "Cliquez gauche et faites glisser pour déplacer cette icône sur la minicarte.",
    ["MMSKIN_DEBUG_TT_POS_FMT"] = "Décalage enregistré : %.0f, %.0f",

    ["MMSKIN_RELOAD_PROMPT"] = "Changer la forme de la minicarte nécessite un rechargement de l'interface.\nRecharger maintenant ?",
})
