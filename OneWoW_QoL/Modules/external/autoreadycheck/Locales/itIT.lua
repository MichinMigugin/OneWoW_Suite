local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["AUTOREADYCHECK_TITLE"] = "Accetta auto. verifica di prontezza",
    ["AUTOREADYCHECK_DESC"] = "Conferma automaticamente che sei pronto quando viene avviata una verifica di prontezza nel tuo gruppo.",
    ["AUTOREADYCHECK_TOGGLE_DEAD"] = "Salta se morto",
    ["AUTOREADYCHECK_TOGGLE_DEAD_DESC"] = "Non accettare automaticamente se sei morto o uno spettro, così il gruppo vede che non sei pronto a iniziare.",
})
