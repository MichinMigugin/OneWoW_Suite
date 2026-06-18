local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["PROFPANEL_TITLE"] = "Painel de profissões",
    ["PROFPANEL_DESC"] = "Mostra um painel complementar ao lado da janela de profissão com detalhamento de perícia por expansão, contagem de receitas e rastreamento da primeira fabricação.",
    ["PROFPANEL_AUTO_SHOW"] = "Exibir painel automaticamente",
    ["PROFPANEL_TOGGLE_TIP"] = "Painel de estatísticas de profissão",
    ["PROFPANEL_HIDE_TIP"] = "Clique para ocultar o painel",
    ["PROFPANEL_SHOW_TIP"] = "Clique para mostrar o painel",
    ["PROFPANEL_STATS_TITLE"] = "Painel de profissões",
    ["PROFPANEL_NO_EXPANSION_DATA"] = "Nenhum dado de expansão disponível.\nAbra uma profissão para escanear.",
    ["PROFPANEL_NO_ALT_DATA"] = "Nenhum outro alt encontrado com esta profissão",
    ["PROFPANEL_OTHER_ALTS"] = "Outros alts com esta profissão",
    ["PROFPANEL_LAST_SCANNED"] = "Último escaneamento: %s",
})
