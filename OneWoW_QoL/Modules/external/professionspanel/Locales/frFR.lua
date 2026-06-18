local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["PROFPANEL_TITLE"] = "Panneau des métiers",
    ["PROFPANEL_DESC"] = "Affiche un panneau compagnon à côté de la fenêtre de métier avec la répartition des compétences par extension, le nombre de recettes et le suivi des premières fabrications.",
    ["PROFPANEL_AUTO_SHOW"] = "Afficher le panneau automatiquement",
    ["PROFPANEL_TOGGLE_TIP"] = "Panneau de stats de métier",
    ["PROFPANEL_HIDE_TIP"] = "Cliquez pour masquer le panneau",
    ["PROFPANEL_SHOW_TIP"] = "Cliquez pour afficher le panneau",
    ["PROFPANEL_STATS_TITLE"] = "Panneau des métiers",
    ["PROFPANEL_NO_EXPANSION_DATA"] = "Aucune donnée d'extension disponible.\nOuvrez un métier pour analyser.",
    ["PROFPANEL_NO_ALT_DATA"] = "Aucun autre reroll trouvé avec ce métier",
    ["PROFPANEL_OTHER_ALTS"] = "Autres rerolls avec ce métier",
    ["PROFPANEL_LAST_SCANNED"] = "Dernière analyse : %s",
})
