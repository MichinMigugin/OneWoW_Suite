local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["LFGPANEL_TITLE"] = "Bloqueios de LdG",
    ["LFGPANEL_DESC"] = "Mostra seus bloqueios atuais de raide e masmorra em um painel lateral quando o Localizador de Grupo está aberto.",
    ["LFGPANEL_SHOW_PANEL"] = "Mostrar painel de bloqueios",
    ["LFGPANEL_SHOW_PANEL_DESC"] = "Mostra o painel de bloqueios quando o Localizador de Grupo abre.",
    ["LFGPANEL_FILTER_RESULTS"] = "Filtrar resultados de LdG",
    ["LFGPANEL_FILTER_RESULTS_DESC"] = "Filtra os resultados de busca de LdG pela dificuldade selecionada.",

    ["LFGPANEL_TT_REFRESH"] = "Atualizar bloqueios",
    ["LFGPANEL_TT_REFRESH_DESC"] = "Solicita os dados de bloqueio mais recentes do servidor.",
    ["LFGPANEL_TT_TOGGLE"] = "Mostrar painel de bloqueios",
    ["LFGPANEL_TT_TOGGLE_DESC"] = "Clique para mostrar o painel de bloqueios.",

    ["LFGPANEL_FILTER_DIFFICULTY"] = "Dificuldade",
    ["LFGPANEL_DIFFICULTY_NORMAL"] = "Normal",
    ["LFGPANEL_DIFFICULTY_HEROIC"] = "Heroico",
    ["LFGPANEL_DIFFICULTY_MYTHIC"] = "Mítico",
    ["LFGPANEL_DIFFICULTY_MYTHICPLUS"] = "Mítico+",
    ["LFGPANEL_DIFFICULTY_LFR"] = "LFR",

    ["LFGPANEL_NO_LOCKOUTS"] = "Nenhum bloqueio ativo.",
    ["LFGPANEL_NO_LOCKOUTS_FILTERED"] = "Nenhum bloqueio corresponde à dificuldade selecionada.",
    ["LFGPANEL_EXPIRED"] = "Expirado",
    ["LFGPANEL_EXTENDED"] = "Estendido",
    ["LFGPANEL_TT_EXTENDED"] = "Bloqueio estendido",
    ["LFGPANEL_TT_EXTENDED_DESC"] = "Este bloqueio foi estendido manualmente além de sua reinicialização normal.",

    ["LFGPANEL_TIME_DAYS"] = "%dd %dh",
    ["LFGPANEL_TIME_HOURS"] = "%dh %dm",
    ["LFGPANEL_TIME_MINUTES"] = "%dm",
    ["LFGPANEL_PROGRESS"] = "%d/%d",

    ["LFGPANEL_TT_LOCKOUT"] = "Bloqueio de instância",
    ["LFGPANEL_TT_LOCKOUT_PROGRESS"] = "Progresso de chefes: %d/%d",
    ["LFGPANEL_TT_LOCKOUT_TIME"] = "Reinicia em: %s",
    ["LFGPANEL_TT_LOCKOUT_DIFFICULTY"] = "Dificuldade: %s",

    ["LFGPANEL_OPT_FILTER_LFG"] = "Filtrar resultados de LdG",
    ["LFGPANEL_TT_FILTER_LFG"] = "Filtrar resultados de LdG",
    ["LFGPANEL_TT_FILTER_LFG_DESC"] = "Quando ativado, os resultados de busca de LdG serão filtrados conforme a dificuldade selecionada.",
})
