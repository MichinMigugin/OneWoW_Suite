local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["AUTOREPAIR_TITLE"] = "Авторемонт",
    ["AUTOREPAIR_DESC"] = "Автоматически чинит всю вашу экипировку, когда вы посещаете торговца, поддерживающего ремонт. Выводит стоимость в чат.",
    ["AUTOREPAIR_TOGGLE_GUILD"] = "Использовать ремонт из банка гильдии",
    ["AUTOREPAIR_TOGGLE_GUILD_DESC"] = "Пытается использовать банк гильдии для оплаты ремонта, прежде чем использовать ваше собственное золото.",
})
