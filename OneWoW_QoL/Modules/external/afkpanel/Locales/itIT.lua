local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["AFKPANEL_TITLE"] = "Pannello AFK",
    ["AFKPANEL_DESC"] = "Sovrapposizione AFK a schermo intero con le stesse schede You e Here del menu ESC, avvisi di posta e aste, e note Daily/Weekly opzionali se Notes e attivo.",
    ["AFKPANEL_CAMERA_SPIN"] = "Rotazione della telecamera",
    ["AFKPANEL_SHOW_DAILY"] = "Mostra note giornaliere",
    ["AFKPANEL_SHOW_WEEKLY"] = "Mostra note settimanali",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - Modalità AFK",
    ["AFKPANEL_CHARACTER_INFO"] = "INFO PERSONAGGIO",
    ["AFKPANEL_ALERTS"] = "AVVISI",
    ["AFKPANEL_NO_ALERTS"] = "Nessun avviso al momento",
    ["AFKPANEL_AFK_TIME"] = "AFK: %s",
    ["AFKPANEL_DAILY_NOTES"] = "NOTE GIORNALIERE",
    ["AFKPANEL_WEEKLY_NOTES"] = "NOTE SETTIMANALI",
    ["AFKPANEL_NO_NOTES"] = "Nessuna nota da mostrare",
    ["AFKPANEL_NO_GUILD"] = "Nessuna gilda",
})
