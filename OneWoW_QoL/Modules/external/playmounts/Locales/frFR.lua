local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["PLAYMOUNTS_TITLE"] = "Montures des joueurs",
    ["PLAYMOUNTS_DESC"] = "Détecte et affiche la monture ou la forme de déplacement actuellement utilisée par les autres joueurs.",
    ["PLAYMOUNTS_TOGGLE_CHAT"] = "Annoncer dans le chat",
    ["PLAYMOUNTS_TOGGLE_CHAT_DESC"] = "Affiche le nom de la monture dans votre fenêtre de chat lorsque vous sélectionnez un joueur monté.",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT"] = "Monture assortie",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT_DESC"] = "Ajoute une option de clic droit sur les joueurs pour invoquer une monture du même type que celle qu'ils chevauchent.",
    ["PLAYMOUNTS_COLLECTED"] = "(Collectée)",
    ["PLAYMOUNTS_NOT_COLLECTED"] = "(Non collectée)",
    ["PLAYMOUNTS_USING"] = "%s utilise %s",
    ["PLAYMOUNTS_SOURCE"] = "Source : %s",
    ["PLAYMOUNTS_DISPLAYMODE_DESC"] = "Contrôle la quantité d'informations sur la monture affichée dans les infobulles et la sortie du chat.",
    ["PLAYMOUNTS_MODE_NAME"] = "Nom",
    ["PLAYMOUNTS_MODE_NAMETYPE"] = "Nom + type",
    ["PLAYMOUNTS_MODE_ALL"] = "Détails complets",
    ["PLAYMOUNTS_TOOLTIP_HEADER"] = "Intégration des infobulles",
    ["PLAYMOUNTS_TOOLTIP_REQUIRES"] = "Nécessite : OneWoW Core",
    ["PLAYMOUNTS_TOOLTIP_DETECTED"] = "État : détecté",
    ["PLAYMOUNTS_TOOLTIP_NOT_DETECTED"] = "État : non détecté",
    ["PLAYMOUNTS_TOOLTIP_NOTE"] = "Activez ou désactivez les lignes d'infobulle de monture dans QoL → Infobulles → Montures des joueurs.",
    ["PLAYMOUNTS_TOOLTIP_VIEW_BTN"] = "Voir les paramètres",
})
