local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted (Phase 4) — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["CURSORENHANCER_TITLE"] = "Улучшение курсора",
    ["CURSORENHANCER_DESC"] = "Показывает настраиваемое кольцо вокруг вашего курсора с дополнительным эффектом следа мыши.",
    ["CURSORENHANCER_OUTER_RING"] = "Показывать внешнее кольцо",
    ["CURSORENHANCER_MIDDLE_RING"] = "Показывать среднее кольцо",
    ["CURSORENHANCER_CENTER_MARKER"] = "Показывать центральную метку",
    ["CURSORENHANCER_SHOW_OOC"] = "Показывать вне боя",
    ["CURSORENHANCER_SHOW_INSTANCE"] = "Показывать только в подземельях",
    ["CURSORENHANCER_MOUSE_TRAIL"] = "Показывать след мыши",
    ["CURSORENHANCER_MODULE_TOGGLES"] = "Переключатели модулей",
    ["CURSORENHANCER_MARKER_TOGGLES"] = "Переключатели меток",
    ["CURSORENHANCER_COLORS_HEADER"] = "Цвета колец",
    ["CURSORENHANCER_OUTER_RING_COLOR"] = "Цвет внешнего кольца",
    ["CURSORENHANCER_MIDDLE_RING_COLOR"] = "Цвет среднего кольца",
    ["CURSORENHANCER_CENTER_MARKER_COLOR"] = "Цвет центральной метки",
    ["CURSORENHANCER_TRAIL_COLOR"] = "Цвет следа",
})
