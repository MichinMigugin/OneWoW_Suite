local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["AUTODELETE_TITLE"] = "Suppression auto",
    ["AUTODELETE_DESC"] = "Évitez de taper SUPPRIMER en détruisant des objets. Le bouton de confirmation devient immédiatement disponible sans que vous ayez à taper quoi que ce soit.",
    ["AUTODELETE_TOGGLE_SKIP"] = "Ignorer la confirmation tapée",
    ["AUTODELETE_TOGGLE_SKIP_DESC"] = "Active automatiquement le bouton Supprimer sans vous obliger à taper SUPPRIMER.",
    ["AUTODELETE_TOGGLE_LINK"] = "Afficher le lien de l'objet",
    ["AUTODELETE_TOGGLE_LINK_DESC"] = "Affiche le lien de l'objet dans la fenêtre de confirmation pour que vous voyiez ce que vous êtes sur le point de supprimer.",
})
