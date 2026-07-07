local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["MMSKIN_TITLE"] = "Ferramentas de mapa (mini)",
    ["MMSKIN_DESC"] = "Personalize o conjunto do seu minimapa: forma, borda, texto de zona, relógio, ações de clique, controles de zoom, visibilidade de elementos e mais. Compatível com temas e totalmente configurável.",

    ["MMSKIN_GROUP_SHAPE"] = "Forma e aparência",
    ["MMSKIN_GROUP_INFO"] = "Sobreposições de informação",
    ["MMSKIN_GROUP_ZOOM"] = "Zoom e rolagem",
    ["MMSKIN_GROUP_CLICKS"] = "Ações de clique",
    ["MMSKIN_GROUP_ELEMENTS"] = "Visibilidade de elementos",
    ["MMSKIN_GROUP_EXTRAS"] = "Extras",
    ["MMSKIN_GROUP_COMPAT"] = "Compatibilidade",

    ["MMSKIN_SQUARE"] = "Minimapa quadrado",
    ["MMSKIN_SQUARE_DESC"] = "Muda a forma do minimapa de redonda para quadrada. Desativar requer recarregar a interface.",
    ["MMSKIN_BORDER"] = "Mostrar borda",
    ["MMSKIN_BORDER_DESC"] = "Exibe uma borda colorida ao redor do minimapa.",
    ["MMSKIN_CLASS_BORDER"] = "Borda com cor de classe",
    ["MMSKIN_CLASS_BORDER_DESC"] = "Usa a cor da sua classe para a borda do minimapa em vez da cor do tema.",
    ["MMSKIN_UNLOCK"] = "Desbloquear minimapa",
    ["MMSKIN_UNLOCK_DESC"] = "Separa o minimapa da sua posição padrão e o torna livremente arrastável.",
    ["MMSKIN_LOCK_POS"] = "Travar posição",
    ["MMSKIN_LOCK_POS_DESC"] = "Impede que o minimapa seja arrastado, mantendo-o na posição atual.",

    ["MMSKIN_ZONE_TEXT"] = "Texto de zona",
    ["MMSKIN_ZONE_TEXT_DESC"] = "Mostra o nome da zona atual acima do minimapa com coloração do tipo JxJ.",
    ["MMSKIN_CLOCK"] = "Relógio",
    ["MMSKIN_CLOCK_DESC"] = "Mostra um relógio abaixo do minimapa. A dica exibe o horário do reino/local e os cronômetros de reinício diário/semanal.",
    ["MMSKIN_CLASS_CLOCK_COLOR"] = "Relógio com cor de classe",
    ["MMSKIN_CLASS_CLOCK_COLOR_DESC"] = "Usa a cor da sua classe para o texto do relógio em vez da cor do tema.",
    ["MMSKIN_ZONE_ALIGN_LABEL"] = "Alinhamento do nome da zona",
    ["MMSKIN_CLOCK_ALIGN_LABEL"] = "Alinhamento do relógio",
    ["MMSKIN_ALIGN_LEFT"] = "Esquerda",
    ["MMSKIN_ALIGN_CENTER"] = "Centro",
    ["MMSKIN_ALIGN_RIGHT"] = "Direita",

    ["MMSKIN_ZONE_CLOCK_INSIDE"] = "Zona e relógio dentro do minimapa",
    ["MMSKIN_ZONE_CLOCK_INSIDE_DESC"] = "Fixa o nome da zona e o relógio nas bordas internas do minimapa em vez de acima e abaixo dele.",

    ["MMSKIN_ZONE_CLOCK_DRAG"] = "Arrastar zona e relógio (segurar Shift)",
    ["MMSKIN_ZONE_CLOCK_DRAG_DESC"] = "Você deve segurar Shift enquanto arrasta o nome da zona ou o relógio para movê-los na tela. As posições são salvas. Solte Shift para cliques normais (o relógio ainda abre o gerenciador de tempo).",

    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM"] = "Fixar zona e relógio ao minimapa",
    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM_DESC"] = "Quando o arraste está ativado, fixa o nome da zona e o relógio ao minimapa para que acompanhem o movimento dele. Se você empilhá-los um sobre o outro, eles se movem como um só.",

    ["MMSKIN_WHEEL_ZOOM"] = "Zoom com a roda do mouse",
    ["MMSKIN_WHEEL_ZOOM_DESC"] = "Aproxima e afasta o minimapa usando a roda do mouse.",
    ["MMSKIN_AUTO_ZOOM"] = "Afastar automaticamente",
    ["MMSKIN_AUTO_ZOOM_DESC"] = "Afasta o minimapa automaticamente após aproximá-lo.",

    ["MMSKIN_CLICK_ACTIONS"] = "Ações de clique",
    ["MMSKIN_CLICK_ACTIONS_DESC"] = "Ativa ações de clique direito, clique do meio e botões extras do mouse no minimapa.",

    ["MMSKIN_MAIL"] = "Indicador de correio",
    ["MMSKIN_MAIL_DESC"] = "Mostra o indicador de correio no minimapa.",
    ["MMSKIN_CRAFTING"] = "Pedidos de criação",
    ["MMSKIN_CRAFTING_DESC"] = "Mostra o indicador de pedidos de criação no minimapa.",
    ["MMSKIN_DIFFICULTY"] = "Ícone de dificuldade",
    ["MMSKIN_DIFFICULTY_DESC"] = "Mostra o ícone de dificuldade da instância no minimapa.",

    ["MMSKIN_TRACKING"] = "Filtro de rastreamento",
    ["MMSKIN_TRACKING_DESC"] = "Mostra o filtro de rastreamento do minimapa (menu suspenso de recursos / ervas / minério / etc.). Desativá-lo remove o pequeno anel/controle ao lado do minimapa.",
    ["MMSKIN_MISSIONS"] = "Botão de missões",
    ["MMSKIN_MISSIONS_DESC"] = "Mostra o botão da página inicial da expansão / missões.",
    ["MMSKIN_GAMETIME"] = "Ícone do calendário",
    ["MMSKIN_GAMETIME_DESC"] = "Mostra o botão do calendário (GameTime) no minimapa.",

    ["MMSKIN_PLUMBER_HIDE_BLIZZARD"] = "Ocultar botão de expansão duplicado da Blizzard com o Plumber",
    ["MMSKIN_PLUMBER_HIDE_BLIZZARD_DESC"] = "Quando o Plumber está carregado, mantém o botão de expansão do minimapa da Blizzard oculto para que apenas o controle Resumo de Expansão do Plumber apareça. Desative para mostrar ambos (não recomendado).",
    ["MMSKIN_PLUMBER_STATUS_ON"] = "O Plumber está carregado — esta opção se aplica.",
    ["MMSKIN_PLUMBER_STATUS_OFF"] = "O Plumber não está carregado — ative isto antes de entrar, ou recarregue após instalar o Plumber.",

    ["MMSKIN_HIDE_ADDONS"] = "Ocultar ícones de addons",
    ["MMSKIN_HIDE_ADDONS_DESC"] = "Oculta os botões de addons do minimapa até você passar o cursor sobre a área do minimapa.",
    ["MMSKIN_COMBAT_FADE"] = "Esmaecer em combate",
    ["MMSKIN_COMBAT_FADE_DESC"] = "Reduz a opacidade do minimapa durante o combate.",
    ["MMSKIN_PET_HIDE"] = "Ocultar em batalhas de mascotes",
    ["MMSKIN_PET_HIDE_DESC"] = "Oculta o minimapa durante batalhas de mascotes.",

    ["MMSKIN_SCALE_LABEL"] = "Escala do conjunto do minimapa",
    ["MMSKIN_SECTION_BORDER"] = "Configurações de borda",
    ["MMSKIN_BORDER_SIZE"] = "Tamanho da borda",
    ["MMSKIN_BORDER_RED"] = "Vermelho",
    ["MMSKIN_BORDER_GREEN"] = "Verde",
    ["MMSKIN_BORDER_BLUE"] = "Azul",
    ["MMSKIN_USE_THEME_COLOR"] = "Usar cor do tema",

    ["MMSKIN_ZONE_BG"] = "Fundo da zona",
    ["MMSKIN_CLOCK_BG"] = "Fundo do relógio",

    ["MMSKIN_AUTO_ZOOM_DELAY"] = "Atraso do afastamento automático",
    ["MMSKIN_SHOW_ZOOM_BTNS"] = "Mostrar botões de zoom",

    ["MMSKIN_HIDE_WM_BTN"] = "Ocultar botão do mapa-múndi",
    ["MMSKIN_HIDE_WM_BTN_DESC"] = "Oculta o pequeno botão do mapa-múndi no minimapa (você ainda pode abrir o mapa com seu atalho).",

    ["MMSKIN_SECTION_COMBAT"] = "Configurações de esmaecimento em combate",
    ["MMSKIN_COMBAT_ALPHA"] = "Opacidade em combate",

    ["MMSKIN_SECTION_CLICKS"] = "Configurações de atribuição de cliques",
    ["MMSKIN_CLICK_RIGHT"] = "Clique direito",
    ["MMSKIN_CLICK_MIDDLE"] = "Clique do meio",
    ["MMSKIN_CLICK_BTN4"] = "Botão 4",
    ["MMSKIN_CLICK_BTN5"] = "Botão 5",
    ["MMSKIN_ACTION_NONE"] = "Nenhuma",
    ["MMSKIN_ACTION_CALENDAR"] = "Calendário",
    ["MMSKIN_ACTION_TRACKING"] = "Rastreamento",
    ["MMSKIN_ACTION_MISSIONS"] = "Missões",
    ["MMSKIN_ACTION_MAP"] = "Mapa",
    ["MMSKIN_WORLD_MAP_BUTTON"] = "Mapa-múndi",

    ["MMSKIN_SHOW_COMPARTMENT"] = "Compartimento de addons",

    ["MMSKIN_CLOCK_TT_TOGGLE"] = "Clique para abrir/fechar o gerenciador de tempo",

    ["MMSKIN_UNCLAMP"] = "Desafixar da borda da tela",

    ["MMSKIN_ZONE_FONT_LABEL"] = "Fonte",
    ["MMSKIN_CLOCK_FONT_LABEL"] = "Fonte",
    ["MMSKIN_FONT_GLOBAL"] = "Fonte global",
    ["MMSKIN_FONT_WOW_DEFAULT"] = "Padrão do WoW (pequena)",

    ["MMSKIN_SECTION_OPACITY"] = "Escala e opacidade",
    ["MMSKIN_OPACITY"] = "Opacidade do minimapa",

    ["MMSKIN_SECTION_DEBUG"] = "Ferramentas de desenvolvedor",
    ["MMSKIN_DEBUG_SHOW"] = "Mostrar ícones de depuração",
    ["MMSKIN_DEBUG_HIDE"] = "Ocultar ícones de depuração",
    ["MMSKIN_DEBUG_DESC"] = "Força a exibição de todos os ícones rastreados com etiquetas coloridas. Arraste qualquer etiqueta para colocar esse ícone no minimapa; as posições são salvas. Oculte a depuração para devolver os ícones ao conjunto (a menos que o minimapa esteja separado). Útil quando os ícones não são acionados naturalmente (ex.: sem correio na sua caixa).",
    ["MMSKIN_DEBUG_TT_DRAG_HINT"] = "Clique com o botão esquerdo e arraste para mover este ícone no minimapa.",
    ["MMSKIN_DEBUG_TT_POS_FMT"] = "Deslocamento salvo: %.0f, %.0f",

    ["MMSKIN_RELOAD_PROMPT"] = "Mudar a forma do minimapa requer recarregar a interface.\nRecarregar agora?",
})
