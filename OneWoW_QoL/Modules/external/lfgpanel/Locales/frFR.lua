local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["LFGPANEL_TITLE"] = "Verrouillages OdG",
    ["LFGPANEL_DESC"] = "Affiche vos verrouillages actuels de raid et de donjon dans un panneau latéral lorsque l'outil de recherche de groupe est ouvert.",
    ["LFGPANEL_SHOW_PANEL"] = "Afficher le panneau des verrouillages",
    ["LFGPANEL_SHOW_PANEL_DESC"] = "Affiche le panneau des verrouillages lorsque l'outil de recherche de groupe s'ouvre.",
    ["LFGPANEL_FILTER_RESULTS"] = "Filtrer les résultats OdG",
    ["LFGPANEL_FILTER_RESULTS_DESC"] = "Filtre les résultats de recherche OdG selon la difficulté sélectionnée.",

    ["LFGPANEL_TT_REFRESH"] = "Actualiser les verrouillages",
    ["LFGPANEL_TT_REFRESH_DESC"] = "Demande les dernières données de verrouillage au serveur.",
    ["LFGPANEL_TT_TOGGLE"] = "Afficher le panneau des verrouillages",
    ["LFGPANEL_TT_TOGGLE_DESC"] = "Cliquez pour afficher le panneau des verrouillages.",

    ["LFGPANEL_FILTER_DIFFICULTY"] = "Difficulté",
    ["LFGPANEL_DIFFICULTY_NORMAL"] = "Normal",
    ["LFGPANEL_DIFFICULTY_HEROIC"] = "Héroïque",
    ["LFGPANEL_DIFFICULTY_MYTHIC"] = "Mythique",
    ["LFGPANEL_DIFFICULTY_MYTHICPLUS"] = "Mythique+",
    ["LFGPANEL_DIFFICULTY_LFR"] = "LFR",

    ["LFGPANEL_NO_LOCKOUTS"] = "Aucun verrouillage actif.",
    ["LFGPANEL_NO_LOCKOUTS_FILTERED"] = "Aucun verrouillage ne correspond à la difficulté sélectionnée.",
    ["LFGPANEL_EXPIRED"] = "Expiré",
    ["LFGPANEL_EXTENDED"] = "Prolongé",
    ["LFGPANEL_TT_EXTENDED"] = "Verrouillage prolongé",
    ["LFGPANEL_TT_EXTENDED_DESC"] = "Ce verrouillage a été prolongé manuellement au-delà de sa réinitialisation normale.",

    ["LFGPANEL_TIME_DAYS"] = "%dd %dh",
    ["LFGPANEL_TIME_HOURS"] = "%dh %dm",
    ["LFGPANEL_TIME_MINUTES"] = "%dm",
    ["LFGPANEL_PROGRESS"] = "%d/%d",

    ["LFGPANEL_TT_LOCKOUT"] = "Verrouillage d'instance",
    ["LFGPANEL_TT_LOCKOUT_PROGRESS"] = "Progression des boss : %d/%d",
    ["LFGPANEL_TT_LOCKOUT_TIME"] = "Réinitialisation dans : %s",
    ["LFGPANEL_TT_LOCKOUT_DIFFICULTY"] = "Difficulté : %s",

    ["LFGPANEL_OPT_FILTER_LFG"] = "Filtrer les résultats OdG",
    ["LFGPANEL_TT_FILTER_LFG"] = "Filtrer les résultats OdG",
    ["LFGPANEL_TT_FILTER_LFG_DESC"] = "Lorsque activé, les résultats de recherche OdG seront filtrés selon la difficulté sélectionnée.",
})
