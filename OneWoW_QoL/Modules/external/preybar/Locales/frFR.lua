local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["PREYBAR_TITLE"] = "Barre de chasse à la proie",
    ["PREYBAR_DESC"] = "Affiche une barre déplaçable qui suit votre progression de chasse à la proie (Froid > Tiède > Chaud > Prêt) pour la zone actuelle, avec le boss, la difficulté et les affixes de la chasse active. Déverrouillez-la pour la mettre en place.",

    ["PREYBAR_TOGGLE_BOSS"] = "Afficher le nom du boss",
    ["PREYBAR_TOGGLE_BOSS_DESC"] = "Affiche le nom de la chasse à la proie active au-dessus de la barre.",
    ["PREYBAR_TOGGLE_DIFFICULTY"] = "Afficher la difficulté",
    ["PREYBAR_TOGGLE_DIFFICULTY_DESC"] = "Affiche la difficulté de la chasse (Normal, Difficile, Cauchemar).",
    ["PREYBAR_TOGGLE_AFFIXES"] = "Afficher les affixes",
    ["PREYBAR_TOGGLE_AFFIXES_DESC"] = "Affiche les icônes d'affixes de la chasse active sous la barre.",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD"] = "Masquer le widget Blizzard",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD_DESC"] = "Masque le widget de progression de chasse à la proie par défaut de Blizzard tant que cette barre est active.",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT"] = "Cliquer pour définir un point de passage",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT_DESC"] = "Quand la proie est prête, cliquez sur la barre pour définir un point de passage vers la chasse sur la carte.",
    ["PREYBAR_TOGGLE_LOCK"] = "Verrouiller la position",
    ["PREYBAR_TOGGLE_LOCK_DESC"] = "Verrouille la barre pour qu'elle ne puisse pas être déplacée. Désactivez ceci et ouvrez ce panneau de paramètres pour repositionner la barre à l'aide de l'aperçu d'exemple.",

    ["PREYBAR_STATE_COLD"] = "Froid",
    ["PREYBAR_STATE_WARM"] = "Tiède",
    ["PREYBAR_STATE_HOT"] = "Chaud",
    ["PREYBAR_STATE_READY"] = "Prêt",

    ["PREYBAR_DIFFICULTY_NORMAL"] = "Normal",
    ["PREYBAR_DIFFICULTY_HARD"] = "Difficile",
    ["PREYBAR_DIFFICULTY_NIGHTMARE"] = "Cauchemar",

    ["PREYBAR_AFFIX_AMBUSH"] = "Embuscade",
    ["PREYBAR_AFFIX_TORMENT"] = "Tourment",
    ["PREYBAR_AFFIX_SEEPING_GORE"] = "Sang suintant",
    ["PREYBAR_AFFIX_ECHO"] = "Écho de prédation",
    ["PREYBAR_AFFIX_BLOODY"] = "Ordre sanglant",

    ["PREYBAR_ADVICE_AMBUSHED"] = "Pris en embuscade !",
    ["PREYBAR_ADVICE_KILL"] = "Tuez quelque chose !",
    ["PREYBAR_ADVICE_READY"] = "La proie est prête - chassez-la !",

    ["PREYBAR_STATE_LABEL"] = "%s  %d%%",
    ["PREYBAR_DEMO_BOSS"] = "Proie d'exemple",
    ["PREYBAR_DRAG_HINT"] = "Déverrouiller pour déplacer  -  Barre de chasse à la proie",
    ["PREYBAR_CLICK_WAYPOINT_HINT"] = "Cliquez pour définir un point de passage vers votre proie",
    ["PREYBAR_OPACITY_FMT"] = "Opacité : %d%%",
    ["PREYBAR_SAMPLE_BAR_HEADER"] = "Barre d'exemple",
    ["PREYBAR_SETTINGS_HINT"] = "Une barre d'exemple est affichée tant que ce panneau est ouvert afin que vous puissiez la positionner. Désactivez Verrouiller la position pour la déplacer, puis verrouillez-la à nouveau. En dehors de ce panneau, la barre n'apparaît que pendant une chasse à la proie active.",
})
