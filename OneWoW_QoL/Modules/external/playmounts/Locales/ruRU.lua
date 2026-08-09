local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["PLAYMOUNTS_TITLE"] = "Средства передвижения игроков",
    ["PLAYMOUNTS_DESC"] = "Определяет и показывает средство передвижения или форму перемещения, которое сейчас используют другие игроки.",
    ["PLAYMOUNTS_TOGGLE_CHAT"] = "Объявлять в чате",
    ["PLAYMOUNTS_TOGGLE_CHAT_DESC"] = "Выводит название средства передвижения в окно чата, когда вы выбираете игрока верхом.",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT"] = "Подобрать средство",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT_DESC"] = "Добавляет игрокам опцию правого щелчка для призыва средства передвижения того же типа, что и у них.",
    ["PLAYMOUNTS_COLLECTED"] = "(Получено)",
    ["PLAYMOUNTS_NOT_COLLECTED"] = "(Не получено)",
    ["PLAYMOUNTS_USING"] = "%s использует %s",
    ["PLAYMOUNTS_SOURCE"] = "Источник: %s",
    ["PLAYMOUNTS_DISPLAYMODE_DESC"] = "Управляет тем, сколько информации о средстве передвижения показывается в подсказках и выводе в чат.",
    ["PLAYMOUNTS_MODE_NAME"] = "Название",
    ["PLAYMOUNTS_MODE_NAMETYPE"] = "Название + тип",
    ["PLAYMOUNTS_MODE_ALL"] = "Полные сведения",
    ["PLAYMOUNTS_TOOLTIP_HEADER"] = "Интеграция подсказок",
    ["PLAYMOUNTS_TOOLTIP_REQUIRES"] = "Требуется: OneWoW Core",
    ["PLAYMOUNTS_TOOLTIP_DETECTED"] = "Статус: обнаружено",
    ["PLAYMOUNTS_TOOLTIP_NOT_DETECTED"] = "Статус: не обнаружено",
    ["PLAYMOUNTS_TOOLTIP_NOTE"] = "Включайте или отключайте строки подсказки о транспорте в QoL → Подсказки → Транспорт игроков.",
    ["PLAYMOUNTS_TOOLTIP_VIEW_BTN"] = "Открыть настройки",
})
