local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["AUTOINVITE_TITLE"] = "Accetta auto. inviti al gruppo",
    ["AUTOINVITE_DESC"] = "Accetta automaticamente gli inviti al gruppo provenienti da persone di cui ti fidi. Scegli sotto quali fonti sono consentite.",
    ["AUTOINVITE_TOGGLE_FRIENDS"] = "Dagli amici",
    ["AUTOINVITE_TOGGLE_FRIENDS_DESC"] = "Accetta inviti da amici di WoW e amici di Battle.net.",
    ["AUTOINVITE_TOGGLE_GUILD"] = "Dalla gilda",
    ["AUTOINVITE_TOGGLE_GUILD_DESC"] = "Accetta inviti dai membri della tua gilda.",
    ["AUTOINVITE_TOGGLE_ALL"] = "Da chiunque",
    ["AUTOINVITE_TOGGLE_ALL_DESC"] = "Accetta qualsiasi invito al gruppo, indipendentemente da chi lo invia. Ha la priorità sugli altri interruttori quando attivo.",
})
