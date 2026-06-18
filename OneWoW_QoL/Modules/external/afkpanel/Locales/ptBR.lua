local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["AFKPANEL_TITLE"] = "Painel AFK",
    ["AFKPANEL_DESC"] = "Exibe uma sobreposição AFK em tela cheia com a info do seu personagem, alertas e notas quando você fica AFK.",
    ["AFKPANEL_CAMERA_SPIN"] = "Giro de câmera",
    ["AFKPANEL_SHOW_DAILY"] = "Mostrar notas diárias",
    ["AFKPANEL_SHOW_WEEKLY"] = "Mostrar notas semanais",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - Modo AFK",
    ["AFKPANEL_CHARACTER_INFO"] = "INFO DO PERSONAGEM",
    ["AFKPANEL_ALERTS"] = "ALERTAS",
    ["AFKPANEL_NO_ALERTS"] = "Nenhum alerta no momento",
    ["AFKPANEL_AFK_TIME"] = "AFK: %s",
    ["AFKPANEL_DAILY_NOTES"] = "NOTAS DIÁRIAS",
    ["AFKPANEL_WEEKLY_NOTES"] = "NOTAS SEMANAIS",
    ["AFKPANEL_NO_NOTES"] = "Nenhuma nota para exibir",
    ["AFKPANEL_NO_GUILD"] = "Sem guilda",
})
