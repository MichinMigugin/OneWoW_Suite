local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["HIDEERRORS_TITLE"] = "Скрыть спам ошибок боя",
    ["HIDEERRORS_DESC"] = "Скрывает самые частые красные сообщения об ошибках (не хватает маны, вне досягаемости, цель должна быть перед вами, заклинание не готово и т. д.), чтобы центр экрана оставался чистым во время боёв.",
})
