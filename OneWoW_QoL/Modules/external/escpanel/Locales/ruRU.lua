local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["ESCPANEL_TITLE"] = "Панель меню ESC",
    ["ESCPANEL_DESC"] = "Показывает информацию о персонаже, оповещения, заметки зоны и полосу порталов рядом с меню ESC. Выберите ниже, какую сторону использует каждый элемент.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Показывать информацию о персонаже",
    ["ESCPANEL_TOGGLE_ALERTS"] = "Показывать оповещения",
    ["ESCPANEL_TOGGLE_ZONE_NOTES"] = "Показывать заметки зоны",
    ["ESCPANEL_TOGGLE_HIDE_ZONE_EMPTY"] = "Скрывать заметки зоны, если пусто",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "Показывать порталы",
    ["ESCPANEL_LAYOUT_HEADER"] = "Раскладка",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "Сторона информационных панелей",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "Сторона порталов",
    ["ESCPANEL_SIDE_LEFT"] = "Слева от меню",
    ["ESCPANEL_SIDE_RIGHT"] = "Справа от меню",
    ["ESCPANEL_LAYOUT_DESC"] = "Когда оба с одной стороны, порталы располагаются снаружи (дальше от меню), а панели — рядом с меню.",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "Размер значков порталов",
})
