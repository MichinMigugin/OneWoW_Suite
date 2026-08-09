local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["PREYBAR_TITLE"] = "Barra de caça à presa",
    ["PREYBAR_DESC"] = "Mostra uma barra movível que acompanha seu progresso de caça à presa (Frio > Morno > Quente > Pronto) na zona atual, com o chefe, a dificuldade e os afixos da caça ativa. Desbloqueie-a para arrastá-la ao lugar.",

    ["PREYBAR_TOGGLE_BOSS"] = "Mostrar nome do chefe",
    ["PREYBAR_TOGGLE_BOSS_DESC"] = "Exibe o nome da caça à presa ativa acima da barra.",
    ["PREYBAR_TOGGLE_DIFFICULTY"] = "Mostrar dificuldade",
    ["PREYBAR_TOGGLE_DIFFICULTY_DESC"] = "Exibe a dificuldade da caça (Normal, Difícil, Pesadelo).",
    ["PREYBAR_TOGGLE_AFFIXES"] = "Mostrar afixos",
    ["PREYBAR_TOGGLE_AFFIXES_DESC"] = "Exibe os ícones de afixos da caça ativa abaixo da barra.",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD"] = "Ocultar widget da Blizzard",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD_DESC"] = "Oculta o widget de progresso de caça à presa padrão da Blizzard enquanto esta barra está ativa.",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT"] = "Clique para definir ponto de rota",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT_DESC"] = "Quando a presa estiver pronta, clique na barra para definir um ponto de rota no mapa até a caça.",
    ["PREYBAR_TOGGLE_LOCK"] = "Travar posição",
    ["PREYBAR_TOGGLE_LOCK_DESC"] = "Trava a barra para que não possa ser arrastada. Desative isto e abra este painel de configurações para reposicionar a barra usando a prévia de amostra.",

    ["PREYBAR_STATE_COLD"] = "Frio",
    ["PREYBAR_STATE_WARM"] = "Morno",
    ["PREYBAR_STATE_HOT"] = "Quente",
    ["PREYBAR_STATE_READY"] = "Pronto",

    ["PREYBAR_DIFFICULTY_NORMAL"] = "Normal",
    ["PREYBAR_DIFFICULTY_HARD"] = "Difícil",
    ["PREYBAR_DIFFICULTY_NIGHTMARE"] = "Pesadelo",

    ["PREYBAR_AFFIX_AMBUSH"] = "Emboscada",
    ["PREYBAR_AFFIX_TORMENT"] = "Tormento",
    ["PREYBAR_AFFIX_SEEPING_GORE"] = "Sangue escorrendo",
    ["PREYBAR_AFFIX_ECHO"] = "Eco de predação",
    ["PREYBAR_AFFIX_BLOODY"] = "Comando sangrento",

    ["PREYBAR_ADVICE_AMBUSHED"] = "Emboscado!",
    ["PREYBAR_ADVICE_KILL"] = "Mate algo!",
    ["PREYBAR_ADVICE_READY"] = "A presa está pronta - cace-a!",

    ["PREYBAR_STATE_LABEL"] = "%s  %d%%",
    ["PREYBAR_DEMO_BOSS"] = "Presa de amostra",
    ["PREYBAR_DRAG_HINT"] = "Desbloquear para arrastar  -  Barra de caça à presa",
    ["PREYBAR_CLICK_WAYPOINT_HINT"] = "Clique para definir um ponto de rota até sua presa",
    ["PREYBAR_OPACITY_FMT"] = "Opacidade: %d%%",
    ["PREYBAR_SAMPLE_BAR_HEADER"] = "Barra de amostra",
    ["PREYBAR_SETTINGS_HINT"] = "Uma barra de amostra é mostrada enquanto este painel está aberto para que você possa posicioná-la. Desative Travar posição para arrastá-la e depois trave-a novamente. Fora deste painel, a barra só aparece durante uma caça à presa ativa.",
})
