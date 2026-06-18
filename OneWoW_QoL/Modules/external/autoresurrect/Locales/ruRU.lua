local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["AUTORESURRECT_TITLE"] = "Автоприём воскрешения",
    ["AUTORESURRECT_DESC"] = "Автоматически принимает запросы на воскрешение, когда кто-то применяет на вас воскрешение. Пропускается, пока вы в бою.",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE"] = "Не принимать в подземельях",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE_DESC"] = "Пропускает автоприём, пока вы в подземелье, рейде, на поле боя или арене. Полезно, если хотите дождаться подходящего момента для воскрешения.",
})
