local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["AUTODELETE_TITLE"] = "Автоудаление",
    ["AUTODELETE_DESC"] = "Не нужно вводить УДАЛИТЬ при уничтожении предметов. Кнопка подтверждения становится доступной сразу, без необходимости что-либо вводить.",
    ["AUTODELETE_TOGGLE_SKIP"] = "Пропускать ввод подтверждения",
    ["AUTODELETE_TOGGLE_SKIP_DESC"] = "Автоматически активирует кнопку «Удалить», не требуя вводить УДАЛИТЬ.",
    ["AUTODELETE_TOGGLE_LINK"] = "Показывать ссылку на предмет",
    ["AUTODELETE_TOGGLE_LINK_DESC"] = "Показывает ссылку на предмет во всплывающем окне подтверждения, чтобы вы видели, что собираетесь удалить.",
})
