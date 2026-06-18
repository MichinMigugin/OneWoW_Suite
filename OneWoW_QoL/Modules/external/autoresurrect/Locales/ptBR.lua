local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["AUTORESURRECT_TITLE"] = "Aceitar auto. ressurreição",
    ["AUTORESURRECT_DESC"] = "Aceita automaticamente os pedidos de ressurreição quando alguém conjura uma ressurreição em você. Pulado enquanto você está em combate.",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE"] = "Não aceitar em instâncias",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE_DESC"] = "Pula a auto-aceitação enquanto você está dentro de uma masmorra, raide, campo de batalha ou arena. Útil se você quiser esperar o momento certo para ressuscitar.",
})
