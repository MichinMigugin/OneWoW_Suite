local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["PLAYMOUNTS_TITLE"] = "Montarias dos jogadores",
    ["PLAYMOUNTS_DESC"] = "Detecta e exibe a montaria ou forma de movimento que outros jogadores estão usando no momento.",
    ["PLAYMOUNTS_TOGGLE_CHAT"] = "Anunciar no chat",
    ["PLAYMOUNTS_TOGGLE_CHAT_DESC"] = "Exibe o nome da montaria na sua janela de chat quando você seleciona um jogador montado.",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT"] = "Igualar montaria",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT_DESC"] = "Adiciona uma opção de clique direito nos jogadores para invocar uma montaria do mesmo tipo que eles estão usando.",
    ["PLAYMOUNTS_COLLECTED"] = "(Coletada)",
    ["PLAYMOUNTS_NOT_COLLECTED"] = "(Não coletada)",
    ["PLAYMOUNTS_USING"] = "%s está usando %s",
    ["PLAYMOUNTS_SOURCE"] = "Fonte: %s",
    ["PLAYMOUNTS_DISPLAYMODE_DESC"] = "Controla quanta informação de montaria é mostrada nas dicas e na saída do chat.",
    ["PLAYMOUNTS_MODE_NAME"] = "Nome",
    ["PLAYMOUNTS_MODE_NAMETYPE"] = "Nome + tipo",
    ["PLAYMOUNTS_MODE_ALL"] = "Detalhes completos",
    ["PLAYMOUNTS_TOOLTIP_HEADER"] = "Integração de dicas",
    ["PLAYMOUNTS_TOOLTIP_REQUIRES"] = "Requer: OneWoW Core",
    ["PLAYMOUNTS_TOOLTIP_DETECTED"] = "Status: detectado",
    ["PLAYMOUNTS_TOOLTIP_NOT_DETECTED"] = "Status: não detectado",
    ["PLAYMOUNTS_TOOLTIP_NOTE"] = "Ative ou desative as linhas de montaria nas dicas em QoL → Dicas → Montarias de jogadores.",
    ["PLAYMOUNTS_TOOLTIP_VIEW_BTN"] = "Ver configurações",
})
