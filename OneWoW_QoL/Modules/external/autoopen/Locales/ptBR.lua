local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["AUTOOPEN_TITLE"] = "Abertura automática",
    ["AUTOOPEN_DESC"] = "Abre automaticamente bolsas, caixas e outros itens recipiente quando aparecem no seu inventário. Não abre itens em um banco, caixa de correio ou comerciante. Itens que você ainda não pode abrir (baús trancados, nível/classe/profissão errados, ou enquanto o espaço está ocupado) são pulados automaticamente.",
    ["AUTOOPEN_OPENING"] = "Abrindo automaticamente: %s",
    ["AUTOOPEN_BLACKLIST_DESC"] = "Adicione itens para impedir que a Abertura automática os abra.",
    ["AUTOOPEN_BLACKLIST_REMOVED"] = "Removido da lista negra: %s",
})
