local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["FASTFORWARD_TITLE"] = "Avanço rápido",
    ["FASTFORWARD_DESC"] = "Pula automaticamente os filmes e cinemáticas do jogo. Segure qualquer tecla modificadora enquanto um filme ou cinemática começa para assisti-lo.",
    ["FASTFORWARD_TOGGLE_MOVIES"] = "Pular filmes",
    ["FASTFORWARD_TOGGLE_MOVIES_DESC"] = "Para automaticamente os filmes do jogo quando começam a tocar.",
    ["FASTFORWARD_TOGGLE_CINEMATICS"] = "Pular cinemáticas",
    ["FASTFORWARD_TOGGLE_CINEMATICS_DESC"] = "Cancela automaticamente as sequências cinemáticas do jogo quando começam.",
    ["FASTFORWARD_TOGGLE_INSTANCE"] = "Apenas em instâncias",
    ["FASTFORWARD_TOGGLE_INSTANCE_DESC"] = "Só pula filmes e cinemáticas enquanto você está dentro de uma masmorra, raide ou outra instância.",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE"] = "Respeitar as não canceláveis",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE_DESC"] = "Não tenta pular cinemáticas que o jogo marca como não canceláveis.",
})
