local ADDON_NAME = ...

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(ADDON_NAME, "ptBR", {

    -- migrated from OneWoW scope
    ["CTX_OPEN_DD"] = "Abrir Depósito Direto",
    ["ADDON_TITLE"] = "Depósito Direto",
    ["ADDON_SUBTITLE"] = "Gerenciamento Automático de Ouro do Banco da Tropa",

    ["ENABLED"] = "Ativado",
    ["DISABLED"] = "Desativado",

    ["TAB_GOLD"] = "Ouro",

    ["DIRECT_DEPOSIT_TITLE"] = "Depósito Direto",
    ["DIRECT_DEPOSIT_DESCRIPTION"] = "Gerencie o ouro automaticamente entre seu personagem e o Banco da Tropa. Defina um valor-alvo para manter no personagem, e o sistema depositará o ouro excedente ou sacará quando faltar. Perfeito para gerenciar o ouro de vários personagens.",
    ["DIRECT_DEPOSIT_ENABLE"] = "Ativar Depósito Direto",
    ["DIRECT_DEPOSIT_ENABLE_DESC"] = "Deposita ou saca ouro do seu Banco da Tropa automaticamente para manter um valor-alvo no personagem ao abrir o banco.",

    ["ACCOUNT_SETTINGS"] = "Configurações de Toda a Conta",
    ["ACCOUNT_SETTINGS_DESC"] = "Estas configurações se aplicam a todos os personagens da sua conta.",

    ["CHARACTER_SETTINGS"] = "Substituição Específica do Personagem",
    ["CHARACTER_SETTINGS_DESC"] = "Substitui as configurações de toda a conta por configurações personalizadas para este personagem específico. Útil para personagens-banco ou personagens com necessidades especiais de gerenciamento de ouro.",

    ["USE_CHAR_SETTINGS"] = "Usar Configurações Específicas do Personagem",
    ["USE_CHAR_SETTINGS_DESC"] = "Ative isto para usar configurações diferentes para este personagem em vez das configurações de toda a conta.",

    ["TARGET_GOLD"] = "Valor a Manter no Personagem",
    ["TARGET_GOLD_DESC"] = "Insira a quantidade de ouro (em peças de ouro) que você quer manter no personagem. Deixe em branco para nenhuma movimentação automática de ouro até definir. Insira 0 para não manter ouro no personagem.",
    ["GOLD"] = "ouro",

    ["DEPOSIT_ENABLE"] = "Depositar Ouro no Banco da Tropa",
    ["DEPOSIT_ENABLE_DESC"] = "Quando você tiver mais que o valor-alvo, deposita o excedente automaticamente no seu Banco da Tropa.",

    ["WITHDRAW_ENABLE"] = "Sacar Ouro do Banco da Tropa",
    ["WITHDRAW_ENABLE_DESC"] = "Quando você tiver menos que o valor-alvo, saca do seu Banco da Tropa automaticamente para atingir o alvo.",

    ["ITEM_DEPOSIT"] = "Depósito Automático de Itens",
    ["ITEM_DEPOSIT_ENABLE"] = "Ativar Depósito Automático de Itens",
    ["ITEM_DEPOSIT_ENABLE_DESC"] = "Deposita itens específicos no banco escolhido automaticamente ao abrir o banco.",
    ["ITEM_DEPOSIT_LIST"] = "Lista de Itens para Depósito Automático",
    ["ITEM_DEPOSIT_ADD_PROMPT"] = "Insira o ID do item ou shift-clique em um item para adicionar:",
    ["ITEM_DEPOSIT_WARBAND"] = "Tropa",
    ["ITEM_DEPOSIT_PERSONAL"] = "Pessoal",

    ["CLEAR"] = "Limpar",

    ["ABOUT_SECTION"] = "Sobre o Depósito Direto",
    ["ABOUT_TEXT"] = "Depósito Direto é um addon de qualidade de vida do OneWoW Suite. Este addon também está disponível como parte do OneWoW Suite completo, que inclui muitos outros addons úteis para aprimorar sua experiência em World of Warcraft. Descubra mais addons que podem ajudar você a organizar suas aventuras e melhorar sua jogabilidade!",

    ["MINIMAP_TOOLTIP_HINT"] = "Clique para alternar as configurações",

    ["ADDON_CHAT_PREFIX"] = "|cFFFFD100Direct Deposit:|r",
    ["DEPOSIT_NOW"] = "Depositar Agora",
    ["ITEM_DRAG_HINT"] = "Arraste itens aqui para adicionar",
    ["ITEM_EMPTY_LIST"] = "Nenhum item na lista de depósito automático.\nArraste itens aqui para adicioná-los.",

    ["TAB_KEYBINDS"] = "Atalhos",

    ["KEYBIND_SECTION"] = "Atalhos de Adição Rápida",
    ["KEYBIND_DESC"] = "Passe o cursor sobre qualquer item e pressione um atalho para adicioná-lo instantaneamente à lista de depósito. Atribua teclas em Menu do Jogo > Atalhos de Teclado > OneWoW Direct Deposit.",
    ["KEYBIND_ADD_PERSONAL"] = "Adicionar Item Sob o Cursor - Banco Pessoal",
    ["KEYBIND_ADD_WARBAND"] = "Adicionar Item Sob o Cursor - Banco da Tropa",
    ["KEYBIND_ADD_GUILD"] = "Adicionar Item Sob o Cursor - Banco da Guilda",
    ["KEYBIND_NO_ITEM"] = "Nenhum item encontrado - passe o cursor sobre um item primeiro.",

    ["WARBOUND_SECTION"] = "Depósito Automático da Tropa",
    ["WARBOUND_ENABLE"] = "Depositar Automaticamente Todos os Itens de Tropa",
    ["WARBOUND_ENABLE_DESC"] = "Ao abrir qualquer banco, deposita automaticamente todos os itens vinculados à tropa (vinculados à conta) das suas bolsas no Banco da Tropa. Itens que já estão na sua lista de depósito acima são excluídos.",

    ["WARBOUND_EXCLUDE_KEYWORD_LABEL"] = "Manter por Palavra-Chave",
    ["WARBOUND_EXCLUDE_KEYWORD_DESC"] = "Itens que correspondem a esta expressão de palavra-chave são mantidos nas suas bolsas e nunca depositados automaticamente. Use palavras-chave como #potion, #flask, #elixir, #consumable, separadas por | para \"ou\". Exemplo: #potion | #flask",
    ["WARBOUND_EXCLUDE_KEYWORD_PLACEHOLDER"] = "ex.: #potion | #flask",
    ["WARBOUND_EXCLUDE_ITEMS_LABEL"] = "Manter Itens Específicos",
    ["WARBOUND_EXCLUDE_ITEMS_DESC"] = "Estes itens são sempre mantidos nas suas bolsas, mesmo quando vinculados à tropa. Arraste um item aqui ou insira o ID do item.",
    ["WARBOUND_EXCLUDE_EMPTY"] = "Nenhum item mantido.\nArraste itens aqui para mantê-los nas suas bolsas.",

    ["TOOLTIP_SECTION"] = "Sobreposição de Dica",
    ["TOOLTIP_ENABLE"] = "Mostrar Status de Depósito nas Dicas",
    ["TOOLTIP_ENABLE_DESC"] = "Itens na fila para depósito mostrarão seu banco de destino na parte inferior da dica.",
    ["TOOLTIP_LABEL"] = "Depositando:",
    ["TOOLTIP_PERSONAL"] = "Pessoal",
    ["TOOLTIP_WARBAND"] = "Tropa",

    ["BINDING_HEADER_ONEWOW_DIRECTDEPOSIT"] = "|cFF00FF00OneWoW|r Direct Deposit",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_TOGGLE"] = "Alternar Janela do Direct Deposit",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_DEPOSIT"] = "Depositar Itens Agora",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_PERSONAL"] = "Adição Rápida: Banco Pessoal",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_WARBAND"] = "Adição Rápida: Banco da Tropa",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_GUILD"] = "Adição Rápida: Banco da Guilda",
})
