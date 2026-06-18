local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["QUESTTOOLS_TITLE"] = "Ferramentas de missão",
    ["QUESTTOOLS_DESC"] = "Automatiza a aceitação de missões, a entrega, o destaque de recompensa e o diálogo rotulado como missão opcional. Segure Shift ao abrir um diálogo de missão ou conversa para pular a auto-aceitação ou o auto-diálogo.",
    ["QUESTTOOLS_TOGGLE_ACCEPT"] = "Aceitar missões automaticamente",
    ["QUESTTOOLS_TOGGLE_ACCEPT_DESC"] = "Aceita missões automaticamente quando o diálogo de missão aparece. Segure Shift ao abrir o diálogo para pular a auto-aceitação.",
    ["QUESTTOOLS_TOGGLE_TURNIN"] = "Entregar missões automaticamente",
    ["QUESTTOOLS_TOGGLE_TURNIN_DESC"] = "Conclui e entrega missões automaticamente quando você cumpriu todos os requisitos. Se houver várias recompensas disponíveis, espera você escolher.",
    ["QUESTTOOLS_TOGGLE_REWARDS"] = "Destacar a melhor recompensa",
    ["QUESTTOOLS_TOGGLE_REWARDS_DESC"] = "Mostra um ícone de moeda de ouro no item de recompensa de missão com o maior valor de venda ao vendedor.",
    ["QUESTTOOLS_TOGGLE_GOSSIP"] = "Auto-diálogo (linhas rotuladas como missão)",
    ["QUESTTOOLS_TOGGLE_GOSSIP_DESC"] = "Seleciona automaticamente as opções de diálogo marcadas como rotuladas de missão (QuestLabelPrepend), ou seja, as mesmas linhas que a interface mostra com o rótulo no estilo missão. Se mais de uma se qualificar, usa o texto visível da linha para decidir. Segure Shift ao abrir o diálogo para pular. Requer suporte a C_GossipInfo e QuestLabelPrepend (FlagsUtil / Enum.GossipOptionRecFlags) no seu cliente.",
})
