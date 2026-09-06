local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["AFKPANEL_TITLE"] = "Panel AFK",
    ["AFKPANEL_DESC"] = "Superposicion AFK a pantalla completa con las mismas fichas You y Here que el menu ESC, alertas de correo y subastas, y notas Daily/Weekly opcionales si Notes esta activado.",
    ["AFKPANEL_CAMERA_SPIN"] = "Giro de cámara",
    ["AFKPANEL_SHOW_DAILY"] = "Mostrar notas diarias",
    ["AFKPANEL_SHOW_WEEKLY"] = "Mostrar notas semanales",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - Modo AFK",
    ["AFKPANEL_CHARACTER_INFO"] = "INFO DEL PERSONAJE",
    ["AFKPANEL_ALERTS"] = "ALERTAS",
    ["AFKPANEL_NO_ALERTS"] = "No hay alertas en este momento",
    ["AFKPANEL_AFK_TIME"] = "AFK: %s",
    ["AFKPANEL_DAILY_NOTES"] = "NOTAS DIARIAS",
    ["AFKPANEL_WEEKLY_NOTES"] = "NOTAS SEMANALES",
    ["AFKPANEL_NO_NOTES"] = "No hay notas que mostrar",
    ["AFKPANEL_NO_GUILD"] = "Sin hermandad",
})
