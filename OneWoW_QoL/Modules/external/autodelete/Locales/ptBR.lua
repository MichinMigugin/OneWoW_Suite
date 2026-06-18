local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["AUTODELETE_TITLE"] = "Exclusão automática",
    ["AUTODELETE_DESC"] = "Evite digitar EXCLUIR ao destruir itens. O botão de confirmação fica imediatamente disponível sem que você precise digitar nada.",
    ["AUTODELETE_TOGGLE_SKIP"] = "Pular confirmação digitada",
    ["AUTODELETE_TOGGLE_SKIP_DESC"] = "Ativa automaticamente o botão Excluir sem exigir que você digite EXCLUIR.",
    ["AUTODELETE_TOGGLE_LINK"] = "Mostrar link do item",
    ["AUTODELETE_TOGGLE_LINK_DESC"] = "Mostra o link do item no pop-up de confirmação para que você veja o que está prestes a excluir.",
})
