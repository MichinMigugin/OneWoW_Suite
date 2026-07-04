local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["FRAMEMOVER_TITLE"] = "Перемещатель окон",
    ["FRAMEMOVER_DESC"] = "Перетаскивайте окна интерфейса Blizzard, чтобы изменить их положение. Используйте Ctrl+прокрутку для масштабирования. Удерживайте Alt при перетаскивании, чтобы частично вывести окна за край экрана, когда включено «Удерживать в пределах экрана». Положения и масштабы могут сохраняться между сеансами.",

    ["FRAMEMOVER_TOGGLE_REQUIRE_SHIFT"] = "Требовать Shift для перетаскивания",
    ["FRAMEMOVER_TOGGLE_ENABLE_SCALING"] = "Масштабирование Ctrl+прокрутка",
    ["FRAMEMOVER_TOGGLE_SAVE_POSITIONS"] = "Запоминать положения",
    ["FRAMEMOVER_TOGGLE_SAVE_SCALES"] = "Запоминать масштабы",
    ["FRAMEMOVER_TOGGLE_CLAMP_SCREEN"] = "Удерживать в пределах экрана",
    ["FRAMEMOVER_TOGGLE_MODIFY_HUD"] = "Показывать всплывающее окно масштаба",

    ["FRAMEMOVER_GROUP_BEHAVIOR"] = "Поведение",
    ["FRAMEMOVER_GROUP_SAVING"] = "Сохранение",

    ["FRAMEMOVER_CAT_CORE"] = "Основной интерфейс",
    ["FRAMEMOVER_CAT_COLLECTIONS"] = "Коллекции и журналы",
    ["FRAMEMOVER_CAT_PROFESSIONS"] = "Профессии и экономика",
    ["FRAMEMOVER_CAT_GROUP"] = "Групповой контент",
    ["FRAMEMOVER_CAT_CHARACTER"] = "Персонаж и таланты",
    ["FRAMEMOVER_CAT_SOCIAL"] = "Общение и гильдии",
    ["FRAMEMOVER_CAT_MISC"] = "Разное",
    ["FRAMEMOVER_CAT_HOUSING"] = "Жильё",

    ["FRAMEMOVER_FRAMES_HEADER"] = "Перемещаемые окна",
    ["FRAMEMOVER_FILTER_EMPTY"] = "Нет окон, соответствующих поиску.",
    ["FRAMEMOVER_RESET_POSITIONS"] = "Сбросить все положения",
    ["FRAMEMOVER_RESET_SCALES"] = "Сбросить все масштабы",
    ["FRAMEMOVER_RESET_POS_DONE"] = "Положения сброшены. Откройте окна заново, чтобы увидеть значения по умолчанию.",
    ["FRAMEMOVER_RESET_SCALE_DONE"] = "Масштабы сброшены. Откройте окна заново, чтобы увидеть значения по умолчанию.",
    ["FRAMEMOVER_ENABLED_TOOLTIP"] = "Левый щелчок для переключения. Ctrl+прокрутка над окном, чтобы изменить его масштаб. Удерживайте Alt при перетаскивании, чтобы обойти ограничение экрана.",
    ["FEATURES_ON"] = "Вкл",
    ["FEATURES_OFF"] = "Выкл",
})
