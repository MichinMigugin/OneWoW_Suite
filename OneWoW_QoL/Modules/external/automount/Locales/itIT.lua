local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["AUTOMOUNT_TITLE"] = "Cavalcatura automatica",
    ["AUTOMOUNT_DESC"] = "Ti fa salire automaticamente sulla cavalcatura più veloce disponibile quando smetti di muoverti in un'area dove è consentito cavalcare. Risale dopo la raccolta.",
    ["AUTOMOUNT_MOUNT_PREFS"] = "Preferenze cavalcatura",
    ["AUTOMOUNT_GROUND_LABEL"] = "Cavalcatura terrestre",
    ["AUTOMOUNT_FLYING_LABEL"] = "Cavalcatura volante",
    ["AUTOMOUNT_AQUATIC_LABEL"] = "Cavalcatura acquatica",
    ["AUTOMOUNT_CAT_ON"] = "Attivo",
    ["AUTOMOUNT_CAT_OFF"] = "Disattivo",
    ["AUTOMOUNT_RANDOM_FAVORITE"] = "Preferita casuale",
    ["AUTOMOUNT_SELECT_TITLE"] = "Scegli cavalcatura %s",
    ["AUTOMOUNT_SELECT_TOOLTIP"] = "Clicca per scegliere una cavalcatura",
    ["AUTOMOUNT_SELECT_TOOLTIP_DESC"] = "Scegli una cavalcatura specifica o lascia che la selezione automatica scelga la più veloce disponibile.",
    ["AUTOMOUNT_DRUID_SECTION"] = "Druido",
    ["AUTOMOUNT_DRUID_MODE_LABEL"] = "Modalità druido",
    ["AUTOMOUNT_DRUID_MODE_DESC"] = "Quando attiva, la cavalcata automatica viene saltata così puoi passare manualmente alla Forma da viaggio dopo la raccolta.",
    ["AUTOMOUNT_STATUS_LABEL"] = "Stato cavalcatura",
    ["AUTOMOUNT_STATUS_READY"] = "Pronto a cavalcare",
    ["AUTOMOUNT_STATUS_MOUNTED"] = "Attualmente in sella",
    ["AUTOMOUNT_STATUS_DISABLED"] = "Cavalcatura automatica disattivata",
    ["AUTOMOUNT_TIMING_SECTION"] = "Tempistica",
    ["AUTOMOUNT_DISMOUNT_DELAY"] = "Ritardo dopo essere scesi",
    ["AUTOMOUNT_DISMOUNT_DELAY_DESC"] = "Quanto tempo dopo essere scesi prima che la cavalcata automatica riprenda.",
    ["AUTOMOUNT_FISHING_DELAY"] = "Ritardo pesca",
    ["AUTOMOUNT_FISHING_DELAY_DESC"] = "Quanto tempo dopo la pesca prima che la cavalcata automatica riprenda.",
    ["AUTOMOUNT_GATHER_DELAY"] = "Ritardo risalita dopo raccolta",
    ["AUTOMOUNT_GATHER_DELAY_DESC"] = "Con quanta rapidità risalire dopo la raccolta.",
    ["AUTOMOUNT_DRUID_CANCEL_LABEL"] = "Annulla auto. Forma da viaggio",
    ["AUTOMOUNT_DRUID_CANCEL_DESC"] = "Annulla automaticamente la Forma da viaggio quando entri in un'area dove è consentito volare, permettendoti di evocare invece una cavalcatura volante.",
})
