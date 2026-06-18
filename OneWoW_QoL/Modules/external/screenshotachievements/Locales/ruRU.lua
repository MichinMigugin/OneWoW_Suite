local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["SCREENSHOTACH_TITLE"] = "Снимок экрана при достижении",
    ["SCREENSHOTACH_DESC"] = "Делает снимок экрана через мгновение после получения достижения, чтобы запечатлеть всплывающее уведомление. Файлы сохраняются как 'WoWScrnShot_*.jpg' в папке World of Warcraft\\_retail_\\Screenshots.",
})
