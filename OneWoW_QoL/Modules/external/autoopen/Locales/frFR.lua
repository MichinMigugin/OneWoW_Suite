local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["AUTOOPEN_TITLE"] = "Ouverture auto",
    ["AUTOOPEN_DESC"] = "Ouvre automatiquement les sacs, boîtes et autres objets conteneurs lorsqu'ils apparaissent dans votre inventaire. N'ouvre pas d'objets à une banque, une boîte aux lettres ou un marchand. Les objets que vous ne pouvez pas encore ouvrir (coffres verrouillés, mauvais niveau/classe/métier, ou pendant que l'emplacement est occupé) sont automatiquement ignorés.",
    ["AUTOOPEN_OPENING"] = "Ouverture auto : %s",
    ["AUTOOPEN_BLACKLIST_DESC"] = "Ajoutez des objets pour empêcher Ouverture auto de les ouvrir.",
    ["AUTOOPEN_BLACKLIST_REMOVED"] = "Retiré de la liste noire : %s",
})
