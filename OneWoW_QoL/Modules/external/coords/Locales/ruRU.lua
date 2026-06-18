local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["COORDS_TITLE"] = "Отображение координат",
    ["COORDS_DESC"] = "Показывает ваши текущие координаты карты в небольшой перемещаемой рамке рядом с мини-картой. Правый щелчок для копирования координат.",
    ["COORDS_TOGGLE_MAPID"] = "Показывать ID карты",
    ["COORDS_TOGGLE_MAPID_DESC"] = "Показывает числовой ID карты рядом с вашими координатами.",
    ["COORDS_TOGGLE_ZONE"] = "Показывать название зоны",
    ["COORDS_TOGGLE_ZONE_DESC"] = "Показывает название текущей зоны под координатами.",
    ["COORDS_TOGGLE_SUBZONE"] = "Показывать подзону",
    ["COORDS_TOGGLE_SUBZONE_DESC"] = "Показывает текущую подзону или название области.",
    ["COORDS_TOGGLE_FACING"] = "Показывать направление",
    ["COORDS_TOGGLE_FACING_DESC"] = "Показывает ваш текущий курс в градусах и по сторонам света.",
    ["COORDS_TOGGLE_SPEED"] = "Показывать скорость",
    ["COORDS_TOGGLE_SPEED_DESC"] = "Показывает вашу текущую скорость передвижения в метрах в секунду.",
    ["COORDS_TOGGLE_HIDE_INSTANCE"] = "Скрывать в подземельях",
    ["COORDS_TOGGLE_HIDE_INSTANCE_DESC"] = "Автоматически скрывает отображение координат, когда вы находитесь в подземелье, рейде или другой инстанции.",
    ["COORDS_MAP"] = "Карта: %d",
    ["COORDS_COPIED"] = "Координаты скопированы: %s",
    ["COORDS_COPY_TITLE"] = "Координаты",
})
