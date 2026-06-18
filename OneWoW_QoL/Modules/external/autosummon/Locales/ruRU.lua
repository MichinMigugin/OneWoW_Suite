local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["AUTOSUMMON_TITLE"] = "Автоприём призыва",
    ["AUTOSUMMON_DESC"] = "Автоматически принимает запросы на призыв от чернокнижников и камней призыва.",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT"] = "Пропускать в бою",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT_DESC"] = "Не принимать автоматически, пока вы в бою. Рекомендуется включить, чтобы вас не утащило посреди боя.",
})
