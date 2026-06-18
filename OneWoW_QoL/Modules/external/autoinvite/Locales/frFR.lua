local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["AUTOINVITE_TITLE"] = "Accepter auto les invitations de groupe",
    ["AUTOINVITE_DESC"] = "Accepte automatiquement les invitations de groupe provenant de personnes de confiance. Choisissez ci-dessous quelles sources sont autorisées.",
    ["AUTOINVITE_TOGGLE_FRIENDS"] = "Des amis",
    ["AUTOINVITE_TOGGLE_FRIENDS_DESC"] = "Accepter les invitations des amis WoW et des amis Battle.net.",
    ["AUTOINVITE_TOGGLE_GUILD"] = "De la guilde",
    ["AUTOINVITE_TOGGLE_GUILD_DESC"] = "Accepter les invitations des membres de votre guilde.",
    ["AUTOINVITE_TOGGLE_ALL"] = "De n'importe qui",
    ["AUTOINVITE_TOGGLE_ALL_DESC"] = "Accepter toute invitation de groupe, quel que soit l'expéditeur. Remplace les autres options lorsqu'activé.",
})
