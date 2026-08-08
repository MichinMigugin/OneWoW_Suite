local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["AUTOMOUNT_TITLE"] = "Montaria automática",
    ["AUTOMOUNT_DESC"] = "Monta você automaticamente na montaria mais rápida disponível quando você para de se mover em uma área onde é possível montar. Remonta após a coleta.",
    ["AUTOMOUNT_MOUNT_PREFS"] = "Preferências de montaria",
    ["AUTOMOUNT_GROUND_LABEL"] = "Montaria terrestre",
    ["AUTOMOUNT_FLYING_LABEL"] = "Montaria voadora",
    ["AUTOMOUNT_AQUATIC_LABEL"] = "Montaria aquática",
    ["AUTOMOUNT_CAT_ON"] = "Ativado",
    ["AUTOMOUNT_CAT_OFF"] = "Desativado",
    ["AUTOMOUNT_RANDOM_FAVORITE"] = "Favorita aleatória",
    ["AUTOMOUNT_SELECT_TITLE"] = "Escolher montaria %s",
    ["AUTOMOUNT_SELECT_TOOLTIP"] = "Clique para escolher uma montaria",
    ["AUTOMOUNT_SELECT_TOOLTIP_DESC"] = "Escolha uma montaria específica ou deixe a seleção automática escolher a mais rápida disponível.",
    ["AUTOMOUNT_DRUID_SECTION"] = "Druida",
    ["AUTOMOUNT_DRUID_MODE_LABEL"] = "Modo druida",
    ["AUTOMOUNT_DRUID_MODE_DESC"] = "Quando ativado, a montagem automática é ignorada para que você possa mudar para a Forma de viagem manualmente após coletar.",
    ["AUTOMOUNT_STATUS_LABEL"] = "Status da montaria",
    ["AUTOMOUNT_STATUS_READY"] = "Pronto para montar",
    ["AUTOMOUNT_STATUS_MOUNTED"] = "Atualmente montado",
    ["AUTOMOUNT_STATUS_DISABLED"] = "Montaria automática desativada",
    ["AUTOMOUNT_TIMING_SECTION"] = "Tempos",
    ["AUTOMOUNT_DISMOUNT_DELAY"] = "Atraso ao desmontar",
    ["AUTOMOUNT_DISMOUNT_DELAY_DESC"] = "Quanto tempo após desmontar antes de a montagem automática retomar.",
    ["AUTOMOUNT_FISHING_DELAY"] = "Atraso de pesca",
    ["AUTOMOUNT_FISHING_DELAY_DESC"] = "Quanto tempo após pescar antes de a montagem automática retomar.",
    ["AUTOMOUNT_GATHER_DELAY"] = "Atraso de remontagem após coleta",
    ["AUTOMOUNT_GATHER_DELAY_DESC"] = "Com que rapidez remontar após coletar.",
    ["AUTOMOUNT_DRUID_CANCEL_LABEL"] = "Cancelar auto. Forma de viagem",
    ["AUTOMOUNT_DRUID_CANCEL_DESC"] = "Cancela automaticamente a Forma de viagem quando você entra em uma área onde é possível voar, permitindo montar uma montaria voadora em vez disso.",
})
