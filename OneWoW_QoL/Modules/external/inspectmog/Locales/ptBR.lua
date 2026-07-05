local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["INSPECTMOG_TITLE"] = "Inspecionar equipamento",
    ["INSPECTMOG_DESC"] = "Adiciona um painel lateral à janela de inspeção listando o equipamento usado pelo jogador que você está inspecionando. Salve a lista inteira em uma nota de jogador do OneWoW Notes, ou Shift-clique em qualquer item para adicioná-lo às suas notas de itens.",

    ["INSPECTMOG_ADD_NOTE"] = "Adicionar à nota do jogador",
    ["INSPECTMOG_ADD_ALL"] = "Adicionar tudo",
    ["INSPECTMOG_EMPTY"] = "Ainda não há equipamento inspecionável.",
    ["INSPECTMOG_PANEL_TITLE"] = "Ferramenta de inspeção de transmog",
    ["INSPECTMOG_NO_DATA"] = "Nenhum dado de inspeção disponível.",
    ["INSPECTMOG_UNKNOWN_PLAYER"] = "Jogador inspecionado",
    ["INSPECTMOG_NATIVE_APPEARANCE"] = "Aparência original",
    ["INSPECTMOG_SOURCE_FORMAT"] = "Fonte #%d",
    ["INSPECTMOG_APPEARANCE_SOURCE_FORMAT"] = "Fonte da aparência: %d",

    ["INSPECTMOG_TT_PREVIEW"] = "Ctrl-clique para visualizar no provador",
    ["INSPECTMOG_TT_NOTES"] = "Shift-clique para adicionar a Notes > Itens",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED"] = "Shift-clique para adicionar o item equipado a Notes > Itens",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED_COLL"] = "Shift-clique para adicionar a aparência deste item a Notes > Colecionáveis",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE"] = "Shift-clique para adicionar a aparência de transmog a Notes > Itens",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE_COLL"] = "Shift-clique para adicionar a aparência de transmog a Notes > Colecionáveis",
    ["INSPECTMOG_ROUTE_COLLECTIBLES"] = "Adicionar aparências aos Colecionáveis",
    ["INSPECTMOG_TT_PREVIEW_EQUIPPED"] = "Ctrl-clique para visualizar o item equipado",
    ["INSPECTMOG_TT_PREVIEW_APPEARANCE"] = "Ctrl-clique para visualizar a aparência de transmog",
    ["INSPECTMOG_TT_HIDDEN_APPEARANCE"] = "Aparências ocultas não são adicionadas às notas de itens",
    ["INSPECTMOG_TT_ADD_ALL_TITLE"] = "Adicionar todo o transmog",
    ["INSPECTMOG_TT_ADD_ALL_DESC"] = "Adiciona todos os itens de aparência de transmog visíveis a Notes > Itens.",

    ["INSPECTMOG_TT_ADD_NOTE_TITLE"] = "Salvar equipamento na nota do jogador",
    ["INSPECTMOG_TT_ADD_NOTE_DESC"] = "Grava cada espaço e item listado na nota deste jogador no OneWoW Notes. Salvar novamente atualiza o bloco de equipamento e mantém o restante da nota.",

    ["INSPECTMOG_NOTE_HEADER"] = "[OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_FOOTER"] = "[/OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_UPDATED"] = "Inspecionado: %s",
    ["INSPECTMOG_NOTE_LINE"] = "%s - %s",

    ["INSPECTMOG_ITEM_STAMP"] = "TMOG inspecionado em %s - %s",

    ["INSPECTMOG_STATUS_NOTE_SAVED"] = "Equipamento salvo na nota de %s.",
    ["INSPECTMOG_STATUS_NOTE_UPDATED"] = "Equipamento atualizado na nota de %s.",
    ["INSPECTMOG_STATUS_ITEM_ADDED"] = "%s adicionado às notas de itens.",
    ["INSPECTMOG_STATUS_NOTES_MISSING"] = "O OneWoW Notes não está instalado.",
    ["INSPECTMOG_STATUS_NO_DATA"] = "Ainda não há dados de equipamento disponíveis.",
})
