local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["PROFPANEL_TITLE"] = "Панель профессий",
    ["PROFPANEL_DESC"] = "Показывает вспомогательную панель рядом с окном профессии с разбивкой навыков по дополнениям, количеством рецептов и отслеживанием первого создания.",
    ["PROFPANEL_AUTO_SHOW"] = "Автопоказ панели",
    ["PROFPANEL_TOGGLE_TIP"] = "Панель статистики профессии",
    ["PROFPANEL_HIDE_TIP"] = "Щёлкните, чтобы скрыть панель",
    ["PROFPANEL_SHOW_TIP"] = "Щёлкните, чтобы показать панель",
    ["PROFPANEL_STATS_TITLE"] = "Панель профессий",
    ["PROFPANEL_NO_EXPANSION_DATA"] = "Нет данных по дополнениям.\nОткройте профессию для сканирования.",
    ["PROFPANEL_NO_ALT_DATA"] = "Других персонажей с этой профессией не найдено",
    ["PROFPANEL_OTHER_ALTS"] = "Другие персонажи с этой профессией",
    ["PROFPANEL_LAST_SCANNED"] = "Последнее сканирование: %s",
})
