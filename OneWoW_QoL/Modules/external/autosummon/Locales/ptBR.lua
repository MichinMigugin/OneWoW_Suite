local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["AUTOSUMMON_TITLE"] = "Aceitar auto. invocação",
    ["AUTOSUMMON_DESC"] = "Aceita automaticamente os pedidos de invocação de bruxos e pedras de invocação.",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT"] = "Pular em combate",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT_DESC"] = "Não aceitar automaticamente enquanto você está em combate. Recomendado ativado para que você não seja puxado no meio da luta.",
})
