local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["AUTOINVITE_TITLE"] = "Aceitar auto. convites de grupo",
    ["AUTOINVITE_DESC"] = "Aceita automaticamente convites de grupo que vêm de pessoas em quem você confia. Escolha abaixo quais fontes são permitidas.",
    ["AUTOINVITE_TOGGLE_FRIENDS"] = "De amigos",
    ["AUTOINVITE_TOGGLE_FRIENDS_DESC"] = "Aceitar convites de amigos do WoW e amigos do Battle.net.",
    ["AUTOINVITE_TOGGLE_GUILD"] = "Da guilda",
    ["AUTOINVITE_TOGGLE_GUILD_DESC"] = "Aceitar convites de membros da sua guilda.",
    ["AUTOINVITE_TOGGLE_ALL"] = "De qualquer um",
    ["AUTOINVITE_TOGGLE_ALL_DESC"] = "Aceitar qualquer convite de grupo, independentemente de quem enviou. Substitui as outras opções quando ativado.",
})
