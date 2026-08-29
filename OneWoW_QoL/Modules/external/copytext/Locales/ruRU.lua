local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["COPYTEXT_TITLE"] = "Копировать текст",
    ["COPYTEXT_DESC"] = "Копирует видимый текст из подсказок или элементов интерфейса в буфер обмена. Используйте /1wcopytext (или /1wct), чтобы скопировать то, что находится под курсором.",
    ["COPYTEXT_TOGGLE_TOOLTIPS"] = "Режим подсказок",
    ["COPYTEXT_TOGGLE_TOOLTIPS_DESC"] = "При копировании захватывает текст из всех видимых подсказок под курсором.",
    ["COPYTEXT_TOGGLE_ANYTHING"] = "Режим «всё»",
    ["COPYTEXT_TOGGLE_ANYTHING_DESC"] = "При копировании захватывает текст из любого видимого элемента интерфейса под курсором, а не только из подсказок.",
    ["COPYTEXT_TOGGLE_FAST"] = "Быстрое копирование",
    ["COPYTEXT_TOGGLE_FAST_DESC"] = "Автоматически выделяет весь текст в окне копирования, чтобы вы могли скопировать его мгновенно, не нажимая.",
    ["COPYTEXT_NO_TEXT"] = "Под курсором текст не найден.",
    ["COPYTEXT_TOOLTIP_CONTENT"] = "Содержимое подсказки",
    ["COPYTEXT_UI_CONTENT"] = "Текст интерфейса",
})
