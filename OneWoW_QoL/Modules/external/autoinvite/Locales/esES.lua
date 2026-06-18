local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["AUTOINVITE_TITLE"] = "Aceptar auto. invitaciones de grupo",
    ["AUTOINVITE_DESC"] = "Acepta automáticamente las invitaciones de grupo que provienen de personas en las que confías. Elige abajo qué fuentes están permitidas.",
    ["AUTOINVITE_TOGGLE_FRIENDS"] = "De amigos",
    ["AUTOINVITE_TOGGLE_FRIENDS_DESC"] = "Aceptar invitaciones de amigos de WoW y amigos de Battle.net.",
    ["AUTOINVITE_TOGGLE_GUILD"] = "De la hermandad",
    ["AUTOINVITE_TOGGLE_GUILD_DESC"] = "Aceptar invitaciones de miembros de tu hermandad.",
    ["AUTOINVITE_TOGGLE_ALL"] = "De cualquiera",
    ["AUTOINVITE_TOGGLE_ALL_DESC"] = "Aceptar cualquier invitación de grupo, sin importar quién la envíe. Anula las demás opciones cuando está activado.",
})
