local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["BAGBAR_TITLE"] = "Barra de bolsa",
    ["BAGBAR_DESC"] = "Mostra itens usáveis da bolsa em uma barra movível. Os itens são escolhidos com uma expressão de palavras-chave (igual à busca de bolsa). Equipamento equipável e itens de missão são sempre excluídos da barra (aplicado automaticamente, não mostrado no editor).",
    ["BAGBAR_LOCK_POSITION"] = "Travar posição",
    ["BAGBAR_MAX_BUTTONS"] = "Máximo de botões",
    ["BAGBAR_SHIFT_RIGHT_CLICK_TO_SKIP"] = "Shift+clique direito para ignorar nesta sessão",
    ["BAGBAR_ALT_RIGHT_CLICK_TO_BLACKLIST"] = "Alt+clique direito para colocar na lista negra permanentemente",
    ["BAGBAR_MANUAL_ITEMS_HEADER"] = "Itens manuais",
    ["BAGBAR_MANUAL_DESC"] = "Fixe itens específicos para dar-lhes maior prioridade na barra. Eles ainda devem corresponder ao seu filtro de expressão e às regras de usabilidade da barra.",
    ["BAGBAR_MACROS_HEADER"] = "Macros manuais",
    ["BAGBAR_MACROS_DESC"] = "Adicione suas macros à barra como botões personalizados. Arraste uma macro da janela de macros para a área de soltar, ou digite um nome de macro e clique em Adicionar. As macros aparecem antes dos itens de bolsa.",
    ["BAGBAR_MACRO_NAME_LABEL"] = "Nome da macro:",
    ["BAGBAR_DRAG_MACRO_HERE"] = "Arraste a macro aqui",
    ["BAGBAR_MACRO_LEFT_CLICK_TO_RUN"] = "Clique esquerdo para executar a macro",
    ["BAGBAR_MACRO_MISSING"] = "(faltando)",
    ["BAGBAR_BLACKLIST_DESC"] = "Shift+clique direito nos itens da barra para ignorá-los nesta sessão. Alt+clique direito para colocá-los na lista negra permanentemente.",
    ["BAGBAR_COLUMNS"] = "Colunas",
    ["BAGBAR_CONTEXT_LOCK"] = "Travar posição",
    ["BAGBAR_GROW_RIGHT"] = "Direita",
    ["BAGBAR_GROW_LEFT"] = "Esquerda",
    ["BAGBAR_EXPRESSION_FILTER_HEADER"] = "Filtro de expressão",
    ["BAGBAR_EXPRESSION_FILTER_DESC"] = "Expressão de palavras-chave que determina quais itens de bolsa aparecem (mesmas palavras-chave que a busca de bolsa). Clique em ? para ajuda. Equipamento equipável e itens de missão são excluídos automaticamente desta expressão.",
    ["BAGBAR_EXPRESSION_FILTER_PLACEHOLDER"] = "ex.: #usable & #mount",
})
