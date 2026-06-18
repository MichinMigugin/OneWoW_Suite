local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["AUTOREPAIR_TITLE"] = "Reparo automático",
    ["AUTOREPAIR_DESC"] = "Repara automaticamente todo o seu equipamento quando você visita um comerciante que oferece reparos. Mostra o custo no chat.",
    ["AUTOREPAIR_TOGGLE_GUILD"] = "Usar reparo do banco da guilda",
    ["AUTOREPAIR_TOGGLE_GUILD_DESC"] = "Tenta usar o banco da guilda para os custos de reparo antes de usar o seu próprio ouro.",
})
