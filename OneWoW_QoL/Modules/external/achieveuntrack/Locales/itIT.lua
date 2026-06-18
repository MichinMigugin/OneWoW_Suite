local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["ACHIEVEUNTRACK_TITLE"] = "Smetti di tracciare le imprese completate",
    ["ACHIEVEUNTRACK_DESC"] = "Cerca e smette automaticamente di tracciare le imprese già completate al login. Libera slot di tracciamento nascosti che possono rimanere bloccati dopo un crash o un completamento tra personaggi diversi.",
})
