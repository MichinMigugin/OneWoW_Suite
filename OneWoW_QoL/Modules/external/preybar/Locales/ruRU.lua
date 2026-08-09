local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["PREYBAR_TITLE"] = "Панель охоты на добычу",
    ["PREYBAR_DESC"] = "Показывает перемещаемую панель, отслеживающую ваш прогресс охоты на добычу (Холодно > Тепло > Горячо > Готово) для текущей зоны, с боссом, сложностью и аффиксами активной охоты. Разблокируйте её, чтобы перетащить на место.",

    ["PREYBAR_TOGGLE_BOSS"] = "Показывать имя босса",
    ["PREYBAR_TOGGLE_BOSS_DESC"] = "Показывает имя активной охоты на добычу над панелью.",
    ["PREYBAR_TOGGLE_DIFFICULTY"] = "Показывать сложность",
    ["PREYBAR_TOGGLE_DIFFICULTY_DESC"] = "Показывает сложность охоты (Обычная, Сложная, Кошмар).",
    ["PREYBAR_TOGGLE_AFFIXES"] = "Показывать аффиксы",
    ["PREYBAR_TOGGLE_AFFIXES_DESC"] = "Показывает значки аффиксов активной охоты под панелью.",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD"] = "Скрыть виджет Blizzard",
    ["PREYBAR_TOGGLE_HIDE_BLIZZARD_DESC"] = "Скрывает стандартный виджет прогресса охоты на добычу от Blizzard, пока эта панель активна.",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT"] = "Щелчок для установки точки маршрута",
    ["PREYBAR_TOGGLE_CLICK_WAYPOINT_DESC"] = "Когда добыча готова, щёлкните по панели, чтобы установить точку маршрута к охоте на карте.",
    ["PREYBAR_TOGGLE_LOCK"] = "Зафиксировать положение",
    ["PREYBAR_TOGGLE_LOCK_DESC"] = "Фиксирует панель, чтобы её нельзя было перетаскивать. Отключите это и откройте панель настроек, чтобы изменить положение с помощью образца предпросмотра.",

    ["PREYBAR_STATE_COLD"] = "Холодно",
    ["PREYBAR_STATE_WARM"] = "Тепло",
    ["PREYBAR_STATE_HOT"] = "Горячо",
    ["PREYBAR_STATE_READY"] = "Готово",

    ["PREYBAR_DIFFICULTY_NORMAL"] = "Обычная",
    ["PREYBAR_DIFFICULTY_HARD"] = "Сложная",
    ["PREYBAR_DIFFICULTY_NIGHTMARE"] = "Кошмар",

    ["PREYBAR_AFFIX_AMBUSH"] = "Засада",
    ["PREYBAR_AFFIX_TORMENT"] = "Мучение",
    ["PREYBAR_AFFIX_SEEPING_GORE"] = "Сочащаяся кровь",
    ["PREYBAR_AFFIX_ECHO"] = "Эхо хищничества",
    ["PREYBAR_AFFIX_BLOODY"] = "Кровавый приказ",

    ["PREYBAR_ADVICE_AMBUSHED"] = "Засада!",
    ["PREYBAR_ADVICE_KILL"] = "Убейте кого-нибудь!",
    ["PREYBAR_ADVICE_READY"] = "Добыча готова - выследите её!",

    ["PREYBAR_STATE_LABEL"] = "%s  %d%%",
    ["PREYBAR_DEMO_BOSS"] = "Образец добычи",
    ["PREYBAR_DRAG_HINT"] = "Разблокировать для перетаскивания  -  Панель охоты на добычу",
    ["PREYBAR_CLICK_WAYPOINT_HINT"] = "Щёлкните, чтобы установить точку маршрута к добыче",
    ["PREYBAR_OPACITY_FMT"] = "Непрозрачность: %d%%",
    ["PREYBAR_SAMPLE_BAR_HEADER"] = "Образец панели",
    ["PREYBAR_SETTINGS_HINT"] = "Пока эта панель открыта, показывается образец панели, чтобы вы могли её разместить. Отключите «Зафиксировать положение», чтобы перетащить её, затем снова зафиксируйте. Вне этой панели полоса появляется только во время активной охоты на добычу.",
})
