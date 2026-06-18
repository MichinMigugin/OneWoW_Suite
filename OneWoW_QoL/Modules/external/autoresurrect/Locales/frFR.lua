local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["AUTORESURRECT_TITLE"] = "Accepter auto la résurrection",
    ["AUTORESURRECT_DESC"] = "Accepte automatiquement les demandes de résurrection lorsque quelqu'un lance une résurrection sur vous. Ignoré pendant que vous êtes en combat.",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE"] = "Ne pas accepter en instance",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE_DESC"] = "Ignore l'auto-acceptation pendant que vous êtes dans un donjon, un raid, un champ de bataille ou une arène. Utile si vous voulez attendre le bon moment pour ressusciter.",
})
