local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["LFGPANEL_TITLE"] = "Блокировки ПГ",
    ["LFGPANEL_DESC"] = "Показывает ваши текущие блокировки рейдов и подземелий в боковой панели, когда открыт Поиск группы.",
    ["LFGPANEL_SHOW_PANEL"] = "Показывать панель блокировок",
    ["LFGPANEL_SHOW_PANEL_DESC"] = "Показывает панель блокировок при открытии Поиска группы.",
    ["LFGPANEL_FILTER_RESULTS"] = "Фильтровать результаты ПГ",
    ["LFGPANEL_FILTER_RESULTS_DESC"] = "Фильтрует результаты поиска ПГ по выбранной сложности.",

    ["LFGPANEL_TT_REFRESH"] = "Обновить блокировки",
    ["LFGPANEL_TT_REFRESH_DESC"] = "Запрашивает с сервера актуальные данные о блокировках.",
    ["LFGPANEL_TT_TOGGLE"] = "Показывать панель блокировок",
    ["LFGPANEL_TT_TOGGLE_DESC"] = "Щёлкните, чтобы показать панель блокировок.",

    ["LFGPANEL_FILTER_DIFFICULTY"] = "Сложность",
    ["LFGPANEL_DIFFICULTY_NORMAL"] = "Обычный",
    ["LFGPANEL_DIFFICULTY_HEROIC"] = "Героический",
    ["LFGPANEL_DIFFICULTY_MYTHIC"] = "Эпохальный",
    ["LFGPANEL_DIFFICULTY_MYTHICPLUS"] = "Эпохальный+",
    ["LFGPANEL_DIFFICULTY_LFR"] = "LFR",

    ["LFGPANEL_NO_LOCKOUTS"] = "Нет активных блокировок.",
    ["LFGPANEL_NO_LOCKOUTS_FILTERED"] = "Нет блокировок, соответствующих выбранной сложности.",
    ["LFGPANEL_EXPIRED"] = "Истекло",
    ["LFGPANEL_EXTENDED"] = "Продлено",
    ["LFGPANEL_TT_EXTENDED"] = "Продлённая блокировка",
    ["LFGPANEL_TT_EXTENDED_DESC"] = "Эта блокировка была продлена вручную сверх обычного сброса.",

    ["LFGPANEL_TIME_DAYS"] = "%dд %dч",
    ["LFGPANEL_TIME_HOURS"] = "%dч %dм",
    ["LFGPANEL_TIME_MINUTES"] = "%dм",
    ["LFGPANEL_PROGRESS"] = "%d/%d",

    ["LFGPANEL_TT_LOCKOUT"] = "Блокировка подземелья",
    ["LFGPANEL_TT_LOCKOUT_PROGRESS"] = "Прогресс по боссам: %d/%d",
    ["LFGPANEL_TT_LOCKOUT_TIME"] = "Сброс через: %s",
    ["LFGPANEL_TT_LOCKOUT_DIFFICULTY"] = "Сложность: %s",

    ["LFGPANEL_OPT_FILTER_LFG"] = "Фильтровать результаты ПГ",
    ["LFGPANEL_TT_FILTER_LFG"] = "Фильтровать результаты ПГ",
    ["LFGPANEL_TT_FILTER_LFG_DESC"] = "Когда включено, результаты поиска ПГ будут отфильтрованы по выбранной сложности.",
})
