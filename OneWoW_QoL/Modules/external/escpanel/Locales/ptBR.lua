local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["ESCPANEL_TITLE"] = "Painel do menu ESC",
    ["ESCPANEL_DESC"] = "Exibe um cartao do personagem, colecoes e notas deste lugar, e uma faixa de portais ao lado do menu ESC. O cartao mostra o correio, a durabilidade, o Grande Cofre e o Posto Comercial, com Empreitadas opcionais. O cartao do lugar tem icones de Alerta de item para Shopping List, notas, Trackers e Farming. Os acertos ficam a esquerda de |, o resto a direita. Passe o mouse para ver detalhes; clique em um acerto para abrir. Clique nele para abrir a janela do personagem, ou no cartao do lugar para abrir essa zona no Catalogo. Escolha abaixo qual lado cada um usa.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Exibir info do personagem",
    ["ESCPANEL_TOGGLE_ENDEAVORS"] = "Exibir Empreitadas",
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
