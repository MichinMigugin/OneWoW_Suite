local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["FASTFORWARD_TITLE"] = "Avance rapide",
    ["FASTFORWARD_DESC"] = "Passe automatiquement les films et cinématiques du jeu. Maintenez une touche de modification pendant qu'un film ou une cinématique démarre pour la regarder à la place.",
    ["FASTFORWARD_TOGGLE_MOVIES"] = "Passer les films",
    ["FASTFORWARD_TOGGLE_MOVIES_DESC"] = "Arrête automatiquement les films du jeu lorsqu'ils commencent à être lus.",
    ["FASTFORWARD_TOGGLE_CINEMATICS"] = "Passer les cinématiques",
    ["FASTFORWARD_TOGGLE_CINEMATICS_DESC"] = "Annule automatiquement les séquences cinématiques du jeu lorsqu'elles commencent.",
    ["FASTFORWARD_TOGGLE_INSTANCE"] = "Instances uniquement",
    ["FASTFORWARD_TOGGLE_INSTANCE_DESC"] = "Ne passe les films et cinématiques que lorsque vous êtes dans un donjon, un raid ou une autre instance.",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE"] = "Respecter les non-annulables",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE_DESC"] = "Ne tente pas de passer les cinématiques que le jeu marque comme ne pouvant pas être annulées.",
})
