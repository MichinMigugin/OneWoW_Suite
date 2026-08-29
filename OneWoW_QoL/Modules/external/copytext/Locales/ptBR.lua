local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["COPYTEXT_TITLE"] = "Copiar texto",
    ["COPYTEXT_DESC"] = "Copia o texto visível de dicas ou elementos da interface para a sua área de transferência. Use /1wcopytext (ou /1wct) para copiar o que está sob o seu cursor.",
    ["COPYTEXT_TOGGLE_TOOLTIPS"] = "Modo dica",
    ["COPYTEXT_TOGGLE_TOOLTIPS_DESC"] = "Ao copiar, captura o texto de quaisquer dicas visíveis sob o seu cursor.",
    ["COPYTEXT_TOGGLE_ANYTHING"] = "Modo tudo",
    ["COPYTEXT_TOGGLE_ANYTHING_DESC"] = "Ao copiar, captura o texto de qualquer elemento da interface visível sob o seu cursor, não apenas dicas.",
    ["COPYTEXT_TOGGLE_FAST"] = "Cópia rápida",
    ["COPYTEXT_TOGGLE_FAST_DESC"] = "Seleciona automaticamente todo o texto na janela de cópia para que você possa copiá-lo instantaneamente sem precisar clicar.",
    ["COPYTEXT_NO_TEXT"] = "Nenhum texto encontrado sob o cursor.",
    ["COPYTEXT_TOOLTIP_CONTENT"] = "Conteúdo da dica",
    ["COPYTEXT_UI_CONTENT"] = "Texto da interface",
})
