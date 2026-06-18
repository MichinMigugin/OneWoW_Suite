local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["DECLINEDUEL_TITLE"] = "Автоотклонение дуэлей",
    ["DECLINEDUEL_DESC"] = "Автоматически отклоняет запросы на дуэль, чтобы окно никогда не задерживалось на экране.",
    ["DECLINEDUEL_TOGGLE_PET"] = "Также отклонять дуэли питомцев",
    ["DECLINEDUEL_TOGGLE_PET_DESC"] = "Также автоматически отклонять запросы на дуэль битвы питомцев.",
})
