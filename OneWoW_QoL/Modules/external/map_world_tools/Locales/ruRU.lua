local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["MAPWORLD_TITLE"] = "Инструменты карты (мир)",
    ["MAPWORLD_DESC"] = "Карта мира: показ неисследованной местности из данных клиента, дополнительные оттенки, настройки карты поля боя, координаты и небольшие опции удобства/очистки.",

    ["MAPWORLD_GROUP_EXPLORE"] = "Исследование (рисунок карты)",
    ["MAPWORLD_GROUP_FOGOVERLAY"] = "Наложение тумана (тёмный слой)",
    ["MAPWORLD_GROUP_FRAME"] = "Окно карты",
    ["MAPWORLD_GROUP_COMFORT"] = "Удобство",
    ["MAPWORLD_GROUP_CLEANUP"] = "Очистка",
    ["MAPWORLD_GROUP_COORDS"] = "Координаты",
    ["MAPWORLD_GROUP_POI"] = "Точки интереса",
    ["MAPWORLD_GROUP_BATTLE"] = "Карта поля боя",
    ["MAPWORLD_GROUP_POLISH"] = "Доработка",
    ["MAPWORLD_GROUP_CANVAS"] = "Наложение на всю карту",
    ["MAPWORLD_GROUP_MAP"] = "Окно карты мира",

    ["MAPWORLD_REVEAL_MAP"] = "Показывать неисследованные области",
    ["MAPWORLD_REVEAL_MAP_DESC"] = "Отрисовывает недостающие плитки исследования с помощью встроенных данных рисунка карты (та же идея, что и раскрытие бумажной карты). Работает на картах мира и поля боя.",

    ["MAPWORLD_TINT_UNEXPLORED"] = "Окрашивать неисследованные области",
    ["MAPWORLD_TINT_UNEXPLORED_DESC"] = "Применяет цветовой оттенок к плиткам, открытым опцией выше (только карты зон).",

    ["MAPWORLD_UNEX_R"] = "Неисследованное: красный",
    ["MAPWORLD_UNEX_G"] = "Неисследованное: зелёный",
    ["MAPWORLD_UNEX_B"] = "Неисследованное: синий",
    ["MAPWORLD_UNEX_A"] = "Неисследованное: непрозрачность",

    ["MAPWORLD_REMOVE_FOG"] = "Скрыть тёмный слой тумана",
    ["MAPWORLD_REMOVE_FOG_DESC"] = "Скрывает рамку тумана войны Blizzard поверх карты (отдельно от отрисовки недостающего рисунка исследования).",

    ["MAPWORLD_FOG_TINT"] = "Окрашивать слой тумана (ТВ)",
    ["MAPWORLD_FOG_TINT_DESC"] = "Когда тёмный слой тумана виден, умножает его цвет.",

    ["MAPWORLD_CLEAR_BLACKOUT"] = "Мир за картой кликабелен",
    ["MAPWORLD_CLEAR_BLACKOUT_DESC"] = "Делает затемнённое «затемнение» за картой прозрачным и не блокирующим щелчки, чтобы вы ясно видели мир.",

    ["MAPWORLD_NO_MAP_FADE"] = "Отключить затухание карты при движении",
    ["MAPWORLD_NO_MAP_FADE_DESC"] = "Задаёт mapFade, чтобы карта не становилась полупрозрачной при движении персонажа.",

    ["MAPWORLD_NO_MAP_EMOTE"] = "Отключить эмоцию чтения",
    ["MAPWORLD_NO_MAP_EMOTE_DESC"] = "Отменяет эмоцию чтения при открытии карты.",

    ["MAPWORLD_HIDE_FILTER_RESET"] = "Скрыть интерфейс сброса фильтров",
    ["MAPWORLD_HIDE_FILTER_RESET_DESC"] = "Скрывает элемент сброса фильтров карты мира и связанные баннеры счётчиков.",

    ["MAPWORLD_HIDE_MAP_TUTORIAL"] = "Скрыть обучение по карте",
    ["MAPWORLD_HIDE_MAP_TUTORIAL_DESC"] = "Скрывает рамку обучения карты мира и помечает её как закрытую в информационных рамках.",

    ["MAPWORLD_SHOW_COORDS"] = "Показывать координаты",
    ["MAPWORLD_SHOW_COORDS_DESC"] = "Показывает положение курсора и игрока в окне карты.",

    ["MAPWORLD_COORDS_LARGE"] = "Крупный шрифт координат",
    ["MAPWORLD_COORDS_LARGE_DESC"] = "Использует более крупный шрифт для отображения координат.",

    ["MAPWORLD_COORDS_BG"] = "Фон панели координат",
    ["MAPWORLD_COORDS_BG_DESC"] = "Показывает тёмную полосу за текстом координат.",

    ["MAPWORLD_HIDE_CONTINENT_POI"] = "Скрывать точки городов на континентах",
    ["MAPWORLD_HIDE_CONTINENT_POI_DESC"] = "Скрывает определённые метки дома, фракции и города на видах континента и карты мира.",

    ["MAPWORLD_ENHANCE_BATTLE_MAP"] = "Улучшить карту поля боя",
    ["MAPWORLD_ENHANCE_BATTLE_MAP_DESC"] = "Показывает группу на карте поля боя и включает опции ниже.",

    ["MAPWORLD_UNLOCK_BATTLEFIELD"] = "Перетаскивайте, чтобы двигать карту поля боя",
    ["MAPWORLD_UNLOCK_BATTLEFIELD_DESC"] = "Перетаскивайте карту поля боя за её внутреннюю область.",

    ["MAPWORLD_BATTLE_CENTER"] = "Держать карту поля боя по центру на игроке",
    ["MAPWORLD_BATTLE_CENTER_DESC"] = "Заново центрирует карту поля боя на вашей позиции. Удерживайте Shift при перетаскивании, чтобы приостановить.",

    ["MAPWORLD_BATTLE_OPACITY"] = "Видимость карты поля боя",
    ["MAPWORLD_BATTLE_GROUP"] = "Размер значков группы",
    ["MAPWORLD_BATTLE_PLAYER"] = "Размер стрелки игрока",

    ["MAPWORLD_TINT_MENU"] = "Переключатель окраски в меню карты мира",
    ["MAPWORLD_TINT_MENU_DESC"] = "Добавляет флажок «Окрашивать неисследованные» в меню слежения карты (может не загрузиться при изменении API меню).",

    ["MAPWORLD_CANVAS_TINT"] = "Цветное наложение на всю карту",
    ["MAPWORLD_CANVAS_TINT_DESC"] = "Окрашивает весь холст карты полупрозрачным цветом (отдельно от окраски исследования).",

    ["MAPWORLD_MAP_ALPHA"] = "Непрозрачность карты мира",
    ["MAPWORLD_MAP_ALPHA_DESC"] = "Снижает непрозрачность всего окна карты мира (альфа рамки).",

    ["MAPWORLD_MAP_ALPHA_SLIDER"] = "Непрозрачность окна карты",
    ["MAPWORLD_RED"] = "Красный",
    ["MAPWORLD_GREEN"] = "Зелёный",
    ["MAPWORLD_BLUE"] = "Синий",

    ["MAPWORLD_CURSOR"] = "Курсор",
})
