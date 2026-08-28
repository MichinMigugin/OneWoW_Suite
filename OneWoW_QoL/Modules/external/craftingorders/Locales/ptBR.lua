local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["CRAFTORDERS_TITLE"] = "Pedidos de criacao",
    ["CRAFTORDERS_DESC"] = "Substitui a lista de pedidos por Pode criar agora e Faltam materiais. Coloque os reagentes que faltam numa lista de compras. Comece, crie e conclua com um botao.",
    ["CRAFTORDERS_SECTION_READY"] = "Pode criar agora",
    ["CRAFTORDERS_SECTION_MISSING"] = "Faltam materiais",
    ["CRAFTORDERS_WEEKLY_NOT_ACCEPTED"] = "Semanal: nao aceita",
    ["CRAFTORDERS_WEEKLY_NOT_LEARNED"] = "Semanal: nao aprendida",
    ["CRAFTORDERS_WEEKLY_COMPLETE"] = "Semanal: concluida",
    ["CRAFTORDERS_WEEKLY_PROGRESS"] = "Semanal: %d / %d preenchidos",
    ["CRAFTORDERS_LOADING"] = "Carregando pedidos...",
    ["CRAFTORDERS_ADD_ACTIVE"] = "Adicionar a %s",
    ["CRAFTORDERS_MAKE_LIST"] = "Criar lista",
    ["CRAFTORDERS_ADD_MENU_HINT"] = "Clique com o botao direito para criar uma lista ou escolher outra.",
    ["CRAFTORDERS_ELSEWHERE_TIP"] = "Tambem em: %s",
    ["CRAFTORDERS_COL_CRAFT"] = "Pedido",
    ["CRAFTORDERS_COL_YOU"] = "Voce fornece",
    ["CRAFTORDERS_COL_CART"] = "Lista",
    ["CRAFTORDERS_COL_CUSTOMER"] = "Cliente fornece",
    ["CRAFTORDERS_COL_REWARD"] = "Voce recebe",
    ["CRAFTORDERS_USE_WOWUI"] = "WoW UI",
    ["CRAFTORDERS_USE_ONEUI"] = "One UI",
    ["CRAFTORDERS_TOGGLE_WOWUI"] = "Usar lista do WoW",
    ["CRAFTORDERS_TOGGLE_WOWUI_DESC"] = "Mostrar a tabela de pedidos da Blizzard em vez de Pode criar agora e Faltam materiais.",
    ["CRAFTORDERS_TOGGLE_HIDE_UNLEARNED"] = "Ocultar receitas nao aprendidas",
    ["CRAFTORDERS_TOGGLE_HIDE_UNLEARNED_DESC"] = "Ocultar pedidos cuja receita voce ainda nao aprendeu.",
    ["CRAFTORDERS_BUCKET_COUNT"] = "%d pedidos",
    ["CRAFTORDERS_ORDER_LIST_NAME"] = "Pedido: %s",
    ["CRAFTORDERS_NO_SHOPPING"] = "Ative a Lista de Compras para adicionar reagentes.",
    ["CRAFTORDERS_KP"] = "%d CP",
    ["CRAFTORDERS_ACUITY"] = "Acuidade x%d",
})
