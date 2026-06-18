local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["MAPWORLD_TITLE"] = "Ferramentas de mapa (mundo)",
    ["MAPWORLD_DESC"] = "Mapa-múndi: revele o terreno inexplorado a partir dos dados do cliente, tonalidades opcionais, ajustes do mapa do campo de batalha, coordenadas e pequenas opções de conforto/limpeza.",

    ["MAPWORLD_GROUP_EXPLORE"] = "Exploração (arte do mapa)",
    ["MAPWORLD_GROUP_FOGOVERLAY"] = "Sobreposição de névoa (camada escura)",
    ["MAPWORLD_GROUP_FRAME"] = "Janela do mapa",
    ["MAPWORLD_GROUP_COMFORT"] = "Conforto",
    ["MAPWORLD_GROUP_CLEANUP"] = "Limpeza",
    ["MAPWORLD_GROUP_COORDS"] = "Coordenadas",
    ["MAPWORLD_GROUP_POI"] = "Pontos de interesse",
    ["MAPWORLD_GROUP_BATTLE"] = "Mapa do campo de batalha",
    ["MAPWORLD_GROUP_POLISH"] = "Acabamento",
    ["MAPWORLD_GROUP_CANVAS"] = "Sobreposição de mapa inteiro",
    ["MAPWORLD_GROUP_MAP"] = "Janela do mapa-múndi",

    ["MAPWORLD_REVEAL_MAP"] = "Mostrar áreas inexploradas",
    ["MAPWORLD_REVEAL_MAP_DESC"] = "Desenha os ladrilhos de exploração ausentes usando os dados de arte de mapa incluídos (a mesma ideia de revelar o mapa de papel). Funciona nos mapas do mundo e do campo de batalha.",

    ["MAPWORLD_TINT_UNEXPLORED"] = "Tingir áreas inexploradas",
    ["MAPWORLD_TINT_UNEXPLORED_DESC"] = "Aplica uma tonalidade de cor aos ladrilhos revelados pela opção acima (apenas mapas de zona).",

    ["MAPWORLD_UNEX_R"] = "Inexplorado vermelho",
    ["MAPWORLD_UNEX_G"] = "Inexplorado verde",
    ["MAPWORLD_UNEX_B"] = "Inexplorado azul",
    ["MAPWORLD_UNEX_A"] = "Opacidade inexplorado",

    ["MAPWORLD_REMOVE_FOG"] = "Ocultar camada de névoa escura",
    ["MAPWORLD_REMOVE_FOG_DESC"] = "Oculta o quadro de névoa de guerra da Blizzard sobre o mapa (separado de desenhar a arte de exploração ausente).",

    ["MAPWORLD_FOG_TINT"] = "Tingir camada de névoa (NdG)",
    ["MAPWORLD_FOG_TINT_DESC"] = "Quando a camada de névoa escura está visível, multiplica sua cor.",

    ["MAPWORLD_CLEAR_BLACKOUT"] = "Mundo clicável atrás do mapa",
    ["MAPWORLD_CLEAR_BLACKOUT_DESC"] = "Torna o «escurecimento» atenuado atrás do mapa transparente e sem bloquear cliques, para que você veja o mundo com clareza.",

    ["MAPWORLD_NO_MAP_FADE"] = "Desativar esmaecimento do mapa ao mover",
    ["MAPWORLD_NO_MAP_FADE_DESC"] = "Define mapFade para que o mapa não fique semitransparente quando seu personagem se move.",

    ["MAPWORLD_NO_MAP_EMOTE"] = "Desativar emote de leitura",
    ["MAPWORLD_NO_MAP_EMOTE_DESC"] = "Cancela o emote de leitura ao abrir o mapa.",

    ["MAPWORLD_HIDE_FILTER_RESET"] = "Ocultar IU de redefinição de filtros",
    ["MAPWORLD_HIDE_FILTER_RESET_DESC"] = "Oculta o controle de redefinição de filtros do mapa-múndi e os banners de contador relacionados.",

    ["MAPWORLD_HIDE_MAP_TUTORIAL"] = "Suprimir tutorial do mapa",
    ["MAPWORLD_HIDE_MAP_TUTORIAL_DESC"] = "Oculta o quadro de tutorial do mapa-múndi e o marca como fechado nos quadros de informação.",

    ["MAPWORLD_SHOW_COORDS"] = "Mostrar coordenadas",
    ["MAPWORLD_SHOW_COORDS_DESC"] = "Mostra a posição do cursor e do jogador na janela do mapa.",

    ["MAPWORLD_COORDS_LARGE"] = "Fonte de coordenadas grande",
    ["MAPWORLD_COORDS_LARGE_DESC"] = "Usa uma fonte maior para a leitura de coordenadas.",

    ["MAPWORLD_COORDS_BG"] = "Fundo da barra de coordenadas",
    ["MAPWORLD_COORDS_BG_DESC"] = "Mostra uma faixa escura atrás do texto de coordenadas.",

    ["MAPWORLD_HIDE_CONTINENT_POI"] = "Ocultar pontos de interesse de cidade nos continentes",
    ["MAPWORLD_HIDE_CONTINENT_POI_DESC"] = "Oculta determinados marcadores de lar, facção e cidade nas vistas de continente e mapa-múndi.",

    ["MAPWORLD_ENHANCE_BATTLE_MAP"] = "Aprimorar mapa do campo de batalha",
    ["MAPWORLD_ENHANCE_BATTLE_MAP_DESC"] = "Mostra o grupo no mapa do campo de batalha e ativa as opções abaixo.",

    ["MAPWORLD_UNLOCK_BATTLEFIELD"] = "Arraste para mover o mapa do campo de batalha",
    ["MAPWORLD_UNLOCK_BATTLEFIELD_DESC"] = "Arraste o mapa do campo de batalha pela sua área interna.",

    ["MAPWORLD_BATTLE_CENTER"] = "Manter o mapa do campo de batalha centrado no jogador",
    ["MAPWORLD_BATTLE_CENTER_DESC"] = "Recentraliza o mapa do campo de batalha na sua posição. Segure Shift ao arrastar para pausar.",

    ["MAPWORLD_BATTLE_OPACITY"] = "Visibilidade do mapa do campo de batalha",
    ["MAPWORLD_BATTLE_GROUP"] = "Tamanho dos ícones de grupo",
    ["MAPWORLD_BATTLE_PLAYER"] = "Tamanho da seta do jogador",

    ["MAPWORLD_TINT_MENU"] = "Alternância de tonalidade do menu do mapa-múndi",
    ["MAPWORLD_TINT_MENU_DESC"] = "Adiciona uma caixa «Tingir inexploradas» ao menu de rastreamento do mapa (pode não carregar se a API do menu mudar).",

    ["MAPWORLD_CANVAS_TINT"] = "Sobreposição de cor de mapa inteiro",
    ["MAPWORLD_CANVAS_TINT_DESC"] = "Tinge toda a tela do mapa com uma cor translúcida (separado da tonalidade de exploração).",

    ["MAPWORLD_MAP_ALPHA"] = "Opacidade do mapa-múndi",
    ["MAPWORLD_MAP_ALPHA_DESC"] = "Reduz a opacidade de toda a janela do mapa-múndi (alfa do quadro).",

    ["MAPWORLD_MAP_ALPHA_SLIDER"] = "Opacidade da janela do mapa",
    ["MAPWORLD_RED"] = "Vermelho",
    ["MAPWORLD_GREEN"] = "Verde",
    ["MAPWORLD_BLUE"] = "Azul",

    ["MAPWORLD_CURSOR"] = "Cursor",
})
