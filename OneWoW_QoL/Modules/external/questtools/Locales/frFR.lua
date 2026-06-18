local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["QUESTTOOLS_TITLE"] = "Outils de quête",
    ["QUESTTOOLS_DESC"] = "Automatise l'acceptation des quêtes, le rendu, la mise en évidence des récompenses et le dialogue libellé quête en option. Maintenez Maj en ouvrant un dialogue de quête ou de dialogue pour ignorer l'auto-acceptation ou l'auto-dialogue.",
    ["QUESTTOOLS_TOGGLE_ACCEPT"] = "Accepter les quêtes automatiquement",
    ["QUESTTOOLS_TOGGLE_ACCEPT_DESC"] = "Accepte automatiquement les quêtes lorsque le dialogue de quête apparaît. Maintenez Maj en ouvrant le dialogue pour ignorer l'auto-acceptation.",
    ["QUESTTOOLS_TOGGLE_TURNIN"] = "Rendre les quêtes automatiquement",
    ["QUESTTOOLS_TOGGLE_TURNIN_DESC"] = "Termine et rend automatiquement les quêtes lorsque vous avez rempli toutes les conditions. Si plusieurs récompenses sont disponibles, il attend votre choix.",
    ["QUESTTOOLS_TOGGLE_REWARDS"] = "Mettre en évidence la meilleure récompense",
    ["QUESTTOOLS_TOGGLE_REWARDS_DESC"] = "Affiche une icône de pièce d'or sur l'objet de récompense de quête ayant la plus haute valeur de vente chez le marchand.",
    ["QUESTTOOLS_TOGGLE_GOSSIP"] = "Auto-dialogue (lignes libellées quête)",
    ["QUESTTOOLS_TOGGLE_GOSSIP_DESC"] = "Sélectionne automatiquement les options de dialogue marquées comme libellées quête (QuestLabelPrepend), c.-à-d. les mêmes lignes que l'interface affiche avec le label de style quête. Si plusieurs conviennent, utilise le texte visible de la ligne pour décider. Maintenez Maj en ouvrant le dialogue pour ignorer. Nécessite la prise en charge de C_GossipInfo et QuestLabelPrepend (FlagsUtil / Enum.GossipOptionRecFlags) sur votre client.",
})
