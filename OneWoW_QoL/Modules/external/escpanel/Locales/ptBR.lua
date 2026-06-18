local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["ESCPANEL_TITLE"] = "Painel do menu ESC",
    ["ESCPANEL_DESC"] = "Exibe info do personagem, alertas, notas de zona e uma faixa de portais ao lado do menu ESC. Escolha abaixo qual lado cada um usa.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Exibir info do personagem",
    ["ESCPANEL_TOGGLE_ALERTS"] = "Exibir alertas",
    ["ESCPANEL_TOGGLE_ZONE_NOTES"] = "Exibir notas de zona",
    ["ESCPANEL_TOGGLE_HIDE_ZONE_EMPTY"] = "Ocultar notas de zona quando vazias",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "Exibir portais",
    ["ESCPANEL_LAYOUT_HEADER"] = "Disposição",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "Lado dos painéis de info",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "Lado dos portais",
    ["ESCPANEL_SIDE_LEFT"] = "À esquerda do menu",
    ["ESCPANEL_SIDE_RIGHT"] = "À direita do menu",
    ["ESCPANEL_LAYOUT_DESC"] = "Quando ambos estão do mesmo lado, os portais ficam na parte externa (mais longe do menu) e os painéis ao lado do menu.",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "Tamanho dos ícones de portal",
})
