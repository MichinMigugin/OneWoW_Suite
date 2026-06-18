local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["DECLINEDUEL_TITLE"] = "Recusar auto. duelos",
    ["DECLINEDUEL_DESC"] = "Recusa automaticamente os pedidos de duelo para que o pop-up nunca fique na sua tela.",
    ["DECLINEDUEL_TOGGLE_PET"] = "Recusar também duelos de mascotes",
    ["DECLINEDUEL_TOGGLE_PET_DESC"] = "Também recusa automaticamente os pedidos de duelo de batalha de mascotes.",
})
