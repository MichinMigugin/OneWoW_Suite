local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["AFKPANEL_TITLE"] = "Панель отошёл",
    ["AFKPANEL_DESC"] = "Полноэкранное наложение AFK с теми же карточками You и Here, что и меню ESC, оповещениями о почте и аукционе, и необязательными Daily/Weekly заметками, если Notes включен.",
    ["AFKPANEL_CAMERA_SPIN"] = "Вращение камеры",
    ["AFKPANEL_SHOW_DAILY"] = "Показывать ежедневные заметки",
    ["AFKPANEL_SHOW_WEEKLY"] = "Показывать еженедельные заметки",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - Режим отошёл",
    ["AFKPANEL_CHARACTER_INFO"] = "ИНФО О ПЕРСОНАЖЕ",
    ["AFKPANEL_ALERTS"] = "ОПОВЕЩЕНИЯ",
    ["AFKPANEL_NO_ALERTS"] = "Сейчас нет оповещений",
    ["AFKPANEL_AFK_TIME"] = "Отошёл: %s",
    ["AFKPANEL_DAILY_NOTES"] = "ЕЖЕДНЕВНЫЕ ЗАМЕТКИ",
    ["AFKPANEL_WEEKLY_NOTES"] = "ЕЖЕНЕДЕЛЬНЫЕ ЗАМЕТКИ",
    ["AFKPANEL_NO_NOTES"] = "Нет заметок для показа",
    ["AFKPANEL_NO_GUILD"] = "Нет гильдии",
})
