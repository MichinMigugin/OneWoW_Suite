local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["CRAFTORDERS_TITLE"] = "Заказы на предметы",
    ["CRAFTORDERS_DESC"] = "Заменяет список заказов разделами «Можно сделать сейчас» и «Не хватает материалов». Недостающие реагенты можно добавить в список покупок. Начать, создать и завершить одной кнопкой.",
    ["CRAFTORDERS_SECTION_READY"] = "Можно сделать сейчас",
    ["CRAFTORDERS_SECTION_MISSING"] = "Не хватает материалов",
    ["CRAFTORDERS_WEEKLY_NOT_ACCEPTED"] = "Еженедельное: не принято",
    ["CRAFTORDERS_WEEKLY_NOT_LEARNED"] = "Еженедельное: не изучено",
    ["CRAFTORDERS_WEEKLY_COMPLETE"] = "Еженедельное: выполнено",
    ["CRAFTORDERS_WEEKLY_PROGRESS"] = "Еженедельное: %d / %d выполнено",
    ["CRAFTORDERS_LOADING"] = "Загрузка заказов...",
    ["CRAFTORDERS_ADD_ACTIVE"] = "Добавить в %s",
    ["CRAFTORDERS_MAKE_LIST"] = "Создать список",
    ["CRAFTORDERS_ADD_MENU_HINT"] = "ПКМ: создать список или выбрать другой.",
    ["CRAFTORDERS_ELSEWHERE_TIP"] = "Также в: %s",
    ["CRAFTORDERS_COL_CRAFT"] = "Заказ",
    ["CRAFTORDERS_COL_YOU"] = "Вы даете",
    ["CRAFTORDERS_COL_CART"] = "Список",
    ["CRAFTORDERS_COL_CUSTOMER"] = "Заказчик дает",
    ["CRAFTORDERS_COL_REWARD"] = "Вы получаете",
    ["CRAFTORDERS_USE_WOWUI"] = "WoW UI",
    ["CRAFTORDERS_USE_ONEUI"] = "One UI",
    ["CRAFTORDERS_TOGGLE_WOWUI"] = "Список WoW",
    ["CRAFTORDERS_TOGGLE_WOWUI_DESC"] = "Показывать таблицу заказов Blizzard вместо «Можно сделать сейчас» и «Не хватает материалов».",
    ["CRAFTORDERS_TOGGLE_HIDE_UNLEARNED"] = "Скрыть неизученные рецепты",
    ["CRAFTORDERS_TOGGLE_HIDE_UNLEARNED_DESC"] = "Скрыть заказы, рецепт которых вы не изучили.",
    ["CRAFTORDERS_BUCKET_COUNT"] = "%d заказов",
    ["CRAFTORDERS_ORDER_LIST_NAME"] = "Заказ: %s",
    ["CRAFTORDERS_NO_SHOPPING"] = "Включите список покупок, чтобы добавлять реагенты.",
    ["CRAFTORDERS_KP"] = "%d знания",
    ["CRAFTORDERS_ACUITY"] = "Острота x%d",
    ["CRAFTORDERS_INCOMPATIBLE_TITLE"] = "Другие аддоны списка заказов",
    ["CRAFTORDERS_INCOMPATIBLE_BODY"] = "%s включен. Эти аддоны остаются загруженными. Включите это для One UI или выключите, чтобы пользоваться ими.",
})
