local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["AUTOREADYCHECK_TITLE"] = "Автоприём проверки готовности",
    ["AUTOREADYCHECK_DESC"] = "Автоматически подтверждает готовность, когда в вашей группе объявляют проверку готовности.",
    ["AUTOREADYCHECK_TOGGLE_DEAD"] = "Пропускать, если мёртв",
    ["AUTOREADYCHECK_TOGGLE_DEAD_DESC"] = "Не принимать автоматически, если вы мертвы или призрак, чтобы группа видела, что вы не готовы начинать.",
})
