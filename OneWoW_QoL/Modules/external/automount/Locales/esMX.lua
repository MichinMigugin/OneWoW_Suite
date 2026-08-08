local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["AUTOMOUNT_TITLE"] = "Montura automática",
    ["AUTOMOUNT_DESC"] = "Te monta automáticamente en la montura más rápida disponible cuando dejas de moverte en una zona montable. Vuelve a montar tras la recolección.",
    ["AUTOMOUNT_MOUNT_PREFS"] = "Preferencias de montura",
    ["AUTOMOUNT_GROUND_LABEL"] = "Montura terrestre",
    ["AUTOMOUNT_FLYING_LABEL"] = "Montura voladora",
    ["AUTOMOUNT_AQUATIC_LABEL"] = "Montura acuática",
    ["AUTOMOUNT_CAT_ON"] = "Activado",
    ["AUTOMOUNT_CAT_OFF"] = "Desactivado",
    ["AUTOMOUNT_RANDOM_FAVORITE"] = "Favorita aleatoria",
    ["AUTOMOUNT_SELECT_TITLE"] = "Elegir montura %s",
    ["AUTOMOUNT_SELECT_TOOLTIP"] = "Haz clic para elegir una montura",
    ["AUTOMOUNT_SELECT_TOOLTIP_DESC"] = "Elige una montura específica o deja que la selección automática escoja la más rápida disponible.",
    ["AUTOMOUNT_DRUID_SECTION"] = "Druida",
    ["AUTOMOUNT_DRUID_MODE_LABEL"] = "Modo druida",
    ["AUTOMOUNT_DRUID_MODE_DESC"] = "Cuando está activado, se omite el montado automático para que puedas cambiar a Forma de viaje manualmente tras recolectar.",
    ["AUTOMOUNT_STATUS_LABEL"] = "Estado de montura",
    ["AUTOMOUNT_STATUS_READY"] = "Listo para montar",
    ["AUTOMOUNT_STATUS_MOUNTED"] = "Montado actualmente",
    ["AUTOMOUNT_STATUS_DISABLED"] = "Montura automática desactivada",
    ["AUTOMOUNT_TIMING_SECTION"] = "Tiempos",
    ["AUTOMOUNT_DISMOUNT_DELAY"] = "Retardo al desmontar",
    ["AUTOMOUNT_DISMOUNT_DELAY_DESC"] = "Cuánto tiempo tras desmontar antes de que se reanude el montado automático.",
    ["AUTOMOUNT_FISHING_DELAY"] = "Retardo de pesca",
    ["AUTOMOUNT_FISHING_DELAY_DESC"] = "Cuánto tiempo tras pescar antes de que se reanude el montado automático.",
    ["AUTOMOUNT_GATHER_DELAY"] = "Retardo de remontado tras recolectar",
    ["AUTOMOUNT_GATHER_DELAY_DESC"] = "Con qué rapidez volver a montar tras recolectar.",
    ["AUTOMOUNT_DRUID_CANCEL_LABEL"] = "Cancelar auto. Forma de viaje",
    ["AUTOMOUNT_DRUID_CANCEL_DESC"] = "Cancela automáticamente la Forma de viaje cuando entras en una zona donde se puede volar, permitiéndote montar una montura voladora en su lugar.",
})
