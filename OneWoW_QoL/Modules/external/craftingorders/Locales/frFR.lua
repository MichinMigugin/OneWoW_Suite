local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["CRAFTORDERS_TITLE"] = "Commandes d'artisanat",
    ["CRAFTORDERS_DESC"] = "Remplace la liste des commandes par Faisable maintenant et Matériaux manquants. Ajoutez les réactifs manquants a une liste de courses. Demarrer, fabriquer et terminer avec un seul bouton.",
    ["CRAFTORDERS_SECTION_READY"] = "Faisable maintenant",
    ["CRAFTORDERS_SECTION_MISSING"] = "Matériaux manquants",
    ["CRAFTORDERS_WEEKLY_NOT_ACCEPTED"] = "Hebdomadaire : non acceptee",
    ["CRAFTORDERS_WEEKLY_NOT_LEARNED"] = "Hebdomadaire : non apprise",
    ["CRAFTORDERS_WEEKLY_COMPLETE"] = "Hebdomadaire : terminee",
    ["CRAFTORDERS_WEEKLY_PROGRESS"] = "Hebdomadaire : %d / %d remplis",
    ["CRAFTORDERS_LOADING"] = "Chargement des commandes...",
    ["CRAFTORDERS_ADD_ACTIVE"] = "Ajouter a %s",
    ["CRAFTORDERS_MAKE_LIST"] = "Creer une liste",
    ["CRAFTORDERS_ADD_MENU_HINT"] = "Clic droit pour creer une liste ou en choisir une autre.",
    ["CRAFTORDERS_ELSEWHERE_TIP"] = "Aussi dans : %s",
    ["CRAFTORDERS_COL_CRAFT"] = "Commande",
    ["CRAFTORDERS_COL_YOU"] = "Vous fournissez",
    ["CRAFTORDERS_COL_CART"] = "Liste",
    ["CRAFTORDERS_COL_CUSTOMER"] = "Le client fournit",
    ["CRAFTORDERS_COL_REWARD"] = "Vous recevez",
    ["CRAFTORDERS_USE_WOWUI"] = "WoW UI",
    ["CRAFTORDERS_USE_ONEUI"] = "One UI",
    ["CRAFTORDERS_TOGGLE_WOWUI"] = "Liste WoW",
    ["CRAFTORDERS_TOGGLE_WOWUI_DESC"] = "Afficher le tableau des commandes de Blizzard a la place de Faisable maintenant et Materiaux manquants.",
    ["CRAFTORDERS_TOGGLE_HIDE_UNLEARNED"] = "Masquer les recettes non apprises",
    ["CRAFTORDERS_TOGGLE_HIDE_UNLEARNED_DESC"] = "Masquer les commandes dont vous n'avez pas appris la recette.",
    ["CRAFTORDERS_BUCKET_COUNT"] = "%d commandes",
    ["CRAFTORDERS_ORDER_LIST_NAME"] = "Commande : %s",
    ["CRAFTORDERS_NO_SHOPPING"] = "Activez la liste de courses pour ajouter des reactifs.",
    ["CRAFTORDERS_KP"] = "%d PC",
    ["CRAFTORDERS_ACUITY"] = "Acuite x%d",
    ["CRAFTORDERS_INCOMPATIBLE_TITLE"] = "Autres addons de liste de commandes",
    ["CRAFTORDERS_INCOMPATIBLE_BODY"] = "%s est active. Ces addons restent charges. Activez ceci pour One UI, ou desactivez-le pour les utiliser.",
})
