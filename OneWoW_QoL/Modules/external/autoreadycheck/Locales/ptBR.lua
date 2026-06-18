local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["AUTOREADYCHECK_TITLE"] = "Aceitar auto. verificação de prontidão",
    ["AUTOREADYCHECK_DESC"] = "Confirma automaticamente que você está pronto quando uma verificação de prontidão é chamada no seu grupo.",
    ["AUTOREADYCHECK_TOGGLE_DEAD"] = "Pular se estiver morto",
    ["AUTOREADYCHECK_TOGGLE_DEAD_DESC"] = "Não aceitar automaticamente se você estiver morto ou for um fantasma, para que o grupo veja que você não está pronto para iniciar.",
})
