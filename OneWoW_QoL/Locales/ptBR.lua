local ADDON_NAME = ...

-- Machine-drafted (Phase 4) — pending native review
OneWoW.Locale:Register(ADDON_NAME, "ptBR", {

    ["ADDON_TITLE"] = "OneWoW - QoL",
    ["ADDON_TITLE_SHORT"] = "QoL",
    ["ADDON_TITLE_FRAME"] = "OneWoW - QoL",
    ["ADDON_LOADED"] = "carregado.",

    ["TAB_FEATURES"] = "Funcionalidades QoL",
    ["TAB_TOGGLES"] = "Interruptores",

    ["FEATURES_LIST_TITLE"] = "Funcionalidades",
    ["FEATURES_FAVORITE_TT_TITLE"] = "Favorito",
    ["FEATURES_FAVORITE_TT_DESC"] = "Fixa esta funcionalidade na seção Favoritos no topo. Clique novamente para removê-la dos Favoritos.",
    ["FEATURES_DETAIL_TITLE"] = "Detalhes",
    ["FEATURES_EMPTY"] = "Nenhum módulo carregado.",
    ["FEATURES_NO_SELECTION"] = "Selecione uma funcionalidade na lista.",
    ["FEATURES_ENABLED"] = "Ativado",
    ["FEATURES_DISABLED"] = "Desativado",
    ["FEATURES_CATEGORY_LABEL"] = "Categoria:",
    ["FEATURES_VERSION_LABEL"] = "Versão:",
    ["FEATURES_AUTHOR_LABEL"] = "Autor:",
    ["FEATURES_CONTACT_LABEL"] = "Contato:",
    ["FEATURES_LINK_LABEL"] = "Link:",
    ["FEATURES_DETAILS_BTN"] = "Detalhes",
    ["FEATURES_DETAILS_TITLE"] = "Detalhes do módulo",
    ["FEATURES_TOGGLES_HEADER"] = "Interruptores do módulo",
    ["FEATURES_ON"] = "Sim",
    ["FEATURES_OFF"] = "Não",
    ["FEATURES_PREVIEW_LABEL"] = "Pré-visualização:",

    ["CATEGORY_AUTOMATION"] = "Automação",
    ["CATEGORY_INTERFACE"] = "Interface",
    ["CATEGORY_SOCIAL"] = "Social",
    ["CATEGORY_COMBAT"] = "Combate",
    ["CATEGORY_ECONOMY"] = "Economia",
    ["CATEGORY_UTILITY"] = "Utilidade",

    ["TOGGLES_LIST_TITLE"] = "Indicadores do jogo",
    ["TOGGLES_FAVORITE_TT_TITLE"] = "Favorito",
    ["TOGGLES_FAVORITE_TT_DESC"] = "Fixa este interruptor na seção Favoritos no topo. Clique novamente para removê-lo dos Favoritos.",
    ["TOGGLES_DETAIL_TITLE"] = "Detalhes do indicador",
    ["TOGGLES_COMING_SOON"] = "Os indicadores do jogo serão adicionados em uma atualização futura.",
    ["TOGGLES_NO_SELECTION"] = "Selecione um indicador na lista.",

    ["SETTINGS_THEME_HEADER"] = "Tema de cores",
    ["SETTINGS_THEME_DESC"] = "Escolha um tema de cores. As alterações se aplicam instantaneamente.",
    ["SETTINGS_LANGUAGE_DESC"] = "Escolha seu idioma preferido. As alterações se aplicam instantaneamente.",
    ["SETTINGS_DEVELOPER_HEADER"] = "Informações para desenvolvedores",
    ["SETTINGS_DEVELOPER_DESC"] = "Este addon oferece suporte a módulos externos. Adicione funcionalidades QoL criando uma pasta de módulo em Modules\\external\\. Use o botão Ajuda ao desenvolvedor para a documentação completa.",
    ["SETTINGS_DEV_HELP_BTN"] = "Ajuda ao desenvolvedor",

    ["DEVHELP_TITLE"] = "Guia do desenvolvedor de módulos",
    ["DEVHELP_BODY"] = [[SISTEMA DE MÓDULOS PLUG-IN

Crie sua pasta:
  Modules\external\yourmodule\

Arquivos (module.lua carrega PRIMEIRO):
  module.lua      - Metadados + registro
  yourmodule.lua  - Lógica do módulo
  Locales\enUS.lua  (koKR.lua opcional)

Em module.lua, defina seu módulo
(o id existe SOMENTE aqui):
  local ADDON_NAME, ns = ...
  ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "yourmodule",
    title       = "MY_TITLE",
    category    = "AUTOMATION",
    description = "MY_DESC",
    version     = "1.0",
    author      = "Seu nome",
    contact     = "seu@email.com",
    link        = "https://seusite.com",
    toggles = {
      { id = "myToggle", label = "MY_TOGGLE_LABEL",
        description = "MY_TOGGLE_DESC", default = true },
    },
    defaultEnabled = true,
  })

Em yourmodule.lua, obtenha-o + sua
visão de locale (capture ao carregar, nunca em execução):
  local _, ns = ...
  local M, L = ns.ModuleRegistry:Current()
  if not M then return end

  function M:OnEnable() end
  function M:OnDisable() end
  function M:OnToggle(id, val) end

Em Locales\enUS.lua:
  local _, ns = ...
  local M = ns.ModuleRegistry:Current()
  OneWoW.Locale:Register(M._scope, "enUS", {
    ["MY_TITLE"] = "My Title",
    ["MY_DESC"]  = "What it does",
  })

O scope é ADDON_NAME .. "." .. id, p. ex.
OneWoW_QoL.yourmodule (derivado, sem
string de scope codificada manualmente).

Referencie outro módulo pelo id:
  ns.ModuleRegistry:GetById("othermodule")
Nunca use ns.<X>Module.

Os valores title, description, bem como o
rótulo e a descrição dos interruptores são
chaves de locale. author, contact e link são
opcionais. contact e link aparecem como
caixas copiáveis na janela Detalhes do módulo.

Categorias disponíveis:
  AUTOMATION  INTERFACE  SOCIAL
  COMBAT      ECONOMY    UTILITY

Adicione seus arquivos ao TOC sob EXTERNAL
MODULES. Ordem: module.lua PRIMEIRO, depois
os Locales, depois seus arquivos de código.

Espaço do banco de dados SavedVariables:
  OneWoW_QoL_DB.modules.yourmodule

Consulte Modules\external\autodelete\ para um
exemplo completo e funcional.]],

    ["MINIMAP_TOOLTIP_TITLE"] = "OneWoW - QoL",
    ["MINIMAP_TOOLTIP_HINT"] = "Clique para abrir",
    ["MINIMAP_RIGHT_CLICK"] = "Clique direito para opções",
    ["MINIMAP_OPEN"] = "Abrir QoL",

    ["LANG_ENGLISH"] = "Inglês",
    ["LANG_KOREAN"] = "Coreano",


    ["SEARCH_HINT"] = "Filtrar...",
    ["TOGGLES_STATUS_ALL"] = "Mostrando %d CVars",
    ["TOGGLES_STATUS_FILTERED"] = "Mostrando %d de %d",
    ["FEATURES_STATUS_ENABLED"] = "%d de %d ativados",

    ["TOGGLES_CVAR_LABEL"] = "CVar:",
    ["TOGGLES_ON"] = "Sim",
    ["TOGGLES_OFF"] = "Não",
    ["TOGGLES_VALUE_LABEL"] = "Valor:",

    ["TOGGLE_CAT_GAMEPLAY"] = "Jogabilidade",
    ["TOGGLE_CAT_INTERFACE"] = "Interface",
    ["TOGGLE_CAT_NAMEPLATES"] = "Placas de identificação",
    ["TOGGLE_CAT_COMBAT_TEXT"] = "Texto de combate",
    ["TOGGLE_CAT_CAMERA"] = "Câmera",
    ["TOGGLE_CAT_CHAT"] = "Bate-papo e social",
    ["TOGGLE_CAT_AUDIO"] = "Áudio",
    ["TOGGLE_CAT_GRAPHICS"] = "Gráficos",
    ["TOGGLE_CAT_NETWORK"] = "Rede",

    ["TOGGLE_NAME_autoLootDefault"] = "Saque automático",
    ["TOGGLE_NAME_autoSelfCast"] = "Conjuração automática em si mesmo",
    ["TOGGLE_NAME_autoDismount"] = "Desmontar automaticamente",
    ["TOGGLE_NAME_autoDismountFlying"] = "Desmontar em voo",
    ["TOGGLE_NAME_autoStand"] = "Levantar automaticamente",
    ["TOGGLE_NAME_autoUnshift"] = "Sair da forma automaticamente",
    ["TOGGLE_NAME_assistAttack"] = "Ataque assistido",
    ["TOGGLE_NAME_ActionButtonUseKeyDown"] = "Botões de ação ao pressionar",
    ["TOGGLE_NAME_deselectOnClick"] = "Desmarcar alvo ao clicar",
    ["TOGGLE_NAME_stopAutoAttackOnTargetChange"] = "Parar ataque automático ao trocar de alvo",
    ["TOGGLE_NAME_lootUnderMouse"] = "Janela de saque sob o mouse",
    ["TOGGLE_NAME_lootLeftmostBag"] = "Saquear na bolsa mais à esquerda",
    ["TOGGLE_NAME_interactOnLeftClick"] = "Interagir com clique esquerdo",
    ["TOGGLE_NAME_autointeract"] = "Interação automática",
    ["TOGGLE_NAME_autoClearAFK"] = "Remover ausência automaticamente",

    ["TOGGLE_NAME_countdownForCooldowns"] = "Contagem regressiva de recargas",
    ["TOGGLE_NAME_displaySpellActivationOverlays"] = "Brilho de proc de magia",
    ["TOGGLE_NAME_alwaysShowActionBars"] = "Sempre mostrar barras de ação",
    ["TOGGLE_NAME_lockActionBars"] = "Travar barras de ação",
    ["TOGGLE_NAME_bottomLeftActionBar"] = "Barra de ação inferior esquerda",
    ["TOGGLE_NAME_bottomRightActionBar"] = "Barra de ação inferior direita",
    ["TOGGLE_NAME_rightActionBar"] = "Barra de ação direita",
    ["TOGGLE_NAME_rightTwoActionBar"] = "Barra de ação direita 2",
    ["TOGGLE_NAME_displayFreeBagSlots"] = "Mostrar espaços livres na bolsa",
    ["TOGGLE_NAME_buffDurations"] = "Mostrar duração dos benefícios",
    ["TOGGLE_NAME_showTargetOfTarget"] = "Mostrar alvo do alvo",
    ["TOGGLE_NAME_showTargetCastbar"] = "Mostrar barra de conjuração do alvo",
    ["TOGGLE_NAME_fullSizeFocusFrame"] = "Quadro de foco em tamanho completo",
    ["TOGGLE_NAME_breakUpLargeNumbers"] = "Formatar números grandes",
    ["TOGGLE_NAME_alwaysCompareItems"] = "Sempre comparar itens",
    ["TOGGLE_NAME_missingTransmogSourceInItemTooltips"] = "Fonte de transmogrificação ausente",
    ["TOGGLE_NAME_autoQuestWatch"] = "Rastrear missões automaticamente",
    ["TOGGLE_NAME_autoQuestProgress"] = "Avisos de progresso de missão",
    ["TOGGLE_NAME_mapFade"] = "O mapa se esmaece ao mover",
    ["TOGGLE_NAME_rotateMinimap"] = "Girar o minimapa",
    ["TOGGLE_NAME_useUiScale"] = "Ativar escala de interface personalizada",
    ["TOGGLE_NAME_uiScale"] = "Escala da interface",

    ["TOGGLE_NAME_nameplateShowEnemies"] = "Mostrar placas inimigas",
    ["TOGGLE_NAME_nameplateShowFriends"] = "Mostrar placas aliadas",
    ["TOGGLE_NAME_nameplateShowSelf"] = "Mostrar placa pessoal",
    ["TOGGLE_NAME_nameplatePersonalShowAlways"] = "Placa pessoal sempre visível",
    ["TOGGLE_NAME_nameplatePersonalShowInCombat"] = "Placa pessoal em combate",
    ["TOGGLE_NAME_ShowClassColorInNameplate"] = "Cores de classe nas placas inimigas",
    ["TOGGLE_NAME_ShowClassColorInFriendlyNameplate"] = "Cores de classe nas placas aliadas",
    ["TOGGLE_NAME_ShowNamePlateLoseAggroFlash"] = "Piscar ao perder a ameaça",
    ["TOGGLE_NAME_namePlateEnemyClickThrough"] = "Placas inimigas não clicáveis",
    ["TOGGLE_NAME_namePlateFriendlyClickThrough"] = "Placas aliadas não clicáveis",
    ["TOGGLE_NAME_nameplateMaxDistance"] = "Distância de exibição das placas",
    ["TOGGLE_NAME_nameplateGlobalScale"] = "Escala global das placas",
    ["TOGGLE_NAME_namePlateEnemySize"] = "Tamanho das placas inimigas",
    ["TOGGLE_NAME_namePlateFriendlySize"] = "Tamanho das placas aliadas",

    ["TOGGLE_NAME_enableFloatingCombatText"] = "Texto de combate flutuante",
    ["TOGGLE_NAME_enableCombatText"] = "Texto de combate padrão",
    ["TOGGLE_NAME_fctCombatState"] = "Texto de estado de combate",
    ["TOGGLE_NAME_floatingCombatTextCombatDamage"] = "Números de dano",
    ["TOGGLE_NAME_floatingCombatTextCombatHealing"] = "Números de cura",
    ["TOGGLE_NAME_floatingCombatTextCombatState"] = "Texto de entrada/saída de combate",
    ["TOGGLE_NAME_floatingCombatTextAuras"] = "Texto de mudança de benefício/prejuízo",
    ["TOGGLE_NAME_floatingCombatTextDodgeParryMiss"] = "Texto de esquiva/aparada/erro",
    ["TOGGLE_NAME_floatingCombatTextHonorGains"] = "Ganhos de honra",
    ["TOGGLE_NAME_floatingCombatTextRepChanges"] = "Mudanças de reputação",
    ["TOGGLE_NAME_floatingCombatTextEnergyGains"] = "Ganhos de energia/mana",
    ["TOGGLE_NAME_floatingCombatTextComboPoints"] = "Ganhos de pontos de combo",
    ["TOGGLE_NAME_floatingCombatTextReactives"] = "Procs reativos",
    ["TOGGLE_NAME_floatingCombatTextPetMeleeDamage"] = "Dano corpo a corpo do mascote",

    ["TOGGLE_NAME_cameraBobbing"] = "Balanço da câmera",
    ["TOGGLE_NAME_cameraWaterCollision"] = "Colisão da câmera com a água",
    ["TOGGLE_NAME_flightAngleLookAhead"] = "Antecipação do ângulo de voo",
    ["TOGGLE_NAME_cameraDynamicPitch"] = "Inclinação dinâmica da câmera",
    ["TOGGLE_NAME_cameraDistanceMaxZoomFactor"] = "Distância máxima de afastamento da câmera",
    ["TOGGLE_NAME_cameraYawMoveSpeed"] = "Velocidade de giro horizontal da câmera",
    ["TOGGLE_NAME_cameraPitchMoveSpeed"] = "Velocidade de inclinação vertical da câmera",
    ["TOGGLE_NAME_cameraZoomSpeed"] = "Velocidade de zoom da câmera",

    ["TOGGLE_NAME_chatBubbles"] = "Balões de fala (/dizer)",
    ["TOGGLE_NAME_chatBubblesParty"] = "Balões de fala (Grupo)",
    ["TOGGLE_NAME_colorChatNamesByClass"] = "Cores de classe no bate-papo",
    ["TOGGLE_NAME_blockTrades"] = "Bloquear pedidos de troca",
    ["TOGGLE_NAME_blockChannelInvites"] = "Bloquear convites de canais",
    ["TOGGLE_NAME_guildMemberNotify"] = "Avisos de login da guilda",
    ["TOGGLE_NAME_removeChatDelay"] = "Remover atraso do bate-papo",
    ["TOGGLE_NAME_chatMouseScroll"] = "Rolar o bate-papo com a roda do mouse",
    ["TOGGLE_NAME_profanityFilter"] = "Filtro de palavrões",
    ["TOGGLE_NAME_chatStyle"] = "Estilo do bate-papo",

    ["TOGGLE_NAME_Sound_EnableAllSound"] = "Todo o som",
    ["TOGGLE_NAME_Sound_EnableMusic"] = "Música",
    ["TOGGLE_NAME_Sound_EnableSFX"] = "Efeitos sonoros",
    ["TOGGLE_NAME_Sound_EnableDialog"] = "Diálogo / Voz",
    ["TOGGLE_NAME_Sound_EnableAmbience"] = "Ambiente",
    ["TOGGLE_NAME_Sound_EnablePetSounds"] = "Sons do mascote",
    ["TOGGLE_NAME_FootstepSounds"] = "Sons de passos",
    ["TOGGLE_NAME_Sound_MasterVolume"] = "Volume principal",
    ["TOGGLE_NAME_Sound_MusicVolume"] = "Volume da música",
    ["TOGGLE_NAME_Sound_SFXVolume"] = "Volume dos efeitos",

    ["TOGGLE_NAME_ffxDeath"] = "Efeito de tela de morte",
    ["TOGGLE_NAME_ffxGlow"] = "Efeito de brilho / bloom",
    ["TOGGLE_NAME_ffxNether"] = "Efeito visual do Caos",
    ["TOGGLE_NAME_emphasizeMySpellEffects"] = "Enfatizar meus efeitos de magia",
    ["TOGGLE_NAME_doNotFlashLowHealthWarning"] = "Desativar o piscar de vida baixa",
    ["TOGGLE_NAME_hdPlayerModels"] = "Modelos de jogador em HD",
    ["TOGGLE_NAME_findYourselfAnywhere"] = "Destaque do personagem",
    ["TOGGLE_NAME_gxVSync"] = "VSync",
    ["TOGGLE_NAME_gxTripleBuffer"] = "Buffer triplo",
    ["TOGGLE_NAME_particleDensity"] = "Densidade de partículas",
    ["TOGGLE_NAME_maxFPS"] = "FPS máx. (primeiro plano)",
    ["TOGGLE_NAME_maxFPSBk"] = "FPS máx. (segundo plano)",
    ["TOGGLE_NAME_gxMaxFrameLatency"] = "Latência máxima de quadros",
    ["TOGGLE_NAME_RenderScale"] = "Escala de renderização",
    ["TOGGLE_NAME_graphicsQuality"] = "Predefinição de qualidade gráfica",
    ["TOGGLE_NAME_ffxAntiAliasingMode"] = "Modo de suavização de serrilhado",
    ["TOGGLE_NAME_colorblindMode"] = "Modo para daltônicos",

    ["TOGGLE_NAME_disableServerNagle"] = "Desativar algoritmo de Nagle",
    ["TOGGLE_NAME_gxFixLag"] = "Corrigir atraso de entrada",
    ["TOGGLE_NAME_reducedLagTolerance"] = "Tolerância de atraso reduzida",
    ["TOGGLE_NAME_SpellQueueWindow"] = "Janela de fila de magias",

    ["TOGGLE_DESC_autoLootDefault"] = "Recolhe automaticamente todo o saque sem clicar em cada item.",
    ["TOGGLE_DESC_autoSelfCast"] = "Conjura magias benéficas em si mesmo quando você não tem nenhum alvo selecionado.",
    ["TOGGLE_DESC_autoDismount"] = "Faz você desmontar automaticamente quando tenta coletar, falar com PNJs ou entrar em combate.",
    ["TOGGLE_DESC_autoDismountFlying"] = "Faz você desmontar automaticamente mesmo em voo. Atenção: você vai cair!",
    ["TOGGLE_DESC_autoStand"] = "Faz você se levantar automaticamente quando tenta se mover ou agir estando sentado.",
    ["TOGGLE_DESC_autoUnshift"] = "Sai automaticamente das formas quando você usa uma habilidade que exige isso.",
    ["TOGGLE_DESC_assistAttack"] = "Ao assistir um alvo aliado, ataca automaticamente o alvo dele.",
    ["TOGGLE_DESC_ActionButtonUseKeyDown"] = "Ativado: as magias disparam na hora ao pressionar a tecla. Desativado: as magias disparam ao soltar, permitindo ver primeiro o alcance.",
    ["TOGGLE_DESC_deselectOnClick"] = "Limpa seu alvo quando você clica no chão vazio.",
    ["TOGGLE_DESC_stopAutoAttackOnTargetChange"] = "Para o ataque automático quando você muda para um novo alvo.",
    ["TOGGLE_DESC_lootUnderMouse"] = "Abre a janela de saque onde estiver o cursor do mouse em vez de em uma posição fixa.",
    ["TOGGLE_DESC_lootLeftmostBag"] = "Coloca os itens saqueados na bolsa mais à esquerda em vez da mais à direita.",
    ["TOGGLE_DESC_interactOnLeftClick"] = "Clique esquerdo em PNJs e objetos para interagir em vez do clique direito.",
    ["TOGGLE_DESC_autointeract"] = "Clicar com o direito em um PNJ fala com ele ou o saqueia automaticamente.",
    ["TOGGLE_DESC_autoClearAFK"] = "Remove automaticamente seu status de ausente quando você se move ou realiza qualquer ação.",

    ["TOGGLE_DESC_countdownForCooldowns"] = "Mostra números de contagem regressiva no centro dos ícones de habilidade durante a recarga.",
    ["TOGGLE_DESC_displaySpellActivationOverlays"] = "Mostra bordas brilhantes nas habilidades quando procs são ativados, como procs de conjuração instantânea.",
    ["TOGGLE_DESC_alwaysShowActionBars"] = "Mantém as barras de ação visíveis mesmo vazias, impedindo que se ocultem.",
    ["TOGGLE_DESC_lockActionBars"] = "Impede arrastar habilidades para fora das barras de ação por acidente.",
    ["TOGGLE_DESC_bottomLeftActionBar"] = "Mostra a barra de ação extra acima da sua barra principal, no lado esquerdo.",
    ["TOGGLE_DESC_bottomRightActionBar"] = "Mostra a barra de ação extra acima da sua barra principal, no lado direito.",
    ["TOGGLE_DESC_rightActionBar"] = "Mostra a barra de ação vertical no lado direito da tela.",
    ["TOGGLE_DESC_rightTwoActionBar"] = "Mostra uma segunda barra de ação vertical no lado direito da tela.",
    ["TOGGLE_DESC_displayFreeBagSlots"] = "Mostra o número de espaços vazios na sua barra de bolsas.",
    ["TOGGLE_DESC_buffDurations"] = "Mostra o tempo restante dos seus benefícios como números de contagem regressiva.",
    ["TOGGLE_DESC_showTargetOfTarget"] = "Mostra quem o seu alvo está mirando. Útil para tanques e curandeiros.",
    ["TOGGLE_DESC_showTargetCastbar"] = "Mostra uma barra de conjuração para o seu alvo atual para que você veja o que ele está conjurando.",
    ["TOGGLE_DESC_fullSizeFocusFrame"] = "Usa um quadro de unidade em tamanho completo para o seu foco em vez do quadro pequeno.",
    ["TOGGLE_DESC_breakUpLargeNumbers"] = "Exibe números grandes com separadores, como 1.000.000 em vez de 1000000.",
    ["TOGGLE_DESC_alwaysCompareItems"] = "Mostra automaticamente a dica de comparação ao passar sobre o equipamento. Sem precisar da tecla Shift.",
    ["TOGGLE_DESC_missingTransmogSourceInItemTooltips"] = "Indica nas dicas de item se você possui esta aparência, mas não desta fonte de item específica.",
    ["TOGGLE_DESC_autoQuestWatch"] = "Adiciona automaticamente novas missões ao seu rastreador de missões no lado direito da tela.",
    ["TOGGLE_DESC_autoQuestProgress"] = "Mostra notificações pop-up quando você progride nas missões.",
    ["TOGGLE_DESC_mapFade"] = "Deixa o mapa transparente quando você se move para que ainda veja o mundo do jogo.",
    ["TOGGLE_DESC_rotateMinimap"] = "O minimapa gira conforme você vira, como uma bússola, em vez de ficar fixo com o norte para cima.",
    ["TOGGLE_DESC_useUiScale"] = "Permite personalizar a escala da interface. Ative isto para usar o controle deslizante de escala.",
    ["TOGGLE_DESC_uiScale"] = "Tamanho geral da interface. Requer que a escala de interface personalizada esteja ativada.",

    ["TOGGLE_DESC_nameplateShowEnemies"] = "Exibe placas de identificação com barra de vida acima das unidades inimigas.",
    ["TOGGLE_DESC_nameplateShowFriends"] = "Exibe placas de identificação com barra de vida acima das unidades aliadas.",
    ["TOGGLE_DESC_nameplateShowSelf"] = "Mostra sua barra de recurso pessoal como uma placa acima do seu personagem.",
    ["TOGGLE_DESC_nameplatePersonalShowAlways"] = "Sempre mostra sua placa de recurso pessoal, mesmo fora de combate.",
    ["TOGGLE_DESC_nameplatePersonalShowInCombat"] = "Mostra sua placa de recurso pessoal apenas durante o combate.",
    ["TOGGLE_DESC_ShowClassColorInNameplate"] = "Colore as placas inimigas por classe no JxJ.",
    ["TOGGLE_DESC_ShowClassColorInFriendlyNameplate"] = "Colore as placas aliadas por classe.",
    ["TOGGLE_DESC_ShowNamePlateLoseAggroFlash"] = "Faz uma placa piscar quando você perde a ameaça sobre um inimigo como tanque.",
    ["TOGGLE_DESC_namePlateEnemyClickThrough"] = "Permite clicar através das placas inimigas. Você vê as barras de vida, mas não pode clicar para mirar.",
    ["TOGGLE_DESC_namePlateFriendlyClickThrough"] = "Permite clicar através das placas aliadas. Você vê as barras de vida, mas não pode clicar para mirar aliados.",
    ["TOGGLE_DESC_nameplateMaxDistance"] = "Distância máxima em metros na qual as placas ficam visíveis. O máximo é 60 em instâncias.",
    ["TOGGLE_DESC_nameplateGlobalScale"] = "Multiplicador de tamanho principal para todas as placas. Afeta tudo após os outros ajustes de escala.",
    ["TOGGLE_DESC_namePlateEnemySize"] = "Multiplicador de tamanho das placas inimigas. Maior as torna mais fáceis de ver em combate.",
    ["TOGGLE_DESC_namePlateFriendlySize"] = "Multiplicador de tamanho das placas de jogadores aliados.",

    ["TOGGLE_DESC_enableFloatingCombatText"] = "Mostra números flutuantes de dano e cura que sobem dos inimigos e aliados.",
    ["TOGGLE_DESC_enableCombatText"] = "Mostra números de dano e cura na área de texto de combate padrão, perto do seu personagem.",
    ["TOGGLE_DESC_fctCombatState"] = "Mostra avisos de texto flutuante como «Você está em combate!» usando o sistema de texto de combate padrão.",
    ["TOGGLE_DESC_floatingCombatTextCombatDamage"] = "Mostra o dano que você causa como números flutuantes.",
    ["TOGGLE_DESC_floatingCombatTextCombatHealing"] = "Mostra a cura que você recebe como números verdes flutuantes.",
    ["TOGGLE_DESC_floatingCombatTextCombatState"] = "Mostra a entrada e saída de combate como mensagens de texto flutuante.",
    ["TOGGLE_DESC_floatingCombatTextAuras"] = "Mostra como texto flutuante quando você ganha ou perde benefícios e prejuízos.",
    ["TOGGLE_DESC_floatingCombatTextDodgeParryMiss"] = "Mostra os resultados de Esquiva, Aparada e Erro como texto flutuante.",
    ["TOGGLE_DESC_floatingCombatTextHonorGains"] = "Mostra os ganhos de pontos de honra como texto flutuante no JxJ.",
    ["TOGGLE_DESC_floatingCombatTextRepChanges"] = "Mostra os ganhos e perdas de reputação como texto flutuante.",
    ["TOGGLE_DESC_floatingCombatTextEnergyGains"] = "Mostra os ganhos de energia, fúria e mana como texto flutuante.",
    ["TOGGLE_DESC_floatingCombatTextComboPoints"] = "Mostra os ganhos de pontos de combo como texto flutuante.",
    ["TOGGLE_DESC_floatingCombatTextReactives"] = "Mostra os procs de habilidades reativas como texto flutuante.",
    ["TOGGLE_DESC_floatingCombatTextPetMeleeDamage"] = "Mostra o dano corpo a corpo do seu mascote como números flutuantes.",

    ["TOGGLE_DESC_cameraBobbing"] = "A câmera balança suavemente para cima e para baixo ao andar e correr. Mais imersivo, mas pode causar enjoo.",
    ["TOGGLE_DESC_cameraWaterCollision"] = "Impede que a câmera vá para debaixo d'água quando seu personagem está acima da superfície.",
    ["TOGGLE_DESC_flightAngleLookAhead"] = "Sua montaria voadora se inclina para mostrar a direção que você segue, para uma sensação mais realista.",
    ["TOGGLE_DESC_cameraDynamicPitch"] = "A câmera se inclina automaticamente conforme sua direção de movimento. É o recurso Action Cam.",
    ["TOGGLE_DESC_cameraDistanceMaxZoomFactor"] = "Multiplicador da distância máxima de afastamento da câmera. Valores maiores permitem afastar mais.",
    ["TOGGLE_DESC_cameraYawMoveSpeed"] = "A rapidez com que a câmera gira para a esquerda e a direita.",
    ["TOGGLE_DESC_cameraPitchMoveSpeed"] = "A rapidez com que a câmera se inclina para cima e para baixo.",
    ["TOGGLE_DESC_cameraZoomSpeed"] = "A rapidez com que a câmera aproxima e afasta com a roda do mouse.",

    ["TOGGLE_DESC_chatBubbles"] = "Mostra balões de fala acima das cabeças dos personagens quando usam /dizer ou /gritar.",
    ["TOGGLE_DESC_chatBubblesParty"] = "Mostra balões de fala das mensagens de grupo e raide acima das cabeças dos personagens.",
    ["TOGGLE_DESC_colorChatNamesByClass"] = "Colore os nomes dos jogadores no bate-papo conforme a classe.",
    ["TOGGLE_DESC_blockTrades"] = "Impede que outros jogadores abram janelas de troca com você.",
    ["TOGGLE_DESC_blockChannelInvites"] = "Impede que outros jogadores convidem você para canais de bate-papo.",
    ["TOGGLE_DESC_guildMemberNotify"] = "Mostra uma mensagem no bate-papo quando membros da guilda entram ou saem.",
    ["TOGGLE_DESC_removeChatDelay"] = "Remove o atraso anti-spam entre o envio de mensagens de bate-papo.",
    ["TOGGLE_DESC_chatMouseScroll"] = "Role pelo histórico do bate-papo usando a roda do mouse.",
    ["TOGGLE_DESC_profanityFilter"] = "Substitui palavrões por símbolos no bate-papo.",
    ["TOGGLE_DESC_chatStyle"] = "Clássico usa janelas de bate-papo separadas. Moderno usa um estilo de bate-papo com abas.",

    ["TOGGLE_DESC_Sound_EnableAllSound"] = "Interruptor principal de todo o áudio do jogo. Desativá-lo silencia tudo.",
    ["TOGGLE_DESC_Sound_EnableMusic"] = "Reproduz música de fundo nas zonas e durante eventos.",
    ["TOGGLE_DESC_Sound_EnableSFX"] = "Reproduz efeitos sonoros, incluindo habilidades, sons de combate e cliques da interface.",
    ["TOGGLE_DESC_Sound_EnableDialog"] = "Reproduz a dublagem dos PNJs e o áudio dos diálogos de missão.",
    ["TOGGLE_DESC_Sound_EnableAmbience"] = "Reproduz sons ambientais do cenário, como vento, pássaros e água.",
    ["TOGGLE_DESC_Sound_EnablePetSounds"] = "Reproduz sons do seu mascote, como rosnados e movimento.",
    ["TOGGLE_DESC_FootstepSounds"] = "Reproduz sons de passos ao andar e correr.",
    ["TOGGLE_DESC_Sound_MasterVolume"] = "Volume geral do jogo. Afeta todos os outros controles de volume.",
    ["TOGGLE_DESC_Sound_MusicVolume"] = "Volume da música de fundo.",
    ["TOGGLE_DESC_Sound_SFXVolume"] = "Volume dos efeitos sonoros, incluindo habilidades e combate.",

    ["TOGGLE_DESC_ffxDeath"] = "Mostra um efeito de tela em tons de cinza dessaturados quando você morre.",
    ["TOGGLE_DESC_ffxGlow"] = "Ativa o suave efeito de brilho bloom ao redor de objetos luminosos.",
    ["TOGGLE_DESC_ffxNether"] = "Ativa efeitos visuais especiais no Caos e em áreas do vazio.",
    ["TOGGLE_DESC_emphasizeMySpellEffects"] = "Torna seus próprios efeitos de magia mais visíveis em comparação com os de outros jogadores.",
    ["TOGGLE_DESC_doNotFlashLowHealthWarning"] = "Desativa o piscar vermelho da tela que aparece quando sua vida está criticamente baixa.",
    ["TOGGLE_DESC_hdPlayerModels"] = "Usa modelos de personagem em alta definição. Mais bonitos, mas consomem mais memória.",
    ["TOGGLE_DESC_findYourselfAnywhere"] = "Mostra um círculo de destaque sob seu personagem para você sempre se encontrar na multidão.",
    ["TOGGLE_DESC_gxVSync"] = "Limita os quadros à taxa de atualização do seu monitor. Evita o rasgamento de tela, mas adiciona um pequeno atraso de entrada.",
    ["TOGGLE_DESC_gxTripleBuffer"] = "Buffer triplo para um ritmo de quadros mais suave. Adiciona um leve atraso de entrada.",
    ["TOGGLE_DESC_particleDensity"] = "Quantos efeitos de magia e partículas aparecem ao mesmo tempo. Valores menores melhoram o FPS em raides cheias.",
    ["TOGGLE_DESC_maxFPS"] = "Máximo de quadros por segundo quando a janela do jogo está ativa. Defina 0 para ilimitado.",
    ["TOGGLE_DESC_maxFPSBk"] = "Máximo de quadros por segundo quando a janela do jogo está em segundo plano. Valores menores economizam energia ao alternar de janela.",
    ["TOGGLE_DESC_gxMaxFrameLatency"] = "Máximo de quadros em fila para renderização. Valores menores reduzem o atraso de entrada. Valores maiores produzem uma saída mais suave.",
    ["TOGGLE_DESC_RenderScale"] = "Multiplicador da resolução interna. Valores acima de 1.0 aplicam supersampling para uma imagem mais nítida. Abaixo de 1.0 melhoram o desempenho.",
    ["TOGGLE_DESC_graphicsQuality"] = "Predefinição principal de qualidade gráfica. Alterá-la ajusta automaticamente todos os outros ajustes gráficos.",
    ["TOGGLE_DESC_ffxAntiAliasingMode"] = "Suaviza as bordas serrilhadas dos objetos. Modos superiores oferecem melhor qualidade, mas usam mais recursos da GPU.",
    ["TOGGLE_DESC_colorblindMode"] = "Ativa ajustes de cor adaptados para daltônicos. Escolha um modo que corresponda ao seu tipo de deficiência de visão de cores.",

    ["TOGGLE_DESC_disableServerNagle"] = "Reduz a latência de rede desativando o agrupamento de pacotes. Pode aumentar levemente o uso de banda.",
    ["TOGGLE_DESC_gxFixLag"] = "Reduz o atraso de entrada do cursor do mouse em alguns sistemas modificando a fila de renderização.",
    ["TOGGLE_DESC_reducedLagTolerance"] = "Otimiza o desempenho de rede para conexões de baixa latência. Pode afetar o enfileiramento de magias.",
    ["TOGGLE_DESC_SpellQueueWindow"] = "Com quantos milissegundos de antecedência você pode enfileirar sua próxima magia antes que a atual termine. Valores maiores são mais tolerantes no tempo.",

    ["TOGGLE_OPT_chatStyle_classic"] = "Clássico",
    ["TOGGLE_OPT_chatStyle_im"] = "Moderno",
    ["TOGGLE_OPT_graphicsQuality_1"] = "1",
    ["TOGGLE_OPT_graphicsQuality_2"] = "2",
    ["TOGGLE_OPT_graphicsQuality_3"] = "3",
    ["TOGGLE_OPT_graphicsQuality_4"] = "4",
    ["TOGGLE_OPT_graphicsQuality_5"] = "5",
    ["TOGGLE_OPT_graphicsQuality_6"] = "6",
    ["TOGGLE_OPT_graphicsQuality_7"] = "7",
    ["TOGGLE_OPT_graphicsQuality_8"] = "8",
    ["TOGGLE_OPT_graphicsQuality_9"] = "9",
    ["TOGGLE_OPT_graphicsQuality_10"] = "10",
    ["TOGGLE_OPT_ffxAntiAliasingMode_0"] = "Não",
    ["TOGGLE_OPT_ffxAntiAliasingMode_1"] = "CMAA",
    ["TOGGLE_OPT_ffxAntiAliasingMode_2"] = "FXAA baixo",
    ["TOGGLE_OPT_ffxAntiAliasingMode_3"] = "FXAA alto",
    ["TOGGLE_OPT_colorblindMode_0"] = "Não",
    ["TOGGLE_OPT_colorblindMode_1"] = "Protanopia",
    ["TOGGLE_OPT_colorblindMode_2"] = "Deuteranopia",
    ["TOGGLE_OPT_colorblindMode_3"] = "Tritanopia",

    ["BINDING_HEADER_ONEWOW_QOL"] = "|cFF00FF00OneWoW|r QoL",
    ["BINDING_NAME_QUESTITEM_1"] = "Item de missão 1",
    ["BINDING_NAME_QUESTITEM_2"] = "Item de missão 2",
    ["BINDING_NAME_QUESTITEM_3"] = "Item de missão 3",
    ["BINDING_NAME_QUESTITEM_4"] = "Item de missão 4",
    ["BINDING_NAME_BAGITEM_1"] = "Item de bolsa 1",
    ["BINDING_NAME_BAGITEM_2"] = "Item de bolsa 2",
    ["BINDING_NAME_BAGITEM_3"] = "Item de bolsa 3",
    ["BINDING_NAME_BAGITEM_4"] = "Item de bolsa 4",
    ["BINDING_NAME_COPY_TEXT"] = "Copiar texto",
})
